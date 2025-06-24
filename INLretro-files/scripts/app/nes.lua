-- create the module's table
local nes = {}

-- import required modules
local dict  = require "scripts.app.dict"
local help  = require "scripts.app.help"
local log   = require "scripts.app.log"

-- file constants and global variables
local PPU_A13N_HI = 0x8000  --PPU /A13 is connected to mcu A15
local PPU_A13_HI =  0x2000  --PPU /A13 is connected to mcu A15
local FC_RF_HI = 0x20    --FC RF audio pin is EXP6 (bit5)

-- local variables
local HEADER_VERSION_NES2_0 = 0
local HEADER_VERSION_INES = 1
local HEADER_VERSION_ARCHAIC = 2

local MIRRORING_TYPE_HORIZONTAL = 0
local MIRRORING_TYPE_VERTICAL = 1
local MIRRORING_TYPE_ONE_SCREEN = 2
local MIRRORING_TYPE_FOUR_SCREENS = 3

local MIRRORING_TYPE_STRING = {
  "HORIZONTAL",
  "VERTICAL",
  "ONE SCREEN",
  "FOUR SCREENS"
}

-- local MIRRORING_TYPES = {
--   HORIZONTAL = 0,
--   VERTICAL = 1,
--   ONE_SCREEN_A = 2,
--   ONE_SCREEN_B = 3,
--   FOUR_SCREENS = 4
-- }

local header = {
  bytes = nil,
  isValid = false,
  version = nil,
  hasBattery = nil,
  hasTrainer = nil,
  mirroringType = 0,
  prgRomSize = 0,
  chrRomSize = 0,
  prgWorkRamSize = 0,
  prgSaveRamSize = 0,
  chrWorkRamSize = 0,
  chrSaveRamSize = 0,
  hasPrgRam = false,
  hasChrRam = false,
}

-- local functions

-- pass a file pointer for a file which is already open
-- leave file open when done
local function parse_header(file)

  local byte_str = file:read(16)
  -- string.rep('B', #byte_str) = 'BBBBBBBBBBBBBBBB' // 16 bytes B
  header.bytes = table.pack(string.unpack(string.rep('B', #byte_str), byte_str))

  -- check if header is valid
  if (tostring(header.bytes[1]) ~= 'N' and header.bytes[2] ~= 'E' and header.bytes[3] ~= 'S' and header.bytes[4] ~= 0x1A) then
    return false
  end
  header.isValid = true

  -- header version
  if (header.bytes[8] & 0x0C == 0x08) then
    -- If byte 7 AND $0C = $08, and the size taking into account byte 9 does not exceed the actual size of the ROM image, then NES 2.0.
    --  TODO: check byte 9
    header.version = HEADER_VERSION_NES2_0
  elseif (header.bytes[8] & 0x0C == 0x04) then
    header.version = HEADER_VERSION_ARCHAIC
  elseif (header.bytes[8] & 0x0C == 0x00) then
    if (header.bytes[13] == 0 and header.bytes[14] == 0 and header.bytes[15] == 0 and header.bytes[16] == 0) then
      header.version = HEADER_VERSION_INES
    else
      header.version = HEADER_VERSION_ARCHAIC
    end
  else
    header.version = HEADER_VERSION_ARCHAIC
  end

  -- mapper ID
  header.mapperId = ( header.bytes[7] >> 4 ) | (header.bytes[8] & 0xF0)
  if (header.version == HEADER_VERSION_NES2_0) then
    header.mapperId = header.mapperId | ( ( header.bytes[9] & 0x0F ) << 8 )
  end

  -- battery
  header.hasBattery = ( header.bytes[7] & 0x02 ) == 0x02

  -- trainer
  header.hasTrainer = ( header.bytes[7] & 0x04 ) == 0x04

  -- mirroring
  if (header.bytes[7] & 0x09 == 0) then
    header.mirroringType = MIRRORING_TYPE_HORIZONTAL
  elseif (header.bytes[7] & 0x09 == 1) then
    header.mirroringType = MIRRORING_TYPE_VERTICAL
  elseif (header.bytes[7] & 0x09 == 8) then
    header.mirroringType = MIRRORING_TYPE_ONE_SCREEN
  elseif (header.bytes[7] & 0x09 == 9) then
    header.mirroringType = MIRRORING_TYPE_FOUR_SCREENS
  end

  -- PRG ROM size | byte 9 and 4
  if (header.version == HEADER_VERSION_NES2_0) then
    if ((header.bytes[10] & 0x0F) == 0x0F) then
      -- TODO...
    else
      header.prgRomSize = (((header.bytes[10] & 0x0F) << 8) | header.bytes[5]) * 0x4000
    end
  else
    header.prgRomSize = header.bytes[5] * 0x4000
  end

  -- CHR ROM size | byte 9 and 5
  if (header.version == HEADER_VERSION_NES2_0) then
    if ((header.bytes[10] & 0xF0) == 0xF0) then
      -- TODO...
    else
      header.chrRomSize = (((header.bytes[10] & 0xF0) << 4) | header.bytes[6]) * 0x2000
    end
  else
    header.chrRomSize = header.bytes[6] * 0x2000
  end

  -- PRG WORK RAM size | byte 10 (NES2) | byte 8 (iNES)
  if (header.version == HEADER_VERSION_NES2_0) then
    header.prgWorkRamSize = header.bytes[11] & 0x0F
    if header.prgWorkRamSize == 0 then
      header.prgWorkRamSize = 0
    else
      header.prgWorkRamSize = 64 << header.prgWorkRamSize
    end
  else
    header.prgWorkRamSize = header.bytes[9] * 8
  end

  -- PRG SAVE RAM size | byte 10 (NES2)
  if (header.version == HEADER_VERSION_NES2_0) then
    header.prgSaveRamSize = header.bytes[11] & 0xF0
    if header.prgSaveRamSize == 0 then
      header.prgSaveRamSize = 0
    else
      header.prgSaveRamSize = 64 << ( header.prgSaveRamSize >> 4 )
    end
  end

  -- set hasPrgRam flag
  if header.prgWorkRamSize ~= 0 or header.prgSaveRamSize ~= 0 then
    header.hasPrgRam = true
  end

  -- CHR WORK RAM size | byte 11 (NES2)
  if (header.version == HEADER_VERSION_NES2_0) then
    header.chrWorkRamSize = header.bytes[12] & 0x0F
    if header.chrWorkRamSize == 0 then
      header.chrWorkRamSize = 0
    else
      header.chrWorkRamSize = 64 << header.chrWorkRamSize
    end
  else
    -- TODO...
  end

  -- CHR SAVE RAM size | byte 11 (NES2)
  if (header.version == HEADER_VERSION_NES2_0) then
    header.chrSaveRamSize = header.bytes[12] & 0xF0
    if header.chrSaveRamSize == 0 then
      header.chrSaveRamSize = 0
    else
      header.chrSaveRamSize = 64 << ( header.chrSaveRamSize >> 4 )
    end
  else
    -- TODO...
  end

  -- set hasChrRam flag
  if header.chrWorkRamSize ~= 0 or header.chrSaveRamSize ~= 0 then
    header.hasChrRam = true
  end

  return true
end

-- pass a file pointer for a file which is already open
-- leave file open when done
local function write_header(file, prgKB, chrKB, mapper, mirroring)

  local temp

  --bytes 0-3 always "NES <eof>"
  file:write("NES")
  file:write(string.char(0x1A))

  --byte 4 PRG-ROM 16KByte banks
  file:write(string.char(prgKB / 16))

  --byte 5 CHR-ROM 8KByte banks
  file:write(string.char(chrKB / 8))

  --byte 6      Flags 6
  --  D~7654 3210
  --    ---------
  --    NNNN FTBM
  --    |||| |||+-- Hard-wired nametable mirroring type
  --    |||| |||     0: Horizontal or mapper-controlled
  --    |||| |||     1: Vertical
  --    |||| ||+--- "Battery" and other non-volatile memory
  --    |||| ||      0: Not present
  --    |||| ||      1: Present
  --    |||| |+--- 512-byte Trainer
  --    |||| |      0: Not present
  --    |||| |      1: Present between Header and PRG-ROM data
  --    |||| +---- Hard-wired four-screen mode
  --    ||||        0: No
  --    ||||        1: Yes
  --    ++++------ Mapper Number D0..D3
  --

  --lower 4bits of mapper number
  temp = mapper & 0x0F

  temp = temp << 4

  if mirroring == "VERT" then
    temp = temp | 0x01
  elseif mirroring == "4SCRN" then
    temp = temp | 0x0A
  elseif mirroring == "1SCRNA" or mirroring == "1SCRNB" then
    temp = temp | 0x08
  end
  --else "HORZ" bit0 = 0

  file:write(string.char(temp))

  --byte7      Flags 7
  --  D~7654 3210
  --    ---------
  --    NNNN 10TT
  --    |||| ||++- Console type
  --    |||| ||     0: Nintendo Entertainment System/Family Computer
  --    |||| ||     1: Nintendo Vs. System
  --    |||| ||     2: Nintendo Playchoice 10
  --    |||| ||     3: Extended Console Type
  --    |||| ++--- NES 2.0 identifier
  --    ++++------ Mapper Number D4..D7
  --

  --upper 4bits of mapper number
  local temp = mapper & 0xF0

  file:write(string.char(temp))

  --8      Mapper MSB/Submapper
  file:write(string.char(0))
  --  D~7654 3210
  --    ---------
  --    SSSS NNNN
  --    |||| ++++- Mapper number D8..D11
  --    ++++------ Submapper number


  --9      PRG-ROM/CHR-ROM size MSB
  file:write(string.char(0))
  --  D~7654 3210
  --    ---------
  --    CCCC PPPP
  --    |||| ++++- PRG-ROM size MSB
  --    ++++------ CHR-ROM size MSB
  --


  --10     PRG-RAM/EEPROM size
  file:write(string.char(0))
  --  D~7654 3210
  --    ---------
  --    pppp PPPP
  --    |||| ++++- PRG-RAM (volatile) shift count
  --    ++++------ PRG-NVRAM/EEPROM (non-volatile) shift count
  --    If the shift count is zero, there is no PRG-(NV)RAM.
  --    If the shift count is non-zero, the actual size is
  --    "64 << shift count" bytes, i.e. 8192 bytes for a shift count of 7.
  --


  --11     CHR-RAM size
  file:write(string.char(0))
  --  D~7654 3210
  --    ---------
  --    cccc CCCC
  --    |||| ++++- CHR-RAM size (volatile) shift count
  --    ++++------ CHR-NVRAM size (non-volatile) shift count
  --    If the shift count is zero, there is no CHR-(NV)RAM.
  --    If the shift count is non-zero, the actual size is
  --    "64 << shift count" bytes, i.e. 8192 bytes for a shift count of 7.
  --


  --12     CPU/PPU Timing
  file:write(string.char(0))
  --  D~7654 3210
  --    ---------
  --    .... ..VV
  --           ++- CPU/PPU timing mode
  --           0: RP2C02 ("NTSC NES")
  --           1: RP2C07 ("Licensed PAL NES")
  --           2: Multiple-region
  --           3: UMC 6527P ("Dendy")
  --


  --13     When Byte 7 AND 3 =1: Vs. System Type
  file:write(string.char(0))
  --  D~7654 3210
  --    ---------
  --    MMMM PPPP
  --    |||| ++++- Vs. PPU Type
  --    ++++------ Vs. Hardware Type
  --
  --When Byte 7 AND 3 =3: Extended Console Type
  --  D~7654 3210
  --    ---------
  --    .... CCCC
  --         ++++- Extended Console Type
  --


  --14     Miscellaneous ROMs
  file:write(string.char(0))
  --    D~7654 3210
  --    ---------
  --    .... ..RR
  --           ++- Number of miscellaneous ROMs present
  --


  --15     Default Expansion Device
  file:write(string.char(0))
  --  D~7654 3210
  --    ---------
  --    ..DD DDDD
  --      ++-++++- Default Expansion Device

end

-- Desc:check if PPU /A13 -> CIRAM /CE jumper present
--    Does NOT check if PPU A13 is inverted and then drives CIRAM /CE
-- Pre: nes_init() been called to setup i/o
-- Post:PPU /A13 left high (disabled), all other ADDRH signals low
-- Rtn: true if jumper is set
local function jumper_ciramce_ppuA13n( debug )

  --check that we can clear CIRAM /CE with PPU /A13
  dict.pinport( "ADDR_SET", 0x0000 )
  --read CIRAM /CE pin
  if dict.pinport( "CTL_RD", "CICE" ) ~= 0 then
    if debug then print("CIRAM /CE high when /A13 low ") end
    return false
  end

  --set PPU /A13 high
  dict.pinport( "ADDR_SET", PPU_A13N_HI )
  --read CIRAM /CE pin
  if dict.pinport( "CTL_RD", "CICE" ) == 0 then
    if debug then print("CIRAM /CE low when /A13 high") end
    return false
  end

  --CICE low jumper appears to be present
  if debug then print("CIRAM /CE <- PPU /A13 jumper present") end
  return true
end

-- Desc:check if PPU A13 is inverted then drives CIRAM /CE
--  Some mappers may do this including INLXO-ROM boards
--  Does NOT check if PPU /A13 is drives CIRAM /CE
-- Pre: nes_init() been called to setup i/o
-- Post:PPU A13 left disabled (hi)
-- Rtn: true if inverted PPU A13 drives CIRAM /CE
local function ciramce_inv_ppuA13 (debug)

  --set PPU A13 low
  dict.pinport( "ADDR_SET", 0x0000 )
  -- CIRAM /CE should be high if inverted A13 is what drives it
  if dict.pinport( "CTL_RD", "CICE" ) == 0 then
    if debug then print("CIRAM /CE low when A13 low") end
    return false
  end

  --check that we can clear CIRAM /CE with PPU A13 high
  dict.pinport( "ADDR_SET", PPU_A13_HI )
  -- CIRAM /CE should be low if inverted A13 is what drives it
  if dict.pinport( "CTL_RD", "CICE" ) ~= 0 then
    if debug then print("CIRAM /CE high when A13 high") end
    return false
  end

  --CICE low jumper appears to be present
  if debug then print("CIRAM /CE <- inverse PPU A13") end
  return true
end

-- Desc:check for famicom audio in->out jumper
--  This drives EXP6 (RF out) -> EXP0 (APU in) which is backwards..
--  not much can do about that for old avr kazzo designs
--  There are probably caps/resistors for synth carts anyway
--  but to be safe only apply short pulses.
--  While we typically don't want to apply 5v to EXP port on NES carts,
--  this only does so for EXP6 which is safe on current designs.
--  All other EXP1-8 pins are only driven low.
-- Pre: nes_init() been called to setup i/o
--  which makes EXP0 floating i/p
-- Post:EXP FF left disabled and EXP0 floating
--  AXLOE pin returned to input with pullup
-- Rtn: true if jumper/connection is present
-- Test:Works on non-expansion sound carts obviously
--  Works on VRC6 and VRC7
--  Others untested
local function jumper_famicom_sound (debug)

  --EXP0 should be floating input
  --AXLOE pin needs to be set as output and
  --EXP FF needs enabled before we can clock it,
  --but don't leave it enabled before exiting function
--
  --set AXLOE to output
  dict.pinport("EXP_ENABLE")
  --Latch low first
  dict.pinport("EXP_SET", 0x00)
--  pull up FCAPU
  dict.pinport("CTL_IP_PU", "FCAPU")
  --read EXP0 Famicom APU audio pin
  if dict.pinport( "CTL_RD", "FCAPU" ) ~= 0 then
    if debug then print("RF audio out (EXP6) didn't drive APU audio in (EXP0) low") end
    dict.pinport("EXP_DISABLE")
    dict.pinport("CTL_IP_FL", "EXP0")
    return false
  end

  --Latch RF audio sound pin high
  dict.pinport("EXP_SET", FC_RF_HI)
  --read Famicom APU audio pin
  if dict.pinport( "CTL_RD", "FCAPU" ) == 0 then
    if debug then print("RF audio out (EXP6) didn't drive APU audio in (EXP0) high") end
    dict.pinport("EXP_DISABLE")
    dict.pinport("CTL_IP_FL", "EXP0")
    return false
  end

  --Famicom audio jumper appears to be present
  if debug then print("RF audio out (EXP6) is connected to APU audio in") end
  --disable EXP PORT and return EXP0 to floating if it was used
  dict.pinport("EXP_DISABLE")
  dict.pinport("CTL_IP_FL", "EXP0")
  return true
end


-- Desc:Run through supported mapper mirroring modes to help detect mapper.
-- Pre:
-- Post:cart mirroring set to found mirroring
-- Rtn: SUCCESS if nothing bad happened, neg if error with kazzo etc
local function detect_mapper_mirroring(debug)

  local read_0x2000, read_0x2400, read_0x2800, read_0x2C00

  -- log.section("Testing mirroring")

  -- if(debug) then log.point("attempting to detect NES/FC mapper via mirroring...") end
--    //TODO call mmc3 detection function
--
--    //TODO call mmc1 detection function
--
--    //fme7 and many other ASIC mappers
--
--    //none of ASIC mappers passed, assume fixed/discrete style mirroring

    dict.pinport("ADDR_SET", 0x2C00)
    read_0x2C00 = dict.pinport("CTL_RD", "CIA10")
    dict.pinport("ADDR_SET", 0x2800)
    read_0x2800 = dict.pinport("CTL_RD", "CIA10")
    dict.pinport("ADDR_SET", 0x2400)
    read_0x2400 = dict.pinport("CTL_RD", "CIA10")
    dict.pinport("ADDR_SET", 0x2000)
    read_0x2000 = dict.pinport("CTL_RD", "CIA10")

    if debug then
      print("0x2C00", "0x2800", "0x2400", "0x2000")
      print(read_0x2C00, read_0x2800, read_0x2400, read_0x2000)
    end

    ---[[
    if read_0x2000 == 0 and read_0x2400 == 0 and read_0x2800 == 0 and read_0x2C00 == 0 then
      if debug then
        log.info("One screen A mirroring sensed")
      end
      return "1SCRNA"
    elseif read_0x2000 ~= 0 and read_0x2400 ~= 0 and read_0x2800 ~= 0 and read_0x2C00 ~= 0 then
      if debug then
        log.info("One screen B mirroring sensed")
      end
      return "1SCRNB"
    elseif read_0x2000 == 0 and read_0x2800 == 0 and read_0x2400 ~= 0 and read_0x2C00 ~= 0 then
      if debug then
        log.info("Vertical mirroring sensed")
      end
      return "VERT"
    elseif read_0x2000 == 0 and read_0x2400 == 0 and read_0x2800 ~= 0 and read_0x2C00 ~= 0 then
      if debug then
        log.info("Horizontal mirroring sensed")
      end
      return "HORZ"
    end
    --]]

    --[[
    rv = dict.nes("CIRAM_A10_MIRROR")
    if (rv == op_nes["MIR_VERT"]) then
      if debug then log.info("Vertical mirroring sensed") end
      return "VERT"
    elseif rv == op_nes["MIR_HORZ"] then
      if debug then log.info("Horizontal mirroring sensed") end
      return "HORZ"
    elseif rv == op_nes["MIR_1SCRNA"] then
      if debug then log.info("One screen A mirroring sensed") end
      return "1SCRNA"
    elseif rv == op_nes["MIR_1SCRNB"] then
      if debug then log.info("One screen B mirroring sensed") end
      return "1SCRNB"
    end
    --]]

    -- Rtn: VERT/HORZ/1SCRNA/1SCRNB
  return nil
end


-- verify the ciccom software mirroring switch is working properly
local function test_cic_soft_switch (debug)
end

-- Desc:CHR-ROM flash manf/prod ID sense test
--  Only senses SST flash ID's
--  Does not make CHR bank writes so A14-A13 must be made valid outside of this funciton
--  An NROM board does this by tieing A14:13 to A12:11
--  Other mappers will pass this function if PT0 has A14:13=01, PT1 has A14:13=10
--  Assumes that isn't getting tricked by having manf/prodID at $0000/0001
--  could add check and increment read address to ensure doesn't get tricked..
-- Pre: nes_init() been called to setup i/o
-- Post:memory manf/prod ID set to read values if passed
--  memory wr_dict and wr_opcode set if successful
--  Software mode exited if entered successfully
-- Rtn: SUCCESS if flash sensed, GEN_FAIL if not, neg if error
local function read_flashID_chrrom_8K (debug)

  local rv
  --enter software mode
  --NROM has A13 tied to A11, and A14 tied to A12.
  --So only A0-12 needs to be valid
  --A13 needs to be low to address CHR-ROM
  --      15 14 13 12
  -- 0x5 = 0b  0  1  0  1  -> $1555
  -- 0x2 = 0b  0  0  1  0  -> $0AAA
  dict.nes("NES_PPU_WR", 0x1555, 0xAA)
  dict.nes("NES_PPU_WR", 0x0AAA, 0x55)
  dict.nes("NES_PPU_WR", 0x1555, 0x90)
  --read manf ID
  rv = dict.nes("NES_PPU_RD", 0x0000)
  if debug then print("attempted read CHR-ROM manf ID:", help.hex(rv)) end
--  if ( rv[RV_DATA0_IDX] != SST_MANF_ID ) {
--    return GEN_FAIL;
--    //no need for software exit since failed to enter
--  }
--
  --read prod ID
  rv = dict.nes("NES_PPU_RD", 0x0001)
  if debug then print("attempted read CHR-ROM prod ID:", help.hex(rv)) end
--  if ( (rv[RV_DATA0_IDX] == SST_PROD_128)
--  ||   (rv[RV_DATA0_IDX] == SST_PROD_256)
--  ||   (rv[RV_DATA0_IDX] == SST_PROD_512) ) {
--    //found expected manf and prod ID
--    flash->manf = SST_MANF_ID;
--    flash->part = rv[RV_DATA0_IDX];
--    flash->wr_dict = DICT_NES;
--    flash->wr_opcode = NES_PPU_WR;
--  }
--
  -- exit software
  dict.nes("NES_PPU_WR", 0x0000, 0xF0)

  --return true
end


--/* Desc:Simple CHR-RAM sense test
-- *  A more thourough test should be implemented in firmware
-- *  This one simply tests one address in PPU address space
-- * Pre: nes_init() been called to setup i/o
-- * Post:
-- * Rtn: SUCCESS if ram sensed, GEN_FAIL if not, neg if error
-- */
--int ppu_ram_sense( USBtransfer *transfer, uint16_t addr ) {
local function ppu_ram_sense(addr, debug)

  local res = true

  log.section("Trying to sense CHR-RAM")

  --write 0xAA to addr
  dict.nes("NES_PPU_WR", addr, 0xAA)

  --try to read it back
  if (dict.nes("NES_PPU_RD", addr) ~= 0xAA) then
    if debug then log.bullet("could not write 0xAA to PPU ".. help.hex(addr, 4, "$")) end
    res = false
  end

  --write 0x55 to addr
  dict.nes("NES_PPU_WR", addr, 0x55)

  --try to read it back
  if (dict.nes("NES_PPU_RD", addr) ~= 0x55) then
    if debug then log.bullet("could not write 0x55 to PPU ".. help.hex(addr, 4, "$")) end
    res = false
  end

  if res then
    log.success("CHR-RAM detected @ PPU ".. help.hex(addr, 4, "$"))
  else
    log.info("CHR-RAM not detected @ PPU ".. help.hex(addr, 4, "$"))
  end

  return res

end

-- Desc:PRG-ROM flash manf/prod ID sense test
--  Using EXP0 /WE writes
--  Only senses SST flash ID's
--  Assumes that isn't getting tricked by having manf/prodID at $8000/8001
--  could add check and increment read address to ensure doesn't get tricked..
-- Pre: nes_init() been called to setup i/o
--  exp0 pullup test must pass
--  if ROM A14 is mapper controlled it must be low when CPU A14 is low
--  controlling A14 outside of this function acts as a means of bank size detection
-- Post:memory manf/prod ID set to read values if passed
--  memory wr_dict and wr_opcode set if successful
--  Software mode exited if entered successfully
-- Rtn: SUCCESS if flash sensed, GEN_FAIL if not, neg if error
local function read_flashID_prgrom_exp0 (debug)
  local rv
  --enter software mode
  --ROMSEL controls PRG-ROM /OE which needs to be low for flash writes
  --So unlock commands need to be addressed below $8000
  --DISCRETE_EXP0_PRGROM_WR doesn't toggle /ROMSEL by definition though, so A15 is unused
  --      15 14 13 12
  -- 0x5 = 0b  0  1  0  1  -> $5555
  -- 0x2 = 0b  0  0  1  0  -> $2AAA
  dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x5555, 0xAA)
  dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x2AAA, 0x55)
  dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x5555, 0x90)
  --read manf ID
  rv = dict.nes("NES_CPU_RD", 0x8000)
  if debug then print("attempted read PRG-ROM manf ID:", help.hex(rv)) end
--  debug("manf id: %x", rv[RV_DATA0_IDX]);
--  if ( rv[RV_DATA0_IDX] != SST_MANF_ID ) {
--    return GEN_FAIL;
--    //no need for software exit since failed to enter
--  }
--
  --read prod ID
  rv = dict.nes("NES_CPU_RD", 0x8001)
  if debug then print("attempted read PRG-ROM prod ID:", help.hex(rv)) end
--  if ( (rv[RV_DATA0_IDX] == SST_PROD_128)
--  ||   (rv[RV_DATA0_IDX] == SST_PROD_256)
--  ||   (rv[RV_DATA0_IDX] == SST_PROD_512) ) {
--    //found expected manf and prod ID
--    flash->manf = SST_MANF_ID;
--    flash->part = rv[RV_DATA0_IDX];
--    flash->wr_dict = DICT_NES;
--    flash->wr_opcode = DISCRETE_EXP0_PRGROM_WR;
--  }
--
  -- exit software
  dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x8000, 0xF0)
  --verify exited
--  rv = dict.nes("NES_CPU_RD", 0x8001)
--  if debug then print("attempted read PRG-ROM prod ID:", help.hex(rv)) end

  return true
end

--[[
  .dP'     8888b.  888888 88""Yb 88   88  dP""b8     888888 88   88 88b 88  dP""b8 .dP"Y8
.dP'        8I  Yb 88__   88__dP 88   88 dP   `"     88__   88   88 88Yb88 dP   `" `Ybo."
`Yb.        8I  dY 88""   88""Yb Y8   8P Yb  "88     88""   Y8   8P 88 Y88 Yb      o.`Y8b
  `Yb.     8888Y"  888888 88oodP `YbodP'  YboodP     88     `YbodP' 88  Y8  YboodP 8bodP'
]]

local function cpu_wr(addr, val, debug, comment)
  if not (type(debug) == "boolean") then debug = true end
  if not (type(comment) == "string") then comment = "" end
  dict.nes("NES_CPU_WR", addr, val)
  if (debug) then log.point("CPU", " W", help.hex(addr, 4, "0x"), val, help.hex(val, 2, "0x"), comment) end
end

local function cpu_rd(addr, debug, label)
  if not (type(debug) == "boolean") then debug = true end
  if not (type(label) == "string") then label = "" end
  local rv
  rv = dict.nes("NES_CPU_RD", addr)
  if (debug) then log.point("CPU", "R ", help.hex(addr, 4, "0x"), rv, help.hex(rv, 2, "0x"), label) end
  return rv
end

local function ppu_wr(addr, val, debug, comment)
  if not (type(debug) == "boolean") then debug = true end
  if not (type(comment) == "string") then comment = "" end
  dict.nes("NES_PPU_WR", addr, val)
  if (debug) then log.point("PPU", " W", help.hex(addr, 4, "0x"), val, help.hex(val, 2, "0x"), comment) end
end

local function ppu_rd(addr, debug, label)
  if not (type(debug) == "boolean") then debug = true end
  if not (type(label) == "string") then label = "" end
  local rv
  rv = dict.nes("NES_PPU_RD", addr)
  if (debug) then log.point("PPU", "R ", help.hex(addr, 4, "0x"), rv, help.hex(rv, 2, "0x"), label) end
  return rv
end

nes.cpu_rd = cpu_rd
nes.cpu_wr = cpu_wr
nes.ppu_rd = ppu_rd
nes.ppu_wr = ppu_wr

--[[
8888b.  888888 88""Yb 88   88  dP""b8     888888 88   88 88b 88  dP""b8 .dP"Y8     `Yb.
 8I  Yb 88__   88__dP 88   88 dP   `"     88__   88   88 88Yb88 dP   `" `Ybo."       `Yb.
 8I  dY 88""   88""Yb Y8   8P Yb  "88     88""   Y8   8P 88 Y88 Yb      o.`Y8b       .dP'
8888Y"  888888 88oodP `YbodP'  YboodP     88     `YbodP' 88  Y8  YboodP 8bodP'     .dP'
]]

-- global variables so other modules can use them


-- call functions desired to run when script is called/imported


-- functions other modules are able to call
nes.jumper_ciramce_ppuA13n = jumper_ciramce_ppuA13n
nes.ciramce_inv_ppuA13 = ciramce_inv_ppuA13
nes.jumper_famicom_sound = jumper_famicom_sound
nes.detect_mapper_mirroring = detect_mapper_mirroring
nes.test_cic_soft_switch = test_cic_soft_switch
nes.ppu_ram_sense = ppu_ram_sense
nes.read_flashID_chrrom_8K = read_flashID_chrrom_8K
nes.read_flashID_prgrom_exp0 = read_flashID_prgrom_exp0
nes.write_header = write_header
nes.parse_header = parse_header
nes.header = header
nes.MIRRORING_TYPE_HORIZONTAL = MIRRORING_TYPE_HORIZONTAL
nes.MIRRORING_TYPE_VERTICAL = MIRRORING_TYPE_VERTICAL
nes.MIRRORING_TYPE_ONE_SCREEN = MIRRORING_TYPE_ONE_SCREEN
nes.MIRRORING_TYPE_FOUR_SCREENS = MIRRORING_TYPE_FOUR_SCREENS
nes.MIRRORING_TYPE_STRING = MIRRORING_TYPE_STRING

-- return the module's table
return nes

-- old C file:
--
--
--
--/* Desc:PRG-ROM flash manf/prod ID sense test
-- *  Using mapper 30 defined PRG-ROM flash writes
-- *  Only senses SST flash ID's
-- *  Assumes that isn't getting tricked by having manf/prodID at $8000/8001
-- *  could add check and increment read address to ensure doesn't get tricked..
-- * Pre: nes_init() been called to setup i/o
-- * Post:memory manf/prod ID set to read values if passed
-- *  memory wr_dict and wr_opcode set if successful
-- *  Software mode exited if entered successfully
-- * Rtn: SUCCESS if flash sensed, GEN_FAIL if not, neg if error
-- */
--int read_flashID_prgrom_map30( USBtransfer *transfer, memory *flash ) {
--
--  uint8_t rv[RV_DATA0_IDX];
--
  --enter software mode
  --$8000-BFFF writes to flash
  --$C000-FFFF writes to mapper
  --      15 14 13 12
  -- 0x5 = 0b  0  1  0  1  -> $9555
  -- 0x2 = 0b  0  0  1  0  -> $2AAA
  --set A14 in mapper reg for $5555 command
--  dictionary_call( transfer, DICT_NES,   NES_CPU_WR,  0xC000,    0x01,
--                  USB_IN,    NULL,  1);
  --write $5555 0xAA
--  dictionary_call( transfer, DICT_NES,   NES_CPU_WR,  0x9555,    0xAA,
--                  USB_IN,    NULL,  1);
  --clear A14 in mapper reg for $2AAA command
--  dictionary_call( transfer, DICT_NES,   NES_CPU_WR,  0xC000,    0x00,
--                  USB_IN,    NULL,  1);
  --write $2AAA 0x55
--  dictionary_call( transfer, DICT_NES,   NES_CPU_WR,  0xAAAA,    0x55,
--                  USB_IN,    NULL,  1);
  --set A14 in mapper reg for $5555 command
--  dictionary_call( transfer, DICT_NES,   NES_CPU_WR,  0xC000,    0x01,
--                  USB_IN,    NULL,  1);
  --write $5555 0x90 for software mode
--  dictionary_call( transfer, DICT_NES,   NES_CPU_WR,  0x9555,    0x90,
--                  USB_IN,    NULL,  1);
--
  --read manf ID
--  dictionary_call( transfer, DICT_NES,   NES_CPU_RD,      0x8000,    NILL,
--                USB_IN,    rv,  RV_DATA0_IDX+1);
--  debug("manf id: %x", rv[RV_DATA0_IDX]);
--  if ( rv[RV_DATA0_IDX] != SST_MANF_ID ) {
--    return GEN_FAIL;
--    //no need for software exit since failed to enter
--  }
--
  --read prod ID
--  dictionary_call( transfer, DICT_NES,   NES_CPU_RD,      0x8001,    NILL,
--                USB_IN,    rv,  RV_DATA0_IDX+1);
--  debug("prod id: %x", rv[RV_DATA0_IDX]);
--  if ( (rv[RV_DATA0_IDX] == SST_PROD_128)
--  ||   (rv[RV_DATA0_IDX] == SST_PROD_256)
--  ||   (rv[RV_DATA0_IDX] == SST_PROD_512) ) {
--    //found expected manf and prod ID
--    flash->manf = SST_MANF_ID;
--    flash->part = rv[RV_DATA0_IDX];
--    flash->wr_dict = DICT_NES;
--    flash->wr_opcode = NES_CPU_WR;
--  }
--
  -- exit software
--  dictionary_call( transfer, DICT_NES,   NES_CPU_WR,  0x8000,    0xF0,
--                  USB_IN,    NULL,  1);
--
  --verify exited
--  dictionary_call( transfer, DICT_NES,   NES_CPU_RD,      0x8000,    NILL,
--                USB_IN,    rv,  RV_DATA0_IDX+1);
--  debug("prod id: %x", rv[RV_DATA0_IDX]);
--
--  return SUCCESS;
--}
