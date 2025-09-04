-- create the module's table
local rainbow = {}

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
local mapname = "RNBW"

-- local functions
local flash_chip

local function erase_sector(addr, debug)
  dict.sega("GEN_SET_RAM", 0x00) -- disable SRAM
  genesis.rom_wr(0x000555, 0x00AA)
  genesis.rom_wr(0x0002AA, 0x0055)
  genesis.rom_wr(0x000555, 0x0080)
  genesis.rom_wr(0x000555, 0x00AA)
  genesis.rom_wr(0x0002AA, 0x0055)
  genesis.rom_wr(addr, 0x0030)

  if debug then
    log.point("erasing sector @ " .. help.hex_0x6(addr))
  end

  local temp = dict.sega("GEN_ROM_RD", addr)
  local nak = 1
  while (temp ~= dict.sega("GEN_ROM_RD", addr)) do
    temp = dict.sega("GEN_ROM_RD", addr)
    nak = nak + 1
  end
end

-- Compute Genesis checksum from a file, which can be compared with header value.
local function checksum_rom(filename)
  local sum = 0

  -- open file
  local file = assert(io.open(filename, "rb"))

  -- skip header
  local header = file:read(0x200)

  while true do
    -- add up remaining 16-bit words
    local bytes = file:read(2)
    if not bytes then break end
    sum = sum + string.unpack(">i2", bytes)
  end

  -- close file
  assert(file:close())

  -- only use the lower bits.
  return sum & 0xFFFF
end

-- Helper to extract fields in internal header.
local function extract_field_from_string(data, start_offset, length)
  -- 1 is added to Offset to handle lua strings being 1-based.
  return string.sub(data, start_offset + 1, start_offset + length)
end

-- Make a human-friendly text representation of ROM Size.
local function str_rom_size(rom_size_kb)
  local mbit = rom_size_kb / 128
  if mbit < 1 then
    mbit = "<1"
  end
  return "" .. rom_size_kb .. " kB (" .. mbit .. " mbit)"
end

-- Populates table with internal header contents from dumped data.
local function header_extract(header_data)
  -- https://plutiedev.com/rom-header
  -- https://en.wikibooks.org/wiki/Genesis_Programming#ROM_header

  -- TODO: Decode publisher from t-series in build field
  -- https://segaretro.org/Third-party_T-series_codes

  local header = {
    {
      name = "Console Name", -- System type
      address = 0x100,
      size = 16
    },
    {
      name = "Release Data", -- Copyright and release date
      address = 0x110,
      size = 16
    },
    {
      name = "Domestic Name", -- Game title (domestic)
      address = 0x120,
      size = 48
    },
    {
      name = "Overseas Name", -- Game title (overseas)
      address = 0x150,
      size = 48
    },
    {
      name = "Serial/Version", -- Serial number
      address = 0x180,
      size = 14
    },
    {
      name = "Checksum", -- ROM checksum
      address = 0x18E,
      size = 2
    },
    {
      name = "Device Support", -- Device support
      address = 0x190,
      size = 16
    },
    {
      name = "ROM Size", -- ROM address range
      address = 0x1A0,
      size = 8
    },
    {
      name = "SRAM Size", -- SRAM address range
      address = 0x1A8,
      size = 8
    },
    {
      name = "Extra Memory", -- Extra memory
      address = 0x1B0,
      size = 12
    },
    {
      name = "Modem Support", -- Modem support
      address = 0x1BC,
      size = 12
    },
    {
      name = "Reserved 1", -- Reserved 1
      address = 0x1C8,
      size = 40
    },
    {
      name = "Region Support", -- Region support
      address = 0x1F0,
      size = 3
    },
    {
      name = "Reserved 2", -- Reserved 2
      address = 0x1F3,
      size = 13
    },
  }

  for i, v in ipairs(header) do
    v.value = extract_field_from_string(header_data, v.address, v.size)

    -- ROM size / SRAM size
    if (v.address == 0x1A0 or v.address == 0x1A8) then
      local rom_start = string.unpack(">i4", string.sub(v.value, 1, 4))
      local rom_end   = string.unpack(">i4", string.sub(v.value, 5, 8))
      v.value         = math.floor((rom_end - rom_start + 1) / 1024)
      v.display_value = str_rom_size(v.value)
    end

    -- Checksum
    if (v.address == 0x18E) then
      v.value = string.unpack(">i2", v.value)
      v.display_value = hexfmt(v.value)
    end
  end

  return header
end

-- Prints parsed header contents to stdout.
local function print_header(genesis_header)
  log.info("#################### ROM HEADER")

  for i, v in ipairs(genesis_header) do
    if (v.display_value ~= nil) then
      log.info(v.name .. ":\t" .. v.display_value)
    else
      log.info(v.name .. ":\t" .. v.value)
    end
  end

  log.info("####################")
end

-- Reads and parses internal ROM header from first page of data.
local function header_read_from_file(filename)
  -- open file
  local file = assert(io.open(filename, "rb"))

  -- read 0x200 bytes
  local header_data = file:read(0x200)

  -- close file
  assert(file:close())

  -- check if valid
  if not header_data then
    print("Unable to read header from file" .. filename .. "...")
    return false
  end

  -- parse header
  local genesis_header = header_extract(header_data)

  return genesis_header
end

local function header_get_by_key(genesis_header, key)
  for i, v in ipairs(genesis_header) do
    help.dump_table(v)
    if (v.name == key) then
      return v
    end
  end
  return {}
end

local function header_defines_ram(genesis_header)
  local v = header_get_by_key(genesis_header, "Extra Memory")
  if v then
    if (string.sub(v.value, 1, 2) == "RA") then
      return true
    end
  end
  return false

  -- for i, v in ipairs(genesis_header) do
  --   if(v.name == "Extra Memory") then
  --     if(string.sub(v.value, 1, 2) == "RA") then
  --       return true
  --     end
  --   end
  -- end
  -- return false
end

-- Reads and parses internal ROM header from first page of data.
local function header_read_from_cart()
  dict.sega("GEN_SET_ADDR_HI", 0x00)

  local page0_data = ""
  dump.dumptocallback(
    function(data)
      page0_data = page0_data .. data
    end,
    64, 0x0000, "GENESIS_ROM_PAGE0", false
  )
  local header_data = string.sub(page0_data, 1, 0x201)
  local genesis_header = header_extract(header_data)
  local console_value = header_get_by_key(genesis_header, "Console Name").value
  genesis_header.valid = false
  if console_value == "SEGA GENESIS    " then genesis_header.valid = true end
  if console_value == "SEGA MEGA DRIVE " then genesis_header.valid = true end
  return genesis_header
end

-- Test that cartridge is readable by looking for valid entries in internal header.
local function rom_manf_id()
  local manufacturer_id
  local device_id
  local device_test

  -- compatible SST39VF / MX29
  -- compatible S29GL01GS / S29GL512S / S29GL256S / S29GL128S

  -- flash manf ID
  genesis.rom_wr(0x000555, 0x00AA)
  genesis.rom_wr(0x0002AA, 0x0055)
  genesis.rom_wr(0x000555, 0x0090)

  manufacturer_id = dict.sega("GEN_ROM_RD", 0x0000)
  chips.display_manufacturer(manufacturer_id)
  flash_chip = manufacturer_id

  device_id = dict.sega("GEN_ROM_RD", 0x000E)
  device_test = chips.display_device(manufacturer_id, device_id)

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

--[[
                         __
  _ __ __ _ _ __ ___    / _|_   _ _ __   ___ ___
 | '__/ _` | '_ ` _ \  | |_| | | | '_ \ / __/ __|
 | | | (_| | | | | | | |  _| |_| | | | | (__\__ \
 |_|  \__,_|_| |_| |_| |_|  \__,_|_| |_|\___|___/

--]]
-- dump the SEGA battery RAM starting at the provided bank
local function ram_dump(file, start_bank, ram_size_KB, debug)
  local KB_per_bank = 64 -- 128KByte addressable per bank, but only use lower byte of each 16bit word
  local addr_base = 0x00 -- A15-8 address of ram start
  local num_banks = math.floor((ram_size_KB * 2) / KB_per_bank)
  -- if(num_banks == 0) then num_banks = 1 end
  local cur_bank = 0

  log.info("SRAM size", ram_size_KB .. "KB")

  dict.sega("GEN_SET_RAM", 0x01) -- enable SRAM

  while cur_bank < num_banks do
    if debug then
      log.point("dumping bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    --select desired bank
    --A17-23
    dict.sega("GEN_SET_ADDR_HI", start_bank + cur_bank)

    --  if (mapping == lorom_name) then --LOROM sram is inside /ROMSEL space
    --    dump.dumptofile( file, KB_per_bank, addr_base, "SNESROM_PAGE", false )
    --  else -- HIROM is outside of /ROMSEL space
    --    dump.dumptofile( file, KB_per_bank, addr_base, "SNESSYS_PAGE", false )
    --  end
    --
    --currently don't have means of dumping RAM with A16 high
    --dump.dumptofile(file, KB_per_bank/2, addr_base, "GENESIS_RAM_PAGE", debug) --A16 low
    dump.dumptofile(file, 32, addr_base, "GENESIS_RAM_PAGE", false) --A16 low
    --    dump.dumptofile(file, KB_per_bank/2, addr_base, "GENESIS_ROM_PAGE1", debug) --A16 high

    cur_bank = cur_bank + 1
  end

  dict.sega("GEN_SET_RAM", 0x00) -- disable SRAM

  spinner.clear()
end

-- write to the WRAM, assumes the WRAM was enabled/disabled as desired prior to calling
local function ram_write(file, start_bank, ram_size_KB, debug)
  local KB_per_bank = 64 -- 128KByte addressable per bank, but only use lower byte of each 16bit word
  local addr_base = 0x00 -- A15-8 address of ram start
  local num_banks = math.floor((ram_size_KB * 2) / KB_per_bank)
  -- if(num_banks == 0) then num_banks = 1 end
  local cur_bank = 0

  log.section("Programming SRAM")
  log.info("SRAM size", ram_size_KB .. "KB")

  dict.sega("GEN_SET_RAM", 0x01) -- enable SRAM

  while cur_bank < num_banks do
    if debug then
      log.point("writing bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Writing", cur_bank, "/", num_banks - 1)
    end

    dict.sega("GEN_SET_ADDR_HI", start_bank + cur_bank)

    flash.write_file(file, ram_size_KB, mapname, "GENESISRAM", false)

    cur_bank = cur_bank + 1
  end

  dict.sega("GEN_SET_RAM", 0x00) -- disable SRAM

  spinner.clear()
  log.success("Done programming SRAM")
end

local function sram_exercise(ram_size, retroprog_id, debug)
  --[[
  SRAM covers the $200001-$20FFFF address range, and only every other byte is used (i.e. $200001, $200003, $200005, etc.).
  This gives you a total of 32KB to work with.
  If you need to save numbers larger than fit in a byte, split it into its separate bytes.
--]]

  dict.stuff("RESET_LFSR")       -- sets it to 1

  dict.sega("GEN_SET_RAM", 0x01) -- enable SRAM

  local addr_hi = 0x20 >> 1      -- A17-23 wayne gretsky RAM starts at bank $20 >> 1

  log.section("Exercising RAM")
  log.info("SRAM size", ram_size .. "KB")

  -- write random data to all banks
  log.point("Writing random data to SRAM")
  dict.sega("GEN_SET_ADDR_HI", addr_hi)
  dict.sega("GEN_PAGE_RAM_WR_LFSR", 0x00)

  --dump sram into file
  local filename = opts.lua_path .. "ignore/gen_sram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))
  log.point("Dumping SRAM")
  ram_dump(file, addr_hi, ram_size, false)

  dict.sega("GEN_SET_RAM", 0x00) -- disable SRAM

  -- close the file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "ignore/lfsr_32KB.bin"

  -- compare the flash file vs post dump file
  if files.compare(filename, goodfile, true) then
    log.success("SRAM test passed")
    return true
  else
    log.error("SRAM test failed")
    return false
  end
end

--[[
                         __
  _ __ ___  _ __ ___    / _|_   _ _ __   ___ ___
 | '__/ _ \| '_ ` _ \  | |_| | | | '_ \ / __/ __|
 | | | (_) | | | | | | |  _| |_| | | | | (__\__ \
 |_|  \___/|_| |_| |_| |_|  \__,_|_| |_|\___|___/

--]]

-- write a single byte to GENESIS ROM flash
local function wr_flash_byte(addr, value, debug)
  if (addr < 0x000000 or addr > 0x3FFFFF) then
    log.error("\n  ERROR! flash write to SEGA GENESIS", string.format("$%X", addr), "must be $0000-FFFF \n\n")
    return
  end

  local addr_hi = (addr >> 16) & 0xff
  local addr_lo = addr & 0xffff

  if debug then log.info("write a byte", help.hex(addr), help.hex(value)) end

  genesis.rom_wr(0x000555, 0x00AA)
  genesis.rom_wr(0x0002AA, 0x0055)
  genesis.rom_wr(0x000555, 0x00A0)
  genesis.rom_wr(addr, value)

  local rv = dict.sega("GEN_ROM_RD", addr_lo)

  local i = 0

  while (rv ~= value) do
    rv = dict.sega("GEN_ROM_RD", addr_lo)
    if debug then print("post write read:", help.hex(rv)) end
    i = i + 1
    if i > 30 then
      log.info("failed write, tried:", string.format("%X", value), "read back value:", string.format("%X", rv))
      return
    end
  end
  if debug then log.info(i, "naks, done writing byte.") end
  if debug then log.info("written value:", string.format("%X", value), "verified value:", string.format("%X", rv)) end

  --TODO handle timeout for problems

  --TODO return pass/fail/info
end

-- /ROMSEL (#C_CE) is always low for this dump
local function rom_dump(file, rom_size_KB, debug)
  -- we're dumping from 0x040000 which is second 512 kB / 256 kW bank ($080000-$0FFFFF)

  local KB_per_bank = 2 * 64 --2Bytes per address, 64K addresses
  local addr_base = 0x0000   -- control signals are manually controlled
  local num_banks = math.floor(rom_size_KB / KB_per_bank)
  local cur_bank = 0

  log.info("ROM size", rom_size_KB .. "KB")

  dict.sega("GEN_SET_RAM", 0x00) -- disable SRAM

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

    -- select desired bank
    dict.sega("GEN_TIME_WR", 0x0001, cur_bank >> 2)
    dict.sega("GEN_SET_ADDR_HI", 0x04 | (cur_bank & 0x03))
    -- dict.sega("GEN_SET_ADDR_HI", cur_bank)

    dump.dumptofile(file, KB_per_bank / 2, addr_base, "GENESIS_ROM_PAGE0", false)
    dump.dumptofile(file, KB_per_bank / 2, addr_base, "GENESIS_ROM_PAGE1", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

local function rom_write(file, rom_size_KB, debug)
  local KB_per_bank = 2 * 64 --2Bytes per address, 64K addresses
  local num_banks = math.floor(rom_size_KB / KB_per_bank)
  local cur_bank = 0

  log.section("Programming ROM")
  log.info("ROM size", rom_size_KB .. "KB")

  dict.sega("GEN_SET_RAM", 0x00) -- disable SRAM

  while cur_bank < num_banks do
    if debug then
      log.point("writing bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- select desired bank
    dict.sega("GEN_TIME_WR", 0x0001, cur_bank >> 2)
    dict.sega("GEN_SET_ADDR_HI", 0x04 | (cur_bank & 0x03))
    -- dict.sega("GEN_SET_ADDR_HI", cur_bank)

    -- -- select the current bank
    -- if (cur_bank <= 0x7F) then
    --   dict.sega("GEN_SET_ADDR_HI", cur_bank)
    -- else
    --   log.error("\n\nERROR!!!!  SEGA bank cannot exceed 0x7F, it was:", string.format("0x%X", cur_bank))
    --   return
    -- end

    flash.write_file(file, KB_per_bank, mapname, "GENESISROM", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
  log.success("Done programming ROM")
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

  -- process options
  local DEBUG = process_opts.debug
  local retroprog_id = process_opts.retroprog_id
  local do_test = process_opts.do_test
  local do_erase = process_opts.do_erase
  local do_rom_dump = process_opts.do_rom_dump
  local do_rom_write = process_opts.do_rom_write
  local do_verify = process_opts.do_verify
  local do_ram_dump = process_opts.do_ram_dump
  local do_ram_write = process_opts.do_ram_write
  local rom_write_file = process_opts.rom_write_file
  local verify_file = process_opts.verify_file
  local rom_dump_file = process_opts.rom_dump_file
  local ram_dump_file = process_opts.ram_dump_file
  local ram_write_file = process_opts.ram_write_file

  -- console options
  local rom_size = console_opts.rom_size_kb
  local ram_size = console_opts.wram_size_kb
  -- TODO: use specified ram size if provided, otherwise autodetect??

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
    log.section("Testing Rainbow")

    -- If garbage data is in the header, it's a waste of time trying to proceed doing anything else.
    -- local genesis_cart_header = header_read_from_cart()
    -- local valid_header = test_cart(genesis_cart_header)
    -- if valid_header ~= true then print("Unreadable cartridge - exiting! (Try cleaning cartridge connector?)") end
    -- assert(valid_header)
    -- print_header(genesis_cart_header)

    rv = rom_manf_id()
    if not rv then return false end

    -- parse header from flash file and from cart
    local genesis_flash_header = nil
    local genesis_cart_header = nil
    if (do_rom_write) then
      genesis_flash_header = header_read_from_file(rom_write_file.filename)
      if rom_size == nil or rom_size == 0 then
        rom_size = header_get_by_key(genesis_flash_header, "ROM Size").value
        log.warning("ROM size not passed, using file header value:",
          header_get_by_key(genesis_flash_header, "ROM Size").display_value)
      end
      -- if ram_size == nil or ram_size == 0 then
      --   ram_size = header_get_by_key(genesis_flash_header, "SRAM Size").value
      --   log.warning("SRAM size not passed, using file header value:", header_get_by_key(genesis_flash_header, "ROM Size").display_value)
      -- end
    elseif (do_rom_dump) then
      genesis_cart_header = header_read_from_cart()
      local valid_header = genesis_cart_header.valid
      if (valid_header == false) then
        log.warning("Unreadable cartridge! (Try cleaning cartridge connector?)")
        -- do return end
      end
      if rom_size == nil or rom_size == 0 then
        rom_size = header_get_by_key(genesis_cart_header, "ROM Size").value
        log.warning("ROM size not passed, using cart header value:",
          header_get_by_key(genesis_cart_header, "ROM Size").display_value)
      end
      -- if ram_size == nil or ram_size == 0 then
      --   ram_size = header_get_by_key(genesis_flash_header, "SRAM Size").value
      --   log.warning("SRAM size not passed, using file header value:", header_get_by_key(genesis_flash_header, "ROM Size").display_value)
      -- end
    end

    -- TODO...
    -- if(header_defines_ram(genesis_flash_header)) then
    -- test SRAM
    -- rv = sram_exercise(ram_size, retroprog_id, DEBUG)
    -- exit script if test fails
    -- if not rv then return end
    -- end
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
    local rambank = (0x20 >> 1) --A17-23 wayne gretsky RAM starts at bank $20>>1
    log.section("Dumping SRAM")
    time.start()
    ram_dump(file, rambank, ram_size, DEBUG)
    time.report(ram_size)
    log.success("SRAM dumping done")

    --may disable SRAM by placing /RESET low

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
    -- flash cart SRAM
    local rambank = (0x20 >> 1) --A17-23 wayne gretsky RAM starts at bank $20>>1
    time.start()
    ram_write(file, rambank, ram_size, DEBUG)
    time.report(rom_size)

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
    log.section("Dumping ROM")
    time.start()
    rom_dump(file, rom_size, DEBUG)
    time.report(rom_size)
    log.success("ROM dumping done")

    -- close file
    assert(file:close())

    -- parse header from dump file
    local genesis_dump_header = header_read_from_file(rom_dump_file.filename)

    log.point("Computing checksum...")
    local checksum = checksum_rom(rom_dump_file.filename)
    local checksum_control = header_get_by_key(genesis_dump_header, "Checksum").value

    if checksum == checksum_control then
      log.success("Checksum OK, dump verified")
    else
      log.error("Checksum mismatch, bad dump, try cleaning cartridge connector?")
      log.info("header:", help.hex_0x4(checksum_control), "computed:", help.hex_0x4(checksum_control))
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
    -- log.error("do_erase disabled")
    -- do return end
    local i = 0
    local temp
    local size_to_erase = rom_size

    log.section("Erasing ROM")

    time.start()
    if (flash_chip == 0x01) then -- Cypress / Spansion
      -- [[
      log.info("erasing only needed sectors because earsing full chip takes 4 min...")

      local sectors = math.floor(rom_size / 128)
      local addr
      size_to_erase = sectors * 128

      for i = 0, sectors - 1, 1 do
        addr = (i * 128 * 1024) >> 1
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
      log.warning("Erasing full flash chip can take up to 4 minutes...")
      dict.sega("GEN_SET_RAM", 0x00) -- disable SRAM
      genesis.rom_wr(0x000555, 0x00AA)
      genesis.rom_wr(0x0002AA, 0x0055)
      genesis.rom_wr(0x000555, 0x0080)
      genesis.rom_wr(0x000555, 0x00AA)
      genesis.rom_wr(0x0002AA, 0x0055)
      genesis.rom_wr(0x000555, 0x0010)

      local nak = 1
      temp = dict.sega("GEN_ROM_RD", 0x0000)
      while (temp ~= dict.sega("GEN_ROM_RD", 0x0000)) do
        temp = dict.sega("GEN_ROM_RD", 0x0000)
        nak = nak + 1
      end
      temp = dict.sega("GEN_ROM_RD", 0x0000)
      log.success("Done erasing ROM", nak .. " naks")
    end

    time.report(size_to_erase)
  end

  --[[
  88""Yb  dP"Yb  8b    d8     Yb        dP 88""Yb 88 888888 888888
  88__dP dP   Yb 88b  d88      Yb  db  dP  88__dP 88   88   88__
  88"Yb  Yb   dP 88YbdP88       YbdPYbdP   88"Yb  88   88   88""
  88  Yb  YbodP  88 YY 88        YP  YP    88  Yb 88   88   888888
  --]]

  -- program file to the cart
  if do_rom_write then
    --open file
    file = assert(io.open(rom_write_file.filename, "rb"))
    --determine if auto-doubling, deinterleaving, etc,
    --needs done to make board compatible with rom

    --local rom_size = console_opts["rom_size_kb"]
    --print("rom size:", rom_size)

    --flash cart
    time.start()
    rom_write(file, rom_size, DEBUG)
    time.report(rom_size)

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
    log.section("Dumping ROM")
    time.start()
    rom_dump(file, rom_size, DEBUG)
    time.report(rom_size)

    -- close file
    assert(file:close())

    -- parse header from dump file
    local genesis_verify_header = header_read_from_file(verify_file.filename)
    -- print_header(genesis_verify_header)

    log.point("Computing checksum...")
    local checksum = checksum_rom(verify_file.filename)
    local checksum_control = header_get_by_key(genesis_verify_header, "Checksum").value

    if checksum == checksum_control then
      log.success("Checksum OK, dump verified")
    else
      log.error("Checksum mismatch, bad dump, try cleaning cartridge connector?")
    end

    -- compare the flash file vs post dump file
    if (files.compare(verify_file.filename, rom_write_file.filename, true, true)) then
      log.success("Flash successfully verified")
    else
      log.error("Flash verification did not match")
    end
  end

  dict.io("IO_RESET")

  do return end



















  -- TODO: dump the ram to file
  if process_opts["dumpram"] then
    print("dumping save RAM")

    file = assert(io.open(ramdumpfile, "wb"))

    -- dump cart to file
    local rambank = (0x20 >> 1) --A17-23 wayne gretsky RAM starts at bank $20>>1

    time.start()
    ram_dump(file, rambank, ram_size, true)
    time.report(rom_size)

    --may disable SRAM by placing /RESET low

    -- close file
    assert(file:close())

    print("DONE Dumping SAVE RAM")
  end

  -- TODO: write to wram on the cart
  --if writeram then
  if process_opts["writeram"] then
    print("\nWriting to WRAM...")

    file = assert(io.open(process_opts["writeram_filename"], "rb"))
    --write_ram(file, ram_size_KB, debug)
    write_ram(file, ram_size, true)

    assert(file:close())

    print("DONE Writing WRAM")
  end

  dict.io("IO_RESET")
end


-- global variables so other modules can use them
--    NONE


-- call functions desired to run when script is called/imported
--    NONE

-- functions other modules are able to call
rainbow.process = process

-- return the module's table
return rainbow
