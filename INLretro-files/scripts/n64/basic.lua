-- create the module's table
local n64     = {}

-- import required modules
local dict    = require "scripts.app.dict"
local n64     = require "scripts.app.n64"
local dump    = require "scripts.app.dump"
local flash   = require "scripts.app.flash"
local chips   = require "scripts.app.chips"
local time    = require "scripts.app.time"
local log     = require "scripts.app.log"
local spinner = require "scripts.app.spinner"
local files   = require "scripts.app.files"
local help    = require "scripts.app.help"

-- file constants and global variables

-- local functions

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
  local KB_per_bank = 64   -- AD0-15 = 64K address space, A0 ignored so 1Byte per address!
  local addr_base = 0x0000 -- control signals are manually controlled
  local bank_base = 0x1000 -- N64 roms start at address 0x1000_0000
  local num_banks = math.floor(rom_size_KB / KB_per_bank)
  local cur_bank = 0
  --  local cur_bank = 512 --second half of RE2


  --[[
  dict.n64("N64_SET_BANK", bank_base + 0)
  dict.n64("N64_LATCH_ADDR", 0x0000)
  print("read: ", help.hex(dict.n64("N64_RD")))
  print("read: ", help.hex(dict.n64("N64_RD")))
  dict.n64("N64_SET_BANK", bank_base + 0)
  dict.n64("N64_LATCH_ADDR", 0x0000)
  dump.dumptofile( file, KB_per_bank, addr_base, "N64_ROM_PAGE", false )

  dict.n64("N64_LATCH_ADDR", 0x0000)
  print("read: ", help.hex(dict.n64("N64_RD")))
  print("read: ", help.hex(dict.n64("N64_RD")))
  dict.n64("N64_LATCH_ADDR", 0x0000)
  dump.dumptofile( file, KB_per_bank, addr_base, "N64_ROM_PAGE", false )
  --]]

  log.info("ROM size", rom_size_KB .. "KB")

  while cur_bank < num_banks do
    if debug then
      log.point("dumping bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- select desired bank
    dict.n64("N64_SET_BANK", bank_base + cur_bank)

    -- dump a 64KByte chunk of rom
    dump.dumptofile(file, KB_per_bank, addr_base, "N64_ROM_PAGE", debug)

    -- prob don't need this till done..
    dict.n64("N64_RELEASE_BUS")

    cur_bank = cur_bank + 1
  end

  spinner.clear()

  dict.n64("N64_RELEASE_BUS")
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

  -- initialize device i/o
  dict.io("IO_RESET")
  dict.io("N64_INIT")

  --[[
888888 888888 .dP"Y8 888888
  88   88__   `Ybo."   88
  88   88""   o.`Y8b   88
  88   888888 8bodP'   88
--]]

  -- test cart
  if do_test then
    log.section("Testing")

    -- --read rom header
    -- print("\nN64 attempt to read in rom header:")

    -- local bank_base = 0x1000  --N64 roms start at address 0x1000_0000
    -- dict.n64("N64_SET_BANK", bank_base + 0)

    -- local i = 0, rv

    -- local header = {}
    -- local header_start = 0x0020
    -- dict.n64("N64_LATCH_ADDR", header_start)

    -- local header_len = 32
    -- while i < header_len do

    --   rv = dict.n64("N64_RD")
    --   header[i+1] = rv>>8
    --   i = i+1
    --   header[i+1] = (rv & 0x00FF)
    --   i = i+1
    -- end

    -- i = 1
    -- while header[i] do
    --   io.write(string.char(header[i]))
    --   --io.write("B-",i,"=",header[i], " ")
    --   i = i+1
    -- end
    -- print("\n")


    --    print("Testing SNES board")
    --
    --    --SNES detect HiROM or LoROM & RAM
    --
    --    --SNES detect if able to read flash ID's
    --    if not rom_manf_id(true) then
    --      print("ERROR unable to read flash ID")
    --      return
    --    end
  end

  --dump the ram to file
  if dumpram then
    --    print("\nDumping SAVE RAM...")
    --
    --    --may have to verify /RESET is high to enable SRAM
    --
    --    file = assert(io.open(ramdumpfile, "wb"))
    --
    --    -- dump cart to file
    --    dump_ram(file, rambank, ram_size, snes_mapping, true)
    --
    --    --may disable SRAM by placing /RESET low
    --
    --    -- close file
    --    assert(file:close())
    --
    --    print("DONE Dumping SAVE RAM")
  end

  --dump the cart to dumpfile
  if do_rom_dump then
    -- open file
    file = assert(io.open(rom_dump_file.filename, "wb"))

    -- dump cart to file
    local image_name = ""
    if n64.rom_header.isValid then
      image_name = n64.rom_header.image_name
    end
    log.section("Dumping ROM", image_name)
    log.info("Ouput format is Big Endian (.z64 format)")

    time.start()
    rom_dump(file, rom_size, DEBUG)
    time.report(rom_size)

    log.success("ROM dumping done")

    -- close file
    assert(file:close())
  end

  -- erase the cart
  if erase then
    --  erase_flash()
  end

  --write to wram on the cart
  if writeram then
    --    print("\nwriting to SAVE RAM...")
    --
    --    file = assert(io.open(ramwritefile, "rb"))
    --
    --    --flash.write_file( file, ram_size, "NOVAR", "PRGRAM", false )
    --    --flash.write_file( file, ram_size, "LOROM_3VOLT", "SNESROM", false )
    --    wr_ram(file, rambank, ram_size, snes_mapping, true)
    --
    --    -- close file
    --    assert(file:close())
    --
    --    print("DONE writing SAVE RAM")
  end


  --program flashfile to the cart
  if program then
    --    --open file
    --    file = assert(io.open(flashfile, "rb"))
    --    --determine if auto-doubling, deinterleaving, etc,
    --    --needs done to make board compatible with rom
    --
    --    --flash cart
    --    flash_rom(file, rom_size, snes_mapping, true)
    --
    --    -- close file
    --    assert(file:close())
  end

  -- verify flash file is on the cart
  if verify then
    --    print("\nPost dumping SNES ROM...")
    --    --for now let's just dump the file and verify manually
    --
    --    file = assert(io.open(verifyfile, "wb"))
    --
    --    -- dump cart to file
    --    rom_dump(file, rom_size, false)
    --
    --    -- close file
    --    assert(file:close())
    --    print("DONE Post dumping SNES ROM")
  end

  dict.io("IO_RESET")
end


-- global variables so other modules can use them


-- call functions desired to run when script is called/imported


-- functions other modules are able to call
n64.process = process

-- return the module's table
return n64
