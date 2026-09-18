-- create the module's table
local unrom   = {}

-- import required modules
local dict    = require "scripts.app.dict"
local nes     = require "scripts.app.nes"
local dump    = require "scripts.app.dump"
local flash   = require "scripts.app.flash"
local time    = require "scripts.app.time"
local log     = require "scripts.app.log"
local spinner = require "scripts.app.spinner"
local files   = require "scripts.app.files"
local help    = require "scripts.app.help"

-- file constants and global variables
local mapname = "UxROM"
local prg_flash_chip
local bank_table_base

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
  local mirroring = nes.detect_mapper_mirroring()
  --write_header(file, prg_kb, chr_kb, mapper, mirroring)
  nes.write_header(file, prg_kb, 0, op_buffer[mapname], mirroring)
end

local function init_mapper()
  --need to select bank0 so PRG-ROM A14 is low when writing to lower bank
  --TODO this needs to be written to rom where value is 0x00 due to bus conflicts
  --so need to find the bank table first!
  --this could present an even larger problem with a blank flash chip
  --would have to get a byte written to 0x00 first before able to change the bank..
  --becomes catch 22 situation.  Will have to rely on mcu over powering PRG-ROM..
  --ahh but a way out would be to disable the PRG-ROM with exp0 (/WE) going low
  --for now the write below seems to be working fine though..
  -- dict.nes("NES_CPU_WR", 0x8000, 0x00)
  dict.nes("NES_CPU_WR", 0xC000, 0x00)
end

--[[
██████╗ ██████╗  ██████╗       ██████╗  ██████╗ ███╗   ███╗
██╔══██╗██╔══██╗██╔════╝       ██╔══██╗██╔═══██╗████╗ ████║
██████╔╝██████╔╝██║  ███╗█████╗██████╔╝██║   ██║██╔████╔██║
██╔═══╝ ██╔══██╗██║   ██║╚════╝██╔══██╗██║   ██║██║╚██╔╝██║
██║     ██║  ██║╚██████╔╝      ██║  ██║╚██████╔╝██║ ╚═╝ ██║
╚═╝     ╚═╝  ╚═╝ ╚═════╝       ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝

--]]

--- Find a bank table in the fixed PRG-ROM bank at 0xC000-0xFFFF.
-- Searches for consecutive bank numbers starting at zero, one per 16 KiB bank.
-- @param prg_size_kb number Total PRG-ROM size in KiB
-- @return integer|nil CPU address of the first matching table, or nil if not found
local function find_bank_table(prg_size_kb)
  log.section("Searching for bank table in last bank")

  local search_base = 0xC0 -- search in $C000-$FFFF, the fixed bank
  local kb_search_space = 16
  local entries = math.floor(prg_size_kb / kb_search_space)

  -- get the fixed bank's content
  local search_data = ""
  dump.dumptocallback(
    function(data) search_data = search_data .. data end,
    kb_search_space, { mapper = search_base, mem_type = "NESCPU_PAGE" }
  )

  -- construct the byte sequence that we need
  local searched_sequence = ""
  while searched_sequence:len() < entries do
    searched_sequence = searched_sequence .. string.char(searched_sequence:len())
  end

  -- search for the banktable in the fixed bank
  local position_in_fixed_bank = string.find(search_data, searched_sequence, 1, true)
  if position_in_fixed_bank == nil then
    return nil
  end

  -- compute the cpu offset of this data
  return 0xC000 + position_in_fixed_bank - 1
end

--- Program one byte to PRG-ROM flash and poll for completion.
-- @param addr integer Address to program, 0x8000-0xFFFF
-- @param value integer 8-bit value to write
-- @param bank integer Mapper bank value selecting the target flash bank
local function prg_rom_flash_byte(addr, value, bank)
  if addr < 0x8000 or addr > 0xFFFF then
    log.error("ERROR! flash write to PRG-ROM", help.hex_0x4(addr), "must be $8000-FFFF")
    return
  end

  dict.nes("NES_CPU_WR", bank_table_base, 0x00)
  dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x5555, 0xAA)
  dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x2AAA, 0x55)
  dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x5555, 0xA0)
  dict.nes("NES_CPU_WR", bank_table_base + bank, bank)
  dict.nes("DISCRETE_EXP0_PRGROM_WR", addr, value)

  local rv = dict.nes("NES_CPU_RD", addr)

  local i = 0

  while rv ~= dict.nes("NES_CPU_RD", addr) do
    rv = dict.nes("NES_CPU_RD", addr)
    i = i + 1
  end

  if DEBUG then
    log.info("Done writing byte,", i .. " naks")
  end
end

--- Dump PRG-ROM contents to an already-open output file.
-- @param file file* Open binary output file
-- @param rom_size_kb integer PRG-ROM size in kilobytes
local function prg_rom_dump(file, rom_size_kb)
  local kb_per_read = 16
  local num_banks = math.floor(rom_size_kb / kb_per_read)
  local cur_bank = 0
  local addr_base = 0x80       -- $8000
  local fixed_bank_base = 0xC0 -- search in $C000-$F000, the fixed bank

  log.info("PRG-ROM size", rom_size_kb .. "KB")

  -- dump all banks except last/fixed bank
  while cur_bank < num_banks - 1 do
    if DEBUG then
      log.point("dumping PRG bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    dict.nes("NES_CPU_WR", bank_table_base + cur_bank, cur_bank) --16KB @ CPU $8000

    dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NESCPU_PAGE" })

    cur_bank = cur_bank + 1
  end

  -- Write fixed bank
  if DEBUG then
    log.point("dumping PRG bank", cur_bank, "of", num_banks - 1)
  else
    spinner.update("Dumping", cur_bank, "/", num_banks - 1)
  end
  dump.dumptofile(file, kb_per_read, { mapper = fixed_bank_base, mem_type = "NESCPU_PAGE" })

  spinner.clear()
end

--- Program PRG-ROM contents from an already-open input file, one bank at a time.
-- @param file file* Open binary input file
-- @param rom_size_kb integer PRG-ROM size in kilobytes
local function prg_rom_flash(file, rom_size_kb)
  init_mapper()

  log.section("Programming PRG-ROM")
  log.info("PRG-ROM size", rom_size_kb .. "KB")

  --bank table should already be written

  local bank_size_kb = 16 --UNROM 16KByte per PRG bank
  local cur_bank = 0
  local num_banks = math.floor(rom_size_kb / bank_size_kb)

  local byte_num --byte number gets reset for each bank
  local byte_str, data, readdata

  -- set the bank table address
  dict.nes("SET_BANK_TABLE", bank_table_base)
  -- if DEBUG then print("get banktable:", string.format("%X", dict.nes("GET_BANK_TABLE"))) end

  while cur_bank < num_banks do
    if DEBUG then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    --select bank to flash
    dict.nes("SET_CUR_BANK", cur_bank)
    --if DEBUG then print("get bank:", dict.nes("GET_CUR_BANK")) end

    -- flash data
    flash.write_file(file, bank_size_kb, { mapper = mapname, mem_type = "PRGROM" })

    cur_bank = cur_bank + 1
  end

  spinner.clear()
  log.success("Done programming PRG-ROM")
end

--- Program a bank-selection table using PRG-ROM bank 0.
-- @param addr_base integer CPU address of the bank table
-- @param entries integer Number of bank table entries to write
local function write_bank_table(addr_base, entries)
  --UxROM can have a single bank table in $C000-FFFF (assuming this is most likely)
  --or a bank table in all other banks in $8000-BFFF (unsupported for now)

  init_mapper()

  log.section("Writing bank table to PRG-ROM")
  log.info("Bank table address:", help.hex_0x4(addr_base))

  for byte = 0, entries, 1 do
    if DEBUG then
      log.point("writing byte", byte, "of", entries - 1)
    else
      spinner.update("Writing byte", byte, "/", entries - 1)
    end
    prg_rom_flash_byte(addr_base + byte, byte, 0)
    byte = byte + 1;
  end

  spinner.clear()
  log.success("Done writing bank table to PRG-ROM")

  --[[
  if base >= 0xC000 then
    --only need one bank table in last bank
    cur_bank = entries - 1  --16 minus 1 is 15 = 0x0F
  else
    --need bank table in all banks except last
    cur_bank = entries - 2  --16 minus 2 is 14 = 0x0E
  end


  while cur_bank >= 0 do
    --select bank to write to (last bank first)
    --use the bank table to make the switch
    dict.nes("NES_CPU_WR", base+cur_bank, cur_bank)

    --write bank table to selected bank
    local i = 0
    while i < entries do
      print("write entry", i, "bank:", cur_bank)
      prg_rom_flash_byte(base+i, i)
      i = i+1;
    end

    cur_bank = cur_bank-1

    if base >= 0xC000 then
      --only need one bank table in last bank
      break
    end
  end
  --]]

  --TODO verify the bank table was successfully written before continuing!
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
  local kb_per_read = 8
  local num_banks = math.floor(rom_size_kb / kb_per_read)
  local cur_bank = 0
  local addr_base = 0x00 -- $0000

  log.info("CHR size", rom_size_kb .. "KB")

  if DEBUG then
    log.point("dump CHR bank", cur_bank, "of", num_banks - 1)
  else
    spinner.update("Dumping", cur_bank, "/", num_banks - 1)
  end

  dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NESPPU_PAGE" })

  spinner.clear()
end

--- Exercise CHR-RAM with an LFSR pattern and compare the dumped result.
-- Overwrites CHR-RAM contents with the test pattern.
-- @param chrram_size_kb integer CHR-RAM size in kilobytes
-- @param retroprog_id string|integer Identifier used in the temporary dump filename
-- @return boolean success True when the CHR-RAM dump matches the expected LFSR data
local function chr_ram_exercise(chrram_size_kb, retroprog_id)
  dict.stuff("RESET_LFSR") -- sets it to 1
  -- dict.stuff("SET_LFSR_L", 0) --lock it up to clear ram
  -- dict.stuff("SET_LFSR_L", 2) --give different seed for testing fails

  local cur_bank = 0
  local num_banks = math.floor(chrram_size_kb / 8)

  log.section("Exercising CHR-RAM")
  log.info("CHR-RAM size\t" .. chrram_size_kb .. "KB")

  -- write random data to all banks
  log.point("Writing random data to CHR-RAM")
  if DEBUG then log.point("init CHR-RAM 8K bank\t" .. cur_bank .. "\tof\t" .. num_banks - 1) end
  local addr = 0x0000
  while addr < 0x2000 do
    dict.nes("PPU_PAGE_WR_LFSR", addr)
    addr = addr + 256
  end

  -- dump CHR-RAM
  local filename = opts.write_path .. "./ignore/nes_chr_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))
  log.point("Dumping CHR-RAM")
  chr_dump(file, chrram_size_kb)

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

  -- parse additional data
  bank_table_base        = options.bank_table

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
    log.section("Testing " .. mapname)

    if bank_table_base == nil then
      if do_rom_write then
        log.info("Bank table is missing from the command line arguments, trying to automatically find it")
        bank_table_base = nes.find_bank_table_in_last_bank(rom_write_file.filename, prg_size_kb, 16)
        if bank_table_base == nil then
          log.error("Couldn't find bank table, use 'bank_table' additional option to specify it manually")
          return false
        else
          log.success("Bank table found at address:", help.hex_0x4(bank_table_base))
        end
      elseif do_rom_dump then
        bank_table_base = find_bank_table(prg_size_kb)
        if bank_table_base == nil then
          log.error("Couldn't find bank table, use 'bank_table' additional option to specify it manually")
          return false
        else
          log.success("Bank table found at address:", help.hex_0x4(bank_table_base))
        end
      else
        log.error("Bank table is missing from the command line arguments")
        return false
      end
    else
      log.info("Bank table address provided:", help.hex_0x4(bank_table_base))
    end

    log.info("EXP0 pull-up test", dict.io("EXP0_PULLUP_TEST"))

    local mirroring = nes.detect_mapper_mirroring()
    log.bullet("PCB mirroring sensed:", mirroring)
    if nes.header.is_valid then
      log.bullet("NES ROM mirroring:", nes.MIRRORING_TYPE_STRING[nes.header.mirroring_type + 1])
      if (nes.header.mirroring_type == nes.MIRRORING_TYPE_HORIZONTAL and mirroring ~= "HORZ")
          or (nes.header.mirroring_type == nes.MIRRORING_TYPE_VERTICAL and mirroring ~= "VERT")
      -- or (nes.header.mirroring_type == nes.MIRRORING_TYPE_VERTICAL and (mirroring ~= "1SCRNA" or mirroring ~= "1SCRNB"))
      -- or  (nes.header.mirroring_type == nes.MIRRORING_TYPE_FOUR_SCREENS and mirroring ~= "4SCRN")
      then
        log.error("PCB mirroring setting doesn't match NES ROM header")
        return false
      end
    else
      log.warning("Can't verify mirroring setting because you're using a binary file as the flash file")
    end

    if do_rom_write and prg_size_kb ~= 0 then
      -- ROMSEL controls PRG-ROM /OE which needs to be low for flash writes
      -- So unlock commands need to be addressed below $8000
      -- DISCRETE_EXP0_PRGROM_WR doesn't toggle /ROMSEL by definition though, so A15 is unused
      --        15 14 13 12
      --  0x5 = 0b  0  1  0  1  -> $5555
      --  0x2 = 0b  0  0  1  0  -> $2AAA
      rv, prg_flash_chip = nes.prg_rom_get_chip({ opcode = "DISCRETE_EXP0_PRGROM_WR" })
      if not rv then
        log.error("Couldn't identify flash chip")
        return false
      end
    end

    -- force CHR-RAM size to 8KB
    -- since UxROM doesn't exist with CHR-ROM
    chr_ram_detected = nes.ppu_ram_sense(0x1000)
    if not chr_ram_detected then
      log.error("CHR-RAM not detected")
      return
    end
    chr_ram_size_kb = 8

    -- test CHR-RAM
    rv = chr_ram_exercise(chr_ram_size_kb, retroprog_id)
    -- exit script if test fails
    if not rv then return end
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

    -- create header
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
    -- erase PRG-ROM only if needed
    if prg_size_kb ~= 0 then
      init_mapper()
      rv = nes.prg_rom_erase(prg_flash_chip, { opcode = "DISCRETE_EXP0_PRGROM_WR" })
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
    if prg_size_kb ~= 0 then
      -- open file
      file = assert(io.open(rom_write_file.filename, "rb"))

      -- flash PRG-ROM
      time.start()
      write_bank_table(bank_table_base, math.floor(prg_size_kb / 16))
      prg_rom_flash(file, prg_size_kb)
      time.report(prg_size_kb)

      -- close file
      assert(file:close())
    end
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
unrom.process = process

-- return the module's table
return unrom
