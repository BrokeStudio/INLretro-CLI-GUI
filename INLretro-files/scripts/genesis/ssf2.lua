-- create the module's table
local ssf2    = {}

-- import required modules
local dict    = require "scripts.app.dict"
local genesis = require "scripts.app.genesis"
local dump    = require "scripts.app.dump"
local flash   = require "scripts.app.flash"
local chips   = require "scripts.app.chips"
local time    = require "scripts.app.time"
local log     = require "scripts.app.log"
local spinner = require "scripts.app.spinner"
local files   = require "scripts.app.files"
local help    = require "scripts.app.help"

-- file constants and global variables
local mapname = "SSF2"

local flash_chip

--[[
███╗   ███╗██╗███████╗ ██████╗    ███████╗██╗   ██╗███╗   ██╗ ██████╗███████╗
████╗ ████║██║██╔════╝██╔════╝    ██╔════╝██║   ██║████╗  ██║██╔════╝██╔════╝
██╔████╔██║██║███████╗██║         █████╗  ██║   ██║██╔██╗ ██║██║     ███████╗
██║╚██╔╝██║██║╚════██║██║         ██╔══╝  ██║   ██║██║╚██╗██║██║     ╚════██║
██║ ╚═╝ ██║██║███████║╚██████╗    ██║     ╚██████╔╝██║ ╚████║╚██████╗███████║
╚═╝     ╚═╝╚═╝╚══════╝ ╚═════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚══════╝

--]]

-- local functions

--- Erase one flash sector on the 32Mb Genesis cartridge.
---@param addr integer 24-bit sector address, 0x000000-0x3FFFFF
local function erase_sector(addr)
  genesis.rom_wr(0x000555 << 1, 0x00AA)
  genesis.rom_wr(0x0002AA << 1, 0x0055)
  genesis.rom_wr(0x000555 << 1, 0x0080)
  genesis.rom_wr(0x000555 << 1, 0x00AA)
  genesis.rom_wr(0x0002AA << 1, 0x0055)
  genesis.rom_wr(addr, 0x0030)

  local temp = genesis.rom_rd(addr)
  local nak = 1
  while (temp ~= genesis.rom_rd(addr)) do
    temp = genesis.rom_rd(addr)
    nak = nak + 1
  end
end

--[[
██████╗  ██████╗ ███╗   ███╗
██╔══██╗██╔═══██╗████╗ ████║
██████╔╝██║   ██║██╔████╔██║
██╔══██╗██║   ██║██║╚██╔╝██║
██║  ██║╚██████╔╝██║ ╚═╝ ██║
╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝

--]]

--- Read and identify the ROM flash manufacturer/device ID.
---@return boolean success True when the flash chip is recognized
local function rom_manf_id()
  local manufacturer_id
  local device_id
  local device_test

  -- compatible SST39VF / MX29
  -- compatible S29GL01GS / S29GL512S / S29GL256S / S29GL128S

  -- flash manf ID
  genesis.rom_wr(0x000555 << 1, 0x00AA)
  genesis.rom_wr(0x0002AA << 1, 0x0055)
  genesis.rom_wr(0x000555 << 1, 0x0090)

  manufacturer_id = genesis.rom_rd(0x0000 << 1)
  chips.display_manufacturer(manufacturer_id)
  flash_chip = manufacturer_id

  device_id = genesis.rom_rd(0x0001 << 1)
  device_test = chips.display_device(manufacturer_id, device_id)

  if manufacturer_id == 0xC2 then
    -- MX chips
    device_id = genesis.rom_rd(0x0001 << 1)
    device_test = chips.display_device(manufacturer_id, device_id)
  elseif manufacturer_id == 0x01 then
    -- Cypress / Spansion
    device_id = genesis.rom_rd(0x000E << 1)
    device_test = chips.display_device(manufacturer_id, device_id)
  else
    -- fallback (SST)
    device_id = genesis.rom_rd(0x0001 << 1)
    device_test = chips.display_device(manufacturer_id, device_id)
  end

  -- exit software
  genesis.rom_wr(0x000000, 0x00F0)

  if device_test == false then
    log.error("Flash chip unknown")
    return false
  else
    log.success("Flash chip deteted successfully")
    return true
  end
end

--- Program one 16-bit word to ROM flash and poll until it reads back.
---@param addr integer 24-bit ROM address, 0x000000-0x3FFFFF
---@param value integer 16-bit value to write
---@param debug? boolean Enable verbose progress logging
local function rom_flash_byte(addr, value, debug)
  if (addr < 0x000000 or addr > 0x3FFFFF) then
    log.error("ERROR! flash write to ROM", help.hex_0x6(addr), "must be $000000-$3FFFFF")
    return
  end

  local addr_hi = (addr >> 16) & 0xff
  local addr_lo = addr & 0xffff

  if debug then
    log.info("write a byte", help.hex_0x6(addr), help.hex_0x4(value))
  end

  genesis.rom_wr(0x000555 << 1, 0x00AA)
  genesis.rom_wr(0x0002AA << 1, 0x0055)
  genesis.rom_wr(0x000555 << 1, 0x00A0)
  genesis.rom_wr(addr, value)

  local rv = genesis.rom_rd(addr_lo)

  local i = 0

  while (rv ~= value) do
    rv = genesis.rom_rd(addr_lo)
    -- if debug then print("post write read:", help.hex(rv)) end
    i = i + 1
    if i > 30 then
      log.info("failed write, tried:", help.hex_0x4(value), "read back value:", help.hex_0x4(rv))
      return
    end
  end

  if debug then
    log.info("Done writing byte,", i .. " naks")
  end

  --TODO handle timeout for problems

  --TODO return pass/fail/info
end

--- Dump SSF2 banked ROM contents to an already-open output file.
---@param file file* Open binary output file
---@param rom_size_kb integer ROM size in kilobytes
---@param debug? boolean Enable verbose progress logging
local function rom_dump(file, rom_size_kb, debug)
  local kb_per_bank = 2 * 64 -- 2 bytes per address, 64K addresses
  local addr_base = 0x0000   -- control signals are manually controlled
  local num_banks = math.floor(rom_size_kb / kb_per_bank)
  local cur_bank = 0

  log.info("ROM size", rom_size_kb .. "KB")

  -- disable SRAM
  genesis.ram_disable()

  while cur_bank < num_banks do
    -- A "large" Genesis ROM is 24 banks, many are 8 and 16 - status every 4 is reasonable.
    -- The largest published Genesis game is Super Street Fighter 2, which is 40 banks!
    -- TODO: Accessing banks in games that are >4MB require using a mapper.
    -- See: https://plutiedev.com/beyond-4mb

    if debug then
      log.point("dumping bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- select desired SSF2 bank
    genesis.time_wr(0xF3, cur_bank >> 2) -- 0xF3 => 0xA130F3

    -- set address hi bits (A23-A16)
    genesis.set_addr_hi(0x08 | ((cur_bank & 0x03) << 1)) -- 0x08 selects the $080000-$0FFFFF window

    dump.dumptofile(file, kb_per_bank / 2, addr_base, "GENESIS_ROM_PAGE0", false)
    dump.dumptofile(file, kb_per_bank / 2, addr_base, "GENESIS_ROM_PAGE1", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--- Program SSF2 banked ROM contents from an already-open input file, one bank at a time.
---@param file file* Open binary input file
---@param rom_size_kb integer ROM size in kilobytes
---@param debug? boolean Enable verbose progress logging
local function rom_write(file, rom_size_kb, debug)
  local kb_per_bank = 2 * 64 -- 2 bytes per address, 64K addresses
  local num_banks = math.floor(rom_size_kb / kb_per_bank)
  local cur_bank = 0

  log.section("Programming ROM")
  log.info("ROM size", rom_size_kb .. "KB")

  -- disable SRAM
  genesis.ram_disable()

  while cur_bank < num_banks do
    if debug then
      log.point("writing bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- select desired SSF2 bank
    genesis.time_wr(0xF3, cur_bank >> 2) -- 0xF3 => 0xA130F3

    -- set address hi bits (A23-A16)
    genesis.set_addr_hi(0x08 | ((cur_bank & 0x03) << 1)) -- 0x08 selects the $080000-$0FFFFF window

    flash.write_file(file, kb_per_bank, mapname, "GENESISROM", false)

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

--- Dump SRAM contents to an already-open output file.
--- Assumes SRAM was enabled as desired before calling.
---@param file file* Open binary output file
---@param addr_hi integer High address byte selecting the SRAM window
---@param ram_size_kb integer SRAM size in kilobytes
---@param debug? boolean Enable verbose progress logging
local function ram_dump(file, addr_hi, ram_size_kb, debug)
  local kb_per_bank = 32 -- TODO: FIXME? => -- 128KByte addressable per bank, but only use lower byte of each 16bit word
  local num_banks = math.floor(ram_size_kb / kb_per_bank)
  local addr_base = 0x00 -- A15-8 address of ram start
  local cur_bank = 0

  log.info("SRAM size", ram_size_kb .. "KB")

  -- select desired bank
  -- A17-23
  genesis.set_addr_hi(addr_hi)

  while cur_bank < num_banks do
    if debug then
      log.point("dumping RAM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- currently don't have means of dumping RAM with A16 high
    dump.dumptofile(file, ram_size_kb, addr_base, "GENESIS_RAM_PAGE", false) -- A16 low

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--- Program SRAM contents from an already-open input file.
---@param file file* Open binary input file
---@param addr_hi integer High address byte selecting the SRAM window
---@param ram_size_kb integer SRAM size in kilobytes
---@param debug? boolean Enable verbose progress logging
local function ram_write(file, addr_hi, ram_size_kb, debug)
  local kb_per_bank = 32 -- 128KByte addressable per bank, but only use lower byte of each 16bit word
  local num_banks = math.floor(ram_size_kb / kb_per_bank)
  local cur_bank = 0

  log.section("Programming SRAM")
  log.info("SRAM size", ram_size_kb .. "KB")

  -- enable RAM
  genesis.ram_enable()

  while cur_bank < num_banks do
    if debug then
      log.point("writing bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Writing", cur_bank, "/", num_banks - 1)
    end

    genesis.set_addr_hi(addr_hi + cur_bank)

    flash.write_file(file, ram_size_kb, mapname, "GENESISRAM", false)

    cur_bank = cur_bank + 1
  end

  -- disable SRAM
  genesis.ram_disable()

  spinner.clear()
  log.success("Done programming SRAM")
end

--- Detect SRAM by preserving, toggling, and restoring one test byte.
---@param debug? boolean Enable verbose progress logging
---@return boolean success True when SRAM read/write behavior is detected
local function ram_test(debug)
  local test = true
  local saved_value
  local write_value
  local read_value

  log.section("Detecting SRAM")

  -- enable RAM
  genesis.ram_enable()

  -- save potential battery backed data first
  saved_value = genesis.ram_rd(0x200000)
  write_value = saved_value ~ 0xff

  -- try to write and read back
  genesis.ram_wr(0x200000, write_value)
  read_value = genesis.ram_rd(0x200000)
  if read_value ~= write_value then
    test = false
  end

  -- put back original value
  genesis.ram_wr(0x200000, saved_value)
  read_value = genesis.ram_rd(0x200000)
  if read_value ~= (saved_value) then
    test = false
  end

  -- disable RAM
  genesis.ram_disable()

  if test then
    log.success("SRAM detected")
  else
    log.error("SRAM not detected")
  end

  return test
end

--- Exercise SRAM with an LFSR pattern and compare the dumped result.
---@param ram_size integer SRAM size in kilobytes
---@param retroprog_id string|integer Identifier used in the temporary dump filename
---@param debug? boolean Enable verbose compare/progress logging
---@return boolean success True when the SRAM dump matches the expected LFSR data
local function ram_exercise(ram_size, retroprog_id, debug)
  --[[
  SRAM covers the $200001-$20FFFF address range, and only every other byte is used (i.e. $200001, $200003, $200005, etc.).
  This gives you a total of 32KB to work with.
  If you need to save numbers larger than fit in a byte, split it into its separate bytes.
--]]

  local addr_hi = 0x20

  dict.stuff("RESET_LFSR") -- sets it to 1

  -- enable SRAM
  genesis.ram_enable()

  -- set SRAM address high bits
  genesis.set_addr_hi(addr_hi)

  log.section("Exercising RAM")
  log.info("RAM size", ram_size .. "KB")

  -- write random data to all banks
  log.point("Writing random data to RAM")
  dict.sega("GEN_PAGE_RAM_WR_LFSR", 0x00, ram_size)

  --dump sram into file
  local filename = opts.lua_path .. "./ignore/gen_sram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))
  log.point("Dumping RAM")
  ram_dump(file, addr_hi, ram_size, debug)

  -- disable SRAM
  genesis.ram_disable()

  -- close the file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "./ignore/lfsr_32KB.bin"

  -- compare the flash file vs post dump file
  if files.compare(filename, goodfile, true, debug) then
    log.success("SRAM test passed")
    return true
  else
    log.error("SRAM test failed")
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
--- Process all requested operations for the Genesis SSF2 mapper.
--- The cartridge should be in reset state before calling.
---@param process_opts table Parsed operation options from the main application
---@param console_opts table Console/cartridge size options
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
  dict.io("SEGA_INIT")

  --[[
  888888 888888 .dP"Y8 888888
    88   88__   `Ybo."   88
    88   88""   o.`Y8b   88
    88   888888 8bodP'   88
  --]]

  -- test cart
  if do_test then
    log.section("Testing " .. mapname)

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
      if ram_size == 0 then
        ram_size = 32
      end
      local is_header_valid = genesis.file_header.is_valid or genesis.cart_header.is_valid
      local has_battery = genesis.file_header:has_battery() or genesis.cart_header:has_battery()
      if options.force_wram_test or is_header_valid then
        if not options.force_wram_test and has_battery then
          log.print()
          log.warning("Can't exercise RAM because ROM has battery backed data")
        else
          if ram_size ~= 0 then
            rv = ram_exercise(ram_size, retroprog_id, DEBUG)
            -- exit script if test fails
            if not rv then return end
          end
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
    -- enable RAM
    genesis.ram_enable()

    -- open file
    file = assert(io.open(ram_dump_file.filename, "wb"))

    -- dump cart to file
    local addr_hi = 0x20
    log.section("Dumping SRAM")
    time.start()
    ram_dump(file, addr_hi, ram_size, DEBUG)
    time.report(ram_size)
    log.success("SRAM dumping done")

    -- close file
    assert(file:close())

    -- disable SRAM
    genesis.ram_disable()
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
    -- flash cart SRAM
    local addr_hi = 0x20
    time.start()
    ram_write(file, addr_hi, ram_size, DEBUG)
    time.report(ram_size)

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

      -- parse ROM dump file header
      log.point("Parsing dumped file header")
      file = assert(io.open(rom_dump_file.filename, "rb"))
      if not genesis.parse_header_file(file) then
        log.warning("Failed to parse ROM dump file header")
      else
        log.success("ROM dump file header parsed successfully")
      end
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
    -- local i = 0
    local temp
    local size_to_erase = rom_size

    -- erase ROM only if needed
    if rom_size ~= 0 then
      log.section("Erasing ROM")

      time.start()
      if (flash_chip == 0x01) then -- Cypress / Spansion
        -- [[
        log.info("erasing only needed sectors because erasing full chip takes 4 min...")

        local sectors = math.floor(rom_size / 128)
        local addr
        -- size_to_erase = sectors * 128

        for i = 0, sectors - 1, 1 do
          addr = i * 128 * 1024
          if (DEBUG) then
            log.bullet("erasing sector", i, "of", sectors - 1)
          else
            spinner.update("Erasing sector ", i, "/", sectors - 1) --, string.format("(%06X)", addr))
          end
          temp = erase_sector(addr, DEBUG)
        end
        spinner.clear()
        log.success("Done erasing ROM (" .. sectors .. " sectors)")
      else
        --]]
        -- disable SRAM
        genesis.ram_disable()

        genesis.rom_wr(0x000555 << 1, 0x00AA)
        genesis.rom_wr(0x0002AA << 1, 0x0055)
        genesis.rom_wr(0x000555 << 1, 0x0080)
        genesis.rom_wr(0x000555 << 1, 0x00AA)
        genesis.rom_wr(0x0002AA << 1, 0x0055)
        genesis.rom_wr(0x000555 << 1, 0x0010)

        rv = genesis.rom_rd(0x0000)
        while (rv ~= genesis.rom_rd(0x0000)) do
          spinner.update("Erasing")
          rv = genesis.rom_rd(0x0000)
          i = i + 1
        end
        spinner.clear()
        log.success("Done erasing ROM", i .. " naks")
      end
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
    if rom_size ~= 0 then
      --open file
      file = assert(io.open(rom_write_file.filename, "rb"))
      --determine if auto-doubling, deinterleaving, etc,
      --needs done to make board compatible with rom

      --flash cart
      time.start()
      rom_write(file, rom_size, DEBUG)
      time.report(rom_size)

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

  -- verify flashed file on the cart
  if do_verify then
    if rom_size ~= 0 then
      -- open file
      file = assert(io.open(verify_file.filename, "wb"))

      -- dump cart to file
      log.section("Dumping ROM")
      time.start()
      rom_dump(file, rom_size, DEBUG)
      time.report(rom_size)

      -- close file
      assert(file:close())

      -- parse ROM dump file header
      log.point("Parsing dumped file header")
      file = assert(io.open(verify_file.filename, "rb"))
      if not genesis.parse_header_file(file) then
        log.warning("Failed to parse ROM dump file header")
      else
        log.success("ROM dump file header parsed successfully")
      end
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
ssf2.process = process

-- return the module's table
return ssf2
