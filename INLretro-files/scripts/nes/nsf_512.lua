-- create the module's table
local nsf_512 = {}

-- import required modules
local dict    = require "scripts.app.dict"
local nes     = require "scripts.app.nes"
local dump    = require "scripts.app.dump"
local flash   = require "scripts.app.flash"
local chips   = require "scripts.app.chips"
local time    = require "scripts.app.time"
local log     = require "scripts.app.log"
local spinner = require "scripts.app.spinner"
local files   = require "scripts.app.files"
local help    = require "scripts.app.help"

-- file constants and global variables
local mapname = "EZNSF"

-- local functions

--[[
███╗   ███╗██╗███████╗ ██████╗    ███████╗██╗   ██╗███╗   ██╗ ██████╗███████╗
████╗ ████║██║██╔════╝██╔════╝    ██╔════╝██║   ██║████╗  ██║██╔════╝██╔════╝
██╔████╔██║██║███████╗██║         █████╗  ██║   ██║██╔██╗ ██║██║     ███████╗
██║╚██╔╝██║██║╚════██║██║         ██╔══╝  ██║   ██║██║╚██╗██║██║     ╚════██║
██║ ╚═╝ ██║██║███████║╚██████╗    ██║     ╚██████╔╝██║ ╚████║╚██████╗███████║
╚═╝     ╚═╝╚═╝╚══════╝ ╚═════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚══════╝

--]]

local function create_header(file, prg_kb, chr_kb)
  local mirroring = nes.detect_mapper_mirroring()
  nes.write_header(file, prg_kb, 0, op_buffer[mapname], mirroring)
end


--local function wr_flash_byte(addr, value, debug)

--base is the actual NES CPU address, not the rom offset (ie $FFF0, not $7FF0)
--local function wr_bank_table(base, entries)
--Action53 not susceptible to bus conflicts, no banktable needed



--initialize mapper for dump/flash routines
local function init_mapper(debug)
  --rom A11-0 are directly connected to CPU
  --A12 pin is part of sector address
  --in BYTE mode, pin A12 is actually CPU A13
  --so ROM A11 must be valid for flash commands
  --ROM A11 pin is actually CPU A12
  --A12 is actually controlled my mapper register...
  --So it should need to be initialized to work, but flash ID is responding properly without it..
  --Therefore I don't think rom A11 pin (CPU A12) needs to be valid, just A11-0?

  --       15 14 13 12
  -- $8000  1  0  0  0 0000 0000 0000
  -- $9000  1  0  0  1 0000 0000 0000
  -- $A000  1  0  1  0 0000 0000 0000 => banks 2, 6, A, E, ... => $AAAA
  -- $D000  1  1  0  0 0000 0000 0000 => banks 1, 3, 5, 7, 9, B, D, F, ... => $D555

  --dict.nes("NES_CPU_WR", 0x5000, 0x00) -- $8000
  --dict.nes("NES_CPU_WR", 0x5001, 0x00) -- $9000
  dict.nes("NES_CPU_WR", 0x5002, 0x0A) -- $A000
  --dict.nes("NES_CPU_WR", 0x5003, 0x00) -- $B000
  --dict.nes("NES_CPU_WR", 0x5004, 0x00) -- $C000
  dict.nes("NES_CPU_WR", 0x5005, 0x05) -- $D000
  --dict.nes("NES_CPU_WR", 0x5006, 0x00) -- $E000
  --dict.nes("NES_CPU_WR", 0x5007, 0x00) -- $F000

  --flash /WE signal only goes low for $9000-9FFF
end


--[[
██████╗ ██████╗  ██████╗       ██████╗  ██████╗ ███╗   ███╗
██╔══██╗██╔══██╗██╔════╝       ██╔══██╗██╔═══██╗████╗ ████║
██████╔╝██████╔╝██║  ███╗█████╗██████╔╝██║   ██║██╔████╔██║
██╔═══╝ ██╔══██╗██║   ██║╚════╝██╔══██╗██║   ██║██║╚██╔╝██║
██║     ██║  ██║╚██████╔╝      ██║  ██║╚██████╔╝██║ ╚═╝ ██║
╚═╝     ╚═╝  ╚═╝ ╚═════╝       ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝

--]]

-- read PRG-ROM flash ID
local function prg_rom_manf_id()
  local manufacturer_id
  local device_id
  local device_test

  init_mapper()

  log.section("Reading PRG-ROM manufacturer/device ID")

  dict.nes("NES_CPU_WR", 0xD555, 0xAA)
  dict.nes("NES_CPU_WR", 0xAAAA, 0x55)
  dict.nes("NES_CPU_WR", 0xD555, 0x90)

  manufacturer_id = dict.nes("NES_CPU_RD", 0x8000)
  chips.display_manufacturer(manufacturer_id)

  device_id = dict.nes("NES_CPU_RD", 0x8001)
  device_test = chips.display_device(manufacturer_id, device_id)

  -- exit software
  dict.nes("NES_CPU_WR", 0x8000, 0xF0)

  if device_test == false then
    return false
  else
    return true
  end
end



-- dump PRG-ROM
local function prg_rom_dump(file, rom_size_KB, debug)
  -- PRG-ROM dump 4KB at a time through MMC3 reg6&7 in mode 0
  local KB_per_read = 4
  local num_banks = math.floor(rom_size_KB / KB_per_read)
  local cur_bank = 0
  local addr_base = 0x80 -- $8000

  log.info("PRG-ROM size", rom_size_KB .. "KB")

  while cur_bank < num_banks do
    if debug then
      log.point("dumping PRG bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    --select desired bank(s) to dump
    dict.nes("NES_CPU_WR", 0x5000, cur_bank) --4KB @ CPU $8000

    dump.dumptofile(file, KB_per_read, addr_base, "NESCPU_PAGE", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

-- host flash one bank at a time
local function prg_rom_flash(file, rom_size_KB, debug)
  init_mapper()

  log.section("Programming PRG-ROM")
  log.info("PRG-ROM size", rom_size_KB .. "KB")

  local bank_size = 4
  local cur_bank = 0
  local num_banks = math.floor(rom_size_KB / bank_size)

  while cur_bank < num_banks do
    if debug then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    --write the current bank to the mapper register
    dict.nes("NES_CPU_WR", 0x5000, cur_bank) --bank at $8000

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size, "MMC3", "PRGROM", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
  log.success("Done programming PRG-ROM")
end


--[[
 ██████╗██╗  ██╗██████╗       ██████╗  █████╗ ███╗   ███╗
██╔════╝██║  ██║██╔══██╗      ██╔══██╗██╔══██╗████╗ ████║
██║     ███████║██████╔╝█████╗██████╔╝███████║██╔████╔██║
██║     ██╔══██║██╔══██╗╚════╝██╔══██╗██╔══██║██║╚██╔╝██║
╚██████╗██║  ██║██║  ██║      ██║  ██║██║  ██║██║ ╚═╝ ██║
 ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝      ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝

--]]

-- dump CHR
local function chr_dump(file, rom_size_KB, debug)
  local KB_per_read = 8
  local num_banks = math.floor(rom_size_KB / KB_per_read)
  local cur_bank = 0
  local addr_base = 0x00 -- $0000

  log.info("CHR size", rom_size_KB .. "KB")

  if debug then
    log.point("dump CHR bank", cur_bank, "of", num_banks - 1)
  else
    spinner.update("Dumping", cur_bank, "/", num_banks - 1)
  end

  dump.dumptofile(file, KB_per_read, addr_base, "NESPPU_1KB_TOGGLE", false)

  spinner.clear()
end

local function chr_ram_exercise(chrram_size, retroprog_id, debug)
  dict.stuff("RESET_LFSR") -- sets it to 1
  -- dict.stuff("SET_LFSR_L", 0) --lock it up to clear ram
  -- dict.stuff("SET_LFSR_L", 2) --give different seed for testing fails

  local cur_bank = 0
  local num_banks = math.floor(chrram_size / 8)

  log.section("Exercising CHR-RAM")
  log.info("CHR-RAM size\t" .. chrram_size .. "KB")

  -- write random data to all banks
  log.point("Writing random data to CHR-RAM")
  if debug then log.point("init CHR-RAM 8K bank\t" .. cur_bank .. "\tof\t" .. num_banks - 1) end
  local addr = 0x0000
  while addr < 0x2000 do
    dict.nes("PPU_PAGE_WR_LFSR", addr)
    addr = addr + 256
  end

  -- dump CHR-RAM
  local filename = opts.lua_path .. "./ignore/nes_chr_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))
  log.point("Dumping CHR-RAM")
  chr_dump(file, chrram_size, debug)

  -- close the file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "./ignore/lfsr_32KB.bin"

  -- compare the flash file vs post dump file
  if files.compare(filename, goodfile, false) then
    log.success("CHR-RAM test passed")
    return true
  else
    log.error("CHR-RAM test failed")
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
  local rv               = nil
  local file
  local chr_ram_detected = false
  local chr_ram_size     = 0

  -- process options
  local DEBUG            = process_opts.debug
  local retroprog_id     = process_opts.retroprog_id
  local do_test          = process_opts.do_test
  local do_erase         = process_opts.do_erase
  local do_rom_write     = process_opts.do_rom_write
  local do_verify        = process_opts.do_verify
  local do_rom_dump      = process_opts.do_rom_dump
  local do_ram_dump      = process_opts.do_ram_dump
  local do_ram_write     = process_opts.do_ram_write
  local nes_file         = process_opts.nes_file
  local rom_write_file   = process_opts.rom_write_file
  local verify_file      = process_opts.verify_file
  local rom_dump_file    = process_opts.rom_dump_file
  local ram_dump_file    = process_opts.ram_dump_file
  local ram_write_file   = process_opts.ram_write_file
  local options          = process_opts.additional_opts

  -- console options
  local prg_size         = console_opts.prg_rom_size_kb
  local chr_size         = console_opts.chr_rom_size_kb
  local wram_size        = console_opts.wram_size_kb

  -- Initialize device i/o
  dict.io("IO_RESET")
  dict.io("NES_INIT")

  --[[
  888888 888888 .dP"Y8 888888
    88   88__   `Ybo."   88
    88   88""   o.`Y8b   88
    88   888888 8bodP'   88
  --]]

  -- test cart
  if do_test then
    log.section("Testing ", mapname)

    -- attempt to read PRG-ROM flash ID
    if options.force_flash_test or (do_rom_write and prg_size ~= 0) then
      rv = prg_rom_manf_id()
      if not rv then
        if do_rom_write then
          log.error("Couldn't identify flash chip")
          return false
        else
          log.warning("Couldn't identify flash chip")
        end
      end
    end

    -- force CHR-RAM size to 8KB
    chr_ram_detected = nes.ppu_ram_sense(0x1000)
    if not chr_ram_detected then
      log.error("CHR-RAM not detected")
      return
    end
    chr_ram_size = 8

    -- test CHR-RAM
    rv = chr_ram_exercise(chr_ram_size, retroprog_id, DEBUG)
    -- exit script if test fails
    if not rv then return end
  end


  --[[
  88""Yb  dP"Yb  8b    d8     8888b.  88   88 8b    d8 88""Yb
  88__dP dP   Yb 88b  d88      8I  Yb 88   88 88b  d88 88__dP
  88"Yb  Yb   dP 88YbdP88      8I  dY Y8   8P 88YbdP88 88"""
  88  Yb  YbodP  88 YY 88     8888Y"  `YbodP' 88 YY 88 88
  --]]

  -- dump cart ROM to file
  if do_rom_dump then
    init_mapper()

    -- open file
    file = assert(io.open(rom_dump_file.filename, "wb"))

    --create header: pass open & empty file & rom sizes
    if rom_dump_file.ext == "nes" then
      --create header: pass open & empty file & rom sizes
      create_header(file, prg_size, chr_size)
    end

    -- dump cart to file
    if prg_size ~= 0 then
      log.section("Dumping PRG-ROM")
      time.start()
      prg_rom_dump(file, prg_size, DEBUG)
      time.report(prg_size)
      log.success("PRG-ROM dumping done")
    end

    -- if chr_size ~= 0 then
    --   log.section("Dumping CHR-ROM")
    --   time.start()
    --   chr_dump(file, chr_size, DEBUG)
    --   time.report(chr_size)
    --   log.success("CHR-ROM dumping done")
    -- end

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
    local i = 0

    -- erase PRG-ROM only if needed
    if prg_size ~= 0 then
      init_mapper()
      log.section("Erasing PRG-ROM")
      time.start()
      dict.nes("NES_CPU_WR", 0xD555, 0xAA)
      dict.nes("NES_CPU_WR", 0xAAAA, 0x55)
      dict.nes("NES_CPU_WR", 0xD555, 0x80)
      dict.nes("NES_CPU_WR", 0xD555, 0xAA)
      dict.nes("NES_CPU_WR", 0xAAAA, 0x55)
      dict.nes("NES_CPU_WR", 0xD555, 0x10)

      -- TODO create some function to pass the read value
      -- that's smart enough to figure out if the board is actually erasing or not
      rv = dict.nes("NES_CPU_RD", 0x8000)
      while rv ~= dict.nes("NES_CPU_RD", 0x8000) do
        spinner.update("Erasing")
        rv = dict.nes("NES_CPU_RD", 0x8000)
        i = i + 1
      end
      spinner.clear()
      log.success("Done erasing PRG-ROM", i .. " naks")
      time.report(prg_size)
    end

    -- -- erase CHR-ROM only if needed
    -- if chr_size ~= 0 then
    --   init_mapper()

    --   log.section("Erasing CHR-ROM")
    --   time.start()
    --   dict.nes("NES_PPU_WR", 0x1555, 0xAA)
    --   dict.nes("NES_PPU_WR", 0x1AAA, 0x55)
    --   dict.nes("NES_PPU_WR", 0x1555, 0x80)
    --   dict.nes("NES_PPU_WR", 0x1555, 0xAA)
    --   dict.nes("NES_PPU_WR", 0x1AAA, 0x55)
    --   dict.nes("NES_PPU_WR", 0x1555, 0x10)

    --   -- TODO create some function to pass the read value
    --   -- that's smart enough to figure out if the board is actually erasing or not
    --   i = 0
    --   rv = dict.nes("NES_PPU_RD", 0x0000)
    --   while rv ~= dict.nes("NES_PPU_RD", 0x0000) do
    --     spinner.update("Erasing")
    --     rv = dict.nes("NES_PPU_RD", 0x0000)
    --     i = i + 1
    --   end
    --   spinner.clear()
    --   log.success("Done erasing CHR-ROM", i .. " naks")
    --   time.report(chr_size)
    -- end
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
    if prg_size ~= 0 then
      time.start()
      prg_rom_flash(file, prg_size, DEBUG)
      time.report(prg_size)
    end

    -- if chr_size ~= 0 then
    --   time.start()
    --   chr_rom_flash(file, chr_size, DEBUG)
    --   time.report(chr_size)
    -- end

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
    init_mapper()

    -- open file
    file = assert(io.open(verify_file.filename, "wb"))

    -- dump cart to file
    if prg_size ~= 0 then
      log.section("Dumping PRG-ROM")
      time.start()
      prg_rom_dump(file, prg_size, DEBUG)
      time.report(prg_size)
      log.success("PRG-ROM dumping done")
    end

    -- if chr_size ~= 0 then
    --   log.section("Dumping CHR-ROM")
    --   time.start()
    --   chr_dump(file, chr_size, DEBUG)
    --   time.report(chr_size)
    --   log.success("CHR-ROM dumping done")
    -- end

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

--   -----------------------------------------
--   -----------------------------------------
--   -----------------------------------------
--   -----------------------------------------
--   -----------------------------------------
--   -----------------------------------------
--   -----------------------------------------
--   -----------------------------------------
--   -----------------------------------------

--   -- --dump the cart to dumpfile
--   -- if read then
--   --   print("\nDumping PRG-ROM...")

--   --   --initialize the mapper for dumping
--   --   init_mapper(debug)

--   --   file = assert(io.open(dumpfile, "wb"))

--   --   --create header: pass open & empty file & rom sizes
--   --   create_header(file, prg_size, chr_size)

--   --   -- dump cart to file
--   --   time.start()
--   --   dump_prgrom(file, prg_size, false)
--   --   time.report(prg_size)

--   --   -- close file
--   --   assert(file:close())
--   --   print("DONE Dumping PRG-ROM")
--   -- end

--   -- -- erase the cart
--   -- if erase then
--   --   --initialize the mapper for erasing
--   --   init_mapper(debug)

--   --   print("erasing PRG-ROM")
--   --   --A0-A14 are all directly addressable in CNROM mode
--   --   --only A0-A11 are required to be valid for tsop-48
--   --   --and mapper writes don't affect PRG banking
--   --   dict.nes("NES_CPU_WR", 0xD555, 0xAA)
--   --   dict.nes("NES_CPU_WR", 0xAAAA, 0x55)
--   --   dict.nes("NES_CPU_WR", 0xD555, 0x80)
--   --   dict.nes("NES_CPU_WR", 0xD555, 0xAA)
--   --   dict.nes("NES_CPU_WR", 0xAAAA, 0x55)
--   --   dict.nes("NES_CPU_WR", 0xD555, 0x10)
--   --   rv = dict.nes("NES_CPU_RD", 0x8000)

--   --   local i = 0

--   --   -- TODO create some function to pass the read value
--   --   -- that's smart enough to figure out if the board is actually erasing or not
--   --   while (rv ~= 0xFF) do
--   --     rv = dict.nes("NES_CPU_RD", 0x8000)
--   --     i = i + 1
--   --   end
--   --   print(i, "naks, done erasing prg.")
--   -- end

--   --program flashfile to the cart
--   if program then
--     --open file
--     file = assert(io.open(flashfile, "rb"))
--     --determine if auto-doubling, deinterleaving, etc,
--     --needs done to make board compatible with rom

--     if flash_filetype == "nes" then
--       --advance past the 16byte header
--       file:read(16)
--     end

--     flash_prgrom(file, prg_size, false)
--     --if chr_size ~= 0 then
--     --  flash_chrrom(file, chr_size, true)
--     --end

--     -- close file
--     assert(file:close())
--   end

--   -- verify flash file is on the cart
--   if verify then
--     --for now let's just dump the file and verify manually
--     print("\nPost dumping PRG & CHR ROMs...")

--     init_mapper()

--     file = assert(io.open(verifyfile, "wb"))

--     if verify_filetype == "nes" then
--       --create header: pass open & empty file & rom sizes
--       create_header(file, prg_size, chr_size)
--     end

--     print("DONE post dumping PRG & CHR ROMs")
--     -- dump cart to file
--     time.start()
--     dump_prgrom(file, prg_size, false)
--     if chr_size ~= 0 then
--       dump_chrrom(file, chr_size, false)
--     end
--     time.report(prg_size + chr_size)

--     -- close file
--     assert(file:close())

--     -- compare the flash file vs post dump file
--     local offset
--     if flash_filetype == "nes" then offset = 16 else offset = false end
--     if (files.compare(verifyfile, flashfile, true, false, offset)) then
--       print("\nSUCCESS! Flash verified")
--     else
--       print("\n\n\n FAILURE! Flash verification did not match")
--     end
--   end

--   dict.io("IO_RESET")
-- end


-- global variables so other modules can use them


-- call functions desired to run when script is called/imported


-- functions other modules are able to call
nsf_512.process = process

-- return the module's table
return nsf_512
