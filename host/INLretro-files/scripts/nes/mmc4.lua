-- create the module's table
local mmc4    = {}

-- import required modules
local dict    = require "scripts.app.dict"
local nes     = require "scripts.app.nes"
local dump    = require "scripts.app.dump"
local flash   = require "scripts.app.flash"
local time    = require "scripts.app.time"
local log     = require "scripts.app.log"
local spinner = require "scripts.app.spinner"
local files   = require "scripts.app.files"
local help    = require "scripts.app.help"

-- file constants and global variables
local mapname = "MMC4"
local prg_flash_chip
local chr_flash_chip

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
  nes.write_header(file, prg_kb, chr_kb, op_buffer[mapname], 0)
end

--disables PRG-RAM, selects Vertical mirroring
--sets up CHR-ROM flash PT0 for DATA, Commands: $5555->$1555  $2AAA->$1AAA
--sets up PRG-ROM flash DATA: $8000-9FFF, Commands: $5555->D555  $2AAA->$AAAA
--leaves $8000 control reg selected to IRQ value selected so $A000 writes don't affect banking
local function init_mapper(debug)
  --RAM is always enabled..

  --set mirroring
  dict.nes("NES_CPU_WR", 0xF000, 0x00) --bit0: 0-vert 1-horz


  --For CHR-ROM flash writes, use lower 4KB (PT0) for writing data & upper 4KB (PT1) for commands
  dict.nes("NES_CPU_WR", 0xB000, 0x02) --4KB @ PPU $0000 -> $2AAA cmd & writes
  dict.nes("NES_CPU_WR", 0xC000, 0x02) --4KB @ PPU $0000
  dict.nes("NES_CPU_WR", 0xD000, 0x05) --4KB @ PPU $1000 -> $5555 cmd
  dict.nes("NES_CPU_WR", 0xE000, 0x05) --4KB @ PPU $1000


  --can use upper 16KB $D555 for $5555 commands
  --need lower bank for $AAAA commands and writes
  --this only allows for writing to even banks when A14=0
  dict.nes("NES_CPU_WR", 0xA000, 0x00) --16KB @ CPU $8000

  --mapper control A14-18
  --even bank A14 = 0
  --odd  bank A14 = 1
  --$8000-BFFF bank selected
  --$C000-FFFF fixed to last 16KB (A14 always high)
  --$C000-DFFF A14 is low
  --$E000-FFFF A14 is high
  --ROM A14 = MAP assign A14 XOR with CPU A13
  --With this mapper modification $5555 -> $D555, $2AAA -> $EAAA
end

-- test the mapper's mirroring modes to verify working properly
-- can be used to help identify board: returns true if pass, false if failed
local function mirror_test(debug)
  --put mapper in known state (mirror bits cleared)
  init_mapper()

  --Vertical
  --dict.nes("NES_CPU_WR", 0xF000, 0x00)  --bit0: 0-vert 1-horz
  if nes.detect_mapper_mirroring(debug) ~= "VERT" then
    log.error("Vertical mirroring test failed")
    return false
  else
    log.success("Vertical mirroring test passed")
  end

  --Horizontal
  dict.nes("NES_CPU_WR", 0xF000, 0x01) --bit0: 0-vert 1-horz
  if nes.detect_mapper_mirroring(debug) ~= "HORZ" then
    log.error("Horizontal mirroring test failed")
    return false
  else
    log.success("Horizontal mirroring test passed")
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

--- Program one byte to PRG-ROM flash and poll for completion.
-- @param addr integer Address to program
-- @param value integer 8-bit value to write
-- @param bank integer Mapper bank value selecting the target flash bank
-- @param debug? boolean Enable verbose progress logging
local function wr_prg_flash_byte(addr, value, bank, debug)
  if (addr < 0x8000 or addr > 0xBFFF) then
    log.error("ERROR! flash write to PRG-ROM", help.hex_0x4(addr), "must be $8000-BFFF")
    return
  end

  --select bank
  dict.nes("NES_CPU_WR", 0xA000, bank)

  --send unlock command and write byte
  --dict.nes("NES_CPU_WR", 0xD555, 0xAA)
  --dict.nes("NES_CPU_WR", 0xAAAA, 0x55)
  --dict.nes("NES_CPU_WR", 0xD555, 0xA0)
  dict.nes("NES_CPU_WR", 0xFAAA, 0xAA)
  dict.nes("NES_CPU_WR", 0xF555, 0x55)
  dict.nes("NES_CPU_WR", 0xFAAA, 0xA0)
  dict.nes("NES_CPU_WR", addr, value) --if this write was $A000-AFFF it will also corrupt the bank

  --recover bank
  dict.nes("NES_CPU_WR", 0xA000, bank)

  local rv = dict.nes("NES_CPU_RD", addr)

  local i = 0

  while rv ~= dict.nes("NES_CPU_RD", addr) do
    rv = dict.nes("NES_CPU_RD", addr)
    i = i + 1
  end

  if debug then
    log.info("Done writing byte,", i .. " naks")
  end

  --TODO handle timeout for problems

  --TODO return pass/fail/info
end

--- Dump PRG-ROM contents to an already-open output file.
-- @param file file* Open binary output file
-- @param rom_size_kb integer PRG-ROM size in kilobytes
-- @param debug? boolean Enable verbose progress logging
local function prg_rom_dump(file, rom_size_kb, debug)
  -- PRG-ROM dump 16KB at a time
  local kb_per_read = 16
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

    --select desired bank(s) to dump
    dict.nes("NES_CPU_WR", 0xA000, cur_bank) -- 16KB @ CPU $8000

    dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NESCPU_PAGE" }, false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--- Erase the entire PRG-ROM flash chip and poll until consecutive reads match.
local function prg_rom_erase()
  local i = 0
  local rv

  init_mapper()

  log.section("Erasing PRG-ROM")

  --PLCC
  dict.nes("NES_CPU_WR", 0xD555, 0xAA)
  dict.nes("NES_CPU_WR", 0xEAAA, 0x55)
  dict.nes("NES_CPU_WR", 0xD555, 0x80)
  dict.nes("NES_CPU_WR", 0xD555, 0xAA)
  dict.nes("NES_CPU_WR", 0xEAAA, 0x55)
  dict.nes("NES_CPU_WR", 0xD555, 0x10)

  --SOP
  --dict.nes("NES_CPU_WR", 0xFAAA, 0xAA)
  --dict.nes("NES_CPU_WR", 0xF555, 0x55)
  --dict.nes("NES_CPU_WR", 0xFAAA, 0x80)
  --dict.nes("NES_CPU_WR", 0xFAAA, 0xAA)
  --dict.nes("NES_CPU_WR", 0xF555, 0x55)
  --dict.nes("NES_CPU_WR", 0xFAAA, 0x10)

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
end

--- Program PRG-ROM contents from an already-open input file, one bank at a time.
-- @param file file* Open binary input file
-- @param rom_size_kb integer PRG-ROM size in kilobytes
-- @param debug? boolean Enable verbose progress logging
local function prg_rom_flash(file, rom_size_kb, debug)
  init_mapper()

  log.section("Programming PRG-ROM")
  log.info("PRG-ROM size", rom_size_kb .. "KB")


  local bank_size = 16 -- MMC4 16KByte per PRG bank
  local cur_bank = 0
  local num_banks = math.floor(rom_size_kb / bank_size)

  while cur_bank < num_banks do
    if debug then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- select desired bank, needed for first write
    dict.nes("NES_CPU_WR", 0xA000, cur_bank) -- 16KB @ CPU $8000

    -- set cur_bank for recovery and subsequent bytes
    dict.nes("SET_CUR_BANK", cur_bank)



    -- write the current bank to the mapper register
    -- DATA writes written to $8000-9FFF
    dict.nes("NES_CPU_WR", 0x8000, 0x06)
    dict.nes("NES_CPU_WR", 0x8001, cur_bank) --8KB @ CPU $8000

    -- set $8000 bank select back to a CHR register
    -- keeps from having the PRG bank changing when writing data
    dict.nes("NES_CPU_WR", 0x8000, 0x00)

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

--- Program one byte to CHR flash and poll for completion.
-- @param addr integer Address to program, 0x0000-0x0FFF
-- @param value integer 8-bit value to write
-- @param bank integer Mapper bank value selecting the target flash bank
-- @param debug? boolean Enable verbose progress logging
local function wr_chr_flash_byte(addr, value, bank, debug)
  if addr < 0x0000 or addr > 0x0FFF then
    log.error("ERROR! flash write to CHR-ROM", help.hex_0x4(addr), "must be $0000-0FFF")
    return
  end

  --set bank for unlock command
  dict.nes("NES_CPU_WR", 0xB000, 0x0A) --4KB @ PPU $0000 -> $2AAA cmd & writes
  dict.nes("NES_CPU_WR", 0xC000, 0x0A) --4KB @ PPU $0000

  --send unlock command
  dict.nes("NES_PPU_WR", 0x1555, 0xAA)
  dict.nes("NES_PPU_WR", 0x0AAA, 0x55)
  dict.nes("NES_PPU_WR", 0x1555, 0xA0)

  --select desired bank
  dict.nes("NES_CPU_WR", 0xB000, bank) --4KB @ PPU $0000 -> $2AAA cmd & writes
  dict.nes("NES_CPU_WR", 0xC000, bank) --4KB @ PPU $0000

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

--- Dump CHR contents to an already-open output file.
-- @param file file* Open binary output file
-- @param rom_size_kb integer CHR size in kilobytes
-- @param debug? boolean Enable verbose progress logging
local function chr_dump(file, rom_size_kb, debug)
  local kb_per_read = 8 -- dump both PT at once
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

    -- the bank is half the size of KB per read so must multiply by 2
    dict.nes("NES_CPU_WR", 0xB000, (cur_bank * 2)) -- 4KB @ PPU $0000
    dict.nes("NES_CPU_WR", 0xC000, (cur_bank * 2)) -- 4KB @ PPU $0000

    -- the bank is half the size of KB per read so must multiply by 2 and add 1 for second 1KB
    dict.nes("NES_CPU_WR", 0xD000, (cur_bank * 2 + 1)) -- 4KB @ PPU $1000
    dict.nes("NES_CPU_WR", 0xE000, (cur_bank * 2 + 1)) -- 4KB @ PPU $1000

    -- 4 = number of KB to dump per loop
    -- 0x00 = starting read address A10-13 -> $0000
    -- mapper must be 0x00 or 0x04-0x3C to designate A10-13
    --   bits 7, 6, 1, & 0 CAN NOT BE SET!
    --   0x04 would designate that A10 is set -> $0400 (the second 1KB PT bank)
    --   0x20 would designate that A13 is set -> $2000 (first name table)
    dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NESPPU_1KB_TOGGLE" }, false)
    -- dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NESPPU_PAGE" }, false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--- Erase the entire CHR-ROM flash chip and poll until consecutive reads match.
local function chr_rom_erase()
  local i = 0
  local rv

  init_mapper()

  log.section("Erasing CHR-ROM")
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
end

--- Program CHR contents from an already-open input file, one bank at a time.
-- @param file file* Open binary input file
-- @param rom_size_kb integer CHR size in kilobytes
-- @param debug? boolean Enable verbose progress logging
local function chr_rom_flash(file, rom_size_kb, debug)
  init_mapper()

  log.section("Programming CHR-ROM")
  log.info("CHR-ROM size", rom_size_kb .. "KB")

  local bank_size = 4 -- MMC4 4KByte CHR bank
  local cur_bank = 0
  local num_banks = math.floor(rom_size_kb / bank_size)


  local byte_num --byte number gets reset for each bank
  local byte_str, data, readdata

  while cur_bank < num_banks do
    if debug then
      log.point("writing CHR bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- set cur_bank so firmware can select desired bank during the write
    dict.nes("SET_CUR_BANK", cur_bank)

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size, { mapper = "MMC4", mem_type = "CHRROM" }, false)

    cur_bank = cur_bank + 1
  end

  print("Done Programming CHR-ROM flash")
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
-- @param debug? boolean Enable verbose progress logging
local function prg_ram_dump(file, ram_size_kb, debug)
  local kb_per_read = 8
  local num_banks = math.floor(ram_size_kb / kb_per_read)
  local cur_bank = 0
  local addr_base = 0x60 -- $6000

  log.info("PRG-RAM size", ram_size_kb .. "KB")

  while cur_bank < num_banks do
    if debug then
      log.point("dumping PRG-RAM bank ", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NESCPU_PAGE" }, false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--- Write PRG-RAM contents from an already-open input file.
-- @param file file* Open binary input file
-- @param ram_size_kb integer PRG-RAM size in kilobytes
-- @param debug? boolean Enable verbose progress logging
local function prg_ram_write(file, ram_size_kb, debug)
  init_mapper()

  log.info("PRG-RAM size", ram_size_kb .. "KB")

  local bank_size = 8
  local cur_bank = 0
  local num_banks = math.floor(ram_size_kb / bank_size)

  -- enable PRG-RAM and allow writes
  dict.nes("NES_CPU_WR", 0xA001, 0x80)

  while cur_bank < num_banks do
    if debug then
      log.point("writing PRG-RAM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    --have the device write a bank worth of data
    flash.write_file(file, bank_size, { mapper = "NOVAR", mem_type = "PRGRAM" }, false)

    cur_bank = cur_bank + 1
  end

  -- disable PRG-RAM and deny writes
  dict.nes("NES_CPU_WR", 0xA001, 0x40)

  spinner.clear()
  log.success("Done programming PRG-RAM")
end

--- Detect PRG-RAM by writing and reading back a test byte.
-- @param debug? boolean Enable verbose progress logging
-- @return boolean success True when RAM read/write behavior is detected
local function prg_ram_detect(debug)
  local read_value
  local saved_value

  log.section("Detecting PRG-RAM")

  -- enable PRG-RAM and allow writes
  dict.nes("NES_CPU_WR", 0xA001, 0x80)

  -- save potential battery backed data first
  saved_value = dict.nes("NES_CPU_RD", 0x6000)

  -- try to write and read back
  dict.nes("NES_CPU_WR", 0x6000, saved_value ~ 0xff)
  read_value = dict.nes("NES_CPU_RD", 0x6000)
  if read_value ~= (saved_value ~ 0xff) then
    return false
  end

  -- put back original value
  dict.nes("NES_CPU_WR", 0x6000, saved_value)
  read_value = dict.nes("NES_CPU_RD", 0x6000)
  if read_value ~= (saved_value) then
    return false
  end

  -- disable PRG-RAM and deny writes
  dict.nes("NES_CPU_WR", 0xA001, 0x40)

  return true
end

--- Test PRG-RAM by overwriting it with pseudo-random data and comparing the dump.
-- @param wram_size_kb integer PRG-RAM size in kilobytes
-- @param retroprog_id string Programmer identifier used in the RAM dump filename
-- @param debug? boolean Enable verbose progress logging
-- @return boolean success True when the dumped data matches the reference pattern
local function prg_ram_test(wram_size_kb, retroprog_id, debug)
  dict.stuff("RESET_LFSR") -- sets it to 1

  local cur_bank = 0
  local num_banks = math.floor(wram_size_kb / 8)

  log.section("Exercising PRG-RAM")
  log.info("PRG-RAM size", wram_size_kb .. "KB")

  -- enable PRG-RAM and allow writes
  dict.nes("NES_CPU_WR", 0xA001, 0x80)

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
  local filename = opts.write_path .. "./ignore/nes_prg_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))

  -- dump PRG-RAM
  log.point("Dumping PRG-RAM")
  prg_ram_dump(file, wram_size_kb, debug)

  -- close file
  assert(file:close())

  -- disable PRG-RAM and deny writes
  dict.nes("NES_CPU_WR", 0xA001, 0x40)

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

    -- attempt to read PRG-ROM flash ID
    if options.force_flash_test or (do_rom_write and prg_size_kb ~= 0) then
      init_mapper()
      rv, prg_flash_chip = nes.prg_rom_get_chip(DEBUG, {
        unlock_addr1 = 0xD555,
        unlock_addr2 = 0xEAAA
      })
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
      rv, chr_flash_chip = nes.chr_rom_get_chip(DEBUG, {
        unlock_addr1 = 0x1555,
        unlock_addr2 = 0x0AAA
      })
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
        elseif nes.header.is_valid and nes.header.has_prg_ram then
          log.warning("ROM header settings implies PRG-RAM")
          log.error("PRG-RAM not detected")
          return false
        elseif wram_size_kb ~= 0 then
          log.warning("CLI options specify " .. wram_size_kb .. "KB of PRG-RAM")
          log.error("PRG-RAM not detected")
          return false
        else
          log.info("PRG-RAM not detected")
        end
      end
    else -- PRG RAM found
      log.success("PRG-RAM detected")

      -- force wram size to 8KB because it's MMC3 maximum
      wram_size_kb = 8

      if options.force_wram_test and (do_rom_dump or do_ram_dump) then
        log.warning("Additional option 'force_wram_test' is ignored when dumping PRG-ROM or PRG-RAM")
      elseif do_rom_write or do_ram_write then
        if options.force_wram_test or do_ram_write then
          rv = prg_ram_test(wram_size_kb, retroprog_id, DEBUG)
          if not rv then return false end
        elseif nes.header.is_valid and nes.header.has_prg_ram then
          if nes.header.has_battery then
            log.warning("Can't test PRG-RAM because ROM header specifies battery backed data")
            log.warning("Use additional option 'force_wram_test' to force PRG-RAM test")
          else
            rv = prg_ram_test(wram_size_kb, retroprog_id, DEBUG)
            if not rv then return false end
          end
        else
          log.warning("Can't test PRG-RAM because data could be battery backed")
          log.warning("Use additional option 'force_wram_test' to force PRG-RAM test")
        end
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

    file = assert(io.open(ram_dump_file.filename, "wb"))

    -- dump cart to file
    prg_ram_dump(file, wram_size_kb, DEBUG)

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

    file = assert(io.open(ram_write_file.filename, "rb"))

    flash.write_file(file, wram_size_kb, { mapper = "NOVAR", mem_type = "PRGRAM" }, false)

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
    -- erase PRG-ROM only if needed
    if prg_size_kb ~= 0 then
      rv = nes.prg_rom_erase(prg_flash_chip, DEBUG, {
        unlock_profile_name = "long",
        unlock_addr1 = 0xD555,
        unlock_addr2 = 0xEAAA
      })
      if not rv then
        log.error("PRG-ROM couldn't be erased")
        return false
      end
    end

    -- erase CHR-ROM only if needed
    if chr_size_kb ~= 0 then
      rv = nes.chr_rom_erase(chr_flash_chip, DEBUG,
        {
          unlock_profile_name = "long",
          unlock_addr1 = 0x1555,
          unlock_addr2 = 0x0AAA
        })
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



























  --   --test cart by reading manf/prod ID
  --   if test then
  --     print("Testing ", mapname)

  --     init_mapper()

  --     --verify mirroring is behaving as expected
  --     mirror_test(true)

  --     nes.ppu_ram_sense(0x1000, true)
  --     print("EXP0 pull-up test:", dict.io("EXP0_PULLUP_TEST"))

  --     --attempt to read PRG-ROM flash ID
  --     prg_rom_manf_id(true)
  --     --attempt to read CHR-ROM flash ID
  --     if chr_size_kb ~= 0 then
  --       chr_rom_manf_id(true)
  --     end
  --   end

  --   --[[ BROKE STUDIO TESTS
  -- print "----------------------------------------"
  -- read_addr(0x6000)
  -- read_addr(0x6001)
  -- read_addr(0x6002)
  -- print "----------------------------------------"
  -- write_addr(0x6000, 0xaa)
  -- write_addr(0x6001, 0x55)
  -- write_addr(0x6002, 0xaa)
  -- print "----------------------------------------"
  -- read_addr(0x6000)
  -- read_addr(0x6001)
  -- read_addr(0x6002)
  -- do return end
  -- print "----------------------------------------"
  -- read_addr(0xfffa)
  -- read_addr(0xfffb)
  -- read_addr(0xfffc)
  -- read_addr(0xfffd)
  -- read_addr(0xfffe)
  -- read_addr(0xffff)
  -- print "----------------------------------------"
  -- write_addr(0xA000, 0xff)
  -- print "----------------------------------------"
  -- for i = 0, 15, 1 do
  --   read_addr(0xbff0+i)
  -- end

  -- do return end

  -- print "----------------------------------------"
  -- write_addr(0xA000, 0x01)
  -- print "----------------------------------------"
  -- for i = 0, 15, 1 do
  --   read_addr(0xC000+i)
  -- end
  -- print "----------------------------------------"

  -- for i = 0, 15, 1 do
  --   read_addr(0xc000+i)
  -- end

  -- do return end

  -- --]]

  --   --dump the ram to file
  --   if dumpram then
  --     print("\nDumping PRG-RAM...")

  --     init_mapper()

  --     --SRAM always enabled

  --     file = assert(io.open(ramdumpfile, "wb"))

  --     -- dump cart to file
  --     dump_wram(file, wram_size_kb, false)

  --     -- close file
  --     assert(file:close())

  --     print("DONE Dumping PRG-RAM")
  --   end



  --   --dump the cart to dumpfile
  --   if read then
  --     print("\nDumping PRG & CHR ROMs...")

  --     init_mapper()

  --     file = assert(io.open(dumpfile, "wb"))

  --     if dump_filetype == "nes" then
  --       --create header: pass open & empty file & rom sizes
  --       create_header(file, prg_size_kb, chr_size_kb)
  --     end

  --     -- dump cart to file
  --     dump_prgrom(file, prg_size_kb, false)
  --     if chr_size_kb ~= 0 then
  --       dump_chrrom(file, chr_size_kb, false)
  --     end

  --     -- close file
  --     assert(file:close())

  --     print("DONE Dumping PRG & CHR ROMs")
  --   end


  --   -- erase the cart
  --   if erase then
  --     print("\nerasing ", mapname)

  --     init_mapper()

  --     --PLCC
  --     print("erasing PRG-ROM PLCC-32")
  --     dict.nes("NES_CPU_WR", 0xD555, 0xAA)
  --     dict.nes("NES_CPU_WR", 0xEAAA, 0x55)
  --     dict.nes("NES_CPU_WR", 0xD555, 0x80)
  --     dict.nes("NES_CPU_WR", 0xD555, 0xAA)
  --     dict.nes("NES_CPU_WR", 0xEAAA, 0x55)
  --     dict.nes("NES_CPU_WR", 0xD555, 0x10)

  --     --SOP
  --     --print("erasing PRG-ROM SOP-44 flash takes a couple sec...")
  --     --dict.nes("NES_CPU_WR", 0xFAAA, 0xAA)
  --     --dict.nes("NES_CPU_WR", 0xF555, 0x55)
  --     --dict.nes("NES_CPU_WR", 0xFAAA, 0x80)
  --     --dict.nes("NES_CPU_WR", 0xFAAA, 0xAA)
  --     --dict.nes("NES_CPU_WR", 0xF555, 0x55)
  --     --dict.nes("NES_CPU_WR", 0xFAAA, 0x10)

  --     rv = dict.nes("NES_CPU_RD", 0x8000)

  --     local i = 0

  --     -- TODO create some function to pass the read value
  --     -- that's smart enough to figure out if the board is actually erasing or not
  --     while (rv ~= 0xFF) do
  --       rv = dict.nes("NES_CPU_RD", 0x8000)
  --       i = i + 1
  --     end
  --     print(i, "naks, done erasing prg.")


  --     --TODO erase CHR-ROM only if present
  --     init_mapper()

  --     print("erasing CHR-ROM")
  --     dict.nes("NES_PPU_WR", 0x1555, 0xAA)
  --     dict.nes("NES_PPU_WR", 0x0AAA, 0x55)
  --     dict.nes("NES_PPU_WR", 0x1555, 0x80)
  --     dict.nes("NES_PPU_WR", 0x1555, 0xAA)
  --     dict.nes("NES_PPU_WR", 0x0AAA, 0x55)
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

  --   --write to wram on the cart
  --   if writeram then
  --     print("\nWriting to PRG-RAM...")

  --     init_mapper()

  --     --SRAM always enabled

  --     file = assert(io.open(ramwritefile, "rb"))

  --     flash.write_file(file, wram_size_kb, { mapper = "NOVAR", mem_type = "PRGRAM" }, false)

  --     -- close file
  --     assert(file:close())

  --     print("DONE Writing PRG-RAM")
  --   end

  --   --program flashfile to the cart
  --   if program then
  --     --open file
  --     file = assert(io.open(flashfile, "rb"))
  --     --determine if auto-doubling, deinterleaving, etc,
  --     --needs done to make board compatible with rom

  --     if flash_filetype == "nes" then
  --       --advance past the 16byte header
  --       file:read(16)
  --     end

  --     flash_prgrom(file, prg_size_kb)
  --     if chr_size_kb ~= 0 then
  --       flash_chrrom(file, chr_size_kb)
  --     end

  --     -- close file
  --     assert(file:close())
  --   end

  --   -- verify flash file is on the cart
  --   if verify then
  --     --for now let's just dump the file and verify manually
  --     print("\nPost dumping PRG & CHR ROMs...")

  --     init_mapper()

  --     file = assert(io.open(verifyfile, "wb"))

  --     if verify_filetype == "nes" then
  --       --create header: pass open & empty file & rom sizes
  --       create_header(file, prg_size_kb, chr_size_kb)
  --     end

  --     print("DONE post dumping PRG & CHR ROMs")
  --     -- dump cart to file
  --     time.start()
  --     dump_prgrom(file, prg_size_kb, false)
  --     if chr_size_kb ~= 0 then
  --       dump_chrrom(file, chr_size_kb, false)
  --     end
  --     time.report(prg_size_kb + chr_size_kb)

  --     -- close file
  --     assert(file:close())

  --     -- compare the flash file vs post dump file
  --     local offset
  --     if flash_filetype == "nes" then offset = 16 else offset = false end
  --     if (files.compare(verifyfile, flashfile, true, false, offset)) then
  --       print("\nSUCCESS! Flash verified")
  --     else
  --       print("\n\n\n FAILURE! Flash verification did not match")
  --     end
  --   end

  dict.io("IO_RESET")
end

-- global variables so other modules can use them

-- call functions desired to run when script is called/imported

-- functions other modules are able to call
mmc4.process = process

-- return the module's table
return mmc4
