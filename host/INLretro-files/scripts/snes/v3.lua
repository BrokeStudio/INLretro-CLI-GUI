-- create the module's table
local v3 = {}

-- import required modules
local dict = require "scripts.app.dict"
local dump = require "scripts.app.dump"
local flash = require "scripts.app.flash"
local snes = require "scripts.app.snes"

-- file constants and global variables

-- local functions
local function prgm_mode(debug)
  if debug then print("going to program mode, swim:", snes_swimcart) end
  if snes_swimcart then
    print("ERROR cart got set to swim mode somehow!!!")
    --   swim.snes_v3_prgm(debug)
  else
    dict.pinport("CTL_SET_LO", "SNES_RST")
  end
end

local function play_mode(debug)
  if debug then print("going to play mode, swim:", snes_swimcart) end
  if snes_swimcart then
    --   swim.snes_v3_play(debug)
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
local function read_flashID(debug)
  local rv
  --enter software mode A11 is highest address bit that needs to be valid
  --datasheet not exactly explicit, A11 might not need to be valid
  --part has A-1 (negative 1) since it's in byte mode, meaning the part's A11 is actually A12
  --WR $AAA:AA $555:55 $AAA:AA
  dict.snes("SNES_SET_BANK", 0x00)

  --put cart in program mode
  --v3.0 boards don't use EXP0 for program mode, must use SWIM via CIC
  -- prgm_mode()

  dict.snes("SNES_ROM_WR", 0x8AAA, 0xAA)
  dict.snes("SNES_ROM_WR", 0x8555, 0x55)
  dict.snes("SNES_ROM_WR", 0x8AAA, 0x90)

  --exit program mode
  -- play_mode()

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
  -- prgm_mode()

  -- exit software
  dict.snes("SNES_ROM_WR", 0x0000, 0xF0)

  --exit program mode
  -- play_mode()

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


--Cart should be in reset state upon calling this function
--this function processes all user requests for this specific board/mapper
local function process(test, read, erase, program, verify, dumpfile, flashfile, verifyfile)
  local rv = nil
  local file


  --initialize device i/o for SNES
  dict.io("IO_RESET")
  dict.io("SNES_INIT")

  -- local snes_mapping = "LOROM"
  local snes_mapping = "HIROM"
  local rom_size = 32
  -- local rom_size = 512
  -- local rom_size = 1024
  -- local rom_size = 2048
  -- local rom_size = 4096
  -- local rom_size = 8192
  -- local rom_size = 12288
  -- local rom_size = 16384

  --test cart by reading manf/prod ID
  if test then
    --SNES detect HiROM or LoROM
    --nes.detect_mapper_mirroring(true)
    --SNES detect if there's save ram and size

    --SNES detect if able to read flash ID's
    if not read_flashID(true) then
      print("ERROR unable to read flash ID")
      return
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

  --dump the cart to dumpfile
  if read then
    --initialize the mapper for dumping
    --init_mapper(debug)

    file = assert(io.open(dumpfile, "wb"))

    --TODO find bank table to avoid bus conflicts!
    -- dump cart to file
    dump.dumptofile(file, rom_size, snes_mapping, "SNESROM", true)

    -- close file
    assert(file:close())
  end

  -- erase the cart
  if erase then
    print("\nerasing tsop takes ~30sec")

    local rv = nil

    --WR $AAA:AA $555:55 $AAA:AA
    dict.snes("SNES_SET_BANK", 0x00)

    --put cart in program mode
    --   snes.prgm_mode()

    dict.snes("SNES_ROM_WR", 0x8AAA, 0xAA)
    dict.snes("SNES_ROM_WR", 0x8555, 0x55)
    dict.snes("SNES_ROM_WR", 0x8AAA, 0x80)
    dict.snes("SNES_ROM_WR", 0x8AAA, 0xAA)
    dict.snes("SNES_ROM_WR", 0x8555, 0x55)
    dict.snes("SNES_ROM_WR", 0x8AAA, 0x10)

    --exit program mode
    --   snes.play_mode()

    rv = dict.snes("SNES_ROM_RD", 0x8000)

    local i = 0

    while (rv ~= 0xFF) do
      rv = dict.snes("SNES_ROM_RD", 0x8000)
      i = i + 1
      --     if debug then print(" ", i,":", string.format("%x",rv)) end
    end
    print(i, "naks, done erasing snes.")

    --put cart in program mode
    --   swim.start()
    --   snes.prgm_mode()

    --reset flash
    dict.snes("SNES_ROM_WR", 0x8000, 0xF0)

    --return to PLAY mode
    --   print("erase play")
    --   snes.play_mode()
    --   print("erase play")
  end


  --program flashfile to the cart
  if program then
    --initialize the mapper for dumping
    --init_mapper(debug)

    --open file
    file = assert(io.open(flashfile, "rb"))
    --determine if auto-doubling, deinterleaving, etc,
    --needs done to make board compatible with rom

    --not susceptible to bus conflicts

    --flash cart
    flash.write_file(file, rom_size, snes_mapping, "SNESROM", true)
    -- close file
    assert(file:close())
  end

  -- verify flash file is on the cart
  if verify then
    --for now let's just dump the file and verify manually

    file = assert(io.open(verifyfile, "wb"))

    -- dump cart to file
    dump.dumptofile(file, rom_size, snes_mapping, "SNESROM", true)

    -- close file
    assert(file:close())
  end

  dict.io("IO_RESET")
end


-- global variables so other modules can use them


-- call functions desired to run when script is called/imported


-- functions other modules are able to call
v3.process = process

-- return the module's table
return v3
