-- create the module's table
local gtrom   = {}

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

-- file constants & variables
local mapname = "GTROM"

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
  nes.write_header(file, prg_kb, chr_kb, op_buffer[mapname], "4SCRN")
end

-- dump NT
local function nt_dump(file, nt, debug)
  local KB_per_read = 1
  local addr_base = 0x20 + nt * 4

  dump.dumptofile(file, KB_per_read, addr_base, "NESPPU_1KB", debug)
end

-- test the mapper's mirroring modes to verify working properly
-- GTROM always uses 2 sets of 4 nametables
-- returns true if pass, false if failed
local function mirror_test(retroprog_id, debug)
  log.section("Testing mirroring settings")

  -- 4 screen
  local test = true

  local filenameA = opts.write_path .. "./ignore/nes_ppu_ntA_dump-" .. retroprog_id .. ".bin"
  local filenameB = opts.write_path .. "./ignore/nes_ppu_ntB_dump-" .. retroprog_id .. ".bin"
  local filenameC = opts.write_path .. "./ignore/nes_ppu_ntC_dump-" .. retroprog_id .. ".bin"
  local filenameD = opts.write_path .. "./ignore/nes_ppu_ntD_dump-" .. retroprog_id .. ".bin"

  local fileA = assert(io.open(filenameA, "wb"))
  local fileB = assert(io.open(filenameB, "wb"))
  local fileC = assert(io.open(filenameC, "wb"))
  local fileD = assert(io.open(filenameD, "wb"))

  for nt = 0, 1, 1 do
    spinner.update("NT", nt, "/", 1)

    -- enable set of 4 nametables
    dict.nes("NES_CPU_WR", 0x5000, nt << 5)

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

    if files.compare(filenameA, filenameB, true, false) == true then
      test = false
      break
    end

    if files.compare(filenameA, filenameC, true, false) == true then
      test = false
      break
    end

    if files.compare(filenameA, filenameD, true, false) == true then
      test = false
      break
    end

    if files.compare(filenameB, filenameC, true, false) == true then
      test = false
      break
    end

    if files.compare(filenameB, filenameD, true, false) == true then
      test = false
      break
    end

    if files.compare(filenameC, filenameD, true, false) == true then
      test = false
      break
    end
  end

  spinner.clear()

  if test == false then
    log.error("Four screen mirroring test failed")
  else
    log.success("Four screen mirroring test passed")
  end

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

  --no bus conflicts
  --$5000-5FFF / $7000-7FFF writes to mapper
  --$8000-FFFF writes to mapper
  --
  --A15 14 - 13 12
  -- 1   1    0  1  : 0x5555 -> $D555
  -- 1   0    1  0  : 0x2AAA -> $AAAA
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

-- REQ: addr must be in the first bank $8000-BFFF
local function prg_rom_flash_byte(addr, value, bank, debug)
  if addr < 0x8000 or addr > 0xBFFF then
    log.error("ERROR! flash write to PRG-ROM", help.hex_0x4(addr), "must be $8000-$BFFF")
    return
  end

  dict.nes("NES_CPU_WR", 0x5000, bank)

  dict.nes("NES_CPU_WR", 0xD555, 0xAA)
  dict.nes("NES_CPU_WR", 0xAAAA, 0x55)
  dict.nes("NES_CPU_WR", 0xD555, 0xA0)

  dict.nes("NES_CPU_WR", addr, value)

  local rv = dict.nes("NES_CPU_RD", addr)

  local i = 0

  while rv ~= dict.nes("NES_CPU_RD", addr) do
    rv = dict.nes("NES_CPU_RD", addr)
    i = i + 1
  end

  if debug then
    log.info("Done writing byte,", i .. " naks")
  end

  -- TODO report error if write failed
end

-- dump PRG-ROM
local function prg_rom_dump(file, rom_size_KB, debug)
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

    -- select desired bank(s) to dump
    dict.nes("NES_CPU_WR", 0x5000, cur_bank) --32KB @ CPU $8000

    dump.dumptofile(file, KB_per_read, addr_base, "NESCPU_PAGE", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

-- host flash one bank at a time
local function prg_rom_flash(file, rom_size_KB, debug)
  log.section("Programming PRG-ROM")
  log.info("PRG-ROM size", rom_size_KB .. "KB")

  local bank_size = 32
  local cur_bank = 0
  local num_banks = math.floor(rom_size_KB / bank_size)

  while cur_bank < num_banks do
    -- select bank to flash
    dict.nes("NES_CPU_WR", 0x5000, cur_bank)
    dict.nes("SET_CUR_BANK", cur_bank)

    if debug then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end


    -- if debug then
    --  log.info("get bank\t" .. dict.nes("GET_CUR_BANK"))
    -- end

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size, mapname, "PRGROM", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
  log.success("Done programming PRG-ROM")
end

--[[
 ██████╗██╗  ██╗██████╗       ██████╗  █████╗ ███╗   ███╗
██╔════╝██║  ██║██╔══██╗      ██╔══██╗██╔══██╗████╗ ████║
██║     ███████║██████╔╝█████╗██████╔╝███████║██╔████╔██║
██║     ██╔══██║██╔══██╗╚════╝██╔══██╗██╔══██║██║╚██╔╝██║
╚██████╗██║  ██║██║  ██║      ██║  ██║██║  ██║██║ ╚═╝ ██║
 ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝      ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝

--]]


-- dump CHR RAM
local function chr_dump(file, rom_size_KB, debug)
  -- CHR dump, all 8KB
  local KB_per_read = 8
  local num_banks = math.floor(rom_size_KB / KB_per_read)
  local cur_bank = 0
  local addr_base = 0x00 -- $0000

  log.info("CHR size", rom_size_KB .. "KB")

  while cur_bank < num_banks do
    if debug then
      log.point("dump CHR bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    dict.nes("NES_CPU_WR", 0x5000, cur_bank << 4) -- 8KB bank at $0000

    dump.dumptofile(file, KB_per_read, addr_base, "NESPPU_PAGE", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

local function chr_ram_exercise(chr_ram_size, retroprog_id, debug)
  dict.stuff("RESET_LFSR") -- sets it to 1
  -- dict.stuff("SET_LFSR_L", 0) --lock it up to clear ram
  -- dict.stuff("SET_LFSR_L", 2) --give different seed for testing fails

  local cur_bank = 0
  local num_banks = math.floor(chr_ram_size / 8)

  log.section("Exercising CHR-RAM")
  log.info("CHR-RAM size", chr_ram_size .. "KB")

  -- write random data to all banks
  log.point("Writing random data to CHR-RAM")
  while cur_bank < num_banks do
    if debug then log.point("init CHR-RAM 8K bank", cur_bank, "of", num_banks - 1) end
    dict.nes("NES_CPU_WR", 0x5000, cur_bank << 4) -- 8KB bank at $0000
    local addr = 0x0000
    while addr < 0x2000 do
      dict.nes("PPU_PAGE_WR_LFSR", addr)
      addr = addr + 256
    end
    cur_bank = cur_bank + 1
  end

  -- dump CHR-RAM
  local filename = opts.write_path .. "./ignore/nes_chr_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))
  log.point("Dumping CHR-RAM")
  chr_dump(file, chr_ram_size, debug)

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



-- -- select different chr-ram banks and verify all 4 banks are present
-- local function gtrom_chrbank_test()

--   dict.nes("NES_CPU_WR", 0x5000, 0x00) --PT & NT bank 0
--   dict.nes("NES_PPU_WR", 0x0000, 0xAA) --PT write
--   dict.nes("NES_PPU_WR", 0x2000, 0xCC) --NT write

--   dict.nes("NES_CPU_WR", 0x5000, 0x30) --PT & NT bank 1
--   dict.nes("NES_PPU_WR", 0x0000, 0x55) --PT write
--   dict.nes("NES_PPU_WR", 0x2000, 0x33) --NT write

--   --read back
--   local test = true
--   dict.nes("NES_CPU_WR", 0x5000, 0x00) --CHR bank 0
--   rv = dict.nes("NES_PPU_RD", 0x0000)
--   if rv ~= 0xAA then
--     print( "\nFAIL CHR-RAM BANKING TEST!!!\n")
--     print("PT bank0 read:", string.format("%X", rv))
--     test = false
--   end
--   rv = dict.nes("NES_PPU_RD", 0x2000)
--   if rv ~= 0xCC then
--     print( "\nFAIL CHR-RAM BANKING TEST!!!\n")
--     print("NT bank0 read:", string.format("%X", rv))
--     test = false
--   end

--   dict.nes("NES_CPU_WR", 0x5000, 0x30) --CHR bank 1
--   rv = dict.nes("NES_PPU_RD", 0x0000)
--   if rv ~= 0x55 then
--     print( "\nFAIL CHR-RAM BANKING TEST!!!\n")
--     print("PT bank1 read:", string.format("%X", rv))
--     test = false
--   end
--   rv = dict.nes("NES_PPU_RD", 0x2000)
--   if rv ~= 0x33 then
--     print( "\nFAIL CHR-RAM BANKING TEST!!!\n")
--     print("NT bank1 read:", string.format("%X", rv))
--     test = false
--   end

--   if test then
--     print("CHR-RAM BANKING TEST PASSED")
--     return true
--   else
--     print("CHR-RAM BANKING TEST FAILED")
--     return false
--   end
-- end

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
  local chr_ram_detected = true
  local chr_ram_size     = 0 -- GTROM uses 32KB of CHR-RAM split into nameblates and patter tables

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
    log.section("Testing " .. mapname)
    log.info("EXP0 pull-up test", dict.io("EXP0_PULLUP_TEST"))

    -- verify mirroring is behaving as expected
    rv = mirror_test(retroprog_id, DEBUG)
    if not rv then return false end

    if do_rom_write and prg_size ~= 0 then
      rv = prg_rom_manf_id()
      if not rv then
        log.error("Couldn't identify flash chip")
        return false
      end
    end

    chr_ram_detected = nes.ppu_ram_sense(0x1000)
    if not chr_ram_detected then
      log.error("CHR-RAM not detected")
      return
    end

    -- CHR-RAM tests
    chr_ram_size = 16

    -- test CHR-RAM
    if chr_ram_size ~= 0 then
      rv = chr_ram_exercise(chr_ram_size, retroprog_id, DEBUG)
      -- exit script if test fails
      if not rv then return end
    end
  end

  --[[
  88""Yb  dP"Yb  8b    d8     8888b.  88   88 8b    d8 88""Yb
  88__dP dP   Yb 88b  d88      8I  Yb 88   88 88b  d88 88__dP
  88"Yb  Yb   dP 88YbdP88      8I  dY Y8   8P 88YbdP88 88"""
  88  Yb  YbodP  88 YY 88     8888Y"  `YbodP' 88 YY 88 88
  --]]

  -- dump cart ROM to file
  if do_rom_dump then
    -- open file
    file = assert(io.open(rom_dump_file.filename, "wb"))

    -- create header: pass open & empty file & rom sizes
    if rom_dump_file.ext == "nes" then
      create_header(file, prg_size, chr_size)
    end

    -- dump cart to file
    log.section("Dumping PRG-ROM")
    time.start()
    prg_rom_dump(file, prg_size, DEBUG)
    time.report(prg_size)
    log.success("PRG-ROM dumping done")

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
      time.start()
      dict.nes("NES_CPU_WR", 0xD555, 0xAA)
      dict.nes("NES_CPU_WR", 0xAAAA, 0x55)
      dict.nes("NES_CPU_WR", 0xD555, 0x80)
      dict.nes("NES_CPU_WR", 0xD555, 0xAA)
      dict.nes("NES_CPU_WR", 0xAAAA, 0x55)
      dict.nes("NES_CPU_WR", 0xD555, 0x10)

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
      time.report(prg_size)
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
    time.start()
    prg_rom_flash(file, prg_size, DEBUG)
    time.report(prg_size)

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
    -- open file
    file = assert(io.open(verify_file.filename, "wb"))

    -- dump cart to file
    log.section("Dumping PRG-ROM")
    time.start()
    prg_rom_dump(file, prg_size, DEBUG)
    time.report(prg_size)
    log.success("PRG-ROM dumping done")

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
gtrom.process = process

-- return the module's table
return gtrom
