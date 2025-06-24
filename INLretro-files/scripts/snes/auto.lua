
-- create the module's table
local lorom = {}

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
local function prgm_mode(debug)
  if debug then print("going to program mode, swim:", snes_swimcart) end
  if snes_swimcart then
    print("ERROR cart got set to swim mode somehow!!!")
--    swim.snes_v3_prgm(debug)
  else
    dict.pinport("CTL_SET_LO", "SNES_RST")
  end
end

local function play_mode(debug)
  if debug then print("going to play mode, swim:", snes_swimcart) end
  if snes_swimcart then
--    swim.snes_v3_play(debug)
    print("ERROR cart got set to swim mode somehow!!!")
  else
    dict.pinport("CTL_SET_HI", "SNES_RST")
  end
end


--local function wr_flash_byte(addr, value, debug)

--base is the actual NES CPU address, not the rom offset (ie $FFF0, not $7FF0)
--local function wr_bank_table(base, entries)
--Action53 not susceptible to bus conflicts, no banktable needed



-- Desc: attempt to read flash rom ID
-- Pre: snes_init() been called to setup i/o
-- Post:Address left on bus memories disabled
-- Rtn: true if flash ID found
local function rom_manf_id( debug )

  local rv
  --enter software mode A11 is highest address bit that needs to be valid
  --datasheet not exactly explicit, A11 might not need to be valid
  --part has A-1 (negative 1) since it's in byte mode, meaning the part's A11 is actually A12
  --WR $AAA:AA $555:55 $AAA:AA
  dict.snes("SNES_SET_BANK", 0x00)

  --put cart in program mode
  --v3.0 boards don't use EXP0 for program mode, must use SWIM via CIC
--  prgm_mode()

  dict.snes("SNES_ROM_WR", 0x8AAA, 0xAA)
  dict.snes("SNES_ROM_WR", 0x8555, 0x55)
  dict.snes("SNES_ROM_WR", 0x8AAA, 0x90)

  --exit program mode
--  play_mode()

  --read manf ID
  local manf_id = dict.snes("SNES_ROM_RD", 0x8000) --0x01 Cypress Manf ID
  if debug then print("attempted read SNES ROM manf ID:", string.format("%X", manf_id)) end

  --read prod ID
  local prod_id = dict.snes("SNES_ROM_RD", 0x8002) --0x7E Prod ID S29GL
  if debug then print("attempted read SNES ROM prod ID:", string.format("%X", prod_id)) end

  local density_id = dict.snes("SNES_ROM_RD", 0x801C) --density 0x10=8MB 0x1A=4MB
  if debug then print("attempted read SNES density ID: ", string.format("%X", density_id)) end

  local boot_sect = dict.snes("SNES_ROM_RD", 0x801E) --boot sector 0x00=top 0x01=bottom
  if debug then print("attempted read SNES boot sect ID:", string.format("%X", boot_sect)) end

  --put cart in program mode
--  prgm_mode()

  -- exit software
  dict.snes("SNES_ROM_WR", 0x0000, 0xF0)

  --exit program mode
--  play_mode()

  --return true if detected flash chip
  if (manf_id == 0x01 and prod_id == 0x49) then
    print("2MB flash detected")
    return true
  elseif (manf_id == 0x01 and prod_id == 0x7E) then
    print("4-8MB flash detected")
    return true
  else
    return false
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

-- dump ROM
local function rom_dump(file, rom_size_KB, debug)

  -- /ROMSEL is always low for this dump

  local KB_per_bank
  local addr_base

  if mapname == "LOROM" then
    KB_per_bank = 32  -- LOROM has 32KB per bank
    addr_base = 0x80  -- LOROM data starts at $8000
  elseif mapname == "HIROM" then
    KB_per_bank = 64  -- HIROM has 64KB per bank
    addr_base = 0x00  -- HIROM data starts at $0000
  else
    log.error("Mapper unknown:", mapname)
    do return end
  end

  local num_banks = math.floor(rom_size_KB / KB_per_bank)
  local cur_bank = 0

  log.info("ROM size", rom_size_KB .. "KB")

  while cur_bank < num_banks do

    if debug then
      log.point("dumping bank", cur_bank, "of", num_banks-1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks-1)
    end

    --select desired bank
    dict.snes("SNES_SET_BANK", cur_bank) -- start_bank+cur_bank)

    dump.dumptofile(file, KB_per_bank, addr_base, "SNESROM_PAGE", false)

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
  local rv = nil
  local file

  -- process options
  local DEBUG           = process_opts.debug
  local retroprog_id    = process_opts.retroprog_id
  local do_test         = process_opts.do_test
  local do_erase        = process_opts.do_erase
  local do_rom_write    = process_opts.do_rom_write
  local do_verify       = process_opts.do_verify
  local do_rom_dump     = process_opts.do_rom_dump
  local do_ram_dump     = process_opts.do_ram_dump
  local do_ram_write    = process_opts.do_ram_write
  local rom_write_file  = process_opts.rom_write_file
  local verify_file     = process_opts.verify_file
  local rom_dump_file   = process_opts.rom_dump_file
  local ram_dump_file   = process_opts.ram_dump_file
  local ram_write_file  = process_opts.ram_write_file
  local options         = process_opts.additional_opts

  -- console options
  local rom_size        = console_opts.rom_size_kb
  local ram_size        = console_opts.wram_size_kb

  -- initialize device i/o
  dict.io("IO_RESET")
  dict.io("SNES_INIT")

  if snes.rom_header.rom_type.mode == 0 then
    mapname = "LOROM"
  elseif snes.rom_header.rom_type.mode == 1 then
    mapname = "HIROM"
  end

--[[
888888 888888 .dP"Y8 888888
  88   88__   `Ybo."   88
  88   88""   o.`Y8b   88
  88   888888 8bodP'   88
--]]

  -- test cart
  if do_test then

    log.section("Testing", mapname)

    --SNES detect HiROM or LoROM
    --nes.detect_mapper_mirroring(true)
    --SNES detect if there's save ram and size

    -- attempt to read ROM flash ID
    if do_rom_write and rom_size ~= 0 then
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

    --quick lame check to see if chip erased
    --[[
    if snes.read_reset_vector(0, true) ~= 0xFFFF then
      erase.erase_snes( false )
    end
    if snes.read_reset_vector( 1, true) ~= 0xFFFF then
      erase.erase_snes( false )
    end
    if snes.read_reset_vector( 20, true) ~= 0xFFFF then
      erase.erase_snes( false )
    end
    if snes.read_reset_vector( 63, true) ~= 0xFFFF then
      erase.erase_snes( false )
    end
    --]]

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
    local cartridge_title = ""
    if snes.rom_header.isValid then
      cartridge_title = snes.rom_header.cartridge_title
    end
    log.section("Dumping ROM", cartridge_title)

    time.start()
    rom_dump(file, rom_size, DEBUG)
    time.report(rom_size)
    log.success("ROM dumping done")

    -- close file
    assert(file:close())

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

-- erase the cart
  if do_erase then

    print("\nerasing tsop takes ~30sec")

    local rv = nil

    --WR $AAA:AA $555:55 $AAA:AA
    dict.snes("SNES_SET_BANK", 0x00)

    --put cart in program mode
--    snes.prgm_mode()

    dict.snes("SNES_ROM_WR", 0x8AAA, 0xAA)
    dict.snes("SNES_ROM_WR", 0x8555, 0x55)
    dict.snes("SNES_ROM_WR", 0x8AAA, 0x80)
    dict.snes("SNES_ROM_WR", 0x8AAA, 0xAA)
    dict.snes("SNES_ROM_WR", 0x8555, 0x55)
    dict.snes("SNES_ROM_WR", 0x8AAA, 0x10)

    --exit program mode
--    snes.play_mode()

    rv = dict.snes("SNES_ROM_RD", 0x8000)

    local i = 0

    while ( rv ~= 0xFF ) do
      rv = dict.snes("SNES_ROM_RD", 0x8000)
      i = i + 1
--      if debug then print(" ", i,":", string.format("%x",rv)) end
    end
    print(i, "naks, done erasing snes.")

    --put cart in program mode
--    swim.start()
--    snes.prgm_mode()

    --reset flash
    dict.snes("SNES_ROM_WR", 0x8000, 0xF0)

    --return to PLAY mode
--    print("erase play")
--    snes.play_mode()
--    print("erase play")



  end


--program flashfile to the cart
  if do_rom_write then

    --initialize the mapper for dumping
    --init_mapper(debug)

    --open file
    file = assert(io.open(rom_write_file.filename, "rb"))
    --determine if auto-doubling, deinterleaving, etc,
    --needs done to make board compatible with rom

    --not susceptible to bus conflicts

    --flash cart
    flash.write_file( file, rom_size, mapname, "SNESROM", true )
    -- close file
    assert(file:close())

  end

-- verify flash file is on the cart
  if do_verify then
    --for now let's just dump the file and verify manually

    file = assert(io.open(verify_file.filename, "wb"))

    -- dump cart to file
    dump.dumptofile( file, rom_size, mapname, "SNESROM", true )

    -- close file
    assert(file:close())
  end

  dict.io("IO_RESET")
end

-- global variables so other modules can use them

-- call functions desired to run when script is called/imported

-- functions other modules are able to call
lorom.process = process

-- return the module's table
return lorom
