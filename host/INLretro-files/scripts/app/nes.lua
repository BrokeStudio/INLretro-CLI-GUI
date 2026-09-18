-- create the module's table
local nes                         = {}

-- import required modules
local chips                       = require "scripts.app.chips"
local dict                        = require "scripts.app.dict"
local dump                        = require "scripts.app.dump"
local flash                       = require "scripts.app.flash"
local files                       = require "scripts.app.files"
local help                        = require "scripts.app.help"
local log                         = require "scripts.app.log"
local spinner                     = require "scripts.app.spinner"
local time                        = require "scripts.app.time"

-- file constants and global variables
local PPU_A13N_HI                 = 0x8000 -- PPU /A13 is connected to mcu A15
local PPU_A13_HI                  = 0x2000 -- PPU /A13 is connected to mcu A15
local FC_RF_HI                    = 0x20   -- FC RF audio pin is EXP6 (bit5)

-- local variables
local HEADER_VERSION_NES2_0       = 0
local HEADER_VERSION_INES         = 1
local HEADER_VERSION_ARCHAIC      = 2

local MIRRORING_TYPE_HORIZONTAL   = 0
local MIRRORING_TYPE_VERTICAL     = 1
local MIRRORING_TYPE_ONE_SCREEN   = 2
local MIRRORING_TYPE_FOUR_SCREENS = 3

local MIRRORING_TYPE_STRING       = {
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

local header                      = {
  bytes = nil,
  is_valid = false,
  version = nil,
  mapper_id = nil,
  has_battery = nil,
  has_trainer = nil,
  mirroring_type = 0,
  prg_rom_size = 0,
  chr_rom_size = 0,
  prg_work_ram_size = 0,
  prg_save_ram_size = 0,
  chr_work_ram_size = 0,
  chr_save_ram_size = 0,
  has_prg_ram = false,
  has_chr_ram = false,
  rom_file_size = 0,
}

-- local functions

-- pass a file pointer for a file which is already open
-- leave file open when done
local function parse_header(file)
  header.rom_file_size = file:seek("end") - 16

  file:seek("set", 0)
  local byte_str = file:read(16)
  -- string.rep('B', #byte_str) = 'BBBBBBBBBBBBBBBB' // 16 bytes B
  header.bytes = table.pack(string.unpack(string.rep('B', #byte_str), byte_str))

  -- check if header is valid
  if (tostring(header.bytes[1]) ~= 'N' and header.bytes[2] ~= 'E' and header.bytes[3] ~= 'S' and header.bytes[4] ~= 0x1A) then
    return false
  end
  header.is_valid = true

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
  header.mapper_id = (header.bytes[7] >> 4) | (header.bytes[8] & 0xF0)
  if (header.version == HEADER_VERSION_NES2_0) then
    header.mapper_id = header.mapper_id | ((header.bytes[9] & 0x0F) << 8)
  end

  -- battery
  header.has_battery = (header.bytes[7] & 0x02) == 0x02

  -- trainer
  header.has_trainer = (header.bytes[7] & 0x04) == 0x04

  -- mirroring
  if (header.bytes[7] & 0x09 == 0) then
    header.mirroring_type = MIRRORING_TYPE_HORIZONTAL
  elseif (header.bytes[7] & 0x09 == 1) then
    header.mirroring_type = MIRRORING_TYPE_VERTICAL
  elseif (header.bytes[7] & 0x09 == 8) then
    header.mirroring_type = MIRRORING_TYPE_ONE_SCREEN
  elseif (header.bytes[7] & 0x09 == 9) then
    header.mirroring_type = MIRRORING_TYPE_FOUR_SCREENS
  end

  -- PRG ROM size | byte 9 and 4
  if (header.version == HEADER_VERSION_NES2_0) then
    if ((header.bytes[10] & 0x0F) == 0x0F) then
      header.prg_rom_size = 2 ^ (header.bytes[5] >> 2) * ((header.bytes[5] & 0x03) * 2 + 1)
    else
      header.prg_rom_size = (((header.bytes[10] & 0x0F) << 8) | header.bytes[5]) * 0x4000
    end
  else
    header.prg_rom_size = header.bytes[5] * 0x4000
  end

  -- CHR ROM size | byte 9 and 5
  if (header.version == HEADER_VERSION_NES2_0) then
    if ((header.bytes[10] & 0xF0) == 0xF0) then
      header.chr_rom_size = 2 ^ (header.bytes[6] >> 2) * ((header.bytes[6] & 0x03) * 2 + 1)
    else
      header.chr_rom_size = (((header.bytes[10] & 0xF0) << 4) | header.bytes[6]) * 0x2000
    end
  else
    header.chr_rom_size = header.bytes[6] * 0x2000
  end

  if header.rom_file_size ~= (header.prg_rom_size) + (header.chr_rom_size) then
    log.error("ROM file size (" ..
      header.rom_file_size ..
      ") does not match header PRG-ROM and CHR-ROM sizes (" ..
      header.chr_rom_size .. " + " .. header.chr_rom_size .. " = " .. header.prg_rom_size + header.chr_rom_size .. ")")
    return false
  end

  -- PRG WORK RAM size | byte 10 (NES2) | byte 8 (iNES)
  if (header.version == HEADER_VERSION_NES2_0) then
    header.prg_work_ram_size = header.bytes[11] & 0x0F
    if header.prg_work_ram_size == 0 then
      header.prg_work_ram_size = 0
    else
      header.prg_work_ram_size = 64 << header.prg_work_ram_size
    end
  else
    header.prg_work_ram_size = header.bytes[9] * 8
  end

  -- PRG SAVE RAM size | byte 10 (NES2)
  if (header.version == HEADER_VERSION_NES2_0) then
    header.prg_save_ram_size = header.bytes[11] & 0xF0
    if header.prg_save_ram_size == 0 then
      header.prg_save_ram_size = 0
    else
      header.prg_save_ram_size = 64 << (header.prg_save_ram_size >> 4)
    end
  end

  -- set has_prg_ram flag
  if header.prg_work_ram_size ~= 0 or header.prg_save_ram_size ~= 0 then
    header.has_prg_ram = true
  end

  -- CHR WORK RAM size | byte 11 (NES2)
  if (header.version == HEADER_VERSION_NES2_0) then
    header.chr_work_ram_size = header.bytes[12] & 0x0F
    if header.chr_work_ram_size == 0 then
      header.chr_work_ram_size = 0
    else
      header.chr_work_ram_size = 64 << header.chr_work_ram_size
    end
  else
    header.chr_work_ram_size = header.chr_rom_size == 0 and 0x2000 or 0
  end

  -- CHR SAVE RAM size | byte 11 (NES2)
  if (header.version == HEADER_VERSION_NES2_0) then
    header.chr_save_ram_size = header.bytes[12] & 0xF0
    if header.chr_save_ram_size == 0 then
      header.chr_save_ram_size = 0
    else
      header.chr_save_ram_size = 64 << (header.chr_save_ram_size >> 4)
    end
  else
    header.chr_save_ram_size = 0
  end

  -- set has_chr_ram flag
  if header.chr_work_ram_size ~= 0 or header.chr_save_ram_size ~= 0 then
    header.has_chr_ram = true
  end

  return true
end

-- pass a file pointer for a file which is already open
-- leave file open when done
local function write_header(file, prg_kb, chr_kb, mapper, mirroring)
  local temp

  --bytes 0-3 always "NES <eof>"
  file:write("NES")
  file:write(string.char(0x1A))

  --byte 4 PRG-ROM 16KByte banks
  file:write(string.char(prg_kb / 16))

  --byte 5 CHR-ROM 8KByte banks
  file:write(string.char(chr_kb / 8))

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

--- Write a byte to the NES CPU bus.
-- @param addr integer CPU address
-- @param val integer Byte to write
-- @param options? table Write options
-- @param options.debug? boolean Log the address and value; defaults to false
-- @param options.comment? string Text appended to the debug log; defaults to an empty string
-- @param options.opcode? string Dictionary opcode; defaults to NES_CPU_WR
local function cpu_wr(addr, val, options)
  options = options or {}
  local debug = options.debug or false
  local comment = options.comment or ""
  local opcode = options.opcode or "NES_CPU_WR"

  dict.nes(opcode, addr, val)
  if (debug) then log.point("CPU", " W", help.hex(addr, 4, "0x"), val, help.hex(val, 2, "0x"), comment) end
end

--- Read a byte from the NES CPU bus.
-- @param addr integer CPU address
-- @param options? table Read options
-- @param options.debug? boolean Log the address and value; defaults to false
-- @param options.label? string Text appended to the debug log; defaults to an empty string
-- @param options.opcode? string Dictionary opcode; defaults to NES_CPU_RD
-- @return integer value Byte read from the CPU bus
local function cpu_rd(addr, options)
  options = options or {}
  local debug = options.debug or false
  local label = options.label or ""
  local opcode = options.opcode or "NES_CPU_RD"
  local rv
  rv = dict.nes(opcode, addr)
  if (debug) then log.point("CPU", "R ", help.hex(addr, 4, "0x"), rv, help.hex(rv, 2, "0x"), label) end
  return rv
end

--- Write a byte to the NES PPU bus.
-- @param addr integer PPU address
-- @param val integer Byte to write
-- @param options? table Write options
-- @param options.debug? boolean Log the address and value; defaults to false
-- @param options.comment? string Text appended to the debug log; defaults to an empty string
-- @param options.opcode? string Dictionary opcode; defaults to NES_PPU_WR
local function ppu_wr(addr, val, options)
  options = options or {}
  local debug = options.debug or false
  local comment = options.comment or ""
  local opcode = options.opcode or "NES_PPU_WR"

  dict.nes(opcode, addr, val)
  if (debug) then log.point("PPU", " W", help.hex(addr, 4, "0x"), val, help.hex(val, 2, "0x"), comment) end
end

--- Read a byte from the NES PPU bus.
-- @param addr integer PPU address
-- @param options? table Read options
-- @param options.debug? boolean Log the address and value; defaults to false
-- @param options.label? string Text appended to the debug log; defaults to an empty string
-- @param options.opcode? string Dictionary opcode; defaults to NES_PPU_RD
-- @return integer value Byte read from the PPU bus
local function ppu_rd(addr, options)
  options = options or {}
  local debug = options.debug or false
  local label = options.label or ""
  local opcode = options.opcode or "NES_PPU_RD"
  local rv
  rv = dict.nes(opcode, addr)
  if (debug) then log.point("PPU", "R ", help.hex(addr, 4, "0x"), rv, help.hex(rv, 2, "0x"), label) end
  return rv
end

-- -- Desc: check if PPU /A13 -> CIRAM /CE jumper present
-- --       Does NOT check if PPU A13 is inverted and then drives CIRAM /CE
-- -- Pre:  nes_init() been called to setup i/o
-- -- Post: PPU /A13 left high (disabled), all other ADDRH signals low
-- -- Rtn:  true if jumper is set
-- local function jumper_ciramce_ppuA13n(debug)
--   --check that we can clear CIRAM /CE with PPU /A13
--   dict.pinport("ADDR_SET", 0x0000)
--   --read CIRAM /CE pin
--   if dict.pinport("CTL_RD", "CICE") ~= 0 then
--     if debug then print("CIRAM /CE high when /A13 low ") end
--     return false
--   end

--   --set PPU /A13 high
--   dict.pinport("ADDR_SET", PPU_A13N_HI)
--   --read CIRAM /CE pin
--   if dict.pinport("CTL_RD", "CICE") == 0 then
--     if debug then print("CIRAM /CE low when /A13 high") end
--     return false
--   end

--   --CICE low jumper appears to be present
--   if debug then print("CIRAM /CE <- PPU /A13 jumper present") end
--   return true
-- end

-- -- Desc: check if PPU A13 is inverted then drives CIRAM /CE
-- --       Some mappers may do this including INLXO-ROM boards
-- --       Does NOT check if PPU /A13 is drives CIRAM /CE
-- -- Pre:  nes_init() been called to setup i/o
-- -- Post: PPU A13 left disabled (hi)
-- -- Rtn:  true if inverted PPU A13 drives CIRAM /CE
-- local function ciramce_inv_ppuA13(debug)
--   --set PPU A13 low
--   dict.pinport("ADDR_SET", 0x0000)
--   -- CIRAM /CE should be high if inverted A13 is what drives it
--   if dict.pinport("CTL_RD", "CICE") == 0 then
--     if debug then print("CIRAM /CE low when A13 low") end
--     return false
--   end

--   --check that we can clear CIRAM /CE with PPU A13 high
--   dict.pinport("ADDR_SET", PPU_A13_HI)
--   -- CIRAM /CE should be low if inverted A13 is what drives it
--   if dict.pinport("CTL_RD", "CICE") ~= 0 then
--     if debug then print("CIRAM /CE high when A13 high") end
--     return false
--   end

--   --CICE low jumper appears to be present
--   if debug then print("CIRAM /CE <- inverse PPU A13") end
--   return true
-- end

-- Desc: check for famicom audio in->out jumper
--       This drives EXP6 (RF out) -> EXP0 (APU in) which is backwards..
--       not much can do about that for old avr kazzo designs
--       There are probably caps/resistors for synth carts anyway
--       but to be safe only apply short pulses.
--       While we typically don't want to apply 5v to EXP port on NES carts,
--       this only does so for EXP6 which is safe on current designs.
--       All other EXP1-8 pins are only driven low.
-- Pre:  nes_init() been called to setup i/o
--       which makes EXP0 floating i/p
-- Post: EXP FF left disabled and EXP0 floating
--       AXLOE pin returned to input with pullup
-- Rtn:  true if jumper/connection is present
-- Test: Works on non-expansion sound carts obviously
--       Works on VRC6 and VRC7
--       Others untested
local function jumper_famicom_sound(debug)
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
  if dict.pinport("CTL_RD", "FCAPU") ~= 0 then
    if debug then print("RF audio out (EXP6) didn't drive APU audio in (EXP0) low") end
    dict.pinport("EXP_DISABLE")
    dict.pinport("CTL_IP_FL", "EXP0")
    return false
  end

  --Latch RF audio sound pin high
  dict.pinport("EXP_SET", FC_RF_HI)
  --read Famicom APU audio pin
  if dict.pinport("CTL_RD", "FCAPU") == 0 then
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


-- Desc: Run through supported mapper mirroring modes to help detect mapper.
-- Pre:
-- Post: cart mirroring set to found mirroring
-- Rtn:  SUCCESS if nothing bad happened, neg if error with kazzo etc
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
  return "UNKNOWN"
end

--- Find a sequential bank-number table in the final bank of a ROM file.
-- Searches the final bank_size_kb * 1024 bytes for consecutive bank numbers
-- from zero through math.floor(prg_size_kb / bank_size_kb) - 1.
-- @param filename string Path to the binary ROM file.
-- @param prg_size_kb number Total PRG ROM size in kilobytes.
-- @param bank_size_kb number Optional bank size in kilobytes (default: 16).
-- @return number|nil CPU address of the table, with the final bank mapped
-- below 0x10000, or nil if no complete table is found.
local function find_bank_table_in_last_bank(filename, prg_size_kb, bank_size_kb)
  local last_bank_size_kb = bank_size_kb or 16 -- use 16KB bank by default
  local banks = math.floor(prg_size_kb / last_bank_size_kb)
  local bytes_found = 0
  local bank_table_base = 0
  local bank_size = last_bank_size_kb * 1024
  local rom_file = assert(io.open(filename, "rb"))
  local file_size = rom_file:seek("end")
  local last_bank_offset = file_size - bank_size

  -- check last bank
  for i = 0, bank_size - 1, 1 do
    -- set cursor
    rom_file:seek("set", last_bank_offset + i)

    -- read one byte
    local byte = string.unpack("B", rom_file:read(1), 1)
    -- if it's zero, reset tracking vars and update bank table address
    if byte == 0 then
      bank_table_base = 0x10000 - bank_size + i
      bytes_found = 1
    elseif byte == bytes_found then
      -- update tracking vars
      bytes_found = bytes_found + 1

      -- found all bytes?
      if bytes_found == banks then
        break
      end
    else
      -- reset tracking vars
      bytes_found = 0
    end
  end

  assert(rom_file:close())

  if bytes_found == banks then
    return bank_table_base
  else
    return nil
  end
end

--- Find a sequential bank-number table shared by all 32 KB PRG ROM banks.
-- Searches for consecutive bank numbers from zero through
-- math.floor(prg_size_kb / 32) - 1 at identical offsets in every bank.
-- @param filename string Path to the binary ROM file.
-- @param prg_size_kb number Total PRG ROM size in kilobytes.
-- @return number|nil CPU address of the table with banks mapped at 0x8000,
-- or nil if no complete table is found.
local function find_bank_table_32(filename, prg_size_kb)
  local banks = math.floor(prg_size_kb / 32)
  local bytes_found = 0
  local bank_table_base = 0
  local bank_size = 32 * 1024
  local romfile = assert(io.open(filename, "rb"))

  -- check first bank
  for i = 0, bank_size - 1, 1 do
    -- set cursor
    romfile:seek("set", i)

    -- read one byte
    local byte = string.unpack("B", romfile:read(1), 1)

    -- do we have a matching byte across banks?
    local match = true
    for b = 1, banks - 1, 1 do
      -- set cursor
      romfile:seek("set", b * bank_size + i)

      -- read byte
      local byte2 = string.unpack("B", romfile:read(1), 1)

      -- control byte
      if byte2 ~= byte then
        match = false
        break
      end
    end

    -- bytes match?
    if match then
      -- if it's zero, reset tracking vars and update bank table address
      if byte == 0 then
        bank_table_base = (i & 0xffff) + 0x8000
        bytes_found = 1
      elseif byte == bytes_found then
        -- update tracking vars
        bytes_found = bytes_found + 1

        -- found all bytes?
        if bytes_found == banks then
          break
        end
      else
        -- reset tracking vars
        bytes_found = 0
      end
    else
      -- reset tracking vars
      bytes_found = 0
    end
  end

  assert(romfile:close())

  if bytes_found == banks then
    return bank_table_base
  else
    return nil
  end
end

--- Read and identify the PRG-ROM flash manufacturer in software identification mode.
-- The caller must enter identification mode and reset the flash afterward.
-- Both short and long profiles read the manufacturer ID at CPU address 0x8000.
-- Other profile names, including nil, return false and an empty table without reading the bus.
-- @param options table Selected unlock profile and read options
-- @param options.unlock_profile_name string Short or long unlock profile
-- @param options.debug? boolean Log the read attempt and CPU read; defaults to false
-- @return boolean found True when recognized, false when unknown or the profile is unsupported
-- @return table manufacturer Manufacturer name and ID, or an empty table when unknown or the profile is unsupported
local function prg_rom_get_manufacturer(options)
  local manufacturer_id

  if options.debug then log.info("Trying to read manufacturer id") end

  if options.unlock_profile_name == "short" or options.unlock_profile_name == "long" then
    manufacturer_id = cpu_rd(0x8000, { debug = options.debug })
    return chips.get_manufacturer(manufacturer_id)
  end

  return false, {}
end

--- Read and identify the PRG-ROM flash device in software identification mode.
-- The caller must enter identification mode and reset the flash afterward.
-- Both profiles first read the device ID at CPU address 0x8001.
-- If the short-profile ID is unknown, reads 0x8002, 0x801C, and 0x801E
-- as the high, middle, and low bytes of a 24-bit device ID.
-- Other profile names, including nil, cause the function to return no values.
-- @param options table Detected manufacturer, unlock profile, and read options
-- @param options.manufacturer table Manufacturer information containing its id
-- @param options.unlock_profile_name string Short or long unlock profile
-- @param options.debug? boolean Log the read attempt and CPU reads; defaults to false
-- @return boolean|nil found True when the manufacturer/device pair is recognized, false when unknown, or nil for other profiles
-- @return table|nil device Chip information, an empty table when unknown, or nil for other profiles
local function prg_rom_get_device(options)
  local device_id
  local device
  local found

  if options.debug then log.info("Trying to read device id") end

  if options.unlock_profile_name == "short" then
    device_id = cpu_rd(0x8001, { debug = options.debug })
    found, device = chips.get_device(options.manufacturer.id, device_id)

    if not found then
      device_id = cpu_rd(0x8002, { debug = options.debug }) << 16
      device_id = device_id | (cpu_rd(0x801C, { debug = options.debug }) << 8)
      device_id = device_id | cpu_rd(0x801E, { debug = options.debug })
      found, device = chips.get_device(options.manufacturer.id, device_id)
    end

    return found, device
  elseif options.unlock_profile_name == "long" then
    device_id = cpu_rd(0x8001, { debug = options.debug })
    return chips.get_device(options.manufacturer.id, device_id)
  end
end

--- Detect the PRG-ROM flash chip by trying manufacturer/device identification for each profile.
-- Tries only the supplied profile, or long then short until a device is recognized.
-- Sends the 0xAA/0x55/0x90 identification sequence using each profile's resolved addresses
-- before reading the manufacturer and device IDs.
-- Logs each recognized manufacturer even if its device is unknown.
-- Adds opcode and addr_base defaults to the supplied options; uses a separate table per attempt.
-- Address overrides must be supplied together.
-- Validates each profile before hardware access, then resets before and after identification.
-- Unknown profiles are logged and skipped.
-- @param debug? boolean Log the selected profile, write addresses, and CPU reads and writes
-- @param options? table Flash access options
-- @param options.opcode? string Flash write opcode; defaults to NES_CPU_WR
-- @param options.addr_base? integer Mask bitwise-ORed with profile addresses when no overrides are supplied; defaults to 0x8000
-- @param options.unlock_profile_name? string Restrict probing to this unlock profile
-- @param options.unlock_addr1? integer Final first unlock address override; bypasses addr_base
-- @param options.unlock_addr2? integer Final second unlock address override; bypasses addr_base
-- @return boolean found True when both manufacturer and device are recognized
-- @return table device Chip information, or an empty table on validation or detection failure
local function prg_rom_get_chip(debug, options)
  log.section("Reading PRG-ROM manufacturer/device ID")

  local manufacturer = {}
  local manufacturer_found = false
  local device = {}
  local device_found = false

  options = options or {}
  options.opcode = options.opcode or "NES_CPU_WR"
  options.addr_base = options.addr_base or 0x8000

  local has_addr1 = options.unlock_addr1 ~= nil
  local has_addr2 = options.unlock_addr2 ~= nil

  if has_addr1 ~= has_addr2 then
    log.error("unlock_addr1 and unlock_addr2 must be provided together")
    return false, {}
  end

  local unlock_profile_list = options.unlock_profile_name
      and { options.unlock_profile_name }
      or { "long", "short" }

  for _, unlock_profile_name in ipairs(unlock_profile_list) do
    local unlock_profile = chips.unlock_profiles[unlock_profile_name]

    if unlock_profile == nil then
      log.error("Unknown unlock profile:", unlock_profile_name)
    else
      local test_options = {
        debug = debug,
        opcode = options.opcode,
        addr_base = options.addr_base,
        unlock_profile_name = unlock_profile_name
      }

      local addr1 = options.unlock_addr1 or (unlock_profile.addr1 | options.addr_base)
      local addr2 = options.unlock_addr2 or (unlock_profile.addr2 | options.addr_base)

      if debug then
        log.point("unlock profile name:", unlock_profile_name)
        log.point("unlock addr1:", help.hex_0x4(addr1))
        log.point("unlock addr2:", help.hex_0x4(addr2))
      end

      -- exit software
      cpu_wr(0xFFFF, 0xF0, { opcode = test_options.opcode, debug = debug })

      -- write sequence
      cpu_wr(addr1, 0xAA, { opcode = test_options.opcode, debug = debug })
      cpu_wr(addr2, 0x55, { opcode = test_options.opcode, debug = debug })
      cpu_wr(addr1, 0x90, { opcode = test_options.opcode, debug = debug })

      manufacturer_found, manufacturer = prg_rom_get_manufacturer(test_options)

      if manufacturer_found then
        chips.display_manufacturer(manufacturer.id)
        test_options.manufacturer = manufacturer
        device_found, device = prg_rom_get_device(test_options)
      end

      -- exit software
      cpu_wr(0xFFFF, 0xF0, { opcode = test_options.opcode, debug = debug })

      if device_found then
        chips.display_device(manufacturer.id, device.id)
        return true, device
      end
    end
  end

  return false, {}
end

--- Erase the entire PRG-ROM flash chip and poll 0x8000 until consecutive reads match.
-- Both short and long unlock profiles are supported; other profiles return false.
-- Polling has no timeout, and a true return value does not verify that the chip is blank.
-- @param device table Flash chip information containing size in KiB and unlock_profile_name
-- @param debug? boolean Log the selected profile, resolved addresses, and CPU writes; polling reads are not logged
-- @param options? table Flash access options
-- @param options.opcode? string Flash write opcode; defaults to NES_CPU_WR
-- @param options.addr_base? integer Mask bitwise-ORed with profile addresses without overrides; defaults to 0x8000
-- @param options.unlock_addr1? integer Final first unlock address override, used without applying addr_base
-- @param options.unlock_addr2? integer Final second unlock address override, used without applying addr_base
-- @return boolean completed True when polling completes, or false for an unsupported profile
local function prg_rom_erase(device, debug, options)
  options = options or {}
  local opcode = options.opcode or "NES_CPU_WR"
  local addr_base = options.addr_base or 0x8000
  local unlock_profile = chips.unlock_profiles[device.unlock_profile_name]
  local i = 0
  local rv

  log.section("Erasing PRG-ROM")
  log.bullet("Chip size", device.size .. "KB")

  if device.unlock_profile_name == "short" or device.unlock_profile_name == "long" then
    time.start()

    local addr1 = options.unlock_addr1 or (unlock_profile.addr1 | addr_base)
    local addr2 = options.unlock_addr2 or (unlock_profile.addr2 | addr_base)

    if debug then
      log.point("unlock profile name", device.unlock_profile_name)
      log.point("unlock addr1", help.hex_0x4(addr1))
      log.point("unlock addr2", help.hex_0x4(addr2))
    end

    cpu_wr(addr1, 0xAA, { opcode = opcode, debug = debug })
    cpu_wr(addr2, 0x55, { opcode = opcode, debug = debug })
    cpu_wr(addr1, 0x80, { opcode = opcode, debug = debug })
    cpu_wr(addr1, 0xAA, { opcode = opcode, debug = debug })
    cpu_wr(addr2, 0x55, { opcode = opcode, debug = debug })
    cpu_wr(addr1, 0x10, { opcode = opcode, debug = debug })
  else
    log.error("Unlock profile unknwown:", device.unlock_profile_name)
    return false
  end

  rv = cpu_rd(0x8000)
  while rv ~= cpu_rd(0x8000) do
    spinner.update("Erasing")
    rv = cpu_rd(0x8000)
    i = i + 1
  end
  spinner.clear()
  log.success("Done erasing PRG-ROM", i .. " naks")
  time.report(device.size)

  return true
end

--- Read and identify the CHR-ROM flash manufacturer in software identification mode.
-- The caller must enter identification mode and reset the flash afterward.
-- Both short and long profiles read the manufacturer ID at PPU address 0x0000.
-- Other profile names, including nil, return false and an empty table without reading the bus.
-- @param options table Selected unlock profile
-- @param options.unlock_profile_name string Short or long unlock profile
-- @param options.debug? boolean Log the PPU read; defaults to false
-- @return boolean found True when recognized, false when unknown or the profile is unsupported
-- @return table manufacturer Manufacturer name and ID, or an empty table when unknown or the profile is unsupported
local function chr_rom_get_manufacturer(options)
  local manufacturer_id

  if options.unlock_profile_name == "short" or options.unlock_profile_name == "long" then
    manufacturer_id = ppu_rd(0x0000, { debug = options.debug })
    return chips.get_manufacturer(manufacturer_id)
  end

  return false, {}
end

--- Read and identify the CHR-ROM flash device in software identification mode.
-- The caller must enter identification mode and reset the flash afterward.
-- The long profile reads the device ID at PPU address 0x0001.
-- The short profile reads PPU address 0x8001, then tries the 24-bit ID from
-- PPU addresses 0x8002, 0x801C, and 0x801E if the first ID is unknown.
-- Other profile names, including nil, cause the function to return no values.
-- @param options table Detected manufacturer and selected unlock profile
-- @param options.manufacturer table Manufacturer information containing its id
-- @param options.unlock_profile_name string Short or long unlock profile
-- @param options.debug? boolean Log the PPU reads; defaults to false
-- @return boolean|nil found True when the manufacturer/device pair is recognized, false when unknown, or nil for other profiles
-- @return table|nil device Chip information, an empty table when unknown, or nil for other profiles
local function chr_rom_get_device(options)
  local device_id
  local device
  local found

  if options.unlock_profile_name == "short" then
    device_id = ppu_rd(0x8001, { debug = options.debug })
    found, device = chips.get_device(options.manufacturer.id, device_id)

    if not found then
      device_id = ppu_rd(0x8002, { debug = options.debug }) << 16
      device_id = device_id | (ppu_rd(0x801C, { debug = options.debug }) << 8)
      device_id = device_id | ppu_rd(0x801E, { debug = options.debug })
      found, device = chips.get_device(options.manufacturer.id, device_id)
    end

    return found, device
  elseif options.unlock_profile_name == "long" then
    device_id = ppu_rd(0x0001, { debug = options.debug })
    return chips.get_device(options.manufacturer.id, device_id)
  end
end

--- Detect the CHR-ROM flash chip by trying manufacturer/device identification for each profile.
-- Tries only the supplied profile, or long then short until a device is recognized.
-- Sends the 0xAA/0x55/0x90 identification sequence using each profile's resolved addresses
-- before reading the manufacturer and device IDs.
-- Logs each recognized manufacturer even if its device is unknown.
-- Adds opcode and addr_base defaults to the supplied options; uses a separate table per attempt.
-- Address overrides must be supplied together.
-- Validates each profile before hardware access, then resets before and after identification.
-- Unknown profiles are logged and skipped.
-- Profile addresses are mapped to 0x1000-0x1FFF using (addr & 0x0FFF) | 0x1000;
-- explicit address overrides are written unchanged.
-- @param debug? boolean Log the selected profile, resolved addresses, and PPU writes; identification reads are not logged
-- @param options? table Flash access options
-- @param options.opcode? string Flash write opcode; defaults to NES_PPU_WR
-- @param options.addr_base? integer Mask bitwise-ORed with profile addresses when no overrides are supplied; defaults to 0x0000
-- @param options.unlock_profile_name? string Restrict probing to this unlock profile
-- @param options.unlock_addr1? integer Final first unlock address override; bypasses addr_base and CHR address masking
-- @param options.unlock_addr2? integer Final second unlock address override; bypasses addr_base and CHR address masking
-- @return boolean found True when both manufacturer and device are recognized
-- @return table device Chip information, or an empty table on validation or detection failure
local function chr_rom_get_chip(debug, options)
  log.section("Reading CHR-ROM manufacturer/device ID")

  local manufacturer = {}
  local manufacturer_found = false
  local device = {}
  local device_found = false

  options = options or {}
  options.opcode = options.opcode or "NES_PPU_WR"
  options.addr_base = options.addr_base or 0x0000

  local has_profile = options.unlock_profile_name ~= nil
  local has_addr1 = options.unlock_addr1 ~= nil
  local has_addr2 = options.unlock_addr2 ~= nil

  if has_addr1 ~= has_addr2 then
    log.error("unlock_addr1 and unlock_addr2 must be provided together")
    return false, {}
  end

  local unlock_profile_list = options.unlock_profile_name
      and { options.unlock_profile_name }
      or { "long", "short" }
  for _, unlock_profile_name in ipairs(unlock_profile_list) do
    local unlock_profile = chips.unlock_profiles[unlock_profile_name]

    if unlock_profile == nil then
      log.error("Unknown unlock profile:", unlock_profile_name)
    else
      local test_options = {
        opcode = options.opcode,
        addr_base = options.addr_base,
        unlock_profile_name = unlock_profile_name
      }

      local addr1
      if options.unlock_addr1 then
        addr1 = options.unlock_addr1
      else
        addr1 = unlock_profile.addr1 | options.addr_base
        addr1 = (addr1 & 0xfff) | 0x1000
      end

      local addr2
      if options.unlock_addr2 then
        addr2 = options.unlock_addr2
      else
        addr2 = unlock_profile.addr2 | options.addr_base
        addr2 = (addr2 & 0xfff) | 0x1000
      end

      if debug then
        log.point("unlock profile name", unlock_profile_name)
        log.point("unlock addr1", help.hex_0x4(addr1))
        log.point("unlock addr2", help.hex_0x4(addr2))
      end

      -- exit software
      ppu_wr(0x0000, 0xF0, { opcode = options.opcode, debug = debug })

      -- write sequence
      ppu_wr(addr1, 0xAA, { opcode = test_options.opcode, debug = debug })
      ppu_wr(addr2, 0x55, { opcode = test_options.opcode, debug = debug })
      ppu_wr(addr1, 0x90, { opcode = test_options.opcode, debug = debug })

      manufacturer_found, manufacturer = chr_rom_get_manufacturer(test_options)

      if manufacturer_found then
        chips.display_manufacturer(manufacturer.id)
        test_options.manufacturer = manufacturer
        device_found, device = chr_rom_get_device(test_options)
      end

      -- exit software
      ppu_wr(0x0000, 0xF0, { opcode = options.opcode, debug = debug })

      if device_found then
        chips.display_device(manufacturer.id, device.id)
        return true, device
      end
    end
  end

  return false, {}
end

--- Erase the entire CHR-ROM flash chip and poll 0x0000 until consecutive reads match.
-- Both short and long unlock profiles are supported; other profiles return false.
-- Polling has no timeout, and a true return value does not verify that the chip is blank.
-- Profile addresses are mapped to 0x1000-0x1FFF using (addr & 0x0FFF) | 0x1000;
-- explicit address overrides are written unchanged.
-- @param device table Flash chip information containing size in KiB and unlock_profile_name
-- @param debug? boolean Log the selected profile, resolved addresses, and PPU writes; polling reads are not logged
-- @param options? table Flash access options
-- @param options.opcode? string Flash write opcode; defaults to NES_PPU_WR
-- @param options.addr_base? integer Mask bitwise-ORed with profile addresses without overrides; defaults to 0x0000
-- @param options.unlock_addr1? integer Final first unlock address override; bypasses addr_base and CHR address masking
-- @param options.unlock_addr2? integer Final second unlock address override; bypasses addr_base and CHR address masking
-- @return boolean completed True when polling completes, or false for an unsupported profile
local function chr_rom_erase(device, debug, options)
  options = options or {}
  local opcode = options.opcode or "NES_PPU_WR"
  local addr_base = options.addr_base or 0x0000
  local unlock_profile = chips.unlock_profiles[device.unlock_profile_name]
  local i = 0
  local rv

  log.section("Erasing CHR-ROM")
  log.bullet("Chip size", device.size .. "KB")

  if device.unlock_profile_name == "short" or device.unlock_profile_name == "long" then
    time.start()

    local addr1
    if options.unlock_addr1 then
      addr1 = options.unlock_addr1
    else
      addr1 = unlock_profile.addr1 | addr_base
      addr1 = (addr1 & 0xfff) | 0x1000
    end

    local addr2
    if options.unlock_addr2 then
      addr2 = options.unlock_addr2
    else
      addr2 = unlock_profile.addr2 | addr_base
      addr2 = (addr2 & 0xfff) | 0x1000
    end

    if debug then
      log.point("unlock profile name", device.unlock_profile_name)
      log.point("unlock addr1", help.hex_0x4(addr1))
      log.point("unlock addr2", help.hex_0x4(addr2))
    end

    ppu_wr(addr1, 0xAA, { opcode = opcode, debug = debug })
    ppu_wr(addr2, 0x55, { opcode = opcode, debug = debug })
    ppu_wr(addr1, 0x80, { opcode = opcode, debug = debug })
    ppu_wr(addr1, 0xAA, { opcode = opcode, debug = debug })
    ppu_wr(addr2, 0x55, { opcode = opcode, debug = debug })
    ppu_wr(addr1, 0x10, { opcode = opcode, debug = debug })
  else
    log.error("Unlock profile unknwown:", device.unlock_profile_name)
    return false
  end

  rv = ppu_rd(0x0000)
  while rv ~= ppu_rd(0x0000) do
    spinner.update("Erasing")
    rv = ppu_rd(0x0000)
    i = i + 1
  end
  spinner.clear()
  log.success("Done erasing CHR-ROM", i .. " naks")
  time.report(device.size)

  return true
end

-- -- verify the ciccom software mirroring switch is working properly
-- local function test_cic_soft_switch(debug)
-- end

-- -- Desc: CHR-ROM flash manf/prod ID sense test
-- --       Only senses SST flash ID's
-- --       Does not make CHR bank writes so A14-A13 must be made valid outside of this funciton
-- --       An NROM board does this by tieing A14:13 to A12:11
-- --       Other mappers will pass this function if PT0 has A14:13=01, PT1 has A14:13=10
-- --       Assumes that isn't getting tricked by having manf/prodID at $0000/0001
-- --       could add check and increment read address to ensure doesn't get tricked..
-- -- Pre:  nes_init() been called to setup i/o
-- -- Post: memory manf/prod ID set to read values if passed
-- --       memory wr_dict and wr_opcode set if successful
-- --       Software mode exited if entered successfully
-- -- Rtn:  SUCCESS if flash sensed, GEN_FAIL if not, neg if error
-- local function read_flashID_chrrom_8K(debug)
--   local rv
--   --enter software mode
--   --NROM has A13 tied to A11, and A14 tied to A12.
--   --So only A0-12 needs to be valid
--   --A13 needs to be low to address CHR-ROM
--   --      15 14 13 12
--   -- 0x5 = 0b  0  1  0  1  -> $1555
--   -- 0x2 = 0b  0  0  1  0  -> $0AAA
--   dict.nes("NES_PPU_WR", 0x1555, 0xAA)
--   dict.nes("NES_PPU_WR", 0x0AAA, 0x55)
--   dict.nes("NES_PPU_WR", 0x1555, 0x90)
--   --read manf ID
--   rv = dict.nes("NES_PPU_RD", 0x0000)
--   if debug then print("attempted read CHR-ROM manf ID:", help.hex(rv)) end
--   --  if ( rv[RV_DATA0_IDX] != SST_MANF_ID ) {
--   --    return GEN_FAIL;
--   --    //no need for software exit since failed to enter
--   --  }
--   --
--   --read prod ID
--   rv = dict.nes("NES_PPU_RD", 0x0001)
--   if debug then print("attempted read CHR-ROM prod ID:", help.hex(rv)) end
--   --  if ( (rv[RV_DATA0_IDX] == SST_PROD_128)
--   --  ||   (rv[RV_DATA0_IDX] == SST_PROD_256)
--   --  ||   (rv[RV_DATA0_IDX] == SST_PROD_512) ) {
--   --    //found expected manf and prod ID
--   --    flash->manf = SST_MANF_ID;
--   --    flash->part = rv[RV_DATA0_IDX];
--   --    flash->wr_dict = DICT_NES;
--   --    flash->wr_opcode = NES_PPU_WR;
--   --  }
--   --
--   -- exit software
--   dict.nes("NES_PPU_WR", 0x0000, 0xF0)

--   --return true
-- end


-- Desc: Simple CHR-RAM sense test
--       A more thourough test should be implemented in firmware
--       This one simply tests one address in PPU address space
-- Pre:  nes_init() been called to setup i/o
-- Post:
-- Rtn:  SUCCESS if ram sensed, GEN_FAIL if not, neg if error
--
--int ppu_ram_sense( USBtransfer *transfer, uint16_t addr ) {
local function ppu_ram_sense(addr, debug)
  local res = true

  log.section("Trying to sense CHR-RAM")

  --write 0xAA to addr
  dict.nes("NES_PPU_WR", addr, 0xAA)

  --try to read it back
  if (dict.nes("NES_PPU_RD", addr) ~= 0xAA) then
    if debug then log.bullet("could not write 0xAA to PPU " .. help.hex(addr, 4, "$")) end
    res = false
  end

  --write 0x55 to addr
  dict.nes("NES_PPU_WR", addr, 0x55)

  --try to read it back
  if (dict.nes("NES_PPU_RD", addr) ~= 0x55) then
    if debug then log.bullet("could not write 0x55 to PPU " .. help.hex(addr, 4, "$")) end
    res = false
  end

  if res then
    log.success("CHR-RAM detected @ PPU " .. help.hex(addr, 4, "$"))
  else
    log.info("CHR-RAM not detected @ PPU " .. help.hex(addr, 4, "$"))
  end

  return res
end

-- -- Desc: PRG-ROM flash manf/prod ID sense test
-- --       Using EXP0 /WE writes
-- --       Only senses SST flash ID's
-- --       Assumes that isn't getting tricked by having manf/prodID at $8000/8001
-- --       could add check and increment read address to ensure doesn't get tricked..
-- -- Pre:  nes_init() been called to setup i/o
-- --       exp0 pullup test must pass
-- --       if ROM A14 is mapper controlled it must be low when CPU A14 is low
-- --       controlling A14 outside of this function acts as a means of bank size detection
-- -- Post: memory manf/prod ID set to read values if passed
-- --       memory wr_dict and wr_opcode set if successful
-- --       Software mode exited if entered successfully
-- -- Rtn:  SUCCESS if flash sensed, GEN_FAIL if not, neg if error
-- local function read_flashID_prgrom_exp0(debug)
--   local rv
--   --enter software mode
--   --ROMSEL controls PRG-ROM /OE which needs to be low for flash writes
--   --So unlock commands need to be addressed below $8000
--   --DISCRETE_EXP0_PRGROM_WR doesn't toggle /ROMSEL by definition though, so A15 is unused
--   --      15 14 13 12
--   -- 0x5 = 0b  0  1  0  1  -> $5555
--   -- 0x2 = 0b  0  0  1  0  -> $2AAA
--   dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x5555, 0xAA)
--   dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x2AAA, 0x55)
--   dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x5555, 0x90)
--   --read manf ID
--   rv = dict.nes("NES_CPU_RD", 0x8000)
--   if debug then print("attempted read PRG-ROM manf ID:", help.hex(rv)) end
--   --  debug("manf id: %x", rv[RV_DATA0_IDX]);
--   --  if ( rv[RV_DATA0_IDX] != SST_MANF_ID ) {
--   --    return GEN_FAIL;
--   --    //no need for software exit since failed to enter
--   --  }
--   --
--   --read prod ID
--   rv = dict.nes("NES_CPU_RD", 0x8001)
--   if debug then print("attempted read PRG-ROM prod ID:", help.hex(rv)) end
--   --  if ( (rv[RV_DATA0_IDX] == SST_PROD_128)
--   --  ||   (rv[RV_DATA0_IDX] == SST_PROD_256)
--   --  ||   (rv[RV_DATA0_IDX] == SST_PROD_512) ) {
--   --    //found expected manf and prod ID
--   --    flash->manf = SST_MANF_ID;
--   --    flash->part = rv[RV_DATA0_IDX];
--   --    flash->wr_dict = DICT_NES;
--   --    flash->wr_opcode = DISCRETE_EXP0_PRGROM_WR;
--   --  }
--   --
--   -- exit software
--   dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x8000, 0xF0)
--   --verify exited
--   --  rv = dict.nes("NES_CPU_RD", 0x8001)
--   --  if debug then print("attempted read PRG-ROM prod ID:", help.hex(rv)) end

--   return true
-- end

--[[
 dP""b8 88  dP""b8
dP   `" 88 dP   `"
Yb      88 Yb
 YboodP 88  YboodP
--]]

nes.cic = {

  flash = function(self, flash_filename, dump_filename, fuse_high, fuse_low)
    -- default values
    if not flash_filename then flash_filename = opts.lua_path .. "./ignore/AVRCICZZ.BIN" end
    if not dump_filename then dump_filename = opts.write_path .. "./ignore/cic_dump.bin" end
    if not fuse_high then fuse_high = 0xfb end
    if not fuse_low then fuse_low = 0x70 end

    log.section("CIC")
    if not self:read_signature() then return false end
    self:read_fuses()
    if not self:erase_chip() then return false end
    self:flash_chip(flash_filename)
    if not self:flash_fuses(fuse_high, fuse_low) then return false end
    self:dump_chip(dump_filename)
    if not self:verify_flash(flash_filename, dump_filename) then return false end
    return true
  end,

  read_signature = function()
    local rv = dict.nes("CIC_GET_SIGNATURE")
    local s0 = (rv >> 0) & 0xff
    local s1 = (rv >> 8) & 0xff
    local s2 = (rv >> 16) & 0xff
    log.info("Read signature bytes: ", help.hex_0x2(s0), help.hex_0x2(s1), help.hex_0x2(s2))
    if s0 ~= 0x1e or s1 ~= 0x90 or s2 ~= 0x07 then
      log.error("CIC signature invalid")
      return false
    else
      log.success("CIC signature valid")
      return true
    end
  end,

  read_fuses = function()
    local fuses = dict.nes("CIC_GET_FUSES")
    local high = (fuses >> 8) & 0xff
    local low = (fuses >> 0) & 0xff
    log.info("Read fuse bytes: ", help.hex_0x2(high), help.hex_0x2(low))
  end,

  flash_fuses = function(self, high, low)
    -- default safe values
    if not high then high = 0xff end
    if not low then low = 0x6a end

    -- flash
    dict.nes("CIC_SET_FUSES", (high << 8) | low)
    log.info("Wrote fuse bytes: ", help.hex_0x2(high), help.hex_0x2(low))

    -- control
    local fuses = dict.nes("CIC_GET_FUSES")
    local rHigh = (fuses >> 8) & 0xff
    local rLow = (fuses >> 0) & 0xff
    if high ~= rHigh or low ~= rLow then
      log.error("Error while flashing fuse bytes")
      return false
    else
      log.success("Fuse bytes flashed successfully")
      return true
    end
  end,

  dump_chip = function(self, filename)
    -- open file
    local file = assert(io.open(filename, "wb"))

    -- dump cart to file
    log.point("Dumping program")
    time.start()

    dump.dumptofile(file, 1, { mapper = 0x80, mem_type = "CIC_READ_BUFFER" }, false)

    time.report(1)
    log.success("CIC dumping done")

    -- close file
    assert(file:close())
  end,

  erase_chip = function()
    local rv = dict.nes("CIC_ERASE_PROGRAM")
    if rv == 0 then
      log.success("CIC successfully erased")
      return true
    else
      log.error("Error while erasing CIC")
      return false
    end
  end,

  flash_chip = function(self, filename)
    -- open file
    local file = assert(io.open(filename, "rb"))

    -- dump cart to file
    log.point("Flashing program")
    time.start()

    flash.write_file(file, 1, { mapper = "CIC_WRITE_BUFFER", mem_type = "CIC" }, false)

    time.report(1)
    log.success("CIC program flashed successfully")

    -- close file
    assert(file:close())
  end,

  verify_flash = function(self, verify_file, dump_file)
    log.point("Verifying data")
    if files.compare(verify_file, dump_file, true, true) then
      log.success("Flash successfully verified")
      return true
    else
      log.error("Flash verification did not match")
      return false
    end
  end

}
-- global variables so other modules can use them


-- call functions desired to run when script is called/imported


-- functions other modules are able to call
-- nes.jumper_ciramce_ppuA13n = jumper_ciramce_ppuA13n
-- nes.ciramce_inv_ppuA13 = ciramce_inv_ppuA13
nes.jumper_famicom_sound = jumper_famicom_sound
nes.detect_mapper_mirroring = detect_mapper_mirroring
-- nes.test_cic_soft_switch = test_cic_soft_switch
nes.ppu_ram_sense = ppu_ram_sense
-- nes.read_flashID_chrrom_8K = read_flashID_chrrom_8K
-- nes.read_flashID_prgrom_exp0 = read_flashID_prgrom_exp0
nes.write_header = write_header
nes.parse_header = parse_header
nes.find_bank_table_32 = find_bank_table_32
nes.find_bank_table_in_last_bank = find_bank_table_in_last_bank

nes.prg_rom_get_chip = prg_rom_get_chip
nes.prg_rom_erase = prg_rom_erase

nes.chr_rom_get_chip = chr_rom_get_chip
nes.chr_rom_erase = chr_rom_erase

nes.cpu_rd = cpu_rd
nes.cpu_wr = cpu_wr
nes.ppu_rd = ppu_rd
nes.ppu_wr = ppu_wr

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
