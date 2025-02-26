-- create the module's table
local bnrom = {}

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
local mapname = "BxROM"
local bank_table_base

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
  nes.write_header(file, prgKB, 0, op_buffer[mapname], mirroring)
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

  local KB_per_read = 32
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

    -- set bank
    dict.nes("NES_CPU_WR", bank_table_base + cur_bank, cur_bank)  -- 32KB @ CPU $8000

    dump.dumptofile(file, KB_per_read, addr_base, "NESCPU_PAGE", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()

end

-- host flash one bank at a time
local function prg_rom_flash(file, rom_size_KB, debug)

  log.section("Programming PRG-ROM")
  log.info("PRG-ROM size", rom_size_KB .. "KB")

  local bank_size = 32  --BNROM 32KByte per PRG bank
  local cur_bank = 0
  local num_banks = math.floor(rom_size_KB / bank_size)

  while cur_bank < num_banks do

    if debug then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks-1)
    end

    -- set bank
    dict.nes("NES_CPU_WR", bank_table_base + cur_bank, cur_bank)  -- 32KB @ CPU $8000

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size, "NROM", "PRGROM", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
  log.success("Done programming PRG-ROM")

end

-- base is the actual NES CPU address, not the rom offset (ie $FFF0, not $7FF0)
local function wr_bank_table(base, entries, debug)

  entries = math.floor(entries)

  -- BNROM needs to have a bank table present in each and every bank
  -- it should also be at the same location in every bank

  -- --first select the last bank as cartridge should be erased (all 0xFF)
  -- --go ahead and write the value to where it's supposed to be incase rom isn't erased
  -- dict.nes("NES_CPU_WR", base+entries-1, entries-1)
  -- 
  -- --write bank table to selected bank
  -- while i < entries do
  --   prg_rom_flash_byte(base+i, i)
  --   i = i+1;
  -- end
  -- --now we can use that bank table to jump to any other bank

  -- smarter solution is to simply count down so we can use just one loop

  log.section("Writing bank table @ " .. help.hex_0x4(base))

  local cur_bank = entries - 1 --16 minus 1 is 15 = 0x0F

  while cur_bank >= 0 do

    if debug then
        log.point("writing PRG-ROM bank", cur_bank, "of", entries-1)
    else
      -- spinner.update()
      spinner.update("Flashing", cur_bank, "/", entries-1)
    end

    --select bank to write to (last bank first)
    --use the bank table to make the switch
    dict.nes("NES_CPU_WR", base + cur_bank, cur_bank)

    --write bank table to selected bank
    local i = 0
    while i < entries do
      prg_rom_flash_byte(base + i, i)
      i = i + 1;
    end

    cur_bank = cur_bank - 1
  end

  spinner.clear()
  log.success("Done writing bank table")

end

--[[
 ██████╗██╗  ██╗██████╗       ██████╗  █████╗ ███╗   ███╗
██╔════╝██║  ██║██╔══██╗      ██╔══██╗██╔══██╗████╗ ████║
██║     ███████║██████╔╝█████╗██████╔╝███████║██╔████╔██║
██║     ██╔══██║██╔══██╗╚════╝██╔══██╗██╔══██║██║╚██╔╝██║
╚██████╗██║  ██║██║  ██║      ██║  ██║██║  ██║██║ ╚═╝ ██║
 ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝      ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝
                                                         
--]]

-- dump CHR
local function chr_dump(file, rom_size_KB, debug)

  -- CHR dump
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

  dump.dumptofile(file, KB_per_read, addr_base, "NESPPU_PAGE", false)

  spinner.clear()

end

local function chr_ram_exercise(chrram_size, retroprog_id, debug)

  dict.stuff("RESET_LFSR")  -- sets it to 1

  local cur_bank = 0
  local num_banks = math.floor(chrram_size / 8)

  log.section("Exercising CHR-RAM")
  log.info("CHR-RAM size\t" .. chrram_size .. "KB")

  -- write random data to all banks
  log.point("Writing random data to CHR-RAM")
  while cur_bank < num_banks do

    if debug then
      log.point("init CHR-RAM 8K bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Writing", cur_bank, "/", num_banks-1)
    end

    -- write data
    local addr = 0x0000
    while addr < 0x2000 do
      dict.nes("PPU_PAGE_WR_LFSR", addr)
      addr = addr + 256
    end

    cur_bank = cur_bank + 1
  end

  spinner.clear()

  -- dump CHR-RAM
  local filename = "ignore/nes_chr_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))
  log.point("Dumping CHR-RAM")
  chr_dump(file, chrram_size, debug)

  -- close the file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = "ignore/lfsr_32KB.bin"

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

  -- parse additional data
  bank_table_base = options.bank_table

  -- Initialize device i/o
  dict.io("IO_RESET")
  dict.io("NES_INIT")

  -- test cart by reading manf/prod ID
  if do_test then

    log.section("Testing ".. mapname)

    if bank_table_base == nil then
      log.error("Bank table is missing from the command line arguments")
      do return end
    end

    log.info("EXP0 pull-up test", dict.io("EXP0_PULLUP_TEST"))

    local mirroring = nes.detect_mapper_mirroring(DEBUG)
    if nes.header.isValid then
      if      (nes.header.mirroringType == nes.MIRRORING_TYPE_HORIZONTAL and mirroring ~= "HORZ")
          or  (nes.header.mirroringType == nes.MIRRORING_TYPE_VERTICAL and mirroring ~= "VERT")
          -- or  (nes.header.mirroringType == nes.MIRRORING_TYPE_ONE_SCREEN and ( mirroring ~= "1SCRNA" or mirroring ~= "1SCRNB" ) )
          -- or  (nes.header.mirroringType == nes.MIRRORING_TYPE_FOUR_SCREENS and mirroring ~= "4SCRN")
      then
        log.bullet("PCB mirroring sensed:", mirroring)
        log.bullet("NES ROM mirroring:", nes.MIRRORING_TYPE_STRING[nes.header.mirroringType+1])
        log.error("PCB mirroring setting doesn't match NES ROM header")
        return false
      end
    else
      log.warning("Can't verify mirroring setting because you're using a binary file as the flash file")
    end

    if do_rom_write and prg_size ~= 0 then
      rv = prg_rom_manf_id()
      if not rv then
        log.error("Couldn't identify flash chip")
        return false
      end
    end

    -- force CHR-RAM size to 8KB
    -- since UNROM-512 doesn't exist with CHR-ROM
    chr_ram_detected = nes.ppu_ram_sense(0x1000)
    if not chr_ram_detected then
      log.error("CHR-RAM not detected")
      return
    end
    chr_ram_size = 8

    -- test CHR-RAM
    rv = chr_ram_exercise(chr_ram_size, retroprog_id, DEBUG)
    -- exit script if test fails
    if not rv then return end

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
    log.section("Dumping PRG-ROM")
    time.start()
    prg_rom_dump(file, prg_size, DEBUG)
    time.report(prg_size)
    log.success("PRG-ROM dumping done")

    -- close file
    assert(file:close())

  end

  -- erase the cart
  if do_erase then

    local i = 0

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
    rv = dict.nes("NES_CPU_RD", 0x8000)
    while rv ~= dict.nes("NES_CPU_RD", 0x8000) do
      spinner.update("Erasing")
      rv = dict.nes("NES_CPU_RD", 0x8000)
      i = i + 1
    end
    spinner.clear()
    log.success("Done erasing PRG-ROM", i .. " naks")

  end

  -- program file to the cart
  if do_rom_write then

    -- open file
    file = assert(io.open(rom_write_file.filename, "rb"))

    -- flash cart
    time.start()
    wr_bank_table(bank_table_base, prg_size / 32, DEBUG)
    prg_rom_flash(file, prg_size, DEBUG)
    time.report(prg_size)

    -- close file
    assert(file:close())

  end

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
bnrom.process = process

-- return the module's table
return bnrom
