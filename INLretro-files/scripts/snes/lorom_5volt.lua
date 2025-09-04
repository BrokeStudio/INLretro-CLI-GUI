-- create the module's table
local lorom_5volt = {}

-- import required modules
local dict = require "scripts.app.dict"
local dump = require "scripts.app.dump"
local flash = require "scripts.app.flash"
local snes = require "scripts.app.snes"

-- file constants and global variables

-- local functions



-- Desc: attempt to read flash rom ID
-- Pre: snes_init() been called to setup i/o
-- Post:Address left on bus memories disabled
-- Rtn: true if valid flash ID found
local function rom_manf_id(debug)
  local rv
  --enter software mode A14 is highest address bit that needs to be valid
  dict.snes("SNES_SET_BANK", 0x00)

  --/ROMSEL wouldn't normally be low for these addresses..
  --true SNES mapped reads would set A15 high to be in lorom /ROMSEL space
  --but A15 isn't connected to the rom on LOROM so the cart can't see the difference
  --plus A15 doesn't need to be valid to read manf/prod ID anyway..
  dict.snes("SNES_ROM_WR", 0x5555, 0xAA)
  dict.snes("SNES_ROM_WR", 0x2AAA, 0x55)
  dict.snes("SNES_ROM_WR", 0x5555, 0x90)

  --read manf ID
  local manf_id = dict.snes("SNES_ROM_RD", 0x8000)
  if debug then print("attempted read SNES ROM manf ID:", string.format("%X", manf_id)) end

  --read prod ID
  local prod_id = dict.snes("SNES_ROM_RD", 0x8001)
  if debug then print("attempted read SNES ROM prod ID:", string.format("%X", prod_id)) end

  -- exit software
  dict.snes("SNES_ROM_WR", 0x0000, 0xF0)

  --return true if detected flash chip
  if (manf_id == 0xBF and prod_id == 0xB7) then
    print("512KByte flash detected")
    return true
  elseif (manf_id == 0xBF and prod_id == 0xB6) then
    print("256KByte flash detected")
    return true
  elseif (manf_id == 0xBF and prod_id == 0xB5) then
    print("128KByte flash detected")
    return true
  else
    return false
  end
end

--dump the SNES ROM starting at the provided bank
--/ROMSEL is always low for this dump
local function dump_rom(file, start_bank, rom_size_KB, debug)
  local KB_per_bank = 32 -- LOROM has 32KB per bank
  local num_banks = rom_size_KB / KB_per_bank
  local cur_bank = 0
  local addr_base = 0x80 -- $8000 LOROM

  while cur_bank < num_banks do
    if debug then print("dump ROM part ", cur_bank, " of ", num_banks) end

    --select desired bank
    dict.snes("SNES_SET_BANK", start_bank + cur_bank)

    dump.dumptofile(file, KB_per_bank, addr_base, "SNESROM_PAGE", false)

    cur_bank = cur_bank + 1
  end
end


--write a single byte to SNES ROM flash
--writes to currently selected bank address
local function wr_flash_byte(addr, value, debug)
  if (addr < 0x0000 or addr > 0xFFFF) then
    print("\n  ERROR! flash write to SNES", string.format("$%X", addr), "must be $0000-FFFF \n\n")
    return
  end

  --send unlock command and write byte
  dict.snes("SNES_ROM_WR", 0x5555, 0xAA)
  dict.snes("SNES_ROM_WR", 0x2AAA, 0x55)
  dict.snes("SNES_ROM_WR", 0x5555, 0xA0)
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


--fast host flash one bank at a time...
--this is controlled from the host side one bank at a time
local function flash_rom(file, rom_size_KB, debug)
  --init_mapper()

  --test some bytes
  --dict.snes("SNES_SET_BANK", 0x00) wr_flash_byte(0x8000, 0xA5, true) wr_flash_byte(0xFFFF, 0x5A, true)
  --dict.snes("SNES_SET_BANK", 0x01) wr_flash_byte(0x8000, 0x15, true) wr_flash_byte(0xFFFF, 0x1A, true)
  --last of 512KB
  --dict.snes("SNES_SET_BANK", 0x0F) wr_flash_byte(0x8000, 0xF5, true) wr_flash_byte(0xFFFF, 0xFA, true)

  print("\nProgramming ROM flash")

  --most of this is overkill for NROM, but it's how we want to handle things for bigger mappers
  local base_addr = 0x8000    --writes occur $8000-9FFF
  local bank_size = 32 * 1024 --SNES LOROM 32KB per ROM bank
  local buff_size = 1         --number of bytes to write at a time
  local cur_bank = 0
  local num_banks = rom_size_KB * 1024 / bank_size

  local byte_num --byte number gets reset for each bank
  local byte_str, data, readdata

  while cur_bank < num_banks do
    if (cur_bank % 4 == 0) then
      print("writing bank: ", cur_bank, " of ", num_banks - 1)
    end

    --select the current bank
    if (cur_bank <= 0xFF) then
      dict.snes("SNES_SET_BANK", cur_bank)
    else
      print("\n\nERROR!!!!  SNES bank cannot exceed 0xFF, it was:", string.format("0x%X", cur_bank))
      return
    end

    --have the device write a bank worth of data

    --[[  This version of the code programs a single byte at a time but doesn't require
    -- board specific functions in the firmware
    print("This is slow as molasses, but gets the job done")
    byte_num = 0  --current byte within the bank
    while byte_num < bank_size do

      --read next byte from the file and convert to binary
      byte_str = file:read(buff_size)
      data = string.unpack("B", byte_str, 1)

      --write the data
      --SLOWEST OPTION: no firmware specific functions 100% host flash algo:
      --wr_flash_byte(base_addr+byte_num, data, false)   --0.7KBps
      --EASIEST FIRMWARE SPEEDUP: 5x faster, create firmware write byte function:
      dict.snes("FLASH_WR_5V", base_addr+byte_num, data)  --3.8KBps (5.5x faster than above)

      --if (verify) then
      -- readdata = dict.nes("NES_CPU_RD", base_addr+byte_num)
      -- if readdata ~= data then
      --   print("ERROR flashing byte number", byte_num, " in bank",cur_bank, " to flash ", data, readdata)
      -- end
      --end

      byte_num = byte_num + 1
    end
    --]]

    --have the device write a bank worth of data
    flash.write_file(file, bank_size / 1024, "LOROM_5VOLT", "SNESROM", false)

    cur_bank = cur_bank + 1
  end

  print("Done Programming ROM flash")
end


--Cart should be in reset state upon calling this function
--this function processes all user requests for this specific board/mapper
local function process(test, read, erase, program, verify, dumpfile, flashfile, verifyfile)
  local rv = nil
  local file

  local snes_mapping = "LOROM"
  --local snes_mapping = "HIROM"

  local ram_size = 0

  --local rom_size = 32
  local rom_size = 512
  --local rom_size = 1024
  --local rom_size = 2048
  --local rom_size = 4096
  --local rom_size = 8192
  --local rom_size = 12288
  --local rom_size = 16384


  -- SNES memory map banking
  -- A15 always high for LOROM (A22 is typically low too)
  -- A22 always high for HIROM
  -- A23 splits the map in half
  -- A22 splits it in quarters (between what's typically low half and high half)
  -- b 7  6  5  4 :  3  2  1  0
  -- A23 22 21 20 : 19 18 17 16

  local first_bank --byte that contains A23-16

  if (snes_mapping == "LOROM") then
    -- LOROM typically sees the upper half (A15=1) of the first address 0b0000:1000_0000
    first_bank = 0x00
  elseif (snes_mapping == "HIROM") then
    -- HIROM typically sees the last 4MByte as the first addresses = 0b1100:0000_0000
    first_bank = 0xC0
  end


  --initialize device i/o for SNES
  dict.io("IO_RESET")
  dict.io("SNES_INIT")


  --test cart by reading manf/prod ID
  if test then
    print("\nTesting SNES board")

    --SNES detect HiROM or LoROM & RAM

    --SNES detect if able to read flash ID's
    if not rom_manf_id(true) then
      print("ERROR unable to read flash ID")
      return
    end
  end

  --dump the cart to dumpfile
  if read then
    print("\nDumping SNES ROM...")

    file = assert(io.open(dumpfile, "wb"))

    -- dump cart to file
    dump_rom(file, first_bank, rom_size, false)

    -- close file
    assert(file:close())
    print("DONE Dumping SNES ROM")
  end

  -- erase the cart
  if erase then
    print("\nErasing PLCC flash")

    local rv = nil

    --WR $AAA:AA $555:55 $AAA:AA
    dict.snes("SNES_SET_BANK", 0x00)

    dict.snes("SNES_ROM_WR", 0x5555, 0xAA)
    dict.snes("SNES_ROM_WR", 0x2AAA, 0x55)
    dict.snes("SNES_ROM_WR", 0x5555, 0x80)
    dict.snes("SNES_ROM_WR", 0x5555, 0xAA)
    dict.snes("SNES_ROM_WR", 0x2AAA, 0x55)
    dict.snes("SNES_ROM_WR", 0x5555, 0x10)
    rv = dict.snes("SNES_ROM_RD", 0x0000)

    local i = 0

    while (rv ~= 0xFF) do
      rv = dict.snes("SNES_ROM_RD", 0x8000)
      i = i + 1
    end
    print(i, "naks, done erasing snes rom.")

    --reset flash
    dict.snes("SNES_ROM_WR", 0x0000, 0xF0)
  end


  --program flashfile to the cart
  if program then
    --open file
    file = assert(io.open(flashfile, "rb"))
    --determine if auto-doubling, deinterleaving, etc,
    --needs done to make board compatible with rom

    --flash cart
    flash_rom(file, rom_size, true)

    -- close file
    assert(file:close())
  end

  -- verify flash file is on the cart
  if verify then
    print("\nPost dumping SNES ROM...")
    --for now let's just dump the file and verify manually

    file = assert(io.open(verifyfile, "wb"))

    -- dump cart to file
    dump_rom(file, first_bank, rom_size, false)

    -- close file
    assert(file:close())
    print("DONE Post dumping SNES ROM")
  end

  dict.io("IO_RESET")
end


-- global variables so other modules can use them


-- call functions desired to run when script is called/imported


-- functions other modules are able to call
lorom_5volt.process = process

-- return the module's table
return lorom_5volt
