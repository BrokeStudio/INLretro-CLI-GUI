-- create the module's table
local n64  = {}

-- import required modules
local dict = require "scripts.app.dict"
local dump = require "scripts.app.dump"
local help = require "scripts.app.help"
local log  = require "scripts.app.log"

-- local functions

--[[
██╗  ██╗███████╗ █████╗ ██████╗ ███████╗██████╗
██║  ██║██╔════╝██╔══██╗██╔══██╗██╔════╝██╔══██╗
███████║█████╗  ███████║██║  ██║█████╗  ██████╔╝
██╔══██║██╔══╝  ██╔══██║██║  ██║██╔══╝  ██╔══██╗
██║  ██║███████╗██║  ██║██████╔╝███████╗██║  ██║
╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝

--]]

-- https://en64.shoutwiki.com/wiki/ROM#Cartridge_ROM_Header

local ROM_TYPES = {
  ["N"] = "cart",
  ["D"] = "64DD disk",
  ["C"] = "cartridge part of expandable game",
  ["E"] = "64DD expansion for cart",
  ["Z"] = "Aleck64 cart",
}

local COUNTRY_CODE = {
  ["7"] = "Beta",                   -- 0x37
  ["A"] = "Asian (NTSC)",           -- 0x41
  ["B"] = "Brazilian",              -- 0x42
  ["C"] = "Chinese",                -- 0x43
  ["D"] = "German",                 -- 0x44
  ["E"] = "North America",          -- 0x45
  ["F"] = "French",                 -- 0x46
  ["G"] = "Gateway 64 (NTSC)",      -- 0x47
  ["H"] = "Dutch",                  -- 0x48
  ["I"] = "Italian",                -- 0x49
  ["J"] = "Japanese",               -- 0x4A
  ["K"] = "Korean",                 -- 0x4B
  ["L"] = "Gateway 64 (PAL)",       -- 0x4C
  ["N"] = "Canadian",               -- 0x4E
  ["P"] = "European (basic spec.)", -- 0x50
  ["S"] = "Spanish",                -- 0x53
  ["U"] = "Australian",             -- 0x55
  ["W"] = "Scandinavian",           -- 0x57
  ["X"] = "European",               -- 0x58
  ["Y"] = "European",               -- 0x59
}


local Header = {
  bytes = nil,
  isValid = false,

  endianness = 0,
  PI_BSB_DOM1_LAT_REG = 0,
  PI_BSD_DOM1_PGS_REG = 0,
  PI_BSD_DOM1_PWD_REG = 0,
  PI_BSB_DOM1_PGS_REG = 0,
  clockrate_override = 0,
  program_counter = 0,
  release_address = 0,
  crc1 = 0,
  crc2 = 0,
  image_name = "",
  media_format = {
    bytes = 0,
    rom_type = 0,
    id = "",
    region = 0
  },
  cartridge_id = "",
  country_code = 0,
  version = 0,
  boot_code = nil,

  -- return version as a string
  get_version = function(self)
    return tostring(((self.version & 0xF0) >> 8) + 1) .. "." .. tostring(self.version & 0x0F)
  end,

  -- return country as a string
  get_country = function(self)
    return COUNTRY_CODE[self.country_code]
  end,

  -- return country as a string
  get_rom_type = function(self)
    return ROM_TYPES[self.media_format.rom_type]
  end,

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
local rom_header = help.copy_table(Header)

-- parse header from data
local function parse_header(byte_str, header)
  header.bytes = table.pack(string.unpack(string.rep('B', #byte_str), byte_str))
  header.endianness = header.bytes[1]
  header.PI_BSB_DOM1_LAT_REG = header.bytes[2]
  header.PI_BSD_DOM1_PGS_REG = header.bytes[2]
  header.PI_BSD_DOM1_PWD_REG = header.bytes[3]
  header.PI_BSB_DOM1_PGS_REG = header.bytes[4]
  header.clockrate_override = (header.bytes[5] << 24) | (header.bytes[6] << 16) |
      (header.bytes[7] << 8) --  | header.bytes[8] -- lower most nybble not read
  header.program_counter = (header.bytes[9] << 24) | (header.bytes[10] << 16) | (header.bytes[11] << 8) |
      header.bytes[12]
  header.release_address = (header.bytes[13] << 24) | (header.bytes[14] << 16) | (header.bytes[15] << 8) |
      header.bytes[16]
  header.crc1 = (header.bytes[17] << 24) | (header.bytes[18] << 16) | (header.bytes[19] << 8) | header.bytes[20]
  header.crc2 = (header.bytes[21] << 24) | (header.bytes[22] << 16) | (header.bytes[23] << 8) | header.bytes[24]
  header.image_name = string.sub(byte_str, 32, 52)
  -- header.media_format = (header.bytes[57] << 24) | (header.bytes[58] << 16) | (header.bytes[59] << 8) | header.bytes[60]
  header.media_format.rom_type = string.sub(byte_str, 60, 60)
  header.media_format.id = string.sub(byte_str, 58, 59)
  header.media_format.region = header.bytes[57]
  header.cartridge_id = string.sub(byte_str, 61, 62)
  header.country_code = string.sub(byte_str, 63, 63)
  header.version = header.bytes[64]
  -- header.boot_code = header.bytes[6]

  -- -- if not header:check_rom_checksum() then
  -- --   log.warning("Rom checksum is not valid")
  -- -- end

  -- cheap test
  if header.program_counter < 0x80000000 then
    log.warning("Header is not valid")
    header.isValid = false
  else
    header.isValid = true
  end

  -- print(help.dump_table(header))

  -- print(header:get_version())
  -- print(header:get_country())
  -- print(header:get_rom_type())


  return header.isValid
end


-- pass a file pointer for a file which is already open
-- leave file open when done
local function parse_header_file(file)
  -- local byte_str
  -- byte_str = file:read(0x100)  -- skip vectors
  -- byte_str = file:read(256)

  -- -- compute global checksum
  -- file:seek("set", 0x200)
  -- file_header.file_rom_checksum = 0
  -- local off = 0
  -- while 1 do
  --   local byte = file:read(2)
  --   if byte == nil then break end
  --   byte = string.unpack(">i2", byte)
  --   file_header.file_rom_checksum = file_header.file_rom_checksum + byte
  --   off = off + 1
  -- end
  -- file_header.file_rom_checksum = file_header.file_rom_checksum & 0xFFFF

  -- return parse_header(byte_str, file_header)
end

-- parse header from rom
-- we should be able to read the header whatever the mapper is
-- global checksum won't be computed though
local function parse_header_rom()
  local addr_base = 0x0000 -- control signals are manually controlled
  local bank_base = 0x1000 -- N64 roms start at address 0x1000_0000
  local byte_str = ""
  local rv

  -- initialize device i/o
  dict.io("IO_RESET")
  dict.io("N64_INIT")

  -- dump data
  dict.n64("N64_SET_BANK", bank_base) -- not required?

  dump.dumptocallback(
    function(data) byte_str = byte_str .. data end,
    1, addr_base, "N64_ROM_PAGE", false
  )

  byte_str = string.sub(byte_str, 0x00 + 1, 0x3F + 1)

  -- prob don't need this...
  dict.n64("N64_RELEASE_BUS")

  -- reset device i/o
  dict.io("IO_RESET")

  byte_str = string.sub(byte_str, 0x00 + 1, 0x3F + 1)
  return parse_header(byte_str, rom_header)
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
n64.file_header       = file_header
n64.rom_header        = rom_header

-- functions
n64.parse_header      = parse_header
n64.parse_header_file = parse_header_file
n64.parse_header_rom  = parse_header_rom

-- n64.set_rom_address = set_rom_address

-- n64.dbg_rom_rd = dbg_rom_rd
-- n64.dbg_rom_wr = dbg_rom_wr
-- n64.rom_rd = rom_rd
-- n64.rom_wr = rom_wr

-- n64.dbg_ram_rd = dbg_ram_rd
-- n64.dbg_ram_wr = dbg_ram_wr
-- n64.ram_rd = ram_rd
-- n64.ram_wr = ram_wr





n64.read_reset_vector = read_reset_vector
n64.read_flashID = read_flashID
n64.prgm_mode = prgm_mode
n64.play_mode = play_mode

-- return the module's table
return n64
