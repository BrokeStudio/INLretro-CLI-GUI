-- create the module's table
local nrom    = {}

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
local mapname = "NROM"
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
  local mirroring = nes.detect_mapper_mirroring()

  -- write_header(file, prg_kb, chr_kb, mapper, mirroring)
  nes.write_header(file, prg_kb, chr_kb, op_buffer[mapname], mirroring)
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
-- @param addr integer Address to program, 0x8000-0xFFFF
-- @param value integer 8-bit value to write
-- @param debug? boolean Enable verbose progress logging
local function prg_rom_flash_byte(addr, value, debug)
  if addr < 0x8000 or addr > 0xFFFF then
    log.error("ERROR! flash write to PRG-ROM", help.hex_0x4(addr), "must be $8000-$FFFF")
    return
  end

  -- send unlock command and write byte
  dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x5555, 0xAA)
  dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x2AAA, 0x55)
  dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x5555, 0xA0)
  dict.nes("DISCRETE_EXP0_PRGROM_WR", addr, value)

  local rv = dict.nes("NES_CPU_RD", addr)

  local i = 0

  while rv ~= dict.nes("NES_CPU_RD", addr) do
    rv = dict.nes("NES_CPU_RD", addr)
    i = i + 1
  end

  if debug then
    log.info("Done writing byte,", i .. " naks")
  end
end

--- Dump PRG-ROM contents to an already-open output file.
-- @param file file* Open binary output file
-- @param rom_size_kb integer PRG-ROM size in kilobytes
-- @param debug? boolean Enable verbose progress logging
local function prg_rom_dump(file, rom_size_kb, debug)
  -- handles 16KB and 32KB NROM
  local kb_per_read = rom_size_kb

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
  log.section("Programming PRG-ROM")
  log.info("PRG-ROM size", rom_size_kb .. "KB")

  local bank_size = 32
  local cur_bank = 0
  local num_banks = math.floor(rom_size_kb / bank_size)

  while cur_bank < num_banks do
    if debug then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

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
-- @param addr integer Address to program
-- @param value integer 8-bit value to write
-- @param debug? boolean Enable verbose progress logging
local function wr_chr_flash_byte(addr, value, debug)
  if (addr < 0x0000 or addr > 0x1FFF) then
    log.error("ERROR! flash write to CHR-ROM", help.hex_0x4(addr), "must be $0000-1FFF")
    return
  end

  -- send unlock command and write byte
  dict.nes("NES_PPU_WR", 0x1555, 0xAA)
  dict.nes("NES_PPU_WR", 0x0AAA, 0x55)
  dict.nes("NES_PPU_WR", 0x1555, 0xA0)
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
-- @param file file* Open binary output file
-- @param rom_size_kb integer CHR size in kilobytes
-- @param debug? boolean Enable verbose progress logging
local function chr_dump(file, rom_size_kb, debug)
  local kb_per_read = 8
  local num_banks = math.floor(rom_size_kb / kb_per_read)
  local cur_bank = 0
  local addr_base = 0x00 -- $0000

  log.info("CHR size", rom_size_kb .. "KB")

  if debug then
    log.point("dump CHR bank", cur_bank, "of", num_banks - 1)
  else
    spinner.update("Dumping", cur_bank, "/", num_banks - 1)
  end

  dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NESPPU_PAGE" }, false)

  spinner.clear()
end

--- Program CHR contents from an already-open input file, one bank at a time.
-- @param file file* Open binary input file
-- @param rom_size_kb integer CHR size in kilobytes
-- @param debug? boolean Enable verbose progress logging
local function chr_rom_flash(file, rom_size_kb, debug)
  log.section("Programming CHR-ROM")
  log.info("CHR-ROM size", rom_size_kb .. "KB")

  local bank_size = 8
  local cur_bank = 0
  local num_banks = math.floor(rom_size_kb / bank_size)

  while cur_bank < num_banks do
    if debug then
      log.point("writing CHR bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size, { mapper = mapname, mem_type = "CHRROM" }, false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
  log.success("Done programming CHR-ROM")
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
    log.section("Testing", mapname)
    log.info("EXP0 pull-up test", dict.io("EXP0_PULLUP_TEST"))

    local mirroring = nes.detect_mapper_mirroring(DEBUG)
    log.bullet("PCB mirroring sensed:", mirroring)
    if nes.header.is_valid then
      log.bullet("NES ROM mirroring:", nes.MIRRORING_TYPE_STRING[nes.header.mirroring_type + 1])
      if nes.header.mirroring_type == nes.MIRRORING_TYPE_HORIZONTAL and mirroring ~= "HORZ"
          or nes.header.mirroring_type == nes.MIRRORING_TYPE_VERTICAL and mirroring ~= "VERT"
      -- or  nes.header.mirroring_type == nes.MIRRORING_TYPE_ONE_SCREEN and ( mirroring ~= "1SCRNA" or mirroring ~= "1SCRNB" )
      -- or  nes.header.mirroring_type == nes.MIRRORING_TYPE_FOUR_SCREENS and mirroring ~= "4SCRN"
      then
        log.error("PCB mirroring setting doesn't match NES ROM header")
        return false
      end
    else
      log.warning("Can't verify mirroring setting because you're using a binary file as the flash file")
    end

    -- attempt to read PRG-ROM flash ID
    if options.force_flash_test or (do_rom_write and prg_size_kb ~= 0) then
      --ROMSEL controls PRG-ROM /OE which needs to be low for flash writes
      --So unlock commands need to be addressed below $8000
      --DISCRETE_EXP0_PRGROM_WR doesn't toggle /ROMSEL by definition though, so A15 is unused
      --      15 14 13 12
      -- 0x5 = 0b  0  1  0  1 -> $5555
      -- 0x2 = 0b  0  0  1  0 -> $2AAA
      rv, prg_flash_chip = nes.prg_rom_get_chip({ opcode = "DISCRETE_EXP0_PRGROM_WR" })
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
      --NROM has A13 tied to A11, and A14 tied to A12.
      --So only A0-12 needs to be valid
      --A13 needs to be low to address CHR-ROM
      --      15 14 13 12
      -- 0x5 = 0b  0  1  0  1 -> $1555
      -- 0x2 = 0b  0  0  1  0 -> $0AAA
      rv, chr_flash_chip = nes.chr_rom_get_chip(
        {
          unlock_profile_name = "long",
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
      rv = nes.prg_rom_erase(prg_flash_chip, DEBUG, { opcode = "DISCRETE_EXP0_PRGROM_WR" })
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
        log.error("PRG-ROM couldn't be erased")
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
nrom.process = process

-- return the module's table
return nrom
