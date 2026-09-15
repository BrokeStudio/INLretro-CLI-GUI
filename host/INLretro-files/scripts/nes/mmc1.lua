-- create the module's table
local mmc1    = {}

-- import required modules
local dict    = require "scripts.app.dict"
local nes     = require "scripts.app.nes"
local dump    = require "scripts.app.dump"
local flash   = require "scripts.app.flash"
local chips   = require "scripts.app.chips"
local time    = require "scripts.app.time"
local log     = require "scripts.app.log"
local spinner = require "scripts.app.spinner"
local files   = require "scripts.app.files"
local help    = require "scripts.app.help"

-- file constants and global variables
local mapname = "MMC1"

-- local functions

--[[
███╗   ███╗██╗███████╗ ██████╗    ███████╗██╗   ██╗███╗   ██╗ ██████╗███████╗
████╗ ████║██║██╔════╝██╔════╝    ██╔════╝██║   ██║████╗  ██║██╔════╝██╔════╝
██╔████╔██║██║███████╗██║         █████╗  ██║   ██║██╔██╗ ██║██║     ███████╗
██║╚██╔╝██║██║╚════██║██║         ██╔══╝  ██║   ██║██║╚██╗██║██║     ╚════██║
██║ ╚═╝ ██║██║███████║╚██████╗    ██║     ╚██████╔╝██║ ╚████║╚██████╗███████║
╚═╝     ╚═╝╚═╝╚══════╝ ╚═════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚══════╝

--]]

local function create_header(file, prg_kb, chr_kb)
  -- write_header(file, prg_kb, chr_kb, mapper, mirroring)
  nes.write_header(file, prg_kb, chr_kb, op_buffer[mapname], 0)
end

local function init_mapper()
  -- MMC1 ignores all but the first write
  dict.nes("NES_CPU_RD", 0x8000)
  -- reset MMC1 shift register with D7 set
  dict.nes("NES_CPU_WR", 0x8000, 0x80)
  -- this reset also effectively sets the control reg to 0x0C:
  --   prg mode 3: fix last bank at $C000 and switch 16 KB bank at $8000
  --   chr mode 0: switch 8 KB at a time
  --   mirroring 0: 1 screen NT0

  -- mmc1_write(0x8000, 0x10);       //32KB mode, prg bank @ $8000-FFFF, 4KB CHR mode
  dict.nes("NES_MMC1_WR", 0x8000, 0x10)
  --   prg mode 3: switch 32 KB at $8000, ignoring low bit of bank number
  --   chr mode 1: switch two separate 4 KB banks
  --   mirroring 0: 1 screen NT0
  --   //note the mapper will constantly reset to this when writing to PRG-ROM
  --   //PRG-ROM A18-A14

  -- select first PRG-ROM bank, disable save RAM
  dict.nes("NES_MMC1_WR", 0xE000, 0x10) -- LSBit ignored in 32KB mode
  -- bit4 RAM enable 0-enabled 1-disabled

  -- //CHR-ROM A16-12 (A14-12 are required to be valid)
  -- bit4 (CHR A16) is /CE pin for PRG-RAM on SNROM
  dict.nes("NES_MMC1_WR", 0xA000, 0x12) -- 4KB bank @ PT0  $2AAA cmd and writes
  dict.nes("NES_MMC1_WR", 0xC000, 0x15) -- 4KB bank @ PT1  $5555 cmd fixed
end

-- test the mapper's mirroring modes to verify working properly
-- can be used to help identify board: returns true if pass, false if failed
local function mirror_test(debug)
  log.section("Testing mirroring settings")

  -- put mapper in known state
  init_mapper()

  -- Vertical
  dict.nes("NES_MMC1_WR", 0x8000, 0x02)
  if nes.detect_mapper_mirroring(debug) ~= "VERT" then
    log.error("Vertical mirroring test failed")
    return false
  else
    log.success("Vertical mirroring test passed")
  end

  -- Horizontal
  dict.nes("NES_MMC1_WR", 0x8000, 0x03)
  if nes.detect_mapper_mirroring(debug) ~= "HORZ" then
    log.error("Horizontal mirroring test failed")
    return false
  else
    log.success("Horizontal mirroring test passed")
  end

  -- 1 screen A
  dict.nes("NES_MMC1_WR", 0x8000, 0x00)
  if nes.detect_mapper_mirroring(debug) ~= "1SCRNA" then
    log.error("One screen mirroring test failed (1 screen A)")
    return false
  else
    log.success("One screen mirroring test passed (1 screen A)")
  end

  -- 1 screen B
  dict.nes("NES_MMC1_WR", 0x8000, 0x01)
  if nes.detect_mapper_mirroring(debug) ~= "1SCRNB" then
    log.error("One screen mirroring test failed (1 screen B)")
    return false
  else
    log.success("One screen mirroring test passed (1 screen B)")
  end

  -- passed all tests
  return true
end

--[[
██████╗ ██████╗  ██████╗       ██████╗  ██████╗ ███╗   ███╗
██╔══██╗██╔══██╗██╔════╝       ██╔══██╗██╔═══██╗████╗ ████║
██████╔╝██████╔╝██║  ███╗█████╗██████╔╝██║   ██║██╔████╔██║
██╔═══╝ ██╔══██╗██║   ██║╚════╝██╔══██╗██║   ██║██║╚██╔╝██║
██║     ██║  ██║╚██████╔╝      ██║  ██║╚██████╔╝██║ ╚═╝ ██║
╚═╝     ╚═╝  ╚═╝ ╚═════╝       ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝

--]]

--- Read and identify the PRG-ROM flash manufacturer/device ID.
---@return boolean found True when the flash chip is recognized
---@return table device Flash chip information, or an empty table when unknown
local function prg_rom_manf_id()
  local manufacturer_id
  local device_id
  local found
  local device

  init_mapper()

  log.section("Reading PRG-ROM manufacturer/device ID")

  dict.nes("NES_CPU_WR", 0xD555, 0xAA)
  dict.nes("NES_CPU_WR", 0xAAAA, 0x55)
  dict.nes("NES_CPU_WR", 0xD555, 0x90)

  manufacturer_id = dict.nes("NES_CPU_RD", 0x8000)
  chips.display_manufacturer(manufacturer_id)

  device_id = dict.nes("NES_CPU_RD", 0x8001)
  found, device = chips.display_device(manufacturer_id, device_id)

  -- exit software
  dict.nes("NES_CPU_WR", 0x8000, 0xF0)

  return found, device
end

--- Program one byte to PRG-ROM flash and poll for completion.
---@param addr integer Address to program, 0x8000-0xFFFF
---@param value integer 8-bit value to write
---@param bank integer Mapper bank value selecting the target flash bank
---@param debug? boolean Enable verbose progress logging
local function prg_rom_flash_byte(addr, value, bank, debug)
  if addr < 0x8000 or addr > 0xFFFF then
    log.error("ERROR! flash write to PRG-ROM", help.hex_0x4(addr), "must be $8000-$FFFF")
    return
  end

  --mmc1_wr(0x8000, 0x10, 0);               //32KB mode
  --//IDK why, but somehow only the first byte gets programmed when ROM A14=1
  --//so somehow it's getting out of 32KB mode for follow on bytes..
  --//even though we reset to 32KB mode after the corrupting final write
  --
  --wr_func( unlock1, 0xAA );
  --wr_func( unlock2, 0x55 );
  --wr_func( unlock1, 0xA0 );
  --wr_func( ((addrH<<8)| n), buff->data[n] );
  --//writes to flash are to $8000-FFFF so any register could have been corrupted and shift register may be off
  --//In reality MMC1 should have blocked all subsequent writes, so maybe only the CHR reg2 got corrupted..?                mmc1_wr(0x8000, 0x10, 1);               //32KB mode
  --mmc1_wr(0xE000, bank, 0);       //reset shift register, and bank register

  --MMC1 ignores all but the first write
  --dict.nes("NES_CPU_RD", 0x8000)
  --  dict.nes("NES_CPU_WR", 0x8000, 0x80) --reset MMC1 shift register with D7 set

  --dict.nes("NES_MMC1_WR", 0x8000, 0x10) --32KB mode, prg bank @ $8000-FFFF, 4KB CHR mode
  --doing this after the write doesn't work for some reason....
  --I think the reason this works is because the last instruction is a write (and it's valid)
  --so the next 4 writes are blocked by the MMC1 including the reset
  dict.nes("NES_MMC1_WR", 0xC000, 0x05) --this seems to work as well which makes sense based on above..
  --so now all follow on writes will be blocked until there is a read

  --send unlock command and write byte
  dict.nes("NES_CPU_WR", 0xD555, 0xAA) --this will reset the MMC1..?,
  --but not if it was blocked by a previous write
  dict.nes("NES_CPU_WR", 0xAAAA, 0x55) --blocked
  dict.nes("NES_CPU_WR", 0xD555, 0xA0) --blocked
  dict.nes("NES_CPU_WR", addr, value)  --blocked

  --  dict.nes("NES_CPU_RD", 0x8000)  --must read before resetting
  --  dict.nes("NES_CPU_WR", 0x8000, 0x80) --reset MMC1 shift register with D7 set
  --  dict.nes("NES_MMC1_WR", 0x8000, 0x10) --32KB mode, prg bank @ $8000-FFFF, 4KB CHR mode
  --  dict.nes("NES_MMC1_WR", 0xE000, bank<<1) --32KB mode, prg bank @ $8000-FFFF, 4KB CHR mode

  local rv = dict.nes("NES_CPU_RD", addr)

  local i = 0

  while rv ~= dict.nes("NES_CPU_RD", addr) do
    rv = dict.nes("NES_CPU_RD", addr)
    i = i + 1
  end

  if debug then
    log.info("Done writing byte,", i .. " naks")
  end

  -- TODO handle timeout for problems

  -- TODO return pass/fail/info
end

--- Dump PRG-ROM contents to an already-open output file.
---@param file file* Open binary output file
---@param rom_size_kb integer PRG-ROM size in kilobytes
---@param debug? boolean Enable verbose progress logging
local function prg_rom_dump(file, rom_size_kb, debug)
  -- PRG-ROM dump 32KB at a time in 32KB bank mode
  local kb_per_read = 32
  local num_banks = math.floor(rom_size_kb / kb_per_read)
  local cur_bank = 0
  local addr_base = 0x80 -- $8000

  log.info("PRG-ROM size", rom_size_kb .. "KB")

  while cur_bank < num_banks do
    if debug then
      log.point("dumping PRG bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- bit4 (CHR A16) is A18 pin for PRG on SOROM, SUROM and SXROM
    if cur_bank < 8 then
      dict.nes("NES_MMC1_WR", 0xA000, 0x00)
      dict.nes("NES_MMC1_WR", 0xC000, 0x00)
    else
      dict.nes("NES_MMC1_WR", 0xA000, 0x10)
      dict.nes("NES_MMC1_WR", 0xC000, 0x10)
    end

    -- set bank
    dict.nes("NES_MMC1_WR", 0xE000, cur_bank << 1) -- LSBit ignored in 32KB mode

    -- dump a bank worth of data
    dump.dumptofile(file, kb_per_read, { mapper = addr_base, mem_type = "NESCPU_PAGE" }, false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--- Program PRG-ROM contents from an already-open input file, one bank at a time.
---@param file file* Open binary input file
---@param rom_size_kb integer PRG-ROM size in kilobytes
---@param debug? boolean Enable verbose progress logging
local function prg_rom_flash(file, rom_size_kb, debug)
  init_mapper()

  log.section("Programming PRG-ROM")
  log.info("PRG-ROM size", rom_size_kb .. "KB")

  local bank_size = 32 -- MMC1 32KByte bank mode
  local cur_bank = 0
  local num_banks = math.floor(rom_size_kb / bank_size)

  while cur_bank < num_banks do
    if debug then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- select bank to flash
    -- used by mmc1_prgrom_flash_wr to select CHR16 for SUROM/SXROM compatibility
    dict.nes("SET_CUR_BANK", cur_bank)

    -- write the current bank to the mapper register
    dict.nes("NES_MMC1_WR", 0xE000, cur_bank << 1) -- LSBit ignored in 32KB mode

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size, { mapper = mapname, mem_type = "PRGROM" }, false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
  log.success("Done programming PRG-ROM")
end

--[[
 ██████╗██╗  ██╗██████╗       ██████╗  ██████╗ ███╗   ███╗
██╔════╝██║  ██║██╔══██╗      ██╔══██╗██╔═══██╗████╗ ████║
██║     ███████║██████╔╝█████╗██████╔╝██║   ██║██╔████╔██║
██║     ██╔══██║██╔══██╗╚════╝██╔══██╗██║   ██║██║╚██╔╝██║
╚██████╗██║  ██║██║  ██║      ██║  ██║╚██████╔╝██║ ╚═╝ ██║
 ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝      ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝

--]]

--- Read and identify the CHR-ROM flash manufacturer/device ID.
---@return boolean found True when the flash chip is recognized
---@return table device Flash chip information, or an empty table when unknown
local function chr_rom_manf_id()
  local manufacturer_id
  local device_id
  local found
  local device

  init_mapper()

  log.section("Reading CHR-ROM manufacturer/device ID")

  dict.nes("NES_PPU_WR", 0x1555, 0xAA)
  dict.nes("NES_PPU_WR", 0x0AAA, 0x55)
  dict.nes("NES_PPU_WR", 0x1555, 0x90)

  manufacturer_id = dict.nes("NES_PPU_RD", 0x0000)
  chips.display_manufacturer(manufacturer_id)

  device_id = dict.nes("NES_PPU_RD", 0x0001)
  found, device = chips.display_device(manufacturer_id, device_id)

  -- exit software
  dict.nes("NES_PPU_WR", 0x0000, 0xF0)

  return found, device
end

--- Program one byte to CHR flash and poll for completion.
---@param addr integer Address to program, 0x0000-0x0FFF
---@param value integer 8-bit value to write
---@param bank integer Mapper bank value selecting the target flash bank
---@param debug? boolean Enable verbose progress logging
local function chr_rom_flash_byte(addr, value, bank, debug)
  if addr < 0x0000 or addr > 0x0FFF then
    log.error("ERROR! flash write to CHR-ROM", help.hex_0x4(addr), "must be $0000-$0FFF")
    return
  end

  -- set banks for unlock commands
  dict.nes("NES_MMC1_WR", 0xA000, 0x02) -- 4KB bank @ PT0  $2AAA cmd and writes (always write data to PT0)
  -- dict.nes("NES_MMC1_WR", 0xC000, 0x05) -- 4KB bank @ PT1  $5555 cmd fixed (never changed)

  -- send unlock command and write byte
  dict.nes("NES_PPU_WR", 0x1555, 0xAA)
  dict.nes("NES_PPU_WR", 0x0AAA, 0x55)
  dict.nes("NES_PPU_WR", 0x1555, 0xA0)

  -- select desired bank for write
  dict.nes("NES_MMC1_WR", 0xA000, bank) -- 4KB bank @ PT0  $2AAA cmd and writes (always write data to PT0)
  dict.nes("NES_PPU_WR", addr, value)

  local rv = dict.nes("NES_PPU_RD", addr)

  local i = 0

  while rv ~= dict.nes("NES_PPU_RD", addr) do
    rv = dict.nes("NES_PPU_RD", addr)
    i = i + 1
  end

  if debug then
    log.info("Done writing byte,", i .. " naks")
  end

  -- TODO handle timeout for problems

  -- TODO return pass/fail/info
end

--- Dump CHR contents to an already-open output file.
---@param file file* Open binary output file
---@param rom_size_kb integer CHR size in kilobytes
---@param debug? boolean Enable verbose progress logging
local function chr_dump(file, rom_size_kb, debug)
  local kb_per_read = 8
  local num_banks = math.floor(rom_size_kb / kb_per_read)
  local cur_bank = 0
  local addr_base = 0x00 -- $0000

  log.info("CHR size", rom_size_kb .. "KB")

  while cur_bank < num_banks do
    if debug then
      log.point("dump CHR bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    dict.nes("NES_MMC1_WR", 0xA000, cur_bank * 2)     -- 4KB bank at $0000
    dict.nes("NES_MMC1_WR", 0xC000, cur_bank * 2 + 1) -- 4KB bank at $1000

    -- have the device dump a bank worth of data
    dump.dumptofile(file, kb_per_read, { mapper = addr_base, mem_type = "NESPPU_1KB" }, false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--- Program CHR contents from an already-open input file, one bank at a time.
---@param file file* Open binary input file
---@param rom_size_kb integer CHR size in kilobytes
---@param debug? boolean Enable verbose progress logging
local function chr_rom_flash(file, rom_size_kb, debug)
  init_mapper()

  log.section("Programming CHR-ROM")
  log.info("CHR-ROM size", rom_size_kb .. "KB")

  local bank_size = 4 -- MMC1 always write to PT0
  local cur_bank = 0
  local num_banks = math.floor(rom_size_kb / bank_size)

  while cur_bank < num_banks do
    if debug then
      log.point("writing CHR bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- select bank to flash
    dict.nes("SET_CUR_BANK", cur_bank)
    if debug then log.point("get bank", dict.nes("GET_CUR_BANK")) end

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size, { mapper = mapname, mem_type = "CHRROM" }, false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
  log.success("Done programming CHR-ROM")
end

--[[
██████╗ ██████╗  ██████╗       ██████╗  █████╗ ███╗   ███╗
██╔══██╗██╔══██╗██╔════╝       ██╔══██╗██╔══██╗████╗ ████║
██████╔╝██████╔╝██║  ███╗█████╗██████╔╝███████║██╔████╔██║
██╔═══╝ ██╔══██╗██║   ██║╚════╝██╔══██╗██╔══██║██║╚██╔╝██║
██║     ██║  ██║╚██████╔╝      ██║  ██║██║  ██║██║ ╚═╝ ██║
╚═╝     ╚═╝  ╚═╝ ╚═════╝       ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝

--]]

--- Dump PRG-RAM contents to an already-open output file.
---@param file file* Open binary output file
---@param ram_size_kb integer PRG-RAM size in kilobytes
---@param debug? boolean Enable verbose progress logging
local function prg_ram_dump(file, ram_size_kb, debug)
  init_mapper()

  local kb_per_read = 8
  local num_banks = math.floor(ram_size_kb / kb_per_read)
  local addr_base = 0x60 -- $6000
  local cur_bank = 0

  log.info("PRG-RAM size", ram_size_kb .. "KB")

  while cur_bank < num_banks do
    if debug then
      log.point("dumping PRG-RAM bank ", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    dict.nes("NES_MMC1_WR", 0xA000, cur_bank << 2) -- 8KB PRG-RAM bank at $6000
    dict.nes("NES_MMC1_WR", 0xC000, cur_bank << 2) -- 8KB PRG-RAM bank at $6000

    -- have the device dump a bank worth of data
    dump.dumptofile(file, kb_per_read, { mapper = addr_base, mem_type = "NESCPU_PAGE" }, false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--- Write PRG-RAM contents from an already-open input file.
---@param file file* Open binary input file
---@param ram_size_kb integer PRG-RAM size in kilobytes
---@param debug? boolean Enable verbose progress logging
local function prg_ram_write(file, ram_size_kb, debug)
  init_mapper()

  log.info("PRG-RAM size", ram_size_kb .. "KB")

  local bank_size = 8
  local cur_bank = 0
  local num_banks = math.floor(ram_size_kb / bank_size)

  -- enable save ram ??????
  -- dict.nes("NES_MMC1_WR", 0xE000, 0x00)  -- bit4 RAM enable 0-enabled 1-disabled

  -- bit4 (CHR A16) is /CE pin for PRG-RAM on SNROM
  dict.nes("NES_MMC1_WR", 0xA000, 0x00)
  dict.nes("NES_MMC1_WR", 0xC000, 0x00)

  while cur_bank < num_banks do
    if debug then
      log.point("writing PRG-RAM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    dict.nes("NES_MMC1_WR", 0xA000, cur_bank << 2) -- 8KB PRG-RAM bank at $6000
    dict.nes("NES_MMC1_WR", 0xC000, cur_bank << 2) -- 8KB PRG-RAM bank at $6000

    --have the device write a bank worth of data
    flash.write_file(file, bank_size, { mapper = "NOVAR", mem_type = "PRGRAM" }, false)

    cur_bank = cur_bank + 1
  end

  -- for save data safety disable PRG-RAM, and deny writes ??????
  -- dict.nes("NES_MMC1_WR", 0xE000, 0x10)  -- bit4 RAM enable 0-enabled 1-disabled

  -- bit4 (CHR A16) is /CE pin for PRG-RAM on SNROM
  dict.nes("NES_MMC1_WR", 0xA000, 0x10)
  dict.nes("NES_MMC1_WR", 0xC000, 0x10)

  spinner.clear()
  log.success("Done programming PRG-RAM")
end

--- Detect PRG-RAM by writing and reading back a test byte.
---@param debug? boolean Enable verbose progress logging
---@return boolean success True when RAM read/write behavior is detected
local function prg_ram_test(debug)
  local test = true
  local read_value
  local saved_value

  log.section("Detecting PRG-RAM")

  -- enable save ram ??????
  -- dict.nes("NES_MMC1_WR", 0xE000, 0x00)  -- bit4 RAM enable 0-enabled 1-disabled

  -- bit4 (CHR A16) is /CE pin for PRG-RAM on SNROM
  dict.nes("NES_MMC1_WR", 0xA000, 0x00)
  dict.nes("NES_MMC1_WR", 0xC000, 0x00)

  -- save potential battery backed data first
  saved_value = dict.nes("NES_CPU_RD", 0x6000)

  -- try to write and read back
  dict.nes("NES_CPU_WR", 0x6000, saved_value ~ 0xff)
  read_value = dict.nes("NES_CPU_RD", 0x6000)
  if read_value ~= (saved_value ~ 0xff) then
    test = false
  end

  -- put back original value
  dict.nes("NES_CPU_WR", 0x6000, saved_value)
  read_value = dict.nes("NES_CPU_RD", 0x6000)
  if read_value ~= (saved_value) then
    test = false
  end

  -- for save data safety disable PRG-RAM, and deny writes ??????
  -- dict.nes("NES_MMC1_WR", 0xE000, 0x10)  -- bit4 RAM enable 0-enabled 1-disabled

  -- bit4 (CHR A16) is /CE pin for PRG-RAM on SNROM
  dict.nes("NES_MMC1_WR", 0xA000, 0x10)
  dict.nes("NES_MMC1_WR", 0xC000, 0x10)

  if test then
    log.success("PRG-RAM detected")
  else
    log.error("PRG-RAM not detected")
  end

  return test
end

--- Detect PRG-RAM size by writing bank markers and reading them back.
--- Overwrites the test byte in each probed bank.
---@param debug? boolean Enable verbose progress logging
---@return integer size_kb Detected PRG-RAM size in kilobytes, or 0 when detection fails
local function prg_ram_get_size(debug)
  -- PRG-RAM can be maximum 32KB
  -- so we'll check 8 8K banks and see if we can write to each

  local prg_ram_size_kb = 32
  local num_banks = math.floor(prg_ram_size_kb / 8)
  local cur_bank = num_banks - 1

  log.section("Detecting PRG-RAM size")

  -- enable save ram ??????
  -- dict.nes("NES_MMC1_WR", 0xE000, 0x00)  -- bit4 RAM enable 0-enabled 1-disabled

  -- bit4 (CHR A16) is /CE pin for PRG-RAM on SNROM
  dict.nes("NES_MMC1_WR", 0xA000, 0x00)
  dict.nes("NES_MMC1_WR", 0xC000, 0x00)

  -- write to banks backwards
  while cur_bank >= 0 do
    if debug then
      log.point("trying to write to PRG-RAM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Writing", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    dict.nes("NES_MMC1_WR", 0xA000, cur_bank << 2) -- 8KB PRG-RAM bank at $6000
    dict.nes("NES_MMC1_WR", 0xC000, cur_bank << 2) -- 8KB PRG-RAM bank at $6000

    -- write data
    dict.nes("NES_CPU_WR", 0x6000, cur_bank)

    cur_bank = cur_bank - 1
  end

  spinner.clear()

  -- read back only last bank
  dict.nes("NES_MMC1_WR", 0xA000, (num_banks - 1) << 2) -- 8KB PRG-RAM bank at $6000
  dict.nes("NES_MMC1_WR", 0xC000, (num_banks - 1) << 2) -- 8KB PRG-RAM bank at $6000
  prg_ram_size_kb = (dict.nes("NES_CPU_RD", 0x6000) + 1) * 8

  -- for save data safety disable PRG-RAM, and deny writes ??????
  -- dict.nes("NES_MMC1_WR", 0xE000, 0x10)  -- bit4 RAM enable 0-enabled 1-disabled

  -- bit4 (CHR A16) is /CE pin for PRG-RAM on SNROM
  dict.nes("NES_MMC1_WR", 0xA000, 0x10)
  dict.nes("NES_MMC1_WR", 0xC000, 0x10)

  if prg_ram_size_kb >= 0 and prg_ram_size_kb <= 32 then
    log.success("PRG-RAM size detected", prg_ram_size_kb .. "KB")
    return prg_ram_size_kb
  else
    log.warning("Failed to detect PRG-RAM size")
    return 0
  end
end

--- Exercise PRG-RAM with an LFSR pattern and compare the dumped result.
--- Overwrites PRG-RAM contents with the test pattern.
---@param wram_size_kb integer PRG-RAM size in kilobytes
---@param retroprog_id string|integer Identifier used in the temporary dump filename
---@param debug? boolean Enable verbose compare/progress logging
---@return boolean success True when the PRG-RAM dump matches the expected LFSR data
local function prg_ram_exercise(wram_size_kb, retroprog_id, debug)
  dict.stuff("RESET_LFSR") -- sets it to 1

  local cur_bank = 0
  local num_banks = math.floor(wram_size_kb / 8)

  log.section("Exercising PRG-RAM")
  log.info("PRG-RAM size", wram_size_kb .. "KB")

  -- enable save ram ??????
  -- dict.nes("NES_MMC1_WR", 0xE000, 0x00)  -- bit4 RAM enable 0-enabled 1-disabled

  -- bit4 (CHR A16) is /CE pin for PRG-RAM on SNROM
  dict.nes("NES_MMC1_WR", 0xA000, 0x00)
  dict.nes("NES_MMC1_WR", 0xC000, 0x00)

  -- write random data to all banks
  log.point("Writing random data to PRG-RAM")
  while cur_bank < num_banks do
    if debug then
      log.point("init PRG-RAM 8K bank", cur_bank, "of", num_banks - 1)
    end

    -- set bank
    dict.nes("NES_MMC1_WR", 0xA000, cur_bank << 2) -- 8KB bank at $6000
    dict.nes("NES_MMC1_WR", 0xC000, cur_bank << 2) -- 8KB bank at $6000

    -- write random data
    local addr = 0x6000
    while addr < 0x8000 do
      dict.nes("CPU_PAGE_WR_LFSR", addr)
      addr = addr + 256
    end
    cur_bank = cur_bank + 1
  end

  -- open file
  local filename = opts.write_path .. "./ignore/nes_prg_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))

  -- dump PRG-RAM
  log.point("Dumping PRG-RAM")
  prg_ram_dump(file, wram_size_kb, false)

  -- close file
  assert(file:close())

  -- for save data safety disable PRG-RAM, and deny writes ??????
  -- dict.nes("NES_MMC1_WR", 0xE000, 0x10)  -- bit4 RAM enable 0-enabled 1-disabled

  -- bit4 (CHR A16) is /CE pin for PRG-RAM on SNROM
  dict.nes("NES_MMC1_WR", 0xA000, 0x10)
  dict.nes("NES_MMC1_WR", 0xC000, 0x10)

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "./ignore/lfsr_32KB.bin"

  -- compare the flash file vs post dump file
  if files.compare(filename, goodfile, false, debug) then
    log.success("PRG-RAM test passed")
    return true
  else
    log.error("PRG-RAM test failed")
    return false
  end
end

--[[
 ██████╗██╗  ██╗██████╗       ██████╗  █████╗ ███╗   ███╗
██╔════╝██║  ██║██╔══██╗      ██╔══██╗██╔══██╗████╗ ████║
██║     ███████║██████╔╝█████╗██████╔╝███████║██╔████╔██║
██║     ██╔══██║██╔══██╗╚════╝██╔══██╗██╔══██║██║╚██╔╝██║
╚██████╗██║  ██║██║  ██║      ██║  ██║██║  ██║██║ ╚═╝ ██║
 ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝      ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝

--]]

--- Detect CHR-RAM size by writing bank markers and reading them back.
--- Overwrites the test byte in each probed bank.
---@param debug? boolean Enable verbose progress logging
---@return integer size_kb Detected CHR-RAM size in kilobytes, or 0 when detection fails
local function chr_ram_get_size(debug)
  -- CHR-RAM can be maximum 32KB
  -- so we'll check 8 4K banks and see if we can write to each

  local chr_ram_size_kb = 32
  local num_banks = math.floor(chr_ram_size_kb / 4)
  local cur_bank = num_banks - 1

  log.section("Detecting CHR-RAM size")

  -- write to banks backwards
  while cur_bank >= 0 do
    if debug then
      log.point("trying to write to CHR-RAM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Writing", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    dict.nes("NES_MMC1_WR", 0xA000, cur_bank * 2)     -- 4KB bank at $0000
    dict.nes("NES_MMC1_WR", 0xC000, cur_bank * 2 + 1) -- 4KB bank at $1000

    -- write data
    dict.nes("NES_PPU_WR", 0x0000, cur_bank)

    cur_bank = cur_bank - 1
  end

  spinner.clear()

  -- read back only last bank
  dict.nes("NES_MMC1_WR", 0xA000, num_banks * 2)     -- 4KB bank at $0000
  dict.nes("NES_MMC1_WR", 0xC000, num_banks * 2 + 1) -- 4KB bank at $1000
  chr_ram_size_kb = (dict.nes("NES_PPU_RD", 0x0000) + 1) * 8

  if chr_ram_size_kb >= 0 and chr_ram_size_kb <= 32 then
    log.success("CHR-RAM size detected", chr_ram_size_kb .. "KB")
    return chr_ram_size_kb
  else
    log.warning("Failed to detect CHR-RAM size")
    return 0
  end
end

--- Exercise CHR-RAM with an LFSR pattern and compare the dumped result.
--- Overwrites CHR-RAM contents with the test pattern.
---@param chr_ram_size_kb integer CHR-RAM size in kilobytes
---@param retroprog_id string|integer Identifier used in the temporary dump filename
---@param debug? boolean Enable verbose compare/progress logging
---@return boolean success True when the CHR-RAM dump matches the expected LFSR data
local function chr_ram_exercise(chr_ram_size_kb, retroprog_id, debug)
  dict.stuff("RESET_LFSR") -- sets it to 1

  local cur_bank = 0
  local num_banks = math.floor(chr_ram_size_kb / 8)

  log.section("Exercising CHR-RAM")
  log.info("CHR-RAM size", chr_ram_size_kb .. "KB")

  -- write random data to all banks
  log.point("Writing random data to CHR-RAM")
  while cur_bank < num_banks do
    if debug then
      log.point("init CHR-RAM 8K bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Writing", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    dict.nes("NES_MMC1_WR", 0xA000, cur_bank * 2)     -- 4KB bank at $0000
    dict.nes("NES_MMC1_WR", 0xC000, cur_bank * 2 + 1) -- 4KB bank at $1000

    -- write data
    local addr = 0x0000
    while addr < 0x2000 do
      dict.nes("PPU_PAGE_WR_LFSR", addr)
      addr = addr + 256
    end

    cur_bank = cur_bank + 1
  end

  spinner.clear()

  -- dump CHR-RAM
  local filename = opts.write_path .. "./ignore/nes_chr_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))
  log.point("Dumping CHR-RAM")
  chr_dump(file, chr_ram_size_kb, debug)

  -- close the file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "./ignore/lfsr_32KB.bin"

  -- compare the flash file vs post dump file
  if files.compare(filename, goodfile, false, debug) then
    log.success("CHR-RAM test passed")
    return true
  else
    log.error("CHR-RAM test failed")
    return false
  end
end

--[[
██████╗ ██████╗  ██████╗  ██████╗███████╗███████╗███████╗
██╔══██╗██╔══██╗██╔═══██╗██╔════╝██╔════╝██╔════╝██╔════╝
██████╔╝██████╔╝██║   ██║██║     █████╗  ███████╗███████╗
██╔═══╝ ██╔══██╗██║   ██║██║     ██╔══╝  ╚════██║╚════██║
██║     ██║  ██║╚██████╔╝╚██████╗███████╗███████║███████║
╚═╝     ╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚══════╝╚══════╝╚══════╝

--]]

--- Process all requested operations for this cartridge board/mapper.
---@param process_opts table Parsed operation options from the main application
---@param console_opts table Console/cartridge size options
---@return false|nil result False on explicitly reported failure; otherwise no value
local function process(process_opts, console_opts)
  -- some local variables
  local rv               = nil
  local file
  local chr_ram_detected = false
  local chr_ram_size_kb  = 0

  -- process options
  local DEBUG            = process_opts.debug
  local retroprog_id     = process_opts.retroprog_id
  local do_test          = process_opts.do_test
  local do_erase         = process_opts.do_erase
  local do_rom_write     = process_opts.do_rom_write
  local do_verify        = process_opts.do_verify
  local do_rom_dump      = process_opts.do_rom_dump
  local do_ram_dump      = process_opts.do_ram_dump
  local do_ram_write     = process_opts.do_ram_write
  local nes_file         = process_opts.nes_file
  local rom_write_file   = process_opts.rom_write_file
  local verify_file      = process_opts.verify_file
  local rom_dump_file    = process_opts.rom_dump_file
  local ram_dump_file    = process_opts.ram_dump_file
  local ram_write_file   = process_opts.ram_write_file
  local options          = process_opts.additional_opts

  -- console options
  local prg_size_kb      = console_opts.prg_rom_size_kb
  local chr_size_kb      = console_opts.chr_rom_size_kb
  local wram_size_kb     = console_opts.wram_size_kb

  -- Initialize device i/o
  dict.io("IO_RESET")
  dict.io("NES_INIT")

  -- put mapper in known state
  init_mapper()

  --[[
  888888 888888 .dP"Y8 888888
    88   88__   `Ybo."   88
    88   88""   o.`Y8b   88
    88   888888 8bodP'   88
  --]]

  -- test cart
  if do_test then
    log.section("Testing", mapname)

    -- verify mirroring is behaving as expected
    rv = mirror_test(DEBUG)
    if not rv then return false end

    chr_ram_detected = nes.ppu_ram_sense(0x1000, DEBUG)

    -- CHR-RAM tests
    if chr_ram_detected then
      -- test CHR-RAM banking and try to detect size
      chr_ram_size_kb = chr_ram_get_size(DEBUG)

      -- test CHR-RAM
      if chr_ram_size_kb ~= 0 then
        rv = chr_ram_exercise(chr_ram_size_kb, retroprog_id, DEBUG)
        -- exit script if test fails
        if not rv then return end
      end
    else
      if chr_ram_size_kb == 0 then
        log.error("CHR-RAM not detected")
        return
      end
    end

    -- attempt to read PRG-ROM flash ID
    if options.force_flash_test or (do_rom_write and prg_size_kb ~= 0) then
      rv = prg_rom_manf_id()
      if not rv then
        if do_rom_write then
          log.error("Couldn't identify flash chip")
          return false
        else
          log.warning("Couldn't identify flash chip")
        end
      end
    end

    -- attempt to read CHR-ROM flash ID
    if options.force_flash_test or (do_rom_write and chr_size_kb ~= 0) then
      rv = chr_rom_manf_id()
      if not rv then
        if do_rom_write then
          log.error("Couldn't identify flash chip")
          return false
        else
          log.warning("Couldn't identify flash chip")
        end
      end
    end

    -- PRG-RAM tests
    rv = prg_ram_test(DEBUG)
    if rv == true then
      if options.force_wram_test then
        log.print()
        log.warning("Flag 'force_wram_test' enabled")
      end
      if options.force_wram_test or nes.header.is_valid then
        if not options.force_wram_test and nes.header.has_battery then
          log.print()
          log.warning("Can't exercise PRG-RAM because NES ROM has battery backed data")
        else
          if wram_size_kb == 0 then
            wram_size_kb = prg_ram_get_size(DEBUG)
          end
          if wram_size_kb ~= 0 then
            rv = prg_ram_exercise(wram_size_kb, retroprog_id, DEBUG)
            -- exit script if test fails
            if not rv then return end
          end
        end
      else
        log.warning("Can't exercise PRG-RAM because data could be battery backed")
      end
    end
  end

  --[[
88""Yb    db    8b    d8     8888b.  88   88 8b    d8 88""Yb
88__dP   dPYb   88b  d88      8I  Yb 88   88 88b  d88 88__dP
88"Yb   dP__Yb  88YbdP88      8I  dY Y8   8P 88YbdP88 88"""
88  Yb dP""""Yb 88 YY 88     8888Y"  `YbodP' 88 YY 88 88
--]]

  -- dump cart RAM to file
  if do_ram_dump then
    init_mapper()

    log.section("Dumping PRG-RAM")

    -- open file
    file = assert(io.open(ram_dump_file.filename, "wb"))

    -- dump cart to file
    if wram_size_kb ~= 0 then
      time.start()
      prg_ram_dump(file, wram_size_kb, DEBUG)
      time.report(wram_size_kb)
      log.success("PRG-RAM dumping done")
    else
      log.error("PRG-RAM size not provided")
      return
    end

    -- close file
    assert(file:close())
  end

  --[[
88""Yb    db    8b    d8     Yb        dP 88""Yb 88 888888 888888
88__dP   dPYb   88b  d88      Yb  db  dP  88__dP 88   88   88__
88"Yb   dP__Yb  88YbdP88       YbdPYbdP   88"Yb  88   88   88""
88  Yb dP""""Yb 88 YY 88        YP  YP    88  Yb 88   88   888888
--]]

  -- write file to the cart RAM
  if do_ram_write then
    log.section("Programming PRG-RAM")

    -- open file
    file = assert(io.open(ram_write_file.filename, "rb"))

    -- flash cart
    if wram_size_kb ~= 0 then
      time.start()
      prg_ram_write(file, wram_size_kb, DEBUG)
      time.report(wram_size_kb)
    else
      log.error("PRG-RAM size not provided")
      return
    end

    -- close file
    assert(file:close())
  end

  --[[
  88""Yb  dP"Yb  8b    d8     8888b.  88   88 8b    d8 88""Yb
  88__dP dP   Yb 88b  d88      8I  Yb 88   88 88b  d88 88__dP
  88"Yb  Yb   dP 88YbdP88      8I  dY Y8   8P 88YbdP88 88"""
  88  Yb  YbodP  88 YY 88     8888Y"  `YbodP' 88 YY 88 88
  --]]

  -- dump cart ROM to file
  if do_rom_dump then
    init_mapper()

    -- open file
    file = assert(io.open(rom_dump_file.filename, "wb"))

    -- create header: pass open & empty file & rom sizes
    if rom_dump_file.ext == "nes" then
      create_header(file, prg_size_kb, chr_size_kb)
    end

    -- dump cart to file
    if prg_size_kb ~= 0 then
      log.section("Dumping PRG-ROM")
      time.start()
      prg_rom_dump(file, prg_size_kb, DEBUG)
      time.report(prg_size_kb)
      log.success("PRG-ROM dumping done")
    end

    if chr_size_kb ~= 0 then
      log.section("Dumping CHR-ROM")
      time.start()
      chr_dump(file, chr_size_kb, DEBUG)
      time.report(chr_size_kb)
      log.success("CHR-ROM dumping done")
    end

    -- close file
    assert(file:close())
  end

  --[[
  88""Yb  dP"Yb  8b    d8     888888 88""Yb    db    .dP"Y8 888888
  88__dP dP   Yb 88b  d88     88__   88__dP   dPYb   `Ybo." 88__
  88"Yb  Yb   dP 88YbdP88     88""   88"Yb   dP__Yb  o.`Y8b 88""
  88  Yb  YbodP  88 YY 88     888888 88  Yb dP""""Yb 8bodP' 888888
  --]]

  -- erase the cart
  if do_erase then
    local i = 0

    -- erase PRG-ROM only if needed
    if prg_size_kb ~= 0 then
      init_mapper()
      log.section("Erasing PRG-ROM")
      time.start()
      dict.nes("NES_CPU_WR", 0xD555, 0xAA)
      dict.nes("NES_CPU_WR", 0xAAAA, 0x55)
      dict.nes("NES_CPU_WR", 0xD555, 0x80)
      dict.nes("NES_CPU_WR", 0xD555, 0xAA)
      dict.nes("NES_CPU_WR", 0xAAAA, 0x55)
      dict.nes("NES_CPU_WR", 0xD555, 0x10)

      -- TODO create some function to pass the read value
      -- that's smart enough to figure out if the board is actually erasing or not
      rv = dict.nes("NES_CPU_RD", 0x8000)
      while rv ~= dict.nes("NES_CPU_RD", 0x8000) do
        spinner.update("Erasing")
        rv = dict.nes("NES_CPU_RD", 0x8000)
        i = i + 1
      end
      spinner.clear()
      log.success("Done erasing PRG-ROM", i .. " naks")
      time.report(prg_size_kb)
    end

    -- erase CHR-ROM only if needed
    if chr_size_kb ~= 0 then
      init_mapper()
      log.section("Erasing CHR-ROM")
      time.start()
      dict.nes("NES_PPU_WR", 0x1555, 0xAA)
      dict.nes("NES_PPU_WR", 0x0AAA, 0x55)
      dict.nes("NES_PPU_WR", 0x1555, 0x80)
      dict.nes("NES_PPU_WR", 0x1555, 0xAA)
      dict.nes("NES_PPU_WR", 0x0AAA, 0x55)
      dict.nes("NES_PPU_WR", 0x1555, 0x10)

      -- TODO create some function to pass the read value
      -- that's smart enough to figure out if the board is actually erasing or not
      i = 0
      rv = dict.nes("NES_PPU_RD", 0x0000)
      while rv ~= dict.nes("NES_PPU_RD", 0x0000) do
        spinner.update("Erasing")
        rv = dict.nes("NES_PPU_RD", 0x0000)
        i = i + 1
      end
      spinner.clear()
      log.success("Done erasing CHR-ROM", i .. " naks")
      time.report(chr_size_kb)
    end
  end

  --[[
  88""Yb  dP"Yb  8b    d8     Yb        dP 88""Yb 88 888888 888888
  88__dP dP   Yb 88b  d88      Yb  db  dP  88__dP 88   88   88__
  88"Yb  Yb   dP 88YbdP88       YbdPYbdP   88"Yb  88   88   88""
  88  Yb  YbodP  88 YY 88        YP  YP    88  Yb 88   88   888888
  --]]

  -- program file to the cart
  if do_rom_write then
    -- open file
    file = assert(io.open(rom_write_file.filename, "rb"))

    -- flash cart
    if prg_size_kb ~= 0 then
      time.start()
      prg_rom_flash(file, prg_size_kb, DEBUG)
      time.report(prg_size_kb)
    end

    if chr_size_kb ~= 0 then
      time.start()
      chr_rom_flash(file, chr_size_kb, DEBUG)
      time.report(chr_size_kb)
    end

    -- close file
    assert(file:close())
  end

  --[[
  Yb    dP 888888 88""Yb 88 888888 Yb  dP
   Yb  dP  88__   88__dP 88 88__    YbdP
    YbdP   88""   88"Yb  88 88""     8P
     YP    888888 88  Yb 88 88      dP
  --]]

  -- verify what we just flashed
  if do_verify then
    init_mapper()

    -- open file
    file = assert(io.open(verify_file.filename, "wb"))

    -- dump cart to file
    if prg_size_kb ~= 0 then
      log.section("Dumping PRG-ROM")
      time.start()
      prg_rom_dump(file, prg_size_kb, DEBUG)
      time.report(prg_size_kb)
      log.success("PRG-ROM dumping done")
    end

    if chr_size_kb ~= 0 then
      log.section("Dumping CHR-ROM")
      time.start()
      chr_dump(file, chr_size_kb, DEBUG)
      time.report(chr_size_kb)
      log.success("CHR-ROM dumping done")
    end

    -- close file
    assert(file:close())

    -- compare the flash file vs post dump file
    log.section("Verifying data")
    if files.compare(verify_file.filename, rom_write_file.filename, true, true) then
      log.success("Flash successfully verified")
    else
      log.error("Flash verification did not match")
    end
  end

  dict.io("IO_RESET")
end

-- global variables so other modules can use them

-- call functions desired to run when script is called/imported

-- functions other modules are able to call
mmc1.process = process

-- return the module's table
return mmc1
