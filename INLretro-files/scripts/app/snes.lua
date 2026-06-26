-- create the module's table
local snes          = {}

-- import required modules
local dict          = require "scripts.app.dict"
local dump          = require "scripts.app.dump"
local help          = require "scripts.app.help"
local log           = require "scripts.app.log"
-- local swim  = require "scripts.app.swim"

-- file constants and global variables
local RESET_VECT_HI = 0xFFFD
local RESET_VECT_LO = 0xFFFC

-- global variables so other modules can use them
snes_swimcart       = nil

-- local functions

--[[
██╗  ██╗███████╗ █████╗ ██████╗ ███████╗██████╗
██║  ██║██╔════╝██╔══██╗██╔══██╗██╔════╝██╔══██╗
███████║█████╗  ███████║██║  ██║█████╗  ██████╔╝
██╔══██║██╔══╝  ██╔══██║██║  ██║██╔══╝  ██╔══██╗
██║  ██║███████╗██║  ██║██████╔╝███████╗██║  ██║
╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝

--]]

-- https://snes.nesdev.org/wiki/ROM_header

local Header = {
  bytes = nil,
  is_valid = false,

  has_smc_header = false,
  is_lorom = false,
  is_exrom = false,
  header_offset = 0,

  cartridge_title = "",
  rom_type = {
    byte = 0,
    speed = 0,
    mode = 0
  },
  chipset = 0,
  rom_size = 0,
  ram_size = 0,
  country = 0,
  developer_id = 0,
  rom_version = 0,
  checksum_complement = 0,
  checksum = 0,
  vectors = {
    _65c816 = {
      COP = 0,
      BRK = 0,
      ABORT = 0,
      NMI = 0,
      NONE = 0,
      IRQ = 0
    },
    _6502 = {
      COP = 0,
      NONE = 0,
      ABORT = 0,
      NMI = 0,
      RESET = 0,
      IRQ = 0
    }
  },

  -- return a value in KB
  get_rom_size = function(self)
    local rom_size = 1 << self.rom_size
    return rom_size
  end,

  -- return a value in KB
  get_ram_size = function(self)
    local ram_size = 1 << self.ram_size
    return ram_size
  end,

  has_sram = function(self)
    if self.get_ram_size ~= 0 then
      return true
    else
      return false
    end
  end,

  -- return true or false
  check_rom_checksum = function(self)
    if self.rom_checksum == self.file_rom_checksum then
      return true
    else
      return false
    end
  end,

  -- return true or false
  check_header_checksum = function(self)
    -- print(self.checksum, self.checksum_complement)
    if self.checksum + self.checksum_complement == 0xFFFF then
      return true
    else
      return false
    end
  end,

  -- return true or false
  check_vectors = function(self)
    if
        self.vectors._65c816.COP < 0x8000 or
        self.vectors._65c816.BRK < 0x8000 or
        self.vectors._65c816.ABORT < 0x8000 or
        self.vectors._65c816.NMI < 0x8000 or
        self.vectors._65c816.IRQ < 0x8000 or
        self.vectors._6502.COP < 0x8000 or
        self.vectors._6502.ABORT < 0x8000 or
        self.vectors._6502.NMI < 0x8000 or
        self.vectors._6502.RESET < 0x8000 or
        self.vectors._6502.IRQ < 0x8000 then
      return false
    end

    return true
  end,

}

local file_header = help.copy_table(Header)
local cart_header = help.copy_table(Header)

-- parse header from data
local function parse_header(byte_str, header)
  header.bytes = table.pack(string.unpack(string.rep('B', #byte_str), byte_str))
  header.cartridge_title = string.sub(byte_str, 1, 21)
  header.rom_type.byte = header.bytes[22]
  header.rom_type.speed = (header.rom_type.byte & 0x10) >> 4
  header.rom_type.mode = header.rom_type.byte & 0x0F
  header.chipset = header.bytes[23]
  header.rom_size = header.bytes[24]
  header.ram_size = header.bytes[25]
  header.country = header.bytes[26]
  header.developer_id = header.bytes[27]
  header.rom_version = header.bytes[28]
  header.checksum_complement = (header.bytes[30] << 8) | header.bytes[29]
  header.checksum = (header.bytes[32] << 8) | header.bytes[31]
  header.vectors._65c816.COP = (header.bytes[38] << 8) | header.bytes[37]
  header.vectors._65c816.BRK = (header.bytes[40] << 8) | header.bytes[39]
  header.vectors._65c816.ABORT = (header.bytes[42] << 8) | header.bytes[41]
  header.vectors._65c816.NMI = (header.bytes[44] << 8) | header.bytes[43]
  header.vectors._65c816.NONE = (header.bytes[46] << 8) | header.bytes[45]
  header.vectors._65c816.IRQ = (header.bytes[48] << 8) | header.bytes[47]
  header.vectors._6502.COP = (header.bytes[54] << 8) | header.bytes[53]
  header.vectors._6502.NONE = (header.bytes[56] << 8) | header.bytes[55]
  header.vectors._6502.ABORT = (header.bytes[58] << 8) | header.bytes[57]
  header.vectors._6502.NMI = (header.bytes[60] << 8) | header.bytes[59]
  header.vectors._6502.RESET = (header.bytes[62] << 8) | header.bytes[61]
  header.vectors._6502.IRQ = (header.bytes[64] << 8) | header.bytes[63]

  -- if not header:check_rom_checksum() then
  --   log.warning("Rom checksum is not valid")
  -- end

  -- cheap test
  if not header:check_header_checksum() or not header:check_vectors() then
    log.warning("Header is not valid")
    header.is_valid = false
  else
    header.is_valid = true
  end

  return header.is_valid
end


-- pass a file pointer for a file which is already open
-- leave file open when done
local function parse_header_file(file)
  local SMC_HEADER_SIZE = 512

  local byte_str

  file_header.file_size = file:seek("end")

  -- try to find ROM header
  -- lorom/hirom + headerless/headered combinations
  -- taken from Mesen source code
  local base_addresses = { 0, 0x200, 0x8000, 0x8200, 0x400000, 0x400200, 0x408000, 0x408200 }
  local found_rom_header = false;
  for i = 1, #base_addresses do
    local base_address = base_addresses[i]
    local checksum_complement = 0;
    local checksum = 0;
    local bytes

    file:seek("set", base_address + 0x7FC0 + 0x1C)
    byte_str = file:read(4)
    bytes = table.pack(string.unpack(string.rep('B', #byte_str), byte_str))
    checksum_complement = bytes[1]
    checksum_complement = checksum_complement | (bytes[2] << 8);
    checksum = bytes[3];
    checksum = checksum | (bytes[4] << 8);

    if checksum + checksum_complement == 0xFFFF and checksum ~= 0 and checksum_complement ~= 0 then
      found_rom_header = true;
      file_header.is_lorom = (base_address & 0x8000) == 0;
      file_header.is_exrom = (base_address & 0x400000) ~= 0;
      file_header.has_smc_header = (base_address & 0x200) ~= 0;
      file_header.header_offset = base_address + 0x7FC0
      if file_header.has_smc_header then
        file_header.header_offset = file_header.header_offset + SMC_HEADER_SIZE
      end
      break
    end
  end

  -- not found?
  if not found_rom_header then
    log.error("Couldn't find ROM header")
    return false
  end

  -- log detected mapper
  if file_header.is_lorom then
    if file_header.is_exrom then
      log.info("ExLoRom mapper detected")
    else
      log.info("LoRom mapper detected")
    end
  else
    if file_header.is_exrom then
      log.info("ExHiRom mapper detected")
    else
      log.info("HiRom mapper detected")
    end
  end

  -- log detected SMC header
  if file_header.has_smc_header then
    log.info("SMC header detected")
  end

  -- parse header
  file:seek("set", file_header.header_offset)
  byte_str = file:read(64)
  return parse_header(byte_str, file_header)
end

-- parse header from rom
-- we should be able to read the header whatever the mapper is
-- global checksum won't be computed though
local function parse_header_cart()
  local byte_str
  local rv

  -- first we try to get the ROM header using HIROM settings
  -- if it doesn't work, then try using LOROM settings

  -- HIROM
  log.point("Trying to dump header using HiRom settings")
  byte_str = ""

  -- initialize device i/o
  dict.io("IO_RESET")
  dict.io("SNES_INIT")

  -- dump data
  -- dict.snes("SNES_SET_BANK", 0) -- not required?
  dump.dumptocallback(
    function(data) byte_str = byte_str .. data end,
    64, "HIROM", "SNESROM", false
  )

  byte_str = string.sub(byte_str, 0xFFC0 + 1, 0xFFFF + 1)
  if parse_header(byte_str, cart_header) then
    log.info("HiRom mapper detected")
    return true
  end

  -- LOROM
  log.point("Trying to dump header using LoRom settings")
  byte_str = ""

  -- initialize device i/o
  dict.io("IO_RESET")
  dict.io("SNES_INIT")

  -- dump data
  -- dict.snes("SNES_SET_BANK", 0) -- not required?
  dump.dumptocallback(
    function(data) byte_str = byte_str .. data end,
    32, "LOROM", "SNESROM", false
  )

  -- reset device i/o
  dict.io("IO_RESET")

  byte_str = string.sub(byte_str, 0x7FC0 + 1, 0x7FFF + 1)
  if parse_header(byte_str, cart_header) then
    log.info("LoRom mapper detected")
    return true
  end

  return false
end

--[[
██████╗  ██████╗ ███╗   ███╗
██╔══██╗██╔═══██╗████╗ ████║
██████╔╝██║   ██║██╔████╔██║
██╔══██╗██║   ██║██║╚██╔╝██║
██║  ██║╚██████╔╝██║ ╚═╝ ██║
╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝

--]]



































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


-- Desc:read reset vector from passed in bank
-- Pre: snes_init() been called to setup i/o
-- Post:Address left on bus memories disabled
-- Rtn: reset vector that was found
local function read_reset_vector(bank, debug)
  --ensure cart is in play mode
  play_mode()

  --first set SNES bank A16-23
  dict.snes("SNES_SET_BANK", bank)

  --read reset vector high byte
  vector = dict.snes("SNES_ROM_RD", RESET_VECT_HI)
  --shift high byte of vector to where it belongs
  vector = vector << 8
  --read low byte of vector
  vector = vector | dict.snes("SNES_ROM_RD", RESET_VECT_LO)

  if debug then print("SNES bank:", bank, "reset vector", string.format("$%x", vector)) end

  return vector
end

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
  prgm_mode()

  dict.snes("SNES_ROM_WR", 0x0AAA, 0xAA)
  dict.snes("SNES_ROM_WR", 0x0555, 0x55)
  dict.snes("SNES_ROM_WR", 0x0AAA, 0x90)

  --exit program mode
  play_mode()

  --read manf ID
  local manf_id = dict.snes("SNES_ROM_RD", 0x0000)
  if debug then print("attempted read SNES ROM manf ID:", string.format("%X", manf_id)) end

  --read prod ID
  local prod_id = dict.snes("SNES_ROM_RD", 0x0002)
  if debug then print("attempted read SNES ROM prod ID:", string.format("%X", prod_id)) end
  local density_id = dict.snes("SNES_ROM_RD", 0x001C)
  if debug then print("attempted read SNES density ID: ", string.format("%X", density_id)) end
  local boot_sect = dict.snes("SNES_ROM_RD", 0x001E)
  if debug then print("attempted read SNES boot sect ID:", string.format("%X", boot_sect)) end

  --put cart in program mode
  prgm_mode()

  -- exit software
  dict.snes("SNES_ROM_WR", 0x0000, 0xF0)

  --exit program mode
  play_mode()

  --return true if detected flash chip
  if (manf_id == 0x01 and prod_id == 0x49) then
    return true
  else
    return false
  end
end

--[[
  .dP'     8888b.  888888 88""Yb 88   88  dP""b8     888888 88   88 88b 88  dP""b8 .dP"Y8
.dP'        8I  Yb 88__   88__dP 88   88 dP   `"     88__   88   88 88Yb88 dP   `" `Ybo."
`Yb.        8I  dY 88""   88""Yb Y8   8P Yb  "88     88""   Y8   8P 88 Y88 Yb      o.`Y8b
  `Yb.     8888Y"  888888 88oodP `YbodP'  YboodP     88     `YbodP' 88  Y8  YboodP 8bodP'
]]

local function rom_wr(addr, val, debug, comment)
  if not (type(debug) == "boolean") then debug = true end
  if not (type(comment) == "string") then comment = "" end
  dict.snes("SNES_ROM_WR", addr, val)
  if (debug) then log.point("ROM", " W", help.hex(addr, 4, "0x"), val, help.hex(val, 2, "0x"), comment) end
end

local function rom_rd(addr, debug, label)
  if not (type(debug) == "boolean") then debug = true end
  if not (type(label) == "string") then label = "" end
  local rv
  rv = dict.snes("SNES_ROM_RD", addr)
  if (debug) then log.point("ROM", "R ", help.hex(addr, 4, "0x"), rv, help.hex(rv, 2, "0x"), label) end
  return rv
end

snes.rom_rd = rom_rd
snes.rom_wr = rom_wr

--[[
8888b.  888888 88""Yb 88   88  dP""b8     888888 88   88 88b 88  dP""b8 .dP"Y8     `Yb.
 8I  Yb 88__   88__dP 88   88 dP   `"     88__   88   88 88Yb88 dP   `" `Ybo."       `Yb.
 8I  dY 88""   88""Yb Y8   8P Yb  "88     88""   Y8   8P 88 Y88 Yb      o.`Y8b       .dP'
8888Y"  888888 88oodP `YbodP'  YboodP     88     `YbodP' 88  Y8  YboodP 8bodP'     .dP'
]]

-- call functions desired to run when script is called/imported

--[[
███████╗██╗  ██╗██████╗  ██████╗ ██████╗ ████████╗
██╔════╝╚██╗██╔╝██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝
█████╗   ╚███╔╝ ██████╔╝██║   ██║██████╔╝   ██║
██╔══╝   ██╔██╗ ██╔═══╝ ██║   ██║██╔══██╗   ██║
███████╗██╔╝ ██╗██║     ╚██████╔╝██║  ██║   ██║
╚══════╝╚═╝  ╚═╝╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝

--]]

-- vars
snes.file_header       = file_header
snes.cart_header       = cart_header

-- functions
snes.parse_header      = parse_header
snes.parse_header_file = parse_header_file
snes.parse_header_cart = parse_header_cart

-- snes.set_rom_address = set_rom_address

-- snes.dbg_rom_rd = dbg_rom_rd
-- snes.dbg_rom_wr = dbg_rom_wr
-- snes.rom_rd = rom_rd
-- snes.rom_wr = rom_wr

-- snes.dbg_ram_rd = dbg_ram_rd
-- snes.dbg_ram_wr = dbg_ram_wr
-- snes.ram_rd = ram_rd
-- snes.ram_wr = ram_wr





snes.read_reset_vector = read_reset_vector
snes.read_flashID = read_flashID
snes.prgm_mode = prgm_mode
snes.play_mode = play_mode

-- return the module's table
return snes
