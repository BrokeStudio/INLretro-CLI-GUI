-- create the module's table
local genesis = {}

-- import required modules
local dict    = require "scripts.app.dict"
local dump    = require "scripts.app.dump"
local help    = require "scripts.app.help"
local log     = require "scripts.app.log"

-- local functions

--[[
██╗  ██╗███████╗ █████╗ ██████╗ ███████╗██████╗
██║  ██║██╔════╝██╔══██╗██╔══██╗██╔════╝██╔══██╗
███████║█████╗  ███████║██║  ██║█████╗  ██████╔╝
██╔══██║██╔══╝  ██╔══██║██║  ██║██╔══╝  ██╔══██╗
██║  ██║███████╗██║  ██║██████╔╝███████╗██║  ██║
╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝

--]]

local SOFTWARE_TYPES = {
  ["GM"] = "Game",
  ["AI"] = "Aid",
  ["OS"] = "Boot ROM (TMSS)",
  ["BR"] = "Boot ROM (Sega CD)",
}

local DEVICE_TYPES = {
  ["J"] = "3-button controller",
  ["6"] = "6-button controller",
  ["0"] = "Master System controller",
  ["A"] = "Analog joystick",
  ["4"] = "Multitap",
  ["G"] = "Lightgun",
  ["L"] = "Activator",
  ["M"] = "Mouse",
  ["B"] = "Trackball",
  ["T"] = "Tablet",
  ["V"] = "Paddle",
  ["K"] = "Keyboard or keypad",
  ["R"] = "RS-232",
  ["P"] = "Printer",
  ["C"] = "CD-ROM (Sega CD)",
  ["F"] = "Floppy drive",
  ["D"] = "Download?",
}

local REGION_TYPES = {
  ["J"] = "Japan",
  ["U"] = "Americas",
  ["E"] = "Europe",
}

local Header = {
  bytes = nil,
  is_valid = false,

  system_type = "",
  copyright_release_date = "",
  game_title_domestic = "",
  game_title_overseas = "",
  serial_number = "",
  rom_checksum = "",
  device_support = "",
  rom_address_range = "",
  ram_address_range = "",
  extra_memory = "",
  modem_support = "",
  region_support = "",

  -- return a value in KB
  get_rom_size = function(self)
    local rom_size = self.rom_address_range._end + 1 - self.rom_address_range._start
    rom_size = rom_size >> 10
    return rom_size
  end,

  -- return a value in KB
  get_ram_size = function(self)
    local ram_size = self.ram_address_range._end + 1 - self.ram_address_range._start
    ram_size = ram_size >> 10
    return ram_size
  end,

  has_sram = function(self)
    if
        self.extra_memory.ra == "RA" and
        self.extra_memory._x20 == 0x20 and
        (
          self.extra_memory.type == 0xA0 or -- no save  16-bit
          self.extra_memory.type == 0xB0 or -- no save   8-bit  even addresses
          self.extra_memory.type == 0xB8 or -- no save   8-bit  odd addresses
          self.extra_memory.type == 0xE0 or -- save     16-bit
          self.extra_memory.type == 0xF0 or -- save      8-bit  even addresses
          self.extra_memory.type == 0xF8    -- save      8-bit  odd addresses
        ) then
      return true
    else
      return false
    end
  end,

  -- return true or false
  has_battery = function(self)
    if
        self.extra_memory.type == 0xE0 or   -- save     16-bit
        self.extra_memory.type == 0xF0 or   -- save      8-bit  even addresses
        self.extra_memory.type == 0xF8 then -- save      8-bit  odd addresses
      return true
    end

    return false
  end,

  -- return true or false
  check_rom_checksum = function(self)
    if self.rom_checksum == self.file_rom_checksum then
      return true
    else
      return false
    end
  end,

}

local file_header = help.copy_table(Header)
local cart_header = help.copy_table(Header)

--- Parse a 256-byte Genesis ROM header into a header table.
---@param byte_str string Raw 256-byte header data, starting at ROM offset 0x100
---@param header table Header table to populate, usually genesis.file_header or genesis.cart_header
---@return boolean is_valid True when the parsed system type starts with "SEGA"
local function parse_header(byte_str, header)
  header.bytes = table.pack(string.unpack(string.rep('B', #byte_str), byte_str))
  header.system_type = string.sub(byte_str, 1, 16)
  header.copyright_release_date = string.sub(byte_str, 17, 32)
  header.game_title_domestic = string.sub(byte_str, 33, 80)
  header.game_title_overseas = string.sub(byte_str, 81, 128)
  header.serial_number = {
    software_type = string.sub(byte_str, 129, 130),
    serial_number = string.sub(byte_str, 132, 139),
    revision = string.sub(byte_str, 141, 142),
  }
  header.rom_checksum = string.unpack(">i2", string.sub(byte_str, 143, 144))
  header.device_support = string.sub(byte_str, 145, 160)
  header.rom_address_range = {
    _start = string.unpack(">i4", string.sub(byte_str, 161, 164)),
    _end = string.unpack(">i4", string.sub(byte_str, 165, 168))
  }
  header.ram_address_range = {
    _start = string.unpack(">i4", string.sub(byte_str, 169, 172)),
    _end = string.unpack(">i4", string.sub(byte_str, 173, 176))
  }
  header.extra_memory = {
    ra = string.sub(byte_str, 177, 178),
    type = string.unpack("B", string.sub(byte_str, 179, 179)),
    _x20 = string.unpack("B", string.sub(byte_str, 180, 180)),
    _start = string.unpack(">i4", string.sub(byte_str, 181, 184)),
    _end = string.unpack(">i4", string.sub(byte_str, 185, 188))
  }
  header.modem_support = string.sub(byte_str, 189, 200)
  header.region_support = string.sub(byte_str, 241, 243)

  if not header:check_rom_checksum() then
    log.warning("Rom checksum is not valid")
  end

  -- cheap test
  if string.sub(header.system_type, 1, 4) ~= "SEGA" then
    log.warning("System type doesn't start with 'SEGA'")
    header.is_valid = false
  else
    header.is_valid = true
  end

  return header.is_valid
end

--- Parse a Genesis ROM header from an already-open file.
--- Leaves the file open after parsing and computes the file checksum.
---@param file file* Open binary ROM file
---@return boolean is_valid True when the parsed system type starts with "SEGA"
local function parse_header_file(file)
  local byte_str
  byte_str = file:read(0x100) -- skip vectors
  byte_str = file:read(256)

  -- compute global checksum
  file:seek("set", 0x200)
  file_header.file_rom_checksum = 0
  local off = 0
  while 1 do
    local byte = file:read(2)
    if byte == nil then break end
    byte = string.unpack(">i2", byte)
    file_header.file_rom_checksum = file_header.file_rom_checksum + byte
    off = off + 1
  end
  file_header.file_rom_checksum = file_header.file_rom_checksum & 0xFFFF

  return parse_header(byte_str, file_header)
end

--- Parse a Genesis ROM header directly from the cartridge.
--- Reads the first ROM page through the basic Genesis dump path; checksum is not computed.
---@return boolean is_valid True when the parsed system type starts with "SEGA"
local function parse_header_cart()
  -- initialize device i/o
  dict.io("IO_RESET")
  dict.io("SEGA_INIT")

  -- dump data
  local byte_str = ""
  dump.dumptocallback(
    function(data) byte_str = byte_str .. data end,
    1, 0x0000, "GENESIS_ROM_PAGE0", false -- 64
  )

  -- reset device i/o
  dict.io("IO_RESET")

  byte_str = string.sub(byte_str, 0x100 + 1, 0x1FF + 1)
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

--- Read an 8-bit value from a Genesis /TIME register.
--- Register offset maps to CPU address 0xA13000 | addr.
---@param addr integer /TIME register offset, 0x00-0xFF
---@return integer|nil value 8-bit value read, or nil if addr is invalid
local function time_rd(addr)
  if (addr > 0xff) then
    log.error("/TIME addresse value too high ($00-$FF)")
    return
  end
  return dict.sega("GEN_TIME_RD", addr)
end

--- Read and log an 8-bit value from a Genesis /TIME register.
---@param addr integer /TIME register offset, 0x00-0xFF
---@param label? string Optional text appended to the log line
---@return integer|nil value 8-bit value read, or nil if addr is invalid
local function dbg_time_rd(addr, label)
  if not (type(label) == "string") then label = "" end
  local rv = time_rd(addr)
  log.bullet("TIME", "R ", help.hex_0x6(0xA13000 | (addr & 0xff)), help.hex_0x4(rv), "(" .. rv .. ")", label)
  return rv
end

--- Write an 8-bit value to a Genesis /TIME register.
--- Register offset maps to CPU address 0xA13000 | addr.
---@param addr integer /TIME register offset, 0x00-0xFF
---@param value integer 8-bit value to write
local function time_wr(addr, value)
  if (addr > 0xff) then
    log.error("/TIME addresse value too high ($00-$FF)")
    return
  end
  dict.sega("GEN_TIME_WR", addr, value)
end

--- Write and log an 8-bit value to a Genesis /TIME register.
---@param addr integer /TIME register offset, 0x00-0xFF
---@param value integer 8-bit value to write
---@param comment? string Optional text appended to the log line
local function dbg_time_wr(addr, value, comment)
  if not (type(comment) == "string") then comment = "" end
  time_wr(addr, value)
  log.bullet("TIME", " W", help.hex_0x6(0xA13000 | (addr & 0xff)), help.hex_0x4(value), "(" .. value .. ")", comment)
end

--- Set the current Genesis bus address from a full 24-bit address.
---@param addr integer 24-bit Genesis address, 0x000000-0xFFFFFF
local function set_addr(addr)
  local addr_hi = (addr >> 16) & 0xFF
  local addr_lo = addr & 0xFFFF
  dict.sega("GEN_SET_ADDR", addr_lo, addr_hi)

  -- or could do:
  -- dict.sega("GEN_SET_ADDR_HI", addr_hi)
  -- dict.sega("GEN_SET_ADDR_LO", addr_lo)
end

--- Set the high address latch used by subsequent Genesis bus accesses.
---@param addr_hi integer High address byte, 0x00-0xFF
local function set_addr_hi(addr_hi)
  dict.sega("GEN_SET_ADDR_HI", addr_hi)
end

--- Set the low address latch used by subsequent Genesis bus accesses.
---@param addr_lo integer Low address word, 0x0000-0xFFFF
local function set_addr_lo(addr_lo)
  dict.sega("GEN_SET_ADDR_LO", addr_lo)
end

--- Read a 16-bit word from the Genesis ROM bus.
--- Sets the full 24-bit address before reading.
---@param addr integer 24-bit Genesis address, 0x000000-0xFFFFFF
---@return integer value 16-bit value read from ROM
local function rom_rd(addr)
  local addr_lo = addr & 0xFFFF
  set_addr(addr)
  return dict.sega("GEN_ROM_RD", addr_lo)
end

--- Read and log a 16-bit word from the Genesis ROM bus.
---@param addr integer 24-bit Genesis address, 0x000000-0xFFFFFF
---@param label? string Optional text appended to the log line
---@return integer value 16-bit value read from ROM
local function dbg_rom_rd(addr, label)
  if not (type(label) == "string") then label = "" end
  local rv = rom_rd(addr)
  log.bullet("ROM", "R ", help.hex_0x6(addr), help.hex_0x4(rv), "(" .. rv .. ")", label)
  return rv
end

--- Write a 16-bit word to the Genesis ROM bus.
--- Sets the full 24-bit address before writing.
---@param addr integer 24-bit Genesis address, 0x000000-0xFFFFFF
---@param value integer 16-bit value to write
local function rom_wr(addr, value)
  set_addr(addr)
  dict.sega("GEN_ROM_WR", value)
end

--- Write and log a 16-bit word to the Genesis ROM bus.
---@param addr integer 24-bit Genesis address, 0x000000-0xFFFFFF
---@param value integer 16-bit value to write
---@param comment? string Optional text appended to the log line
local function dbg_rom_wr(addr, value, comment)
  if not (type(comment) == "string") then comment = "" end
  rom_wr(addr, value)
  log.bullet("ROM", " W", help.hex_0x6(addr), help.hex_0x4(value), "(" .. value .. ")", comment)
end

--- Read an 8-bit value from the Genesis RAM bus.
--- Sets the full 24-bit address before reading.
---@param addr integer 24-bit Genesis address, 0x000000-0xFFFFFF
---@return integer value 8-bit value read from RAM
local function ram_rd(addr)
  local addr_lo = addr & 0xFFFF
  set_addr(addr)
  return dict.sega("GEN_RAM_RD", addr_lo)
end

--- Read and log an 8-bit value from the Genesis RAM bus.
---@param addr integer 24-bit Genesis address, 0x000000-0xFFFFFF
---@param label? string Optional text appended to the log line
---@return integer value 8-bit value read from RAM
local function dbg_ram_rd(addr, label)
  if not (type(label) == "string") then label = "" end
  local rv = ram_rd(addr)
  log.bullet("RAM", "R ", help.hex_0x6(addr), help.hex_0x2(rv), "(" .. rv .. ")", label)
  return rv
end

--- Write an 8-bit value to the Genesis RAM bus.
--- Sets the full 24-bit address before writing.
---@param addr integer 24-bit Genesis address, 0x000000-0xFFFFFF
---@param value integer 8-bit value to write
local function ram_wr(addr, value)
  set_addr(addr)
  local addr_lo = addr & 0xFFFF
  dict.sega("GEN_RAM_WR", addr_lo, value)
end

--- Write and log an 8-bit value to the Genesis RAM bus.
---@param addr integer 24-bit Genesis address, 0x000000-0xFFFFFF
---@param value integer 8-bit value to write
---@param comment? string Optional text appended to the log line
local function dbg_ram_wr(addr, value, comment)
  if not (type(comment) == "string") then comment = "" end
  ram_wr(addr, value)
  log.bullet("RAM", " W", help.hex_0x6(addr), help.hex_0x2(value), "(" .. value .. ")", comment)
end

--- Enable Genesis cartridge SRAM through /TIME register 0xF1.
local function ram_enable()
  time_wr(0xF1, 0x01)
end

--- Disable Genesis cartridge SRAM through /TIME register 0xF1.
local function ram_disable()
  time_wr(0xF1, 0x00)
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
genesis.file_header       = file_header
genesis.cart_header       = cart_header

-- functions
genesis.parse_header      = parse_header
genesis.parse_header_file = parse_header_file
genesis.parse_header_cart = parse_header_cart

-- helpers
genesis.time_rd           = time_rd
genesis.dbg_time_rd       = dbg_time_rd
genesis.time_wr           = time_wr
genesis.dbg_time_wr       = dbg_time_wr

genesis.set_addr          = set_addr
genesis.set_addr_hi       = set_addr_hi
genesis.set_addr_lo       = set_addr_lo

genesis.rom_rd            = rom_rd
genesis.dbg_rom_rd        = dbg_rom_rd
genesis.rom_wr            = rom_wr
genesis.dbg_rom_wr        = dbg_rom_wr

genesis.ram_rd            = ram_rd
genesis.dbg_ram_rd        = dbg_ram_rd
genesis.ram_wr            = ram_wr
genesis.dbg_ram_wr        = dbg_ram_wr
genesis.ram_enable        = ram_enable
genesis.ram_disable       = ram_disable

-- return the module's table
return genesis
