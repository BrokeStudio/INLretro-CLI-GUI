
-- create the module's table
local genesis = {}

-- import required modules
local dict  = require "scripts.app.dict"
local dump  = require "scripts.app.dump"
local help  = require "scripts.app.help"
local log   = require "scripts.app.log"

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
  isValid = false,

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
      self.extra_memory.type == 0xE0 or    -- save     16-bit
      self.extra_memory.type == 0xF0 or    -- save      8-bit  even addresses
      self.extra_memory.type == 0xF8 then  -- save      8-bit  odd addresses
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
local rom_header = help.copy_table(Header)

-- parse header from data
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
    header.isValid = false
  else
    header.isValid = true
  end

  return header.isValid
end

-- pass a file pointer for a file which is already open
-- leave file open when done
local function parse_header_file(file)

  local byte_str
  byte_str = file:read(0x100)  -- skip vectors
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

-- parse header from rom
-- we should be able to read the header whatever the mapper is
-- global checksum won't be computed though
local function parse_header_rom()

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

  byte_str = string.sub(byte_str, 0x100+1, 0x1FF+1)
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

local function set_rom_address(addr)
  local addr_hi = ( addr >> 16 ) & 0xFF
  local addr_lo = addr & 0xFFFF
  dict.sega("GEN_SET_ADDR", addr_lo, addr_hi)

  -- or could do:
  -- dict.sega("GEN_SET_ADDR_HI", addr_hi)
  -- dict.sega("GEN_SET_ADDR_LO", addr_lo)
end

local function dbg_rom_wr(addr, val, debug, comment)
  if not (type(debug) == "boolean") then debug = true end
  if not (type(comment) == "string") then comment = "" end
  set_rom_address(addr)
  dict.sega("GEN_ROM_WR", val)
  if (debug) then log.bullet("ROM", " W", help.hex_0x6(addr), help.hex_0x4(val), "("..val..")", comment) end
end

local function rom_wr(addr, val)
  dbg_rom_wr(addr, val, false)
end

local function dbg_rom_rd(addr, debug, label)
  if not (type(debug) == "boolean") then debug = true end
  if not (type(label) == "string") then label = "" end
  local rv
  local addr_lo = addr & 0xFFFF
  set_rom_address(addr)
  rv = dict.sega("GEN_ROM_RD", addr_lo)
  if (debug) then log.bullet("ROM", "R ", help.hex_0x6(addr), help.hex_0x4(rv), "("..rv..")", label) end
  return rv
end

local function rom_rd(addr)
  return dbg_rom_rd(addr, false)
end

--[[
██████╗  █████╗ ███╗   ███╗
██╔══██╗██╔══██╗████╗ ████║
██████╔╝███████║██╔████╔██║
██╔══██╗██╔══██║██║╚██╔╝██║
██║  ██║██║  ██║██║ ╚═╝ ██║
╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝
                           
--]]

local function set_ram_address(addr)
  local addr_hi = ( addr >> 16 ) & 0xFF
  local addr_lo = addr & 0xFFFF
  dict.sega("GEN_SET_ADDR", addr_lo, addr_hi)

  -- or could do:
  -- dict.sega("GEN_SET_ADDR_HI", addr_hi)
  -- dict.sega("GEN_SET_ADDR_LO", addr_lo)
end

local function dbg_ram_wr(addr, val, debug, comment)
  if not (type(debug) == "boolean") then debug = true end
  if not (type(comment) == "string") then comment = "" end
  set_ram_address(addr)
  local addr_lo = addr & 0xFFFF
  dict.sega("GEN_RAM_WR", addr_lo, val)
  if (debug) then log.bullet("RAM", " W", help.hex_0x6(addr), help.hex_0x2(val), "("..val..")", comment) end
end

local function ram_wr(addr, val)
  dbg_ram_wr(addr, val, false)
end

local function dbg_ram_rd(addr, debug, label)
  if not (type(debug) == "boolean") then debug = true end
  if not (type(label) == "string") then label = "" end
  local rv
  local addr_lo = addr & 0xFFFF
  set_ram_address(addr)
  rv = dict.sega("GEN_RAM_RD", addr_lo)
  if (debug) then log.bullet("RAM", "R ", help.hex_0x6(addr), help.hex_0x2(rv), "("..rv..")", label) end
  return rv
end

local function ram_rd(addr)
  return dbg_ram_rd(addr, false)
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
genesis.rom_header        = rom_header

-- functions
genesis.parse_header      = parse_header
genesis.parse_header_file = parse_header_file
genesis.parse_header_rom  = parse_header_rom

genesis.set_rom_address = set_rom_address

genesis.dbg_rom_rd = dbg_rom_rd
genesis.dbg_rom_wr = dbg_rom_wr
genesis.rom_rd = rom_rd
genesis.rom_wr = rom_wr

genesis.dbg_ram_rd = dbg_ram_rd
genesis.dbg_ram_wr = dbg_ram_wr
genesis.ram_rd = ram_rd
genesis.ram_wr = ram_wr

-- return the module's table
return genesis
