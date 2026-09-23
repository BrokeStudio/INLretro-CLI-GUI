-- create the module's table
local gtrom       = {}

-- import required modules
local dict        = require "scripts.app.dict"
local nes         = require "scripts.app.nes"
local dump        = require "scripts.app.dump"
local flash       = require "scripts.app.flash"
local chips       = require "scripts.app.chips"
local time        = require "scripts.app.time"
local log         = require "scripts.app.log"
local spinner     = require "scripts.app.spinner"
local files       = require "scripts.app.files"
local help        = require "scripts.app.help"

-- file constants and global variables
local mapname     = "GTROM"

-- registers
local BANK_SELECT = 0x5000

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
  nes.write_header(file, prg_kb, chr_kb, op_buffer[mapname], "4SCRN")
end

-- dump NT
local function nt_dump(file, nt)
  local kb_per_read = 1
  local addr_base = 0x20 + nt * 4

  dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NES_PPU_1KB" })
end

-- test the mapper's mirroring modes to verify working properly
-- GTROM always uses 2 sets of 4 nametables
-- returns true if pass, false if failed
local function mirror_test(retroprog_id)
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
    nes.cpu_wr(BANK_SELECT, nt << 5)

    fileA:seek("set")
    fileB:seek("set")
    fileC:seek("set")
    fileD:seek("set")

    nt_dump(fileA, 0)
    nt_dump(fileB, 1)
    nt_dump(fileC, 2)
    nt_dump(fileD, 3)

    fileA:flush()
    fileB:flush()
    fileC:flush()
    fileD:flush()

    if files.compare(filenameA, filenameB, true) == true then
      test = false
      break
    end

    if files.compare(filenameA, filenameC, true) == true then
      test = false
      break
    end

    if files.compare(filenameA, filenameD, true) == true then
      test = false
      break
    end

    if files.compare(filenameB, filenameC, true) == true then
      test = false
      break
    end

    if files.compare(filenameB, filenameD, true) == true then
      test = false
      break
    end

    if files.compare(filenameC, filenameD, true) == true then
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

--- Read and identify the PRG-ROM flash manufacturer/device ID.
-- @return boolean found True when the flash chip is recognized
-- @return table device Flash chip information, or an empty table when unknown
local function prg_rom_manf_id()
  local manufacturer_id
  local device_id
  local found
  local device

  log.section("Reading PRG-ROM manufacturer/device ID")

  -- no bus conflicts
  -- $5000-5FFF / $7000-7FFF writes to mapper
  -- $8000-FFFF writes to mapper
  --
  -- A15 14 - 13 12
  --  1   1    0  1  : 0x5555 -> $D555
  --  1   0    1  0  : 0x2AAA -> $AAAA
  nes.cpu_wr(0xD555, 0xAA)
  nes.cpu_wr(0xAAAA, 0x55)
  nes.cpu_wr(0xD555, 0x90)

  manufacturer_id = nes.cpu_rd(0x8000)
  chips.display_manufacturer(manufacturer_id)

  device_id = nes.cpu_rd(0x8001)
  found, device = chips.display_device(manufacturer_id, device_id)

  -- exit software
  nes.cpu_wr(0x8000, 0xF0)

  return found, device
end

--- Program one byte to PRG-ROM flash and poll for completion.
-- @param addr integer Address to program, 0x8000-0xBFFF
-- @param value integer 8-bit value to write
-- @param bank integer Mapper bank value selecting the target flash bank
local function prg_rom_flash_byte(addr, value, bank)
  if addr < 0x8000 or addr > 0xBFFF then
    log.error("ERROR! flash write to PRG-ROM", help.hex_0x4(addr), "must be $8000-$BFFF")
    return
  end

  nes.cpu_wr(BANK_SELECT, bank)

  nes.cpu_wr(0xD555, 0xAA)
  nes.cpu_wr(0xAAAA, 0x55)
  nes.cpu_wr(0xD555, 0xA0)

  nes.cpu_wr(addr, value)

  local rv = nes.cpu_rd(addr)

  local i = 0

  while rv ~= nes.cpu_rd(addr) do
    rv = nes.cpu_rd(addr)
    i = i + 1
  end

  if DEBUG then
    log.info("Done writing byte,", i .. " naks")
  end

  -- TODO report error if write failed
end

--- Dump PRG-ROM contents to an already-open output file.
-- @param file file* Open binary output file
-- @param rom_size_kb integer PRG-ROM size in kilobytes
local function prg_rom_dump(file, rom_size_kb)
  local kb_per_read = 32
  local num_banks = rom_size_kb // kb_per_read
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
    nes.cpu_wr(BANK_SELECT, cur_bank) -- 32KB @ CPU $8000

    dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NES_CPU_PAGE" })

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--- Program PRG-ROM contents from an already-open input file, one bank at a time.
-- @param file file* Open binary input file
-- @param rom_size_kb integer PRG-ROM size in kilobytes
local function prg_rom_flash(file, rom_size_kb)
  log.section("Programming PRG-ROM")
  log.info("PRG-ROM size", rom_size_kb .. "KB")

  local bank_size_kb = 32
  local cur_bank = 0
  local num_banks = rom_size_kb // bank_size_kb

  while cur_bank < num_banks do
    -- select bank to flash
    nes.cpu_wr(BANK_SELECT, cur_bank)
    dict.nes("SET_CUR_BANK", cur_bank)

    if DEBUG then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end


    -- if DEBUG then
    --  log.info("get bank\t" .. dict.nes("GET_CUR_BANK"))
    -- end

    -- flash data
    flash.write_file(file, bank_size_kb, { mapper = mapname, mem_type = "NES_PRG_ROM" })

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

--- Dump CHR contents to an already-open output file.
-- @param file file* Open binary output file
-- @param rom_size_kb integer CHR size in kilobytes
local function chr_dump(file, rom_size_kb)
  -- CHR dump, all 8KB
  local kb_per_read = 8
  local num_banks = rom_size_kb // kb_per_read
  local cur_bank = 0
  local addr_base = 0x00 -- $0000

  log.info("CHR size", rom_size_kb .. "KB")

  while cur_bank < num_banks do
    if DEBUG then
      log.point("dump CHR bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    nes.cpu_wr(BANK_SELECT, cur_bank << 4) -- 8KB bank at $0000

    dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NES_PPU_PAGE" })

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--- Exercise CHR-RAM with an LFSR pattern and compare the dumped result.
-- Overwrites CHR-RAM contents with the test pattern.
-- @param chr_ram_size_kb integer CHR-RAM size in kilobytes
-- @param retroprog_id string|integer Identifier used in the temporary dump filename
-- @return boolean success True when the CHR-RAM dump matches the expected LFSR data
local function chr_ram_exercise(chr_ram_size_kb, retroprog_id)
  dict.stuff("RESET_LFSR") -- sets it to 1
  -- dict.stuff("SET_LFSR_L", 0) -- lock it up to clear ram
  -- dict.stuff("SET_LFSR_L", 2) -- give different seed for testing fails

  local cur_bank = 0
  local num_banks = chr_ram_size_kb // 8

  log.section("Exercising CHR-RAM")
  log.info("CHR-RAM size", chr_ram_size_kb .. "KB")

  -- write random data to all banks
  log.point("Writing random data to CHR-RAM")
  while cur_bank < num_banks do
    if DEBUG then log.point("init CHR-RAM 8K bank", cur_bank, "of", num_banks - 1) end
    nes.cpu_wr(BANK_SELECT, cur_bank << 4) -- 8KB bank at $0000
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



-- -- select different chr-ram banks and verify all 4 banks are present
-- local function gtrom_chrbank_test()

--   nes.cpu_wr(BANK_SELECT, 0x00) -- PT & NT bank 0
--   nes.ppu_wr(0x0000, 0xAA) -- PT write
--   nes.ppu_wr(0x2000, 0xCC) -- NT write

--   nes.cpu_wr(BANK_SELECT, 0x30) -- PT & NT bank 1
--   nes.ppu_wr(0x0000, 0x55) -- PT write
--   nes.ppu_wr(0x2000, 0x33) -- NT write

--   -- read back
--   local test = true
--   nes.cpu_wr(BANK_SELECT, 0x00) -- CHR bank 0
--   rv = nes.ppu_rd(0x0000)
--   if rv ~= 0xAA then
--     print( "\nFAIL CHR-RAM BANKING TEST!!!\n")
--     print("PT bank0 read:", string.format("%X", rv))
--     test = false
--   end
--   rv = nes.ppu_rd(0x2000)
--   if rv ~= 0xCC then
--     print( "\nFAIL CHR-RAM BANKING TEST!!!\n")
--     print("NT bank0 read:", string.format("%X", rv))
--     test = false
--   end

--   nes.cpu_wr(BANK_SELECT, 0x30) -- CHR bank 1
--   rv = nes.ppu_rd(0x0000)
--   if rv ~= 0x55 then
--     print( "\nFAIL CHR-RAM BANKING TEST!!!\n")
--     print("PT bank1 read:", string.format("%X", rv))
--     test = false
--   end
--   rv = nes.ppu_rd(0x2000)
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

--- Process all requested operations for this cartridge board/mapper.
-- @param process_opts table Parsed operation options from the main application
-- @param console_opts table Console/cartridge size options
-- @return false|nil result False on explicitly reported failure; otherwise no value
local function process(process_opts, console_opts)
  -- some local variables
  local rv               = nil
  local file
  local chr_ram_detected = true
  local chr_ram_size_kb  = 0 -- GTROM uses 32KB of CHR-RAM split into nameblates and patter tables

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

  -- initialize device i/o for NES
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
    rv = mirror_test(retroprog_id)
    if not rv then return false end

    if do_rom_write and prg_size_kb ~= 0 then
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
    chr_ram_size_kb = 16

    -- test CHR-RAM
    if chr_ram_size_kb ~= 0 then
      rv = chr_ram_exercise(chr_ram_size_kb, retroprog_id)
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
      create_header(file, prg_size_kb, chr_size_kb)
    end

    -- dump cart to file
    log.section("Dumping PRG-ROM")
    time.start()
    prg_rom_dump(file, prg_size_kb)
    time.report(prg_size_kb)
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
    if prg_size_kb ~= 0 then
      log.section("Erasing PRG-ROM")
      time.start()
      nes.cpu_wr(0xD555, 0xAA)
      nes.cpu_wr(0xAAAA, 0x55)
      nes.cpu_wr(0xD555, 0x80)
      nes.cpu_wr(0xD555, 0xAA)
      nes.cpu_wr(0xAAAA, 0x55)
      nes.cpu_wr(0xD555, 0x10)

      -- TODO create some function to pass the read value
      -- that's smart enough to figure out if the board is actually erasing or not
      rv = nes.cpu_rd(0x8000)
      while rv ~= nes.cpu_rd(0x8000) do
        spinner.update("Erasing")
        rv = nes.cpu_rd(0x8000)
        i = i + 1
      end
      spinner.clear()
      log.success("Done erasing PRG-ROM", i .. " naks")
      time.report(prg_size_kb)
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
    prg_rom_flash(file, prg_size_kb)
    time.report(prg_size_kb)

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
    prg_rom_dump(file, prg_size_kb)
    time.report(prg_size_kb)
    log.success("PRG-ROM dumping done")

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
gtrom.process = process

-- return the module's table
return gtrom
