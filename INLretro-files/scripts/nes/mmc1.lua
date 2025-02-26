
-- create the module's table
local mmc1 = {}

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

local function create_header(file, prgKB, chrKB)
  -- write_header(file, prgKB, chrKB, mapper, mirroring)
  nes.write_header(file, prgKB, chrKB, op_buffer[mapname], 0)
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

-- read PRG-ROM flash ID
local function prg_rom_manf_id()

  local manufacturer_id
  local device_id
  local device_test

  init_mapper()

  log.section("Reading PRG-ROM manufacturer/device ID")

  dict.nes("NES_CPU_WR", 0xD555, 0xAA)
  dict.nes("NES_CPU_WR", 0xAAAA, 0x55)
  dict.nes("NES_CPU_WR", 0xD555, 0x90)

  manufacturer_id = dict.nes("NES_CPU_RD", 0x8000)
  chips.display_manufacturer(manufacturer_id)

  device_id = dict.nes("NES_CPU_RD", 0x8001)
  device_test = chips.display_device(manufacturer_id, device_id)

  -- exit software
  dict.nes("NES_CPU_WR", 0x8000, 0xF0)

  if device_test == false then
    return false
  else
    return true
  end

end

-- write a single byte to PRG-ROM flash
-- PRE: assumes mapper is initialized and bank is selected as prescribed in mapper_init
-- REQ: addr must be in the first bank $8000-FFFF
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
  dict.nes("NES_CPU_WR", 0xD555, 0xAA)  --this will reset the MMC1..?, 
            --but not if it was blocked by a previous write
  dict.nes("NES_CPU_WR", 0xAAAA, 0x55)  --blocked
  dict.nes("NES_CPU_WR", 0xD555, 0xA0)  --blocked
  dict.nes("NES_CPU_WR", addr, value) --blocked

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

-- dump PRG-ROM
local function prg_rom_dump(file, rom_size_KB, debug)

  -- PRG-ROM dump 32KB at a time in 32KB bank mode
  local KB_per_read = 32
  local num_banks = math.floor(rom_size_KB / KB_per_read)
  local cur_bank = 0
  local addr_base = 0x80  -- $8000

  log.info("PRG-ROM size", rom_size_KB .. "KB")

  while cur_bank < num_banks do

    if debug then
      log.point("dumping PRG bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks-1)
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
    dict.nes("NES_MMC1_WR", 0xE000, cur_bank << 1)  -- LSBit ignored in 32KB mode

    -- dump a bank worth of data
    dump.dumptofile(file, KB_per_read, addr_base, "NESCPU_PAGE", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()

end

-- host flash one bank at a time
local function prg_rom_flash(file, rom_size_KB, debug)

  init_mapper()

  log.section("Programming PRG-ROM")
  log.info("PRG-ROM size", rom_size_KB .. "KB")

  local bank_size = 32 -- MMC1 32KByte bank mode
  local cur_bank = 0
  local num_banks = math.floor(rom_size_KB / bank_size)

  while cur_bank < num_banks do

    if debug then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks-1)
    end

    -- select bank to flash
    -- used by mmc1_prgrom_flash_wr to select CHR16 for SUROM/SXROM compatibility
    dict.nes("SET_CUR_BANK", cur_bank)

    -- write the current bank to the mapper register
    dict.nes("NES_MMC1_WR", 0xE000, cur_bank << 1)  -- LSBit ignored in 32KB mode

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size, mapname, "PRGROM", false)

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

-- read CHR-ROM flash ID
local function chr_rom_manf_id()

  local manufacturer_id
  local device_id
  local device_test

  init_mapper()

  log.section("Reading CHR-ROM manufacturer/device ID")

  dict.nes("NES_PPU_WR", 0x1555, 0xAA)
  dict.nes("NES_PPU_WR", 0x0AAA, 0x55)
  dict.nes("NES_PPU_WR", 0x1555, 0x90)

  manufacturer_id = dict.nes("NES_PPU_RD", 0x0000)
  chips.display_manufacturer(manufacturer_id)

  device_id = dict.nes("NES_PPU_RD", 0x0001)
  device_test = chips.display_device(manufacturer_id, device_id)

  -- exit software
  dict.nes("NES_PPU_WR", 0x0000, 0xF0)

  if device_test == false then
    return false
  else
    return true
  end

end

-- write a single byte to CHR-ROM flash
-- PRE: assumes mapper is initialized and bank is selected as prescribed in mapper_init
-- REQ: addr must be in the first bank $0000-0FFF
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

-- dump CHR-ROM/RAM
local function chr_dump(file, rom_size_KB, debug)

  local KB_per_read = 8
  local num_banks = math.floor(rom_size_KB / KB_per_read)
  local cur_bank = 0
  local addr_base = 0x00  -- $0000

  log.info("CHR size", rom_size_KB .. "KB")

  while cur_bank < num_banks do

    if debug then
      log.point("dump CHR bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks-1)
    end

    dict.nes("NES_MMC1_WR", 0xA000, cur_bank*2)   -- 4KB bank at $0000
    dict.nes("NES_MMC1_WR", 0xC000, cur_bank*2+1) -- 4KB bank at $1000

    -- have the device dump a bank worth of data
    dump.dumptofile( file, KB_per_read, addr_base, "NESPPU_1KB", false )

    cur_bank = cur_bank + 1
  end

  spinner.clear()

end

-- host flash one bank at a time
local function chr_rom_flash(file, rom_size_KB, debug)

  init_mapper()

  log.section("Programming CHR-ROM")
  log.info("CHR-ROM size", rom_size_KB .. "KB")

  local bank_size = 4 -- MMC1 always write to PT0
  local cur_bank = 0
  local num_banks = math.floor(rom_size_KB / bank_size)

  while cur_bank < num_banks do

    if debug then
      log.point("writing CHR bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks-1)
    end

    -- select bank to flash
    dict.nes("SET_CUR_BANK", cur_bank)
    if debug then log.point("get bank", dict.nes("GET_CUR_BANK")) end

    -- have the device write a bank worth of data
    flash.write_file( file, bank_size, mapname, "CHRROM", false )

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

-- dump the PRG-RAM, assumes the PRG-RAM was enabled as desired prior to calling
local function prg_ram_dump(file, ram_size_KB, debug)

  init_mapper()

  local KB_per_read = 8
  local num_banks = math.floor(ram_size_KB / KB_per_read)
  local addr_base = 0x60  -- $6000
  local cur_bank = 0

  log.info("PRG-RAM size", ram_size_KB .. "KB")

  while cur_bank < num_banks do

    if debug then
      log.point("dumping PRG-RAM bank ", cur_bank, "of", num_banks-1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks-1)
    end

    -- set bank
    dict.nes("NES_MMC1_WR", 0xA000, cur_bank << 2) -- 8KB PRG-RAM bank at $6000
    dict.nes("NES_MMC1_WR", 0xC000, cur_bank << 2) -- 8KB PRG-RAM bank at $6000

    -- have the device dump a bank worth of data
    dump.dumptofile(file, KB_per_read, addr_base, "NESCPU_PAGE", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()

end

-- host write one bank at a time
local function prg_ram_write(file, ram_size_KB, debug)

  init_mapper()

  log.info("PRG-RAM size", ram_size_KB .. "KB")

  local bank_size = 8
  local cur_bank = 0
  local num_banks = math.floor(ram_size_KB / bank_size)

  -- enable save ram ??????
  -- dict.nes("NES_MMC1_WR", 0xE000, 0x00)  -- bit4 RAM enable 0-enabled 1-disabled

  -- bit4 (CHR A16) is /CE pin for PRG-RAM on SNROM
  dict.nes("NES_MMC1_WR", 0xA000, 0x00)
  dict.nes("NES_MMC1_WR", 0xC000, 0x00)

  while cur_bank < num_banks do

    if debug then
      log.point("writing PRG-RAM bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks-1)
    end

    -- set bank
    dict.nes("NES_MMC1_WR", 0xA000, cur_bank << 2) -- 8KB PRG-RAM bank at $6000
    dict.nes("NES_MMC1_WR", 0xC000, cur_bank << 2) -- 8KB PRG-RAM bank at $6000

    --have the device write a bank worth of data
    flash.write_file(file, bank_size, "NOVAR", "PRGRAM", false )

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

-- try to detect if PRG-RAM is present
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

-- try to detect PRG-RAM size
local function prg_ram_get_size(debug)

  -- PRG-RAM can be maximum 32KB
  -- so we'll check 8 8K banks and see if we can write to each

  local prg_ram_size = 32
  local num_banks = math.floor(prg_ram_size / 8)
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
      log.point("trying to write to PRG-RAM bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Writing", cur_bank, "/", num_banks-1)
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
  prg_ram_size = ( dict.nes("NES_CPU_RD", 0x6000) + 1 ) * 8

  -- for save data safety disable PRG-RAM, and deny writes ??????
  -- dict.nes("NES_MMC1_WR", 0xE000, 0x10)  -- bit4 RAM enable 0-enabled 1-disabled

  -- bit4 (CHR A16) is /CE pin for PRG-RAM on SNROM
  dict.nes("NES_MMC1_WR", 0xA000, 0x10)
  dict.nes("NES_MMC1_WR", 0xC000, 0x10)

  if prg_ram_size >= 0 and prg_ram_size <= 32 then
    log.success("PRG-RAM size detected", prg_ram_size .. "KB")
    return prg_ram_size
  else
    log.warning("Failed to detect PRG-RAM size")
    return 0
  end
end

local function prg_ram_exercise(wram_size, retroprog_id, debug)

  dict.stuff("RESET_LFSR")  -- sets it to 1

  local cur_bank = 0
  local num_banks = math.floor(wram_size / 8)

  log.section("Exercising PRG-RAM")
  log.info("PRG-RAM size", wram_size .. "KB")

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
  local filename = "ignore/nes_prg_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))

  -- dump PRG-RAM
  log.point("Dumping PRG-RAM")
  prg_ram_dump(file, wram_size, false)

  -- close file
  assert(file:close())

  -- for save data safety disable PRG-RAM, and deny writes ??????
  -- dict.nes("NES_MMC1_WR", 0xE000, 0x10)  -- bit4 RAM enable 0-enabled 1-disabled

  -- bit4 (CHR A16) is /CE pin for PRG-RAM on SNROM
  dict.nes("NES_MMC1_WR", 0xA000, 0x10)
  dict.nes("NES_MMC1_WR", 0xC000, 0x10)

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = "ignore/lfsr_32KB.bin"

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

-- try to detect CHR-RAM size
local function chr_ram_get_size(debug)

  -- CHR-RAM can be maximum 32KB
  -- so we'll check 8 4K banks and see if we can write to each

  local chr_ram_size = 32
  local num_banks = math.floor(chr_ram_size / 4)
  local cur_bank = num_banks - 1

  log.section("Detecting CHR-RAM size")

  -- write to banks backwards
  while cur_bank >= 0 do

    if debug then
      log.point("trying to write to CHR-RAM bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Writing", cur_bank, "/", num_banks-1)
    end

    -- set bank
    dict.nes("NES_MMC1_WR", 0xA000, cur_bank*2) -- 4KB bank at $0000
    dict.nes("NES_MMC1_WR", 0xC000, cur_bank*2+1) -- 4KB bank at $1000

    -- write data
    dict.nes("NES_PPU_WR", 0x0000, cur_bank)

    cur_bank = cur_bank - 1
  end

  spinner.clear()

  -- read back only last bank
  dict.nes("NES_MMC1_WR", 0xA000, num_banks*2) -- 4KB bank at $0000
  dict.nes("NES_MMC1_WR", 0xC000, num_banks*2+1) -- 4KB bank at $1000
  chr_ram_size = ( dict.nes("NES_PPU_RD", 0x0000) + 1 ) * 8

  if chr_ram_size >= 0 and chr_ram_size <= 32 then
    log.success("CHR-RAM size detected", chr_ram_size .. "KB")
    return chr_ram_size
  else
    log.warning("Failed to detect CHR-RAM size")
    return 0
  end
end

local function chr_ram_exercise(chr_ram_size, retroprog_id, debug)

  dict.stuff("RESET_LFSR")  -- sets it to 1

  local cur_bank = 0
  local num_banks = math.floor(chr_ram_size / 8)

  log.section("Exercising CHR-RAM")
  log.info("CHR-RAM size", chr_ram_size .. "KB")

  -- write random data to all banks
  log.point("Writing random data to CHR-RAM")
  while cur_bank < num_banks do

    if debug then
      log.point("init CHR-RAM 8K bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Writing", cur_bank, "/", num_banks-1)
    end

    -- set bank
    dict.nes("NES_MMC1_WR", 0xA000, cur_bank*2) -- 4KB bank at $0000
    dict.nes("NES_MMC1_WR", 0xC000, cur_bank*2+1) -- 4KB bank at $1000

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
  local filename = "ignore/nes_chr_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))
  log.point("Dumping CHR-RAM")
  chr_dump(file, chr_ram_size, debug)

  -- close the file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = "ignore/lfsr_32KB.bin"

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

-- Cart should be in reset state upon calling this function
-- this function processes all user requests for this specific board/mapper
local function process(process_opts, console_opts)

  -- some local variables
  local rv = nil
  local file
  local chr_ram_detected = false
  local chr_ram_size = 0

  -- process options
  local DEBUG           = process_opts.debug
  local retroprog_id    = process_opts.retroprog_id
  local do_test         = process_opts.do_test
  local do_erase        = process_opts.do_erase
  local do_rom_write    = process_opts.do_rom_write
  local do_verify       = process_opts.do_verify
  local do_rom_dump     = process_opts.do_rom_dump
  local do_ram_dump     = process_opts.do_ram_dump
  local do_ram_write    = process_opts.do_ram_write
  local nes_file        = process_opts.nes_file
  local rom_write_file  = process_opts.rom_write_file
  local verify_file     = process_opts.verify_file
  local rom_dump_file   = process_opts.rom_dump_file
  local ram_dump_file   = process_opts.ram_dump_file
  local ram_write_file  = process_opts.ram_write_file
  local options         = process_opts.additional_opts

  -- console options
  local prg_size        = console_opts.prg_rom_size_kb
  local chr_size        = console_opts.chr_rom_size_kb
  local wram_size       = console_opts.wram_size_kb

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

    -- attempt to read PRG-ROM flash ID
    if options.force_flash_test or (do_rom_write and prg_size ~= 0) then
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
    if options.force_flash_test or (do_rom_write and chr_size ~= 0) then
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
      if options.force_wram_test or nes.header.isValid then
        if not options.force_wram_test and nes.header.hasBattery ~= 0 then
          log.print()
          log.warning("Can't exercise PRG-RAM because NES ROM has battery backed data")
        else
          if wram_size == 0 then
            wram_size = prg_ram_get_size(DEBUG)
          end
          if wram_size ~= 0 then
            rv = prg_ram_exercise(wram_size, retroprog_id, DEBUG)
            -- exit script if test fails
            if not rv then return end
          end
        end
      else
        log.warning("Can't exercise PRG-RAM because data could be battery backed")
      end
    end

    -- CHR-RAM tests
    if chr_ram_detected then
      -- test CHR-RAM banking and try to detect size
      chr_ram_size = chr_ram_get_size(DEBUG)

      -- test CHR-RAM
      if chr_ram_size ~= 0 then
        rv = chr_ram_exercise(chr_ram_size, retroprog_id, DEBUG)
        -- exit script if test fails
        if not rv then return end
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
    if wram_size ~= 0 then
      time.start()
      prg_ram_dump(file, wram_size, DEBUG)
      time.report(wram_size)
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
    if wram_size ~= 0 then
      time.start()
      prg_ram_write(file, wram_size, DEBUG)
      time.report(wram_size)
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
      create_header(file, prg_size, chr_size)
    end

    -- dump cart to file
    if prg_size ~= 0 then
      log.section("Dumping PRG-ROM")
      time.start()
      prg_rom_dump(file, prg_size, DEBUG)
      time.report(prg_size)
      log.success("PRG-ROM dumping done")
    end

    if chr_size ~= 0 then
      log.section("Dumping CHR-ROM")
      time.start()
      chr_dump(file, chr_size, DEBUG)
      time.report(chr_size)
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
    if prg_size ~= 0 then
      init_mapper()
      log.section("Erasing PRG-ROM")
      dict.nes("NES_CPU_WR", 0xD555, 0xAA)
      dict.nes("NES_CPU_WR", 0xAAAA, 0x55)
      dict.nes("NES_CPU_WR", 0xD555, 0x80)
      dict.nes("NES_CPU_WR", 0xD555, 0xAA)
      dict.nes("NES_CPU_WR", 0xAAAA, 0x55)
      dict.nes("NES_CPU_WR", 0xD555, 0x10)
      rv = dict.nes("NES_CPU_RD", 0x8000)

      -- TODO create some function to pass the read value
      -- that's smart enough to figure out if the board is actually erasing or not
      while rv ~= dict.nes("NES_CPU_RD", 0x8000) do
        spinner.update("Erasing")
        rv = dict.nes("NES_CPU_RD", 0x8000)
        i = i + 1
      end
      spinner.clear()
      log.success("Done erasing PRG-ROM", i .. " naks")
    end

    -- erase CHR-ROM only if needed
    if chr_size ~= 0 then
      init_mapper()
      log.section("Erasing CHR-ROM")
      dict.nes("NES_PPU_WR", 0x1555, 0xAA)
      dict.nes("NES_PPU_WR", 0x0AAA, 0x55)
      dict.nes("NES_PPU_WR", 0x1555, 0x80)
      dict.nes("NES_PPU_WR", 0x1555, 0xAA)
      dict.nes("NES_PPU_WR", 0x0AAA, 0x55)
      dict.nes("NES_PPU_WR", 0x1555, 0x10)
      rv = dict.nes("NES_PPU_RD", 0x0000)

      i = 0

      -- TODO create some function to pass the read value 
      -- that's smart enough to figure out if the board is actually erasing or not
      while rv ~= dict.nes("NES_PPU_RD", 0x0000) do
        spinner.update("Erasing")
        rv = dict.nes("NES_PPU_RD", 0x0000)
        i = i + 1
      end
      spinner.clear()
      log.success("Done erasing CHR-ROM", i .. " naks")
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
    if prg_size ~= 0 then
      time.start()
      prg_rom_flash(file, prg_size, DEBUG)
      time.report(prg_size)
    end

    if chr_size ~= 0 then
      time.start()
      chr_rom_flash(file, chr_size, DEBUG)
      time.report(chr_size)
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
    if prg_size ~= 0 then
      log.section("Dumping PRG-ROM")
      time.start()
      prg_rom_dump(file, prg_size, DEBUG)
      time.report(prg_size)
      log.success("PRG-ROM dumping done")
    end

    if chr_size ~= 0 then
      log.section("Dumping CHR-ROM")
      time.start()
      chr_dump(file, chr_size, DEBUG)
      time.report(chr_size)
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
