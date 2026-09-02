-- create the module's table
local help = {}

-- import required modules

-- file constants and global variables

-- local functions
local function get_script_path()
  local str = debug.getinfo(1).source:sub(2)
  local sep = package.config:sub(1, 1)
  local pattern
  if sep == "\\" then
    pattern = "(.*\\)"
  else
    pattern = "(.*/)"
  end
  return str:match(pattern) --:match("str_match")
end

local function file_exists(filename)
  local f = io.open(filename, "r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

--- Check if a file or directory exists in this path
local function exists(path)
  local ok, err, code = os.rename(path, path)
  if not ok then
    if code == 13 then
      -- Permission denied, but it exists
      return true
    end
  end
  return ok, err
end

local function file_copy(old_path, new_path)
  local old_file = io.open(old_path)
  local new_file = io.open(new_path, "w")
  if not old_file or not new_file then
    return false
  end
  while true do
    local block = old_file:read(2 ^ 13)
    if not block then break end
    new_file:write(block)
  end
  old_file:close()
  new_file:close()
  return true
end

local function parse_str_args(sep, ...)
  local args = { ... }
  local text = ""
  for i, v in ipairs(args) do
    text = text .. tostring(v)
    if (i ~= #args) then text = text .. sep end
  end
  return text
end

local function parse_filename(filename)
  local rv = {
    filename = "",
    path = "",
    name = "",
    base = "",
    ext = ""
  }
  if (type(filename) == "string") then
    local m = { string.match(filename, "(.-)([^\\/]-%.?([^%.\\/]*))$") }
    rv.filename = filename
    rv.path = m[1]
    rv.name = m[2]
    rv.base = m[2]:gsub("." .. m[3], "")
    rv.ext = m[3]:lower()
  end
  return rv
end

local function hex(data, digits, prefix)
  --if digits == nil or type(digits) ~= "number"then
  if type(digits) ~= "number" then
    digits = "%X"
  else
    digits = "%0" .. digits .. "X"
  end

  if prefix == nil then prefix = "" end

  return string.format(prefix .. digits, data)
end

local function hex_0x2(data)
  data = data & 0xFF
  return string.format("0x%02X", data)
end

local function hex_0x4(data)
  data = data & 0xFFFF
  return string.format("0x%04X", data)
end

local function hex_0x6(data)
  data = data & 0xFFFFFF
  return string.format("0x%06X", data)
end

local function hex_0x8(data)
  data = data & 0xFFFFFFFF
  return string.format("0x%08X", data)
end

-- file must already be open for writing in binary mode
local function file_wr_bin(file, data)
  file:write(string.char(data))
end

local function copy_table(orig)
  assert(type(orig) == "table", "copy_table expects a table")
  local copy = {}
  for orig_key, orig_value in pairs(orig) do
    copy[orig_key] = orig_value
  end
  return setmetatable(copy, getmetatable(orig))
end

local function dump_table(o, l)
  if l == nil or l == 0 then l = 1 end
  local tab = ""
  for i = 1, l * 2, 1 do
    tab = tab .. " "
  end
  if type(o) == 'table' then
    local s = '{ ' .. '\n'
    for k, v in pairs(o) do
      if type(k) ~= 'number' then k = '"' .. k .. '"' end
      s = s .. tab .. '[' .. k .. '] = ' .. dump_table(v, l + 1) .. ',' .. '\n'
    end
    return s .. tab:sub(1, -3) .. '}'
  else
    local t = tostring(o)
    if type(o) ~= 'number' and type(o) ~= 'boolean' then t = '"' .. t .. '"' end
    return tostring(t)
  end
end

local function sleep(seconds)
  -- log.point("Waiting for", seconds, "seconds...")
  local end_time = os.time() + seconds
  while os.time() < end_time do
  end
end

local function parse_additional_opts(str)
  local t = {}
  if str == nil then return true, t end

  -- split string by comma (,)
  local kvs = {}
  for sub_str in string.gmatch(str, '([^,]+)') do
    table.insert(kvs, sub_str)
  end

  -- split each key/value pairs by equal (=)
  for i, kv in pairs(kvs) do
    if not string.match(kv, "=") then
      t[string.lower(kv)] = true
    else
      for k, v in string.gmatch(kv, "([%w_]+)=([%w_]+)") do
        if (string.lower(v) == "true") then
          v = true
        elseif (string.lower(v) == "false") then
          v = false
        end
        t[string.lower(k)] = v
      end
    end
  end

  -- cleanup some options if needed
  for k, v in pairs(t) do
    if k == "force_wram_test" and type(v) ~= "boolean" then t[k] = false end
    if k == "force_flash_test" and type(v) ~= "boolean" then t[k] = false end
    if k == "no_bin_regen" and type(v) ~= "boolean" then t[k] = false end
    if k == "flash_cic" and type(v) ~= "boolean" then t[k] = false end
    if k == "bank_table" then
      v = tonumber(v)
      if v == nil then return false, t, "Passed bank table address is missing/invalid" end
    end
  end

  return true, t
end

-- global variables so other modules can use them

-- call functions desired to run when script is called/imported

-- functions other modules are able to call
help.parse_filename        = parse_filename
help.hex                   = hex
help.hex_0x2               = hex_0x2
help.hex_0x4               = hex_0x4
help.hex_0x6               = hex_0x6
help.hex_0x8               = hex_0x8
help.file_wr_bin           = file_wr_bin
help.file_exists           = file_exists
help.exists                = exists
help.file_copy             = file_copy
help.parse_str_args        = parse_str_args
help.dump_table            = dump_table
help.copy_table            = copy_table
help.sleep                 = sleep
help.parse_additional_opts = parse_additional_opts
help.get_script_path       = get_script_path

-- return the module's table
return help
