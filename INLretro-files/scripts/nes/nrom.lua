
-- create the module's table
local nrom = {}

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
  local mirroring = nes.detect_mapper_mirroring()

  -- write_header(file, prgKB, chrKB, mapper, mirroring)
  nes.write_header(file, prgKB, chrKB, op_buffer[mapname], mirroring)
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

  log.section("Reading PRG-ROM manufacturer/device ID")

  --enter software mode
  --ROMSEL controls PRG-ROM /OE which needs to be low for flash writes
  --So unlock commands need to be addressed below $8000
  --DISCRETE_EXP0_PRGROM_WR doesn't toggle /ROMSEL by definition though, so A15 is unused
  --      15 14 13 12
  -- 0x5 = 0b  0  1  0  1 -> $5555
  -- 0x2 = 0b  0  0  1  0 -> $2AAA
  dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x5555, 0xAA)
  dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x2AAA, 0x55)
  dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x5555, 0x90)

  manufacturer_id = dict.nes("NES_CPU_RD", 0x8000)
  chips.display_manufacturer(manufacturer_id)

  device_id = dict.nes("NES_CPU_RD", 0x8001)
  device_test = chips.display_device(manufacturer_id, device_id)

  -- exit software
  dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x8000, 0xF0)

  if device_test == false then
    return false
  else
    return true
  end

end

-- write a single byte to PRG-ROM flash
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

-- dump PRG-ROM
local function prg_rom_dump(file, rom_size_KB, debug)

  -- handles 16KB and 32KB NROM
  local KB_per_read = rom_size_KB

  local num_banks = math.floor(rom_size_KB / KB_per_read)
  local cur_bank = 0
  local addr_base = 0x80  -- $8000

  log.info("PRG-ROM size", rom_size_KB .. "KB")

  while cur_bank < num_banks do

    if debug then
      log.point("dumping PRG bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks-1)
    end

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

    if debug then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks-1)
    end

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size, mapname, "PRGROM", false)

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

-- read CHR-ROM flash ID
local function chr_rom_manf_id()

  local manufacturer_id
  local device_id
  local device_test

  log.section("Reading CHR-ROM manufacturer/device ID")

  --enter software mode
  --NROM has A13 tied to A11, and A14 tied to A12.
  --So only A0-12 needs to be valid
  --A13 needs to be low to address CHR-ROM
  --      15 14 13 12
  -- 0x5 = 0b  0  1  0  1 -> $1555
  -- 0x2 = 0b  0  0  1  0 -> $0AAA
  dict.nes("NES_PPU_WR", 0x1555, 0xAA)
  dict.nes("NES_PPU_WR", 0x0AAA, 0x55)
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

-- dump CHR ROM
local function chr_dump(file, rom_size_KB, debug)

  local KB_per_read = 8
  local num_banks = math.floor(rom_size_KB / KB_per_read)
  local cur_bank = 0
  local addr_base = 0x00  -- $0000

  log.info("CHR size", rom_size_KB .. "KB")

  if debug then
    log.point("dump CHR bank", cur_bank, "of", num_banks-1)
  else
    spinner.update("Dumping", cur_bank, "/", num_banks-1)
  end

  dump.dumptofile( file, KB_per_read, addr_base, "NESPPU_PAGE", false )

  spinner.clear()

end

-- host flash one bank at a time
local function chr_rom_flash(file, rom_size_KB, debug)

  log.section("Programming CHR-ROM")
  log.info("CHR-ROM size", rom_size_KB .. "KB")

  local bank_size = 8
  local cur_bank = 0
  local num_banks = math.floor(rom_size_KB / bank_size)

  while cur_bank < num_banks do

    if debug then
      log.point("writing CHR bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks-1)
    end

    -- have the device write a bank worth of data
    flash.write_file( file, bank_size, mapname, "CHRROM", false )

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
  local mirror          = console_opts.mirror

  -- Initialize device i/o
  dict.io("IO_RESET")
  dict.io("NES_INIT")

  -- test cart
  if do_test then

    log.section("Testing", mapname)
    log.info("EXP0 pull-up test", dict.io("EXP0_PULLUP_TEST"))

    local mirroring = nes.detect_mapper_mirroring(DEBUG)
    if nes.header.isValid then
      if      nes.header.mirroringType == nes.MIRRORING_TYPE_HORIZONTAL and mirroring ~= "HORZ"
          or  nes.header.mirroringType == nes.MIRRORING_TYPE_VERTICAL and mirroring ~= "VERT"
          -- or  nes.header.mirroringType == nes.MIRRORING_TYPE_ONE_SCREEN and ( mirroring ~= "1SCRNA" or mirroring ~= "1SCRNB" )
          -- or  nes.header.mirroringType == nes.MIRRORING_TYPE_FOUR_SCREENS and mirroring ~= "4SCRN"
      then
        log.bullet("PCB mirroring sensed:", mirroring)
        log.bullet("NES ROM mirroring:", nes.MIRRORING_TYPE_STRING[nes.header.mirroringType+1])
        log.error("PCB mirroring setting doesn't match NES ROM header")
        return false
      end
    else
      log.warning("Can't verify mirroring setting because you're using a binary file as the flash file")
    end

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

  end

  -- dump cart ROM to file
  if do_rom_dump then

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

  -- erase the cart
  if do_erase then

    local i = 0

    -- erase PRG-ROM only if needed
    if prg_size ~= 0 then
      log.section("Erasing PRG-ROM")
      dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x5555, 0xAA)
      dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x2AAA, 0x55)
      dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x5555, 0x80)
      dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x5555, 0xAA)
      dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x2AAA, 0x55)
      dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x5555, 0x10)
      rv = dict.nes("NES_CPU_RD", 0x8000)

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
      log.section("Erasing CHR-ROM")
      dict.nes("NES_PPU_WR", 0x1555, 0xAA)
      dict.nes("NES_PPU_WR", 0x0AAA, 0x55)
      dict.nes("NES_PPU_WR", 0x1555, 0x80)
      dict.nes("NES_PPU_WR", 0x1555, 0xAA)
      dict.nes("NES_PPU_WR", 0x0AAA, 0x55)
      dict.nes("NES_PPU_WR", 0x1555, 0x10)
      rv = dict.nes("NES_PPU_RD", 0x0000)

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

  -- verify what we just flashed
  if do_verify then

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
nrom.process = process

-- return the module's table
return nrom
