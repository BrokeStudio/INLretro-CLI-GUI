-- create the module's table
local gb   = {}

-- import required modules
local dict = require "scripts.app.dict"
local dump = require "scripts.app.dump"
local help = require "scripts.app.help"
local log  = require "scripts.app.log"

-- file constants and global variables

--[[
██╗  ██╗███████╗ █████╗ ██████╗ ███████╗██████╗
██║  ██║██╔════╝██╔══██╗██╔══██╗██╔════╝██╔══██╗
███████║█████╗  ███████║██║  ██║█████╗  ██████╔╝
██╔══██║██╔══╝  ██╔══██║██║  ██║██╔══╝  ██╔══██╗
██║  ██║███████╗██║  ██║██████╔╝███████╗██║  ██║
╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝

--]]

local CARTRIDGE_TYPES = {
  ["00"] = "ROM ONLY",
  ["01"] = "MBC1",
  ["02"] = "MBC1+RAM",
  ["03"] = "MBC1+RAM+BATTERY",
  ["05"] = "MBC2",
  ["06"] = "MBC2+BATTERY",
  ["08"] = "ROM+RAM 9",
  ["09"] = "ROM+RAM+BATTERY 9",
  ["0B"] = "MMM01",
  ["0C"] = "MMM01+RAM",
  ["0D"] = "MMM01+RAM+BATTERY",
  ["0F"] = "MBC3+TIMER+BATTERY",
  ["10"] = "MBC3+TIMER+RAM+BATTERY 10",
  ["11"] = "MBC3",
  ["12"] = "MBC3+RAM 10",
  ["13"] = "MBC3+RAM+BATTERY 10",
  ["19"] = "MBC5",
  ["1A"] = "MBC5+RAM",
  ["1B"] = "MBC5+RAM+BATTERY",
  ["1C"] = "MBC5+RUMBLE",
  ["1D"] = "MBC5+RUMBLE+RAM",
  ["1E"] = "MBC5+RUMBLE+RAM+BATTERY",
  ["20"] = "MBC6",
  ["22"] = "MBC7+SENSOR+RUMBLE+RAM+BATTERY",
  ["FC"] = "POCKET CAMERA",
  ["FD"] = "BANDAI TAMA5",
  ["FE"] = "HuC3",
  ["FF"] = "HuC1+RAM+BATTERY",
}
local NEW_LICENSEE_CODES = {
  ["0"] = "None",
  ["1"] = "Nintendo Research & Development 1",
  ["8"] = "Capcom",
  ["13"] = "EA (Electronic Arts)",
  ["18"] = "Hudson Soft",
  ["19"] = "B-AI",
  ["20"] = "KSS",
  ["22"] = "Planning Office WADA",
  ["24"] = "PCM Complete",
  ["25"] = "San-X",
  ["28"] = "Kemco",
  ["29"] = "SETA Corporation",
  ["30"] = "Viacom",
  ["31"] = "Nintendo",
  ["32"] = "Bandai",
  ["33"] = "Ocean Software/Acclaim Entertainment",
  ["34"] = "Konami",
  ["35"] = "HectorSoft",
  ["37"] = "Taito",
  ["38"] = "Hudson Soft",
  ["39"] = "Banpresto",
  ["41"] = "Ubi Soft1",
  ["42"] = "Atlus",
  ["44"] = "Malibu Interactive",
  ["46"] = "Angel",
  ["47"] = "Bullet-Proof Software2",
  ["49"] = "Irem",
  ["50"] = "Absolute",
  ["51"] = "Acclaim Entertainment",
  ["52"] = "Activision",
  ["53"] = "Sammy USA Corporation",
  ["54"] = "Konami",
  ["55"] = "Hi Tech Expressions",
  ["56"] = "LJN",
  ["57"] = "Matchbox",
  ["58"] = "Mattel",
  ["59"] = "Milton Bradley Company",
  ["60"] = "Titus Interactive",
  ["61"] = "Virgin Games Ltd.3",
  ["64"] = "Lucasfilm Games4",
  ["67"] = "Ocean Software",
  ["69"] = "EA (Electronic Arts)",
  ["70"] = "Infogrames5",
  ["71"] = "Interplay Entertainment",
  ["72"] = "Broderbund",
  ["73"] = "Sculptured Software6",
  ["75"] = "The Sales Curve Limited7",
  ["78"] = "THQ",
  ["79"] = "Accolade",
  ["80"] = "Misawa Entertainment",
  ["83"] = "lozc",
  ["86"] = "Tokuma Shoten",
  ["87"] = "Tsukuda Original",
  ["91"] = "Chunsoft Co.8",
  ["92"] = "Video System",
  ["93"] = "Ocean Software/Acclaim Entertainment",
  ["95"] = "Varie",
  ["96"] = "Yonezawa/s’pal",
  ["97"] = "Kaneko",
  ["99"] = "Pack-In-Video",
  ["9H"] = "Bottom Up",
  ["A4"] = "Konami (Yu-Gi-Oh!)",
  ["BL"] = "MTO",
  ["DK"] = "Kodansha",
}

local Header = {
  bytes = nil,
  is_valid = false,

  title = "",
  manufacturer_code = 0,
  cgb_flag = 0,
  new_licensee_code = 0,
  sgb_flag = 0,
  cartridge_type = 0,
  rom_size = 0,
  ram_size = 0,
  destination_code = 0,
  old_licensee_code = 0,
  mask_rom_version_number = 0,
  header_checksum = 0,
  global_checksum = 0,
  file_global_checksum = 0,

  --- Return the ROM capacity encoded by the header.
  -- @param self table Game Boy header
  -- @return integer size_kb ROM capacity in KiB, or 0 for an unsupported size code
  get_rom_size = function(self)
    local rom_size = 0

    if self.rom_size == 0x00 then
      rom_size = 32
    elseif self.rom_size == 0x01 then
      rom_size = 64
    elseif self.rom_size == 0x02 then
      rom_size = 128
    elseif self.rom_size == 0x03 then
      rom_size = 256
    elseif self.rom_size == 0x04 then
      rom_size = 512
    elseif self.rom_size == 0x05 then
      rom_size = 1024
    elseif self.rom_size == 0x06 then
      rom_size = 2048
    elseif self.rom_size == 0x07 then
      rom_size = 4096
    elseif self.rom_size == 0x08 then
      rom_size = 8192
    elseif self.rom_size == 0x52 then
      rom_size = 1152
    elseif self.rom_size == 0x53 then
      rom_size = 1280
    elseif self.rom_size == 0x54 then
      rom_size = 1536
    end

    return rom_size
  end,

  --- Return the cartridge RAM capacity encoded by the header and cartridge type.
  -- MBC2 RAM is reported as 1 KiB, and RNBW cartridge types add 8 KiB of FPGA RAM.
  -- @param self table Game Boy header
  -- @return integer size_kb RAM capacity in KiB, or 0 when the cartridge has no RAM or the size code is unsupported
  get_ram_size = function(self)
    local ram_size = 0

    if self.cartridge_type == 5 or self.cartridge_type == 6 then
      -- MBC2 has 512x4bits of cart ram
      ram_size = 1 -- 0x200 -- TODO: how to handle this? returning 1 for now
    else
      if self.ram_size == 0x00 then
        ram_size = 0
      elseif self.ram_size == 0x01 then
        ram_size = 2
      elseif self.ram_size == 0x02 then
        ram_size = 8
      elseif self.ram_size == 0x03 then
        ram_size = 32
      elseif self.ram_size == 0x04 then
        ram_size = 128
      elseif self.ram_size == 0x05 then
        ram_size = 64
      end
    end

    if self.cartridge_type == 0xFA or self.cartridge_type == 0xFB then
      -- RNBW has 8KB of FPGA-RAM
      ram_size = ram_size + 8
    end

    return ram_size
  end,

  --- Check whether the cartridge type includes battery-backed storage.
  -- @param self table Game Boy header
  -- @return boolean has_battery True when the cartridge type is battery-backed
  has_battery = function(self)
    if
        self.cartridge_type == 0x03 or
        self.cartridge_type == 0x06 or
        self.cartridge_type == 0x09 or
        self.cartridge_type == 0x0D or
        self.cartridge_type == 0x0F or
        self.cartridge_type == 0x10 or
        self.cartridge_type == 0x13 or
        self.cartridge_type == 0x1B or
        self.cartridge_type == 0x1E or
        self.cartridge_type == 0x22 or
        self.cartridge_type == 0xFF then
      return true
    end

    return false
  end,

  --- Return the descriptive name of the cartridge type.
  -- @param self table Game Boy header
  -- @return string|nil type_name Cartridge type name, or nil when the type is unknown
  get_cartridge_type_name = function(self)
    return CARTRIDGE_TYPES[help.hex(self.cartridge_type, 2)]
  end,

  --- Return the publisher name associated with the new licensee code.
  -- @param self table Game Boy header
  -- @return string licensee_name Publisher name, or a string containing the unknown code
  get_new_licensee_code = function(self)
    local code = NEW_LICENSEE_CODES[self.new_licensee_code]
    if code == nil then code = "UNKNOWN NEW LICENSEE CODE ()" .. self.new_licensee_code .. ")" end
    return code
  end,

  --- Validate the Game Boy header checksum stored at 0x014D.
  -- Uses the 25 bytes stored in `self.bytes` before the checksum byte.
  -- @param self table Game Boy header containing bytes and header_checksum
  -- @return boolean valid True when the calculated checksum matches header_checksum
  check_header_checksum = function(self)
    local checksum = 0
    for i = 1, 25, 1 do
      checksum = checksum - tonumber(self.bytes[i]) - 1
    end
    checksum = checksum & 0xff
    if checksum == self.header_checksum then
      return true
    else
      return false
    end
  end,

  --- Compare the stored global checksum with the checksum calculated from a ROM file.
  -- @param self table Game Boy header containing global_checksum and file_global_checksum
  -- @return boolean valid True when both checksum values match
  check_global_checksum = function(self)
    if self.global_checksum == self.file_global_checksum then
      return true
    else
      return false
    end
  end,

}

local file_header = help.copy_table(Header)
local cart_header = help.copy_table(Header)

--- Parse Game Boy header bytes into a header table and validate its checksums.
-- Updates all decoded header fields and `header.is_valid`. A global checksum mismatch
-- is logged but does not make the header invalid; validity depends on the header checksum.
-- @param byte_str string Header bytes from ROM offsets 0x0134 through 0x014F
-- @param header table Destination header table containing the checksum methods and file_global_checksum
-- @return boolean valid True when the header checksum is valid
local function parse_header(byte_str, header)
  header.bytes = table.pack(string.unpack(string.rep('B', #byte_str), byte_str))
  header.title = string.sub(byte_str, 1, 11)
  header.manufacturer_code = string.sub(byte_str, 12, 15)
  header.cgb_flag = header.bytes[16]
  header.old_licensee_code = header.bytes[24]
  if header.old_licensee_code == 0x33 then
    -- header.new_licensee_code = tonumber(string.char(header.bytes[17])) * 10 + tonumber(string.char(header.bytes[18]))
    header.new_licensee_code = tonumber(header.bytes[17]) * 10 + tonumber(header.bytes[18])
  end
  header.sgb_flag = header.bytes[19]
  header.cartridge_type = header.bytes[20]
  header.rom_size = header.bytes[21]
  header.ram_size = header.bytes[22]
  header.destination_code = header.bytes[23]
  header.mask_rom_version_number = header.bytes[25]
  header.header_checksum = header.bytes[26]
  header.global_checksum = (header.bytes[27] << 8) | header.bytes[28]

  if not header:check_global_checksum() then
    log.warning("Header global checksum is not valid")
  end

  if not header:check_header_checksum() then
    log.warning("Header checksum is not valid")
    header.is_valid = false
  else
    header.is_valid = true
  end

  return header.is_valid
end

--- Read and validate a Game Boy header from an open ROM file.
-- Calculates the global checksum over the file while excluding offsets 0x014E and
-- 0x014F, updates `gb.file_header`, and leaves the file open at end of file.
-- @param file file* Open, readable, and seekable ROM file
-- @return boolean valid True when the header checksum is valid
local function parse_header_file(file)
  local byte_str
  byte_str = file:read(0x134) -- skip entry point and nintendo logo
  byte_str = file:read(27)

  -- compute global checksum
  file:seek("set")
  file_header.file_global_checksum = 0
  local off = 0
  while 1 do
    local byte = file:read(1)
    if byte == nil then break end
    byte = string.unpack("B", byte)
    -- if off ~= 0x014D and off ~= 0x014E and off ~= 0x14F then
    if off ~= 0x14E and off ~= 0x14F then
      file_header.file_global_checksum = file_header.file_global_checksum + byte
    end
    off = off + 1
  end
  file_header.file_global_checksum = file_header.file_global_checksum & 0xFFFF

  return parse_header(byte_str, file_header)
end

--- Read and validate the header from the connected Game Boy cartridge.
-- Initializes and powers the cartridge interface, dumps the first ROM page, updates
-- `gb.cart_header`, then resets the interface. The global checksum is not calculated.
-- @return boolean valid True when the header checksum is valid
local function parse_header_cart()
  -- initialize device i/o
  dict.io("IO_RESET")
  dict.io("GB_INIT")
  dict.io("GB_POWER_5V")

  -- dump data
  local byte_str = ""
  dump.dumptocallback(function(data) byte_str = byte_str .. data end, 1, { mapper = 0x0000, mem_type = "GB_PAGE" })

  -- reset device i/o
  dict.io("IO_RESET")

  byte_str = string.sub(byte_str, 0x134 + 1, 0x14F + 1)
  return parse_header(byte_str, cart_header)
end

--[[
██╗  ██╗███████╗██╗     ██████╗ ███████╗██████╗ ███████╗
██║  ██║██╔════╝██║     ██╔══██╗██╔════╝██╔══██╗██╔════╝
███████║█████╗  ██║     ██████╔╝█████╗  ██████╔╝███████╗
██╔══██║██╔══╝  ██║     ██╔═══╝ ██╔══╝  ██╔══██╗╚════██║
██║  ██║███████╗███████╗██║     ███████╗██║  ██║███████║
╚═╝  ╚═╝╚══════╝╚══════╝╚═╝     ╚══════╝╚═╝  ╚═╝╚══════╝

--]]

--- Write a byte to the Game Boy cartridge ROM bus.
-- When global debug logging is enabled, logs the opcode, address, value, and comment.
-- @param addr integer ROM bus address
-- @param val integer Byte to write
-- @param options? table Write options
-- @param options.comment? string Text appended to the debug log; defaults to an empty string
-- @param options.opcode? string Game Boy dictionary opcode; defaults to GB_WR
local function rom_wr(addr, val, options)
  options = options or {}
  local comment = options.comment or ""
  local opcode = options.opcode or "GB_WR"

  dict.gb(opcode, addr, val)
  if DEBUG then log.bullet("ROM", " W", opcode, help.hex_0x4(addr), val, help.hex_0x2(val), comment) end
end

--- Read a byte from the Game Boy cartridge ROM bus.
-- When global debug logging is enabled, logs the opcode, address, value, and comment.
-- @param addr integer ROM bus address
-- @param options? table Read options
-- @param options.comment? string Text appended to the debug log; defaults to an empty string
-- @param options.opcode? string Game Boy dictionary opcode; defaults to GB_RD
-- @return integer value Byte returned by the dictionary opcode
local function rom_rd(addr, options)
  options = options or {}
  local comment = options.comment or ""
  local opcode = options.opcode or "GB_RD"
  local rv

  rv = dict.gb(opcode, addr)
  if DEBUG then log.bullet("ROM", "R ", opcode, help.hex_0x4(addr), rv, help.hex_0x2(rv), comment) end
  return rv
end

--[[
███████╗██╗  ██╗██████╗  ██████╗ ██████╗ ████████╗
██╔════╝╚██╗██╔╝██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝
█████╗   ╚███╔╝ ██████╔╝██║   ██║██████╔╝   ██║
██╔══╝   ██╔██╗ ██╔═══╝ ██║   ██║██╔══██╗   ██║
███████╗██╔╝ ██╗██║     ╚██████╔╝██║  ██║   ██║
╚══════╝╚═╝  ╚═╝╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝

--]]

-- vars
gb.file_header       = file_header
gb.cart_header       = cart_header

-- functions
gb.parse_header      = parse_header
gb.parse_header_file = parse_header_file
gb.parse_header_cart = parse_header_cart

gb.rom_wr            = rom_wr
gb.rom_rd            = rom_rd

-- return the module's table
return gb
