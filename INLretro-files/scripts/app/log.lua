-- create the module's table
local log        = {}

-- import required modules
local ansicolors = require 'scripts.app.ansicolors'
local help       = require 'scripts.app.help'

-- file constants and global variables

-- local functions

local function isWindows()
  return type(package) == 'table' and type(package.config) == 'string' and package.config:sub(1, 1) == '\\'
end

local symbols = {
  ballotDisabled = '☒',
  ballotOff = '☐',
  ballotOn = '☑',
  bullet = '•',
  bulletWhite = '◦',
  fullBlock = '█',
  heart = '❤',
  identicalTo = '≡',
  line = '─',
  mark = '※',
  middot = '·',
  minus = '－',
  multiplication = '×',
  obelus = '÷',
  pencilDownRight = '✎',
  pencilRight = '✏',
  pencilUpRight = '✐',
  percent = '%',
  pilcrow2 = '❡',
  pilcrow = '¶',
  plusMinus = '±',
  section = '§',
  starsOff = '☆',
  starsOn = '★',
  upDownArrow = '↕',
  none = ''
};

if isWindows then
  symbols.check = '√'
  symbols.cross = '×'
  symbols.ellipsisLarge = '...'
  symbols.ellipsis = '...'
  symbols.info = 'i'
  symbols.question = '?'
  symbols.questionSmall = '?'
  symbols.pointer = '▸' -- '>'
  symbols.pointerSmall = '»'
  symbols.radioOff = '( )'
  symbols.radioOn = '(*)'
  symbols.warning = '‼'
else
  symbols.ballotCross = '✘'
  symbols.check = '✔'
  symbols.cross = '✖'
  symbols.ellipsisLarge = '⋯'
  symbols.ellipsis = '…'
  symbols.info = 'ℹ'
  symbols.question = '?'
  symbols.questionFull = '？'
  symbols.questionSmall = '﹖'
  symbols.pointer = '▸' -- isLinux ? '▸' : '❯'
  symbols.pointerSmall = '▸' -- isLinux ? '‣' : '›'
  symbols.radioOff = '◯'
  symbols.radioOn = '◉'
  symbols.warning = '⚠'
end

local LogTypes = {
  None = 0,
  Section = 1,
  Info = 2,
  Success = 3,
  Warning = 4,
  Error = 5,
  Point = 6,
  Bullet = 7,
}

local function _print(text)
  if text == nil then text = "" end
  if (opts.gui == nil or opts.gui == false) then
    -- CLI
    io.write(text .. "\n")
  else
    -- GUI
    gui_log_add(text);
  end
end

local function section(...)
  local text = help.parse_str_args("\t", ...)
  if (opts.gui == nil or opts.gui == false) then
    -- CLI
    _print(" ")
    _print(ansicolors('%{bright magenta}' .. symbols.line .. ' ' .. text))
  else
    -- GUI
    gui_log_add(" ");
    gui_log_add(LogTypes.Section, text)
  end
end

local function info(...)
  local text = help.parse_str_args("\t", ...)
  if (opts.gui == nil or opts.gui == false) then
    -- CLI
    _print(ansicolors('%{cyan}' .. symbols.info .. ' ' .. text))
  else
    -- GUI
    gui_log_add(LogTypes.Info, text)
  end
end

local function success(...)
  local text = help.parse_str_args("\t", ...)
  if (opts.gui == nil or opts.gui == false) then
    -- CLI
    _print(ansicolors('%{green}' .. symbols.check .. ' ' .. text))
  else
    -- GUI
    gui_log_add(LogTypes.Success, text)
  end
end

local function warning(...)
  local text = help.parse_str_args("\t", ...)
  if (opts.gui == nil or opts.gui == false) then
    -- CLI
    _print(ansicolors('%{yellow}' .. symbols.warning .. ' ' .. text))
  else
    -- GUI
    gui_log_add(LogTypes.Warning, text)
  end
end

local function error(...)
  local text = help.parse_str_args("\t", ...)
  if (opts.gui == nil or opts.gui == false) then
    -- CLI
    _print(ansicolors('%{red}' .. symbols.cross .. ' ' .. text))
  else
    -- GUI
    gui_log_add(LogTypes.Error, text)
  end
end

local function point(...)
  local text = help.parse_str_args("\t", ...)
  if (opts.gui == nil or opts.gui == false) then
    -- CLI
    _print(ansicolors('%{cyan}' .. symbols.pointer .. ' ' .. text))
  else
    -- GUI
    gui_log_add(LogTypes.Point, text)
  end
end

local function bullet(...)
  local text = help.parse_str_args("\t", ...)
  if (opts.gui == nil or opts.gui == false) then
    -- CLI
    _print(ansicolors('%{cyan}' .. symbols.bullet .. ' ' .. text))
  else
    -- GUI
    gui_log_add(LogTypes.Bullet, text)
  end
end

-- local function color(color, ...)
--   _print(ansicolors('%{' .. color .. '}' .. help.parse_str_args("\t", ...)))
-- end

local function custom(color, symbol, ...)
  if color == nil then color = "white" end
  if symbol == nil then symbol = "" else symbol = symbols[symbol] end
  _print(ansicolors('%{' .. color .. '}' .. symbol .. ' ' .. help.parse_str_args("\t", ...)))
end

-- global variables so other modules can use them

-- call functions desired to run when script is called/imported

-- functions other modules are able to call
log.section = section
log.info = info
log.success = success
log.error = error
log.warning = warning
log.point = point
log.bullet = bullet
-- log.custom = custom
-- log.color = color
log.print = _print

log.symbols = symbols

-- return the module's table
return log
