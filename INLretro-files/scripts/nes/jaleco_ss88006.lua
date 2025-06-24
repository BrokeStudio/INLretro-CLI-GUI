-- create the module's table
local jaleco_ss88006 = {}

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
local mapname = "JALECO_SS88006"

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

local function init_mapper(debug)

  -- set $8000 8k bank register for flashing purpose
  dict.nes("NES_CPU_WR", 0x8001, 0x00)  -- hi 4 bits
  dict.nes("NES_CPU_WR", 0x8000, 0x00)  -- lo 4 bits

  -- set $A000 8k bank register for flashing purpose
  dict.nes("NES_CPU_WR", 0x8003, 0x00)  -- hi 4 bits
  dict.nes("NES_CPU_WR", 0x8002, 0x01)  -- lo 4 bits

  -- set $C000 8k bank register for flashing purpose
  dict.nes("NES_CPU_WR", 0x9001, 0x00)  -- hi 4 bits
  dict.nes("NES_CPU_WR", 0x9000, 0x02)  -- lo 4 bits

  -- disable PRG-RAM and deny writes
  dict.nes("NES_CPU_WR", 0x9002, 0x00)

  -- set $1400 CHR banks for flashing purpose
  dict.nes("NES_CPU_WR", 0xC003, 0x01)  -- hi 4 bits
  dict.nes("NES_CPU_WR", 0xC002, 0x05)  -- lo 4 bits

  -- set $1800 CHR banks for flashing purpose
  dict.nes("NES_CPU_WR", 0xD001, 0x00)  -- hi 4 bits
  dict.nes("NES_CPU_WR", 0xD000, 0x0A)  -- lo 4 bits

end

-- test the mapper's mirroring modes to verify working properly
-- can be used to help identify board: returns true if pass, false if failed
local function mirror_test(debug)

  -- put mapper in known state
  init_mapper()

  -- 7  bit  0
  -- ---------
  -- .... ..MM
  --        ||
  --        ++-- 0: Horizontal (A11)
  --             1: Vertical (A10)
  --             2: 1scA (Ground)
  --             3: 1scB (Vcc)

  -- Vertical
  dict.nes("NES_CPU_WR", 0xF002, 0x01)
  if nes.detect_mapper_mirroring(debug) ~= "VERT" then
    log.error("Vertical mirroring test failed")
    return false
  else
    log.success("Vertical mirroring test passed")
  end

  -- Horizontal
  dict.nes("NES_CPU_WR", 0xF002, 0x00)
  if nes.detect_mapper_mirroring(debug) ~= "HORZ" then
    log.error("Horizontal mirroring test failed")
    return false
  else
    log.success("Horizontal mirroring test passed")
  end

  -- 1 Screen A
  dict.nes("NES_CPU_WR", 0xF002, 0x02)
  if nes.detect_mapper_mirroring(debug) ~= "1SCRNA" then
    log.error("One screen mirroring test failed (1 screen A)")
    return false
  else
    log.success("One screen mirroring test passed (1 screen A)")
  end

  -- 1 Screen B
  dict.nes("NES_CPU_WR", 0xF002, 0x03)
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

  -- mapper writes affect PRG banking /!\
  dict.nes("M2_HIGH_WR", 0xD555, 0xAA)  --D555 & F003 (mirror) = D001 (CHR bank)
  dict.nes("M2_HIGH_WR", 0xAAAA, 0x55)  --AAAA & F003 (mirror) = A002 (no register)
  dict.nes("M2_HIGH_WR", 0xD555, 0x90)  --D555

  manufacturer_id = dict.nes("NES_CPU_RD", 0x8000)
  chips.display_manufacturer(manufacturer_id)

  device_id = dict.nes("NES_CPU_RD", 0x8001)
  device_test = chips.display_device(manufacturer_id, device_id)

  -- exit software
  dict.nes("M2_HIGH_WR", 0x8000, 0xF0)

  if device_test == false then
    return false
  else
    return true
  end

end

--write a single byte to PRG-ROM flash
--PRE: assumes mapper is initialized and bank is selected as prescribed in mapper_init
--REQ: addr must be in the first bank $8000-9FFF
local function prg_rom_flash_byte(addr, value, bank, debug)

  if (addr < 0x8000 or addr > 0x9FFF) then
    log.error("\n  ERROR! flash write to PRG-ROM", string.format("$%X", addr), "must be $8000-9FFF \n\n")
    return
  end

  --select bank
  dict.nes("NES_CPU_WR", 0x8001, (bank & 0xF0) >> 4) -- hi 4 bits
  dict.nes("NES_CPU_WR", 0x8000, (bank & 0x0F))      -- lo 4 bits

  --send unlock command and write byte
  dict.nes("M2_HIGH_WR", 0xD555, 0xAA)
  dict.nes("M2_HIGH_WR", 0xAAAA, 0x55)
  dict.nes("M2_HIGH_WR", 0xD555, 0xA0)
  dict.nes("M2_HIGH_WR", addr, value)

  local rv = dict.nes("NES_CPU_RD", addr)

  local i = 0

  while (rv ~= value) do
    rv = dict.nes("NES_CPU_RD", addr)
    i = i + 1
  end
  if debug then print(i, "naks, done writing byte.") end

  --dict.nes("NES_CPU_WR", 0xC002, 0x00)  --disable prgram flashing -- must be done by caller

  --TODO handle timeout for problems

  --TODO return pass/fail/info
end

--dump the PRG ROM
local function prg_rom_dump(file, rom_size_KB, debug)

  --PRG-ROM dump 8KB at a time
  local KB_per_read = 8
  local num_banks = math.floor(rom_size_KB / KB_per_read)
  local cur_bank = 0
  local addr_base = 0x80 -- $8000

  log.info("PRG-ROM size", rom_size_KB .. "KB")

  while cur_bank < num_banks do

    if debug then
      log.point("dumping PRG bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks-1)
    end

    -- set bank
    dict.nes("NES_CPU_WR", 0x8001, (cur_bank & 0xF0) >> 4) -- hi 4 bits
    dict.nes("NES_CPU_WR", 0x8000, (cur_bank & 0x0F))      -- lo 4 bits

    -- dump data
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

  local bank_size = 8 -- MMC3 8KByte per PRG bank
  local cur_bank = 0
  local num_banks = math.floor(rom_size_KB/bank_size)

  while cur_bank < num_banks do

    if debug then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks-1)
    end

    -- set bank
    dict.nes("NES_CPU_WR", 0x8001, (cur_bank & 0xF0) >> 4) -- hi 4 bits
    dict.nes("NES_CPU_WR", 0x8000, (cur_bank & 0x0F))      -- lo 4 bits

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size, "A53_512K", "PRGROM", false)
    -- TODO: should we keep A53_512K here?

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
local function chr_rom_manf_id(debug)

  local manufacturer_id
  local device_id
  local device_test

  init_mapper()

  log.section("Reading CHR-ROM manufacturer/device ID")

  --       17 16 15 14 13 12 11 10
  -- $0000  0  0  0  0  0  0  0  0 00 0000 0000
  -- $1000  0  0  0  0  0  1  0  0 00 0000 0000

  -- $1555  0  0  0  0  0  1  0  1 01 0101 0101
  -- $1AAA  0  0  0  0  0  1  1  0 10 1010 1010

  -- $5555  0  0  0  1  0  1  0  1 01 0101 0101
  -- $2AAA  0  0  0  0  1  0  1  0 10 1010 1010

  dict.nes("NES_PPU_WR", 0x1555, 0xAA)
  dict.nes("NES_PPU_WR", 0x1AAA, 0x55)
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
-- REQ: addr must be in the first 2 banks $0000-0FFF
local function chr_rom_flash_byte(addr, value, bank, debug)

  if addr < 0x0000 or addr > 0x0FFF then
    log.error("\n  ERROR! flash write to CHR-ROM", string.format("$%X", addr), "must be $0000-0FFF \n\n")
    return
  end

  --send unlock command
  dict.nes("NES_PPU_WR", 0x1555, 0xAA)
  dict.nes("NES_PPU_WR", 0x0AAA, 0x55)
  dict.nes("NES_PPU_WR", 0x1555, 0xA0)

  --write data
  dict.nes("NES_PPU_WR", addr, value)

  local rv = dict.nes("NES_PPU_RD", addr)

  local i = 0

  while (rv ~= value) do
    rv = dict.nes("NES_PPU_RD", addr)
    i = i + 1
  end
  if debug then print(i, "naks, done writing byte.") end

  --TODO handle timeout for problems

  --TODO return pass/fail/info
end

-- dump CHR-ROM/RAM
local function chr_dump(file, rom_size_KB, debug)

  local KB_per_read = 4   -- dump one PT at a time
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

    -- set 1K banks x 4
    local bank = cur_bank * 4

    -- set $0000 CHR bank
    dict.nes("NES_CPU_WR", 0xA001, ((bank + 0) & 0xf0) >> 4) -- hi 4 bits
    dict.nes("NES_CPU_WR", 0xA000, ((bank + 0) & 0x0f))      -- lo 4 bits

    -- set $0400 CHR bank
    dict.nes("NES_CPU_WR", 0xA003, ((bank + 1) & 0xf0) >> 4) -- hi 4 bits
    dict.nes("NES_CPU_WR", 0xA002, ((bank + 1) & 0x0f))      -- lo 4 bits

    -- set $0800 CHR bank
    dict.nes("NES_CPU_WR", 0xB001, ((bank + 2) & 0xf0) >> 4) -- hi 4 bits
    dict.nes("NES_CPU_WR", 0xB000, ((bank + 2) & 0x0f))      -- lo 4 bits

    -- set $0C00 CHR bank
    dict.nes("NES_CPU_WR", 0xB003, ((bank + 3) & 0xf0) >> 4) -- hi 4 bits
    dict.nes("NES_CPU_WR", 0xB002, ((bank + 3) & 0x0f))      -- lo 4 bits

    --4 = number of KB to dump per loop
    --0x00 = starting read address A10-13 -> $0000
    --mapper must be 0x00 or 0x04-0x3C to designate A10-13
    --  bits 7, 6, 1, & 0 CAN NOT BE SET!
    --  0x04 would designate that A10 is set -> $0400 (the second 1KB PT bank)
    --  0x20 would designate that A13 is set -> $2000 (first name table)
    dump.dumptofile(file, KB_per_read, addr_base, "NESPPU_PAGE", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()

end

-- host flash one bank at a time
local function chr_rom_flash(file, rom_size_KB, debug)

  init_mapper()

  log.section("Programming CHR-ROM")
  log.info("CHR-ROM size", rom_size_KB .. "KB")

  local bank_size = 4  -- MMC3 2KByte per lower CHR bank and we're using 2 of them..
  local cur_bank = 0
  local num_banks = math.floor(rom_size_KB / bank_size)

  while cur_bank < num_banks do

    if debug then
      log.point("writing CHR bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks-1)
    end

    -- set 1K banks x 4
    local bank = cur_bank * 4

    -- set $0000 CHR bank
    dict.nes("NES_CPU_WR", 0xA001, ((bank + 0) & 0xf0) >> 4) -- hi 4 bits
    dict.nes("NES_CPU_WR", 0xA000, ((bank + 0) & 0x0f))      -- lo 4 bits

    -- set $0400 CHR bank
    dict.nes("NES_CPU_WR", 0xA003, ((bank + 1) & 0xf0) >> 4) -- hi 4 bits
    dict.nes("NES_CPU_WR", 0xA002, ((bank + 1) & 0x0f))      -- lo 4 bits

    -- set $0800 CHR bank
    dict.nes("NES_CPU_WR", 0xB001, ((bank + 2) & 0xf0) >> 4) -- hi 4 bits
    dict.nes("NES_CPU_WR", 0xB000, ((bank + 2) & 0x0f))      -- lo 4 bits

    -- set $0C00 CHR bank
    dict.nes("NES_CPU_WR", 0xB003, ((bank + 3) & 0xf0) >> 4) -- hi 4 bits
    dict.nes("NES_CPU_WR", 0xB002, ((bank + 3) & 0x0f))      -- lo 4 bits

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size, "MMC3", "CHRROM", false)

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

-- dump the PRG-RAM, assumes the PRG-RAM was enabled/disabled as desired prior to calling
local function prg_ram_dump(file, ram_size_KB, debug)

  local KB_per_read = 8
  local num_banks = math.floor(ram_size_KB / KB_per_read)
  local cur_bank = 0
  local addr_base = 0x06  -- $6000

  log.info("PRG-RAM size", ram_size_KB .. "KB")

  while cur_bank < num_banks do

    if debug then
      log.point("dumping PRG-RAM bank ", cur_bank, "of", num_banks-1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks-1)
    end

    dump.dumptofile( file, KB_per_read, addr_base, "NESCPU_4KB", false )

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

  -- enable PRG-RAM and allow writes
  dict.nes("NES_CPU_WR", 0x9002, 0x03)

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

  -- disable PRG-RAM and deny writes
  dict.nes("NES_CPU_WR", 0x9002, 0x00)

  spinner.clear()
  log.success("Done programming PRG-RAM")

end

-- try to detect if PRG-RAM is present
local function prg_ram_detect(debug)

  local test = true
  local read_value
  local saved_value

  log.section("Detecting PRG-RAM")

  -- enable PRG-RAM and allow writes
  dict.nes("NES_CPU_WR", 0x9002, 0x03)

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

  -- disable PRG-RAM and deny writes
  dict.nes("NES_CPU_WR", 0x9002, 0x00)

  if test then
    log.success("PRG-RAM detected")
  else
    log.error("PRG-RAM not detected")
  end

  return test

end

local function prg_ram_test(wram_size, retroprog_id, debug)

  dict.stuff("RESET_LFSR")  -- sets it to 1

  local cur_bank = 0
  local num_banks = math.floor(wram_size / 8)

  log.section("Exercising PRG-RAM")
  log.info("PRG-RAM size", wram_size .. "KB")

  -- enable PRG-RAM and allow writes
  dict.nes("NES_CPU_WR", 0x9002, 0x03)

  -- write random data to all banks
  log.point("Writing random data to PRG-RAM")
  while cur_bank < num_banks do

    if debug then
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
  local filename = "ignore/nes_prg_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))

  -- dump PRG-RAM
  log.point("Dumping PRG-RAM")
  prg_ram_dump(file, wram_size, debug)

  -- close file
  assert(file:close())

  -- disable PRG-RAM and deny writes
  dict.nes("NES_CPU_WR", 0x9002, 0x00)

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = "ignore/lfsr_32KB.bin"

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

-- try to detect CHR-RAM size
local function chr_ram_get_size(debug)

  -- CHR-RAM can be maximum 2KB
  -- so we'll check 8 4K banks and see if we can write to each

  local chr_ram_size = 8
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

    -- set 1K banks x 4
    local bank = cur_bank * 4

    -- set $0000 CHR bank
    dict.nes("NES_CPU_WR", 0xA001, ((bank + 0) & 0xf0) >> 4) -- hi 4 bits
    dict.nes("NES_CPU_WR", 0xA000, ((bank + 0) & 0x0f))      -- lo 4 bits

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
  local num_banks = math.floor(chr_ram_size / 4)

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

    -- set 1K banks x 4
    local bank = cur_bank * 4

    -- set $0000 CHR bank
    dict.nes("NES_CPU_WR", 0xA001, ((bank + 0) & 0xf0) >> 4) -- hi 4 bits
    dict.nes("NES_CPU_WR", 0xA000, ((bank + 0) & 0x0f))      -- lo 4 bits

    -- set $0400 CHR bank
    dict.nes("NES_CPU_WR", 0xA003, ((bank + 1) & 0xf0) >> 4) -- hi 4 bits
    dict.nes("NES_CPU_WR", 0xA002, ((bank + 1) & 0x0f))      -- lo 4 bits

    -- set $0800 CHR bank
    dict.nes("NES_CPU_WR", 0xB001, ((bank + 2) & 0xf0) >> 4) -- hi 4 bits
    dict.nes("NES_CPU_WR", 0xB000, ((bank + 2) & 0x0f))      -- lo 4 bits

    -- set $0C00 CHR bank
    dict.nes("NES_CPU_WR", 0xB003, ((bank + 3) & 0xf0) >> 4) -- hi 4 bits
    dict.nes("NES_CPU_WR", 0xB002, ((bank + 3) & 0x0f))      -- lo 4 bits

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

  --initialize device i/o for NES
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
    rv = mirror_test(DEBUG)
    if not rv then return false end

    chr_ram_detected = nes.ppu_ram_sense(0x1000, DEBUG)
    -- print("EXP0 pull-up test:", dict.io("EXP0_PULLUP_TEST"))

    -- attempt to read PRG-ROM flash ID
    if prg_size ~= 0 then
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
    if chr_size ~= 0 then
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
    if options.force_wram_test then
      log.print()
      log.warning("Additional option 'force_wram_test' enabled")
    end

    rv = prg_ram_detect(DEBUG)

    if rv == false then -- PRG RAM not found

      if do_ram_dump or do_ram_write then
        log.error("PRG-RAM not detected")
        return false
      elseif do_rom_write then
        if options.force_wram_test then
          log.warning("Additional option 'force_wram_test' implies PRG-RAM presence")
          log.error("PRG-RAM not detected")
          return false
        elseif nes.header.isValid and nes.header.hasPrgRam then
          log.warning("ROM header settings implies PRG-RAM")
          log.error("PRG-RAM not detected")
          return false
        elseif wram_size ~= 0 then
          log.warning("CLI options specify " .. wram_size .. "KB of PRG-RAM")
          log.error("PRG-RAM not detected")
          return false
        else
          log.info("PRG-RAM not detected")
        end
      end

    else -- PRG RAM found

      log.success("PRG-RAM detected")

      -- force wram size to 8KB because it's SS88006 maximum
      wram_size = 8

      if options.force_wram_test and ( do_rom_dump or do_ram_dump ) then
        log.warning("Additional option 'force_wram_test' ignored when dumping PRG-ROM or PRG-RAM")
      elseif do_rom_write or do_ram_write then
        if options.force_wram_test or do_ram_write then
          rv = prg_ram_test(wram_size, retroprog_id, DEBUG)
          if not rv then return false end
        elseif nes.header.isValid and nes.header.hasPrgRam then
          if nes.header.hasBattery then
            log.warning("Can't test PRG-RAM because ROM header specifies battery backed data")
            log.warning("Use additional option 'force_wram_test' to force PRG-RAM test")
          else
            rv = prg_ram_test(wram_size, retroprog_id, DEBUG)
            if not rv then return false end
          end
        else
          log.warning("Can't test PRG-RAM because data could be battery backed")
          log.warning("Use additional option 'force_wram_test' to force PRG-RAM test")
        end
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

    -- enable PRG-RAM and deny writes
    dict.nes("NES_CPU_WR", 0x9002, 0x03)

    file = assert(io.open(ram_dump_file.filename, "wb"))

    -- dump cart to file
    prg_ram_dump(file, wram_size, DEBUG)

    -- disable PRG-RAM and deny writes
    dict.nes("NES_CPU_WR", 0x9002, 0x00)

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

    -- enable PRG-RAM and allow writes
    dict.nes("NES_CPU_WR", 0x9002, 0x03)

    file = assert(io.open(ram_write_file.filename, "rb"))

    flash.write_file( file, wram_size, "NOVAR", "PRGRAM", false )

    -- disable PRG-RAM and deny writes
    dict.nes("NES_CPU_WR", 0x9002, 0x00)

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

    init_mapper()

    -- erase PRG-ROM only if needed
    if prg_size ~= 0 then
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
      while ( rv ~= 0xFF ) do
        rv = dict.nes("NES_CPU_RD", 0x8000)
        i = i + 1
      end
      log.success("Done erasing PRG-ROM", i .. " naks")
    end

    -- erase CHR-ROM only if needed
    if chr_size ~= 0 then
      init_mapper()

      log.section("Erasing CHR-ROM")
      dict.nes("NES_PPU_WR", 0x1555, 0xAA)
      dict.nes("NES_PPU_WR", 0x1AAA, 0x55)
      dict.nes("NES_PPU_WR", 0x1555, 0x80)
      dict.nes("NES_PPU_WR", 0x1555, 0xAA)
      dict.nes("NES_PPU_WR", 0x1AAA, 0x55)
      dict.nes("NES_PPU_WR", 0x1555, 0x10)
      rv = dict.nes("NES_PPU_RD", 0x0000)

      i = 0

      -- TODO create some function to pass the read value
      -- that's smart enough to figure out if the board is actually erasing or not
      while ( rv ~= 0xFF ) do
        rv = dict.nes("NES_PPU_RD", 0x0000)
        i = i + 1
      end
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




























  -- do return end

  -- --dump the ram to file
  -- if dumpram then
  --   print("\nDumping PRG-RAM...")

  --   init_mapper()

  --   --SRAM always enabled

  --   file = assert(io.open(ramdumpfile, "wb"))

  --   -- dump cart to file
  --   dump_wram(file, wram_size, false)

  --   -- close file
  --   assert(file:close())

  --   print("DONE Dumping PRG-RAM")
  -- end


  -- --dump the cart to dumpfile
  -- if read then
  --   print("\nDumping PRG & CHR ROMs...")

  --   init_mapper()

  --   file = assert(io.open(dumpfile, "wb"))

  --   if dump_filetype == "nes" then
  --     --create header: pass open & empty file & rom sizes
  --     create_header(file, prg_size, chr_size)
  --   end

  --   -- dump cart to file
  --   dump_prgrom(file, prg_size, false)
  --   if chr_size ~= 0 then
  --     dump_chrrom(file, chr_size, false)
  --   end

  --   -- close file
  --   assert(file:close())

  --   print("DONE Dumping PRG & CHR ROMs")
  -- end

  -- -- erase the cart
  -- if erase then
  --   print("\nerasing ", mapname)

  --   init_mapper()

  --   --PLCC
  --   print("erasing PRG-ROM")
  --   dict.nes("M2_HIGH_WR", 0xD555, 0xAA)
  --   dict.nes("M2_HIGH_WR", 0xAAAA, 0x55)
  --   dict.nes("M2_HIGH_WR", 0xD555, 0x80)
  --   dict.nes("M2_HIGH_WR", 0xD555, 0xAA)
  --   dict.nes("M2_HIGH_WR", 0xAAAA, 0x55)
  --   dict.nes("M2_HIGH_WR", 0xD555, 0x10)

  --   rv = dict.nes("NES_CPU_RD", 0x8000)

  --   local i = 0

  --   -- TODO create some function to pass the read value
  --   -- that's smart enough to figure out if the board is actually erasing or not
  --   while (rv ~= 0xFF) do
  --     rv = dict.nes("NES_CPU_RD", 0x8000)
  --     i = i + 1
  --   end
  --   print(i, "naks, done erasing prg.")

  --   init_mapper()

  --   if chr_size ~= 0 then
  --     print("erasing CHR-ROM")
  --     dict.nes("NES_PPU_WR", 0x1555, 0xAA)
  --     dict.nes("NES_PPU_WR", 0x1AAA, 0x55)
  --     dict.nes("NES_PPU_WR", 0x1555, 0x80)
  --     dict.nes("NES_PPU_WR", 0x1555, 0xAA)
  --     dict.nes("NES_PPU_WR", 0x1AAA, 0x55)
  --     dict.nes("NES_PPU_WR", 0x1555, 0x10)
  --     rv = dict.nes("NES_PPU_RD", 0x0000)

  --     local i = 0

  --     -- TODO create some function to pass the read value
  --     -- that's smart enough to figure out if the board is actually erasing or not
  --     while (rv ~= 0xFF) do
  --       rv = dict.nes("NES_PPU_RD", 0x8000)
  --       i = i + 1
  --     end
  --     print(i, "naks, done erasing chr.")
  --   end
  -- end

  -- --write to wram on the cart
  -- if writeram then
  --   print("\nWriting to PRG-RAM...")

  --   init_mapper()

  --   --SRAM always enabled

  --   file = assert(io.open(ramwritefile, "rb"))

  --   flash.write_file(file, wram_size, "NOVAR", "PRGRAM", false)

  --   -- close file
  --   assert(file:close())

  --   print("DONE Writing PRG-RAM")
  -- end

  -- --program flashfile to the cart
  -- if program then
  --   --open file
  --   file = assert(io.open(flashfile, "rb"))
  --   --determine if auto-doubling, deinterleaving, etc,
  --   --needs done to make board compatible with rom

  --   if flash_filetype == "nes" then
  --     --advance past the 16byte header
  --     file:read(16)
  --   end

  --   flash_prgrom(file, prg_size, false)
  --   if chr_size ~= 0 then
  --     flash_chrrom(file, chr_size, true)
  --   end

  --   -- close file
  --   assert(file:close())
  -- end

  -- -- verify flash file is on the cart
  -- if verify then
  --   --for now let's just dump the file and verify manually
  --   print("\nPost dumping PRG & CHR ROMs...")

  --   init_mapper()

  --   file = assert(io.open(verifyfile, "wb"))

  --   if verify_filetype == "nes" then
  --     --create header: pass open & empty file & rom sizes
  --     create_header(file, prg_size, chr_size)
  --   end

  --   print("DONE post dumping PRG & CHR ROMs")
  --   -- dump cart to file
  --   time.start()
  --   dump_prgrom(file, prg_size, false)
  --   if chr_size ~= 0 then
  --     dump_chrrom(file, chr_size, false)
  --   end
  --   time.report(prg_size + chr_size)

  --   -- close file
  --   assert(file:close())

  --   -- compare the flash file vs post dump file
  --   local offset
  --   if flash_filetype == "nes" then offset = 16 else offset = false end
  --   if (files.compare(verifyfile, flashfile, true, false, offset)) then
  --     print("\nSUCCESS! Flash verified")
  --   else
  --     print("\n\n\n FAILURE! Flash verification did not match")
  --   end
  -- end

  -- dict.io("IO_RESET")
end


-- global variables so other modules can use them


-- call functions desired to run when script is called/imported


-- functions other modules are able to call
jaleco_ss88006.process = process

-- return the module's table
return jaleco_ss88006
