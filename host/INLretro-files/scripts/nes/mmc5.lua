-- create the module's table
local mmc5                = {}

-- import required modules
local dict                = require "scripts.app.dict"
local nes                 = require "scripts.app.nes"
local dump                = require "scripts.app.dump"
local flash               = require "scripts.app.flash"
local chips               = require "scripts.app.chips"
local time                = require "scripts.app.time"
local log                 = require "scripts.app.log"
local spinner             = require "scripts.app.spinner"
local files               = require "scripts.app.files"
local help                = require "scripts.app.help"

-- file constants and global variables
local mapname             = "MMC5"
local prg_flash_chip
local chr_flash_chip

-- registers
local FLASH_MODE          = 0x50FF

local PRG_MODE            = 0x5100
local CHR_MODE            = 0x5101
local PRG_RAM_PROTECT_1   = 0x5102
local PRG_RAM_PROTECT_2   = 0x5103
local EXRAM_MODE          = 0x5104
local NAMETABLE_MAPPING   = 0x5105

local PRG_BANK_0          = 0x5113
local PRG_BANK_1          = 0x5114
local PRG_BANK_2          = 0x5115
local PRG_BANK_3          = 0x5116
local PRG_BANK_4          = 0x5117

local CHR_BANK_A_0        = 0x5120
local CHR_BANK_A_1        = 0x5121
local CHR_BANK_A_2        = 0x5122
local CHR_BANK_A_3        = 0x5123
local CHR_BANK_A_4        = 0x5124
local CHR_BANK_A_5        = 0x5125
local CHR_BANK_A_6        = 0x5126
local CHR_BANK_A_7        = 0x5127
local CHR_BANK_B_0        = 0x5128
local CHR_BANK_B_1        = 0x5129
local CHR_BANK_B_2        = 0x512A
local CHR_BANK_B_3        = 0x512B
local UPPER_CHR_BANK_BITS = 0x5130

local IRQ_STATUS          = 0x5204
local MULTIPLICAND        = 0x5205
local MULTIPLIER          = 0x5206

-- local functions

--[[
██╗  ██╗███████╗██╗     ██████╗ ███████╗██████╗ ███████╗
██║  ██║██╔════╝██║     ██╔══██╗██╔════╝██╔══██╗██╔════╝
███████║█████╗  ██║     ██████╔╝█████╗  ██████╔╝███████╗
██╔══██║██╔══╝  ██║     ██╔═══╝ ██╔══╝  ██╔══██╗╚════██║
██║  ██║███████╗███████╗██║     ███████╗██║  ██║███████║
╚═╝  ╚═╝╚══════╝╚══════╝╚═╝     ╚══════╝╚═╝  ╚═╝╚══════╝

--]]

local function create_header(file, prg_kb, chr_kb)
  -- write_header(file, prg_kb, chr_kb, mapper, mirroring)
  nes.write_header(file, prg_kb, chr_kb, op_buffer[mapname], 0)
end

-- disables PRG-RAM, selects horizontal mirroring
local function init_mapper()
  -- flash mode
  nes.cpu_wr(FLASH_MODE, 0x80) -- enable flash mode + clear in-frame flag

  -- for save data safety start by disabling PRG-RAM writes
  nes.cpu_wr(PRG_RAM_PROTECT_1, 0x01) -- bits 1&0 must be '01' (ie 0x02) to allow writes to PRG-RAM
  nes.cpu_wr(PRG_RAM_PROTECT_2, 0x02) -- bits 1&0 must be '10' (ie 0x01) to allow writes to PRG-RAM

  -- set mirroring
  nes.cpu_wr(NAMETABLE_MAPPING, 0x44) -- horizontal mirroring

  -- PRG MODE
  nes.cpu_wr(PRG_MODE, 0x00) -- PRG banking mode 0 single 32KByte bank (couldn't get this to work..)
  -- nes.cpu_wr(PRG_MODE, 0x03) -- PRG banking mode 3 4x 8KB banks

  -- PRG-RAM bank
  nes.cpu_wr(PRG_BANK_0, 0x00) -- PRG-RAM bank @ $6000-7FFF (regardless of PRG mode)

  -- PRG-ROM bank
  nes.cpu_wr(PRG_BANK_4, 0x00) -- PRG-ROM bank @ $8000-FFFF (mode 0) bits 1&0 don't matter (CPU A14/13)
  -- nes.cpu_wr(PRG_BANK_1, 0x80) -- PRG-ROM bank @ $8000-9FFF (mode 3) bit7 must be set to see ROM
  -- nes.cpu_wr(PRG_BANK_2, 0x81) -- PRG-ROM bank @ $A000-BFFF (mode 3) bit7 must be set to see ROM
  -- nes.cpu_wr(PRG_BANK_3, 0x82) -- PRG-ROM bank @ $C000-DFFF (mode 3) bit7 must be set to see ROM
  -- nes.cpu_wr(PRG_BANK_4, 0x83) -- PRG-ROM bank @ $E000-FFFF (mode 3) bit7 must be set to see ROM

  -- CHR MODE
  nes.cpu_wr(0x2000, 0x00) -- 8x8 sprite mode
  -- nes.cpu_wr(CHR_MODE, 0x00) -- single 8KByte bank
  -- nes.cpu_wr(CHR_MODE, 0x02) -- four 2KByte bank (mode 2)

  nes.cpu_wr(CHR_MODE, 0x00)     -- one 8KByte bank (mode 0)
  nes.cpu_wr(CHR_BANK_A_7, 0x00) -- CHR-ROM bank @ $0000-1FFF (mode 0)

  -- CHR-ROM bank
  -- nes.cpu_wr(CHR_BANK_A_7, 0x00) -- CHR-ROM bank @ $0000-1FFF (mode 0)
  -- nes.cpu_wr(CHR_BANK_B_3, 0x00) -- CHR-ROM bank @ $0000-1FFF (mode 0 8x16 sprites)

  nes.cpu_wr(UPPER_CHR_BANK_BITS, 0x00)

  -- nes.cpu_wr(CHR_BANK_A_0, 0x00)
  -- nes.cpu_wr(CHR_BANK_A_1, 0x00)
  -- nes.cpu_wr(CHR_BANK_A_2, 0x00)
  -- nes.cpu_wr(CHR_BANK_A_3, 0x00)
  -- nes.cpu_wr(CHR_BANK_A_4, 0x00)
  -- nes.cpu_wr(CHR_BANK_A_6, 0x00)
  -- nes.cpu_wr(CHR_BANK_B_0, 0x00)
  -- nes.cpu_wr(CHR_BANK_B_1, 0x00)
  -- nes.cpu_wr(CHR_BANK_B_2, 0x00)
  -- nes.cpu_wr(CHR_BANK_B_3, 0x00)

  -- nes.cpu_wr(CHR_BANK_A_5, 0x0A) -- CHR-ROM bank @ $1000-17FF (mode 2)
  -- nes.cpu_wr(CHR_BANK_A_7, 0x05) -- CHR-ROM bank @ $1800-1FFF (mode 2)

  -- CHR-ROM upper bank
  -- TODO
  -- nes.cpu_wr(UPPER_CHR_BANK_BITS, 0x00)
end

-- test the mapper's mirroring modes to verify working properly
-- can be used to help identify board: returns true if pass, false if failed
local function mirror_test()
  -- put mapper in known state (mirror bits cleared)
  init_mapper()
  local res

  -- $5105 = 0x44: Horizontal arrangement
  nes.cpu_wr(NAMETABLE_MAPPING, 0x44)
  res = nes.detect_mapper_mirroring()
  if res ~= "VERT" then
    log.error("Horizontal arrangement test failed")
    return false
  else
    log.success("Horizontal arrangement test passed")
  end

  -- $5105 = 0x50: Vertical arrangement
  nes.cpu_wr(NAMETABLE_MAPPING, 0x50)
  if nes.detect_mapper_mirroring() ~= "HORZ" then
    log.error("Vertical arrangement test failed")
    return false
  else
    log.success("Vertical arrangement test passed")
  end

  -- $5105 = 0x00: single screen 0
  nes.cpu_wr(NAMETABLE_MAPPING, 0x00)
  if nes.detect_mapper_mirroring() ~= "1SCRNA" then
    log.error("One screen A mirror test failed")
    return false
  else
    log.success("One screen A mirror test passed")
  end

  -- $5105 = 0x55: single screen 1
  nes.cpu_wr(NAMETABLE_MAPPING, 0x55)
  if nes.detect_mapper_mirroring() ~= "1SCRNB" then
    log.error("One screen B mirror test failed")
    return false
  else
    log.success("One screen B mirror test passed")
  end

  -- TODO fancy MMC5 other mirroring options (EXRAM etc)

  -- passed all tests
  return true
end

local function test_multiplication()
  local lo, hi
  local result

  init_mapper()

  log.section("Test Multiplication")

  math.randomseed(os.time() % 0x80000000)
  lo = math.random(255)
  hi = math.random(255)
  result = lo * hi

  log.info(lo, "x", hi)

  nes.cpu_wr(MULTIPLICAND, lo)
  nes.cpu_wr(MULTIPLIER, hi)

  lo = nes.cpu_rd(MULTIPLICAND)
  hi = nes.cpu_rd(MULTIPLIER)

  if (result ~= (hi << 8) | lo) then
    log.error("Multiplication test failed")
  else
    log.success("Multiplication test passed")
  end
end

--[[
██████╗ ██████╗  ██████╗       ██████╗  ██████╗ ███╗   ███╗
██╔══██╗██╔══██╗██╔════╝       ██╔══██╗██╔═══██╗████╗ ████║
██████╔╝██████╔╝██║  ███╗█████╗██████╔╝██║   ██║██╔████╔██║
██╔═══╝ ██╔══██╗██║   ██║╚════╝██╔══██╗██║   ██║██║╚██╔╝██║
██║     ██║  ██║╚██████╔╝      ██║  ██║╚██████╔╝██║ ╚═╝ ██║
╚═╝     ╚═╝  ╚═╝ ╚═════╝       ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝

--]]

--- Dump PRG-ROM contents to an already-open output file.
-- @param file file* Open binary output file
-- @param rom_size_kb integer PRG-ROM size in kilobytes
local function prg_rom_dump(file, rom_size_kb)
  -- PRG-ROM dump 32KB at a time through $5117 in mode 0
  -- above didn't work, dump 8KB at at time through $5114 in mode 3
  -- PRG-ROM dump 32KB at a time
  -- using PRG mode 0
  local kb_per_read = 32
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

    -- select desired bank to dump
    nes.cpu_wr(PRG_BANK_4, ((cur_bank << 2)|0x80)) -- 32KB & CPU $8000 (bits0&1 don't matter)
    -- above didn't work, only saw the last 8KB repeated...
    -- nes.cpu_wr(PRG_BANK_1, (cur_bank | 0x80)) -- 8KB & CPU $8000 (bit7 must be set to see ROM)

    dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NES_CPU_PAGE" })

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

  local bank_size_kb = 32 -- 32KByte per PRG bank
  local cur_bank = 0
  local num_banks = math.floor(rom_size_kb / bank_size_kb)

  -- local byte_num -- byte number gets reset for each bank
  -- local byte_str, data, readdata

  local options
  if prg_flash_chip.buffer == true then
    options = "USE_BUFFER"
    log.info("Using buffer programming")
  elseif prg_flash_chip.unlock_bypass == true then
    options = "USE_UNLOCK_BYPASS"
    log.info("Using unlock bypass mode")
  end

  while cur_bank < num_banks do
    if DEBUG then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- select desired bank to dump
    nes.cpu_wr(PRG_BANK_4, cur_bank << 2) -- 32KB & CPU $8000 (bits0&1&7 don't matter)
    -- write the current bank to the mapper register
    -- nes.cpu_wr(PRG_BANK_1, (cur_bank | 0x80)) -- 8KB @ CPU $8000

    -- flash data

    --[[  This version of the code programs a single byte at a time but doesn't require
    --  MMC3 specific functions in the firmware
    print("This is slow as molasses, but gets the job done")
    byte_num = 0  -- current byte within the bank
    while byte_num < bank_size_kb do

      -- read next byte from the file and convert to binary
      byte_str = file:read(buff_size)
      data = string.unpack("B", byte_str, 1)

      -- write the data
      -- SLOWEST OPTION: no firmware MMC3 specific functions 100% host flash algo:
      -- wr_prg_flash_byte(base_addr+byte_num, data, false)   -- 0.7KBps

      -- EASIEST FIRMWARE SPEEDUP: 5x faster, create MMC3 write byte function:
      dict.nes("RNBW_PRG_FLASH_WR", base_addr+byte_num, data)  -- 3.8KBps (5.5x faster than above)
      -- NEXT STEP: firmware write page/bank function can use function pointer for the function above
      --  this may cause issues with more complex algos
      --  sometimes cur bank is needed
      --  for this to work, need to have function post conditions meet the preconditions
      --  that way host intervention is only needed for bank controls
      --  Is there a way to allow for double buffering though..?
      --  YES!  just think of the bank as a complete memory
      --  this greatly simplifies things and is exactly where we want to go
      --  This is completed below outside the byte while loop @ 39KBps

      if (verify) then
        readdata = nes.cpu_rd(base_addr+byte_num)
        if readdata ~= data then
          print("ERROR flashing byte number", byte_num, " in bank",cur_bank, " to flash ", data, readdata)
        end
      end

      byte_num = byte_num + 1
    end
    --]]

    -- flash data
    flash.write_file(file, bank_size_kb, { mapper = "RNBW", mem_type = "NES_PRG_ROM", options = options })

    cur_bank = cur_bank + 1
  end

  -- -- exit unlock bypass mode
  -- nes.cpu_wr(0x8000, 0x90)
  -- nes.cpu_wr(0x8000, 0x00)

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

local function test_chr_banks(retroprog_id)
  init_mapper()

  local rv
  local bank

  log.section("Test CHR banks")

  nes.cpu_rd(IRQ_STATUS)

  nes.cpu_wr(CHR_MODE, 0x00) -- 1 8KByte bank (mode 0)

  nes.cpu_wr(CHR_BANK_A_0, 0xff)
  nes.cpu_wr(CHR_BANK_A_1, 0xff)
  nes.cpu_wr(CHR_BANK_A_2, 0xff)
  nes.cpu_wr(CHR_BANK_A_3, 0xff)
  nes.cpu_wr(CHR_BANK_A_4, 0xff)
  nes.cpu_wr(CHR_BANK_A_5, 0xff)
  nes.cpu_wr(CHR_BANK_A_6, 0xff)
  nes.cpu_wr(CHR_BANK_A_7, 0xff)
  nes.cpu_wr(CHR_BANK_B_0, 0xff)
  nes.cpu_wr(CHR_BANK_B_1, 0xff)
  nes.cpu_wr(CHR_BANK_B_2, 0xff)
  nes.cpu_wr(CHR_BANK_B_3, 0xff)

  for i = 0, 1, 1 do            -- 255
    bank = i * 8
    nes.cpu_wr(CHR_BANK_A_7, i) -- CHR-ROM bank @ $0000-1FFF (mode 0)
    -- nes.cpu_wr(CHR_BANK_A_0, i)
    nes.cpu_rd(CHR_BANK_A_7)
    rv = nes.ppu_rd(0x03ff)
    if (rv ~= bank + 0) then log.error("ERROR") end
    rv = nes.ppu_rd(0x07ff)
    if (rv ~= bank + 1) then log.error("ERROR") end
    rv = nes.ppu_rd(0x0bff)
    if (rv ~= bank + 2) then log.error("ERROR") end
    rv = nes.ppu_rd(0x0fff)
    if (rv ~= bank + 3) then log.error("ERROR") end
    rv = nes.ppu_rd(0x1000)
    rv = nes.ppu_rd(0x13ff)
    if (rv ~= bank + 4) then log.error("ERROR") end
    rv = nes.ppu_rd(0x17ff)
    if (rv ~= bank + 5) then log.error("ERROR") end
    rv = nes.ppu_rd(0x1bff)
    if (rv ~= bank + 6) then log.error("ERROR") end
    rv = nes.ppu_rd(0x1fff)
    if (rv ~= bank + 7) then log.error("ERROR") end
    log.print()
  end

  do return end


  nes.cpu_wr(CHR_MODE, 0x03)    -- 8 1KByte bank (mode 3)

  for i = 0, 15, 1 do           -- 255
    nes.cpu_wr(CHR_BANK_A_0, i) -- CHR-ROM bank @ $0000-03FF (mode 3)
    -- nes.cpu_wr(CHR_BANK_A_0, i)
    nes.cpu_rd(CHR_BANK_A_0)
    nes.ppu_rd(0x03ff)
    -- log.print()
  end
end

--- Dump CHR contents to an already-open output file.
-- @param file file* Open binary output file
-- @param rom_size_kb integer CHR size in kilobytes
local function chr_dump(file, rom_size_kb)
  local kb_per_read = 8
  local num_banks = math.floor(rom_size_kb / kb_per_read)
  local addr_base = 0x00 -- $0000
  local cur_bank = 0

  log.info("CHR size", rom_size_kb .. "KB")

  while cur_bank < num_banks do
    if DEBUG then
      log.point("dump CHR bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- CHR-ROM bank
    nes.cpu_wr(CHR_BANK_A_7, cur_bank) -- CHR-ROM bank @ $0000-1FFF (mode 0)
    -- nes.cpu_wr(CHR_BANK_B_3, cur_bank) -- CHR-ROM bank @ $0000-1FFF (mode 0 8x16 sprites)

    -- nes.cpu_wr(CHR_BANK_A_1, cur_bank * 2) -- CHR-ROM bank @ $0000-07FF (mode 2)
    -- nes.cpu_wr(CHR_BANK_A_3, cur_bank * 2 + 1) -- CHR-ROM bank @ $0800-0FFF (mode 2)

    dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NES_PPU_1KB_TOGGLE" })

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

  local bank_size_kb = 8 -- 8KByte per CHR bank
  local cur_bank = 0
  local num_banks = math.floor(rom_size_kb / bank_size_kb)

  local options
  if prg_flash_chip.buffer == true then
    options = "USE_BUFFER"
    log.info("Using buffer programming")
  elseif prg_flash_chip.unlock_bypass == true then
    options = "USE_UNLOCK_BYPASS"
    log.info("Using unlock bypass mode")
  end

  while cur_bank < num_banks do
    if DEBUG then
      log.point("writing CHR bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    nes.cpu_wr(CHR_BANK_A_7, cur_bank) -- CHR-ROM bank @ $0000-1FFF (mode 0)
    -- nes.cpu_wr(CHR_BANK_A_1, cur_bank * 2) -- 2KB @ PPU $0000
    -- nes.cpu_wr(CHR_BANK_A_3, cur_bank * 2 + 1) -- 2KB @ PPU $0800

    -- flash data
    --[[  This version of the code programs a single byte at a time but doesn't require
    --  MMC3 specific functions in the firmware
    print("This is slow as molasses, but gets the job done")
    byte_num = 0  -- current byte within the bank
    while byte_num < bank_size_kb do

      -- read next byte from the file and convert to binary
      byte_str = file:read(buff_size)
      data = string.unpack("B", byte_str, 1)

      -- write the data
      -- SLOWEST OPTION: no firmware MMC3 specific functions 100% host flash algo:
      -- wr_chr_flash_byte(base_addr+byte_num, data, false)  -- 0.7KBps
      -- EASIEST FIRMWARE SPEEDUP: 5x faster, create MMC3 write byte function:
      dict.nes("RNBW_CHR_FLASH_WR", base_addr+byte_num, data) -- 3.8KBps (5.5x faster than above)
      -- FASTEST have the firmware handle flashing a bank's worth of data
      -- control the init and banking from the host side

      if (verify) then
        readdata = nes.ppu_rd(base_addr+byte_num)
        if readdata ~= data then
          print("ERROR flashing byte number", byte_num, " in bank",cur_bank, " to flash ", data, readdata)
        end
      end

      byte_num = byte_num + 1
    end
    --]]

    -- flash data
    flash.write_file(file, bank_size_kb, { mapper = "RNBW", mem_type = "NES_CHR_ROM", options = options })

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
  local addr_base = 0x60 -- $6000
  local cur_bank = 0

  log.info("PRG-RAM size", ram_size_kb .. "KB")

  while cur_bank < num_banks do
    if DEBUG then
      log.point("dumping PRG-RAM bank ", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    nes.cpu_wr(PRG_BANK_0, cur_bank) -- PRG-RAM bank @ $6000-7FFF (regardless of PRG mode)

    dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NES_CPU_PAGE" })

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

local function write_ram(file, ram_size_kb)
  -- TODO
  log.error("TODO: prg_ram_write")
  do return end

  --  init_mapper()

  -- test some bytes
  -- wr_prg_flash_byte(0x0000, 0xA5, true)
  -- wr_prg_flash_byte(0x0FFF, 0x5A, true)

  print("\nProgramming PRG-RAM")
  -- initial testing of MMC3 with no specific MMC3 flash firmware functions 6min per 256KByte = 0.7KBps


  local base_addr = 0x6000   -- writes occur $6000-7FFF
  local bank_size_kb = 8     -- MMC5 8KByte per RAM bank
  local bank_size = 8 * 1024 -- MMC5 8KByte per RAM bank
  local buff_size = 1        -- number of bytes to write at a time
  local cur_bank = 0
  local num_banks = math.floor(ram_size_kb / bank_size_kb)

  local byte_num -- byte number gets reset for each bank
  local byte_str, data, readdata
  local rv
  local timout

  while cur_bank < num_banks do
    if (cur_bank % 8 == 0) then
      print("writing bank: ", cur_bank, " of ", num_banks - 1)
    end

    -- write the current bank to the mapper register
    -- DATA writes written to $6000-7FFF
    nes.cpu_wr(PRG_BANK_0, cur_bank) -- PRG-RAM bank @ $6000-7FFF (regardless of PRG mode)


    -- flash data

    -- -[[  This version of the code programs a single byte at a time but doesn't require
    --  MMC3 specific functions in the firmware
    -- print("This is slow as molasses, but gets the job done")
    byte_num = 0 -- current byte within the bank
    while byte_num < bank_size do
      -- read next byte from the file and convert to binary
      byte_str = file:read(buff_size)
      data = string.unpack("B", byte_str, 1)

      -- write the data
      -- SLOWEST OPTION: no firmware MMC3 specific functions 100% host flash algo:
      -- wr_prg_flash_byte(base_addr+byte_num, data, false)   -- 0.7KBps

      -- need to quickly write the byte after unlocking the PRG-RAM
      -- before the 11.2usec timeout happens
      rv = dict.nes("MMC5_PRG_RAM_WR", base_addr + byte_num, data) -- 3.8KBps (5.5x faster than above)

      if (rv == data) then
        -- write succeeded
        timeout = 0
      else
        print("PRG-RAM byte failed to write, retrying")
        rv = dict.nes("MMC5_PRG_RAM_WR", base_addr + byte_num, data) -- 3.8KBps (5.5x faster than above)
        if (rv ~= data) then
          print("FAILED on RETRY...")
        end
      end

      byte_num = byte_num + 1
    end
    --]]

    -- flash data
    -- FAST!  13sec for 512KB = 39KBps
    -- flash.write_file(file, bank_size_kb/1024, { mapper = mapname, mem_type = "NES_PRG_ROM" })
    -- flash.write_file(file, bank_size_kb/1024, { mapper = "NOVAR", mem_type = "NES_PRG_RAM" })

    cur_bank = cur_bank + 1
  end

  print("Done Programming PRG-RAM")
end

--- Detect PRG-RAM by writing and reading back a test byte.
-- @return boolean success True when RAM read/write behavior is detected
local function prg_ram_test()
  local test = true
  local read_value
  local saved_value

  log.section("Detecting PRG-RAM")

  -- disable write protection
  nes.cpu_wr(PRG_RAM_PROTECT_1, 0x02) -- bits 1&0 must be '10' (ie 0x02) to allow writes to PRG-RAM
  nes.cpu_wr(PRG_RAM_PROTECT_2, 0x01) -- bits 1&0 must be '01' (ie 0x01) to allow writes to PRG-RAM

  -- set bank
  nes.cpu_wr(PRG_BANK_0, 0x00)

  -- save potential battery backed data first
  saved_value = nes.cpu_rd(0x6000)

  -- try to write and read back
  nes.cpu_wr(0x6000, saved_value ~ 0xff)
  read_value = nes.cpu_rd(0x6000)
  if read_value ~= (saved_value ~ 0xff) then
    test = false
  end

  if test then
    -- put back original value
    nes.cpu_wr(0x6000, saved_value)

    -- enable write protection
    nes.cpu_wr(PRG_RAM_PROTECT_1, 0x00) -- bits 1&0 must be '01' (ie 0x02) to allow writes to PRG-RAM
    nes.cpu_wr(PRG_RAM_PROTECT_2, 0x00) -- bits 1&0 must be '10' (ie 0x01) to allow writes to PRG-RAM

    -- TODO: maybe check if it worked?
    log.success("PRG-RAM detected")
  else
    log.error("PRG-RAM not detected")
  end

  return test
end

--- Detect PRG-RAM size by writing bank markers and reading them back.
-- Overwrites the test byte in each probed bank.
-- @return integer size_kb Detected PRG-RAM size in kilobytes, or 0 when detection fails
local function prg_ram_get_size()
  -- PRG-RAM can be maximum 128KB
  -- so we'll check sixteen (16) 8K banks and see if we can write to each

  local prg_ram_size_kb = 128 -- let's use 32K as default value for now
  local num_banks = math.floor(prg_ram_size_kb / 8)
  local cur_bank = num_banks - 1

  log.section("Detecting PRG-RAM size")

  -- disable write protection
  nes.cpu_wr(PRG_RAM_PROTECT_1, 0x02) -- bits 1&0 must be '10' (ie 0x02) to allow writes to PRG-RAM
  nes.cpu_wr(PRG_RAM_PROTECT_2, 0x01) -- bits 1&0 must be '01' (ie 0x01) to allow writes to PRG-RAM

  -- write to banks backwards
  while cur_bank >= 0 do
    if DEBUG then
      log.point("trying to write to PRG-RAM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Writing", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    nes.cpu_wr(PRG_BANK_0, cur_bank)

    -- write data
    nes.cpu_wr(0x6000, cur_bank)

    cur_bank = cur_bank - 1
  end

  spinner.clear()

  -- read back only last bank
  nes.cpu_wr(PRG_BANK_0, num_banks - 1)
  prg_ram_size_kb = (nes.cpu_rd(0x6000) + 1) * 8

  -- enable write protection
  nes.cpu_wr(PRG_RAM_PROTECT_1, 0x00) -- bits 1&0 must be '01' (ie 0x02) to allow writes to PRG-RAM
  nes.cpu_wr(PRG_RAM_PROTECT_2, 0x00) -- bits 1&0 must be '10' (ie 0x01) to allow writes to PRG-RAM

  if prg_ram_size_kb >= 0 and prg_ram_size_kb <= 128 then
    log.success("PRG-RAM size detected", prg_ram_size_kb .. "KB")
    return prg_ram_size_kb
  else
    log.warning("Failed to detect PRG-RAM size")
    return 0
  end
end

--- Exercise PRG-RAM with an LFSR pattern and compare the dumped result.
-- Overwrites PRG-RAM contents with the test pattern.
-- @param wram_size_kb integer PRG-RAM size in kilobytes
-- @param retroprog_id string|integer Identifier used in the temporary dump filename
-- @return boolean success True when the PRG-RAM dump matches the expected LFSR data
local function prg_ram_exercise(wram_size_kb, retroprog_id)
  if wram_size_kb == 0 or wram_size_kb == nil then
    log.error("PRG-RAM size invalid")
    return false
  end

  dict.stuff("RESET_LFSR") -- sets it to 1

  local cur_bank = 0
  local num_banks = math.floor(wram_size_kb / 8)

  log.section("Exercising PRG-RAM")
  log.info("PRG-RAM size", wram_size_kb .. "KB")

  -- disable write protection
  nes.cpu_wr(PRG_RAM_PROTECT_1, 0x02) -- bits 1&0 must be '10' (ie 0x02) to allow writes to PRG-RAM
  nes.cpu_wr(PRG_RAM_PROTECT_2, 0x01) -- bits 1&0 must be '01' (ie 0x01) to allow writes to PRG-RAM

  -- write random data to all banks
  log.point("Writing random data to PRG-RAM")
  while cur_bank < num_banks do
    if DEBUG then
      log.point("init PRG-RAM 8K bank", cur_bank, "of", num_banks - 1)
    end

    -- set bank
    nes.cpu_wr(PRG_BANK_0, cur_bank)

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

  -- enable write protection
  nes.cpu_wr(PRG_RAM_PROTECT_1, 0x00) -- bits 1&0 must be '01' (ie 0x02) to allow writes to PRG-RAM
  nes.cpu_wr(PRG_RAM_PROTECT_2, 0x00) -- bits 1&0 must be '10' (ie 0x01) to allow writes to PRG-RAM

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
███████╗██╗  ██╗██████╗  █████╗ ███╗   ███╗
██╔════╝╚██╗██╔╝██╔══██╗██╔══██╗████╗ ████║
█████╗   ╚███╔╝ ██████╔╝███████║██╔████╔██║
██╔══╝   ██╔██╗ ██╔══██╗██╔══██║██║╚██╔╝██║
███████╗██╔╝ ██╗██║  ██║██║  ██║██║ ╚═╝ ██║
╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝

--]]

-- dump the EXRAM
local function exram_dump_cpu(file)
  local addr_base = 0x5C -- $5C00

  log.info("EXRAM size", 1 .. "KB")

  if DEBUG then
    log.point("dump EXRAM bank ", 0, "of", 0)
  else
    spinner.update("Dumping", 0, "/", 0)
  end

  dump.dumptofile(file, 1, { addr_base = addr_base, mem_type = "NES_CPU_PAGE" })

  spinner.clear()
end

-- dump the EXRAM
local function exram_dump_ppu(file, addr_base)
  if addr_base == nil then
    addr_base = 0x20 -- $2000
  end

  -- log.info("EXRAM size", 1 .. "KB")

  if DEBUG then
    log.point("dump EXRAM bank ", 0, "of", 0)
  else
    spinner.update("Dumping", 0, "/", 0)
  end

  dump.dumptofile(file, 1, { addr_base = addr_base, mem_type = "NES_PPU_1KB_TOGGLE" })

  spinner.clear()
end

local function exram_exercise_mode0_1_cpu_ppu(retroprog_id, mode)
  local addr
  local filename, file, goodfile
  local test = true

  -- set EXRAM mode
  nes.cpu_wr(EXRAM_MODE, mode & 1)

  -- set Nametable mapping
  nes.cpu_wr(NAMETABLE_MAPPING, 0xAA) -- EXRAM

  -- flash mode
  nes.cpu_wr(FLASH_MODE, 0xC0) -- enable flash mode + set in-frame flag

  log.section("Exercising EXRAM (mode " .. mode .. ") - CPU writes / PPU reads")

  -- open file
  filename = opts.write_path .. "./ignore/nes_exram_dump_ppu-" .. retroprog_id .. ".bin"
  file = assert(io.open(filename, "wb"))

  dict.stuff("RESET_LFSR") -- sets it to 1

  for nt = 0, 3, 1 do
    -- write random data
    log.point("Writing random data to EXRAM (CPU)")

    addr = 0x5C00
    while (addr < 0x6000) do
      dict.nes("CPU_PAGE_WR_LFSR", addr)
      addr = addr + 256
    end

    -- dump EXRAM
    addr = 0x20 + nt * 4
    log.point("Dumping EXRAM (PPU) @ " .. help.hex_0x2(addr) .. "00")
    file:seek("set")
    exram_dump_ppu(file, addr)
    file:flush()

    -- re-open & compare dump with known lsfr bitstream
    goodfile = opts.lua_path .. "./ignore/lfsr_32KB.bin"

    -- compare the flash file vs post dump file
    if not files.compare(filename, goodfile, false, 0, nt * 0x400) then
      test = false
      break
    end
  end

  nes.cpu_wr(FLASH_MODE, 0x80) -- enable flash mode + clear in-frame flag
  assert(file:close())
  return test
end

local function exram_exercise_mode0_1_ppu_ppu(retroprog_id, mode)
  local addr_start, addr_end
  local filename, file, goodfile
  local test = true

  -- set EXRAM mode
  nes.cpu_wr(EXRAM_MODE, mode & 1)

  -- set Nametable mapping
  nes.cpu_wr(NAMETABLE_MAPPING, 0xAA) -- EXRAM

  -- flash mode
  nes.cpu_wr(FLASH_MODE, 0xC0) -- enable flash mode + set in-frame flag

  log.section("Exercising EXRAM (mode " .. mode .. ") - PPU writes / PPU reads")

  -- open file
  filename = opts.write_path .. "./ignore/nes_exram_dump_ppu-" .. retroprog_id .. ".bin"
  file = assert(io.open(filename, "wb"))

  -- re-open & compare dump with known lsfr bitstream
  goodfile = opts.lua_path .. "./ignore/lfsr_32KB.bin"

  dict.stuff("RESET_LFSR") -- sets it to 1

  for nt = 0, 3, 1 do
    -- write random data
    log.point("Writing random data to EXRAM (PPU)")

    addr_start = 0x2000 + 1 * 0x400
    addr_end = addr_start + 0x400
    while (addr_start < addr_end) do
      dict.nes("PPU_PAGE_WR_LFSR", addr_start)
      addr_start = addr_start + 256
    end

    -- dump EXRAM
    addr_start = 0x20 + nt * 4
    log.point("Dumping EXRAM (PPU) @ " .. help.hex_0x2(addr_start) .. "00")
    file:seek("set")
    exram_dump_ppu(file, addr_start)
    file:flush()

    -- compare the flash file vs post dump file
    if not files.compare(filename, goodfile, false, 0, nt * 0x400) then
      test = false
      break
    end
  end

  nes.cpu_wr(FLASH_MODE, 0x80) -- enable flash mode + clear in-frame flag
  assert(file:close())
  return test
end

local function exram_exercise_mode2(retroprog_id)
  local addr
  local filename, file, goodfile

  log.section("Exercising EXRAM (mode 2)")

  -- set EXRAM mode - CPU R/W
  nes.cpu_wr(EXRAM_MODE, 0x02)

  -- write random data
  log.point("Writing random data to EXRAM (CPU, in-frame)")

  nes.cpu_wr(FLASH_MODE, 0xC0) -- enable flash mode + set in-frame flag

  dict.stuff("RESET_LFSR")     -- sets it to 1

  addr = 0x5C00
  while (addr < 0x6000) do
    dict.nes("CPU_PAGE_WR_LFSR", addr)
    addr = addr + 256
  end

  -- open file
  filename = opts.write_path .. "./ignore/nes_exram_dump_cpu-" .. retroprog_id .. ".bin"
  file = assert(io.open(filename, "wb"))

  -- dump EXRAM
  log.point("Dumping EXRAM")
  exram_dump_cpu(file)

  -- close file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  goodfile = opts.lua_path .. "./ignore/lfsr_32KB.bin"

  -- compare the flash file vs post dump file
  if not files.compare(filename, goodfile, false) then
    return false
  end

  -- write random data
  log.point("Writing random data to EXRAM (CPU, not in-frame)")

  nes.cpu_wr(FLASH_MODE, 0x80) -- enable flash mode + clear in-frame flag

  dict.stuff("RESET_LFSR")     -- sets it to 1

  addr = 0x5C00
  while (addr < 0x6000) do
    dict.nes("CPU_PAGE_WR_LFSR", addr)
    addr = addr + 256
  end

  -- open file
  filename = opts.write_path .. "./ignore/nes_exram_dump_cpu-" .. retroprog_id .. ".bin"
  file = assert(io.open(filename, "wb"))

  -- dump EXRAM
  log.point("Dumping EXRAM")
  exram_dump_cpu(file)

  -- close file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  goodfile = opts.lua_path .. "./ignore/lfsr_32KB.bin"

  -- compare the flash file vs post dump file
  if not files.compare(filename, goodfile, false) then
    return false
  end

  return true
end

local function exram_exercise(retroprog_id)
  local exram_ram_size = 1
  local cur_bank = 0
  local num_banks = 1
  local addr
  local rv

  -- test mode 0 cpu/ppu
  rv = exram_exercise_mode0_1_cpu_ppu(retroprog_id, 0)
  if rv then
    log.success("EXRAM test passed")
  else
    log.error("EXRAM test failed")
    return false
  end

  -- test mode 0 ppu/ppu
  rv = exram_exercise_mode0_1_ppu_ppu(retroprog_id, 0)
  if rv then
    log.success("EXRAM test passed")
  else
    log.error("EXRAM test failed")
    return false
  end

  log.warning("MODE 1 test to finish")

  -- -- test mode 1 cpu/ppu
  -- rv = exram_exercise_mode0_1_cpu_ppu(retroprog_id, 1)
  -- if rv then
  --   log.success("EXRAM test passed")
  -- else
  --   log.error("EXRAM test failed")
  --   return false
  -- end

  -- -- test mode 1 ppu/ppu
  -- rv = exram_exercise_mode0_1_ppu_ppu(retroprog_id, 1)
  -- if rv then
  --   log.success("EXRAM test passed")
  -- else
  --   log.error("EXRAM test failed")
  --   return false
  -- end

  -- test mode 2
  rv = exram_exercise_mode2(retroprog_id)
  if rv then
    log.success("EXRAM test passed")
  else
    log.error("EXRAM test failed")
    return false
  end

  -- passed all tests
  return true
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
    log.section("Testing " .. mapname)

    -- test_multiplication()
    -- test_chr_banks(retroprog_id)

    -- do return end

    -- verify mirroring is behaving as expected
    rv = mirror_test()
    if not rv then return false end

    chr_ram_detected = nes.ppu_ram_sense(0x1000)

    if options.force_flash_test or (do_rom_write and prg_size_kb ~= 0) then
      -- rv = prg_rom_manf_id()
      rv, prg_flash_chip = nes.prg_rom_get_chip()
      if not rv then
        if do_rom_write and prg_size_kb ~= 0 then
          log.error("Couldn't identify flash chip")
          return false
        else
          log.warning("Couldn't identify flash chip")
        end
      end
    end

    if options.force_flash_test or (do_rom_write and chr_size_kb ~= 0) then
      -- rv = chr_rom_manf_id()
      rv, chr_flash_chip = nes.chr_rom_get_chip()
      if not rv then
        if do_rom_write and chr_size_kb ~= 0 then
          log.error("Couldn't identify flash chip")
          return false
        else
          log.warning("Couldn't identify flash chip")
        end
      end
    end

    -- -- EXRAM tests
    rv = exram_exercise(retroprog_id)
    -- exit script if test fails
    if not rv then return end

    -- PRG-RAM tests
    rv = prg_ram_test()
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
            wram_size_kb = prg_ram_get_size()
          end
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
      prg_ram_dump(file, wram_size_kb)
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
      -- prg_ram_write(file, wram_size_kb)
      log.warning("TODO: ADD RAM WRITE SUPPORT")
      time.report(wram_size_kb)
    else
      log.error("PRG-RAM size not provided")
      return
    end

    -- close file
    assert(file:close())
  end

  -- write to wram on the cart
  if writeram then
    print("\nwriting to PRG-RAM...")

    init_mapper()

    -- disable write protection, and enable PRG-RAM
    -- for save data safety start by disabling PRG-RAM writes
    -- nes.cpu_wr(PRG_RAM_PROTECT_1, 0x02) -- bits 1&0 must be '01' (ie 0x02) to allow writes to PRG-RAM
    -- nes.cpu_wr(PRG_RAM_PROTECT_2, 0x01) -- bits 1&0 must be '10' (ie 0x01) to allow writes to PRG-RAM

    -- test with 1 Byte
    --    local addr = 0x600C
    --    local rv = nes.cpu_rd(addr)
    --    print(help.hex(addr), ":", help.hex(rv))
    --    nes.cpu_wr(addr, 0xAA)
    --    rv = nes.cpu_rd(addr)
    --    print(help.hex(addr), ":", help.hex(rv))

    --  rv = nes.cpu_rd(0x600C)
    --  print("600C:", help.hex(rv))
    --  rv = nes.cpu_rd(0x600D)
    --  print("600D:", help.hex(rv))

    file = assert(io.open(ramwritefile, "rb"))

    write_ram(file, wram_size_kb)
    -- flash.write_file(file, wram_size_kb, { mapper = "NOVAR", mem_type = "NES_PRG_RAM" })
    -- flash.write_file(file, wram_size_kb, { mapper = "MMC5", mem_type = "NES_PRG_RAM" })

    -- for save data safety disable PRG-RAM writes
    -- nes.cpu_wr(PRG_RAM_PROTECT_1, 0x01) -- bits 1&0 must be '01' (ie 0x02) to allow writes to PRG-RAM
    -- nes.cpu_wr(PRG_RAM_PROTECT_2, 0x02) -- bits 1&0 must be '10' (ie 0x01) to allow writes to PRG-RAM

    -- close file
    assert(file:close())

    print("DONE writing PRG-RAM")
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
    local i = 0

    -- erase PRG-ROM only if needed
    if prg_size_kb ~= 0 then
      init_mapper()
      log.section("Erasing PRG-ROM")
      time.start()
      nes.cpu_wr(0x8AAA, 0xAA)
      nes.cpu_wr(0x8555, 0x55)
      nes.cpu_wr(0x8AAA, 0x80)
      nes.cpu_wr(0x8AAA, 0xAA)
      nes.cpu_wr(0x8555, 0x55)
      nes.cpu_wr(0x8AAA, 0x10)

      -- TODO create some function to pass the read value
      -- that's smart enough to figure out if the board is actually erasing or not
      repeat
        rv = nes.cpu_rd(0x8000)
        spinner.update("Erasing")
        i = i + 1
      until rv == nes.cpu_rd(0x8000)

      spinner.clear()
      log.success("Done erasing PRG-ROM", i .. " naks")
      time.report(prg_size_kb)
    end

    -- erase CHR-ROM only if needed
    if chr_size_kb ~= 0 then
      init_mapper()
      log.section("Erasing CHR-ROM")
      time.start()
      nes.ppu_wr(0x1AAA, 0xAA)
      nes.ppu_wr(0x1555, 0x55)
      nes.ppu_wr(0x1AAA, 0x80)
      nes.ppu_wr(0x1AAA, 0xAA)
      nes.ppu_wr(0x1555, 0x55)
      nes.ppu_wr(0x1AAA, 0x10)

      -- TODO create some function to pass the read value
      -- that's smart enough to figure out if the board is actually erasing or not
      i = 0
      repeat
        rv = nes.ppu_rd(0x0000)
        spinner.update("Erasing")
        i = i + 1
      until rv == nes.ppu_rd(0x0000)

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
mmc5.process = process

-- return the module's table
return mmc5
