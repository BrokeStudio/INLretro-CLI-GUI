-- create the module's table
local vrc6a = {}

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
local mapname = "VRC6a"

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


-- disables PRG-RAM, selects Vertical mirroring
-- sets up CHR-ROM flash PT0 for DATA, Commands: $5555->$1555  $2AAA->$1AAA
-- sets up PRG-ROM flash DATA: $8000-9FFF, Commands: $5555->D555  $2AAA->$AAAA
-- leaves $8000 control reg selected to IRQ value selected so $A000 writes don't affect banking
local function init_mapper(debug)

  -- set $8000 16k bank register for flashing purpose
  dict.nes("NES_CPU_WR", 0xC002, 0x00)  -- disable prgram flashing
  dict.nes("NES_CPU_WR", 0x8000, 0x00)

  -- set $C000 8k bank register for flashing purpose
  dict.nes("NES_CPU_WR", 0xC000, 0x02)

  -- disable PRG-RAM
  -- enable PPU banking mode 1
  dict.nes("NES_CPU_WR", 0xB003, 0x00)

  -- set $1000 and $1800 CHR banks for flashing purpose
  dict.nes("NES_CPU_WR", 0xE001, 0x15)
  dict.nes("NES_CPU_WR", 0xE002, 0x0A)
end


-- test the mapper's mirroring modes to verify working properly
-- can be used to help identify board: returns true if pass, false if failed
local function mirror_test(debug)

  log.section("Testing mirroring settings")

  -- put mapper in known state
  init_mapper()

  -- Vertical
  dict.nes("NES_CPU_WR", 0xB003, 0x20)
  if nes.detect_mapper_mirroring(debug) ~= "VERT" then
    log.error("Vertical mirroring test failed")
    return false
  else
    log.success("Vertical mirroring test passed")
  end

  --Horizontal
  dict.nes("NES_CPU_WR", 0xB003, 0x24)
  if nes.detect_mapper_mirroring(debug) ~= "HORZ" then
    log.error("Horizontal mirroring test failed")
    return false
  else
    log.success("Horizontal mirroring test passed")
  end

    -- 1 screen A
    dict.nes("NES_CPU_WR", 0xB003, 0x28)
  if nes.detect_mapper_mirroring(debug) ~= "1SCRNA" then
    log.error("One screen mirroring test failed (1 screen A)")
    return false
  else
    log.success("One screen mirroring test passed (1 screen A)")
  end

  -- 1 screen B
  dict.nes("NES_CPU_WR", 0xB003, 0x2C)
  if nes.detect_mapper_mirroring(debug) ~= "1SCRNB" then
    log.error("One screen mirroring test failed (1 screen B)")
    return false
  else
    log.success("One screen mirroring test passed (1 screen B)")
  end

  -- restore register 0xB003 value
  dict.nes("NES_CPU_WR", 0xB003, 0x00)

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

--read PRG-ROM flash ID
local function prg_rom_manf_id()

  local manufacturer_id
  local device_id
  local device_test

  init_mapper()

  log.section("Reading PRG-ROM manufacturer/device ID")


  --       15 14 13 12
  -- $8000  1  0  0  0 0000 0000 0000
  -- $C000  1  1  0  0 0000 0000 0000

  --       15 14 13 12
  -- $D555  1  1  0  1
  -- $AAAA  1  0  1  0

  --       15 14 13 12
  -- $5555  0  1  0  1  0101 0101 0101
  -- $D555  1  1  0  1  0101 0101 0101
  --        [-----] => bank C = 0x02

  --       15 14 13 12
  -- $2AAA  0  0  1  0  1010 1010 1010
  -- $AAAA  1  0  1  0  1010 1010 1010
  -- $EAAA  1  1  1  0  1010 1010 1010 nope :(
  --        [--] => bank 8 = 0x00

  --       15 14 13 12
  -- $8000  1  0  0  0  0000 0000 0000

  -- mapper writes affect PRG banking /!\
  dict.nes("NES_CPU_WR", 0x8000, 0xF0) -- force exit software

  dict.nes("NES_CPU_WR", 0xD555, 0xAA) --D555 & F003 (mirror) = D001 (CHR bank)
  dict.nes("NES_CPU_WR", 0xAAAA, 0x55) --AAAA & F003 (mirror) = A002 (no register)
  dict.nes("NES_CPU_WR", 0xD555, 0x90) --D555

  manufacturer_id = dict.nes("NES_CPU_RD", 0x8000)
  chips.display_manufacturer(manufacturer_id)

  device_id = dict.nes("NES_CPU_RD", 0x8001)
  device_test = chips.display_device(manufacturer_id, device_id)

  -- exit software
  dict.nes("NES_CPU_WR", 0x8000, 0xF0)

  -- reset $8000-$BFFF bank to 0
  dict.nes("NES_CPU_WR", 0x8000, 0xF0)

  if device_test == false then
    return false
  else
    return true
  end

end

-- write a single byte to PRG-ROM flash
-- PRE: assumes mapper is initialized and bank is selected as prescribed in mapper_init
-- REQ: addr must be in the first bank $8000-9FFF
local function prg_rom_flash_byte(addr, value, bank, debug)

  if (addr < 0x8000 or addr > 0x9FFF) then
    log.error("ERROR! flash write to PRG-ROM", help.hex_0x4(addr), "must be $8000-9FFF")
    return
  end

  -- fix address
  addr = addr & 0x7FFF
  addr = addr | 0x6000

  -- select bank
  -- dict.nes("NES_CPU_WR", 0xC002, 0x01)  --enable prgram flashing -- must be done by caller
  dict.nes("NES_CPU_WR", 0xC001, bank)

  -- send unlock command and write byte
  dict.nes("NES_CPU_WR", 0xD555, 0xAA)
  dict.nes("NES_CPU_WR", 0xAAAA, 0x55)
  dict.nes("NES_CPU_WR", 0xD555, 0xA0)
  dict.nes("NES_CPU_WR", addr, value)

  -- recover bank
  -- dict.nes("NES_CPU_WR", 0x8000, bank)

  local rv = dict.nes("NES_CPU_RD", addr)

  local i = 0

  while rv ~= dict.nes("NES_CPU_RD", addr) do
    rv = dict.nes("NES_CPU_RD", addr)
    i = i + 1
  end

  if debug then
    log.info("Done writing byte,", i .. " naks")
  end

  --dict.nes("NES_CPU_WR", 0xC002, 0x00)  --disable prgram flashing -- must be done by caller

  --TODO handle timeout for problems

  --TODO return pass/fail/info
end

-- dump the PRG ROM
local function prg_rom_dump(file, rom_size_KB, debug)

  -- PRG-ROM dump 16KB at a time
  local KB_per_read = 16
  local num_banks = rom_size_KB / KB_per_read
  local cur_bank = 0
  local addr_base = 0x80  -- $8000

  log.info("PRG-ROM size", rom_size_KB .. "KB")

  while cur_bank < num_banks do

    if debug then
      log.point("dumping PRG bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks-1)
    end

    -- select desired bank(s) to dump
    dict.nes("NES_CPU_WR", 0x8000, cur_bank) -- 16KB @ CPU $8000

    -- 16 = number of KB to dump per loop
    -- 0x08 = starting read address A12-15 -> $8000
    -- NESCPU_4KB designate mapper independent read of NES CPU address space
    -- mapper must be 0-15 to designate A12-15
    -- dump.dumptofile( file, 16, 0x08, "NESCPU_4KB", true )
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


  local bank_size = 8 -- VRC6 8KByte per PRG bank
  local cur_bank = 0
  local num_banks = math.floor(rom_size_KB/bank_size)

  -- this is a custom register
  -- that allow flashing data
  -- in the $6000-$7FFF area
  dict.nes("NES_CPU_WR", 0xC002, 0x01)  -- enable prgram flashing

  while cur_bank < num_banks do

    if debug then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks-1)
    end

    -- select desired bank, needed for first write
    dict.nes("NES_CPU_WR", 0xC001, cur_bank) --8KB @ CPU $6000

    -- set cur_bank for recovery and subsequent bytes
    dict.nes("SET_CUR_BANK", cur_bank)
    -- if debug then print("get bank:", dict.nes("GET_CUR_BANK")) end

    --have the device write a bank worth of data
    flash.write_file(file, bank_size, mapname, "PRGROM", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
  log.success("Done programming PRG-ROM")

  dict.nes("NES_CPU_WR", 0xC002, 0x02)  -- disable prgram flashing

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
local function wr_chr_flash_byte(addr, value, bank, debug)

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
  if debug then print(i, "naks, done writing byte.") end

  --TODO handle timeout for problems

  --TODO return pass/fail/info
end

-- dump CHR-ROM/RAM
local function chr_dump(file, rom_size_KB, debug)

  local KB_per_read = 4 -- 1KByte bank x 4
  local num_banks = math.floor(rom_size_KB / KB_per_read)
  local cur_bank = 0
  local addr_base = 0x00 -- $0000

  log.info("CHR size", rom_size_KB .. "KB")

  while cur_bank < num_banks do

    if debug then
      log.point("dump CHR bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks-1)
    end

    -- set 1K banks x 4
    dict.nes("NES_CPU_WR", 0xD000, (cur_bank * 4))   --1KB @ PPU $0000
    dict.nes("NES_CPU_WR", 0xD001, (cur_bank * 4 + 1)) --1KB @ PPU $0400
    dict.nes("NES_CPU_WR", 0xD002, (cur_bank * 4 + 2)) --1KB @ PPU $0800
    dict.nes("NES_CPU_WR", 0xD003, (cur_bank * 4 + 3)) --1KB @ PPU $0C00

    -- 4 = number of KB to dump per loop
    -- 0x00 = starting read address A10-13 -> $0000
    -- mapper must be 0x00 or 0x04-0x3C to designate A10-13
    --   bits 7, 6, 1, & 0 CAN NOT BE SET!
    --   0x04 would designate that A10 is set -> $0400 (the second 1KB PT bank)
    --   0x20 would designate that A13 is set -> $2000 (first name table)
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

  local bank_size = 4  -- 1KByte per lower CHR bank and we're using 4 of them..
  local cur_bank = 0
  local num_banks = math.floor(rom_size_KB / bank_size)

  while cur_bank < num_banks do

    if debug then
      log.point("writing CHR bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks-1)
    end

    -- set current 1K banks
    dict.nes("NES_CPU_WR", 0xD000, cur_bank * 4)      -- 1KB @ PPU $0000
    dict.nes("NES_CPU_WR", 0xD001, cur_bank * 4 + 1)  -- 1KB @ PPU $0400
    dict.nes("NES_CPU_WR", 0xD002, cur_bank * 4 + 2)  -- 1KB @ PPU $0800
    dict.nes("NES_CPU_WR", 0xD003, cur_bank * 4 + 3)  -- 1KB @ PPU $0C00

    -- have the device write a bank worth of data
    flash.write_file(file, 4, mapname, "CHRROM", false)

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
  log.error("TODO")
  do return end

  local bank_size = 8
  local cur_bank = 0
  local num_banks = math.floor(ram_size_KB / bank_size)

  -- enable PRG-RAM
  dict.nes("NES_CPU_WR", 0xB003, 0x80)

  while cur_bank < num_banks do

    if debug then
      log.point("writing PRG-RAM bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks-1)
    end

    --have the device write a bank worth of data
    flash.write_file(file, bank_size, "NOVAR", "PRGRAM", false )

    cur_bank = cur_bank + 1
  end

  -- disable PRG-RAM
  dict.nes("NES_CPU_WR", 0xB003, 0x00)

  spinner.clear()
  log.success("Done programming PRG-RAM")

end

-- try to detect if PRG-RAM is present
local function prg_ram_test(debug)

  local test = true
  local read_value
  local saved_value

  log.section("Detecting PRG-RAM")

  -- enable PRG-RAM
  dict.nes("NES_CPU_WR", 0xB003, 0x80)

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
  dict.nes("NES_CPU_WR", 0xB003, 0x40)

  if test then
    log.success("PRG-RAM detected")
  else
    log.error("PRG-RAM not detected")
  end

  return test

end

local function prg_ram_exercise(wram_size, retroprog_id, debug)

  dict.stuff("RESET_LFSR")  -- sets it to 1

  local cur_bank = 0
  local num_banks = math.floor(wram_size / 8)

  log.section("Exercising PRG-RAM")
  log.info("PRG-RAM size", wram_size .. "KB")

  -- enable PRG-RAM
  dict.nes("NES_CPU_WR", 0xB003, 0x80)

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
  local filename = opts.lua_path .. "ignore/nes_prg_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))

  -- dump PRG-RAM
  log.point("Dumping PRG-RAM")
  prg_ram_dump(file, wram_size, debug)

  -- close file
  assert(file:close())

  -- disable PRG-RAM
  dict.nes("NES_CPU_WR", 0xB003, 0x00)

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "ignore/lfsr_32KB.bin"

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

    --the bank is half the size of KB per read so must multiply by 2
    --but bit0 isn't used with these 2KB banks, so shift by 1
    dict.nes("NES_CPU_WR", 0x8000, 0x00)
    dict.nes("NES_CPU_WR", 0x8001, ((cur_bank*2)<<1))   -- 2KB @ PPU $0000

    --the bank is half the size of KB per read so must multiply by 2 and add 1 for second 4KB
    --but bit0 isn't used with these 2KB banks, so shift by 1
    dict.nes("NES_CPU_WR", 0x8000, 0x01)
    dict.nes("NES_CPU_WR", 0x8001, ((cur_bank*2+1)<<1)) -- 2KB @ CPU $0800

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
  local filename = opts.lua_path .. "ignore/nes_chr_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))
  log.point("Dumping CHR-RAM")
  chr_dump(file, chr_ram_size, debug)

  -- close the file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "ignore/lfsr_32KB.bin"

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
    rv = prg_ram_test(DEBUG)
    if rv == true then
      if options.force_wram_test then
        log.print()
        log.warning("Flag 'force_wram_test' enabled")
      end
      -- force wram size to 8KB
      if wram_size == 0 then
        wram_size = 8
      end
      if options.force_wram_test or nes.header.isValid then
        if not options.force_wram_test and nes.header.hasBattery ~= 0 then
          log.print()
          log.warning("Can't exercise PRG-RAM because NES ROM has battery backed data")
        else
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

      log.error("TODO: CHR-RAM tests...")
      do return end

      -- force size to 8KB
      chr_ram_size = 8

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

    -- enable PRG-RAM
    dict.nes("NES_CPU_WR", 0xB003, 0x80)

    file = assert(io.open(ram_dump_file.filename, "wb"))

    -- dump cart to file
    prg_ram_dump(file, wram_size, DEBUG)

    -- disable PRG-RAM
    dict.nes("NES_CPU_WR", 0xB003, 0x00)

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
    dict.nes("NES_CPU_WR", 0xB003, 0x80)

    file = assert(io.open(ram_write_file.filename, "rb"))

    flash.write_file( file, wram_size, "NOVAR", "PRGRAM", false )

    -- disable PRG-RAM
    dict.nes("NES_CPU_WR", 0xB003, 0x00)

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
end


-- global variables so other modules can use them


-- call functions desired to run when script is called/imported


-- functions other modules are able to call
vrc6a.process = process

-- return the module's table
return vrc6a
