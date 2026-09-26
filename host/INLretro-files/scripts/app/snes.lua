-- create the module's table
local snes          = {}

-- import required modules
local chips         = require "scripts.app.chips"
local dict          = require "scripts.app.dict"
local dump          = require "scripts.app.dump"
local help          = require "scripts.app.help"
local log           = require "scripts.app.log"
local time          = require "scripts.app.time"
local spinner       = require "scripts.app.spinner"
-- local swim  = require "scripts.app.swim"

-- file constants and global variables
local RESET_VECT_HI = 0xFFFD
local RESET_VECT_LO = 0xFFFC

local ROMSEL_LO     = 0
local ROMSEL_HI     = 1

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

  --- Return the ROM size declared by the header.
  -- @param self table SNES header
  -- @return integer size_kb ROM size in kilobytes
  get_rom_size = function(self)
    local rom_size = 1 << self.rom_size
    return rom_size
  end,

  --- Return the RAM size declared by the header.
  -- @param self table SNES header
  -- @return integer size_kb RAM size in kilobytes, or 0 when no RAM is declared
  get_ram_size = function(self)
    if self.ram_size == 0 then
      return 0
    end

    return 1 << self.ram_size
  end,

  --- Check whether the header declares cartridge RAM.
  -- @param self table SNES header
  -- @return boolean has_sram True when the declared RAM size is nonzero
  has_sram = function(self)
    return self:get_ram_size() ~= 0
  end,

  has_battery = function(self)
    local chipset = self.chipset & 0x0F

    return chipset == 0x02 or
        chipset == 0x05 or
        chipset == 0x06
  end,


  --- Compare the checksum calculated from the ROM with the checksum in the header.
  -- @param self table SNES header
  -- @return boolean valid True when both ROM checksums match
  check_rom_checksum = function(self)
    if self.rom_checksum == self.file_rom_checksum then
      return true
    else
      return false
    end
  end,

  --- Validate the checksum and checksum-complement fields.
  -- @param self table SNES header
  -- @return boolean valid True when both fields add up to 0xFFFF
  check_header_checksum = function(self)
    -- print(self.checksum, self.checksum_complement)
    if self.checksum + self.checksum_complement == 0xFFFF then
      return true
    else
      return false
    end
  end,

  --- Validate the emulation-mode reset vector.
  -- @param self table SNES header
  -- @return boolean valid True when the reset vector points to 0x8000-0xFFFF
  check_vectors = function(self)
    if
    -- self.vectors._65c816.COP < 0x8000 or
    -- self.vectors._65c816.BRK < 0x8000 or
    -- self.vectors._65c816.ABORT < 0x8000 or
    -- self.vectors._65c816.NMI < 0x8000 or
    -- self.vectors._65c816.IRQ < 0x8000 or
    -- self.vectors._6502.COP < 0x8000 or
    -- self.vectors._6502.ABORT < 0x8000 or
    -- self.vectors._6502.NMI < 0x8000 or
        self.vectors._6502.RESET < 0x8000 then -- or
      -- self.vectors._6502.IRQ < 0x8000 then
      return false
    end

    return true
  end,

}

local file_header = help.copy_table(Header)
local cart_header = help.copy_table(Header)

--- Parse a 64-byte SNES internal header into a header table.
-- @param byte_str string Raw internal-header bytes
-- @param header table Header table to populate
-- @return boolean valid True when the checksum fields and reset vector are valid
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


--- Locate and parse the SNES internal header in an already-open ROM file.
-- Supports LoROM, HiROM, ExLoROM, ExHiROM, and optional 512-byte SMC headers.
-- Leaves the file open and changes its current position.
-- @param file file* Open binary ROM file
-- @return boolean valid True when a valid internal header is found and parsed
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
      log.info("ExLoROM mapper detected")
    else
      log.info("LoROM mapper detected")
    end
  else
    if file_header.is_exrom then
      log.info("ExHiROM mapper detected")
    else
      log.info("HiROM mapper detected")
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

--- Read and parse the internal header directly from a cartridge.
-- Tries HiROM first, then LoROM; does not calculate the full-ROM checksum.
-- @return boolean valid True when a matching HiROM or LoROM header is found
local function parse_header_cart()
  local byte_str
  local rv

  -- first we try to get the ROM header using HIROM settings
  -- if it doesn't work, then try using LOROM settings

  -- HIROM
  log.point("Trying to dump header using HiROM settings")
  byte_str = ""

  -- initialize device i/o
  dict.io("IO_RESET")
  dict.io("SNES_INIT")

  -- dump data
  dict.snes("SNES_SET_BANK", 0x40)
  dump.dumptocallback(
    function(data) byte_str = byte_str .. data end,
    64, { mapper = "HIROM", mem_type = "SNES_ROM" }
  )

  -- reset device i/o
  dict.io("IO_RESET")

  byte_str = string.sub(byte_str, 0xFFC0 + 1, 0xFFFF + 1)
  if parse_header(byte_str, cart_header) and cart_header.rom_type.mode == 1 then
    log.info("HiROM mapper detected")
    return true
  end

  -- LOROM
  log.point("Trying to dump header using LoROM settings")
  byte_str = ""

  -- initialize device i/o
  dict.io("SNES_INIT")

  -- dump data
  dict.snes("SNES_SET_BANK", 0x00)
  dump.dumptocallback(
    function(data) byte_str = byte_str .. data end,
    32, { mapper = "LOROM", mem_type = "SNES_ROM" }
  )

  -- reset device i/o
  dict.io("IO_RESET")

  byte_str = string.sub(byte_str, 0x7FC0 + 1, 0x7FFF + 1)
  if parse_header(byte_str, cart_header) and cart_header.rom_type.mode == 0 then
    log.info("LoROM mapper detected")
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

--- Put the cartridge hardware into flash-programming mode.
local function prgm_mode()
  if DEBUG then print("going to program mode, swim:", snes_swimcart) end
  if snes_swimcart then
    print("ERROR cart got set to swim mode somehow!!!")
    --   swim.snes_v3_prgm()
  else
    dict.pinport("CTL_SET_LO", "SNES_RST")
  end
end

--- Return the cartridge hardware to normal play mode.
local function play_mode()
  if DEBUG then print("going to play mode, swim:", snes_swimcart) end
  if snes_swimcart then
    --   swim.snes_v3_play()
    print("ERROR cart got set to swim mode somehow!!!")
  else
    dict.pinport("CTL_SET_HI", "SNES_RST")
  end
end

--- Read the emulation-mode reset vector from a SNES bank.
-- The device I/O must already be initialized for SNES access.
-- @param bank integer Bank to select before reading the vector
-- @return integer vector 16-bit reset vector
local function read_reset_vector(bank)
  --ensure cart is in play mode
  play_mode()

  --first set SNES bank A16-23
  dict.snes("SNES_SET_BANK", bank)

  --read reset vector high byte
  vector = dict.snes("SNES_RD", RESET_VECT_HI, ROMSEL_LO)
  --shift high byte of vector to where it belongs
  vector = vector << 8
  --read low byte of vector
  vector = vector | dict.snes("SNES_RD", RESET_VECT_LO, ROMSEL_LO)

  if DEBUG then print("SNES bank:", bank, "reset vector", string.format("$%x", vector)) end

  return vector
end

--- Enter software-ID mode and probe for the expected flash ROM.
-- The device I/O must already be initialized for SNES access.
-- @return boolean found True when manufacturer 0x01 and product 0x49 are read
local function read_flashID()
  local rv
  --enter software mode A11 is highest address bit that needs to be valid
  --datasheet not exactly explicit, A11 might not need to be valid
  --part has A-1 (negative 1) since it's in byte mode, meaning the part's A11 is actually A12
  --WR $AAA:AA $555:55 $AAA:AA
  dict.snes("SNES_SET_BANK", 0x00)

  --put cart in program mode
  --v3.0 boards don't use EXP0 for program mode, must use SWIM via CIC
  prgm_mode()

  dict.snes("SNES_WR_LO", 0x0AAA, 0xAA)
  dict.snes("SNES_WR_LO", 0x0555, 0x55)
  dict.snes("SNES_WR_LO", 0x0AAA, 0x90)

  --exit program mode
  play_mode()

  --read manf ID
  local manf_id = dict.snes("SNES_RD", 0x0000, ROMSEL_LO)
  if DEBUG then print("attempted read SNES ROM manf ID:", string.format("%X", manf_id)) end

  --read prod ID
  local prod_id = dict.snes("SNES_RD", 0x0002, ROMSEL_LO)
  if DEBUG then print("attempted read SNES ROM prod ID:", string.format("%X", prod_id)) end
  local density_id = dict.snes("SNES_RD", 0x001C, ROMSEL_LO)
  if DEBUG then print("attempted read SNES density ID: ", string.format("%X", density_id)) end
  local boot_sect = dict.snes("SNES_RD", 0x001E, ROMSEL_LO)
  if DEBUG then print("attempted read SNES boot sect ID:", string.format("%X", boot_sect)) end

  --put cart in program mode
  prgm_mode()

  -- exit software
  dict.snes("SNES_WR_LO", 0x0000, 0xF0)

  --exit program mode
  play_mode()

  --return true if detected flash chip
  if (manf_id == 0x01 and prod_id == 0x49) then
    return true
  else
    return false
  end
end

--- Issue a SNES write using the opcode selected by the access options.
-- @param addr integer 16-bit bus address
-- @param val integer 8-bit value to write
-- @param options table Access options; `romsel` selects the default opcode and `opcode` overrides it
-- @return string opcode Opcode sent to the firmware
local function wr(addr, val, options)
  local romsel = options.romsel or ROMSEL_LO
  local default_opcode
  if romsel == 0 then
    default_opcode = "SNES_WR_LO"
  else
    default_opcode = "SNES_WR_HI"
  end
  local opcode = options.opcode or default_opcode

  dict.snes(opcode, addr, val)
  return opcode
end

--- Issue a SNES read using the opcode selected by the access options.
-- @param addr integer 16-bit bus address
-- @param options table Access options; `romsel` controls /ROMSEL and `opcode` overrides SNES_RD
-- @return integer value 8-bit value read from the bus
-- @return string opcode Opcode sent to the firmware
local function rd(addr, options)
  local romsel = options.romsel or ROMSEL_LO
  local opcode = options.opcode or "SNES_RD"
  local rv

  rv = dict.snes(opcode, addr, romsel)
  return rv, opcode
end

--- Write one byte through the SNES ROM access wrapper.
-- @param addr integer 16-bit bus address
-- @param val integer 8-bit value to write
-- @param options table|nil Optional access and debug-log settings
local function rom_wr(addr, val, options)
  options = options or {}
  local comment = options.comment or ""
  local opcode = wr(addr, val, options)
  if DEBUG then log.point("ROM", " W", opcode, help.hex(addr, 4, "0x"), val, help.hex(val, 2, "0x"), comment) end
end

--- Read one byte through the SNES ROM access wrapper.
-- @param addr integer 16-bit bus address
-- @param options table|nil Optional access and debug-log settings
-- @return integer value 8-bit value read from the bus
local function rom_rd(addr, options)
  options = options or {}
  local comment = options.comment or ""
  local rv, opcode = rd(addr, options)
  if DEBUG then log.point("ROM", "R ", opcode, help.hex(addr, 4, "0x"), rv, help.hex(rv, 2, "0x"), comment) end
  return rv
end

--- Write one byte through the SNES RAM access wrapper.
-- @param addr integer 16-bit bus address
-- @param val integer 8-bit value to write
-- @param options table|nil Optional access and debug-log settings
local function ram_wr(addr, val, options)
  options = options or {}
  local comment = options.comment or ""
  local opcode = wr(addr, val, options)
  if DEBUG then log.point("RAM", " W", opcode, help.hex(addr, 4, "0x"), val, help.hex(val, 2, "0x"), comment) end
end

--- Read one byte through the SNES RAM access wrapper.
-- @param addr integer 16-bit bus address
-- @param options table|nil Optional access and debug-log settings
-- @return integer value 8-bit value read from the bus
local function ram_rd(addr, options)
  options = options or {}
  local comment = options.comment or ""
  local rv, opcode = rd(addr, options)
  if DEBUG then log.point("RAM", "R ", opcode, help.hex(addr, 4, "0x"), rv, help.hex(rv, 2, "0x"), comment) end
  return rv
end


--- Read and identify the ROM flash manufacturer in software identification mode.
-- The caller must enter identification mode and reset the flash afterward.
-- Both short and long profiles read the manufacturer ID at CPU address 0x8000.
-- Other profile names, including nil, return false and an empty table without reading the bus.
-- @param options table Selected unlock profile and read options
-- @param options.unlock_profile_name string Short or long unlock profile
-- @return boolean found True when recognized, false when unknown or the profile is unsupported
-- @return table manufacturer Manufacturer name and ID, or an empty table when unknown or the profile is unsupported
local function rom_get_manufacturer(options)
  local manufacturer_id

  if DEBUG then log.info("Trying to read manufacturer id") end

  if options.unlock_profile_name == "short" or options.unlock_profile_name == "long" then
    manufacturer_id = rom_rd(options.addr_base)
    return chips.get_manufacturer(manufacturer_id)
  end

  return false, {}
end

--- Read and identify the ROM flash device in software identification mode.
-- The caller must enter identification mode and reset the flash afterward.
-- Both profiles first read the device ID at CPU address 0x8001.
-- If the short-profile ID is unknown, reads 0x8002, 0x801C, and 0x801E
-- as the high, middle, and low bytes of a 24-bit device ID.
-- Other profile names, including nil, cause the function to return no values.
-- @param options table Detected manufacturer, unlock profile, and read options
-- @param options.manufacturer table Manufacturer information containing its id
-- @param options.unlock_profile_name string Short or long unlock profile
-- @return boolean|nil found True when the manufacturer/device pair is recognized, false when unknown, or nil for other profiles
-- @return table|nil device Chip information, an empty table when unknown, or nil for other profiles
local function rom_get_device(options)
  local device_id
  local device
  local found

  if DEBUG then log.info("Trying to read device id") end

  if options.unlock_profile_name == "short" then
    device_id = rom_rd(options.addr_base + 0x01)
    found, device = chips.get_device(options.manufacturer.id, device_id)

    if not found then
      device_id = rom_rd(options.addr_base + 0x02) << 16
      device_id = device_id | (rom_rd(options.addr_base + 0x1C) << 8)
      device_id = device_id | rom_rd(options.addr_base + 0x1E)
      found, device = chips.get_device(options.manufacturer.id, device_id)
    end

    return found, device
  elseif options.unlock_profile_name == "long" then
    device_id = rom_rd(options.addr_base + 0x01)
    return chips.get_device(options.manufacturer.id, device_id)
  end
end

--- Detect the ROM flash chip by trying manufacturer/device identification for each profile.
-- Tries only the supplied profile, or long then short until a device is recognized.
-- Sends the 0xAA/0x55/0x90 identification sequence using each profile's resolved addresses
-- before reading the manufacturer and device IDs.
-- Logs each recognized manufacturer even if its device is unknown.
-- Adds opcode and addr_base defaults to the supplied options; uses a separate table per attempt.
-- Address overrides must be supplied together.
-- Validates each profile before hardware access, then resets before and after identification.
-- Unknown profiles are logged and skipped.
-- @param options? table Flash access options
-- @param options.opcode? string Flash write opcode; defaults to NES_CPU_WR
-- @param options.addr_base? integer Mask bitwise-ORed with profile addresses when no overrides are supplied; defaults to 0x8000
-- @param options.unlock_profile_name? string Restrict probing to this unlock profile
-- @param options.unlock_addr1? integer Final first unlock address override; bypasses addr_base
-- @param options.unlock_addr2? integer Final second unlock address override; bypasses addr_base
-- @return boolean found True when both manufacturer and device are recognized
-- @return table device Chip information, or an empty table on validation or detection failure
local function rom_get_chip(options)
  log.section("Reading ROM manufacturer/device ID")

  local manufacturer = {}
  local manufacturer_found = false
  local device = {}
  local device_found = false

  options = options or {}
  options.opcode = options.opcode or "SNES_WR_LO"
  options.bank = options.bank or 0x00
  options.addr_base = options.addr_base or 0x0000

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

      local addr1 = options.unlock_addr1 or (unlock_profile.addr1 | options.addr_base)
      local addr2 = options.unlock_addr2 or (unlock_profile.addr2 | options.addr_base)

      if DEBUG then
        log.point("unlock profile name:", unlock_profile_name)
        log.point("unlock addr1:", help.hex_0x4(addr1))
        log.point("unlock addr2:", help.hex_0x4(addr2))
      end

      -- exit software
      rom_wr(options.addr_base, 0xF0, { opcode = test_options.opcode })

      dict.snes("SNES_SET_BANK", 0x00)

      -- write sequence
      rom_wr(addr1, 0xAA, { opcode = test_options.opcode })
      rom_wr(addr2, 0x55, { opcode = test_options.opcode })
      rom_wr(addr1, 0x90, { opcode = test_options.opcode })

      manufacturer_found, manufacturer = rom_get_manufacturer(test_options)

      if manufacturer_found then
        chips.display_manufacturer(manufacturer.id)
        test_options.manufacturer = manufacturer
        device_found, device = rom_get_device(test_options)
      end

      -- exit software
      rom_wr(options.addr_base, 0xF0, { opcode = test_options.opcode })

      if device_found then
        chips.display_device(manufacturer.id, device.id)
        return true, device
      end
    end
  end

  return false, {}
end


--- Erase the entire ROM flash chip and poll 0x8000 until consecutive reads match.
-- Both short and long unlock profiles are supported; other profiles return false.
-- Polling has no timeout, and a true return value does not verify that the chip is blank.
-- @param device table Flash chip information containing size in KiB and unlock_profile_name
-- @param options? table Flash access options
-- @param options.opcode? string Flash write opcode; defaults to NES_CPU_WR
-- @param options.addr_base? integer Mask bitwise-ORed with profile addresses without overrides; defaults to 0x8000
-- @param options.unlock_addr1? integer Final first unlock address override, used without applying addr_base
-- @param options.unlock_addr2? integer Final second unlock address override, used without applying addr_base
-- @return boolean completed True when polling completes, or false for an unsupported profile
local function rom_erase(device, options)
  options = options or {}
  local opcode = options.opcode or "SNES_WR_LO"
  local bank = options.bank or 0x00
  local addr_base = options.addr_base or 0x0000
  local unlock_profile = chips.unlock_profiles[device.unlock_profile_name]
  local i = 0
  local rv

  log.section("Erasing ROM")
  log.bullet("Chip size", device.size .. "KB")

  if device.unlock_profile_name == "short" or device.unlock_profile_name == "long" then
    time.start()

    local addr1 = options.unlock_addr1 or (unlock_profile.addr1 | addr_base)
    local addr2 = options.unlock_addr2 or (unlock_profile.addr2 | addr_base)

    if DEBUG then
      log.point("unlock profile name", device.unlock_profile_name)
      log.point("unlock addr1", help.hex_0x4(addr1))
      log.point("unlock addr2", help.hex_0x4(addr2))
    end

    dict.snes("SNES_SET_BANK", bank)

    rom_wr(addr1, 0xAA, { opcode = opcode })
    rom_wr(addr2, 0x55, { opcode = opcode })
    rom_wr(addr1, 0x80, { opcode = opcode })
    rom_wr(addr1, 0xAA, { opcode = opcode })
    rom_wr(addr2, 0x55, { opcode = opcode })
    rom_wr(addr1, 0x10, { opcode = opcode })
  else
    log.error("Unlock profile unknwown:", device.unlock_profile_name)
    return false
  end

  rv = rom_rd(options.addr_base)
  while rv ~= rom_rd(options.addr_base) do
    spinner.update("Erasing")
    rv = rom_rd(options.addr_base)
    i = i + 1
  end
  spinner.clear()
  log.success("Done erasing ROM", i .. " naks")
  time.report(device.size)

  return true
end

snes.rom_rd = rom_rd
snes.rom_wr = rom_wr
snes.ram_rd = ram_rd
snes.ram_wr = ram_wr

snes.rom_get_chip = rom_get_chip
snes.rom_erase = rom_erase

snes.ROMSEL_LO = ROMSEL_LO
snes.ROMSEL_HI = ROMSEL_HI

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

snes.read_reset_vector = read_reset_vector
snes.read_flashID      = read_flashID
snes.prgm_mode         = prgm_mode
snes.play_mode         = play_mode

-- return the module's table
return snes
