-- create the module's table
local action53 = {}

-- import required modules
local dict     = require "scripts.app.dict"
local nes      = require "scripts.app.nes"
local dump     = require "scripts.app.dump"
local flash    = require "scripts.app.flash"
local chips    = require "scripts.app.chips"
local time     = require "scripts.app.time"
local log      = require "scripts.app.log"
local spinner  = require "scripts.app.spinner"
local files    = require "scripts.app.files"
local help     = require "scripts.app.help"

-- file constants and global variables
local mapname  = "A53"

-- local functions

--[[
███╗   ███╗██╗███████╗ ██████╗    ███████╗██╗   ██╗███╗   ██╗ ██████╗███████╗
████╗ ████║██║██╔════╝██╔════╝    ██╔════╝██║   ██║████╗  ██║██╔════╝██╔════╝
██╔████╔██║██║███████╗██║         █████╗  ██║   ██║██╔██╗ ██║██║     ███████╗
██║╚██╔╝██║██║╚════██║██║         ██╔══╝  ██║   ██║██║╚██╗██║██║     ╚════██║
██║ ╚═╝ ██║██║███████║╚██████╗    ██║     ╚██████╔╝██║ ╚████║╚██████╗███████║
╚═╝     ╚═╝╚═╝╚══════╝ ╚═════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚══════╝

  --]]

-- initialize mapper for dump/flash routines
local function init_mapper()
  -- //Setup as CNROM, then scroll through outer banks.
  -- cpu_wr(0x5000, 0x80);   //reg select mode
  dict.nes("NES_CPU_WR", 0x5000, 0x80)

  -- //   xxSSPPMM   SS-size: 0-32KB, PP-prg mode: 0,1 32KB, MM-mirror
  -- cpu_wr(0x8000, 0b00000000);     //reg value 256KB inner, 32KB banks
  dict.nes("NES_CPU_WR", 0x8000, 0x00)
  -- cpu_wr(0x5000, 0x81);   //outer reg select mode
  dict.nes("NES_CPU_WR", 0x5000, 0x81)
  -- cpu_wr(0x8000, 0x00);   //first 32KB bank
  dict.nes("NES_CPU_WR", 0x8000, 0x00)

  -- cpu_wr(0x5000, 0x01);   //inner prg reg select
  dict.nes("NES_CPU_WR", 0x5000, 0x01)
  -- cpu_wr(0x8000, 0x00);   //controls nothing in this size
  dict.nes("NES_CPU_WR", 0x8000, 0x00)
  -- cpu_wr(0x5000, 0x00);   //chr reg select
  dict.nes("NES_CPU_WR", 0x5000, 0x00)
  -- cpu_wr(0x8000, 0x00);   //first chr bank
  dict.nes("NES_CPU_WR", 0x8000, 0x00)
  -- selecting CNROM means that mapper writes to $8000-FFFF will only change the CHR-RAM bank which
  -- doesn't affect anything we're concerned about

  -- enable flash writes $5000 set to 0b0 101 010 0
  -- dict.nes("NES_CPU_WR", 0x5000, 0x54)
  -- dict.nes("NES_CPU_WR", 0x5555, 0x54)
end

local function create_header(file, prg_kb, chr_kb)
  -- write_header(file, prg_kb, chr_kb, mapper, mirroring)
  nes.write_header(file, prg_kb, chr_kb, op_buffer[mapname], 0)
end

-- test the mapper's mirroring modes to verify working properly
-- can be used to help identify board: returns true if pass, false if failed
local function mirror_test(chr_size, chr_ram_detected, retroprog_id, debug)
  log.section("Testing mirroring settings")

  -- put mapper in known state
  init_mapper()

  -- CIRAM
  log.point("CIRAM")

  -- 1 screen A
  dict.nes("NES_CPU_WR", 0x5000, 0x80)
  dict.nes("NES_CPU_WR", 0x8000, 0x00)
  if nes.detect_mapper_mirroring(debug) ~= "1SCRNA" then
    log.error("One screen mirroring test failed (1 screen A)")
    return false
  else
    log.success("One screen mirroring test passed (1 screen A)")
  end

  -- 1 screen B
  dict.nes("NES_CPU_WR", 0x5000, 0x80)
  dict.nes("NES_CPU_WR", 0x8000, 0x01)
  if nes.detect_mapper_mirroring(debug) ~= "1SCRNB" then
    log.error("One screen mirroring test failed (1 screen B)")
    return false
  else
    log.success("One screen mirroring test passed (1 screen B)")
  end

  -- Vertical
  dict.nes("NES_CPU_WR", 0x5000, 0x80)
  dict.nes("NES_CPU_WR", 0x8000, 0x02)
  if nes.detect_mapper_mirroring(debug) ~= "VERT" then
    log.error("Vertical mirroring test failed")
    return false
  else
    log.success("Vertical mirroring test passed")
  end

  -- Horizontal
  dict.nes("NES_CPU_WR", 0x5000, 0x80)
  dict.nes("NES_CPU_WR", 0x8000, 0x03)
  if nes.detect_mapper_mirroring(debug) ~= "HORZ" then
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

-- read PRG-ROM flash ID
local function prg_rom_manf_id()
  init_mapper()

  local manufacturer_id
  local device_id
  local device_test

  log.section("Reading PRG-ROM manufacturer/device ID")

  -- exit software
  dict.nes("NES_CPU_WR", 0x8000, 0xF0)

  dict.nes("NES_CPU_WR", 0x8AAA, 0xAA)
  dict.nes("NES_CPU_WR", 0x8555, 0x55)
  dict.nes("NES_CPU_WR", 0x8AAA, 0x90)

  manufacturer_id = dict.nes("NES_CPU_RD", 0x8000)
  chips.display_manufacturer(manufacturer_id)

  device_id = dict.nes("NES_CPU_RD", 0x8001)
  device_test = chips.display_device(manufacturer_id, device_id)

  if not device_test then
    device_id = dict.nes("NES_CPU_RD", 0x8002) << 16
    device_id = device_id | (dict.nes("NES_CPU_RD", 0x801C) << 8)
    device_id = device_id | dict.nes("NES_CPU_RD", 0x801E)
    device_test = chips.display_device(manufacturer_id, device_id)
  end

  -- exit software
  dict.nes("NES_CPU_WR", 0x8000, 0xF0)

  if device_test == false then
    return false
  else
    return true
  end
end

-- REQ: addr must be in the first bank $8000-FFFF
local function prg_rom_flash_byte(addr, value, debug)
  --[[
  if addr < 0x8000 or addr > 0xFFFF then
    print("\n  ERROR! flash write to PRG-ROM", string.format("$%X", addr), "must be $8000-9FFF \n\n")
    return
  end
]]
  --send unlock command and write byte
  dict.nes("FLASH_3V_WR", addr, 0xA0) -- FLASH_3V_WR = M2_HIGH_WR
  dict.nes("FLASH_3V_WR", addr, value)

  local rv = dict.nes("NES_CPU_RD", addr)

  local i = 0

  while (rv ~= value) do
    rv = dict.nes("NES_CPU_RD", addr)
    i = i + 1
  end
  if debug then print(i, "naks, done writing byte.") end

  --TODO handle timeout for problems

  --TODO return pass/fail/info
end

--dump the PRG ROM
local function og_prg_rom_dump(file, rom_size_KB, debug)
  --PRG-ROM dump 32KB at a time in CNROM mode with supervisor register
  local KB_per_read = 32
  local num_banks = rom_size_KB / KB_per_read
  local cur_bank = 0
  local addr_base = 0x80 -- $8000 PAGE

  while cur_bank < num_banks do
    if debug then print("dump PRG part ", cur_bank, " of ", num_banks) end

    --select desired bank(s) to dump
    --nes_cpu_wr(0x5000, 0x81); //outer reg select mode
    --nes_cpu_wr(0x8000, bank);         //outer bank
    --nes_cpu_wr(0x5000, 0x00); //chr reg select act like CNROM
    dict.nes("NES_CPU_WR", 0x5000, 0x81)
    dict.nes("NES_CPU_WR", 0x8000, cur_bank)
    --dict.nes("NES_CPU_WR", 0x5000, 0x54)

    --[[  This version of the code dumps a single byte at a time but doesn't require
    --    specific functions in the firmware
    print("This is slow as molasses, but gets the job done")

    for i = 0, KB_per_read*1024-1, 1 do
      file:write(string.char(dict.nes("NES_CPU_RD", 0x8000+i)))
    end

      --]]

    --dump bank's worth of data
    dump.dumptofile(file, KB_per_read, addr_base, "NESCPU_PAGE", false)

    cur_bank = cur_bank + 1
  end
end

-- dump PRG-ROM
local function prg_rom_dump(file, rom_size_KB, debug)
  -- PRG-ROM dump 32KB at a time
  local KB_per_read = 32
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

    -- select desired bank to dump
    dict.nes("NES_CPU_WR", 0x5000, 0x81)
    dict.nes("NES_CPU_WR", 0x8000, cur_bank)

    dump.dumptofile(file, KB_per_read, addr_base, "NESCPU_PAGE", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--host flash one bank at a time...
--this is controlled from the host side one bank at a time
--but requires mapper specific firmware flashing functions
--there is super slow version commented out that doesn't require MMC3 specific firmware code
local function og_prg_rom_flash(file, rom_size_KB, debug)
  init_mapper()

  --test some bytes
  --prg_rom_flash_byte(0x0000, 0xA5, true)
  --prg_rom_flash_byte(0x0FFF, 0x5A, true)

  print("\nProgramming PRG-ROM flash")
  --initial testing of MMC3 with no specific MMC3 flash firmware functions 6min per 256KByte = 0.7KBps


  local base_addr = 0x8000    --writes occur $8000-9FFF
  local bank_size = 32 * 1024 --in CNROM mode 32KB PRG bank
  local buff_size = 1         --number of bytes to write at a time
  local cur_bank = 0
  local num_banks = rom_size_KB * 1024 / bank_size

  local byte_num --byte number gets reset for each bank
  local byte_str, data, readdata


  while cur_bank < num_banks do
    if (cur_bank % 4 == 0) then
      print("writing PRG bank: ", cur_bank, " of ", num_banks - 1)
    end

    --write the current bank to the mapper register
    --nes_cpu_wr(0x5000, 0x81); //outer reg select mode
    dict.nes("NES_CPU_WR", 0x5000, 0x81)
    --nes_cpu_wr(0x8000, bank);         //outer bank
    dict.nes("NES_CPU_WR", 0x8000, cur_bank)
    --nes_cpu_wr(0x5000, 0x54); //
    --dict.nes("NES_CPU_WR", 0x5000, 0x54)


    --have the device write a bank worth of data

    --[[  This version of the code programs a single byte at a time but doesn't require
    --  MMC3 specific functions in the firmware
    print("This is slow as molasses, but gets the job done")
    byte_num = 0  --current byte within the bank
    dict.nes("FLASH_3V_WR", 0x8AAA, 0xAA)
    dict.nes("FLASH_3V_WR", 0x8555, 0x55)
    dict.nes("FLASH_3V_WR", 0x8AAA, 0x20)
    while byte_num < bank_size do

      --read next byte from the file and convert to binary
      byte_str = file:read(buff_size)
      data = string.unpack("B", byte_str, 1)

      --write the data
      --SLOWEST OPTION: no firmware MMC3 specific functions 100% host flash algo:
      prg_rom_flash_byte(base_addr+byte_num, data, false)   --0.7KBps

      --EASIEST FIRMWARE SPEEDUP: 5x faster, create MMC3 write byte function:
      --dict.nes("A53_TSSOP_FLASH_WR", base_addr+byte_num, data)  --3.8KBps (5.5x faster than above)
      --NEXT STEP: firmware write page/bank function can use function pointer for the function above
      --  this may cause issues with more complex algos
      --  sometimes cur bank is needed
      --  for this to work, need to have function post conditions meet the preconditions
      --  that way host intervention is only needed for bank controls
      --  Is there a way to allow for double buffering though..?
      --  YES!  just think of the bank as a complete memory
      --  this greatly simplifies things and is exactly where we want to go
      --  This is completed below outside the byte while loop @ 39KBps

      if (verify) then
        readdata = dict.nes("NES_CPU_RD", base_addr+byte_num)
        if readdata ~= data then
          print("ERROR flashing byte number", byte_num, " in bank",cur_bank, " to flash ", data, readdata)
        end
      end

      byte_num = byte_num + 1
    end
    dict.nes("FLASH_3V_WR", 0x8000, 0x90)
    dict.nes("FLASH_3V_WR", 0x8000, 0x00)
      --]]

    --have the device write a bank worth of data
    --FAST!  13sec for 512KB = 39KBps
    flash.write_file(file, bank_size / 1024, mapname, "PRGROM", false)

    cur_bank = cur_bank + 1
  end

  print("Done Programming PRG-ROM flash")
end

-- host flash one bank at a time
local function prg_rom_flash(file, rom_size_KB, debug)
  init_mapper()

  log.info("PRG-ROM size", rom_size_KB .. "KB")

  local bank_size = 32 -- 32KByte per PRG bank
  local cur_bank = 0
  local num_banks = math.floor(rom_size_KB / bank_size)

  while cur_bank < num_banks do
    if debug then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- write the bank to flash to the mapper register
    dict.nes("NES_CPU_WR", 0x5000, 0x81)
    dict.nes("NES_CPU_WR", 0x8000, cur_bank)
    dict.nes("NES_CPU_WR", 0x5000, 0x00)

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size, mapname, "PRGROM", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
  log.success("Done programming PRG-ROM")
end

























local function read_gift(base, len)
  local rv
  init_mapper()

  --select last bank in read only mode
  dict.nes("NES_CPU_WR", 0x5000, 0x81)
  dict.nes("NES_CPU_WR", 0x8000, 0xFF)

  local i = 0

  while i < len do
    rv = dict.nes("NES_CPU_RD", base + i)
    io.write(string.char(rv))
    i = i + 1
  end

  i = 0

  print("")

  while i < len do
    rv = dict.nes("NES_CPU_RD", base + i)
    io.write(string.format("%X.", rv))
    i = i + 1
  end

  print("")
end

local function write_gift(base, off)
  local i
  local rv
  init_mapper()

  --select last bank in flash mode
  dict.nes("NES_CPU_WR", 0x5000, 0x81)
  dict.nes("NES_CPU_WR", 0x8000, 0xFF)
  --dict.nes("NES_CPU_WR", 0x5000, 0x54)

  --enter unlock bypass mode
  dict.nes("FLASH_3V_WR", 0x8AAA, 0xAA)
  dict.nes("FLASH_3V_WR", 0x8555, 0x55)
  dict.nes("FLASH_3V_WR", 0x8AAA, 0x20)

  --write 0xA0 to address of byte to write, then write data
  dict.nes("FLASH_3V_WR", base + off, 0xA0)
  dict.nes("FLASH_3V_WR", base + off, 0x00) --end previous line
  off = off + 1
  dict.nes("FLASH_3V_WR", base + off, 0xA0)
  dict.nes("FLASH_3V_WR", base + off, 0x15) --line number..?
  off = off + 1
  dict.nes("FLASH_3V_WR", base + off, 0xA0)
  dict.nes("FLASH_3V_WR", base + off, string.byte("(", 1)) --start with open parenth


  --off = off + 1  --increase to start of message but index starting at 1
  i = 1

  --regular editions don't have gift messages
  --local msg1 = "Contributor Edition"
  --local msg1 = "Limited Edition"
  --local msg2 = "82 of 100"  --  all flashed

  --local msg1 = " Contributor Edition "
  --local msg2 = " PinoBatch "  --issue if capital P or R is first char for some reason..

  local len = string.len(msg1)

  while (i <= len) do
    dict.nes("FLASH_3V_WR", base + off + i, 0xA0)
    dict.nes("FLASH_3V_WR", base + off + i, string.byte(msg1, i)) --line 1 of message
    print("write:", string.byte(msg1, i))
    i = i + 1
  end

  off = off + i

  dict.nes("FLASH_3V_WR", base + off, 0xA0)
  dict.nes("FLASH_3V_WR", base + off, 0x00) --end current line
  off = off + 1
  dict.nes("FLASH_3V_WR", base + off, 0xA0)
  dict.nes("FLASH_3V_WR", base + off, 0x16) --line number..?
  off = off + 1
  dict.nes("FLASH_3V_WR", base + off, 0xA0)
  dict.nes("FLASH_3V_WR", base + off, string.byte("(", 1)) --start with open parenth

  i = 1


  len = string.len(msg2)

  while (i <= len) do
    dict.nes("FLASH_3V_WR", base + off + i, 0xA0)
    dict.nes("FLASH_3V_WR", base + off + i, string.byte(msg2, i)) --line 2 of message
    print("write:", string.byte(msg2, i))
    i = i + 1
  end

  off = off + i

  dict.nes("FLASH_3V_WR", base + off, 0xA0)
  dict.nes("FLASH_3V_WR", base + off, 0x00) --end current line

  --]]


  --poll until stops toggling, or data is as wrote
  --  rv = dict.nes("NES_CPU_RD", 0x8BDC)
  --  print (rv)


  --exit unlock bypass
  dict.nes("FLASH_3V_WR", 0x8000, 0x90)
  dict.nes("FLASH_3V_WR", 0x8000, 0x00)
  --reset the flash chip
  dict.nes("FLASH_3V_WR", 0x8000, 0xF0)
end

-- dump CHR-ROM/RAM
local function chr_dump(file, rom_size_KB, debug)
  local KB_per_read = 8
  local num_banks = math.floor(rom_size_KB / KB_per_read)
  local addr_base = 0x00 -- $0000
  local cur_bank = 0

  log.info("CHR size", rom_size_KB .. "KB")

  while cur_bank < num_banks do
    if debug then
      log.point("dump CHR bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    dict.nes("NES_CPU_WR", 0x8000, cur_bank) -- 8KB @ PPU $0000

    dump.dumptofile(file, KB_per_read, addr_base, "NESPPU_1KB", false)

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

-- select different chr-ram banks and verify all banks are present
local function chr_ram_get_size(debug)
  -- CHR-RAM can be maximum 32KB
  -- so we'll check four (4) 8K banks and see if we can write to each

  local chr_ram_size = 32
  local num_banks = math.floor(chr_ram_size / 4) - 1
  local rv

  log.section("Detecting CHR-RAM size")

  dict.nes("NES_CPU_WR", 0x5000, 0x00)

  -- set CHR bank to bank 0
  dict.nes("NES_CPU_WR", 0x8000, 0x00)

  -- write to banks backwards
  for cur_bank = num_banks, 0, -1 do
    if debug then log.point("trying to write to CHR bank", cur_bank, "of", num_banks) end
    dict.nes("NES_CPU_WR", 0x8000, cur_bank) -- 8KB bank at $0000
    dict.nes("NES_PPU_WR", 0x0000, cur_bank)
    cur_bank = cur_bank + 1
  end

  -- read back only last bank
  dict.nes("NES_CPU_WR", 0x8000, num_banks) -- 8KB bank at $0000
  rv = dict.nes("NES_PPU_RD", 0x0000)
  chr_ram_size = (rv + 1) * 8

  if chr_ram_size >= 0 and chr_ram_size <= 32 then
    log.success("CHR-RAM size detected", chr_ram_size .. "KB")
    return chr_ram_size
  else
    log.warning("Failed to detect CHR-RAM size")
    return 0
  end
end

local function chr_ram_exercise(chr_ram_size, retroprog_id, debug)
  dict.stuff("RESET_LFSR") -- sets it to 1

  local cur_bank = 0
  local num_banks = math.floor(chr_ram_size / 8)

  log.section("Exercising CHR-RAM")
  log.info("CHR-RAM size", chr_ram_size .. "KB")

  dict.nes("NES_CPU_WR", 0x5000, 0x00)

  -- set CHR bank to bank 0
  dict.nes("NES_CPU_WR", 0x8000, 0x00)

  -- write random data to all banks
  log.point("Writing random data to CHR-RAM")
  while cur_bank < num_banks do
    if debug then log.point("init CHR-RAM 8K bank", cur_bank, "of", num_banks - 1) end
    dict.nes("NES_CPU_WR", 0x8000, cur_bank) -- 8KB bank at $0000
    local addr = 0x0000
    while (addr < 0x2000) do
      dict.nes("PPU_PAGE_WR_LFSR", addr)
      addr = addr + 256
    end
    cur_bank = cur_bank + 1
  end

  -- open file
  local filename = opts.lua_path .. "./ignore/nes_chr_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))

  -- dump CHR-RAM
  log.point("Dumping CHR-RAM")
  chr_dump(file, chr_ram_size, debug)

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

    chr_ram_detected = nes.ppu_ram_sense(0x1000, DEBUG)

    -- verify mirroring is behaving as expected
    rv = mirror_test(chr_size, chr_ram_detected, retroprog_id, DEBUG)
    if not rv then return false end

    if options.force_flash_test or (do_rom_write and prg_size ~= 0) then
      rv = prg_rom_manf_id()
      if not rv then
        log.error("Couldn't identify flash chip")
        return false
      end
    end

    -- CHR-RAM tests
    if chr_ram_detected then
      -- test CHR-RAM banking and try to detect size
      chr_ram_size = chr_ram_get_size(DEBUG)

      -- test CHR-RAM
      if chr_ram_size ~= 0 then
        rv = chr_ram_exercise(chr_ram_size, retroprog_id, DEBUG)
        -- exit script if test fails
        if not rv then return end
      end
    end

    -- --manipulate gift message
    -- local base = 0x8BD0
    -- local start_offset = 0xC
    -- local len = 80
    -- --read_gift(base, len)

    -- --write_gift(base, start_offset)

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
      log.section("Erasing PRG-ROM")
      time.start()
      dict.nes("NES_CPU_WR", 0x8AAA, 0xAA)
      dict.nes("NES_CPU_WR", 0x8555, 0x55)
      dict.nes("NES_CPU_WR", 0x8AAA, 0x80)
      dict.nes("NES_CPU_WR", 0x8AAA, 0xAA)
      dict.nes("NES_CPU_WR", 0x8555, 0x55)
      dict.nes("NES_CPU_WR", 0x8AAA, 0x10)

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
  end

  --[[
  88""Yb  dP"Yb  8b    d8     Yb        dP 88""Yb 88 888888 888888
  88__dP dP   Yb 88b  d88      Yb  db  dP  88__dP 88   88   88__
  88"Yb  Yb   dP 88YbdP88       YbdPYbdP   88"Yb  88   88   88""
  88  Yb  YbodP  88 YY 88        YP  YP    88  Yb 88   88   888888
  --]]

  -- program file to the cart
  if do_rom_write then
    log.section("Programming PRG-ROM")

    -- -- set bank
    -- dict.nes("NES_CPU_WR", 0x5000, 0x81)
    -- dict.nes("NES_CPU_WR", 0x8000, cur_bank)
    -- dict.nes("NES_CPU_WR", 0x5000, 0x00)

    -- dict.nes("NES_CPU_WR", 0x8AAA, 0xAA);
    -- dict.nes("NES_CPU_WR", 0x8555, 0x55);
    -- dict.nes("NES_CPU_WR", 0x8AAA, 0xA0);
    -- dict.nes("NES_CPU_WR", 0x8000, 0xAA);


    -- -- -- enter unlock bypass mode
    -- -- dict.nes("NES_CPU_WR", 0x8AAA, 0xAA);
    -- -- dict.nes("NES_CPU_WR", 0x8555, 0x55);
    -- -- dict.nes("NES_CPU_WR", 0x8AAA, 0x20);

    -- -- -- write data
    -- -- dict.nes("NES_CPU_WR", 0x8000, 0xA0);
    -- -- dict.nes("NES_CPU_WR", 0x8000, 0xAA);

    -- rv = dict.nes("NES_CPU_WR", 0x8000)
    -- while rv ~= dict.nes("NES_CPU_WR", 0x8000) do
    --   rv = dict.nes("NES_CPU_WR", 0x8000)
    -- end

    -- -- -- exit unlock bypasse mode
    -- -- dict.nes("NES_CPU_WR", 0x8000, 0x90);
    -- -- dict.nes("NES_CPU_WR", 0x8000, 0x00);

    -- nes.cpu_rd(0x8000)

    -- open file
    file = assert(io.open(rom_write_file.filename, "rb"))

    -- flash cart
    if prg_size ~= 0 then
      time.start()
      prg_rom_flash(file, prg_size, DEBUG)
      time.report(prg_size)
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























  --[[
    nes.cpu_wr(0x5000, 0x81)
    nes.cpu_wr(0x8000, 7)

    nes.cpu_rd(0xfef0)
    nes.cpu_rd(0xfef1)
    nes.cpu_rd(0xfef2)
    nes.cpu_rd(0xfef3)
    nes.cpu_rd(0xfef4)
    nes.cpu_rd(0xfef5)
    nes.cpu_rd(0xfef6)
    nes.cpu_rd(0xfef7)
    nes.cpu_rd(0xfef8)
    nes.cpu_rd(0xfef9)
    nes.cpu_rd(0xfefa)
    nes.cpu_rd(0xfefb)
    nes.cpu_rd(0xfefc)
    nes.cpu_rd(0xfefd)
    nes.cpu_rd(0xfefe)
    nes.cpu_rd(0xfeff)

  do return end
  --]]

  --dump the cart to dumpfile
  if read then
    print("\nDumping PRG & CHR ROMs...")

    --initialize the mapper for dumping
    init_mapper(debug)

    file = assert(io.open(dumpfile, "wb"))

    --create header: pass open & empty file & rom sizes
    if dump_filetype == "nes" then
      --create header: pass open & empty file & rom sizes
      create_header(file, prg_size, chr_size)
    end

    -- dump cart to file
    prg_rom_dump(file, prg_size, true) --false)
    if chr_size ~= 0 then
      dump_chrrom(file, chr_size, false)
    end

    -- close file
    assert(file:close())

    print("DONE Dumping PRG & CHR ROMs")
  end

  -- erase the cart
  --  erase = nil
  if erase then
    --initialize the mapper for erasing
    init_mapper(debug)

    print("\nerasing action53 tsop takes ~30sec")

    print("erasing PRG-ROM")
    --A0-A14 are all directly addressable in CNROM mode
    --only A0-A11 are required to be valid for tsop-48
    --and mapper writes don't affect PRG banking
    dict.nes("FLASH_3V_WR", 0x8AAA, 0xAA)
    dict.nes("FLASH_3V_WR", 0x8555, 0x55)
    dict.nes("FLASH_3V_WR", 0x8AAA, 0x80)
    dict.nes("FLASH_3V_WR", 0x8AAA, 0xAA)
    dict.nes("FLASH_3V_WR", 0x8555, 0x55)
    dict.nes("FLASH_3V_WR", 0x8AAA, 0x10)
    rv = dict.nes("NES_CPU_RD", 0x8000)

    local i = 0

    -- TODO create some function to pass the read value
    -- that's smart enough to figure out if the board is actually erasing or not
    while (rv ~= 0xFF) do
      rv = dict.nes("NES_CPU_RD", 0x8000)
      i = i + 1
    end
    print(i, "naks, done erasing prg.")
  end
  --[[
nes.cpu_wr(0x5000, 0x81)
nes.cpu_wr(0x8000, 0x00)
nes.cpu_wr(0x5000, 0x54)

nes.cpu_rd(0xf4f6)

nes.cpu_wr(0x8AAA, 0xAA)
nes.cpu_wr(0x8555, 0x55)
nes.cpu_wr(0x8AAA, 0x20)

nes.cpu_wr(0xf4f6, 0xa0)
nes.cpu_wr(0xf4f6, 0xaa)

nes.cpu_wr(0x8000, 0x90)
nes.cpu_wr(0x8000, 0x00)
nes.cpu_wr(0x8000, 0xF0)

nes.cpu_rd(0xf4f6)

  do return end
  --]]
  --program flashfile to the cart
  if program then
    --initialize the mapper for dumping
    init_mapper(debug)

    --open file
    file = assert(io.open(flashfile, "rb"))
    --determine if auto-doubling, deinterleaving, etc,
    --needs done to make board compatible with rom

    --not susceptible to bus conflicts

    if flash_filetype == "nes" then
      --advance past the 16byte header
      file:read(16)
    end

    --flash cart
    time.start()
    prg_rom_flash(file, prg_size, true)
    time.report(prg_size)

    -- close file
    assert(file:close())
  end

  -- verify flash file is on the cart
  if verify then
    --for now let's just dump the file and verify manually
    print("\nPost dumping PRG & CHR ROMs...")

    --initialize the mapper for dumping
    init_mapper(debug)

    file = assert(io.open(verifyfile, "wb"))

    if verify_filetype == "nes" then
      --create header: pass open & empty file & rom sizes
      create_header(file, prg_size, chr_size)
    end

    -- dump cart to file
    time.start()
    prg_rom_dump(file, prg_size, false)
    time.report(prg_size)
    print("DONE post dumping PRG & CHR ROMs")

    -- close file
    assert(file:close())

    -- compare the flash file vs post dump file
    local offset
    if flash_filetype == "nes" then offset = 16 else offset = false end
    if (files.compare(verifyfile, flashfile, true, false, offset)) then
      print("\nSUCCESS! Flash verified")
    else
      print("\n\n\n FAILURE! Flash verification did not match")
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
