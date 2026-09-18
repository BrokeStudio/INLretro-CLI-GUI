-- create the module's table
local vrc6a        = {}

-- import required modules
local dict         = require "scripts.app.dict"
local nes          = require "scripts.app.nes"
local dump         = require "scripts.app.dump"
local flash        = require "scripts.app.flash"
local chips        = require "scripts.app.chips"
local time         = require "scripts.app.time"
local log          = require "scripts.app.log"
local spinner      = require "scripts.app.spinner"
local files        = require "scripts.app.files"
local help         = require "scripts.app.help"

-- file constants and global variables
local mapname      = "VRC6a"
local prg_flash_chip
local chr_flash_chip

local PRG_16K      = 0x8000 -- 16k PRG Select ($8000-$8003)
local PRG_8K       = 0xC000 --	8k PRG Select ($C000)
local RAM_8K       = 0xC001 -- 8K PRG-RAM select, added for flash purpose
local FLASH_ENABLE = 0xC002 -- PRG-ROM flash through $6000-$7FFF select, added for flash purpose
local PPU_BANKING  = 0xB003 -- PPU Banking Style ($B003)
local CHR_0        = 0xD000
local CHR_1        = 0xD001
local CHR_2        = 0xD002
local CHR_3        = 0xD003
local CHR_4        = 0xE000
local CHR_5        = 0xE001
local CHR_6        = 0xE002
local CHR_7        = 0xE003

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

-- disables PRG-RAM, selects Vertical mirroring
-- sets up CHR-ROM flash PT0 for DATA, Commands: $5555->$1555  $2AAA->$1AAA
-- sets up PRG-ROM flash DATA: $8000-9FFF, Commands: $5555->D555  $2AAA->$AAAA
-- leaves $8000 control reg selected to IRQ value selected so $A000 writes don't affect banking
local function init_mapper()
  -- set $8000 16k bank register for flashing purpose
  dict.nes("NES_CPU_WR", FLASH_ENABLE, 0x00) -- disable prgram flashing
  dict.nes("NES_CPU_WR", PRG_16K, 0x00)

  -- set $C000 8k bank register for flashing purpose
  dict.nes("NES_CPU_WR", PRG_8K, 0x02)

  -- disable PRG-RAM
  -- enable PPU banking mode 1
  dict.nes("NES_CPU_WR", PPU_BANKING, 0x00)

  -- set $1000 and $1800 CHR banks for flashing purpose
  dict.nes("NES_CPU_WR", CHR_5, 0x15)
  dict.nes("NES_CPU_WR", CHR_6, 0x0A)
end


-- test the mapper's mirroring modes to verify working properly
-- can be used to help identify board: returns true if pass, false if failed
local function mirror_test()
  log.section("Testing mirroring settings")

  -- put mapper in known state
  init_mapper()

  -- Vertical
  dict.nes("NES_CPU_WR", PPU_BANKING, 0x20)
  if nes.detect_mapper_mirroring() ~= "VERT" then
    log.error("Vertical mirroring test failed")
    return false
  else
    log.success("Vertical mirroring test passed")
  end

  --Horizontal
  dict.nes("NES_CPU_WR", PPU_BANKING, 0x24)
  if nes.detect_mapper_mirroring() ~= "HORZ" then
    log.error("Horizontal mirroring test failed")
    return false
  else
    log.success("Horizontal mirroring test passed")
  end

  -- 1 screen A
  dict.nes("NES_CPU_WR", PPU_BANKING, 0x28)
  if nes.detect_mapper_mirroring() ~= "1SCRNA" then
    log.error("One screen mirroring test failed (1 screen A)")
    return false
  else
    log.success("One screen mirroring test passed (1 screen A)")
  end

  -- 1 screen B
  dict.nes("NES_CPU_WR", PPU_BANKING, 0x2C)
  if nes.detect_mapper_mirroring() ~= "1SCRNB" then
    log.error("One screen mirroring test failed (1 screen B)")
    return false
  else
    log.success("One screen mirroring test passed (1 screen B)")
  end

  -- restore register PPU_BANKING value
  dict.nes("NES_CPU_WR", PPU_BANKING, 0x00)

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

--- Program one byte to PRG-ROM flash and poll for completion.
-- @param addr integer Address to program
-- @param value integer 8-bit value to write
-- @param bank integer Mapper bank value selecting the target flash bank
local function prg_rom_flash_byte(addr, value, bank)
  if (addr < 0x8000 or addr > 0x9FFF) then
    log.error("ERROR! flash write to PRG-ROM", help.hex_0x4(addr), "must be $8000-9FFF")
    return
  end

  -- fix address
  addr = addr & 0x7FFF
  addr = addr | 0x6000

  -- select bank
  -- dict.nes("NES_CPU_WR", FLASH_ENABLE, 0x01)  --enable prgram flashing -- must be done by caller
  dict.nes("NES_CPU_WR", RAM_8K, bank)

  -- send unlock command and write byte
  dict.nes("NES_CPU_WR", 0xD555, 0xAA)
  dict.nes("NES_CPU_WR", 0xAAAA, 0x55)
  dict.nes("NES_CPU_WR", 0xD555, 0xA0)
  dict.nes("NES_CPU_WR", addr, value)

  -- recover bank
  -- dict.nes("NES_CPU_WR", PRG_16K, bank)

  local rv = dict.nes("NES_CPU_RD", addr)

  local i = 0

  while rv ~= dict.nes("NES_CPU_RD", addr) do
    rv = dict.nes("NES_CPU_RD", addr)
    i = i + 1
  end

  if DEBUG then
    log.info("Done writing byte,", i .. " naks")
  end

  --dict.nes("NES_CPU_WR", FLASH_ENABLE, 0x00)  --disable prgram flashing -- must be done by caller

  --TODO handle timeout for problems

  --TODO return pass/fail/info
end

--- Dump PRG-ROM contents to an already-open output file.
-- @param file file* Open binary output file
-- @param rom_size_kb integer PRG-ROM size in kilobytes
local function prg_rom_dump(file, rom_size_kb)
  -- PRG-ROM dump 16KB at a time
  local kb_per_read = 16
  local num_banks = math.floor(rom_size_kb / kb_per_read)
  local cur_bank = 0
  local addr_base = 0x80 -- $8000

  log.info("PRG-ROM size", rom_size_kb .. "KB")

  while cur_bank < num_banks do
    if DEBUG then
      log.point("dumping PRG bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- select desired bank(s) to dump
    dict.nes("NES_CPU_WR", PRG_16K, cur_bank) -- 16KB @ CPU $8000

    dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NESCPU_PAGE" })

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--- Program PRG-ROM contents from an already-open input file, one bank at a time.
-- @param file file* Open binary input file
-- @param rom_size_kb integer PRG-ROM size in kilobytes
local function prg_rom_flash(file, rom_size_kb)
  init_mapper()

  log.section("Programming PRG-ROM")
  log.info("PRG-ROM size", rom_size_kb .. "KB")


  local bank_size = 8 -- VRC6 8KByte per PRG bank
  local cur_bank = 0
  local num_banks = math.floor(rom_size_kb / bank_size)

  local options
  if prg_flash_chip.buffer == true then
    options = "USE_BUFFER"
    log.info("Using buffer programming")
  elseif prg_flash_chip.unlock_bypass == true then
    options = "USE_UNLOCK_BYPASS"
    log.info("Using unlock bypass mode")
  end

  -- this is a custom register
  -- that allow flashing data
  -- in the $6000-$7FFF area
  dict.nes("NES_CPU_WR", FLASH_ENABLE, 0x01) -- enable prgram flashing

  while cur_bank < num_banks do
    if DEBUG then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- select desired bank, needed for first write
    dict.nes("NES_CPU_WR", RAM_8K, cur_bank) -- 8KB @ CPU $6000

    -- set cur_bank for recovery and subsequent bytes
    dict.nes("SET_CUR_BANK", cur_bank)
    -- if DEBUG then print("get bank:", dict.nes("GET_CUR_BANK")) end

    --have the device write a bank worth of data
    flash.write_file(file, bank_size, { mapper = mapname, mem_type = "PRGROM", options = options })

    cur_bank = cur_bank + 1
  end

  spinner.clear()
  log.success("Done programming PRG-ROM")

  dict.nes("NES_CPU_WR", FLASH_ENABLE, 0x02) -- disable prgram flashing
end

--[[
 ██████╗██╗  ██╗██████╗       ██████╗  ██████╗ ███╗   ███╗
██╔════╝██║  ██║██╔══██╗      ██╔══██╗██╔═══██╗████╗ ████║
██║     ███████║██████╔╝█████╗██████╔╝██║   ██║██╔████╔██║
██║     ██╔══██║██╔══██╗╚════╝██╔══██╗██║   ██║██║╚██╔╝██║
╚██████╗██║  ██║██║  ██║      ██║  ██║╚██████╔╝██║ ╚═╝ ██║
 ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝      ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝

--]]

--- Program one byte to CHR flash and poll for completion.
-- @param addr integer Address to program, 0x0000-0x0FFF
-- @param value integer 8-bit value to write
-- @param bank integer Mapper bank value selecting the target flash bank
local function wr_chr_flash_byte(addr, value, bank)
  if addr < 0x0000 or addr > 0x0FFF then
    log.error("ERROR! flash write to CHR-ROM", help.hex_0x4(addr), "must be $0000-0FFF")
    return
  end

  --send unlock command and write byte
  dict.nes("NES_PPU_WR", 0x1555, 0xAA)
  dict.nes("NES_PPU_WR", 0x0AAA, 0x55)
  dict.nes("NES_PPU_WR", 0x1555, 0xA0)
  dict.nes("NES_PPU_WR", addr, value)

  local rv = dict.nes("NES_PPU_RD", addr)

  local i = 0

  while (rv ~= value) do
    rv = dict.nes("NES_PPU_RD", addr)
    i = i + 1
  end
  if DEBUG then print(i, "naks, done writing byte.") end

  --TODO handle timeout for problems

  --TODO return pass/fail/info
end

--- Dump CHR contents to an already-open output file.
-- @param file file* Open binary output file
-- @param rom_size_kb integer CHR size in kilobytes
local function chr_dump(file, rom_size_kb)
  local kb_per_read = 4 -- 1KByte bank x 4
  local num_banks = math.floor(rom_size_kb / kb_per_read)
  local cur_bank = 0
  local addr_base = 0x00 -- $0000

  log.info("CHR size", rom_size_kb .. "KB")

  while cur_bank < num_banks do
    if DEBUG then
      log.point("dump CHR bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- set 1K banks x 4
    dict.nes("NES_CPU_WR", CHR_0, (cur_bank * 4))     --1KB @ PPU $0000
    dict.nes("NES_CPU_WR", CHR_1, (cur_bank * 4 + 1)) --1KB @ PPU $0400
    dict.nes("NES_CPU_WR", CHR_2, (cur_bank * 4 + 2)) --1KB @ PPU $0800
    dict.nes("NES_CPU_WR", CHR_3, (cur_bank * 4 + 3)) --1KB @ PPU $0C00

    -- 4 = number of KB to dump per loop
    -- 0x00 = starting read address A10-13 -> $0000
    -- mapper must be 0x00 or 0x04-0x3C to designate A10-13
    --   bits 7, 6, 1, & 0 CAN NOT BE SET!
    --   0x04 would designate that A10 is set -> $0400 (the second 1KB PT bank)
    --   0x20 would designate that A13 is set -> $2000 (first name table)
    dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NESPPU_PAGE" })

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--- Program CHR contents from an already-open input file, one bank at a time.
-- @param file file* Open binary input file
-- @param rom_size_kb integer CHR size in kilobytes
local function chr_rom_flash(file, rom_size_kb)
  init_mapper()

  log.section("Programming CHR-ROM")
  log.info("CHR-ROM size", rom_size_kb .. "KB")

  local bank_size = 4 -- 1KByte per lower CHR bank and we're using 4 of them..
  local cur_bank = 0
  local num_banks = math.floor(rom_size_kb / bank_size)

  while cur_bank < num_banks do
    if DEBUG then
      log.point("writing CHR bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- set current 1K banks
    dict.nes("NES_CPU_WR", CHR_0, cur_bank * 4)     -- 1KB @ PPU $0000
    dict.nes("NES_CPU_WR", CHR_1, cur_bank * 4 + 1) -- 1KB @ PPU $0400
    dict.nes("NES_CPU_WR", CHR_2, cur_bank * 4 + 2) -- 1KB @ PPU $0800
    dict.nes("NES_CPU_WR", CHR_3, cur_bank * 4 + 3) -- 1KB @ PPU $0C00

    -- have the device write a bank worth of data
    flash.write_file(file, 4, { mapper = mapname, mem_type = "CHRROM" })

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
-- @param file file* Open binary output file
-- @param ram_size_kb integer PRG-RAM size in kilobytes
local function prg_ram_dump(file, ram_size_kb)
  local kb_per_read = 8
  local num_banks = math.floor(ram_size_kb / kb_per_read)
  local cur_bank = 0
  local addr_base = 0x60 -- $6000

  log.info("PRG-RAM size", ram_size_kb .. "KB")

  while cur_bank < num_banks do
    if DEBUG then
      log.point("dumping PRG-RAM bank ", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NESCPU_PAGE" })

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--- Write PRG-RAM contents from an already-open input file.
-- @param file file* Open binary input file
-- @param ram_size_kb integer PRG-RAM size in kilobytes
local function prg_ram_write(file, ram_size_kb)
  init_mapper()

  log.info("PRG-RAM size", ram_size_kb .. "KB")
  log.error("TODO")
  do return end

  local bank_size = 8
  local cur_bank = 0
  local num_banks = math.floor(ram_size_kb / bank_size)

  -- enable PRG-RAM
  dict.nes("NES_CPU_WR", PPU_BANKING, 0x80)

  while cur_bank < num_banks do
    if DEBUG then
      log.point("writing PRG-RAM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    --have the device write a bank worth of data
    flash.write_file(file, bank_size, { mapper = "NOVAR", mem_type = "PRGRAM" })

    cur_bank = cur_bank + 1
  end

  -- disable PRG-RAM
  dict.nes("NES_CPU_WR", PPU_BANKING, 0x00)

  spinner.clear()
  log.success("Done programming PRG-RAM")
end

--- Detect PRG-RAM by writing and reading back a test byte.
-- @return boolean success True when RAM read/write behavior is detected
local function prg_ram_test()
  local test = true
  local read_value
  local saved_value

  log.section("Detecting PRG-RAM")

  -- enable PRG-RAM
  dict.nes("NES_CPU_WR", PPU_BANKING, 0x80)

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

  -- disable PRG-RAM
  dict.nes("NES_CPU_WR", PPU_BANKING, 0x40)

  if test then
    log.success("PRG-RAM detected")
  else
    log.error("PRG-RAM not detected")
  end

  return test
end

--- Exercise PRG-RAM with an LFSR pattern and compare the dumped result.
-- Overwrites PRG-RAM contents with the test pattern.
-- @param wram_size_kb integer PRG-RAM size in kilobytes
-- @param retroprog_id string|integer Identifier used in the temporary dump filename
-- @return boolean success True when the PRG-RAM dump matches the expected LFSR data
local function prg_ram_exercise(wram_size_kb, retroprog_id)
  dict.stuff("RESET_LFSR") -- sets it to 1

  local cur_bank = 0
  local num_banks = math.floor(wram_size_kb / 8)

  log.section("Exercising PRG-RAM")
  log.info("PRG-RAM size", wram_size_kb .. "KB")

  -- enable PRG-RAM
  dict.nes("NES_CPU_WR", PPU_BANKING, 0x80)

  -- write random data to all banks
  log.point("Writing random data to PRG-RAM")
  while cur_bank < num_banks do
    if DEBUG then
      log.point("init PRG-RAM 8K bank", cur_bank, "of", num_banks - 1)
    end

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
  prg_ram_dump(file, wram_size_kb)

  -- close file
  assert(file:close())

  -- disable PRG-RAM
  dict.nes("NES_CPU_WR", PPU_BANKING, 0x00)

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "./ignore/lfsr_32KB.bin"

  -- compare the flash file vs post dump file
  if files.compare(filename, goodfile, false) then
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

--- Exercise CHR-RAM with an LFSR pattern and compare the dumped result.
-- Overwrites CHR-RAM contents with the test pattern.
-- @param chr_ram_size_kb integer CHR-RAM size in kilobytes
-- @param retroprog_id string|integer Identifier used in the temporary dump filename
-- @return boolean success True when the CHR-RAM dump matches the expected LFSR data
local function chr_ram_exercise(chr_ram_size_kb, retroprog_id)
  dict.stuff("RESET_LFSR") -- sets it to 1

  local cur_bank = 0
  local num_banks = math.floor(chr_ram_size_kb / 4)

  log.section("Exercising CHR-RAM")
  log.info("CHR-RAM size", chr_ram_size_kb .. "KB")

  -- write random data to all banks
  log.point("Writing random data to CHR-RAM")
  while cur_bank < num_banks do
    if DEBUG then
      log.point("init CHR-RAM 8K bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Writing", cur_bank, "/", num_banks - 1)
    end

    --the bank is half the size of KB per read so must multiply by 2
    --but bit0 isn't used with these 2KB banks, so shift by 1
    dict.nes("NES_CPU_WR", PRG_16K, 0x00)
    dict.nes("NES_CPU_WR", 0x8001, ((cur_bank * 2) << 1)) -- 2KB @ PPU $0000

    --the bank is half the size of KB per read so must multiply by 2 and add 1 for second 4KB
    --but bit0 isn't used with these 2KB banks, so shift by 1
    dict.nes("NES_CPU_WR", PRG_16K, 0x01)
    dict.nes("NES_CPU_WR", 0x8001, ((cur_bank * 2 + 1) << 1)) -- 2KB @ CPU $0800

    -- write data
    local addr = 0x0000
    while addr < 0x1000 do
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
  chr_dump(file, chr_ram_size_kb)

  -- close the file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "./ignore/lfsr_32KB.bin"

  -- compare the flash file vs post dump file
  if files.compare(filename, goodfile, false) then
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
-- @param process_opts table Parsed operation options from the main application
-- @param console_opts table Console/cartridge size options
-- @return false|nil result False on explicitly reported failure; otherwise no value
local function process(process_opts, console_opts)
  -- some local variables
  local rv               = nil
  local file
  local chr_ram_detected = false
  local chr_ram_size_kb  = 0

  -- process options
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

  --[[
  888888 888888 .dP"Y8 888888
    88   88__   `Ybo."   88
    88   88""   o.`Y8b   88
    88   888888 8bodP'   88
  --]]

  -- test cart
  if do_test then
    log.section("Testing ", mapname)

    -- verify mirroring is behaving as expected
    rv = mirror_test()
    if not rv then return false end

    chr_ram_detected = nes.ppu_ram_sense(0x1000)
    -- print("EXP0 pull-up test:", dict.io("EXP0_PULLUP_TEST"))

    -- attempt to read PRG-ROM flash ID
    if options.force_flash_test or (do_rom_write and prg_size_kb ~= 0) then
      init_mapper()
      rv, prg_flash_chip = nes.prg_rom_get_chip()
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
      init_mapper()
      rv, chr_flash_chip = nes.chr_rom_get_chip()
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
    rv = prg_ram_test()
    if rv == true then
      if options.force_wram_test then
        log.print()
        log.warning("Flag 'force_wram_test' enabled")
      end
      -- force wram size to 8KB
      if wram_size_kb == 0 then
        wram_size_kb = 8
      end
      if options.force_wram_test or nes.header.is_valid then
        if not options.force_wram_test and nes.header.has_battery then
          log.print()
          log.warning("Can't exercise PRG-RAM because NES ROM has battery backed data")
        else
          if wram_size_kb ~= 0 then
            rv = prg_ram_exercise(wram_size_kb, retroprog_id)
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
      log.error("TODO: CHR-RAM tests...")
      do return end

      -- force size to 8KB
      chr_ram_size_kb = 8

      -- test CHR-RAM
      if chr_ram_size_kb ~= 0 then
        rv = chr_ram_exercise(chr_ram_size_kb, retroprog_id)
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

    -- enable PRG-RAM
    dict.nes("NES_CPU_WR", PPU_BANKING, 0x80)

    file = assert(io.open(ram_dump_file.filename, "wb"))

    -- dump cart to file
    prg_ram_dump(file, wram_size_kb)

    -- disable PRG-RAM
    dict.nes("NES_CPU_WR", PPU_BANKING, 0x00)

    -- close file
    assert(file:close())

    log.success("Done dumping PRG-RAM")
  end

  --[[
  88""Yb    db    8b    d8     Yb        dP 88""Yb 88 888888 888888
  88__dP   dPYb   88b  d88      Yb  db  dP  88__dP 88   88   88__
  88"Yb   dP__Yb  88YbdP88       YbdPYbdP   88"Yb  88   88   88""
  88  Yb dP""""Yb 88 YY 88        YP  YP    88  Yb 88   88   888888
  --]]

  -- write file to the cart RAM
  if do_ram_write then
    log.section("Writing to PRG-RAM")

    init_mapper()

    -- enable PRG-RAM
    dict.nes("NES_CPU_WR", PPU_BANKING, 0x80)

    file = assert(io.open(ram_write_file.filename, "rb"))

    flash.write_file(file, wram_size_kb, { mapper = "NOVAR", mem_type = "PRGRAM" })

    -- disable PRG-RAM
    dict.nes("NES_CPU_WR", PPU_BANKING, 0x00)

    -- close file
    assert(file:close())

    log.success("Done writing PRG-RAM")
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

    --create header: pass open & empty file & rom sizes
    if rom_dump_file.ext == "nes" then
      --create header: pass open & empty file & rom sizes
      create_header(file, prg_size_kb, chr_size_kb)
    end

    -- dump cart to file
    if prg_size_kb ~= 0 then
      log.section("Dumping PRG-ROM")
      time.start()
      prg_rom_dump(file, prg_size_kb)
      time.report(prg_size_kb)
      log.success("PRG-ROM dumping done")
    end

    if chr_size_kb ~= 0 then
      log.section("Dumping CHR-ROM")
      time.start()
      chr_dump(file, chr_size_kb)
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
    -- erase PRG-ROM only if needed
    if prg_size_kb ~= 0 then
      rv = nes.prg_rom_erase(prg_flash_chip)
      if not rv then
        log.error("PRG-ROM couldn't be erased")
        return false
      end
    end

    -- erase CHR-ROM only if needed
    if chr_size_kb ~= 0 then
      rv = nes.chr_rom_erase(chr_flash_chip)
      if not rv then
        log.error("CHR-ROM couldn't be erased")
        return false
      end
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
      prg_rom_flash(file, prg_size_kb)
      time.report(prg_size_kb)
    end

    if chr_size_kb ~= 0 then
      time.start()
      chr_rom_flash(file, chr_size_kb)
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
      prg_rom_dump(file, prg_size_kb)
      time.report(prg_size_kb)
      log.success("PRG-ROM dumping done")
    end

    if chr_size_kb ~= 0 then
      log.section("Dumping CHR-ROM")
      time.start()
      chr_dump(file, chr_size_kb)
      time.report(chr_size_kb)
      log.success("CHR-ROM dumping done")
    end

    -- close file
    assert(file:close())

    -- compare the flash file vs post dump file
    log.section("Verifying data")
    if files.compare(verify_file.filename, rom_write_file.filename, true) then
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
vrc6a.process = process

-- return the module's table
return vrc6a
