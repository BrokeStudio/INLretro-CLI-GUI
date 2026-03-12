-- create the module's table
local mmc5    = {}

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
local mapname = "MMC5"

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

-- disables PRG-RAM, selects horizontal mirroring
local function init_mapper(debug)
  -- flash mode
  dict.nes("NES_CPU_WR", 0x50FF, 0x80) -- enable flash mode + clear in-frame flag

  -- for save data safety start by disabling PRG-RAM writes
  dict.nes("NES_CPU_WR", 0x5102, 0x01) -- bits 1&0 must be '01' (ie 0x02) to allow writes to PRG-RAM
  dict.nes("NES_CPU_WR", 0x5103, 0x02) -- bits 1&0 must be '10' (ie 0x01) to allow writes to PRG-RAM

  -- set mirroring
  dict.nes("NES_CPU_WR", 0x5105, 0x44) -- horizontal mirroring

  -- PRG MODE
  dict.nes("NES_CPU_WR", 0x5100, 0x00) -- PRG banking mode 0 single 32KByte bank (couldn't get this to work..)
  -- dict.nes("NES_CPU_WR", 0x5100, 0x03) -- PRG banking mode 3 4x 8KB banks

  -- PRG-RAM bank
  dict.nes("NES_CPU_WR", 0x5113, 0x00) -- PRG-RAM bank @ $6000-7FFF (regardless of PRG mode)

  -- PRG-ROM bank
  dict.nes("NES_CPU_WR", 0x5117, 0x00) -- PRG-ROM bank @ $8000-FFFF (mode 0) bits 1&0 don't matter (CPU A14/13)
  -- dict.nes("NES_CPU_WR", 0x5114, 0x80) -- PRG-ROM bank @ $8000-9FFF (mode 3) bit7 must be set to see ROM
  -- dict.nes("NES_CPU_WR", 0x5115, 0x81)  -- PRG-ROM bank @ $A000-BFFF (mode 3) bit7 must be set to see ROM
  -- dict.nes("NES_CPU_WR", 0x5116, 0x82)  -- PRG-ROM bank @ $C000-DFFF (mode 3) bit7 must be set to see ROM
  -- dict.nes("NES_CPU_WR", 0x5117, 0x83)  -- PRG-ROM bank @ $E000-FFFF (mode 3) bit7 must be set to see ROM

  -- CHR MODE
  dict.nes("NES_CPU_WR", 0x2000, 0x00) -- 8x8 sprite mode
  -- dict.nes("NES_CPU_WR", 0x5101, 0x00)  -- single 8KByte bank
  -- dict.nes("NES_CPU_WR", 0x5101, 0x02) -- four 2KByte bank (mode 2)

  dict.nes("NES_CPU_WR", 0x5101, 0x00) -- one 8KByte bank (mode 0)
  dict.nes("NES_CPU_WR", 0x5127, 0x00) -- CHR-ROM bank @ $0000-1FFF (mode 0)

  -- CHR-ROM bank
  -- dict.nes("NES_CPU_WR", 0x5127, 0x00)  -- CHR-ROM bank @ $0000-1FFF (mode 0)
  -- dict.nes("NES_CPU_WR", 0x512B, 0x00)  -- CHR-ROM bank @ $0000-1FFF (mode 0 8x16 sprites)

  dict.nes("NES_CPU_WR", 0x5130, 0x00) -- Upper CHR Bank bits

  -- dict.nes("NES_CPU_WR", 0x5120, 0x00)
  -- dict.nes("NES_CPU_WR", 0x5121, 0x00)
  -- dict.nes("NES_CPU_WR", 0x5122, 0x00)
  -- dict.nes("NES_CPU_WR", 0x5123, 0x00)
  -- dict.nes("NES_CPU_WR", 0x5124, 0x00)
  -- dict.nes("NES_CPU_WR", 0x5126, 0x00)
  -- dict.nes("NES_CPU_WR", 0x5128, 0x00)
  -- dict.nes("NES_CPU_WR", 0x5129, 0x00)
  -- dict.nes("NES_CPU_WR", 0x512A, 0x00)
  -- dict.nes("NES_CPU_WR", 0x512B, 0x00)

  -- dict.nes("NES_CPU_WR", 0x5125, 0x0A) -- CHR-ROM bank @ $1000-17FF (mode 2)
  -- dict.nes("NES_CPU_WR", 0x5127, 0x05) -- CHR-ROM bank @ $1800-1FFF (mode 2)

  -- CHR-ROM upper bank
  -- TODO
  -- dict.nes("NES_CPU_WR", 0x5130, 0x00)
end

-- test the mapper's mirroring modes to verify working properly
-- can be used to help identify board: returns true if pass, false if failed
local function mirror_test(debug)
  -- put mapper in known state (mirror bits cleared)
  init_mapper()
  local res

  -- $5105 = 0x44: Horizontal arrangement
  dict.nes("NES_CPU_WR", 0x5105, 0x44)
  res = nes.detect_mapper_mirroring(debug)
  if res ~= "VERT" then
    log.error("Horizontal arrangement test failed")
    return false
  else
    log.success("Horizontal arrangement test passed")
  end

  -- $5105 = 0x50: Vertical arrangement
  dict.nes("NES_CPU_WR", 0x5105, 0x50)
  if nes.detect_mapper_mirroring(debug) ~= "HORZ" then
    log.error("Vertical arrangement test failed")
    return false
  else
    log.success("Vertical arrangement test passed")
  end

  -- $5105 = 0x00: single screen 0
  dict.nes("NES_CPU_WR", 0x5105, 0x00)
  if nes.detect_mapper_mirroring(debug) ~= "1SCRNA" then
    log.error("One screen A mirror test failed")
    return false
  else
    log.success("One screen A mirror test passed")
  end

  -- $5105 = 0x55: single screen 1
  dict.nes("NES_CPU_WR", 0x5105, 0x55)
  if nes.detect_mapper_mirroring(debug) ~= "1SCRNB" then
    log.error("One screen B mirror test failed")
    return false
  else
    log.success("One screen B mirror test passed")
  end

  -- TODO fancy MMC5 other mirroring options (EXRAM etc)

  -- passed all tests
  return true
end

local function text_multiplication(debug)
  local lo, hi
  local result

  init_mapper()

  log.section("Test Multiplication")

  math.randomseed(os.time() % 0x80000000)
  lo = math.random(255)
  hi = math.random(255)
  result = lo * hi

  log.info(lo, "x", hi)

  dict.nes("NES_CPU_WR", 0x5205, lo)
  dict.nes("NES_CPU_WR", 0x5206, hi)

  lo = dict.nes("NES_CPU_RD", 0x5205)
  hi = dict.nes("NES_CPU_RD", 0x5206)

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

-- read PRG-ROM flash ID
local function prg_rom_manf_id()
  local manufacturer_id
  local device_id
  local device_test

  init_mapper()

  log.section("Reading PRG-ROM manufacturer/device ID")

  -- exit software
  dict.nes("NES_CPU_WR", 0x8000, 0xF0)

  dict.nes("NES_CPU_WR", 0x8AAA, 0xAA)
  dict.nes("NES_CPU_WR", 0x8555, 0x55)
  dict.nes("NES_CPU_WR", 0x8AAA, 0x90)

  manufacturer_id = dict.nes("NES_CPU_RD", 0x8000)
  chips.display_manufacturer(manufacturer_id)

  device_id = dict.nes("NES_CPU_RD", 0x8001)
  device_test = chips.display_device(manufacturer_id, device_id)

  if not device_test then
    device_id = dict.nes("NES_CPU_RD", 0x8002) << 16
    device_id = device_id | (dict.nes("NES_CPU_RD", 0x801C) << 8)
    device_id = device_id | dict.nes("NES_CPU_RD", 0x801E)
    device_test = chips.display_device(manufacturer_id, device_id)
  end

  -- exit software
  dict.nes("NES_CPU_WR", 0x8000, 0xF0)

  if device_test == false then
    return false
  else
    return true
  end
end

-- dump PRG-ROM
local function prg_rom_dump(file, rom_size_KB, debug)
  -- PRG-ROM dump 32KB at a time through $5117 in mode 0
  -- above didn't work, dump 8KB at at time through $5114 in mode 3
  -- PRG-ROM dump 32KB at a time
  -- using PRG mode 0
  local KB_per_read = 32
  local num_banks = math.floor(rom_size_KB / KB_per_read)
  local cur_bank = 0
  local addr_base = 0x80 -- $8000

  log.info("PRG-ROM size", rom_size_KB .. "KB")

  while cur_bank < num_banks do
    if debug then
      log.point("dumping PRG bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- select desired bank to dump
    dict.nes("NES_CPU_WR", 0x5117, ((cur_bank << 2)|0x80)) -- 32KB & CPU $8000 (bits0&1 don't matter)
    -- above didn't work, only saw the last 8KB repeated...
    -- dict.nes("NES_CPU_WR", 0x5114, (cur_bank | 0x80)) -- 8KB & CPU $8000 (bit7 must be set to see ROM)

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

  local bank_size = 32 -- 32KByte per PRG bank
  local cur_bank = 0
  local num_banks = math.floor(rom_size_KB / bank_size)

  -- local byte_num -- byte number gets reset for each bank
  -- local byte_str, data, readdata

  while cur_bank < num_banks do
    if debug then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- select desired bank to dump
    dict.nes("NES_CPU_WR", 0x5117, cur_bank << 2) -- 32KB & CPU $8000 (bits0&1&7 don't matter)
    -- write the current bank to the mapper register
    -- dict.nes("NES_CPU_WR", 0x5114, (cur_bank | 0x80)) -- 8KB @ CPU $8000

    -- have the device write a bank worth of data

    --[[  This version of the code programs a single byte at a time but doesn't require
    --  MMC3 specific functions in the firmware
    print("This is slow as molasses, but gets the job done")
    byte_num = 0  -- current byte within the bank
    while byte_num < bank_size do

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
        readdata = dict.nes("NES_CPU_RD", base_addr+byte_num)
        if readdata ~= data then
          print("ERROR flashing byte number", byte_num, " in bank",cur_bank, " to flash ", data, readdata)
        end
      end

      byte_num = byte_num + 1
    end
    --]]

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size, "RNBW", "PRGROM", false)

    cur_bank = cur_bank + 1
  end

  -- -- exit unlock bypass mode
  -- dict.nes("NES_CPU_WR", 0x8000, 0x90)
  -- dict.nes("NES_CPU_WR", 0x8000, 0x00)

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

local function test_chr_banks(retroprog_id, debug)
  init_mapper()

  local rv
  local bank

  log.section("Test CHR banks")

  nes.cpu_rd(0x5204)

  dict.nes("NES_CPU_WR", 0x5101, 0x00) -- 1 8KByte bank (mode 0)

  dict.nes("NES_CPU_WR", 0x5120, 0xff)
  dict.nes("NES_CPU_WR", 0x5121, 0xff)
  dict.nes("NES_CPU_WR", 0x5122, 0xff)
  dict.nes("NES_CPU_WR", 0x5123, 0xff)
  dict.nes("NES_CPU_WR", 0x5124, 0xff)
  dict.nes("NES_CPU_WR", 0x5125, 0xff)
  dict.nes("NES_CPU_WR", 0x5126, 0xff)
  dict.nes("NES_CPU_WR", 0x5127, 0xff)
  dict.nes("NES_CPU_WR", 0x5128, 0xff)
  dict.nes("NES_CPU_WR", 0x5129, 0xff)
  dict.nes("NES_CPU_WR", 0x512a, 0xff)
  dict.nes("NES_CPU_WR", 0x512b, 0xff)

  for i = 0, 1, 1 do                  -- 255
    bank = i * 8
    dict.nes("NES_CPU_WR", 0x5127, i) -- CHR-ROM bank @ $0000-1FFF (mode 0)
    -- nes.cpu_wr(0x5120, i)
    nes.cpu_rd(0x5127)
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


  dict.nes("NES_CPU_WR", 0x5101, 0x03) -- 8 1KByte bank (mode 3)

  for i = 0, 15, 1 do                  -- 255
    dict.nes("NES_CPU_WR", 0x5120, i)  -- CHR-ROM bank @ $0000-03FF (mode 3)
    -- nes.cpu_wr(0x5120, i)
    nes.cpu_rd(0x5120)
    nes.ppu_rd(0x03ff)
    -- log.print()
  end
end

-- read CHR-ROM flash ID
local function chr_rom_manf_id()
  local manufacturer_id
  local device_id
  local device_test

  init_mapper()

  log.section("Reading CHR-ROM manufacturer/device ID")

  -- exit software
  dict.nes("NES_PPU_WR", 0x0000, 0xF0)

  dict.nes("NES_PPU_WR", 0x0AAA, 0xAA)
  dict.nes("NES_PPU_WR", 0x0555, 0x55)
  dict.nes("NES_PPU_WR", 0x0AAA, 0x90)

  manufacturer_id = dict.nes("NES_PPU_RD", 0x0000)
  chips.display_manufacturer(manufacturer_id)

  device_id = dict.nes("NES_PPU_RD", 0x0001)
  device_test = chips.display_device(manufacturer_id, device_id)

  device_id = dict.nes("NES_PPU_RD", 0x0002) << 16
  device_id = device_id | (dict.nes("NES_PPU_RD", 0x001C) << 8)
  device_id = device_id | dict.nes("NES_PPU_RD", 0x001E)
  device_test = chips.display_device(manufacturer_id, device_id)

  -- exit software
  dict.nes("NES_PPU_WR", 0x0000, 0xF0)

  if device_test == false then
    return false
  else
    return true
  end
end

-- dump CHR-ROM/RAM
local function chr_dump(file, rom_size_KB, debug)
  local KB_per_read = 8
  local num_banks = math.floor(rom_size_KB / KB_per_read)
  local addr_base = 0x00 -- $0000
  local cur_bank = 0

  log.info("CHR size", rom_size_KB .. "KB")

  while cur_bank < num_banks do
    if debug then
      log.point("dump CHR bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- CHR-ROM bank
    dict.nes("NES_CPU_WR", 0x5127, cur_bank) -- CHR-ROM bank @ $0000-1FFF (mode 0)
    -- dict.nes("NES_CPU_WR", 0x512B, cur_bank)  -- CHR-ROM bank @ $0000-1FFF (mode 0 8x16 sprites)

    -- dict.nes("NES_CPU_WR", 0x5121, cur_bank * 2)     -- CHR-ROM bank @ $0000-07FF (mode 2)
    -- dict.nes("NES_CPU_WR", 0x5123, cur_bank * 2 + 1) -- CHR-ROM bank @ $0800-0FFF (mode 2)

    dump.dumptofile(file, KB_per_read, addr_base, "NESPPU_1KB_TOGGLE", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

-- host flash one bank at a time
local function chr_rom_flash(file, rom_size_KB, debug)
  init_mapper()

  log.section("Programming CHR-ROM")
  log.info("CHR-ROM size", rom_size_KB .. "KB")

  local bank_size = 8 -- 8KByte per CHR bank
  local cur_bank = 0
  local num_banks = math.floor(rom_size_KB / bank_size)

  while cur_bank < num_banks do
    if debug then
      log.point("writing CHR bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    dict.nes("NES_CPU_WR", 0x5127, cur_bank) -- CHR-ROM bank @ $0000-1FFF (mode 0)
    -- dict.nes("NES_CPU_WR", 0x5121, cur_bank * 2)     -- 2KB @ PPU $0000
    -- dict.nes("NES_CPU_WR", 0x5123, cur_bank * 2 + 1) -- 2KB @ PPU $0800

    -- have the device write a bank worth of data
    --[[  This version of the code programs a single byte at a time but doesn't require
    --  MMC3 specific functions in the firmware
    print("This is slow as molasses, but gets the job done")
    byte_num = 0  -- current byte within the bank
    while byte_num < bank_size do

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
        readdata = dict.nes("NES_PPU_RD", base_addr+byte_num)
        if readdata ~= data then
          print("ERROR flashing byte number", byte_num, " in bank",cur_bank, " to flash ", data, readdata)
        end
      end

      byte_num = byte_num + 1
    end
    --]]

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size, "RNBW", "CHRROM", false)

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
  local KB_per_read = 8
  local num_banks = math.floor(ram_size_KB / KB_per_read)
  local addr_base = 0x60 -- $6000
  local cur_bank = 0

  log.info("PRG-RAM size", ram_size_KB .. "KB")

  while cur_bank < num_banks do
    if debug then
      log.point("dumping PRG-RAM bank ", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    dict.nes("NES_CPU_WR", 0x5113, cur_bank) -- PRG-RAM bank @ $6000-7FFF (regardless of PRG mode)

    dump.dumptofile(file, KB_per_read, addr_base, "NESCPU_PAGE", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

-- write to the PRG-RAM, assumes the PRG-RAM was enabled/disabled as desired prior to calling
local function write_ram(file, ram_size_KB, debug)
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
  local bank_size = 8 * 1024 -- MMC5 8KByte per RAM bank
  local buff_size = 1        -- number of bytes to write at a time
  local cur_bank = 0
  local num_banks = ram_size_KB * 1024 / bank_size

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
    dict.nes("NES_CPU_WR", 0x5113, cur_bank) -- PRG-RAM bank @ $6000-7FFF (regardless of PRG mode)


    -- have the device write a bank worth of data

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

    -- have the device write a bank worth of data
    -- FAST!  13sec for 512KB = 39KBps
    -- flash.write_file( file, bank_size/1024, mapname, "PRGROM", false )
    -- flash.write_file( file, bank_size/1024, "NOVAR", "PRGRAM", false )

    cur_bank = cur_bank + 1
  end

  print("Done Programming PRG-RAM")
end

-- try to detect if PRG-RAM is present
local function prg_ram_test(debug)
  local test = true
  local read_value
  local saved_value

  log.section("Detecting PRG-RAM")

  -- disable write protection
  dict.nes("NES_CPU_WR", 0x5102, 0x02) -- bits 1&0 must be '10' (ie 0x02) to allow writes to PRG-RAM
  dict.nes("NES_CPU_WR", 0x5103, 0x01) -- bits 1&0 must be '01' (ie 0x01) to allow writes to PRG-RAM

  -- set bank
  dict.nes("NES_CPU_WR", 0x5113, 0x00)

  -- save potential battery backed data first
  saved_value = dict.nes("NES_CPU_RD", 0x6000)

  -- try to write and read back
  dict.nes("NES_CPU_WR", 0x6000, saved_value ~ 0xff)
  read_value = dict.nes("NES_CPU_RD", 0x6000)
  if read_value ~= (saved_value ~ 0xff) then
    test = false
  end

  if test then
    -- put back original value
    dict.nes("NES_CPU_WR", 0x6000, saved_value)

    -- enable write protection
    dict.nes("NES_CPU_WR", 0x5102, 0x00) -- bits 1&0 must be '01' (ie 0x02) to allow writes to PRG-RAM
    dict.nes("NES_CPU_WR", 0x5103, 0x00) -- bits 1&0 must be '10' (ie 0x01) to allow writes to PRG-RAM

    -- TODO: maybe check if it worked?
    log.success("PRG-RAM detected")
  else
    log.error("PRG-RAM not detected")
  end

  return test
end

-- try to detect PRG-RAM size
local function prg_ram_get_size(debug)
  -- PRG-RAM can be maximum 128KB
  -- so we'll check sixteen (16) 8K banks and see if we can write to each

  local prg_ram_size = 128 -- let's use 32K as default value for now
  local num_banks = math.floor(prg_ram_size / 8)
  local cur_bank = num_banks - 1

  log.section("Detecting PRG-RAM size")

  -- disable write protection
  dict.nes("NES_CPU_WR", 0x5102, 0x02) -- bits 1&0 must be '10' (ie 0x02) to allow writes to PRG-RAM
  dict.nes("NES_CPU_WR", 0x5103, 0x01) -- bits 1&0 must be '01' (ie 0x01) to allow writes to PRG-RAM

  -- write to banks backwards
  while cur_bank >= 0 do
    if debug then
      log.point("trying to write to PRG-RAM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Writing", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    dict.nes("NES_CPU_WR", 0x5113, cur_bank)

    -- write data
    dict.nes("NES_CPU_WR", 0x6000, cur_bank)

    cur_bank = cur_bank - 1
  end

  spinner.clear()

  -- read back only last bank
  dict.nes("NES_CPU_WR", 0x5113, num_banks - 1)
  prg_ram_size = (dict.nes("NES_CPU_RD", 0x6000) + 1) * 8

  -- enable write protection
  dict.nes("NES_CPU_WR", 0x5102, 0x00) -- bits 1&0 must be '01' (ie 0x02) to allow writes to PRG-RAM
  dict.nes("NES_CPU_WR", 0x5103, 0x00) -- bits 1&0 must be '10' (ie 0x01) to allow writes to PRG-RAM

  if prg_ram_size >= 0 and prg_ram_size <= 128 then
    log.success("PRG-RAM size detected", prg_ram_size .. "KB")
    return prg_ram_size
  else
    log.warning("Failed to detect PRG-RAM size")
    return 0
  end
end

local function prg_ram_exercise(wram_size, retroprog_id, debug)
  if wram_size == 0 or wram_size == nil then
    log.error("PRG-RAM size invalid")
    return false
  end

  dict.stuff("RESET_LFSR") -- sets it to 1

  local cur_bank = 0
  local num_banks = math.floor(wram_size / 8)

  log.section("Exercising PRG-RAM")
  log.info("PRG-RAM size", wram_size .. "KB")

  -- disable write protection
  dict.nes("NES_CPU_WR", 0x5102, 0x02) -- bits 1&0 must be '10' (ie 0x02) to allow writes to PRG-RAM
  dict.nes("NES_CPU_WR", 0x5103, 0x01) -- bits 1&0 must be '01' (ie 0x01) to allow writes to PRG-RAM

  -- write random data to all banks
  log.point("Writing random data to PRG-RAM")
  while cur_bank < num_banks do
    if debug then
      log.point("init PRG-RAM 8K bank", cur_bank, "of", num_banks - 1)
    end

    -- set bank
    dict.nes("NES_CPU_WR", 0x5113, cur_bank)

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
  prg_ram_dump(file, wram_size, false)

  -- close file
  assert(file:close())

  -- enable write protection
  dict.nes("NES_CPU_WR", 0x5102, 0x00) -- bits 1&0 must be '01' (ie 0x02) to allow writes to PRG-RAM
  dict.nes("NES_CPU_WR", 0x5103, 0x00) -- bits 1&0 must be '10' (ie 0x01) to allow writes to PRG-RAM

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
███████╗██╗  ██╗██████╗  █████╗ ███╗   ███╗
██╔════╝╚██╗██╔╝██╔══██╗██╔══██╗████╗ ████║
█████╗   ╚███╔╝ ██████╔╝███████║██╔████╔██║
██╔══╝   ██╔██╗ ██╔══██╗██╔══██║██║╚██╔╝██║
███████╗██╔╝ ██╗██║  ██║██║  ██║██║ ╚═╝ ██║
╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝

--]]

-- dump the EXRAM
local function exram_dump_cpu(file, debug)
  local addr_base = 0x5C -- $5C00

  log.info("EXRAM size", 1 .. "KB")

  if debug then
    log.point("dump EXRAM bank ", 0, "of", 0)
  else
    spinner.update("Dumping", 0, "/", 0)
  end

  dump.dumptofile(file, 1, addr_base, "NESCPU_PAGE", debug)

  spinner.clear()
end

-- dump the EXRAM
local function exram_dump_ppu(file, addr_base, debug)
  if addr_base == nil then
    addr_base = 0x20 -- $2000
  end

  -- log.info("EXRAM size", 1 .. "KB")

  if debug then
    log.point("dump EXRAM bank ", 0, "of", 0)
  else
    spinner.update("Dumping", 0, "/", 0)
  end

  dump.dumptofile(file, 1, addr_base, "NESPPU_1KB_TOGGLE", debug)

  spinner.clear()
end

local function exram_exercise_mode0_1_cpu_ppu(retroprog_id, mode, debug)
  local addr
  local filename, file, goodfile
  local test = true

  -- set EXRAM mode
  dict.nes("NES_CPU_WR", 0x5104, mode & 1)

  -- set Nametable mapping
  dict.nes("NES_CPU_WR", 0x5105, 0xAA) -- EXRAM

  -- flash mode
  dict.nes("NES_CPU_WR", 0x50FF, 0xC0) -- enable flash mode + set in-frame flag

  log.section("Exercising EXRAM (mode " .. mode .. ") - CPU writes / PPU reads")

  -- open file
  filename = opts.lua_path .. "ignore/nes_exram_dump_ppu-" .. retroprog_id .. ".bin"
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
    exram_dump_ppu(file, addr, debug)
    file:flush()

    -- re-open & compare dump with known lsfr bitstream
    goodfile = opts.lua_path .. "ignore/lfsr_32KB.bin"

    -- compare the flash file vs post dump file
    if not files.compare(filename, goodfile, false, debug, 0, nt * 0x400) then
      test = false
      break
    end
  end

  dict.nes("NES_CPU_WR", 0x50FF, 0x80) -- enable flash mode + clear in-frame flag
  assert(file:close())
  return test
end

local function exram_exercise_mode0_1_ppu_ppu(retroprog_id, mode, debug)
  local addr_start, addr_end
  local filename, file, goodfile
  local test = true

  -- set EXRAM mode
  dict.nes("NES_CPU_WR", 0x5104, mode & 1)

  -- set Nametable mapping
  dict.nes("NES_CPU_WR", 0x5105, 0xAA) -- EXRAM

  -- flash mode
  dict.nes("NES_CPU_WR", 0x50FF, 0xC0) -- enable flash mode + set in-frame flag

  log.section("Exercising EXRAM (mode " .. mode .. ") - PPU writes / PPU reads")

  -- open file
  filename = opts.lua_path .. "ignore/nes_exram_dump_ppu-" .. retroprog_id .. ".bin"
  file = assert(io.open(filename, "wb"))

  -- re-open & compare dump with known lsfr bitstream
  goodfile = opts.lua_path .. "ignore/lfsr_32KB.bin"

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
    exram_dump_ppu(file, addr_start, debug)
    file:flush()

    -- compare the flash file vs post dump file
    if not files.compare(filename, goodfile, false, debug, 0, nt * 0x400) then
      test = false
      break
    end
  end

  dict.nes("NES_CPU_WR", 0x50FF, 0x80) -- enable flash mode + clear in-frame flag
  assert(file:close())
  return test
end

local function exram_exercise_mode2(retroprog_id, debug)
  local addr
  local filename, file, goodfile

  log.section("Exercising EXRAM (mode 2)")

  -- set EXRAM mode - CPU R/W
  dict.nes("NES_CPU_WR", 0x5104, 0x02)

  -- write random data
  log.point("Writing random data to EXRAM (CPU, in-frame)")

  dict.nes("NES_CPU_WR", 0x50FF, 0xC0) -- enable flash mode + set in-frame flag

  dict.stuff("RESET_LFSR")             -- sets it to 1

  addr = 0x5C00
  while (addr < 0x6000) do
    dict.nes("CPU_PAGE_WR_LFSR", addr)
    addr = addr + 256
  end

  -- open file
  filename = opts.lua_path .. "ignore/nes_exram_dump_cpu-" .. retroprog_id .. ".bin"
  file = assert(io.open(filename, "wb"))

  -- dump EXRAM
  log.point("Dumping EXRAM")
  exram_dump_cpu(file, false)

  -- close file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  goodfile = opts.lua_path .. "ignore/lfsr_32KB.bin"

  -- compare the flash file vs post dump file
  if not files.compare(filename, goodfile, false) then
    return false
  end

  -- write random data
  log.point("Writing random data to EXRAM (CPU, not in-frame)")

  dict.nes("NES_CPU_WR", 0x50FF, 0x80) -- enable flash mode + clear in-frame flag

  dict.stuff("RESET_LFSR")             -- sets it to 1

  addr = 0x5C00
  while (addr < 0x6000) do
    dict.nes("CPU_PAGE_WR_LFSR", addr)
    addr = addr + 256
  end

  -- open file
  filename = opts.lua_path .. "ignore/nes_exram_dump_cpu-" .. retroprog_id .. ".bin"
  file = assert(io.open(filename, "wb"))

  -- dump EXRAM
  log.point("Dumping EXRAM")
  exram_dump_cpu(file, false)

  -- close file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  goodfile = opts.lua_path .. "ignore/lfsr_32KB.bin"

  -- compare the flash file vs post dump file
  if not files.compare(filename, goodfile, false) then
    return false
  end

  return true
end

local function exram_exercise(retroprog_id, debug)
  local exram_ram_size = 1
  local cur_bank = 0
  local num_banks = 1
  local addr
  local rv

  -- test mode 0 cpu/ppu
  rv = exram_exercise_mode0_1_cpu_ppu(retroprog_id, 0, debug)
  if rv then
    log.success("EXRAM test passed")
  else
    log.error("EXRAM test failed")
    return false
  end

  -- test mode 0 ppu/ppu
  rv = exram_exercise_mode0_1_ppu_ppu(retroprog_id, 0, debug)
  if rv then
    log.success("EXRAM test passed")
  else
    log.error("EXRAM test failed")
    return false
  end

  log.warning("MODE 1 test to finish")

  -- -- test mode 1 cpu/ppu
  -- rv = exram_exercise_mode0_1_cpu_ppu(retroprog_id, 1, debug)
  -- if rv then
  --   log.success("EXRAM test passed")
  -- else
  --   log.error("EXRAM test failed")
  --   return false
  -- end

  -- -- test mode 1 ppu/ppu
  -- rv = exram_exercise_mode0_1_ppu_ppu(retroprog_id, 1, debug)
  -- if rv then
  --   log.success("EXRAM test passed")
  -- else
  --   log.error("EXRAM test failed")
  --   return false
  -- end

  -- test mode 2
  rv = exram_exercise_mode2(retroprog_id, debug)
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

-- Cart should be in reset state upon calling this function
-- this function processes all user requests for this specific board/mapper
local function process(process_opts, console_opts)
  -- some local variables
  local rv               = nil
  local file
  local chr_ram_detected = false
  local chr_ram_size     = 0

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
  local prg_size         = console_opts.prg_rom_size_kb
  local chr_size         = console_opts.chr_rom_size_kb
  local wram_size        = console_opts.wram_size_kb

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

    -- text_multiplication(DEBUG)
    -- test_chr_banks(retroprog_id, DEBUG)

    -- do return end

    -- verify mirroring is behaving as expected
    rv = mirror_test(DEBUG)
    if not rv then return false end

    chr_ram_detected = nes.ppu_ram_sense(0x1000, DEBUG)

    if options.force_flash_test or (do_rom_write and prg_size ~= 0) then
      rv = prg_rom_manf_id()
      if not rv then
        if do_rom_write and prg_size ~= 0 then
          log.error("Couldn't identify flash chip")
          return false
        else
          log.warning("Couldn't identify flash chip")
        end
      end
    end

    if options.force_flash_test or (do_rom_write and chr_size ~= 0) then
      rv = chr_rom_manf_id()
      if not rv then
        if do_rom_write and chr_size ~= 0 then
          log.error("Couldn't identify flash chip")
          return false
        else
          log.warning("Couldn't identify flash chip")
        end
      end
    end

    -- -- EXRAM tests
    rv = exram_exercise(retroprog_id, DEBUG)
    -- exit script if test fails
    if not rv then return end

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
      -- prg_ram_write(file, wram_size, DEBUG)
      log.warning("TODO: ADD RAM WRITE SUPPORT")
      time.report(wram_size)
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
    --  dict.nes("NES_CPU_WR", 0x5102, 0x02)  -- bits 1&0 must be '01' (ie 0x02) to allow writes to PRG-RAM
    --  dict.nes("NES_CPU_WR", 0x5103, 0x01)  -- bits 1&0 must be '10' (ie 0x01) to allow writes to PRG-RAM

    -- test with 1 Byte
    --    local addr = 0x600C
    --    local rv = dict.nes("NES_CPU_RD", addr)
    --    print(help.hex(addr), ":", help.hex(rv))
    --    dict.nes("NES_CPU_WR", addr, 0xAA)
    --    rv = dict.nes("NES_CPU_RD", addr)
    --    print(help.hex(addr), ":", help.hex(rv))

    --  rv = dict.nes("NES_CPU_RD", 0x600C)
    --  print("600C:", help.hex(rv))
    --  rv = dict.nes("NES_CPU_RD", 0x600D)
    --  print("600D:", help.hex(rv))

    file = assert(io.open(ramwritefile, "rb"))

    write_ram(file, wram_size, true)
    -- flash.write_file( file, wram_size, "NOVAR", "PRGRAM", false )
    -- flash.write_file( file, wram_size, "MMC5", "PRGRAM", false )

    -- for save data safety disable PRG-RAM writes
    --  dict.nes("NES_CPU_WR", 0x5102, 0x01)  -- bits 1&0 must be '01' (ie 0x02) to allow writes to PRG-RAM
    --  dict.nes("NES_CPU_WR", 0x5103, 0x02)  -- bits 1&0 must be '10' (ie 0x01) to allow writes to PRG-RAM

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
      time.start()
      dict.nes("NES_CPU_WR", 0x8AAA, 0xAA)
      dict.nes("NES_CPU_WR", 0x8555, 0x55)
      dict.nes("NES_CPU_WR", 0x8AAA, 0x80)
      dict.nes("NES_CPU_WR", 0x8AAA, 0xAA)
      dict.nes("NES_CPU_WR", 0x8555, 0x55)
      dict.nes("NES_CPU_WR", 0x8AAA, 0x10)

      -- TODO create some function to pass the read value
      -- that's smart enough to figure out if the board is actually erasing or not
      repeat
        rv = dict.nes("NES_CPU_RD", 0x8000)
        spinner.update("Erasing")
        i = i + 1
      until rv == dict.nes("NES_CPU_RD", 0x8000)

      spinner.clear()
      log.success("Done erasing PRG-ROM", i .. " naks")
      time.report(prg_size)
    end

    -- erase CHR-ROM only if needed
    if chr_size ~= 0 then
      init_mapper()
      log.section("Erasing CHR-ROM")
      time.start()
      dict.nes("NES_PPU_WR", 0x1AAA, 0xAA)
      dict.nes("NES_PPU_WR", 0x1555, 0x55)
      dict.nes("NES_PPU_WR", 0x1AAA, 0x80)
      dict.nes("NES_PPU_WR", 0x1AAA, 0xAA)
      dict.nes("NES_PPU_WR", 0x1555, 0x55)
      dict.nes("NES_PPU_WR", 0x1AAA, 0x10)

      -- TODO create some function to pass the read value
      -- that's smart enough to figure out if the board is actually erasing or not
      i = 0
      repeat
        rv = dict.nes("NES_PPU_RD", 0x0000)
        spinner.update("Erasing")
        i = i + 1
      until rv == dict.nes("NES_PPU_RD", 0x0000)

      spinner.clear()
      log.success("Done erasing CHR-ROM", i .. " naks")
      time.report(chr_size)
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
mmc5.process = process

-- return the module's table
return mmc5
