-- create the module's table
local genesis_32mb = {}

-- import required modules
local dict         = require "scripts.app.dict"
local genesis      = require "scripts.app.genesis"
local dump         = require "scripts.app.dump"
local flash        = require "scripts.app.flash"
local chips        = require "scripts.app.chips"
local time         = require "scripts.app.time"
local log          = require "scripts.app.log"
local spinner      = require "scripts.app.spinner"
local files        = require "scripts.app.files"
local help         = require "scripts.app.help"

-- file constants and global variables
local mapname      = "NOVAR"

--[[
███╗   ██╗ ██████╗ ████████╗███████╗███████╗
████╗  ██║██╔═══██╗╚══██╔══╝██╔════╝██╔════╝
██╔██╗ ██║██║   ██║   ██║   █████╗  ███████╗
██║╚██╗██║██║   ██║   ██║   ██╔══╝  ╚════██║
██║ ╚████║╚██████╔╝   ██║   ███████╗███████║
╚═╝  ╚═══╝ ╚═════╝    ╚═╝   ╚══════╝╚══════╝

--]]

-- genesis.dbg_rom_rd(0x000000 >> 1)  -- E1 00
-- genesis.dbg_rom_rd(0x000100 >> 1)  -- 53 45
-- genesis.dbg_rom_rd(0x000101 >> 1)  -- 53 45
-- genesis.dbg_rom_rd(0x212B75 >> 1)  -- FE C1 FF

-- print()
-- dict.sega("GEN_SET_RAM", 0x01)

-- genesis.dbg_ram_rd(0x200000 >> 1)  -- 2B
-- genesis.dbg_ram_rd(0x200002 >> 1)  -- 7B
-- genesis.dbg_ram_rd(0x200004 >> 1)  -- 3F
-- genesis.dbg_ram_rd(0x200006 >> 1)  -- E6

-- dict.sega("GEN_SET_RAM", 0x00)

-- local functions

--[[
███╗   ███╗██╗███████╗ ██████╗    ███████╗██╗   ██╗███╗   ██╗ ██████╗███████╗
████╗ ████║██║██╔════╝██╔════╝    ██╔════╝██║   ██║████╗  ██║██╔════╝██╔════╝
██╔████╔██║██║███████╗██║         █████╗  ██║   ██║██╔██╗ ██║██║     ███████╗
██║╚██╔╝██║██║╚════██║██║         ██╔══╝  ██║   ██║██║╚██╗██║██║     ╚════██║
██║ ╚═╝ ██║██║███████║╚██████╗    ██║     ╚██████╔╝██║ ╚████║╚██████╗███████║
╚═╝     ╚═╝╚═╝╚══════╝ ╚═════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚══════╝

--]]

local flash_chip

local function erase_sector(addr, debug)
  genesis.rom_wr(0x000555, 0x00AA)
  genesis.rom_wr(0x0002AA, 0x0055)
  genesis.rom_wr(0x000555, 0x0080)
  genesis.rom_wr(0x000555, 0x00AA)
  genesis.rom_wr(0x0002AA, 0x0055)
  genesis.rom_wr(addr, 0x0030)

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

  -- compatible SST39VF / MX29
  -- compatible S29GL01GS / S29GL512S / S29GL256S / S29GL128S

  -- flash manf ID
  genesis.rom_wr(0x000555, 0x00AA)
  genesis.rom_wr(0x0002AA, 0x0055)
  genesis.rom_wr(0x000555, 0x0090)

  manufacturer_id = dict.sega("GEN_ROM_RD", 0x0000)
  chips.display_manufacturer(manufacturer_id)
  flash_chip = manufacturer_id

  device_id = dict.sega("GEN_ROM_RD", 0x0001)
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

-- write a single byte to ROM flash
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

  genesis.rom_wr(0x000555, 0x00AA)
  genesis.rom_wr(0x0002AA, 0x0055)
  genesis.rom_wr(0x000555, 0x00A0)
  genesis.rom_wr(addr, value)

  local rv = dict.sega("GEN_ROM_RD", addr_lo)

  local i = 0

  while (rv ~= value) do
    rv = dict.sega("GEN_ROM_RD", addr_lo)
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

-- dump ROM
local function rom_dump(file, rom_size_KB, debug)
  local KB_per_bank = 128  -- A1-16 = 64K address space, 2Bytes per address
  local addr_base = 0x0000 -- control signals are manually controlled
  local num_banks = math.floor(rom_size_KB / KB_per_bank)
  local cur_bank = 0

  log.info("ROM size", rom_size_KB .. "KB")

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
    dict.sega("GEN_SET_ADDR_HI", cur_bank)

    dump.dumptofile(file, KB_per_bank / 2, addr_base, "GENESIS_ROM_PAGE0", false)
    dump.dumptofile(file, KB_per_bank / 2, addr_base, "GENESIS_ROM_PAGE1", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

-- host flash one bank at a time
local function rom_write(file, rom_size_KB, debug)
  local base_addr = 0x0000
  local bank_size = 2 * 64 --2Bytes per address, 64K addresses
  local buff_size = 1      --number of bytes to read from file at a time
  local cur_bank = 0

  local num_banks = math.floor(rom_size_KB / bank_size)

  log.section("Programming ROM")
  log.info("ROM size", rom_size_KB .. "KB")

  dict.sega("GEN_SET_RAM", 0x00) -- disable SRAM

  while cur_bank < num_banks do
    if debug then
      log.point("writing bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- select the current bank
    if (cur_bank <= 0x7F) then
      dict.sega("GEN_SET_ADDR_HI", cur_bank)
    else
      log.error("\n\nERROR!!!!  SEGA bank cannot exceed 0x7F, it was:", help.hex_0x2(cur_bank))
      return
    end

    flash.write_file(file, bank_size, mapname, "GENESISROM", false)

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
local function ram_dump(file, start_bank, ram_size_KB, debug)
  local KB_per_bank = 32 -- TODO: FIXME? => -- 128KByte addressable per bank, but only use lower byte of each 16bit word
  local num_banks = math.floor(ram_size_KB / KB_per_bank)
  local addr_base = 0x00 -- A15-8 address of ram start
  local cur_bank = 0

  log.info("SRAM size", ram_size_KB .. "KB")

  -- select desired bank
  -- A17-23
  dict.sega("GEN_SET_ADDR_HI", 0x20 >> 1) -- start_bank) -- + cur_bank)

  while cur_bank < num_banks do
    if debug then
      log.point("dumping RAM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- currently don't have means of dumping RAM with A16 high
    dump.dumptofile(file, ram_size_KB, addr_base, "GENESIS_RAM_PAGE", false) -- A16 low

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

-- host write one bank at a time
local function ram_write(file, start_bank, ram_size_KB, debug)
  local KB_per_bank = 32 -- 128KByte addressable per bank, but only use lower byte of each 16bit word
  local num_banks = math.floor(ram_size_KB / KB_per_bank)
  local cur_bank = 0

  log.section("Programming SRAM")
  log.info("SRAM size", ram_size_KB .. "KB")

  -- enable RAM
  dict.sega("GEN_SET_RAM", 0x01)

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

  -- disable SRAM
  dict.sega("GEN_SET_RAM", 0x00)

  spinner.clear()
  log.success("Done programming SRAM")
end

-- try to detect ram
local function ram_test(debug)
  local test = true
  local read_value
  local saved_value

  log.section("Detecting RAM")

  -- enable RAM
  dict.sega("GEN_SET_RAM", 0x01)

  -- save potential battery backed data first
  saved_value = genesis.ram_rd(0x200000 >> 1)

  -- try to write and read back
  genesis.ram_wr(0x200000 >> 1, saved_value ~ 0xff)
  read_value = genesis.ram_rd(0x200000 >> 1)
  if read_value ~= (saved_value ~ 0xff) then
    test = false
  end

  -- put back original value
  genesis.ram_wr(0x200000 >> 1, saved_value)
  read_value = genesis.ram_rd(0x200000 >> 1)
  if read_value ~= (saved_value) then
    test = false
  end

  -- disable RAM
  dict.sega("GEN_SET_RAM", 0x00)

  if test then
    log.success("RAM detected")
  else
    log.error("RAM not detected")
  end

  return test
end

local function ram_exercise(ram_size, retroprog_id, debug)
  --[[
  SRAM covers the $200001-$20FFFF address range, and only every other byte is used (i.e. $200001, $200003, $200005, etc.).
  This gives you a total of 32KB to work with.
  If you need to save numbers larger than fit in a byte, split it into its separate bytes.
--]]

  dict.stuff("RESET_LFSR") -- sets it to 1

  -- enable SRAM
  dict.sega("GEN_SET_RAM", 0x01)

  log.section("Exercising RAM")
  log.info("RAM size", ram_size .. "KB")

  -- write random data to all banks
  log.point("Writing random data to RAM")
  local addr_hi = 0x20 >> 1
  dict.sega("GEN_PAGE_RAM_WR_LFSR", 0x00)

  --dump sram into file
  local filename = opts.lua_path .. "ignore/gen_sram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))
  log.point("Dumping RAM")
  ram_dump(file, addr_hi, ram_size, debug)

  -- disable SRAM
  dict.sega("GEN_SET_RAM", 0x00)

  -- close the file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "ignore/lfsr_32KB.bin"

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
    log.section("Testing 32Mb") --.. mapname)

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
      local isHeaderValid = genesis.file_header.isValid or genesis.rom_header.isValid
      local hasBattery = genesis.file_header:has_battery() or genesis.rom_header:has_battery()
      if options.force_wram_test or isHeaderValid then
        if not options.force_wram_test and hasBattery then
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
    dict.sega("GEN_SET_RAM", 0x01)

    -- open file
    file = assert(io.open(ram_dump_file.filename, "wb"))

    -- dump cart to file
    local rambank = 0x20 >> 1 --A17-23 wayne gretsky RAM starts at bank $20>>1
    log.section("Dumping SRAM")
    time.start()
    ram_dump(file, rambank, ram_size, DEBUG)
    time.report(ram_size)
    log.success("SRAM dumping done")

    -- close file
    assert(file:close())

    -- disable RAM
    dict.sega("GEN_SET_RAM", 0x00)
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

  --[[
  88""Yb  dP"Yb  8b    d8     888888 88""Yb    db    .dP"Y8 888888
  88__dP dP   Yb 88b  d88     88__   88__dP   dPYb   `Ybo." 88__
  88"Yb  Yb   dP 88YbdP88     88""   88"Yb   dP__Yb  o.`Y8b 88""
  88  Yb  YbodP  88 YY 88     888888 88  Yb dP""""Yb 8bodP' 888888
  --]]

  -- erase the cart
  if do_erase then
    local i = 0

    -- erase ROM only if needed
    if rom_size ~= 0 then
      log.section("Erasing ROM")
      time.start()
      dict.sega("GEN_SET_RAM", 0x00) -- disable SRAM
      genesis.rom_wr(0x000555, 0x00AA)
      genesis.rom_wr(0x0002AA, 0x0055)
      genesis.rom_wr(0x000555, 0x0080)
      genesis.rom_wr(0x000555, 0x00AA)
      genesis.rom_wr(0x0002AA, 0x0055)
      genesis.rom_wr(0x000555, 0x0010)

      rv = dict.sega("GEN_ROM_RD", 0x0000)
      while (rv ~= dict.sega("GEN_ROM_RD", 0x0000)) do
        spinner.update("Erasing")
        rv = dict.sega("GEN_ROM_RD", 0x0000)
        i = i + 1
      end
      spinner.clear()
      log.success("Done erasing ROM", i .. " naks")
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

  -- verify flashed file on the cart
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

  dict.io("IO_RESET")
end

-- global variables so other modules can use them

-- call functions desired to run when script is called/imported

-- functions other modules are able to call
genesis_32mb.process = process

-- return the module's table
return genesis_32mb
