-- create the module's table
local spinner = {}

-- import required modules
local colors = require 'scripts.app.ansicolors'
local help = require 'scripts.app.help'

-- file constants and global variables

-- local functions

-- local frames = { '[-]', '[\\]', '[-]', '[/]' }
local frames = { '-', '\\', '|', '/' }
-- local frames = { "■", "□", "▪", "▫", "▪", "□" }
-- local frames = { "▌", "▀", "▐", "▄" }
-- local frames = { "▓", "▒", "░", "▒" }
-- local frames = { "┤", "┘", "┴", "└", "├", "┌", "┬", "┐" }
-- local frames = {"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"} -- doesn't work on Windows
-- local frames = {  "( ●    )",
--                   "(  ●   )",
--                   "(   ●  )",
--                   "(    ● )",
--                   "(     ●)",
--                   "(    ● )",
--                   "(   ●  )",
--                   "(  ●   )",
--                   "( ●    )",
--                   "(●     )" }
local step = 0
-- local time = 0
local text = ""
local prefix = ""
local suffix = ""
local back = ""
local size = 0

if (opts.gui == nil or opts.gui == false) then
  prefix = "%{reverse bright}     "
  suffix = " ...     %{reset}"
end

local function display()
  if (opts.gui == nil or opts.gui == false) then -- USING CLI
    text = prefix .. text .. frames[step + 1] .. suffix
    back = ""
    size = string.len(text)
    for i = 1, size, 1 do
      back = back .. "\b"
    end
    io.write(colors(text) .. back)
  else -- USING GUI
    gui_spinner_update(text .. frames[step + 1] .. " ...")
  end
end

local function update(...)
  text = help.parse_str_args(" ", ...)
  for i = 1, string.len(frames[1]), 1 do
    text = text .. " "
  end
  step = (step + 1) % #frames
  display()
end

local function clear()
  if (opts.gui == nil or opts.gui == false) then -- USING CLI
    text = "%{reset}"
    for i = 1, size - 1, 1 do
      text = text .. " "
    end
    size = 0
    io.write(colors(text) .. back)
  else -- USING GUI
    gui_spinner_clear()
  end
end

-- global variables so other modules can use them

-- call functions desired to run when script is called/imported

-- functions other modules are able to call
spinner.update = update
spinner.clear = clear

-- return the module's table
return spinner
