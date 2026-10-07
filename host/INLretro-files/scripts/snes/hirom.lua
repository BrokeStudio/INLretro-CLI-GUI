-- create the module's table
local hirom   = {}

-- import required modules
local dict    = require "scripts.app.dict"
local snes    = require "scripts.app.snes"
local dump    = require "scripts.app.dump"
local flash   = require "scripts.app.flash"
local chips   = require "scripts.app.chips"
local time    = require "scripts.app.time"
local log     = require "scripts.app.log"
local spinner = require "scripts.app.spinner"
local files   = require "scripts.app.files"
local help    = require "scripts.app.help"

-- file constants and global variables
local mapname = "HIROM"
local rom_flash_chip

-- local functions

--[[
██╗  ██╗███████╗██╗     ██████╗ ███████╗██████╗ ███████╗
██║  ██║██╔════╝██║     ██╔══██╗██╔════╝██╔══██╗██╔════╝
███████║█████╗  ██║     ██████╔╝█████╗  ██████╔╝███████╗
██╔══██║██╔══╝  ██║     ██╔═══╝ ██╔══╝  ██╔══██╗╚════██║
██║  ██║███████╗███████╗██║     ███████╗██║  ██║███████║
╚═╝  ╚═╝╚══════╝╚══════╝╚═╝     ╚══════╝╚═╝  ╚═╝╚══════╝

--]]

-- local functions

--[[
██████╗  ██████╗ ███╗   ███╗
██╔══██╗██╔═══██╗████╗ ████║
██████╔╝██║   ██║██╔████╔██║
██╔══██╗██║   ██║██║╚██╔╝██║
██║  ██║╚██████╔╝██║ ╚═╝ ██║
╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝

--]]

--- Program one byte to ROM flash and poll for completion.
-- @param addr integer Address to program
-- @param value integer 8-bit value to write
local function rom_flash_byte(addr, value)
  if (addr < 0x0000 or addr > 0xFFFF) then
    print("\n  ERROR! flash write to SNES", string.format("$%X", addr), "must be $0000-FFFF \n\n")
    return false
  end

  --send unlock command and write byte
  snes.rom_wr(0x0AAA, 0xAA)
  snes.rom_wr(0x0555, 0x55)
  snes.rom_wr(0x0AAA, 0xA0)
  snes.rom_wr(addr, value)

  local rv = snes.rom_rd(addr)

  local i = 0

  while (rv ~= value) do
    rv = snes.rom_rd(addr)
    i = i + 1
  end
  if DEBUG then print(i, "naks, done writing byte.") end
  if DEBUG then print("written value:", string.format("%X", value), "verified value:", string.format("%X", rv)) end

  --TODO handle timeout for problems

  --TODO return pass/fail/info
  return true
end

--- Dump ROM contents to an already-open output file.
-- @param file file* Open binary output file
-- @param rom_size_kb integer ROM size in kilobytes
local function rom_dump(file, rom_size_kb)
  -- /ROMSEL is always low for this dump

  local kb_per_bank = 64 -- HIROM has 64KB per bank
  local num_banks = rom_size_kb // kb_per_bank
  local cur_bank = 0

  -- HIROM data starts at $0000
  -- If addressing ExHiRom:
  -- File offset:   $000000–3FFFFF
  -- SNES address:  $C0:0000 to $FF:FFFF
  -- File offset:   $400000–7FFFFF
  -- SNES address:  $40:0000 to $7F:FFFF
  local EMPTY_32KB = string.rep(string.char(0xFF), 32 * 1024)

  log.info("ROM size", rom_size_kb .. "KB")

  while cur_bank < num_banks do
    local bank
    if cur_bank < 0x40 then
      bank = 0xC0 + cur_bank
    elseif cur_bank < 0x7E then
      bank = 0x40 + (cur_bank - 0x40)
    else
      bank = 0x3E + (cur_bank - 0x7E)
    end

    if DEBUG then
      log.point("dumping bank", cur_bank, "of", num_banks - 1, "(" .. bank .. ")")
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- select desired bank
    dict.snes("SNES_SET_BANK", bank)

    if cur_bank < 0x7E then
      dump.dumptofile(file, kb_per_bank,
        {
          mapper = mapname,
          mem_type = "SNES_ROM"
        })
    elseif cur_bank == 0x7E then
      -- pad file with dummy data
      file:write(EMPTY_32KB)

      -- dump $3E:8000-$FFFF
      dump.dumptofile(file, 32,
        {
          mapper = mapname,
          mem_type = "SNES_ROM",
          first_page = 0x80
        })
    elseif cur_bank == 0x7F then
      -- pad file with dummy data
      file:write(EMPTY_32KB)

      -- dump $3F:8000-$FFFF
      dump.dumptofile(file, 32,
        {
          mapper = mapname,
          mem_type = "SNES_ROM",
          first_page = 0x80
        })
    end

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--- Program ROM contents from an already-open input file, one bank at a time.
-- @param file file* Open binary input file
-- @param rom_size_kb integer ROM size in kilobytes
local function rom_flash(file, rom_size_kb)
  log.section("Programming ROM")
  log.info("ROM size", rom_size_kb .. "KB")

  local kb_per_bank = 64 -- HIROM has 64KB per bank
  local num_banks = rom_size_kb // kb_per_bank
  local cur_bank = 0

  -- HIROM data starts at $0000
  -- If addressing ExHiRom:
  -- File offset:   $000000–3FFFFF
  -- SNES address:  $C0:0000 to $FF:FFFF
  -- File offset:   $400000–7FFFFF
  -- SNES address:  $40:0000 to $7F:FFFF

  local options
  if rom_flash_chip.buffer == true then
    options = "USE_BUFFER"
    log.info("Using buffer programming")
  elseif rom_flash_chip.unlock_bypass == true then
    options = "USE_UNLOCK_BYPASS"
    log.info("Using unlock bypass mode")
  end

  while cur_bank < num_banks do
    local bank
    if cur_bank < 0x40 then
      bank = 0xC0 + cur_bank
    elseif cur_bank < 0x7E then
      bank = 0x40 + (cur_bank - 0x40)
    else
      bank = 0x3E + (cur_bank - 0x7E)
    end

    if DEBUG then
      log.point("writing bank", cur_bank, "of", num_banks - 1, "(" .. bank .. ")")
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- select desired bank
    dict.snes("SNES_SET_BANK", bank)

    if cur_bank < 0x7E then
      flash.write_file(file, kb_per_bank, { mapper = mapname, mem_type = "SNES_ROM", options = options })
    elseif cur_bank == 0x7E then
      -- Skip inaccessible $7E0000-$7E7FFF
      file:seek("cur", 0x8000)

      dict.snes("SNES_SET_BANK", 0x3E)
      flash.write_file(file, 32,
        {
          mapper = mapname,
          mem_type = "SNES_ROM",
          options = options,
          first_page = 0x80
        })
    elseif cur_bank == 0x7F then
      -- Skip inaccessible $7F0000-$7F7FFF
      file:seek("cur", 0x8000)

      dict.snes("SNES_SET_BANK", 0x3F)
      flash.write_file(file, 32,
        {
          mapper = mapname,
          mem_type = "SNES_ROM",
          options = options,
          first_page = 0x80
        })
    end

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--[[
██████╗  █████╗ ███╗   ███╗
██╔══██╗██╔══██╗████╗ ████║
██████╔╝███████║██╔████╔██║
██╔══██╗██╔══██║██║╚██╔╝██║
██║  ██║██║  ██║██║ ╚═╝ ██║
╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝

--]]

--- Dump HiROM cartridge RAM from successive 8 KiB banks.
-- Restores ROM bank 0x00 after the transfer.
-- @param file file* Open binary output file
-- @param ram_size_kb integer Number of kilobytes to dump
local function ram_dump(file, ram_size_kb)
  local BANK_SIZE_KB = 8
  local FIRST_BANK = 0x20

  local remaining_kb = ram_size_kb
  local cur_bank = 0

  log.info("RAM size", ram_size_kb .. "KB")

  while remaining_kb > 0 do
    local chunk_size_kb = math.min(remaining_kb, BANK_SIZE_KB)

    if DEBUG then
      log.point("dumping RAM bank", cur_bank)
    else
      spinner.update("Dumping", ram_size_kb - remaining_kb, "/", ram_size_kb)
    end

    dict.snes("SNES_SET_BANK", FIRST_BANK + cur_bank)

    dump.dumptofile(file, chunk_size_kb, { mapper = mapname, mem_type = "SNES_RAM" })

    remaining_kb = remaining_kb - chunk_size_kb
    cur_bank = cur_bank + 1
  end

  -- select desired bank (access ROM)
  dict.snes("SNES_SET_BANK", 0x00)

  spinner.clear()
end

--- Write HiROM cartridge RAM to successive 8 KiB banks.
-- Restores ROM bank 0x00 after the transfer.
-- @param file file* Open binary input file
-- @param ram_size_kb integer Number of kilobytes to write
local function ram_write(file, ram_size_kb)
  local BANK_SIZE_KB = 8
  local FIRST_BANK = 0x20

  local remaining_kb = ram_size_kb
  local cur_bank = 0

  log.info("RAM size", ram_size_kb .. "KB")

  while remaining_kb > 0 do
    local chunk_size_kb = math.min(remaining_kb, BANK_SIZE_KB)

    if DEBUG then
      log.point("writing RAM bank", cur_bank)
    else
      spinner.update("Writing", ram_size_kb - remaining_kb, "/", ram_size_kb)
    end

    dict.snes("SNES_SET_BANK", FIRST_BANK + cur_bank)

    flash.write_file(file, chunk_size_kb, { mapper = mapname, mem_type = "SNES_RAM" })

    remaining_kb = remaining_kb - chunk_size_kb
    cur_bank = cur_bank + 1
  end

  -- select desired bank (access ROM)
  dict.snes("SNES_SET_BANK", 0x00)

  log.success("Done programming RAM")
end

--- Detect HiROM cartridge RAM without changing the stored byte.
-- @return boolean detected True when an inverted test byte can be read back
local function ram_detect()
  local saved_value
  local test_value
  local read_value

  local options = { romsel = snes.ROMSEL_HI }

  log.section("Detecting RAM")

  -- select desired bank (access RAM)
  dict.snes("SNES_SET_BANK", 0x20)

  -- save potential battery backed data first
  saved_value = snes.ram_rd(0x6000, options)
  test_value = (saved_value ~ 0xFF) & 0xFF

  -- try to write and read back
  snes.ram_wr(0x6000, test_value, options)
  read_value = snes.ram_rd(0x6000, options)

  -- put back original value
  snes.ram_wr(0x6000, saved_value, options)

  -- select desired bank (access ROM)
  dict.snes("SNES_SET_BANK", 0x00)

  return read_value == test_value
end

--- Detect mirrored HiROM RAM size while preserving the probed bytes.
-- @return integer size_kb Detected RAM size in kilobytes, or 0 on failure
local function ram_get_size()
  local BLOCK_SIZE = 0x400
  local BANK_SIZE = 0x2000
  local FIRST_BANK = 0x20
  local FIRST_ADDR = 0x6000
  local LAST_OFFSET = 0x7C00

  local options = { romsel = snes.ROMSEL_HI }
  local saved_values = {}
  local selected_bank
  local offset
  local bank
  local addr

  log.section("Detecting RAM size")

  -- back up every location touched by the mirror test
  offset = 0
  while offset <= LAST_OFFSET do
    bank = FIRST_BANK + (offset // BANK_SIZE)
    addr = FIRST_ADDR + (offset % BANK_SIZE)

    if bank ~= selected_bank then
      dict.snes("SNES_SET_BANK", bank)
      selected_bank = bank
    end

    saved_values[offset] = snes.ram_rd(addr, options)
    offset = offset + BLOCK_SIZE
  end

  -- write from high to low so the last surviving marker is the RAM size in KiB
  offset = LAST_OFFSET
  while offset >= 0 do
    bank = FIRST_BANK + (offset // BANK_SIZE)
    addr = FIRST_ADDR + (offset % BANK_SIZE)

    if bank ~= selected_bank then
      dict.snes("SNES_SET_BANK", bank)
      selected_bank = bank
    end

    local marker = (offset // BLOCK_SIZE) + 1
    snes.ram_wr(addr, marker, options)
    offset = offset - BLOCK_SIZE
  end

  bank = FIRST_BANK + (LAST_OFFSET // BANK_SIZE)
  addr = FIRST_ADDR + (LAST_OFFSET % BANK_SIZE)

  if bank ~= selected_bank then
    dict.snes("SNES_SET_BANK", bank)
    selected_bank = bank
  end

  local ram_size_kb = snes.ram_rd(addr, options)

  -- restore saved data data
  offset = 0
  while offset <= LAST_OFFSET do
    bank = FIRST_BANK + (offset // BANK_SIZE)
    addr = FIRST_ADDR + (offset % BANK_SIZE)

    if bank ~= selected_bank then
      dict.snes("SNES_SET_BANK", bank)
      selected_bank = bank
    end

    snes.ram_wr(addr, saved_values[offset], options)
    offset = offset + BLOCK_SIZE
  end

  -- Select a ROM bank again
  dict.snes("SNES_SET_BANK", 0x00)

  if ram_size_kb ~= 1 and
      ram_size_kb ~= 2 and
      ram_size_kb ~= 4 and
      ram_size_kb ~= 8 and
      ram_size_kb ~= 16 and
      ram_size_kb ~= 32 then
    log.warning("Failed to detect RAM size")
    return 0
  else
    log.success("RAM size detected", ram_size_kb .. "KB")
    return ram_size_kb
  end
end

--- Overwrite HiROM RAM with an LFSR pattern and verify the resulting dump.
-- @param ram_size_kb integer RAM size in kilobytes
-- @param retroprog_id string|integer Identifier used in the temporary dump filename
-- @return boolean success True when the dump matches the reference LFSR stream
local function ram_test(ram_size_kb, retroprog_id)
  local BANK_SIZE_KB = 8
  local FIRST_BANK = 0x20
  local FIRST_ADDR = 0x6000

  local remaining_kb = ram_size_kb
  local cur_bank = 0

  dict.stuff("RESET_LFSR") -- sets it to 1

  log.section("Exercising RAM")
  log.info("RAM size", ram_size_kb .. "KB")

  -- write random data to all banks
  log.point("Writing random data to RAM")

  while remaining_kb > 0 do
    local chunk_size_kb = math.min(remaining_kb, BANK_SIZE_KB)
    local addr = FIRST_ADDR
    local end_addr = FIRST_ADDR + chunk_size_kb * 1024

    dict.snes("SNES_SET_BANK", FIRST_BANK + cur_bank)

    while addr < end_addr do
      dict.snes("SNES_PAGE_WR_LFSR", addr, snes.ROMSEL_HI)
      addr = addr + 256
    end

    remaining_kb = remaining_kb - chunk_size_kb
    cur_bank = cur_bank + 1
  end

  -- select desired bank (access ROM)
  dict.snes("SNES_SET_BANK", 0x00)

  -- open file
  local filename = opts.write_path .. "./ignore/snes_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))

  -- dump RAM
  log.point("Dumping RAM")
  ram_dump(file, ram_size_kb)

  -- close file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "./ignore/lfsr_32KB.bin"

  -- compare the flash file vs post dump file
  if files.compare(filename, goodfile, false) then
    log.success("RAM test passed")
    return true
  else
    log.error("RAM test failed")
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
  local rv              = nil
  local file

  -- process options
  local retroprog_id    = process_opts.retroprog_id
  local do_rom_erase    = process_opts.do_rom_erase
  local do_rom_write    = process_opts.do_rom_write
  local do_rom_verify   = process_opts.do_rom_verify
  local do_rom_dump     = process_opts.do_rom_dump
  local do_ram_dump     = process_opts.do_ram_dump
  local do_ram_write    = process_opts.do_ram_write
  local do_ram_verify   = process_opts.do_ram_verify
  local rom_write_file  = process_opts.rom_write_file
  local rom_verify_file = process_opts.rom_verify_file
  local rom_dump_file   = process_opts.rom_dump_file
  local ram_dump_file   = process_opts.ram_dump_file
  local ram_write_file  = process_opts.ram_write_file
  local ram_verify_file = process_opts.ram_verify_file
  local options         = process_opts.additional_opts

  -- console options
  local rom_size_kb     = console_opts.rom_size_kb
  local ram_size_kb     = console_opts.ram_size_kb

  -- initialize device i/o
  dict.io("IO_RESET")
  dict.io("SNES_INIT")

  --[[
  888888 888888 .dP"Y8 888888
    88   88__   `Ybo."   88
    88   88""   o.`Y8b   88
    88   888888 8bodP'   88
  --]]

  -- test cart
  log.section("Testing", mapname)

  -- attempt to read ROM flash ID
  if options.force_flash_test or (do_rom_write and rom_size_kb ~= 0) then
    rv, rom_flash_chip = snes.rom_get_chip({ bank = 0x40, addr_base = 0x8000 })
    if not rv then
      if do_rom_write then
        log.error("Couldn't identify flash chip")
        return false
      else
        log.warning("Couldn't identify flash chip")
      end
    end
  end

  -- RAM tests
  if options.force_ram_test then
    log.print()
    log.warning("Additional option 'force_ram_test' enabled")
  end

  rv = ram_detect()

  if rv == false then -- RAM not found
    if do_ram_dump or do_ram_write then
      log.error("RAM not detected")
      return false
    elseif do_rom_write then
      if options.force_ram_test then
        log.warning("Additional option 'force_ram_test' implies RAM presence")
        log.error("RAM not detected")
        return false
      elseif snes.file_header.is_valid and snes.file_header:has_sram() then
        log.warning("ROM header settings implies RAM")
        log.error("RAM not detected")
        return false
      elseif ram_size_kb ~= 0 then
        log.warning("CLI options specify " .. ram_size_kb .. "KB of RAM")
        log.error("RAM not detected")
        return false
      else
        log.info("RAM not detected")
      end
    end
  else -- PRG RAM found
    log.success("RAM detected")

    if ram_size_kb == 0 then
      ram_size_kb = ram_get_size()
    end

    if options.force_ram_test and (do_rom_dump or do_ram_dump) then
      log.warning("Additional option 'force_ram_test' is ignored when dumping ROM or RAM")
    elseif do_rom_write or do_ram_write then
      if options.force_ram_test then
        rv = ram_test(ram_size_kb, retroprog_id)
        if not rv then return false end
      elseif snes.file_header.is_valid and snes.file_header:has_sram() then
        if snes.file_header:has_battery() then
          log.warning("Can't test RAM because ROM header specifies battery backed data")
          log.warning("Use additional option 'force_ram_test' to force RAM test")
        else
          rv = ram_test(ram_size_kb, retroprog_id)
          if not rv then return false end
        end
      else
        log.warning("Can't test RAM because data could be battery backed")
        log.warning("Use additional option 'force_ram_test' to force RAM test")
      end
    end
  end


  --[[
  88""Yb    db    8b    d8     8888b.  88   88 8b    d8 88""Yb
  88__dP   dPYb   88b  d88      8I  Yb 88   88 88b  d88 88__dP
  88"Yb   dP__Yb  88YbdP88      8I  dY Y8   8P 88YbdP88 88"""
  88  Yb dP""""Yb 88 YY 88     8888Y"  `YbodP' 88 YY 88 88
  --]]

  if do_ram_dump then
    local cartridge_title = ""
    if snes.cart_header.is_valid then
      cartridge_title = snes.cart_header.cartridge_title
    end
    log.section("Dumping RAM", cartridge_title)

    -- check ram size
    if ram_size_kb == 0 then
      log.error("RAM size not provided")
      return false
    end

    -- open file
    file = assert(io.open(ram_dump_file.filename, "wb"))

    time.start()
    ram_dump(file, ram_size_kb)
    time.report(ram_size_kb)
    log.success("Done dumping ROM")

    -- close file
    assert(file:close())
  end

  --[[
  88""Yb    db    8b    d8     Yb        dP 88""Yb 88 888888 888888
  88__dP   dPYb   88b  d88      Yb  db  dP  88__dP 88   88   88__
  88"Yb   dP__Yb  88YbdP88       YbdPYbdP   88"Yb  88   88   88""
  88  Yb dP""""Yb 88 YY 88        YP  YP    88  Yb 88   88   888888
  --]]

  -- program file to the cart
  if do_ram_write then
    log.section("Programming RAM")

    -- check ram size
    if ram_size_kb == 0 then
      log.error("RAM size not provided")
      return false
    end

    -- open file
    file = assert(io.open(ram_write_file.filename, "rb"))

    -- flash cart
    time.start()
    ram_write(file, ram_size_kb)
    time.report(ram_size_kb)

    -- close file
    assert(file:close())

    if do_ram_verify then
      -- open file
      file = assert(io.open(ram_verify_file.filename, "wb"))

      -- dump cart to file
      log.section("Dumping RAM")
      time.start()
      ram_dump(file, ram_size_kb)
      time.report(ram_size_kb)
      log.success("RAM dumping done")

      -- close file
      assert(file:close())

      -- compare the flash file vs post dump file
      log.section("Verifying data")
      if files.compare(ram_verify_file.filename, ram_write_file.filename, true) then
        log.success("Flash successfully verified")
      else
        log.error("Flash verification did not match")
      end
    end
  end

  --[[
  88""Yb  dP"Yb  8b    d8     8888b.  88   88 8b    d8 88""Yb
  88__dP dP   Yb 88b  d88      8I  Yb 88   88 88b  d88 88__dP
  88"Yb  Yb   dP 88YbdP88      8I  dY Y8   8P 88YbdP88 88"""
  88  Yb  YbodP  88 YY 88     8888Y"  `YbodP' 88 YY 88 88
  --]]

  if do_rom_dump then
    local cartridge_title = ""
    if snes.cart_header.is_valid then
      cartridge_title = snes.cart_header.cartridge_title
    end
    log.section("Dumping ROM", cartridge_title)

    -- check rom size
    if rom_size_kb == 0 then
      log.error("ROM size not provided")
      return false
    end

    -- open file
    file = assert(io.open(rom_dump_file.filename, "wb"))

    -- dump data
    time.start()
    rom_dump(file, rom_size_kb)
    time.report(rom_size_kb)
    log.success("Done dumping ROM")

    -- close file
    assert(file:close())

    -- TODO
    -- -- parse ROM dump file header
    -- log.point("Parsing dumped file header")
    -- file = assert(io.open(rom_dump_file.filename, "rb"))
    -- if not snes.parse_header_file(file) then
    --   log.warning("Failed to parse ROM dump file header")
    -- else
    --   log.success("ROM dump file header parsed successfully")
    -- end
    -- assert(file:close())
  end

  --[[
  88""Yb  dP"Yb  8b    d8     Yb        dP 88""Yb 88 888888 888888
  88__dP dP   Yb 88b  d88      Yb  db  dP  88__dP 88   88   88__
  88"Yb  Yb   dP 88YbdP88       YbdPYbdP   88"Yb  88   88   88""
  88  Yb  YbodP  88 YY 88        YP  YP    88  Yb 88   88   888888
  --]]

  if do_rom_write then
    -- open file
    file = assert(io.open(rom_write_file.filename, "rb"))

    -- erase rom
    snes.rom_erase(rom_flash_chip, { bank = 0x40, addr_base = 0x8000 })

    -- flash cart
    time.start()
    rom_flash(file, rom_size_kb)
    time.report(rom_size_kb)

    -- close file
    assert(file:close())

    if do_rom_verify then
      -- open file
      file = assert(io.open(rom_verify_file.filename, "wb"))

      -- dump cart to file
      log.section("Dumping ROM")
      time.start()
      rom_dump(file, rom_size_kb)
      time.report(rom_size_kb)
      log.success("Done dumping ROM")

      -- close file
      assert(file:close())

      -- compare the flash file vs post dump file
      log.section("Verifying data")
      if files.compare(rom_verify_file.filename, rom_write_file.filename, true) then
        log.success("Flash successfully verified")
      else
        log.error("Flash verification did not match")
      end
    end
  end

  return true
end

-- global variables so other modules can use them

-- call functions desired to run when script is called/imported

-- functions other modules are able to call
hirom.process = process
hirom.ram_dump = ram_dump
hirom.ram_write = ram_write
hirom.ram_detect = ram_detect
hirom.ram_test = ram_test

-- return the module's table
return hirom
