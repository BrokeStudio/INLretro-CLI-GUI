-- create the module's table
local lorom   = {}

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
local mapname = "LOROM"
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
  snes.rom_wr(0x8AAA, 0xAA)
  snes.rom_wr(0x8555, 0x55)
  snes.rom_wr(0x8AAA, 0xA0)
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

  local kb_per_bank = 32 -- LOROM has 32KB per bank
  local num_banks = rom_size_kb // kb_per_bank
  local cur_bank = 0

  -- LOROM data starts at $8000
  -- If addressing ExLoRom:
  -- File offset:   $000000–3FFFFF
  -- SNES address:  $80:8000 to $FF:FFFF
  -- File offset:   $400000–7FFFFF
  -- SNES address:  $00:8000 to $7F:FFFF
  local EMPTY_32KB = string.rep(string.char(0xFF), 32 * 1024)

  log.info("ROM size", rom_size_kb .. "KB")

  while cur_bank < num_banks do
    local bank
    if cur_bank < 0x80 then
      bank = 0x80 + cur_bank
    else
      bank = cur_bank - 0x80
    end

    if DEBUG then
      log.point("dumping bank", cur_bank, "of", num_banks - 1, "(" .. bank .. ")")
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- select desired bank
    dict.snes("SNES_SET_BANK", bank)

    if cur_bank < 0xFE then
      dump.dumptofile(file, kb_per_bank,
        {
          mapper = mapname,
          mem_type = "SNES_ROM",
          first_page = 0x80
        })
    else
      -- pad file with dummy data
      file:write(EMPTY_32KB)
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

  local kb_per_bank = 32 -- LOROM has 32KB per bank
  local num_banks = rom_size_kb // kb_per_bank
  local cur_bank = 0

  -- LOROM data starts at $8000
  -- If addressing ExLoRom:
  -- File offset:   $000000–3FFFFF
  -- SNES address:  $80:8000 to $FF:FFFF
  -- File offset:   $400000–7FFFFF
  -- SNES address:  $00:8000 to $7F:FFFF

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
    if cur_bank < 0x80 then
      bank = 0x80 + cur_bank
    else
      bank = cur_bank - 0x80
    end

    if DEBUG then
      log.point("writing bank", cur_bank, "of", num_banks - 1, "(" .. bank .. ")")
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- select desired bank
    dict.snes("SNES_SET_BANK", bank)

    if cur_bank < 0xFE then
      flash.write_file(file, kb_per_bank,
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

--- Dump LoROM cartridge RAM to an already-open output file.
-- Selects bank 0x70 for the transfer and restores ROM bank 0x00 afterward.
-- @param file file* Open binary output file
-- @param ram_size_kb integer Number of kilobytes to dump
local function ram_dump(file, ram_size_kb)
  local kb_per_read = ram_size_kb

  log.info("RAM size", ram_size_kb .. "KB")

  -- select desired bank (access RAM)
  dict.snes("SNES_SET_BANK", 0x70)

  -- dump data
  dump.dumptofile(file, kb_per_read, { mapper = mapname, mem_type = "SNES_RAM" })

  -- select desired bank (access ROM)
  dict.snes("SNES_SET_BANK", 0x00)
end

--- Write one 32 KiB LoROM RAM bank from an already-open input file.
-- Selects bank 0x70 for the transfer and restores ROM bank 0x00 afterward.
-- @param file file* Open binary input file
-- @param ram_size_kb integer RAM size in kilobytes, used for reporting
local function ram_write(file, ram_size_kb)
  log.info("RAM size", ram_size_kb .. "KB")

  -- select desired bank (access RAM)
  dict.snes("SNES_SET_BANK", 0x70)

  -- have the device write a bank worth of data
  flash.write_file(file, ram_size_kb, { mapper = mapname, mem_type = "SNES_RAM" })

  -- select desired bank (access ROM)
  dict.snes("SNES_SET_BANK", 0x00)

  log.success("Done programming RAM")
end

--- Detect LoROM cartridge RAM without changing the stored byte.
-- @return boolean detected True when an inverted test byte can be read back
local function ram_detect()
  local saved_value
  local test_value
  local read_value

  local options = { romsel = snes.ROMSEL_LO }

  log.section("Detecting RAM")

  -- select desired bank (access RAM)
  dict.snes("SNES_SET_BANK", 0x70)

  -- save potential battery backed data first
  saved_value = snes.ram_rd(0x0000, options)
  test_value = (saved_value ~ 0xFF) & 0xFF

  -- try to write and read back
  snes.ram_wr(0x0000, test_value, options)
  read_value = snes.ram_rd(0x0000, options)
  -- put back original value
  snes.ram_wr(0x0000, saved_value, options)

  -- select desired bank (access ROM)
  dict.snes("SNES_SET_BANK", 0x00)

  return read_value == test_value
end

--- Detect mirrored LoROM RAM size while preserving the probed bytes.
-- @return integer size_kb Detected RAM size in kilobytes, or 0 on failure
local function ram_get_size()
  local BLOCK_SIZE = 0x400
  local LAST_OFFSET = 0x7C00
  local saved_values = {}

  log.section("Detecting RAM size")

  -- select desired bank (access RAM)
  dict.snes("SNES_SET_BANK", 0x70)

  -- backup ram data
  for offset = 0, LAST_OFFSET, BLOCK_SIZE do
    saved_values[offset] = snes.ram_rd(offset)
  end

  -- write marker values
  for offset = LAST_OFFSET, 0, -BLOCK_SIZE do
    local marker = (offset // BLOCK_SIZE) + 1
    snes.ram_wr(offset, marker)
  end

  local ram_size_kb = snes.ram_rd(LAST_OFFSET)

  -- restore original ram data
  for offset = 0, LAST_OFFSET, BLOCK_SIZE do
    snes.ram_wr(offset, saved_values[offset])
  end

  -- select desired bank (access ROM)
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

--- Overwrite LoROM RAM with an LFSR pattern and verify the resulting dump.
-- @param ram_size_kb integer RAM size in kilobytes
-- @param retroprog_id string|integer Identifier used in the temporary dump filename
-- @return boolean success True when the dump matches the reference LFSR stream
local function ram_test(ram_size_kb, retroprog_id)
  dict.stuff("RESET_LFSR") -- sets it to 1

  log.section("Exercising RAM")
  log.info("RAM size", ram_size_kb .. "KB")

  -- select desired bank (access RAM)
  dict.snes("SNES_SET_BANK", 0x70)

  -- write random data to all banks
  log.point("Writing random data to RAM")

  -- write random data
  local addr = 0x0000
  while addr < (ram_size_kb * 1024) do
    dict.snes("SNES_PAGE_WR_LFSR", addr, snes.ROMSEL_LO)
    addr = addr + 256
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
    rv, rom_flash_chip = snes.rom_get_chip({ bank = 0x00, addr_base = 0x8000 })
    if not rv then
      if do_rom_write then
        log.error("Couldn't identify flash chip")
        return DONE(false)
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
      return DONE(false)
    elseif do_rom_write then
      if options.force_ram_test then
        log.warning("Additional option 'force_ram_test' implies RAM presence")
        log.error("RAM not detected")
        return DONE(false)
      elseif snes.file_header.is_valid and snes.file_header:has_sram() then
        log.warning("ROM header settings implies RAM")
        log.error("RAM not detected")
        return DONE(false)
      elseif ram_size_kb ~= 0 then
        log.warning("CLI options specify " .. ram_size_kb .. "KB of RAM")
        log.error("RAM not detected")
        return DONE(false)
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
        if not rv then return DONE(false) end
      elseif snes.file_header.is_valid and snes.file_header:has_sram() then
        if snes.file_header:has_battery() then
          log.warning("Can't test RAM because ROM header specifies battery backed data")
          log.warning("Use additional option 'force_ram_test' to force RAM test")
        else
          rv = ram_test(ram_size_kb, retroprog_id)
          if not rv then return DONE(false) end
        end
      else
        log.warning("Can't test RAM because data could be battery backed")
        log.warning("Use additional option 'force_ram_test' to force RAM test")
      end
    end
  end

  -- check rom/ram sizes
  if not snes.check_rom_ram_size(process_opts, rom_size_kb, ram_size_kb) then
    return DONE(false)
  end

  --[[
  88""Yb    db    8b    d8     8888b.  88   88 8b    d8 88""Yb
  88__dP   dPYb   88b  d88      8I  Yb 88   88 88b  d88 88__dP
  88"Yb   dP__Yb  88YbdP88      8I  dY Y8   8P 88YbdP88 88"""
  88  Yb dP""""Yb 88 YY 88     8888Y"  `YbodP' 88 YY 88 88
  --]]

  if do_ram_dump then
    -- open file
    file = assert(io.open(ram_dump_file.filename, "wb"))

    -- dump cart to file
    local cartridge_title = ""
    if snes.cart_header.is_valid then
      cartridge_title = snes.cart_header.cartridge_title
    end
    log.section("Dumping RAM", cartridge_title)

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
    if rom_size_kb ~= 0 then
      -- open file
      file = assert(io.open(rom_dump_file.filename, "wb"))

      -- dump cart to file
      local cartridge_title = ""
      if snes.cart_header.is_valid then
        cartridge_title = snes.cart_header.cartridge_title
      end
      log.section("Dumping ROM", cartridge_title)

      time.start()
      rom_dump(file, rom_size_kb)
      time.report(rom_size_kb)
      log.success("Done dumping ROM")

      -- close file
      assert(file:close())
    end

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

    -- erase ROM only if needed
    snes.rom_erase(rom_flash_chip, { bank = 0x00, addr_base = 0x8000 })

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

  return DONE(true)
end

-- global variables so other modules can use them

-- call functions desired to run when script is called/imported

-- functions other modules are able to call
lorom.process = process
lorom.ram_dump = ram_dump
lorom.ram_write = ram_write
lorom.ram_detect = ram_detect
lorom.ram_test = ram_test

-- return the module's table
return lorom
