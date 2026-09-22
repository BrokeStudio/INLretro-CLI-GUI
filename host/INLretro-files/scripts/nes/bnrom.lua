-- create the module's table
local bnrom    = {}

-- import required modules
local dict     = require "scripts.app.dict"
local nes      = require "scripts.app.nes"
local dump     = require "scripts.app.dump"
local flash    = require "scripts.app.flash"
local time     = require "scripts.app.time"
local log      = require "scripts.app.log"
local spinner  = require "scripts.app.spinner"
local files    = require "scripts.app.files"
local help     = require "scripts.app.help"

-- file constants and global variables
local mapname  = "BxROM"
local prg_flash_chip
local bank_table_base

-- registers
local PRG_BANK = 0x8000

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

  -- write_header(file, prg_kb, chr_kb, mapper, mirroring)
  nes.write_header(file, prg_kb, 0, op_buffer[mapname], mirroring)
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
local function prg_rom_flash_byte(addr, value)
  if addr < 0x8000 or addr > 0xFFFF then
    log.error("ERROR! flash write to PRG-ROM", help.hex_0x4(addr), "must be $8000-$FFFF")
    return
  end

  -- send unlock command and write byte
  nes.cpu_wr(0x5555, 0xAA, { opcode = "DISCRETE_EXP0_PRGROM_WR" })
  nes.cpu_wr(0x2AAA, 0x55, { opcode = "DISCRETE_EXP0_PRGROM_WR" })
  nes.cpu_wr(0x5555, 0xA0, { opcode = "DISCRETE_EXP0_PRGROM_WR" })
  nes.cpu_wr(addr, value, { opcode = "DISCRETE_EXP0_PRGROM_WR" })

  local rv = nes.cpu_rd(addr)

  local i = 0

  while rv ~= nes.cpu_rd(addr) do
    rv = nes.cpu_rd(addr)
    i = i + 1
  end

  if DEBUG then
    log.info("Done writing byte,", i .. " naks")
  end
end

--- Dump PRG-ROM in ascending 32 KiB bank order using the configured bank table.
-- Requires bank_table_base to reference a valid bank-selection table at the same
-- CPU address in every bank. Writes at the output file's current position.
-- @param file file* Open binary output file
-- @param rom_size_kb integer PRG-ROM size in kilobytes
-- @return boolean success True after all banks have been dumped
local function prg_rom_dump(file, rom_size_kb)
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

    -- set bank
    nes.cpu_wr(bank_table_base + cur_bank, cur_bank) -- 32KB @ CPU $8000

    dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NES_CPU_PAGE" })

    cur_bank = cur_bank + 1
  end

  spinner.clear()

  return true
end

--- Dump PRG-ROM without a known bank table, then search for a shared table.
-- Reads the initially visible bank to locate a byte equal to zero, then selects
-- each bank by writing its number to a matching byte in the currently visible
-- bank. Writes all 32 KiB banks in ascending order, excluding the initial read.
-- Searches the dumped banks for the sequence 0..num_banks-1 at a common offset
-- and sets bank_table_base to the first matching CPU address, if any.
-- A missing shared table only emits a warning; a missing bank-selection byte
-- aborts the dump and may leave a partial output file.
-- @param file file* Empty binary file opened for reading and writing, without a header
-- @param rom_size_kb integer PRG-ROM size in kilobytes
-- @return boolean success True after all banks are dumped, even if no shared table is found; false if a required bank-selection byte is absent
local function prg_rom_dump_no_bank_table(file, rom_size_kb)
  local kb_per_read = 32
  local num_banks = math.floor(rom_size_kb / kb_per_read)
  local cur_bank = 0
  local addr_base = 0x80 -- $8000
  local bank_size = kb_per_read * 1024

  local search_pos
  local found
  local rv

  log.info("PRG-ROM size", rom_size_kb .. "KB")

  -- get the current bank content
  local search_data = ""
  dump.dumptocallback(
    function(data) search_data = search_data .. data end,
    kb_per_read, { addr_base = addr_base, mem_type = "NES_CPU_PAGE" }
  )

  -- search for 0x00 in this bank
  search_pos = string.find(search_data, string.char(0x00), 1, true)
  if search_pos == nil then
    return false
  else
    search_pos = search_pos - 1
  end

  -- main loop
  while 1 do
    if DEBUG then
      log.point("dumping PRG bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    nes.cpu_wr(PRG_BANK + search_pos, cur_bank)

    -- dump bank
    dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NES_CPU_PAGE" })

    -- search for 0x0f in the dumped bank
    file:seek("set", cur_bank * bank_size)
    found = false
    cur_bank = cur_bank + 1

    -- are we done?
    if cur_bank == num_banks then
      break
    end

    -- search for a byte maching next bank to bankswitch
    for i = 0, bank_size_kb - 1, 1 do
      rv = string.unpack("B", file:read(1), 1)
      if rv == cur_bank then
        search_pos = i & 0x7fff
        found = true
        file:seek("end")
        break
      end
    end

    if not found then
      spinner.clear()
      log.error("Couldn't find next bank value (" .. cur_bank .. ") in last dumped bank")
      return false
    end
  end

  spinner.clear()

  -- now let's find bank_table accross banks
  local banks = {}

  -- construct the byte sequence that we're looking for
  local searched_sequence = ""
  while searched_sequence:len() < num_banks do
    searched_sequence = searched_sequence .. string.char(searched_sequence:len())
  end

  cur_bank = 0
  while cur_bank < num_banks do
    banks[cur_bank + 1] = {}
    file:seek("set", cur_bank * bank_size_kb)
    search_data = file:read(bank_size_kb)

    -- search for the banktable in the bank content
    local offset = 1
    while offset < bank_size_kb do
      local position_in_fixed_bank = string.find(search_data, searched_sequence, offset, true)
      if position_in_fixed_bank == nil then
        break
      else
        offset = position_in_fixed_bank + #searched_sequence
        banks[cur_bank + 1][#banks[cur_bank + 1] + 1] = position_in_fixed_bank - 1
      end
    end

    if DEBUG then
      log.point("searching in PRG bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Searching", cur_bank, "/", num_banks - 1)
    end

    cur_bank = cur_bank + 1
  end

  spinner.clear()

  -- find intersection
  local addr
  for i = 1, #banks[1], 1 do
    addr = banks[1][i]
    found = true

    for j = 2, #banks, 1 do
      found = false

      for k = 1, #banks[j], 1 do
        if banks[j][k] == addr then
          found = true
          break
        end
      end

      if not found then
        break
      end
    end

    if found then
      break
    end
  end

  if found then
    bank_table_base = addr + 0x8000
    log.info("Bank table found at address", help.hex_0x4(bank_table_base))
  else
    log.warning("Couldn't find bank table...")
  end

  return true
end

--- Program PRG-ROM contents from an already-open input file, one bank at a time.
-- @param file file* Open binary input file
-- @param rom_size_kb integer PRG-ROM size in kilobytes
local function prg_rom_flash(file, rom_size_kb)
  log.section("Programming PRG-ROM")
  log.info("PRG-ROM size", rom_size_kb .. "KB")

  local bank_size_kb = 32 -- BNROM 32KByte per PRG bank
  local cur_bank = 0
  local num_banks = math.floor(rom_size_kb / bank_size_kb)

  while cur_bank < num_banks do
    if DEBUG then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    nes.cpu_wr(bank_table_base + cur_bank, cur_bank) -- 32KB @ CPU $8000

    -- flash data
    flash.write_file(file, bank_size_kb, { mapper = "NROM", mem_type = "NES_PRG_ROM" })

    cur_bank = cur_bank + 1
  end

  spinner.clear()
  log.success("Done programming PRG-ROM")
end

--- Program a bank-selection table at the same address in every PRG-ROM bank.
-- @param addr_base integer CPU address of the bank table
-- @param entries number Number of table entries and banks, rounded down to an integer
local function write_bank_table(addr_base, entries)
  -- BNROM needs to have a bank table present in each and every bank
  -- it should also be at the same location in every bank

  log.section("Writing bank table to PRG-ROM")
  log.info("Bank table address:", help.hex_0x4(addr_base))

  local cur_bank = entries - 1 -- 16 minus 1 is 15 = 0x0F

  while cur_bank >= 0 do
    if DEBUG then
      log.point("writing PRG-ROM bank", cur_bank, "of", entries - 1)
    else
      spinner.update("Flashing", cur_bank, "/", entries - 1)
    end

    -- select bank to write to (last bank first)
    -- use the bank table to make the switch
    nes.cpu_wr(addr_base + cur_bank, cur_bank)

    -- write bank table to selected bank
    for byte = entries - 1, 0, -1 do
      if DEBUG then
        log.point("writing byte", byte, "of", entries - 1)
      end
      prg_rom_flash_byte(addr_base + byte, byte)
    end

    cur_bank = cur_bank - 1
  end

  spinner.clear()
  log.success("Done writing bank table to PRG-ROM")
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
  -- CHR dump
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

  dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NES_PPU_PAGE" })

  spinner.clear()
end

--- Exercise CHR-RAM with an LFSR pattern and compare the dumped result.
-- Overwrites CHR-RAM contents with the test pattern.
-- @param chrram_size_kb integer CHR-RAM size in kilobytes
-- @param retroprog_id string|integer Identifier used in the temporary dump filename
-- @return boolean success True when the CHR-RAM dump matches the expected LFSR data
local function chr_ram_exercise(chrram_size_kb, retroprog_id)
  dict.stuff("RESET_LFSR") -- sets it to 1

  local cur_bank = 0
  local num_banks = math.floor(chrram_size_kb / 8)

  log.section("Exercising CHR-RAM")
  log.info("CHR-RAM size\t" .. chrram_size_kb .. "KB")

  -- write random data to all banks
  log.point("Writing random data to CHR-RAM")
  while cur_bank < num_banks do
    if DEBUG then
      log.point("init CHR-RAM 8K bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Writing", cur_bank, "/", num_banks - 1)
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
        bank_table_base = nes.find_bank_table_32(rom_write_file.filename, prg_size_kb)
        if bank_table_base == nil then
          log.error("Couldn't find bank table, use 'bank_table' additional option to specify it manually")
          return false
        else
          log.success("Bank table found at address:", help.hex_0x4(bank_table_base))
        end
      else
        if not do_rom_dump then
          log.error("Bank table is missing from the command line arguments")
          return false
        end
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
      -- or  (nes.header.mirroring_type == nes.MIRRORING_TYPE_ONE_SCREEN and ( mirroring ~= "1SCRNA" or mirroring ~= "1SCRNB" ) )
      -- or  (nes.header.mirroring_type == nes.MIRRORING_TYPE_FOUR_SCREENS and mirroring ~= "4SCRN")
      then
        log.error("PCB mirroring setting doesn't match NES ROM header")
        return false
      end
    else
      log.warning("Can't verify mirroring setting because you're using a binary file as the flash file")
    end

    if do_rom_write and prg_size_kb ~= 0 then
      rv, prg_flash_chip = nes.prg_rom_get_chip({ opcode = "DISCRETE_EXP0_PRGROM_WR" })
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
    local result

    -- open file
    file = assert(io.open(rom_dump_file.filename, "w+b"))

    -- create header: pass open & empty file & rom sizes
    if rom_dump_file.ext == "nes" then
      create_header(file, prg_size_kb, chr_size_kb)
    end

    -- dump cart to file
    log.section("Dumping PRG-ROM")
    time.start()
    if bank_table_base ~= nil then
      result = prg_rom_dump(file, prg_size_kb)
    else
      result = prg_rom_dump_no_bank_table(file, prg_size_kb)
    end
    time.report(prg_size_kb)
    if result then
      log.success("PRG-ROM dumping done")
    else
      log.error("PRG-ROM dumping failed")
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
      write_bank_table(bank_table_base, math.floor(prg_size_kb / 32))
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
bnrom.process = process

-- return the module's table
return bnrom
