-- create the module's table
local auto    = {}

-- import required modules
local dict    = require "scripts.app.dict"
local snes    = require "scripts.app.snes"
local log     = require "scripts.app.log"

local lorom   = require "scripts.snes.lorom"
local hirom   = require "scripts.snes.hirom"

-- file constants and global variables
local mapname = nil

-- local functions

--[[
██████╗ ██████╗  ██████╗  ██████╗███████╗███████╗███████╗
██╔══██╗██╔══██╗██╔═══██╗██╔════╝██╔════╝██╔════╝██╔════╝
██████╔╝██████╔╝██║   ██║██║     █████╗  ███████╗███████╗
██╔═══╝ ██╔══██╗██║   ██║██║     ██╔══╝  ╚════██║╚════██║
██║     ██║  ██║╚██████╔╝╚██████╗███████╗███████║███████║
╚═╝     ╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚══════╝╚══════╝╚══════╝

--]]

--- Detect the cartridge mapper and delegate all requested operations.
-- @param process_opts table Parsed operation options from the main application
-- @param console_opts table Console/cartridge size options
-- @return false|nil result False when the header mapper is invalid, the delegated result otherwise
local function process(process_opts, console_opts)
  -- process options
  local do_rom_write = process_opts.do_rom_write

  if not do_rom_write and snes.cart_header.is_valid then
    if snes.cart_header.is_lorom == true then
      mapname = "LOROM"
    elseif snes.cart_header.is_lorom == false then
      mapname = "HIROM"
    end
  end

  if do_rom_write then
    log.error("ROM write does is not available in 'auto' mode")
  elseif mapname == "LOROM" then
    return lorom.process(process_opts, console_opts)
  elseif mapname == "HIROM" then
    return hirom.process(process_opts, console_opts)
  else
    log.error("Couldn't detect mapper")
  end

  return DONE(true)
end

-- global variables so other modules can use them

-- call functions desired to run when script is called/imported

-- functions other modules are able to call
auto.process = process

-- return the module's table
return auto
