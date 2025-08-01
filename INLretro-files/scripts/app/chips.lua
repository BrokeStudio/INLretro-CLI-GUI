-- create the module's table
local chips         = {}

-- import required modules
local help          = require "scripts.app.help"
local log           = require "scripts.app.log"

-- file constants and global variables

-- local functions

local manufacturers = {
  { name = "SST",                id = 0xBF },
  { name = "Cypress / Spansion", id = 0x01 },
  { name = "MX",                 id = 0xC2 },
}

local devices       = {
  { manufacturer_id = 0xBF, id = 0xB7,     part_number = "SST39SF040",                                size = 512 },
  { manufacturer_id = 0xBF, id = 0xB6,     part_number = "SST39SF020",                                size = 256 },
  { manufacturer_id = 0xBF, id = 0xB5,     part_number = "SST39SF010A",                               size = 128 },

  { manufacturer_id = 0xBF, id = 0xC8,     part_number = "SST39VF1681",                               size = 2048 },
  { manufacturer_id = 0xBF, id = 0xC9,     part_number = "SST39VF1682",                               size = 2048 },

  { manufacturer_id = 0xBF, id = 0x235A,   part_number = "SST39VF320 (top boot block)",               size = 4096 },
  { manufacturer_id = 0xBF, id = 0x235B,   part_number = "SST39VF320 (bottom boot block)",            size = 4096 },

  { manufacturer_id = 0xC2, id = 0x22A7,   part_number = "MF29LV320 (top boot block)",                size = 4096 },
  { manufacturer_id = 0xC2, id = 0x22A8,   part_number = "MF29LV320 (bottom boot block)",             size = 4096 },

  { manufacturer_id = 0x01, id = 0xDA0000, part_number = "S29AL008 (top boot block)",                 size = 1024 },
  { manufacturer_id = 0x01, id = 0x5B0000, part_number = "S29AL008 (bottom boot block)",              size = 1024 },

  { manufacturer_id = 0x01, id = 0xC40000, part_number = "S29AL016 (top boot block)",                 size = 2048 },
  { manufacturer_id = 0x01, id = 0x490000, part_number = "S29AL016 (bottom boot block)",              size = 2048 },

  { manufacturer_id = 0x01, id = 0x7E0A00, part_number = "S29JL032 (bottom boot block)",              size = 4096 },
  { manufacturer_id = 0x01, id = 0x7E0A01, part_number = "S29JL032 (top boot block)",                 size = 4096 },

  { manufacturer_id = 0x01, id = 0x7E0201, part_number = "S29JL064 (top/bottom boot block)",          size = 8192 },

  { manufacturer_id = 0x01, id = 0x7E0C01, part_number = "S29GL064 (uniform sector (01, 02, V1, V2)", size = 8192 },
  { manufacturer_id = 0x01, id = 0x7E1000, part_number = "S29GL064 (bottom boot block)",              size = 8192 },
  { manufacturer_id = 0x01, id = 0x7E1001, part_number = "S29GL064 (top boot block)",                 size = 8192 },

  { manufacturer_id = 0x01, id = 0x2221,   part_number = "S29GL128S (uniform sector)",                size = 16384 },
  { manufacturer_id = 0x01, id = 0x2222,   part_number = "S29GL256S (uniform sector)",                size = 32768 },
  { manufacturer_id = 0x01, id = 0x2223,   part_number = "S29GL512S (uniform sector)",                size = 65536 },
  { manufacturer_id = 0x01, id = 0x2228,   part_number = "S29GL01GS (uniform sector)",                size = 131072 },

}

local function get_manufacturer(manufacturer_id)
  for k, v in ipairs(manufacturers) do
    if v.id == manufacturer_id then
      return v
    end
  end
  return {}
end

local function get_device(manufacturer_id, device_id)
  for k, v in ipairs(devices) do
    if v.manufacturer_id == manufacturer_id and v.id == device_id then
      return v
    end
  end
  return {}
end

local function display_manufacturer(manufacturer_id)
  local manufacturer = chips.get_manufacturer(manufacturer_id)
  if next(manufacturer) == nil then
    log.warning("Manuf. unknown", help.hex(manufacturer_id, 6, "0x"))
    return false
  else
    log.bullet("Manuf. ID", help.hex(manufacturer_id, 6, "0x"), manufacturer.name)
    return true
  end
end

local function display_device(manufacturer_id, device_id)
  local device = chips.get_device(manufacturer_id, device_id)
  if next(device) == nil then
    log.warning("Device unknown", help.hex(device_id, 6, "0x"))
    return false
  else
    log.bullet("Device ID", help.hex(device_id, 6, "0x"), device.part_number)
    log.bullet("Chip size", device.size .. "KB")
    return device
  end
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
