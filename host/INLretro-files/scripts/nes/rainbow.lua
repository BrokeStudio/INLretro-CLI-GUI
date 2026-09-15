-- create the module's table
local rainbow          = {}

-- import required modules
local dict             = require "scripts.app.dict"
local nes              = require "scripts.app.nes"
local dump             = require "scripts.app.dump"
local flash            = require "scripts.app.flash"
local chips            = require "scripts.app.chips"
local time             = require "scripts.app.time"
local log              = require "scripts.app.log"
local spinner          = require "scripts.app.spinner"
local files            = require "scripts.app.files"
local help             = require "scripts.app.help"

-- file constants and global variables
local mapname          = "RNBW" --"Rainbow"

local prg_flash_chip
local chr_flash_chip

local PRG_BANKING_MODE = 0x4100
local PRG_6_HI         = 0x4106
local PRG_7_HI         = 0x4107
local PRG_8_HI         = 0x4108
local PRG_5_LO         = 0x4115
local PRG_6_LO         = 0x4116
local PRG_7_LO         = 0x4117
local PRG_8_LO         = 0x4118
local CHR_BANKING_MODE = 0x4120
local NT_A_BANK        = 0x4126
local NT_B_BANK        = 0x4127
local NT_C_BANK        = 0x4128
local NT_D_BANK        = 0x4129
local NT_A_CTRL        = 0x412A
local NT_B_CTRL        = 0x412B
local NT_C_CTRL        = 0x412C
local NT_D_CTRL        = 0x412D
local CHR_0_HI         = 0x4130
local CHR_0_LO         = 0x4140
local WIFI_CONTROL     = 0x4190
local WIFI_RX          = 0x4191
local WIFI_TX          = 0x4192
local WIFI_RX_ADD      = 0x4193
local WIFI_TX_ADD      = 0x4194
local BOOTLOADER_MODE  = 0x41FF

-- local functions

--[[
███╗   ███╗██╗███████╗ ██████╗    ███████╗██╗   ██╗███╗   ██╗ ██████╗███████╗
████╗ ████║██║██╔════╝██╔════╝    ██╔════╝██║   ██║████╗  ██║██╔════╝██╔════╝
██╔████╔██║██║███████╗██║         █████╗  ██║   ██║██╔██╗ ██║██║     ███████╗
██║╚██╔╝██║██║╚════██║██║         ██╔══╝  ██║   ██║██║╚██╗██║██║     ╚════██║
██║ ╚═╝ ██║██║███████║╚██████╗    ██║     ╚██████╔╝██║ ╚████║╚██████╗███████║
╚═╝     ╚═╝╚═╝╚══════╝ ╚═════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚══════╝

--]]

local function init_mapper(debug)
  -- exit bootloader
  -- enable flash mode
  dict.nes("NES_CPU_WR", BOOTLOADER_MODE, 0x80)

  -- PRG

  -- set PRG-ROM MODE to 0 (32K)
  -- set PRG-RAM MODE to 0 (8K)
  dict.nes("NES_CPU_WR", PRG_BANKING_MODE, 0)

  -- map PRG-ROM at $6000
  dict.nes("NES_CPU_WR", PRG_6_HI, 0x00)

  -- CHR

  -- set CHR to CHR-ROM mode 0 (8K mode)
  dict.nes("NES_CPU_WR", CHR_BANKING_MODE, 0)

  -- reset PRG flash chips
  -- dict.nes("NES_CPU_WR", 0x8000, 0x90)
  -- dict.nes("NES_CPU_WR", 0x8000, 0x00)
  dict.nes("NES_CPU_WR", 0x8000, 0xF0)

  -- reset CHR flash chips
  -- dict.nes("NES_PPU_WR", 0x0000, 0x90)
  -- dict.nes("NES_PPU_WR", 0x0000, 0x00)
  dict.nes("NES_PPU_WR", 0x0000, 0xF0)
end

local function create_header(file, prg_kb, chr_kb)
  -- write_header(file, prg_kb, chr_kb, mapper, mirroring)
  nes.write_header(file, prg_kb, chr_kb, op_buffer[mapname], 0)
end

-- dump NT
local function nt_dump(file, nt, debug)
  local kb_per_read = 1
  local addr_base = 0x20 + nt * 4

  dump.dumptofile(file, kb_per_read, { mapper = addr_base, mem_type = "NESPPU_1KB_TOGGLE" }, debug)
end

local function _mirror_test(retroprog_id, debug)
  local nt_max = 255
  local test = true

  local filenameA = opts.write_path .. "./ignore/nes_ppu_ntA_dump-" .. retroprog_id .. ".bin"
  local filenameB = opts.write_path .. "./ignore/nes_ppu_ntB_dump-" .. retroprog_id .. ".bin"
  local filenameC = opts.write_path .. "./ignore/nes_ppu_ntC_dump-" .. retroprog_id .. ".bin"
  local filenameD = opts.write_path .. "./ignore/nes_ppu_ntD_dump-" .. retroprog_id .. ".bin"

  local fileA = assert(io.open(filenameA, "wb"))
  local fileB = assert(io.open(filenameB, "wb"))
  local fileC = assert(io.open(filenameC, "wb"))
  local fileD = assert(io.open(filenameD, "wb"))

  if debug == false then
    nt_max = 0
  end

  -- 1 screen
  for nt = 0, nt_max, 1 do
    spinner.update("NT", nt, "/", nt_max)

    dict.nes("NES_CPU_WR", NT_A_BANK, nt)
    dict.nes("NES_CPU_WR", NT_B_BANK, nt)
    dict.nes("NES_CPU_WR", NT_C_BANK, nt)
    dict.nes("NES_CPU_WR", NT_D_BANK, nt)

    fileA:seek("set")
    fileB:seek("set")
    fileC:seek("set")
    fileD:seek("set")

    nt_dump(fileA, 0, debug)
    nt_dump(fileB, 1, debug)
    nt_dump(fileC, 2, debug)
    nt_dump(fileD, 3, debug)

    fileA:flush()
    fileB:flush()
    fileC:flush()
    fileD:flush()

    if files.compare(filenameA, filenameB, true, false) == false then
      test = false
      break
    end

    if files.compare(filenameB, filenameC, true, false) == false then
      test = false
      break
    end

    if files.compare(filenameC, filenameD, true, false) == false then
      test = false
      break
    end
  end
  spinner.clear()

  if test == false then
    log.error("One screen mirroring test failed")
    goto done
  else
    log.success("One screen mirroring test passed")
  end

  -- Horizontal
  for nt = 0, nt_max, 1 do
    spinner.update("NT", nt, "/", nt_max)

    dict.nes("NES_CPU_WR", NT_A_BANK, nt)
    dict.nes("NES_CPU_WR", NT_B_BANK, nt)
    dict.nes("NES_CPU_WR", NT_C_BANK, (nt + 1) & 0xff)
    dict.nes("NES_CPU_WR", NT_D_BANK, (nt + 1) & 0xff)

    fileA:seek("set")
    fileB:seek("set")
    fileC:seek("set")
    fileD:seek("set")

    nt_dump(fileA, 0, debug)
    nt_dump(fileB, 1, debug)
    nt_dump(fileC, 2, debug)
    nt_dump(fileD, 3, debug)

    fileA:flush()
    fileB:flush()
    fileC:flush()
    fileD:flush()

    if files.compare(filenameA, filenameB, true, false) == false then
      test = false
      break
    end

    if files.compare(filenameC, filenameD, true, false) == false then
      test = false
      break
    end
  end

  spinner.clear()

  if test == false then
    log.error("Horizontal mirroring test failed")
    goto done
  else
    log.success("Horizontal mirroring test passed")
  end

  -- Vertical
  for nt = 0, nt_max, 1 do
    spinner.update("NT", nt, "/", nt_max)

    dict.nes("NES_CPU_WR", NT_A_BANK, nt)
    dict.nes("NES_CPU_WR", NT_B_BANK, (nt + 1) & 0xff)
    dict.nes("NES_CPU_WR", NT_C_BANK, nt)
    dict.nes("NES_CPU_WR", NT_D_BANK, (nt + 1) & 0xff)

    fileA:seek("set")
    fileB:seek("set")
    fileC:seek("set")
    fileD:seek("set")

    nt_dump(fileA, 0, debug)
    nt_dump(fileB, 1, debug)
    nt_dump(fileC, 2, debug)
    nt_dump(fileD, 3, debug)

    fileA:flush()
    fileB:flush()
    fileC:flush()
    fileD:flush()

    if files.compare(filenameA, filenameC, true, false) == false then
      test = false
      break
    end

    if files.compare(filenameB, filenameD, true, false) == false then
      test = false
      break
    end
  end

  spinner.clear()

  if test == false then
    log.error("Vertical mirroring test failed")
    goto done
  else
    log.success("Vertical mirroring test passed")
  end

  ::done::

  assert(fileA:close())
  assert(fileB:close())
  assert(fileC:close())
  assert(fileD:close())

  if test == true then
    assert(os.remove(filenameA))
    assert(os.remove(filenameB))
    assert(os.remove(filenameC))
    assert(os.remove(filenameD))
  end

  return test
end

-- test the mapper's mirroring modes to verify working properly
-- can be used to help identify board: returns true if pass, false if failed
local function mirror_test(chr_size_kb, chr_ram_detected, retroprog_id, debug)
  log.section("Testing mirroring settings")

  -- put mapper in known state
  init_mapper()

  -- CIRAM
  log.point("CIRAM")
  dict.nes("NES_CPU_WR", NT_A_CTRL, 0x00)
  dict.nes("NES_CPU_WR", NT_B_CTRL, 0x00)
  dict.nes("NES_CPU_WR", NT_C_CTRL, 0x00)
  dict.nes("NES_CPU_WR", NT_D_CTRL, 0x00)

  -- 1 screen A
  dict.nes("NES_CPU_WR", NT_A_BANK, 0x00)
  dict.nes("NES_CPU_WR", NT_B_BANK, 0x00)
  dict.nes("NES_CPU_WR", NT_C_BANK, 0x00)
  dict.nes("NES_CPU_WR", NT_D_BANK, 0x00)
  if nes.detect_mapper_mirroring(debug) ~= "1SCRNA" then
    log.error("One screen mirroring test failed (1 screen A)")
    return false
  else
    log.success("One screen mirroring test passed (1 screen A)")
  end

  -- 1 screen B
  dict.nes("NES_CPU_WR", NT_A_BANK, 0x01)
  dict.nes("NES_CPU_WR", NT_B_BANK, 0x01)
  dict.nes("NES_CPU_WR", NT_C_BANK, 0x01)
  dict.nes("NES_CPU_WR", NT_D_BANK, 0x01)
  if nes.detect_mapper_mirroring(debug) ~= "1SCRNB" then
    log.error("One screen mirroring test failed (1 screen B)")
    return false
  else
    log.success("One screen mirroring test passed (1 screen B)")
  end

  -- Vertical
  dict.nes("NES_CPU_WR", NT_A_BANK, 0x00)
  dict.nes("NES_CPU_WR", NT_C_BANK, 0x00)
  dict.nes("NES_CPU_WR", NT_B_BANK, 0x01)
  dict.nes("NES_CPU_WR", NT_D_BANK, 0x01)
  if nes.detect_mapper_mirroring(debug) ~= "VERT" then
    log.error("Vertical mirroring test failed")
    return false
  else
    log.success("Vertical mirroring test passed")
  end

  -- Horizontal
  dict.nes("NES_CPU_WR", NT_A_BANK, 0x00)
  dict.nes("NES_CPU_WR", NT_B_BANK, 0x00)
  dict.nes("NES_CPU_WR", NT_C_BANK, 0x01)
  dict.nes("NES_CPU_WR", NT_D_BANK, 0x01)
  if nes.detect_mapper_mirroring(debug) ~= "HORZ" then
    log.error("Horizontal mirroring test failed")
    return false
  else
    log.success("Horizontal mirroring test passed")
  end

  -- CHR-ROM
  if chr_size_kb ~= 0 then
    log.point("CHR-ROM")
    dict.nes("NES_CPU_WR", NT_A_CTRL, 0xC0)
    dict.nes("NES_CPU_WR", NT_B_CTRL, 0xC0)
    dict.nes("NES_CPU_WR", NT_C_CTRL, 0xC0)
    dict.nes("NES_CPU_WR", NT_D_CTRL, 0xC0)
    if _mirror_test(retroprog_id, debug) == false then
      return false
    end
  end

  -- CHR-RAM
  if chr_ram_detected then
    log.point("CHR-RAM")
    dict.nes("NES_CPU_WR", NT_A_CTRL, 0x40)
    dict.nes("NES_CPU_WR", NT_B_CTRL, 0x40)
    dict.nes("NES_CPU_WR", NT_C_CTRL, 0x40)
    dict.nes("NES_CPU_WR", NT_D_CTRL, 0x40)
    if _mirror_test(retroprog_id, debug) == false then
      return false
    end
  end

  -- FPGA-RAM
  log.point("FPGA-RAM")
  dict.nes("NES_CPU_WR", NT_A_CTRL, 0x80)
  dict.nes("NES_CPU_WR", NT_B_CTRL, 0x80)
  dict.nes("NES_CPU_WR", NT_C_CTRL, 0x80)
  dict.nes("NES_CPU_WR", NT_D_CTRL, 0x80)
  if _mirror_test(retroprog_id, debug) == false then
    return false
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
  local device
  local found

  log.section("Reading PRG-ROM manufacturer/device ID")

  -- exit software
  dict.nes("NES_CPU_WR", 0x8000, 0xF0)

  dict.nes("NES_CPU_WR", 0x8AAA, 0xAA)
  dict.nes("NES_CPU_WR", 0x8555, 0x55)
  dict.nes("NES_CPU_WR", 0x8AAA, 0x90)

  manufacturer_id = dict.nes("NES_CPU_RD", 0x8000)
  chips.display_manufacturer(manufacturer_id)

  device_id = dict.nes("NES_CPU_RD", 0x8001)
  found, device = chips.display_device(manufacturer_id, device_id)

  if not found then
    device_id = dict.nes("NES_CPU_RD", 0x8002) << 16
    device_id = device_id | (dict.nes("NES_CPU_RD", 0x801C) << 8)
    device_id = device_id | dict.nes("NES_CPU_RD", 0x801E)
    found, device = chips.display_device(manufacturer_id, device_id)
  end

  prg_flash_chip = device

  -- exit software
  dict.nes("NES_CPU_WR", 0x8000, 0xF0)

  return found, device
end

local function prg_erase_sector(addr, debug)
  local bank_32K = addr >> 17
  local bank_32K_lo = (bank_32K & 0xff)
  local bank_32K_hi = (bank_32K >> 8) & 0xff

  dict.nes("NES_CPU_WR", PRG_8_LO, bank_32K_lo)
  dict.nes("NES_CPU_WR", PRG_8_HI, bank_32K_hi)

  dict.nes("NES_CPU_WR", 0x8000, 0xF0)
  dict.nes("NES_CPU_WR", 0x8AAA, 0xAA)
  dict.nes("NES_CPU_WR", 0x8555, 0x55)
  dict.nes("NES_CPU_WR", 0x8AAA, 0x80)
  dict.nes("NES_CPU_WR", 0x8AAA, 0xAA)
  dict.nes("NES_CPU_WR", 0x8555, 0x55)
  dict.nes("NES_CPU_WR", 0x8000, 0x30)

  if debug then
    log.point("erasing sector @ " .. help.hex_0x6(addr))
  end

  local temp
  local nak = 0

  while (dict.nes("NES_CPU_RD", 0x8000) ~= 0xFF) do
    nak = nak + 1
    if nak > 100000 then
      temp = dict.nes("NES_CPU_RD", 0x8000)
      log.error("sector erase failed", help.hex_0x6(addr), "read", help.hex_0x2(temp))
      return false
    end
  end

  for offset = 0, 30, 2 do
    temp = dict.nes("NES_CPU_RD", 0x8000)
    if temp ~= 0xFF then
      log.error("sector erase verify failed", help.hex_0x6(addr + offset), "read", help.hex_0x2(temp))
      return false
    end
  end

  return true
end

--- Program one byte to PRG-ROM flash and poll for completion.
---@param addr integer Address to program, 0x8000-0xFFFF
---@param value integer 8-bit value to write
---@param debug? boolean Enable verbose progress logging
local function prg_rom_flash_byte(addr, value, debug)
  local i = 0
  local rv

  if addr < 0x8000 or addr > 0xFFFF then
    log.error("ERROR! flash write to PRG-ROM", help.hex_0x4(addr), "must be $8000-$FFFF")
    return
  end

  dict.nes("NES_CPU_WR", 0x8AAA, 0xAA)
  dict.nes("NES_CPU_WR", 0x8555, 0x55)
  dict.nes("NES_CPU_WR", 0x8AAA, 0xA0)
  dict.nes("NES_CPU_WR", addr, value)

  -- /!\ needs to be in unlock bypass mode
  -- dict.nes("NES_CPU_WR", addr, 0xA0)
  -- dict.nes("NES_CPU_WR", addr, value)

  repeat
    rv = dict.nes("NES_CPU_RD", addr)
    i = i + 1
  until rv == dict.nes("NES_CPU_RD", addr)

  if debug then print(i, "naks, done writing byte.") end

  --TODO report error if write failed
end

--- Dump PRG-ROM contents to an already-open output file.
---@param file file* Open binary output file
---@param rom_size_kb integer PRG-ROM size in kilobytes
---@param debug? boolean Enable verbose progress logging
local function prg_rom_dump(file, rom_size_kb, debug)
  -- PRG-ROM dump 32KB at a time
  -- using PRG mode 0
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

    -- select desired bank to dump
    dict.nes("NES_CPU_WR", PRG_8_HI, (cur_bank & 0xff00) >> 8) -- 32KB @ CPU $8000
    dict.nes("NES_CPU_WR", PRG_8_LO, (cur_bank & 0x00ff) >> 0) -- 32KB @ CPU $8000

    dump.dumptofile(file, kb_per_read, { mapper = addr_base, mem_type = "NESCPU_PAGE_TOGGLE" }, false)

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

  local bank_size = 32 -- 32KByte per PRG bank
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

  while cur_bank < num_banks do
    if debug then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- write the bank to flash to the mapper register
    dict.nes("NES_CPU_WR", PRG_8_HI, (cur_bank & 0xff00) >> 8) -- 32KB @ CPU $8000
    dict.nes("NES_CPU_WR", PRG_8_LO, (cur_bank & 0x00ff) >> 0) -- 32KB @ CPU $8000

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size, { mapper = mapname, mem_type = "PRGROM", options = options }, false)

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
  local device
  local found

  init_mapper()

  log.section("Reading CHR-ROM manufacturer/device ID")

  -- exit software
  dict.nes("NES_PPU_WR", 0x0000, 0x90)
  dict.nes("NES_PPU_WR", 0x0000, 0x00)
  dict.nes("NES_PPU_WR", 0x0000, 0xF0)

  dict.nes("NES_PPU_WR", 0x0AAA, 0xAA)
  dict.nes("NES_PPU_WR", 0x0555, 0x55)
  dict.nes("NES_PPU_WR", 0x0AAA, 0x90)

  manufacturer_id = dict.nes("NES_PPU_RD", 0x0000)
  chips.display_manufacturer(manufacturer_id)

  device_id = dict.nes("NES_PPU_RD", 0x0001)
  found, device = chips.display_device(manufacturer_id, device_id)

  device_id = dict.nes("NES_PPU_RD", 0x0002) << 16
  device_id = device_id | (dict.nes("NES_PPU_RD", 0x001C) << 8)
  device_id = device_id | dict.nes("NES_PPU_RD", 0x001E)
  found, device = chips.display_device(manufacturer_id, device_id)

  -- exit software
  dict.nes("NES_PPU_WR", 0x0000, 0xF0)

  chr_flash_chip = device

  return found, device
end

local function chr_erase_sector(addr, debug)
  local bank_8K = addr >> 13
  local bank_8K_lo = bank_8K & 0xff
  local bank_8K_hi = (bank_8K >> 8) & 0xff

  dict.nes("NES_CPU_WR", CHR_0_LO, bank_8K_lo)
  dict.nes("NES_CPU_WR", CHR_0_HI, bank_8K_hi)

  dict.nes("NES_PPU_WR", 0x0000, 0xF0)
  dict.nes("NES_PPU_WR", 0x0AAA, 0xAA)
  dict.nes("NES_PPU_WR", 0x0555, 0x55)
  dict.nes("NES_PPU_WR", 0x0AAA, 0x80)
  dict.nes("NES_PPU_WR", 0x0AAA, 0xAA)
  dict.nes("NES_PPU_WR", 0x0555, 0x55)
  dict.nes("NES_PPU_WR", 0x0000, 0x30)

  if debug then
    log.point("erasing CHR sector @ " .. help.hex_0x6(addr))
  end

  local temp
  local nak = 0

  while (dict.nes("NES_PPU_RD", 0x0000) ~= 0xFF) do
    nak = nak + 1
    if nak > 100000 then
      temp = dict.nes("NES_PPU_RD", 0x0000)
      log.error("CHR sector erase failed", help.hex_0x6(addr), "read", help.hex_0x2(temp))
      return false
    end
  end

  for offset = 0, 30, 2 do
    temp = dict.nes("NES_PPU_RD", offset)
    if temp ~= 0xFF then
      log.error("CHR sector erase verify failed", help.hex_0x6(addr + offset), "read", help.hex_0x2(temp))
      return false
    end
  end

  return true
end

--- Program one byte to CHR flash and poll for completion.
---@param addr integer Address to program, 0x0000-0x0FFF
---@param value integer 8-bit value to write
---@param debug? boolean Enable verbose progress logging
local function chr_rom_flash_byte(addr, value, debug)
  if addr < 0x0000 or addr > 0x0FFF then
    print("\n  ERROR! flash write to CHR-ROM", string.format("$%X", addr), "must be $0000-0FFF \n\n")
    return
  end

  -- send unlock command and write byte
  dict.nes("NES_PPU_WR", 0x0555, 0xAA)
  dict.nes("NES_PPU_WR", 0x0AAA, 0x55)
  dict.nes("NES_PPU_WR", 0x0555, 0xA0)
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
  local addr_base = 0x00 -- $0000
  local cur_bank = 0

  log.info("CHR size", rom_size_kb .. "KB")

  while cur_bank < num_banks do
    if debug then
      log.point("dump CHR bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    dict.nes("NES_CPU_WR", CHR_0_HI, (cur_bank & 0xff00) >> 8) -- 8KB @ PPU $0000
    dict.nes("NES_CPU_WR", CHR_0_LO, cur_bank & 0xff)          -- 8KB @ PPU $0000

    dump.dumptofile(file, kb_per_read, { mapper = addr_base, mem_type = "NESPPU_1KB_TOGGLE" }, false)

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

  local bank_size = 8 -- 8KByte per CHR bank
  local cur_bank = 0
  local num_banks = math.floor(rom_size_kb / bank_size)

  local options
  if chr_flash_chip.buffer == true then
    options = "USE_BUFFER"
    log.info("Using buffer programming")
  elseif chr_flash_chip.unlock_bypass == true then
    options = "USE_UNLOCK_BYPASS"
    log.info("Using unlock bypass mode")
  end

  while cur_bank < num_banks do
    if debug then
      log.point("writing CHR bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    dict.nes("NES_CPU_WR", CHR_0_HI, (cur_bank & 0xff00) >> 8) -- 8KB @ PPU $0000
    dict.nes("NES_CPU_WR", CHR_0_LO, cur_bank & 0xff)          -- 8KB @ PPU $0000

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size, { mapper = mapname, mem_type = "CHRROM", options = options }, false)

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
    dict.nes("NES_CPU_WR", PRG_6_LO, cur_bank)

    dump.dumptofile(file, kb_per_read, { mapper = addr_base, mem_type = "NESCPU_PAGE_TOGGLE" }, false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--- Write PRG-RAM contents from an already-open input file.
---@param file file* Open binary input file
---@param ram_size_kb integer PRG-RAM size in kilobytes
---@param debug? boolean Enable verbose progress logging
local function prg_ram_write(file, ram_size_kb, debug)
  -- TODO
  log.error("TODO: prg_ram_write")
  do return end

  init_mapper()

  log.info("PRG-RAM size", ram_size_kb .. "KB")

  local bank_size = 8
  local cur_bank = 0
  local num_banks = math.floor(ram_size_kb / bank_size)

  -- map PRG-RAM at $6000
  dict.nes("NES_CPU_WR", PRG_6_HI, 0x80)

  while cur_bank < num_banks do
    if debug then
      log.point("writing PRG-RAM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    dict.nes("NES_CPU_WR", PRG_6_LO, cur_bank)

    --have the device write a bank worth of data
    flash.write_file(file, bank_size, { mapper = "NOVAR", mem_type = "PRGRAM" }, false)

    cur_bank = cur_bank + 1
  end

  -- map PRG-ROM at $6000
  dict.nes("NES_CPU_WR", PRG_6_HI, 0x00)

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

  -- map PRG-RAM at $6000
  dict.nes("NES_CPU_WR", PRG_6_HI, 0x80)

  -- 8KB PRG-RAM bank at $6000
  dict.nes("NES_CPU_WR", PRG_6_LO, 0)

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
    -- TODO: maybe check if it worked?
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
  -- PRG-RAM can be maximum 256KB
  -- so we'll check sixteen (32) 8K banks and see if we can write to each

  local prg_ram_size_kb = 256
  local num_banks = math.floor(prg_ram_size_kb / 8)

  log.section("Detecting PRG-RAM size")

  -- set PRG-RAM mode to 8K
  local rv = dict.nes("NES_CPU_RD", PRG_BANKING_MODE)
  dict.nes("NES_CPU_WR", PRG_BANKING_MODE, rv & 0x7f)

  -- map PRG-RAM at $6000
  dict.nes("NES_CPU_WR", PRG_6_HI, 0x80)

  -- write to banks backwards
  for cur_bank = num_banks, 0, -1 do
    if debug then
      log.point("trying to write to PRG-RAM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Writing", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    dict.nes("NES_CPU_WR", PRG_6_LO, cur_bank) -- 8KB bank at $6000

    -- write data
    dict.nes("NES_CPU_WR", 0x6000, cur_bank)

    cur_bank = cur_bank - 1
  end

  spinner.clear()

  -- read back only last bank
  dict.nes("NES_CPU_WR", PRG_6_LO, num_banks - 1) -- 8KB bank at $6000
  prg_ram_size_kb = (dict.nes("NES_CPU_RD", 0x6000) + 1) * 8

  if prg_ram_size_kb >= 0 and prg_ram_size_kb <= 256 then
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
  if wram_size_kb == 0 or wram_size_kb == nil then
    log.error("PRG-RAM size invalid")
    return false
  end

  dict.stuff("RESET_LFSR") -- sets it to 1

  local cur_bank = 0
  local num_banks = math.floor(wram_size_kb / 8)

  log.section("Exercising PRG-RAM")
  log.info("PRG-RAM size", wram_size_kb .. "KB")

  -- map PRG-RAM at $6000
  dict.nes("NES_CPU_WR", PRG_6_HI, 0x80)

  -- write random data to all banks
  log.point("Writing random data to PRG-RAM")
  while cur_bank < num_banks do
    if debug then
      log.point("init PRG-RAM 8K bank", cur_bank, "of", num_banks - 1)
    end

    -- set bank
    dict.nes("NES_CPU_WR", PRG_6_LO, cur_bank)

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

  -- map PRG-ROM at $6000
  dict.nes("NES_CPU_WR", PRG_6_HI, 0x00)

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "./ignore/lfsr_" .. wram_size_kb .. "KB.bin"

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
███████╗██████╗  ██████╗  █████╗       ██████╗  █████╗ ███╗   ███╗
██╔════╝██╔══██╗██╔════╝ ██╔══██╗      ██╔══██╗██╔══██╗████╗ ████║
█████╗  ██████╔╝██║  ███╗███████║█████╗██████╔╝███████║██╔████╔██║
██╔══╝  ██╔═══╝ ██║   ██║██╔══██║╚════╝██╔══██╗██╔══██║██║╚██╔╝██║
██║     ██║     ╚██████╔╝██║  ██║      ██║  ██║██║  ██║██║ ╚═╝ ██║
╚═╝     ╚═╝      ╚═════╝ ╚═╝  ╚═╝      ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝

--]]

--- Dump FPGA-RAM contents to an already-open output file.
---@param file file* Open binary output file
---@param rom_size_kb integer FPGA-RAM size in kilobytes
---@param debug? boolean Enable verbose progress logging
local function fpga_ram_dump(file, rom_size_kb, debug)
  local kb_per_read = 4
  local num_banks = rom_size_kb / kb_per_read
  local addr_base = 0x50 -- $5000
  local cur_bank = 0

  log.info("FPGA-RAM size", rom_size_kb .. "KB")

  while cur_bank < num_banks do
    dict.nes("NES_CPU_WR", PRG_5_LO, cur_bank) -- 4KB PRG-RAM bank at $5000

    if debug then
      log.point("dump FPGA-RAM bank ", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    dump.dumptofile(file, kb_per_read, { mapper = addr_base, mem_type = "NESCPU_PAGE_TOGGLE" }, false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--- Exercise FPGA-RAM with an LFSR pattern and compare the dumped result.
--- Overwrites FPGA-RAM contents with the test pattern.
---@param retroprog_id string|integer Identifier used in the temporary dump filename
---@param debug? boolean Enable verbose compare/progress logging
---@return boolean success True when the FPGA-RAM dump matches the expected LFSR data
local function fpga_ram_exercise(retroprog_id, debug)
  dict.stuff("RESET_LFSR") -- sets it to 1

  local fpga_ram_size_kb = 8
  local cur_bank = 0
  local num_banks = math.floor(fpga_ram_size_kb / 4)

  log.section("Exercising FPGA-RAM")
  log.info("FPGA-RAM size", fpga_ram_size_kb .. "KB")

  -- set FPGA-RAM bank to bank 0
  dict.nes("NES_CPU_WR", PRG_5_LO, 0x00) -- 4KB bank at $5000

  -- write random data to all banks
  log.point("Writing random data to FPGA-RAM")
  while cur_bank < num_banks do
    if debug then log.point("init FPGA-RAM 4K bank", cur_bank, "of", num_banks - 1) end
    dict.nes("NES_CPU_WR", PRG_5_LO, cur_bank) -- 8KB bank at $5000
    local addr = 0x5000
    while (addr < 0x6000) do
      dict.nes("CPU_PAGE_WR_LFSR", addr)
      addr = addr + 256
    end
    cur_bank = cur_bank + 1
  end

  -- open file
  local filename = opts.write_path .. "./ignore/nes_fpga_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))

  -- dump FPGA-RAM
  log.point("Dumping FPGA-RAM")
  fpga_ram_dump(file, fpga_ram_size_kb, false)

  -- close file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "./ignore/lfsr_32KB.bin"

  -- compare the flash file vs post dump file
  if files.compare(filename, goodfile, false) then
    log.success("FPGA-RAM test passed")
    return true
  else
    log.error("FPGA-RAM test failed")
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
  -- CHR-RAM can be maximum 256KB
  -- so we'll check sixteen (32) 8K banks and see if we can write to each

  local chr_ram_size_kb = 256
  local num_banks = math.floor(chr_ram_size_kb / 8) - 1

  log.section("Detecting CHR-RAM size")

  -- set CHR-RAM mode 0 (8K mode)
  dict.nes("NES_CPU_WR", CHR_BANKING_MODE, 0x40)

  -- set CHR bank to bank 0
  dict.nes("NES_CPU_WR", CHR_0_HI, 0)
  -- dict.nes("NES_CPU_WR", CHR_0_LO, 0)

  -- write to banks backwards
  for cur_bank = num_banks, 0, -1 do
    if debug then log.point("trying to write to CHR bank", cur_bank, "of", num_banks) end
    if debug then
      log.point("trying to write to CHR-RAM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Writing", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    dict.nes("NES_CPU_WR", CHR_0_LO, cur_bank) -- 8KB bank at $0000

    -- write data
    dict.nes("NES_PPU_WR", 0x0000, cur_bank)

    cur_bank = cur_bank + 1
  end

  spinner.clear()

  -- read back only last bank
  dict.nes("NES_CPU_WR", CHR_0_LO, num_banks) -- 8KB bank at $0000
  chr_ram_size_kb = (dict.nes("NES_PPU_RD", 0x0000) + 1) * 8

  -- set CHR to CHR-ROM mode 0 (8K mode)
  dict.nes("NES_CPU_WR", CHR_BANKING_MODE, 0)

  if chr_ram_size_kb >= 0 and chr_ram_size_kb <= 256 then
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

  -- set CHR to CHR-RAM mode 0 (8K mode)
  dict.nes("NES_CPU_WR", CHR_BANKING_MODE, 0x40)

  -- set CHR bank to bank 0
  dict.nes("NES_CPU_WR", CHR_0_HI, 0)
  dict.nes("NES_CPU_WR", CHR_0_LO, 0)

  -- write random data to all banks
  log.point("Writing random data to CHR-RAM")
  while cur_bank < num_banks do
    if debug then log.point("init CHR-RAM 8K bank", cur_bank, "of", num_banks - 1) end
    dict.nes("NES_CPU_WR", CHR_0_LO, cur_bank) -- 8KB bank at $0000
    local addr = 0x0000
    while (addr < 0x2000) do
      dict.nes("PPU_PAGE_WR_LFSR", addr)
      addr = addr + 256
    end
    cur_bank = cur_bank + 1
  end

  -- open file
  local filename = opts.write_path .. "./ignore/nes_chr_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))

  -- dump CHR-RAM
  log.point("Dumping CHR-RAM")
  chr_dump(file, chr_ram_size_kb, debug)

  -- set CHR to CHR-ROM mode 0 (8K mode)
  dict.nes("NES_CPU_WR", CHR_BANKING_MODE, 0)

  -- close the file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "./ignore/lfsr_" .. chr_ram_size_kb .. "KB.bin"

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
    log.section("Testing " .. mapname)

    -- nes.cpu_wr(BOOTLOADER_MODE, 0x83) -- flash mode + bootrom

    -- nes.cpu_rd(0x4160)

    -- rv = nes.cpu_rd(0x4120)
    -- nes.cpu_wr(0x4120, rv ~ 0xff)
    -- nes.cpu_rd(0x4120)

    -- nes.cpu_rd(0x4800)
    -- nes.cpu_wr(0x4800, 0xAA)
    -- rv = nes.cpu_rd(0x4800)
    -- nes.cpu_wr(0x4800, rv ~ 0xff)
    -- nes.cpu_rd(0x4800)

    -- nes.cpu_rd(0xFFFA)
    -- nes.cpu_rd(0xFFFB)
    -- nes.cpu_rd(0xFFFC)
    -- nes.cpu_rd(0xFFFD)
    -- nes.cpu_rd(0xFFFE)
    -- nes.cpu_rd(0xFFFF)

    -- nes.cpu_rd(0xFBF2)
    -- nes.cpu_rd(0xFBF3)

    -- do return end


    -- rv = nes.cpu_rd(PRG_BANKING_MODE)
    -- nes.cpu_wr(PRG_BANKING_MODE, rv & 0x7f)

    -- nes.cpu_wr(PRG_6_HI, 0x80)
    -- nes.cpu_wr(PRG_6_LO, 0x00)

    -- nes.cpu_wr(0x6000, 0xaa)
    -- rv = nes.cpu_rd(0x6000)
    -- nes.cpu_wr(0x6000, rv ~ 0xff)
    -- nes.cpu_rd(0x6000)

    -- nes.cpu_wr(0x6000, 0xaa)
    -- nes.cpu_wr(0x7000, 0x55)
    -- nes.cpu_rd(0x6000)
    -- nes.cpu_rd(0x7000)

    -- rv = prg_ram_exercise(32, retroprog_id, DEBUG)

    -- do return end

    dict.nes("NES_CPU_WR", CHR_BANKING_MODE, 0x40) -- CHR-RAM
    chr_ram_detected = nes.ppu_ram_sense(0x1000, DEBUG)
    dict.nes("NES_CPU_WR", CHR_BANKING_MODE, 0)    -- CHR-ROM

    -- verify mirroring is behaving as expected
    rv = mirror_test(chr_size_kb, chr_ram_detected, retroprog_id, DEBUG)
    if not rv then return false end

    if options.force_flash_test or (do_rom_write and prg_size_kb ~= 0) then
      rv = prg_rom_manf_id()
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
      rv = chr_rom_manf_id()
      if not rv then
        if do_rom_write and chr_size_kb ~= 0 then
        log.error("Couldn't identify flash chip")
        return false
        else
          log.warning("Couldn't identify flash chip")
        end
      end
    end

    -- FPGA-RAM tests
    rv = fpga_ram_exercise(retroprog_id, DEBUG)
    -- exit script if test fails
    if not rv then return end

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

    -- map PRG-RAM at $6000
    dict.nes("NES_CPU_WR", PRG_6_HI, 0x80)

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

    -- map PRG-ROM at $6000
    dict.nes("NES_CPU_WR", PRG_6_HI, 0x00)

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
    local nak = 0

    local temp
    local size_to_erase = prg_size_kb

    -- erase PRG-ROM only if needed
    if prg_size_kb ~= 0 then
      init_mapper()
      log.section("Erasing PRG-ROM")
      time.start()

      if (prg_flash_chip.manufacturer_id == 0x01666) then -- Cypress / Spansion
        -- [[
        log.info("erasing only needed sectors...")

        local sectors = math.floor(prg_size_kb / 64)
        size_to_erase = sectors * 64
        local addr
        -- TODO: save the flash chip size so we can decide if it's best to erase sctors or the whole chip
        -- TODO: how can we know the sectors layout (top/bottom boot etc)

        for i = 0, sectors - 1, 1 do
          addr = i * 64 * 1024
          if (DEBUG) then
            log.bullet("erasing sector", i, "of", sectors - 1)
          else
            spinner.update("Erasing sector ", i, "/", sectors - 1) --, string.format("(%06X)", addr))
          end
          temp = prg_erase_sector(addr, DEBUG)
          if temp == false then
            spinner.clear()
            return false
          end
        end
        spinner.clear()
        log.success("Done erasing ROM (" .. sectors .. " sectors)")
      else
        --]]
      dict.nes("NES_CPU_WR", 0x8000, 0xF0)
      dict.nes("NES_CPU_WR", 0x8AAA, 0xAA)
      dict.nes("NES_CPU_WR", 0x8555, 0x55)
      dict.nes("NES_CPU_WR", 0x8AAA, 0x80)
      dict.nes("NES_CPU_WR", 0x8AAA, 0xAA)
      dict.nes("NES_CPU_WR", 0x8555, 0x55)
      dict.nes("NES_CPU_WR", 0x8AAA, 0x10)

      -- TODO create some function to pass the read value
      -- that's smart enough to figure out if the board is actually erasing or not
        nak = 0
      repeat
      rv = dict.nes("NES_CPU_RD", 0x8000)
        spinner.update("Erasing")
          nak = nak + 1
      until rv == dict.nes("NES_CPU_RD", 0x8000)

      spinner.clear()
        log.success("Done erasing PRG-ROM", nak .. " naks")
      end

      time.report(size_to_erase)
    end

    -- erase CHR-ROM only if needed
    if chr_size_kb ~= 0 then
      init_mapper()
      log.section("Erasing CHR-ROM")
      time.start()
      size_to_erase = chr_size_kb

      -- if (chr_flash_chip.manufacturer_id == 0x01) then -- Cypress / Spansion
      if (chr_flash_chip.manufacturer_id == 0x01666) then -- Cypress / Spansion
        local sectors = math.floor(chr_size_kb / 64)
        size_to_erase = sectors * 64
        local addr
        -- TODO: save the flash chip size so we can decide if it's best to erase sctors or the whole chip

        for i = 0, sectors - 1, 1 do
          addr = i * 64 * 1024
          if (DEBUG) then
            log.bullet("erasing CHR sector", i, "of", sectors - 1)
          else
            spinner.update("Erasing CHR sector ", i, "/", sectors - 1)
          end
          temp = chr_erase_sector(addr, DEBUG)
          if temp == false then
            spinner.clear()
            return false
          end
        end

        spinner.clear()
        log.success("Done erasing CHR-ROM (" .. sectors .. " sectors)")
      else
      dict.nes("NES_PPU_WR", 0x1AAA, 0xAA)
      dict.nes("NES_PPU_WR", 0x1555, 0x55)
      dict.nes("NES_PPU_WR", 0x1AAA, 0x80)
      dict.nes("NES_PPU_WR", 0x1AAA, 0xAA)
      dict.nes("NES_PPU_WR", 0x1555, 0x55)
      dict.nes("NES_PPU_WR", 0x1AAA, 0x10)

      -- TODO create some function to pass the read value
      -- that's smart enough to figure out if the board is actually erasing or not
        nak = 0
      repeat
      rv = dict.nes("NES_PPU_RD", 0x0000)
        spinner.update("Erasing")
          nak = nak + 1
      until rv == dict.nes("NES_PPU_RD", 0x0000)

      spinner.clear()
        log.success("Done erasing CHR-ROM", nak .. " naks")
      end

      time.report(size_to_erase)
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
rainbow.process = process

-- return the module's table
return rainbow
