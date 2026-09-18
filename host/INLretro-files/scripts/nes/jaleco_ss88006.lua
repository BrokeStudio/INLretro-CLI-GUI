-- create the module's table
local jaleco_ss88006 = {}

-- import required modules
local dict           = require "scripts.app.dict"
local nes            = require "scripts.app.nes"
local dump           = require "scripts.app.dump"
local flash          = require "scripts.app.flash"
local time           = require "scripts.app.time"
local log            = require "scripts.app.log"
local spinner        = require "scripts.app.spinner"
local files          = require "scripts.app.files"
local help           = require "scripts.app.help"

-- file constants and global variables
local mapname        = "JALECO_SS88006"
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
  -- write_header(file, prg_kb, chr_kb, mapper, mirroring)
  nes.write_header(file, prg_kb, chr_kb, op_buffer[mapname], 0)
end

local function init_mapper(debug)
  -- set $8000 8k bank register for flashing purpose
  dict.nes("NES_CPU_WR", 0x8001, 0x00) -- hi 4 bits
  dict.nes("NES_CPU_WR", 0x8000, 0x00) -- lo 4 bits

  -- set $A000 8k bank register for flashing purpose
  dict.nes("NES_CPU_WR", 0x8003, 0x00) -- hi 4 bits
  dict.nes("NES_CPU_WR", 0x8002, 0x01) -- lo 4 bits

  -- set $C000 8k bank register for flashing purpose
  dict.nes("NES_CPU_WR", 0x9001, 0x00) -- hi 4 bits
  dict.nes("NES_CPU_WR", 0x9000, 0x02) -- lo 4 bits

  -- disable PRG-RAM and deny writes
  dict.nes("NES_CPU_WR", 0x9002, 0x00)

  -- set $1400 CHR banks for flashing purpose
  dict.nes("NES_CPU_WR", 0xC003, 0x01) -- hi 4 bits
  dict.nes("NES_CPU_WR", 0xC002, 0x05) -- lo 4 bits

  -- set $1800 CHR banks for flashing purpose
  dict.nes("NES_CPU_WR", 0xD001, 0x00) -- hi 4 bits
  dict.nes("NES_CPU_WR", 0xD000, 0x0A) -- lo 4 bits
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

--- Program one byte to PRG-ROM flash and poll for completion.
-- @param addr integer Address to program
-- @param value integer 8-bit value to write
-- @param bank integer Mapper bank value selecting the target flash bank
-- @param debug? boolean Enable verbose progress logging
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

--- Dump PRG-ROM contents to an already-open output file.
-- @param file file* Open binary output file
-- @param rom_size_kb integer PRG-ROM size in kilobytes
-- @param debug? boolean Enable verbose progress logging
local function prg_rom_dump(file, rom_size_kb, debug)
  --PRG-ROM dump 8KB at a time
  local kb_per_read = 8
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

    -- set bank
    dict.nes("NES_CPU_WR", 0x8001, (cur_bank & 0xF0) >> 4) -- hi 4 bits
    dict.nes("NES_CPU_WR", 0x8000, (cur_bank & 0x0F))      -- lo 4 bits

    -- dump data
    dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NESCPU_PAGE" }, false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--- Program PRG-ROM contents from an already-open input file, one bank at a time.
-- @param file file* Open binary input file
-- @param rom_size_kb integer PRG-ROM size in kilobytes
-- @param debug? boolean Enable verbose progress logging
local function prg_rom_flash(file, rom_size_kb, debug)
  init_mapper()

  log.section("Programming PRG-ROM")
  log.info("PRG-ROM size", rom_size_kb .. "KB")

  local bank_size = 8 -- MMC3 8KByte per PRG bank
  local cur_bank = 0
  local num_banks = math.floor(rom_size_kb / bank_size)

  while cur_bank < num_banks do
    if debug then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    dict.nes("NES_CPU_WR", 0x8001, (cur_bank & 0xF0) >> 4) -- hi 4 bits
    dict.nes("NES_CPU_WR", 0x8000, (cur_bank & 0x0F))      -- lo 4 bits

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size, { mapper = "A53_512K", mem_type = "PRGROM" }, false)
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

--- Program one byte to CHR flash and poll for completion.
-- @param addr integer Address to program, 0x0000-0x0FFF
-- @param value integer 8-bit value to write
-- @param bank integer Mapper bank value selecting the target flash bank
-- @param debug? boolean Enable verbose progress logging
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

--- Dump CHR contents to an already-open output file.
-- @param file file* Open binary output file
-- @param rom_size_kb integer CHR size in kilobytes
-- @param debug? boolean Enable verbose progress logging
local function chr_dump(file, rom_size_kb, debug)
  local kb_per_read = 4 -- dump one PT at a time
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
    dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NESPPU_PAGE" }, false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--- Program CHR contents from an already-open input file, one bank at a time.
-- @param file file* Open binary input file
-- @param rom_size_kb integer CHR size in kilobytes
-- @param debug? boolean Enable verbose progress logging
local function chr_rom_flash(file, rom_size_kb, debug)
  init_mapper()

  log.section("Programming CHR-ROM")
  log.info("CHR-ROM size", rom_size_kb .. "KB")

  local bank_size = 4 -- MMC3 2KByte per lower CHR bank and we're using 2 of them..
  local cur_bank = 0
  local num_banks = math.floor(rom_size_kb / bank_size)

  while cur_bank < num_banks do
    if debug then
      log.point("writing CHR bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
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
    flash.write_file(file, bank_size, { mapper = "MMC3", mem_type = "CHRROM" }, false)

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
  dict.nes("NES_CPU_WR", 0x9002, 0x03)

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

  -- disable PRG-RAM and deny writes
  dict.nes("NES_CPU_WR", 0x9002, 0x00)

  spinner.clear()
  log.success("Done programming PRG-RAM")
end

--- Detect PRG-RAM by writing and reading back a test byte.
-- @param debug? boolean Enable verbose progress logging
-- @return boolean success True when RAM read/write behavior is detected
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
  local filename = opts.write_path .. "./ignore/nes_prg_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))

  -- dump PRG-RAM
  log.point("Dumping PRG-RAM")
  prg_ram_dump(file, wram_size_kb, debug)

  -- close file
  assert(file:close())

  -- disable PRG-RAM and deny writes
  dict.nes("NES_CPU_WR", 0x9002, 0x00)

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

--- Detect CHR-RAM size by writing bank markers and reading them back.
-- Overwrites the test byte in each probed bank.
-- @param debug? boolean Enable verbose progress logging
-- @return integer size_kb Detected CHR-RAM size in kilobytes, or 0 when detection fails
local function chr_ram_get_size(debug)
  -- CHR-RAM can be maximum 2KB
  -- so we'll check 8 4K banks and see if we can write to each

  local chr_ram_size_kb = 8
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
-- Overwrites CHR-RAM contents with the test pattern.
-- @param chr_ram_size_kb integer CHR-RAM size in kilobytes
-- @param retroprog_id string|integer Identifier used in the temporary dump filename
-- @param debug? boolean Enable verbose compare/progress logging
-- @return boolean success True when the CHR-RAM dump matches the expected LFSR data
local function chr_ram_exercise(chr_ram_size_kb, retroprog_id, debug)
  dict.stuff("RESET_LFSR") -- sets it to 1

  local cur_bank = 0
  local num_banks = math.floor(chr_ram_size_kb / 4)

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
    if options.force_flash_test or (do_rom_write and prg_size_kb ~= 0) then
      -- mapper writes affect PRG banking /!\
      --D555 & F003 (mirror) = D001 (CHR bank)
      --AAAA & F003 (mirror) = A002 (no register)
      --D555
      rv, prg_flash_chip = nes.prg_rom_get_chip(DEBUG, { opcode = "M2_HIGH_WR" })
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
      rv, chr_flash_chip = nes.chr_rom_get_chip(DEBUG)
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

      -- force wram size to 8KB because it's SS88006 maximum
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
    prg_ram_dump(file, wram_size_kb, DEBUG)

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

    flash.write_file(file, wram_size_kb, { mapper = "NOVAR", mem_type = "PRGRAM" }, false)

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
      rv = nes.prg_rom_erase(prg_flash_chip, DEBUG)
      if not rv then
        log.error("PRG-ROM couldn't be erased")
        return false
      end
    end

    -- erase CHR-ROM only if needed
    if chr_size_kb ~= 0 then
      init_mapper()
      rv = nes.chr_rom_erase(chr_flash_chip, DEBUG)
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

  dict.io("IO_RESET")
end


-- global variables so other modules can use them


-- call functions desired to run when script is called/imported


-- functions other modules are able to call
jaleco_ss88006.process = process

-- return the module's table
return jaleco_ss88006
