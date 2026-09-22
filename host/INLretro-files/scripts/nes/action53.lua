-- create the module's table
local action53        = {}

-- import required modules
local dict            = require "scripts.app.dict"
local nes             = require "scripts.app.nes"
local dump            = require "scripts.app.dump"
local flash           = require "scripts.app.flash"
local time            = require "scripts.app.time"
local log             = require "scripts.app.log"
local spinner         = require "scripts.app.spinner"
local files           = require "scripts.app.files"
local help            = require "scripts.app.help"

-- file constants and global variables
local mapname         = "A53"
local prg_flash_chip

-- registers
local REGISTER_SELECT = 0x5000
local CHR_BANK        = 0x00
local INNER_BANK      = 0x01
local MODE            = 0x80
local OUTER_BANK      = 0x81
local REGISTER_VALUE  = 0x8000

-- local functions

--[[
██╗  ██╗███████╗██╗     ██████╗ ███████╗██████╗ ███████╗
██║  ██║██╔════╝██║     ██╔══██╗██╔════╝██╔══██╗██╔════╝
███████║█████╗  ██║     ██████╔╝█████╗  ██████╔╝███████╗
██╔══██║██╔══╝  ██║     ██╔═══╝ ██╔══╝  ██╔══██╗╚════██║
██║  ██║███████╗███████╗██║     ███████╗██║  ██║███████║
╚═╝  ╚═╝╚══════╝╚══════╝╚═╝     ╚══════╝╚═╝  ╚═╝╚══════╝

--]]

-- initialize mapper for dump/flash routines
local function init_mapper()
  -- //Setup as CNROM, then scroll through outer banks.
  -- cpu_wr(0x5000, 0x80);   //reg select mode
  nes.cpu_wr(REGISTER_SELECT, MODE)

  -- //   xxSSPPMM   SS-size: 0-32KB, PP-prg mode: 0,1 32KB, MM-mirror
  -- cpu_wr(0x8000, 0b00000000);     //reg value 256KB inner, 32KB banks
  nes.cpu_wr(REGISTER_VALUE, 0x00)
  -- cpu_wr(0x5000, 0x81);   //outer reg select mode
  nes.cpu_wr(REGISTER_SELECT, OUTER_BANK)
  -- cpu_wr(0x8000, 0x00);   //first 32KB bank
  nes.cpu_wr(REGISTER_VALUE, 0x00)

  -- cpu_wr(0x5000, 0x01);   //inner prg reg select
  nes.cpu_wr(REGISTER_SELECT, INNER_BANK)
  -- cpu_wr(0x8000, 0x00);   //controls nothing in this size
  nes.cpu_wr(REGISTER_VALUE, 0x00)
  -- cpu_wr(0x5000, 0x00);   //chr reg select
  nes.cpu_wr(REGISTER_SELECT, CHR_BANK)
  -- cpu_wr(0x8000, 0x00);   //first chr bank
  nes.cpu_wr(REGISTER_VALUE, 0x00)
end

local function create_header(file, prg_kb, chr_kb)
  -- write_header(file, prg_kb, chr_kb, mapper, mirroring)
  nes.write_header(file, prg_kb, chr_kb, op_buffer[mapname], 0)
end

-- test the mapper's mirroring modes to verify working properly
-- can be used to help identify board: returns true if pass, false if failed
local function mirror_test(chr_size_kb, chr_ram_detected, retroprog_id)
  log.section("Testing mirroring settings")

  -- put mapper in known state
  init_mapper()

  -- 1 screen A
  nes.cpu_wr(REGISTER_SELECT, MODE)
  nes.cpu_wr(REGISTER_VALUE, 0x00)
  if nes.detect_mapper_mirroring() ~= "1SCRNA" then
    log.error("One screen mirroring test failed (1 screen A)")
    return false
  else
    log.success("One screen mirroring test passed (1 screen A)")
  end

  -- 1 screen B
  nes.cpu_wr(REGISTER_SELECT, MODE)
  nes.cpu_wr(REGISTER_VALUE, 0x01)
  if nes.detect_mapper_mirroring() ~= "1SCRNB" then
    log.error("One screen mirroring test failed (1 screen B)")
    return false
  else
    log.success("One screen mirroring test passed (1 screen B)")
  end

  -- Vertical
  nes.cpu_wr(REGISTER_SELECT, MODE)
  nes.cpu_wr(REGISTER_VALUE, 0x02)
  if nes.detect_mapper_mirroring() ~= "VERT" then
    log.error("Vertical mirroring test failed")
    return false
  else
    log.success("Vertical mirroring test passed")
  end

  -- Horizontal
  nes.cpu_wr(REGISTER_SELECT, MODE)
  nes.cpu_wr(REGISTER_VALUE, 0x03)
  if nes.detect_mapper_mirroring() ~= "HORZ" then
    log.error("Horizontal mirroring test failed")
    return false
  else
    log.success("Horizontal mirroring test passed")
  end

  -- passed all tests
  return true
end

--[[
██████╗ ██████╗  ██████╗       ██████╗  ██████╗ ███╗   ███╗
██╔══██╗██╔══██╗██╔════╝       ██╔══██╗██╔═══██╗████╗ ████║
██████╔╝██████╔╝██║  ███╗█████╗██████╔╝██║   ██║██╔████╔██║
██╔═══╝ ██╔══██╗██║   ██║╚════╝██╔══██╗██║   ██║██║╚██╔╝██║
██║     ██║  ██║╚██████╔╝      ██║  ██║╚██████╔╝██║ ╚═╝ ██║
╚═╝     ╚═╝  ╚═╝ ╚═════╝       ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝

  --]]

--- Program one byte to PRG-ROM flash and poll for completion.
-- @param addr integer Address to program, 0x8000-0xFFFF
-- @param value integer 8-bit value to write
local function prg_rom_flash_byte(addr, value)
  local timeout = 0xFFFF
  local result = false

  if (addr < 0x8000 or addr > 0xFFFF) then
    log.error("Flash write to PRG-ROM", help.hex_0x4(addr), "must be in the $8000-$FFFF range")
    return false
  end

  -- send unlock command
  nes.cpu_wr(0xD555, 0xAA)
  nes.cpu_wr(0xAAAA, 0x55)
  nes.cpu_wr(0xD555, 0xA0)

  -- write value
  nes.cpu_wr(addr, value)

  -- control the written byte
  local rv = nes.cpu_rd(addr)

  while timeout > 0 and rv ~= nes.cpu_rd(addr) do
    rv = nes.cpu_rd(addr)
    timeout = timeout - 1
  end

  if nes.cpu_rd(addr) == value then result = true end

  if DEBUG then
    log.info("Done writing byte,", 0xFFFF - timeout .. " naks")
  end

  return result
end

--- Dump PRG-ROM contents to an already-open output file.
-- @param file file* Open binary output file
-- @param rom_size_kb integer PRG-ROM size in kilobytes
local function prg_rom_dump(file, rom_size_kb)
  -- PRG-ROM dump 32KB at a time
  local kb_per_read = 32
  local num_banks = math.floor(rom_size_kb / kb_per_read)
  local cur_bank = 0
  local addr_base = 0x80 -- $8000

  log.info("PRG-ROM size", rom_size_kb .. "KB")

  while cur_bank < num_banks do
    if DEBUG then
      log.point("dumping PRG bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- select desired bank to dump
    nes.cpu_wr(REGISTER_SELECT, OUTER_BANK)
    nes.cpu_wr(REGISTER_VALUE, cur_bank)

    dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NES_CPU_PAGE" })

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--- Program PRG-ROM contents from an already-open input file, one bank at a time.
-- @param file file* Open binary input file
-- @param rom_size_kb integer PRG-ROM size in kilobytes
local function prg_rom_flash(file, rom_size_kb)
  init_mapper()

  log.section("Programming PRG-ROM")
  log.info("PRG-ROM size", rom_size_kb .. "KB")

  local bank_size_kb = 32 -- 32KByte per PRG bank
  local cur_bank = 0
  local num_banks = math.floor(rom_size_kb / bank_size_kb)

  local options
  if prg_flash_chip.buffer == true then
    options = "USE_BUFFER"
    log.info("Using buffer programming")
  elseif prg_flash_chip.unlock_bypass == true then
    options = "USE_UNLOCK_BYPASS"
    log.info("Using unlock bypass mode")
  end

  while cur_bank < num_banks do
    if DEBUG then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- write the bank to flash to the mapper register
    nes.cpu_wr(REGISTER_SELECT, OUTER_BANK)
    nes.cpu_wr(REGISTER_VALUE, cur_bank)
    nes.cpu_wr(REGISTER_SELECT, CHR_BANK)

    -- flash data
    flash.write_file(file, bank_size_kb, { mapper = mapname, mem_type = "NES_PRG_ROM", options = options })

    cur_bank = cur_bank + 1
  end

  spinner.clear()
  log.success("Done programming PRG-ROM")
end

-- Legacy code, need to be updated at some point
local function read_gift(base, len)
  local rv
  init_mapper()

  -- select last bank in read only mode
  nes.cpu_wr(REGISTER_SELECT, OUTER_BANK)
  nes.cpu_wr(REGISTER_VALUE, 0xFF)

  local i = 0

  while i < len do
    rv = nes.cpu_rd(base + i)
    io.write(string.char(rv))
    i = i + 1
  end

  i = 0

  print("")

  while i < len do
    rv = nes.cpu_rd(base + i)
    io.write(string.format("%X.", rv))
    i = i + 1
  end

  print("")
end

-- Legacy code, need to be updated at some point
local function write_gift(base, off)
  local i
  local rv
  init_mapper()

  -- select last bank in flash mode
  nes.cpu_wr(REGISTER_SELECT, OUTER_BANK)
  nes.cpu_wr(REGISTER_VALUE, 0xFF)

  -- enter unlock bypass mode
  nes.cpu_wr(0x8AAA, 0xAA, { opcode = "FLASH_3V_WR" })
  nes.cpu_wr(0x8555, 0x55, { opcode = "FLASH_3V_WR" })
  nes.cpu_wr(0x8AAA, 0x20, { opcode = "FLASH_3V_WR" })

  -- write 0xA0 to address of byte to write, then write data
  nes.cpu_wr(base + off, 0xA0, { opcode = "FLASH_3V_WR" })
  nes.cpu_wr(base + off, 0x00, { opcode = "FLASH_3V_WR" }) -- end previous line
  off = off + 1
  nes.cpu_wr(base + off, 0xA0, { opcode = "FLASH_3V_WR" })
  nes.cpu_wr(base + off, 0x15, { opcode = "FLASH_3V_WR" }) -- line number..?
  off = off + 1
  nes.cpu_wr(base + off, 0xA0, { opcode = "FLASH_3V_WR" })
  nes.cpu_wr(base + off, string.byte("(", 1), { opcode = "FLASH_3V_WR" }) -- start with open parenth


  -- off = off + 1  -- increase to start of message but index starting at 1
  i = 1

  -- regular editions don't have gift messages
  -- local msg1 = "Contributor Edition"
  -- local msg1 = "Limited Edition"
  -- local msg2 = "82 of 100"  --  all flashed

  -- local msg1 = " Contributor Edition "
  -- local msg2 = " PinoBatch "  -- issue if capital P or R is first char for some reason..

  local len = string.len(msg1)

  while (i <= len) do
    nes.cpu_wr(base + off + i, 0xA0, { opcode = "FLASH_3V_WR" })
    nes.cpu_wr(base + off + i, string.byte(msg1, i), { opcode = "FLASH_3V_WR" }) -- line 1 of message
    print("write:", string.byte(msg1, i))
    i = i + 1
  end

  off = off + i

  nes.cpu_wr(base + off, 0xA0, { opcode = "FLASH_3V_WR" })
  nes.cpu_wr(base + off, 0x00, { opcode = "FLASH_3V_WR" }) -- end current line
  off = off + 1
  nes.cpu_wr(base + off, 0xA0, { opcode = "FLASH_3V_WR" })
  nes.cpu_wr(base + off, 0x16, { opcode = "FLASH_3V_WR" }) -- line number..?
  off = off + 1
  nes.cpu_wr(base + off, 0xA0, { opcode = "FLASH_3V_WR" })
  nes.cpu_wr(base + off, string.byte("(", 1), { opcode = "FLASH_3V_WR" }) -- start with open parenth

  i = 1


  len = string.len(msg2)

  while (i <= len) do
    nes.cpu_wr(base + off + i, 0xA0, { opcode = "FLASH_3V_WR" })
    nes.cpu_wr(base + off + i, string.byte(msg2, i), { opcode = "FLASH_3V_WR" }) -- line 2 of message
    print("write:", string.byte(msg2, i))
    i = i + 1
  end

  off = off + i

  nes.cpu_wr(base + off, 0xA0, { opcode = "FLASH_3V_WR" })
  nes.cpu_wr(base + off, 0x00, { opcode = "FLASH_3V_WR" }) -- end current line

  --]]


  -- poll until stops toggling, or data is as wrote
  --  rv = nes.cpu_rd(0x8BDC)
  --  print (rv)


  -- exit unlock bypass
  nes.cpu_wr(0x8000, 0x90, { opcode = "FLASH_3V_WR" })
  nes.cpu_wr(0x8000, 0x00, { opcode = "FLASH_3V_WR" })
  -- reset the flash chip
  nes.cpu_wr(0x8000, 0xF0, { opcode = "FLASH_3V_WR" })
end

--- Dump CHR contents to an already-open output file.
-- @param file file* Open binary output file
-- @param rom_size_kb integer CHR size in kilobytes
local function chr_dump(file, rom_size_kb)
  local kb_per_read = 8
  local num_banks = math.floor(rom_size_kb / kb_per_read)
  local addr_base = 0x00 -- $0000
  local cur_bank = 0

  log.info("CHR size", rom_size_kb .. "KB")

  while cur_bank < num_banks do
    if DEBUG then
      log.point("dump CHR bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    nes.cpu_wr(REGISTER_VALUE, cur_bank) -- 8KB @ PPU $0000

    dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NES_PPU_1KB" })

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--[[
 ██████╗██╗  ██╗██████╗       ██████╗  █████╗ ███╗   ███╗
██╔════╝██║  ██║██╔══██╗      ██╔══██╗██╔══██╗████╗ ████║
██║     ███████║██████╔╝█████╗██████╔╝███████║██╔████╔██║
██║     ██╔══██║██╔══██╗╚════╝██╔══██╗██╔══██║██║╚██╔╝██║
╚██████╗██║  ██║██║  ██║      ██║  ██║██║  ██║██║ ╚═╝ ██║
 ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝      ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝

  --]]

--- Detect CHR-RAM size by writing bank markers and reading them back.
-- Overwrites the test byte in each probed bank.
-- @return integer size_kb Detected CHR-RAM size in kilobytes, or 0 when detection fails
local function chr_ram_get_size()
  -- CHR-RAM can be maximum 32KB
  -- so we'll check four (4) 8K banks and see if we can write to each

  local chr_ram_size_kb = 32
  local num_banks = math.floor(chr_ram_size_kb / 4) - 1
  local rv

  log.section("Detecting CHR-RAM size")

  nes.cpu_wr(REGISTER_SELECT, CHR_BANK)

  -- set CHR bank to bank 0
  nes.cpu_wr(REGISTER_VALUE, 0x00)

  -- write to banks backwards
  for cur_bank = num_banks, 0, -1 do
    if DEBUG then log.point("trying to write to CHR bank", cur_bank, "of", num_banks) end
    nes.cpu_wr(REGISTER_VALUE, cur_bank) -- 8KB bank at $0000
    nes.ppu_wr(0x0000, cur_bank)
    cur_bank = cur_bank + 1
  end

  -- read back only last bank
  nes.cpu_wr(REGISTER_VALUE, num_banks) -- 8KB bank at $0000
  rv = nes.ppu_rd(0x0000)
  chr_ram_size_kb = (rv + 1) * 8

  if chr_ram_size_kb >= 0 and chr_ram_size_kb <= 32 then
    log.success("CHR-RAM size detected", chr_ram_size_kb .. "KB")
    return chr_ram_size_kb
  else
    log.warning("Failed to detect CHR-RAM size")
    return 0
  end
end

--- Exercise CHR-RAM with an LFSR pattern and compare the dumped result.
-- Overwrites CHR-RAM contents with the test pattern.
-- @param chr_ram_size_kb integer CHR-RAM size in kilobytes
-- @param retroprog_id string|integer Identifier used in the temporary dump filename
-- @return boolean success True when the CHR-RAM dump matches the expected LFSR data
local function chr_ram_exercise(chr_ram_size_kb, retroprog_id)
  dict.stuff("RESET_LFSR") -- sets it to 1

  local cur_bank = 0
  local num_banks = math.floor(chr_ram_size_kb / 8)

  log.section("Exercising CHR-RAM")
  log.info("CHR-RAM size", chr_ram_size_kb .. "KB")

  nes.cpu_wr(REGISTER_SELECT, CHR_BANK)

  -- set CHR bank to bank 0
  nes.cpu_wr(REGISTER_VALUE, 0x00)

  -- write random data to all banks
  log.point("Writing random data to CHR-RAM")
  while cur_bank < num_banks do
    if DEBUG then log.point("init CHR-RAM 8K bank", cur_bank, "of", num_banks - 1) end
    nes.cpu_wr(REGISTER_VALUE, cur_bank) -- 8KB bank at $0000
    local addr = 0x0000
    while (addr < 0x2000) do
      dict.nes("PPU_PAGE_WR_LFSR", addr)
      addr = addr + 256
    end
    cur_bank = cur_bank + 1
  end

  -- open file
  local filename = opts.write_path .. "./ignore/nes_chr_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))

  -- dump CHR-RAM
  log.point("Dumping CHR-RAM")
  chr_dump(file, chr_ram_size_kb)

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

--- Process all requested operations for this cartridge board/mapper.
-- @param process_opts table Parsed operation options from the main application
-- @param console_opts table Console/cartridge size options
-- @return false|nil result False on explicitly reported failure; otherwise no value
local function process(process_opts, console_opts)
  -- some local variables
  local rv               = nil
  local file
  local chr_ram_detected = false
  local chr_ram_size_kb  = 0

  -- process options
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
  local prg_size_kb      = console_opts.prg_rom_size_kb
  local chr_size_kb      = console_opts.chr_rom_size_kb
  local wram_size_kb     = console_opts.wram_size_kb

  -- initialize device i/o for NES
  dict.io("IO_RESET")
  dict.io("NES_INIT")

  -- put mapper in known state
  init_mapper()

  --[[
  888888 888888 .dP"Y8 888888
    88   88__   `Ybo."   88
    88   88""   o.`Y8b   88
    88   888888 8bodP'   88
  --]]

  -- test cart
  if do_test then
    log.section("Testing " .. mapname)

    chr_ram_detected = nes.ppu_ram_sense(0x1000)

    -- verify mirroring is behaving as expected
    rv = mirror_test(chr_size_kb, chr_ram_detected, retroprog_id)
    if not rv then return false end

    if options.force_flash_test or (do_rom_write and prg_size_kb ~= 0) then
      init_mapper()
      rv, prg_flash_chip = nes.prg_rom_get_chip()
      if not rv then
        log.error("Couldn't identify flash chip")
        return false
      end
    end

    -- CHR-RAM tests
    if chr_ram_detected then
      -- test CHR-RAM banking and try to detect size
      chr_ram_size_kb = chr_ram_get_size()

      -- test CHR-RAM
      if chr_ram_size_kb ~= 0 then
        rv = chr_ram_exercise(chr_ram_size_kb, retroprog_id)
        -- exit script if test fails
        if not rv then return end
      end
    end

    -- -- manipulate gift message
    -- local base = 0x8BD0
    -- local start_offset = 0xC
    -- local len = 80
    -- -- read_gift(base, len)

    -- -- write_gift(base, start_offset)

    -- read_gift(base, len)
  end

  --[[
  88""Yb    db    8b    d8     8888b.  88   88 8b    d8 88""Yb
  88__dP   dPYb   88b  d88      8I  Yb 88   88 88b  d88 88__dP
  88"Yb   dP__Yb  88YbdP88      8I  dY Y8   8P 88YbdP88 88"""
  88  Yb dP""""Yb 88 YY 88     8888Y"  `YbodP' 88 YY 88 88
  --]]

  -- dump cart RAM to file
  if do_ram_dump then
    log.section("Dumping PRG-RAM")
    log.warning("Not supported for this mapper")
  end

  --[[
  88""Yb    db    8b    d8     Yb        dP 88""Yb 88 888888 888888
  88__dP   dPYb   88b  d88      Yb  db  dP  88__dP 88   88   88__
  88"Yb   dP__Yb  88YbdP88       YbdPYbdP   88"Yb  88   88   88""
  88  Yb dP""""Yb 88 YY 88        YP  YP    88  Yb 88   88   888888
  --]]

  -- write file to the cart RAM
  if do_ram_write then
    log.section("Programming PRG-RAM")
    log.warning("Not supported for this mapper")
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

    -- create header: pass open & empty file & rom sizes
    if rom_dump_file.ext == "nes" then
      create_header(file, prg_size_kb, chr_size_kb)
    end

    -- dump cart to file
    if prg_size_kb ~= 0 then
      log.section("Dumping PRG-ROM")
      time.start()
      prg_rom_dump(file, prg_size_kb)
      time.report(prg_size_kb)
      log.success("PRG-ROM dumping done")
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
    -- erase PRG-ROM only if needed
    if prg_size_kb ~= 0 then
      rv = nes.prg_rom_erase(prg_flash_chip)
      if not rv then
        log.error("PRG-ROM couldn't be erased")
        return false
      end
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
    if prg_size_kb ~= 0 then
      -- open file
      file = assert(io.open(rom_write_file.filename, "rb"))

      -- flash cart
      time.start()
      prg_rom_flash(file, prg_size_kb)
      time.report(prg_size_kb)

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

  -- verify what we just flashed
  if do_verify then
    init_mapper()

    -- open file
    file = assert(io.open(verify_file.filename, "wb"))

    -- dump cart to file
    if prg_size_kb ~= 0 then
      log.section("Dumping PRG-ROM")
      time.start()
      prg_rom_dump(file, prg_size_kb)
      time.report(prg_size_kb)
      log.success("PRG-ROM dumping done")
    end

    -- close file
    assert(file:close())

    -- compare the flash file vs post dump file
    log.section("Verifying data")
    if files.compare(verify_file.filename, rom_write_file.filename, true) then
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
action53.process = process

-- return the module's table
return action53
