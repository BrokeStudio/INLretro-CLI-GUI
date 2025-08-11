
-- create the module's table
local rainbow          = {}

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
local mapname            = "RNBW" --"Rainbow"

local PRG_BANKING_MODE  = 0x4100
local PRG_6_HI          = 0x4106
local PRG_7_HI          = 0x4107
local PRG_8_HI          = 0x4108
local PRG_5_LO          = 0x4115
local PRG_6_LO          = 0x4116
local PRG_7_LO          = 0x4117
local PRG_8_LO          = 0x4118
local CHR_BANKING_MODE  = 0x4120
local NT_A_BANK         = 0x4126
local NT_B_BANK         = 0x4127
local NT_C_BANK         = 0x4128
local NT_D_BANK         = 0x4129
local NT_A_CTRL         = 0x412A
local NT_B_CTRL         = 0x412B
local NT_C_CTRL         = 0x412C
local NT_D_CTRL         = 0x412D
local CHR_0_HI          = 0x4130
local CHR_0_LO          = 0x4140
local WIFI_CONTROL      = 0x4190
local WIFI_RX           = 0x4191
local WIFI_TX           = 0x4192
local WIFI_RX_ADD       = 0x4193
local WIFI_TX_ADD       = 0x4194
local BOOTLOADER_MODE   = 0x41FF

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

local function create_header(file, prgKB, chrKB)
  -- write_header(file, prgKB, chrKB, mapper, mirroring)
  nes.write_header(file, prgKB, chrKB, op_buffer[mapname], 0)
end

-- dump NT
local function nt_dump(file, nt, debug)

  local KB_per_read = 1
  local addr_base = 0x20 + nt * 4

  dump.dumptofile(file, KB_per_read, addr_base, "NESPPU_1KB", debug)

end

local function _mirror_test(retroprog_id, debug)

  local nt_max = 255
  local test = true

  local filenameA = opts.lua_path .. "ignore/nes_ppu_ntA_dump-" .. retroprog_id .. ".bin"
  local filenameB = opts.lua_path .. "ignore/nes_ppu_ntB_dump-" .. retroprog_id .. ".bin"
  local filenameC = opts.lua_path .. "ignore/nes_ppu_ntC_dump-" .. retroprog_id .. ".bin"
  local filenameD = opts.lua_path .. "ignore/nes_ppu_ntD_dump-" .. retroprog_id .. ".bin"

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
    dict.nes("NES_CPU_WR", NT_C_BANK, (nt+1)&0xff)
    dict.nes("NES_CPU_WR", NT_D_BANK, (nt+1)&0xff)

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
    dict.nes("NES_CPU_WR", NT_B_BANK, (nt+1)&0xff)
    dict.nes("NES_CPU_WR", NT_C_BANK, nt)
    dict.nes("NES_CPU_WR", NT_D_BANK, (nt+1)&0xff)

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
local function mirror_test(chr_size, chr_ram_detected, retroprog_id, debug)

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
  if chr_size ~= 0 then
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
  -- log.point("FPGA-RAM")
  -- dict.nes("NES_CPU_WR", NT_A_CTRL, 0x80)
  -- dict.nes("NES_CPU_WR", NT_B_CTRL, 0x80)
  -- dict.nes("NES_CPU_WR", NT_C_CTRL, 0x80)
  -- dict.nes("NES_CPU_WR", NT_D_CTRL, 0x80)
  -- if _mirror_test(retroprog_id, debug) == false then
  --  return false
  -- end

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
    device_id = device_id | ( dict.nes("NES_CPU_RD", 0x801C) << 8 )
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

-- REQ: addr must be in the first bank $8000-BFFF
local function prg_rom_flash_byte(addr, value, bank, debug)
  if addr < 0x8000 or addr > 0xBFFF then
    log.error("ERROR! flash write to PRG-ROM", help.hex_0x4(addr), "must be $8000-$BFFF")
    return
  end

  -- /!\ needs to be in unlock bypass mode
  dict.nes("NES_CPU_WR", addr, 0xA0)
  dict.nes("NES_CPU_WR", addr, value)

  local rv = dict.nes("NES_CPU_RD", addr)

  local i = 0

  while (rv ~= value) do
    rv = dict.nes("NES_CPU_RD", addr)
    i = i + 1
  end
  if debug then print(i, "naks, done writing byte.") end

  --TODO report error if write failed
end

-- dump PRG-ROM
local function prg_rom_dump(file, rom_size_KB, debug)

  -- PRG-ROM dump 32KB at a time
  -- using PRG mode 0
  local KB_per_read = 32
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

    -- select desired bank to dump
    dict.nes("NES_CPU_WR", PRG_8_HI, (cur_bank & 0xff00) >> 8)  --32KB @ CPU $8000
    dict.nes("NES_CPU_WR", PRG_8_LO,  cur_bank & 0x00ff)        --32KB @ CPU $8000

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

  -- -- enter unlock bypass mode
  -- dict.nes("NES_CPU_WR", 0x8AAA, 0xAA)
  -- dict.nes("NES_CPU_WR", 0x8555, 0x55)
  -- dict.nes("NES_CPU_WR", 0x8AAA, 0x20)

  while cur_bank < num_banks do

    if debug then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks-1)
    end

    -- write the bank to flash to the mapper register
    dict.nes("NES_CPU_WR", PRG_8_HI, (cur_bank & 0xff00) >> 8) --8KB @ CPU $8000
    dict.nes("NES_CPU_WR", PRG_8_LO, (cur_bank & 0x00ff))      --8KB @ CPU $8000

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size, mapname, "PRGROM", false)

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

-- read CHR-ROM flash ID
local function chr_rom_manf_id()

  local manufacturer_id
  local device_id
  local device_test

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
  device_test = chips.display_device(manufacturer_id, device_id)

  device_id = dict.nes("NES_PPU_RD", 0x0002) << 16
  device_id = device_id | ( dict.nes("NES_PPU_RD", 0x001C) << 8 )
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

-- write a single byte to CHR-ROM flash
-- PRE: assumes mapper is initialized and bank is selected as prescribed in mapper_init
-- REQ: addr must be in the first 2 banks $0000-0FFF
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

-- dump CHR-ROM/RAM
local function chr_dump(file, rom_size_KB, debug)

  local KB_per_read = 8
  local num_banks = math.floor(rom_size_KB / KB_per_read)
  local addr_base = 0x00 -- $0000
  local cur_bank = 0

  log.info("CHR size", rom_size_KB .. "KB")

  while cur_bank < num_banks do

    if debug then
      log.point("dump CHR bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks-1)
    end

    dict.nes("NES_CPU_WR", CHR_0_HI, (cur_bank & 0xff00) >> 8)  -- 8KB @ PPU $0000
    dict.nes("NES_CPU_WR", CHR_0_LO,  cur_bank & 0xff)          -- 8KB @ PPU $0000

    dump.dumptofile(file, KB_per_read, addr_base, "NESPPU_1KB", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()

end

-- host flash one bank at a time
local function chr_rom_flash(file, rom_size_KB, debug)

  init_mapper()

  log.section("Programming CHR-ROM")
  log.info("CHR-ROM size", rom_size_KB .. "KB")

  local bank_size = 8 * 1024  -- 8KByte per CHR bank
  local cur_bank = 0
  local num_banks = math.floor(rom_size_KB * 1024 / bank_size)

  while cur_bank < num_banks do

    if debug then
      log.point("writing CHR bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks-1)
    end

    -- set bank
    dict.nes("NES_CPU_WR", CHR_0_HI, (cur_bank & 0xff00) >> 8) -- 8KB @ PPU $0000
    dict.nes("NES_CPU_WR", CHR_0_LO, cur_bank & 0xff)          -- 8KB @ PPU $0000

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size / 1024, mapname, "CHRROM", false)

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
    dict.nes("NES_CPU_WR", PRG_6_LO, cur_bank)

    dump.dumptofile(file, KB_per_read, addr_base, "NESCPU_PAGE", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()

end

-- host write one bank at a time
local function prg_ram_write(file, ram_size_KB, debug)
  -- TODO
  log.error("TODO: prg_ram_write")
  do return end

  init_mapper()

  log.info("PRG-RAM size", ram_size_KB .. "KB")

  local bank_size = 8
  local cur_bank = 0
  local num_banks = math.floor(ram_size_KB / bank_size)

  -- map PRG-RAM at $6000
  dict.nes("NES_CPU_WR", PRG_6_HI, 0x80)

  while cur_bank < num_banks do

    if debug then
      log.point("writing PRG-RAM bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks-1)
    end

    -- set bank
    dict.nes("NES_CPU_WR", PRG_6_LO, cur_bank)

    --have the device write a bank worth of data
    flash.write_file(file, bank_size, "NOVAR", "PRGRAM", false )

    cur_bank = cur_bank + 1
  end

  -- map PRG-ROM at $6000
  dict.nes("NES_CPU_WR", PRG_6_HI, 0x00)

  spinner.clear()
  log.success("Done programming PRG-RAM")

end

-- try to detect if PRG-RAM is present
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

-- try to detect PRG-RAM size
local function prg_ram_get_size(debug)

  -- PRG-RAM can be maximum 128KB
  -- so we'll check sixteen (16) 8K banks and see if we can write to each

  local prg_ram_size = 8 --32 -- 128 -- let's use 32K as default value for now
  local num_banks = math.floor(prg_ram_size / 8)
  local cur_bank = num_banks - 1

  log.section("Detecting PRG-RAM size")

  -- set PRG-RAM mode to 8K
  local rv = dict.nes("NES_CPU_RD", PRG_BANKING_MODE)
  dict.nes("NES_CPU_WR", PRG_BANKING_MODE, rv & 0x7f)

  -- map PRG-RAM at $6000
  dict.nes("NES_CPU_WR", PRG_6_HI, 0x80)

  -- write to banks backwards
  while cur_bank >= 0 do

    if debug then
      log.point("trying to write to PRG-RAM bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Writing", cur_bank, "/", num_banks-1)
    end

    -- set bank
    dict.nes("NES_CPU_WR", PRG_6_LO, cur_bank)

    -- write data
    dict.nes("NES_CPU_WR", 0x6000, cur_bank)

    cur_bank = cur_bank - 1
  end

  spinner.clear()

  -- read back only last bank
  dict.nes("NES_CPU_WR", PRG_6_LO, num_banks - 1)
  prg_ram_size = ( dict.nes("NES_CPU_RD", 0x6000) + 1 ) * 8

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

  dict.stuff("RESET_LFSR")  -- sets it to 1

  local cur_bank = 0
  local num_banks = math.floor(wram_size / 8)

  log.section("Exercising PRG-RAM")
  log.info("PRG-RAM size", wram_size .. "KB")

  -- map PRG-RAM at $6000
  dict.nes("NES_CPU_WR", PRG_6_HI, 0x80)

  -- write random data to all banks
  log.point("Writing random data to PRG-RAM")
  while cur_bank < num_banks do

    if debug then
      log.point("init PRG-RAM 8K bank", cur_bank, "of", num_banks-1)
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
  local filename = opts.lua_path .. "ignore/nes_prg_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))

  -- dump PRG-RAM
  log.point("Dumping PRG-RAM")
  prg_ram_dump(file, wram_size, false)

  -- close file
  assert(file:close())

  -- map PRG-ROM at $6000
  dict.nes("NES_CPU_WR", PRG_6_HI, 0x00)

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
███████╗██████╗  ██████╗  █████╗       ██████╗  █████╗ ███╗   ███╗
██╔════╝██╔══██╗██╔════╝ ██╔══██╗      ██╔══██╗██╔══██╗████╗ ████║
█████╗  ██████╔╝██║  ███╗███████║█████╗██████╔╝███████║██╔████╔██║
██╔══╝  ██╔═══╝ ██║   ██║██╔══██║╚════╝██╔══██╗██╔══██║██║╚██╔╝██║
██║     ██║     ╚██████╔╝██║  ██║      ██║  ██║██║  ██║██║ ╚═╝ ██║
╚═╝     ╚═╝      ╚═════╝ ╚═╝  ╚═╝      ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝

--]]

-- dump the FPGA-RAM
local function fpga_ram_dump( file, rom_size_KB, debug )

  local KB_per_read = 4
  local num_banks = rom_size_KB / KB_per_read
  local addr_base = 0x50  -- $5000
  local cur_bank = 0

  log.info("FPGA-RAM size", rom_size_KB .. "KB")

  while cur_bank < num_banks do

    dict.nes("NES_CPU_WR", PRG_5_LO, cur_bank) -- 4KB PRG-RAM bank at $5000

    if debug then
      log.point("dump FPGA-RAM bank ", cur_bank, "of", num_banks-1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks-1)
    end

    dump.dumptofile(file, KB_per_read, addr_base, "NESCPU_PAGE", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()

end

local function fpga_ram_exercise(retroprog_id, debug)

  dict.stuff("RESET_LFSR")  -- sets it to 1

  local fpga_ram_size = 8
  local cur_bank = 0
  local num_banks = math.floor((fpga_ram_size / 4))

  log.section("Exercising FPGA-RAM")
  log.info("FPGA-RAM size", fpga_ram_size .. "KB")

  -- set FPGA-RAM bank to bank 0
  dict.nes("NES_CPU_WR", PRG_5_LO, 0x00) -- 4KB bank at $5000

  -- write random data to all banks
  log.point("Writing random data to FPGA-RAM")
  while cur_bank < num_banks do
    if debug then log.point("init FPGA-RAM 4K bank", cur_bank, "of", num_banks-1) end
    dict.nes("NES_CPU_WR", PRG_5_LO, cur_bank) -- 8KB bank at $5000
    local addr = 0x5000
    while (addr < 0x6000) do
      dict.nes("CPU_PAGE_WR_LFSR", addr)
      addr = addr + 256
    end
    cur_bank = cur_bank + 1
  end

  -- open file
  local filename = opts.lua_path .. "ignore/nes_fpga_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))

  -- dump FPGA-RAM
  log.point("Dumping FPGA-RAM")
  fpga_ram_dump(file, fpga_ram_size, false)

  -- close file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "ignore/lfsr_32KB.bin"

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

-- select different chr-ram banks and verify all banks are present
local function chr_ram_get_size(debug)

  -- CHR-RAM can be maximum 128KB
  -- so we'll check sixteen (16) 8K banks and see if we can write to each

  local chr_ram_size = 32 -- 128 -- let's use 32K as default value for now
  local num_banks = math.floor(chr_ram_size / 4) - 1
  local rv

  log.section("Detecting CHR-RAM size")

  -- set CHR to CHR-RAM mode 0 (8K mode)
  dict.nes("NES_CPU_WR", CHR_BANKING_MODE, 0x40)

  -- set CHR bank to bank 0
  dict.nes("NES_CPU_WR", CHR_0_HI, 0)
  dict.nes("NES_CPU_WR", CHR_0_LO, 0)

  -- write to banks backwards
  for cur_bank = num_banks, 0, -1 do
    if debug then log.point("trying to write to CHR bank", cur_bank, "of", num_banks) end
    dict.nes("NES_CPU_WR", CHR_0_LO, cur_bank)  -- 8KB bank at $0000
    dict.nes("NES_PPU_WR", 0x0000, cur_bank)
    cur_bank = cur_bank + 1
  end

  -- read back only last bank
  dict.nes("NES_CPU_WR", CHR_0_LO, num_banks) -- 8KB bank at $0000
  rv = dict.nes("NES_PPU_RD", 0x0000)
  chr_ram_size = ( rv + 1 ) * 8

  -- set CHR to CHR-ROM mode 0 (8K mode)
  dict.nes("NES_CPU_WR", CHR_BANKING_MODE, 0)

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

  -- set CHR to CHR-RAM mode 0 (8K mode)
  dict.nes("NES_CPU_WR", CHR_BANKING_MODE, 0x40)

  -- set CHR bank to bank 0
  dict.nes("NES_CPU_WR", CHR_0_HI, 0)
  dict.nes("NES_CPU_WR", CHR_0_LO, 0)

  -- write random data to all banks
  log.point("Writing random data to CHR-RAM")
  while cur_bank < num_banks do
    if debug then log.point("init CHR-RAM 8K bank", cur_bank, "of", num_banks-1) end
    dict.nes("NES_CPU_WR", CHR_0_LO, cur_bank)  -- 8KB bank at $0000
    local addr = 0x0000
    while (addr < 0x2000) do
      dict.nes("PPU_PAGE_WR_LFSR", addr)
      addr = addr + 256
    end
    cur_bank = cur_bank + 1
  end

  -- open file
  local filename = opts.lua_path .. "ignore/nes_chr_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))

  -- dump CHR-RAM
  log.point("Dumping CHR-RAM")
  chr_dump(file, chr_ram_size, debug)

  -- set CHR to CHR-ROM mode 0 (8K mode)
  dict.nes("NES_CPU_WR", CHR_BANKING_MODE, 0)

  -- close the file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "ignore/lfsr_32KB.bin"

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

    log.section("Testing ".. mapname)


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

    dict.nes("NES_CPU_WR", CHR_BANKING_MODE, 0x40)  -- CHR-RAM
    chr_ram_detected = nes.ppu_ram_sense(0x1000, DEBUG)
    dict.nes("NES_CPU_WR", CHR_BANKING_MODE, 0) -- CHR-ROM

    -- verify mirroring is behaving as expected
    rv = mirror_test(chr_size, chr_ram_detected, retroprog_id, DEBUG)
    if not rv then return false end

    if options.force_flash_test or (do_rom_write and prg_size ~= 0) then
      rv = prg_rom_manf_id()
      if not rv then
        log.error("Couldn't identify flash chip")
        return false
      end
    end

    if options.force_flash_test or (do_rom_write and chr_size ~= 0) then
      rv = chr_rom_manf_id()
      if not rv then
        log.error("Couldn't identify flash chip")
        return false
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

    -- map PRG-RAM at $6000
    dict.nes("NES_CPU_WR", PRG_6_HI, 0x80)

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
      log.section("Erasing PRG-ROM")
      dict.nes("NES_CPU_WR", 0x8AAA, 0xAA)
      dict.nes("NES_CPU_WR", 0x8555, 0x55)
      dict.nes("NES_CPU_WR", 0x8AAA, 0x80)
      dict.nes("NES_CPU_WR", 0x8AAA, 0xAA)
      dict.nes("NES_CPU_WR", 0x8555, 0x55)
      dict.nes("NES_CPU_WR", 0x8AAA, 0x10)

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
      dict.nes("NES_PPU_WR", 0x1AAA, 0xAA)
      dict.nes("NES_PPU_WR", 0x1555, 0x55)
      dict.nes("NES_PPU_WR", 0x1AAA, 0x80)
      dict.nes("NES_PPU_WR", 0x1AAA, 0xAA)
      dict.nes("NES_PPU_WR", 0x1555, 0x55)
      dict.nes("NES_PPU_WR", 0x1AAA, 0x10)

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
rainbow.process = process

-- return the module's table
return rainbow
