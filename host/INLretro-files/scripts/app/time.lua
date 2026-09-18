-- create the module's table
local time = {}

-- import required modules
local log = require "scripts.app.log"

-- file constants and global variables
local tstart

-- local functions
local function start()
  tstart = os.clock()
end

--send the number of KBytes flashed so it can report KBps
local function report(size_kb)
  local total_time = os.clock() - tstart
  local speed = string.format("%.2f", (size_kb / total_time))
  total_time = string.format("%.3f", total_time)
  log.info("Total time: " .. total_time .. " seconds, average speed: " .. speed .. " KBps")
end

local function sleep(n) -- seconds
  local t0 = os.clock()
  while os.clock() - t0 <= n do end
end

-- global variables so other modules can use them

-- call functions desired to run when script is called/imported

-- functions other modules are able to call
time.start  = start
time.report = report
time.sleep  = sleep

-- return the module's table
return time
