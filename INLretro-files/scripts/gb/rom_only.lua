-- create the module's table
local romonly = {}

-- import required modules
local dict    = require "scripts.app.dict"
local gb      = require "scripts.app.gb"
local dump    = require "scripts.app.dump"
local flash   = require "scripts.app.flash"
local chips   = require "scripts.app.chips"
local time    = require "scripts.app.time"
local log     = require "scripts.app.log"
local spinner = require "scripts.app.spinner"
local files   = require "scripts.app.files"
local help    = require "scripts.app.help"

-- file constants and global variables
local mapname = "ROMONLY"

-- local functions

--[[
███╗   ███╗██╗███████╗ ██████╗    ███████╗██╗   ██╗███╗   ██╗ ██████╗███████╗
████╗ ████║██║██╔════╝██╔════╝    ██╔════╝██║   ██║████╗  ██║██╔════╝██╔════╝
██╔████╔██║██║███████╗██║         █████╗  ██║   ██║██╔██╗ ██║██║     ███████╗
██║╚██╔╝██║██║╚════██║██║         ██╔══╝  ██║   ██║██║╚██╗██║██║     ╚════██║
██║ ╚═╝ ██║██║███████║╚██████╗    ██║     ╚██████╔╝██║ ╚████║╚██████╗███████║
╚═╝     ╚═╝╚═╝╚══════╝ ╚═════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚══════╝

--]]

--[[
██████╗  ██████╗ ███╗   ███╗
██╔══██╗██╔═══██╗████╗ ████║
██████╔╝██║   ██║██╔████╔██║
██╔══██╗██║   ██║██║╚██╔╝██║
██║  ██║╚██████╔╝██║ ╚═╝ ██║
╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝

--]]

-- read ROM flash ID
local function rom_manf_id()
  local manufacturer_id
  local device_id
  local device_test

  log.section("Reading ROM manufacturer/device ID")

  dict.gameboy("GAMEBOY_WR", 0x5555, 0xAA)
  dict.gameboy("GAMEBOY_WR", 0x2AAA, 0x55)
  dict.gameboy("GAMEBOY_WR", 0x5555, 0x90)

  manufacturer_id = dict.gameboy("GAMEBOY_RD", 0x0000)
  chips.display_manufacturer(manufacturer_id)

  device_id = dict.gameboy("GAMEBOY_RD", 0x0001)
  device_test = chips.display_device(manufacturer_id, device_id)

  -- exit software
  dict.gameboy("GAMEBOY_WR", 0x0000, 0xF0)

  if device_test == false then
    return false
  else
    return true
  end
end

-- erase ROM
local function rom_erase()
  local i = 0
  local rv

  log.section("Erasing ROM")
  dict.gameboy("GAMEBOY_WR", 0x2000, 0x01)
  dict.gameboy("GAMEBOY_PIN31_WR", 0x5555, 0xAA)
  dict.gameboy("GAMEBOY_PIN31_WR", 0x2AAA, 0x55)
  dict.gameboy("GAMEBOY_PIN31_WR", 0x5555, 0x80)
  dict.gameboy("GAMEBOY_PIN31_WR", 0x5555, 0xAA)
  dict.gameboy("GAMEBOY_PIN31_WR", 0x2AAA, 0x55)
  dict.gameboy("GAMEBOY_PIN31_WR", 0x5555, 0x10)

  -- TODO create some function to pass the read value
  -- that's smart enough to figure out if the board is actually erasing or not
  rv = dict.gameboy("GAMEBOY_RD", 0x0000)
  while rv ~= dict.gameboy("GAMEBOY_RD", 0x0000) do
    spinner.update("Erasing")
    rv = dict.gameboy("GAMEBOY_RD", 0x0000)
    i = i + 1
  end
  spinner.clear()
  log.success("Done erasing ROM", i .. " naks")
end

-- dump the ROM
local function rom_dump(file, rom_size_KB, debug)
  -- ROM dump 32KB at a time
  local KB_per_read = 32
  local num_banks = math.floor(rom_size_KB / KB_per_read)
  local cur_bank = 0
  local addr_base = 0x00 -- $0000

  -- the first bank is fixed and only visible at $0000-3FFF
  if debug then
    log.point("dumping bank", cur_bank, "of", num_banks - 1)
  else
    spinner.update("Dumping", cur_bank, "/", num_banks - 1)
  end

  dump.dumptofile(file, KB_per_read, addr_base, "GAMEBOY_PAGE", false)

  spinner.clear()
end

-- flash the ROM
local function rom_flash(file, rom_size_KB, debug)
  log.section("Programming ROM")
  log.info("ROM size", rom_size_KB .. "KB")

  local bank_size = 32
  local cur_bank = 0
  local num_banks = math.floor(rom_size_KB / bank_size)

  -- flash fixed bank first
  if debug then
    log.point("writing bank", cur_bank, "of", num_banks - 1)
  else
    spinner.update("Flashing", cur_bank, "/", num_banks - 1)
  end

  dict.gameboy("GAMEBOY_SET_CUR_BANK", cur_bank)

  flash.write_file(file, bank_size, mapname, "GBROM", false)

  spinner.clear()
  log.success("Done programming ROM")
end

-- local functions
local function unsupported(operation)
  print("\nUNSUPPORTED OPERATION: \"" .. operation .. "\" not implemented yet for Gameboy - " .. mapname .. "\n")
end

--write a single byte to ROM flash
local function wr_rom_flash_byte(addr, value, debug)
  if (addr < 0x0000 or addr > 0x7FFF) then
    print("\n  ERROR! flash write to ROM", string.format("$%X", addr), "must be $0000-7FFF \n\n")
    return
  end

  --send unlock command and write byte
  dict.gameboy("GAMEBOY_WR", 0x5555, 0xAA)
  dict.gameboy("GAMEBOY_WR", 0x2AAA, 0x55)
  dict.gameboy("GAMEBOY_WR", 0x5555, 0xA0)
  dict.gameboy("GAMEBOY_WR", addr, value)

  local rv = dict.gameboy("GAMEBOY_RD", addr)

  local i = 0

  while (rv ~= value) do
    rv = dict.gameboy("GAMEBOY_RD", addr)
    i = i + 1
  end
  if debug then print(i, "naks, done writing byte.") end

  --TODO handle timeout for problems

  --TODO return pass/fail/info
end

--[[
██████╗  █████╗ ███╗   ███╗
██╔══██╗██╔══██╗████╗ ████║
██████╔╝███████║██╔████╔██║
██╔══██╗██╔══██║██║╚██╔╝██║
██║  ██║██║  ██║██║ ╚═╝ ██║
╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝

--]]

-- dump the RAM, assumes the RAM was enabled as desired prior to calling
local function ram_dump(file, ram_size_KB, debug)
  local KB_per_read = 8
  local num_banks = math.floor(ram_size_KB / KB_per_read)
  local cur_bank = 0
  local addr_base = 0xA0 -- $A000

  log.info("RAM size", ram_size_KB .. "KB")

  while cur_bank < num_banks do
    if debug then
      log.point("dumping RAM bank ", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- have the device dump a bank worth of data
    dump.dumptofile(file, KB_per_read, addr_base, "GAMEBOY_PAGE", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

-- write to the PRG-RAM, assumes the PRG-RAM was enabled/disabled as desired prior to calling
local function ram_write(file, ram_size_KB, debug)
  log.section("Programming RAM")
  log.info("RAM size", ram_size_KB .. "KB")

  local bank_size = 8
  local cur_bank = 0
  local num_banks = math.floor(ram_size_KB / bank_size)

  while cur_bank < num_banks do
    if debug then
      log.point("writing bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size, mapname, "GBRAM", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
  log.success("Done programming RAM")
end

-- try to detect ram
local function ram_test(debug)
  local test = true
  local read_value
  local saved_value

  log.section("Detecting RAM")

  -- save potential battery backed data first
  saved_value = dict.gameboy("GAMEBOY_RD", 0xA000)

  -- try to write and read back
  dict.gameboy("GAMEBOY_WR", 0xA000, saved_value ~ 0xff)
  read_value = dict.gameboy("GAMEBOY_RD", 0xA000)
  if read_value ~= (saved_value ~ 0xff) then
    test = false
  end

  -- put back original value
  dict.gameboy("GAMEBOY_WR", 0xA000, saved_value)
  read_value = dict.gameboy("GAMEBOY_RD", 0xA000)
  if read_value ~= (saved_value) then
    test = false
  end

  if test then
    log.success("RAM detected")
  else
    log.error("RAM not detected")
  end

  return test
end

local function ram_exercise(ram_size, retroprog_id, debug)
  dict.stuff("RESET_LFSR") -- sets it to 1

  local cur_bank = 0
  local num_banks = math.floor(ram_size / 8)

  log.section("Exercising RAM")
  log.info("RAM size", ram_size .. "KB")

  -- write random data to all banks
  log.point("Writing random data to RAM")
  while cur_bank < num_banks do
    if debug then
      log.point("init RAM 8K bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Initializing", cur_bank, "/", num_banks - 1)
    end

    -- write random data
    local addr = 0xA000
    while addr < 0xC000 do
      dict.gameboy("GAMEBOY_PAGE_WR_LFSR", addr)
      addr = addr + 256
    end

    cur_bank = cur_bank + 1
  end

  spinner.clear()

  -- open file
  local filename = opts.lua_path .. "./ignore/gb_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))

  -- dump RAM
  log.point("Dumping RAM")
  ram_dump(file, ram_size, debug)

  -- close file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "./ignore/lfsr_32KB.bin"

  -- compare the flash file vs post dump file
  if files.compare(filename, goodfile, false, debug) then
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

-- Cart should be in reset state upon calling this function
-- this function processes all user requests for this specific board/mapper
local function process(process_opts, console_opts)
  -- some local variables
  local rv             = nil
  local file

  -- process options
  local DEBUG          = process_opts.debug
  local retroprog_id   = process_opts.retroprog_id
  local do_test        = process_opts.do_test
  local do_erase       = process_opts.do_erase
  local do_rom_write   = process_opts.do_rom_write
  local do_verify      = process_opts.do_verify
  local do_rom_dump    = process_opts.do_rom_dump
  local do_ram_dump    = process_opts.do_ram_dump
  local do_ram_write   = process_opts.do_ram_write
  local rom_write_file = process_opts.rom_write_file
  local verify_file    = process_opts.verify_file
  local rom_dump_file  = process_opts.rom_dump_file
  local ram_dump_file  = process_opts.ram_dump_file
  local ram_write_file = process_opts.ram_write_file
  local options        = process_opts.additional_opts

  -- console options
  local rom_size       = console_opts.rom_size_kb
  local ram_size       = console_opts.wram_size_kb

  -- Initialize device i/o
  dict.io("IO_RESET")
  dict.io("GAMEBOY_INIT")

  dict.io("GB_POWER_5V") -- Gameboy carts prob run fine at 3v if want to be safe

  --[[
  888888 888888 .dP"Y8 888888
    88   88__   `Ybo."   88
    88   88""   o.`Y8b   88
    88   888888 8bodP'   88
  --]]

  -- test cart
  if do_test then
    log.section("Testing", mapname)

    -- attempt to read ROM flash ID
    if options.force_flash_test or (do_rom_write and rom_size ~= 0) then
      rv = rom_manf_id()
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
    rv = ram_test(DEBUG)
    if rv == true then
      if options.force_wram_test then
        log.print()
        log.warning("Flag 'force_wram_test' enabled")
      end
      local is_header_valid = gb.file_header.is_valid or gb.cart_header.is_valid
      local has_battery = gb.file_header:has_battery() or gb.cart_header:has_battery()
      if options.force_wram_test or is_header_valid then
        if not options.force_wram_test and has_battery then
          log.print()
          log.warning("Can't exercise RAM because ROM has battery backed data")
        else
          -- if wram_size == 0 then
          --   wram_size = ram_get_size(DEBUG)
          -- end
          -- if wram_size ~= 0 then
          rv = ram_exercise(8, retroprog_id, DEBUG)
          -- exit script if test fails
          if not rv then return end
          -- end
        end
      else
        log.warning("Can't exercise RAM because data could be battery backed")
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
    -- open file
    file = assert(io.open(ram_dump_file.filename, "wb"))

    -- dump cart to file
    if ram_size ~= 0 then
      log.section("Dumping RAM")
      time.start()
      ram_dump(file, ram_size, DEBUG)
      time.report(ram_size)
      log.success("RAM dumping done")
    else
      log.error("RAM size not provided")
      return
    end

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
    -- open file
    file = assert(io.open(ram_write_file.filename, "rb"))

    -- flash cart
    if ram_size ~= 0 then
      time.start()
      ram_write(file, ram_size, DEBUG)
      time.report(ram_size)
    else
      log.error("RAM size not provided")
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
    if rom_size ~= 0 then
    -- open file
    file = assert(io.open(rom_dump_file.filename, "wb"))

    -- dump cart to file
      log.section("Dumping ROM")
      time.start()
      rom_dump(file, rom_size, DEBUG)
      time.report(rom_size)
      log.success("ROM dumping done")

    -- close file
    assert(file:close())
  end
  end

  --[[
  88""Yb  dP"Yb  8b    d8     888888 88""Yb    db    .dP"Y8 888888
  88__dP dP   Yb 88b  d88     88__   88__dP   dPYb   `Ybo." 88__
  88"Yb  Yb   dP 88YbdP88     88""   88"Yb   dP__Yb  o.`Y8b 88""
  88  Yb  YbodP  88 YY 88     888888 88  Yb dP""""Yb 8bodP' 888888
  --]]

  -- erase the cart
  if do_erase then
    -- erase ROM only if needed
    if rom_size ~= 0 then
      time.start()
      rom_erase()
      time.report(rom_size)
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
    if rom_size ~= 0 then
      time.start()
      rom_flash(file, rom_size, DEBUG)
      time.report(rom_size)
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
    if rom_size ~= 0 then
    -- open file
    file = assert(io.open(verify_file.filename, "wb"))

    -- dump cart to file
      log.section("Dumping ROM")
      time.start()
      rom_dump(file, rom_size, DEBUG)
      time.report(rom_size)
      log.success("ROM dumping done")

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
  end

  dict.io("IO_RESET")
end

-- global variables so other modules can use them
--    NONE

-- call functions desired to run when script is called/imported
--    NONE

-- functions other modules are able to call
romonly.process = process

-- return the module's table
return romonly
