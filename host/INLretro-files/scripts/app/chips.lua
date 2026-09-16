-- create the module's table
local chips         = {}

-- import required modules
local help          = require "scripts.app.help"
local log           = require "scripts.app.log"

-- file constants and global variables

-- local functions

local manufacturers = {
  { name = "Cypress / Spansion", id = 0x01 },
  { name = "Hynix",              id = 0xAD },
  { name = "SST",                id = 0xBF },
  { name = "MX",                 id = 0xC2 },
}

local devices       = {
  -- S29AL008
  { manufacturer_id = 0x01, id = 0xDA0000, part_number = "S29AL008 (top boot block)",                 size = 1024,    unlock_bypass = true,  buffer = false },
  { manufacturer_id = 0x01, id = 0x5B0000, part_number = "S29AL008 (bottom boot block)",              size = 1024,    unlock_bypass = true,  buffer = false },

  -- S29AL016
  { manufacturer_id = 0x01, id = 0xC40000, part_number = "S29AL016 (top boot block)",                 size = 2048,    unlock_bypass = true,  buffer = false },
  { manufacturer_id = 0x01, id = 0x490000, part_number = "S29AL016 (bottom boot block)",              size = 2048,    unlock_bypass = true,  buffer = false },

  -- S29JL032
  { manufacturer_id = 0x01, id = 0x7E0A00, part_number = "S29JL032 (bottom boot block)",              size = 4096,    unlock_bypass = true,  buffer = false },
  { manufacturer_id = 0x01, id = 0x7E0A01, part_number = "S29JL032 (top boot block)",                 size = 4096,    unlock_bypass = true,  buffer = false },

  -- S29JL064
  { manufacturer_id = 0x01, id = 0x7E0201, part_number = "S29JL064 (top/bottom boot block)",          size = 8192,    unlock_bypass = true,  buffer = false },

  -- S29GL064S
  { manufacturer_id = 0x01, id = 0x7E0C01, part_number = "S29GL064S (uniform sector (01, 02, V1, V2)", size = 8192,    unlock_bypass = true,  buffer = true },
  { manufacturer_id = 0x01, id = 0x7E1000, part_number = "S29GL064S (bottom boot block)",              size = 8192,    unlock_bypass = true,  buffer = true },
  { manufacturer_id = 0x01, id = 0x7E1001, part_number = "S29GL064S (top boot block)",                 size = 8192,    unlock_bypass = true,  buffer = true },

  -- S29GL128S
  { manufacturer_id = 0x01, id = 0x2221,   part_number = "S29GL128S (uniform sector)",                size = 16384,   unlock_bypass = false,  buffer = true },
  { manufacturer_id = 0x01, id = 0x2222,   part_number = "S29GL256S (uniform sector)",                size = 32768,   unlock_bypass = false,  buffer = true },
  { manufacturer_id = 0x01, id = 0x2223,   part_number = "S29GL512S (uniform sector)",                size = 65536,   unlock_bypass = false,  buffer = true },
  { manufacturer_id = 0x01, id = 0x2228,   part_number = "S29GL01GS (uniform sector)",                size = 131072,  unlock_bypass = false,  buffer = true },

  -- HY29F400 / AMI29F400AB
  { manufacturer_id = 0xAD, id = 0x23,     part_number = "HY29F400 / AMI29F400AB (top boot block)",   size = 512,     unlock_bypass = false,  buffer = false },
  { manufacturer_id = 0xAD, id = 0xAB,     part_number = "HY29F400 / AMI29F400AB (bottom boot block)",size = 512,     unlock_bypass = false,  buffer = false },
  { manufacturer_id = 0xAD, id = 0x2223,   part_number = "HY29F400 / AMI29F400AB (top boot block)",   size = 512,     unlock_bypass = false,  buffer = false },
  { manufacturer_id = 0xAD, id = 0x22AB,   part_number = "HY29F400 / AMI29F400AB (bottom boot block)",size = 512,     unlock_bypass = false,  buffer = false },

  --SST39SF
  { manufacturer_id = 0xBF, id = 0xB7,     part_number = "SST39SF040",                                size = 512,     unlock_bypass = false,  buffer = false },
  { manufacturer_id = 0xBF, id = 0xB6,     part_number = "SST39SF020",                                size = 256,     unlock_bypass = false,  buffer = false },
  { manufacturer_id = 0xBF, id = 0xB5,     part_number = "SST39SF010A",                               size = 128,     unlock_bypass = false,  buffer = false },

  -- SST39VF168*
  { manufacturer_id = 0xBF, id = 0xC8,     part_number = "SST39VF1681",                               size = 2048,    unlock_bypass = false,  buffer = false },
  { manufacturer_id = 0xBF, id = 0xC9,     part_number = "SST39VF1682",                               size = 2048,    unlock_bypass = false,  buffer = false },

  -- SST39VF320
  { manufacturer_id = 0xBF, id = 0x235A,   part_number = "SST39VF320 (top boot block)",               size = 4096,    unlock_bypass = false,  buffer = false },
  { manufacturer_id = 0xBF, id = 0x235B,   part_number = "SST39VF320 (bottom boot block)",            size = 4096,    unlock_bypass = false,  buffer = false },

  -- MX29LV320 - WORD mode
  { manufacturer_id = 0xC2, id = 0x22A7,   part_number = "MX29LV320 (top boot block)",                size = 4096,    unlock_bypass = false,  buffer = false },
  { manufacturer_id = 0xC2, id = 0x22A8,   part_number = "MX29LV320 (bottom boot block)",             size = 4096,    unlock_bypass = false,  buffer = false },

  -- MX29LV320 - BYTE mode
  { manufacturer_id = 0xC2, id = 0xA7,     part_number = "MX29LV320 (top boot block)",                size = 4096,    unlock_bypass = false,  buffer = false },
  { manufacturer_id = 0xC2, id = 0xA8,     part_number = "MX29LV320 (bottom boot block)",             size = 4096,    unlock_bypass = false,  buffer = false },

}

--- Look up a flash chip manufacturer by ID.
-- @param manufacturer_id integer Flash manufacturer ID
-- @return boolean found True when the manufacturer is recognized
-- @return table manufacturer Manufacturer name and ID, or an empty table when unknown
local function get_manufacturer(manufacturer_id)
  for k, v in ipairs(manufacturers) do
    if v.id == manufacturer_id then
      return true, v
    end
  end
  return false, {}
end

--- Look up a flash chip by manufacturer and device IDs.
-- @param manufacturer_id integer Flash manufacturer ID
-- @param device_id integer Flash device ID
-- @return boolean found True when the device is recognized
-- @return table device Device IDs, part number, size in KiB, and unlock_bypass/buffer support flags, or an empty table when unknown
local function get_device(manufacturer_id, device_id)
  for k, v in ipairs(devices) do
    if v.manufacturer_id == manufacturer_id and v.id == device_id then
      return true, v
    end
  end
  return false, {}
end

--- Log the flash manufacturer name and ID, or a warning when unknown.
-- @param manufacturer_id integer Flash manufacturer ID
-- @return boolean found True when the manufacturer is recognized
-- @return table manufacturer Manufacturer name and ID, or an empty table when unknown
local function display_manufacturer(manufacturer_id)
  local found, manufacturer
  found, manufacturer = chips.get_manufacturer(manufacturer_id)
  if found then
    log.bullet("Manuf. ID", help.hex(manufacturer_id, 6, "0x"), manufacturer.name)
  else
    log.warning("Manuf. unknown", help.hex(manufacturer_id, 6, "0x"))
  end
  return found, manufacturer
end

--- Log the flash device ID, part number, and size, or a warning when unknown.
-- @param manufacturer_id integer Flash manufacturer ID
-- @param device_id integer Flash device ID
-- @return boolean found True when the device is recognized
-- @return table device Device IDs, part number, size in KiB, and unlock_bypass/buffer support flags, or an empty table when unknown
local function display_device(manufacturer_id, device_id)
  local found, device
  found, device = chips.get_device(manufacturer_id, device_id)
  if found then
    log.bullet("Device ID", help.hex(device_id, 6, "0x"), device.part_number)
    log.bullet("Chip size", device.size .. "KB")
  else
    log.warning("Device unknown", help.hex(device_id, 6, "0x"))
    return false, {}
  end
  return found, device
end

-- global variables so other modules can use them

-- call functions desired to run when script is called/imported

-- functions other modules are able to call
chips.get_manufacturer = get_manufacturer
chips.get_device = get_device
chips.display_manufacturer = display_manufacturer
chips.display_device = display_device

-- return the module's table
return chips
