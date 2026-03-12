-- create the module's table
local mbc5    = {}

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
local mapname = "MBC5"

-- local functions

--[[
███╗   ███╗██╗███████╗ ██████╗    ███████╗██╗   ██╗███╗   ██╗ ██████╗███████╗
████╗ ████║██║██╔════╝██╔════╝    ██╔════╝██║   ██║████╗  ██║██╔════╝██╔════╝
██╔████╔██║██║███████╗██║         █████╗  ██║   ██║██╔██╗ ██║██║     ███████╗
██║╚██╔╝██║██║╚════██║██║         ██╔══╝  ██║   ██║██║╚██╗██║██║     ╚════██║
██║ ╚═╝ ██║██║███████║╚██████╗    ██║     ╚██████╔╝██║ ╚████║╚██████╗███████║
╚═╝     ╚═╝╚═╝╚══════╝ ╚═════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚══════╝

--]]

-- write a single byte to ROM flash
local function rom_flash_byte(addr, value, debug)
  if addr < 0x0000 or addr > 0x7FFF then
    log.error("ERROR! flash write to ROM", help.hex_0x4(addr), "must be $0000-$7FFF")
    return
  end

  dict.gameboy("GAMEBOY_WR", 0x5555, 0xAA)
  dict.gameboy("GAMEBOY_WR", 0x2AAA, 0x55)
  dict.gameboy("GAMEBOY_WR", 0x5555, 0xA0)
  dict.gameboy("GAMEBOY_WR", addr, value)

  local rv = dict.gameboy("GAMEBOY_RD", addr)

  local i = 0

  while rv ~= dict.gameboy("GAMEBOY_RD", addr) do
    rv = dict.gameboy("GAMEBOY_RD", addr)
    i = i + 1
  end

  if debug then
    log.info("Done writing byte,", i .. " naks")
  end

  -- TODO handle timeout for problems

  -- TODO return pass/fail/info
end

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

  dict.gameboy("GAMEBOY_PIN31_WR", 0x0AAA, 0xAA)
  dict.gameboy("GAMEBOY_PIN31_WR", 0x0555, 0x55)
  dict.gameboy("GAMEBOY_PIN31_WR", 0x0AAA, 0x90)

  manufacturer_id = dict.gameboy("GAMEBOY_RD", 0x0000)
  chips.display_manufacturer(manufacturer_id)

  device_id = dict.gameboy("GAMEBOY_RD", 0x0001)
  device_test = chips.display_device(manufacturer_id, device_id)

  if not device_test then
    device_id = dict.gameboy("GAMEBOY_RD", 0x0002) << 16
    device_id = device_id | (dict.gameboy("GAMEBOY_RD", 0x001C) << 8)
    device_id = device_id | dict.gameboy("GAMEBOY_RD", 0x001E)
    device_test = chips.display_device(manufacturer_id, device_id)
  end

  -- exit software
  dict.gameboy("GAMEBOY_PIN31_WR", 0x0000, 0xF0)

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
  dict.gameboy("GAMEBOY_PIN31_WR", 0x0AAA, 0xAA)
  dict.gameboy("GAMEBOY_PIN31_WR", 0x0555, 0x55)
  dict.gameboy("GAMEBOY_PIN31_WR", 0x0AAA, 0x80)
  dict.gameboy("GAMEBOY_PIN31_WR", 0x0AAA, 0xAA)
  dict.gameboy("GAMEBOY_PIN31_WR", 0x0555, 0x55)
  dict.gameboy("GAMEBOY_PIN31_WR", 0x0AAA, 0x10)

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

-- dump ROM
local function rom_dump(file, rom_size_KB, debug)
  -- ROM dump 16KB at a time
  local KB_per_read = 16
  local num_banks = math.floor(rom_size_KB / KB_per_read)
  local cur_bank = 0
  local addr_base = 0x40 -- $4000

  while cur_bank < num_banks do
    if debug then
      log.point("dumping bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    dict.gameboy("GAMEBOY_WR", 0x3000, (cur_bank & 0x100) >> 8)
    dict.gameboy("GAMEBOY_WR", 0x2000, cur_bank & 0xff)

    dump.dumptofile(file, KB_per_read, addr_base, "GAMEBOY_PAGE", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

-- host flash one bank at a time
local function rom_flash(file, rom_size_KB, debug)
  log.section("Programming ROM")
  log.info("ROM size", rom_size_KB .. "KB")

  local bank_size = 16
  local cur_bank = 0
  local num_banks = math.floor(rom_size_KB / bank_size)

  while cur_bank < num_banks do
    if debug then
      log.point("writing bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    dict.gameboy("GAMEBOY_SET_CUR_BANK", cur_bank) -- FIXME
    dict.gameboy("GAMEBOY_WR", 0x3000, (cur_bank & 0x100) >> 8)
    dict.gameboy("GAMEBOY_WR", 0x2000, cur_bank & 0xff)

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size, mapname, "GBROM", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
  log.success("Done programming ROM")
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

    -- set bank
    dict.gameboy("GAMEBOY_WR", 0x4000, cur_bank)

    -- have the device dump a bank worth of data
    dump.dumptofile(file, KB_per_read, addr_base, "GAMEBOY_PAGE", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

-- write to the RAM, assumes the RAM was enabled/disabled as desired prior to calling
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

    -- set bank
    dict.gameboy("GAMEBOY_WR", 0x4000, cur_bank)

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size, mapname, "GBRAM", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
  log.success("Done programming RAM")
end

local function ram_detect(debug)
  local test = true
  local read_value
  local saved_value

  log.section("Detecting RAM")

  -- enable RAM
  dict.gameboy("GAMEBOY_WR", 0x0000, 0x0A)

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

  -- disable RAM
  dict.gameboy("GAMEBOY_WR", 0x0000, 0x00)

  return test
end

-- try to detect RAM size
local function ram_get_size(debug)
  -- RAM can be maximum 32KB
  -- so we'll check 8 8K banks and see if we can write to each

  local ram_size = 32
  local num_banks = math.floor(ram_size / 8)
  local cur_bank = num_banks - 1

  log.section("Detecting RAM size")

  -- enable RAM
  dict.gameboy("GAMEBOY_WR", 0x0000, 0x0A)

  -- write to banks backwards
  while cur_bank >= 0 do
    if debug then
      log.point("trying to write to RAM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Writing", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    dict.gameboy("GAMEBOY_WR", 0x4000, cur_bank)

    -- write data
    dict.gameboy("GAMEBOY_WR", 0xA000, cur_bank)

    cur_bank = cur_bank - 1
  end

  spinner.clear()

  -- read back only last bank
  dict.gameboy("GAMEBOY_WR", 0x4000, num_banks - 1)
  ram_size = (dict.gameboy("GAMEBOY_RD", 0xA000) + 1) * 8

  -- disable RAM
  dict.gameboy("GAMEBOY_WR", 0x0000, 0x00)

  if ram_size >= 0 and ram_size <= 32 then
    log.success("RAM size detected", ram_size .. "KB")
    return ram_size
  else
    log.warning("Failed to detect RAM size")
    return 0
  end
end

local function ram_exercise(wram_size, retroprog_id, debug)
  dict.stuff("RESET_LFSR") -- sets it to 1

  local cur_bank = 0
  local num_banks = math.floor(wram_size / 8)

  log.section("Exercising RAM")
  log.info("RAM size", wram_size .. "KB")

  -- enable RAM
  dict.gameboy("GAMEBOY_WR", 0x0000, 0x0A)

  -- write random data to all banks
  log.point("Writing random data to RAM")
  while cur_bank < num_banks do
    if debug then
      log.point("init RAM 8K bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Initializing", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    dict.gameboy("GAMEBOY_WR", 0x4000, cur_bank)

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
  local filename = opts.lua_path .. "ignore/gb_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))

  -- dump RAM
  log.point("Dumping RAM")
  ram_dump(file, wram_size, false)

  -- disable RAM
  dict.gameboy("GAMEBOY_WR", 0x0000, 0x00)

  -- close file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "ignore/lfsr_32KB.bin"

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
  local wram_size      = console_opts.wram_size_kb

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
    rv = ram_detect(DEBUG)

    if rv == false then -- RAM not found
      if do_ram_dump or do_ram_write then
        log.error("RAM not detected")
        return false
      elseif do_rom_write then
        if options.force_wram_test then
          log.warning("Additional option 'force_wram_test' implies RAM presence")
          log.error("RAM not detected")
          return false
        elseif gb.file_header.isValid and gb.file_header:get_ram_size() ~= 0 then
          log.warning("ROM header settings implies RAM")
          log.error("RAM not detected")
          -- return false
        elseif wram_size ~= 0 then
          log.warning("CLI options specify " .. wram_size .. "KB of RAM")
          log.error("RAM not detected")
          return false
        else
          log.info("RAM not detected")
        end
      end
    else -- RAM found
      log.success("RAM detected")
      if wram_size == 0 then
        wram_size = ram_get_size(DEBUG)
      end
      if (do_rom_dump or do_ram_dump) and options.force_wram_test then
        log.warning("Additional option 'force_wram_test' is ignored when dumping ROM or RAM")
      elseif do_rom_write then
        if wram_size < gb.file_header:get_ram_size() then
          log.error("On board RAM size is less than ROM header RAM size")
          return false
        elseif options.force_wram_test then
          rv = ram_exercise(wram_size, retroprog_id, DEBUG)
          if not rv then return false end
        else
          log.warning("Can't test RAM because data could be battery backed")
          log.warning("Use additional option 'force_wram_test' to force RAM test")
        end
      elseif do_ram_write then
        rv = ram_exercise(wram_size, retroprog_id, DEBUG)
        if not rv then return false end
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

    -- enable RAM
    dict.gameboy("GAMEBOY_WR", 0x0000, 0x0A)

    -- dump cart to file
    if wram_size ~= 0 then
      log.section("Dumping RAM")
      time.start()
      ram_dump(file, wram_size, DEBUG)
      time.report(wram_size)
      log.success("RAM dumping done")
    else
      log.error("RAM size not provided")
      return
    end

    -- disable RAM
    dict.gameboy("GAMEBOY_WR", 0x0000, 0x00)

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

    -- enable RAM
    dict.gameboy("GAMEBOY_WR", 0x0000, 0x0A)

    -- flash cart
    if wram_size ~= 0 then
      time.start()
      ram_write(file, wram_size, DEBUG)
      time.report(wram_size)
    else
      log.error("RAM size not provided")
      return
    end

    -- disable RAM
    dict.gameboy("GAMEBOY_WR", 0x0000, 0x00)

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
    -- open file
    file = assert(io.open(rom_dump_file.filename, "wb"))

    -- dump cart to file
    if rom_size ~= 0 then
      log.section("Dumping ROM")
      time.start()
      rom_dump(file, rom_size, DEBUG)
      time.report(rom_size)
      log.success("ROM dumping done")
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
    -- open file
    file = assert(io.open(verify_file.filename, "wb"))

    -- dump cart to file
    if rom_size ~= 0 then
      log.section("Dumping ROM")
      time.start()
      rom_dump(file, rom_size, DEBUG)
      time.report(rom_size)
      log.success("ROM dumping done")
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
mbc5.process = process

-- return the module's table
return mbc5
