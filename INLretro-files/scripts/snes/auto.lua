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

-- local functions

--[[
███╗   ███╗██╗███████╗ ██████╗    ███████╗██╗   ██╗███╗   ██╗ ██████╗███████╗
████╗ ████║██║██╔════╝██╔════╝    ██╔════╝██║   ██║████╗  ██║██╔════╝██╔════╝
██╔████╔██║██║███████╗██║         █████╗  ██║   ██║██╔██╗ ██║██║     ███████╗
██║╚██╔╝██║██║╚════██║██║         ██╔══╝  ██║   ██║██║╚██╗██║██║     ╚════██║
██║ ╚═╝ ██║██║███████║╚██████╗    ██║     ╚██████╔╝██║ ╚████║╚██████╗███████║
╚═╝     ╚═╝╚═╝╚══════╝ ╚═════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚══════╝

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

-- read ROM flash ID
local function rom_manf_id(debug)
  local manufacturer_id
  local device_id
  local device_test

  -- enter software mode A11 is highest address bit that needs to be valid
  -- datasheet not exactly explicit, A11 might not need to be valid
  -- part has A-1 (negative 1) since it's in byte mode, meaning the part's A11 is actually A12
  -- WR $AAA:AA $555:55 $AAA:AA
  dict.snes("SNES_SET_BANK", 0x00)

  dict.snes("SNES_ROM_WR", 0x8AAA, 0xAA)
  dict.snes("SNES_ROM_WR", 0x8555, 0x55)
  dict.snes("SNES_ROM_WR", 0x8AAA, 0x90)

  manufacturer_id = dict.snes("SNES_ROM_RD", 0x8000)
  chips.display_manufacturer(manufacturer_id)

  if manufacturer_id == 0xC2 then
    -- MX chips
    device_id = dict.snes("SNES_ROM_RD", 0x0002)
    device_test = chips.display_device(manufacturer_id, device_id)
  elseif manufacturer_id == 0x01 then
    -- Cypress / Spansion
    device_id = dict.snes("SNES_ROM_RD", 0x0002) << 16
    device_id = device_id | (dict.snes("SNES_ROM_RD", 0x001C) << 8)
    device_id = device_id | dict.snes("SNES_ROM_RD", 0x001E)
  device_test = chips.display_device(manufacturer_id, device_id)
  else
    -- fallback (SST)
    device_id = dict.snes("SNES_ROM_RD", 0x0001)
    device_test = chips.display_device(manufacturer_id, device_id)
  end

  -- exit software
  dict.snes("SNES_ROM_WR", 0x8000, 0xF0)

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
  dict.snes("SNES_SET_BANK", 0x00)
  dict.snes("SNES_ROM_WR", 0x8AAA, 0xAA)
  dict.snes("SNES_ROM_WR", 0x8555, 0x55)
  dict.snes("SNES_ROM_WR", 0x8AAA, 0x80)
  dict.snes("SNES_ROM_WR", 0x8AAA, 0xAA)
  dict.snes("SNES_ROM_WR", 0x8555, 0x55)
  dict.snes("SNES_ROM_WR", 0x8AAA, 0x10)

  -- TODO create some function to pass the read value
  -- that's smart enough to figure out if the board is actually erasing or not
  rv = dict.snes("SNES_ROM_RD", 0x0000)
  while rv ~= dict.snes("SNES_ROM_RD", 0x0000) do
    spinner.update("Erasing")
    rv = dict.snes("SNES_ROM_RD", 0x0000)
    i = i + 1
  end
  spinner.clear()
  log.success("Done erasing ROM", i .. " naks")
end

--write a single byte to SNES ROM flash
--writes to currently selected bank address
local function rom_flash_byte(addr, value, debug)
  if (addr < 0x0000 or addr > 0xFFFF) then
    print("\n  ERROR! flash write to SNES", string.format("$%X", addr), "must be $0000-FFFF \n\n")
    return
  end

  --send unlock command and write byte
  dict.snes("SNES_ROM_WR", 0x8AAA, 0xAA)
  dict.snes("SNES_ROM_WR", 0x8555, 0x55)
  dict.snes("SNES_ROM_WR", 0x8AAA, 0xA0)
  dict.snes("SNES_ROM_WR", addr, value)

  local rv = dict.snes("SNES_ROM_RD", addr)

  local i = 0

  while (rv ~= value) do
    rv = dict.snes("SNES_ROM_RD", addr)
    i = i + 1
  end
  if debug then print(i, "naks, done writing byte.") end
  if debug then print("written value:", string.format("%X", value), "verified value:", string.format("%X", rv)) end

  --TODO handle timeout for problems

  --TODO return pass/fail/info
end

-- dump ROM
local function rom_dump(file, rom_size_KB, debug)
  -- /ROMSEL is always low for this dump

  local KB_per_bank
  local addr_base

  if mapname == "LOROM" then
    KB_per_bank = 32 -- LOROM has 32KB per bank
    addr_base = 0x80 -- LOROM data starts at $8000
  elseif mapname == "HIROM" then
    KB_per_bank = 64 -- HIROM has 64KB per bank
    addr_base = 0x00 -- HIROM data starts at $0000
  else
    log.error("Mapper unknown:", mapname)
    do return end
  end

  local num_banks = math.floor(rom_size_KB / KB_per_bank)
  local cur_bank = 0

  log.info("ROM size", rom_size_KB .. "KB")

  while cur_bank < num_banks do
    if debug then
      log.point("dumping bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    --select desired bank
    dict.snes("SNES_SET_BANK", cur_bank) -- start_bank+cur_bank)

    dump.dumptofile(file, KB_per_bank, addr_base, "SNESROM_PAGE", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

-- host flash one bank at a time
local function rom_flash(file, rom_size_KB, debug)
  local KB_per_bank
  -- local addr_base
  local mapmode

  if mapname == "LOROM" then
    KB_per_bank = 32 -- LOROM has 32KB per bank
    -- addr_base = 0x80 -- LOROM data starts at $8000
  elseif mapname == "HIROM" then
    KB_per_bank = 64 -- HIROM has 64KB per bank
    -- addr_base = 0x00 -- HIROM data starts at $0000
  else
    log.error("Mapper unknown:", mapname)
    do return end
  end

  local num_banks = math.floor(rom_size_KB / KB_per_bank)
  local cur_bank = 0

  log.section("Programming ROM")
  log.info("ROM size", rom_size_KB .. "KB")

  while cur_bank < num_banks do
    if debug then
      log.point("writing bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    --select desired bank
    dict.snes("SNES_SET_BANK", cur_bank) -- start_bank+cur_bank)

    flash.write_file(file, KB_per_bank, mapname .. "_3VOLT", "SNESROM", true)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
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

  if snes.cart_header.is_valid then
    if snes.cart_header.rom_type.mode == 0 then
      mapname = "LOROM"
    elseif snes.cart_header.rom_type.mode == 1 then
      mapname = "HIROM"
    else
      log.error("Cart ROM header rom type is invalid")
      return false
    end
  end

  if snes.file_header.is_valid then
    if snes.file_header.rom_type.mode == 0 then
    mapname = "LOROM"
    elseif snes.file_header.rom_type.mode == 1 then
    mapname = "HIROM"
    else
      log.error("File ROM header rom type is invalid")
      return false
    end
  end

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
    local cartridge_title = ""
      if snes.cart_header.is_valid then
        cartridge_title = snes.cart_header.cartridge_title
    end
    log.section("Dumping ROM", cartridge_title)

    time.start()
    rom_dump(file, rom_size, DEBUG)
    time.report(rom_size)
    log.success("ROM dumping done")

    -- close file
    assert(file:close())
    end

    -- -- parse ROM dump file header
    -- log.point("Parsing dumped file header")
    -- file = assert(io.open(rom_dump_file.filename, "rb"))
    -- if not genesis.parse_header_file(file) then
    --   log.warning("Failed to parse ROM dump file header")
    -- else
    --   log.success("ROM dump file header parsed successfully")
    -- end
    -- assert(file:close())
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

-- call functions desired to run when script is called/imported

-- functions other modules are able to call
lorom.process = process

-- return the module's table
return lorom
