-- create the module's table
local rainbow       = {}

-- import required modules
local dict          = require "scripts.app.dict"
local genesis       = require "scripts.app.genesis"
local dump          = require "scripts.app.dump"
local flash         = require "scripts.app.flash"
local chips         = require "scripts.app.chips"
local time          = require "scripts.app.time"
local log           = require "scripts.app.log"
local spinner       = require "scripts.app.spinner"
local files         = require "scripts.app.files"
local help          = require "scripts.app.help"

-- file constants and global variables
local mapname       = "RNBW"

local flash_chip

local R_BOOTROM     = 0x01 -- 0xA13001 - Bootrom configuration
local R_RNBW_CONFIG = 0xC1 -- 0xA130C1 - Configuration
local R_RNBW_RX     = 0xC3 -- 0xA130C3 - RX - Reception
local R_RNBW_TX     = 0xC5 -- 0xA130C5 - TX - Transimission
local R_RNBW_RX_RAM = 0xC7 -- 0xA130C7 - RX RAM destination address
local R_RNBW_TX_RAM = 0xC9 -- 0xA130C9 - TX RAM source address
local R_SRAM        = 0xF1

--[[
███╗   ███╗██╗███████╗ ██████╗    ███████╗██╗   ██╗███╗   ██╗ ██████╗███████╗
████╗ ████║██║██╔════╝██╔════╝    ██╔════╝██║   ██║████╗  ██║██╔════╝██╔════╝
██╔████╔██║██║███████╗██║         █████╗  ██║   ██║██╔██╗ ██║██║     ███████╗
██║╚██╔╝██║██║╚════██║██║         ██╔══╝  ██║   ██║██║╚██╗██║██║     ╚════██║
██║ ╚═╝ ██║██║███████║╚██████╗    ██║     ╚██████╔╝██║ ╚████║╚██████╗███████║
╚═╝     ╚═╝╚═╝╚══════╝ ╚═════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚══════╝

--]]

-- local functions

local function test_bootrom()
  local rv

  log.section("Bootrom test")

  log.point("Enable Bootrom")
  genesis.time_wr(R_BOOTROM, 0x03) -- Enable Bootrom

  dict.sega("GEN_SET_ADDR_HI", 0x00)

  rv = dict.sega("GEN_ROM_RD", 0x0000 >> 1)
  log.print(help.hex_0x4(rv))
  rv = dict.sega("GEN_ROM_RD", 0x0002 >> 1)
  log.print(help.hex_0x4(rv))
  rv = dict.sega("GEN_ROM_RD", 0x0004 >> 1)
  log.print(help.hex_0x4(rv))
  rv = dict.sega("GEN_ROM_RD", 0x0006 >> 1)
  log.print(help.hex_0x4(rv))

  log.point("Disable Bootrom")
  genesis.time_wr(R_BOOTROM, 0x00) -- Disable Bootrom

  rv = dict.sega("GEN_ROM_RD", 0x0000 >> 1)
  log.print(help.hex_0x4(rv))
  rv = dict.sega("GEN_ROM_RD", 0x0002 >> 1)
  log.print(help.hex_0x4(rv))
  rv = dict.sega("GEN_ROM_RD", 0x0004 >> 1)
  log.print(help.hex_0x4(rv))
  rv = dict.sega("GEN_ROM_RD", 0x0006 >> 1)
  log.print(help.hex_0x4(rv))
end

local function test_wifi()
  local rv

  log.section("Wi-Fi/ESP test")

  log.point("Enable ESP")
  genesis.time_wr(R_RNBW_CONFIG, 0x01) -- enable ESP

  log.point("Enable FPGA-RAM")
  genesis.time_wr(R_SRAM, 0x81)

  log.point("Acknowledge messages if needed")
  rv = 0
  while rv ~= 0 do
    rv = dict.sega("GEN_TIME_RD", R_RNBW_RX) -- ack message
  end

  log.point("Set TX RAM address")
  genesis.time_wr(R_RNBW_TX_RAM, 0x00) -- set TX RAM address

  log.point("Set RX RAM address")
  genesis.time_wr(R_RNBW_RX_RAM, 0x01) -- set RX RAM address

  log.point("Prepare command")
  dict.sega("GEN_SET_ADDR_HI", 0x20)
  dict.sega("GEN_RAM_WR", 0x1800, 0x01)
  dict.sega("GEN_RAM_WR", 0x1801, 0x00)

  log.point("Send command")
  genesis.time_wr(R_RNBW_TX, 0x01) -- send command

  log.point("Wait for response")
  rv = 0
  while rv < 0x80 do
    rv = dict.sega("GEN_TIME_RD", R_RNBW_RX)
  end

  log.point("Read response")
  rv = dict.sega("GEN_RAM_RD", 0x1900)
  log.bullet(help.hex_0x2(rv))
  rv = dict.sega("GEN_RAM_RD", 0x1901)
  log.bullet(help.hex_0x2(rv))
  rv = dict.sega("GEN_RAM_RD", 0x1902)
  log.bullet(help.hex_0x2(rv))

  log.point("Acknowledge message")
  genesis.time_wr(R_RNBW_RX) -- ack message

  log.point("Disable FPGA-RAM/SRAM")
  genesis.ram_disable()

  log.point("Disable ESP")
  genesis.time_wr(R_RNBW_CONFIG, 0x00) -- disable ESP
end

--[[
██████╗  ██████╗ ███╗   ███╗
██╔══██╗██╔═══██╗████╗ ████║
██████╔╝██║   ██║██╔████╔██║
██╔══██╗██║   ██║██║╚██╔╝██║
██║  ██║╚██████╔╝██║ ╚═╝ ██║
╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝

--]]

-- Test that cartridge is readable by looking for valid entries in internal header.
local function rom_manf_id()
  local manufacturer_id
  local device_id
  local device_test

  -- compatible SST39VF / MX29
  -- compatible S29GL01GS / S29GL512S / S29GL256S / S29GL128S

  -- flash manf ID
  genesis.rom_wr(0x000555 << 1, 0x00AA)
  genesis.rom_wr(0x0002AA << 1, 0x0055)
  genesis.rom_wr(0x000555 << 1, 0x0090)

  manufacturer_id = dict.sega("GEN_ROM_RD", 0x0000 << 1)
  chips.display_manufacturer(manufacturer_id)
  flash_chip = manufacturer_id

  device_id = dict.sega("GEN_ROM_RD", 0x000E << 1)
  device_test = chips.display_device(manufacturer_id, device_id)

  -- exit software
  genesis.rom_wr(0x000000, 0x00F0)

  if device_test == false then
    log.error("Flash chip unknown")
    return false
  else
    log.success("Flash chip deteted successfully")
    return true
  end
end

local function rom_erase_sector(addr, debug)
  local cur_bank = addr >> 17       -- 128KB banks
  local local_addr = addr & 0x1FFFF -- offset inside 128KB bank
  local window_addr = 0x080000 | ((cur_bank & 0x03) << 17)

  -- select desired bank
  genesis.time_wr(0xF3, cur_bank >> 2) -- 0xF3 => 0xA130F3

  -- set address hi bits (A23-A16)
  dict.sega("GEN_SET_ADDR_HI", 0x08 | ((cur_bank & 0x03) << 1)) -- 0x08 controls A19, set to 1 to read from bank 1 (0x80000-0xFFFFF)

  genesis.rom_wr(window_addr | (0x000555 << 1), 0x00AA)
  genesis.rom_wr(window_addr | (0x0002AA << 1), 0x0055)
  genesis.rom_wr(window_addr | (0x000555 << 1), 0x0080)
  genesis.rom_wr(window_addr | (0x000555 << 1), 0x00AA)
  genesis.rom_wr(window_addr | (0x0002AA << 1), 0x0055)
  genesis.rom_wr(window_addr | local_addr, 0x0030)

  if debug then
    log.point("erasing sector @ " .. help.hex_0x6(addr))
  end

  local temp
  local nak = 0
  local check_addr = window_addr | local_addr

  while (genesis.rom_rd(check_addr) ~= 0xFFFF) do
    nak = nak + 1
    if nak > 100000 then
      temp = genesis.rom_rd(check_addr)
      log.error("sector erase failed", help.hex_0x6(addr), "read", help.hex_0x4(temp))
      return false
    end
  end

  for offset = 0, 30, 2 do
    check_addr = window_addr | (local_addr + offset)
    temp = genesis.rom_rd(check_addr)
    if temp ~= 0xFFFF then
      log.error("sector erase verify failed", help.hex_0x6(addr + offset), "read", help.hex_0x4(temp))
      return false
    end
  end

  return true
end

-- write a single byte to ROM flash
local function rom_flash_byte(addr, value, debug)
  if (addr < 0x000000 or addr > 0x3FFFFF) then
    log.error("ERROR! flash write to ROM", string.format("$%X", addr), "must be $000000-$3FFFFF")
    return
  end

  local addr_hi = (addr >> 16) & 0xff
  local addr_lo = addr & 0xffff

  -- genesis.time_wr(0xF3, addr_hi >> 2)
  -- dict.sega("GEN_SET_ADDR_HI", 0x08 | (addr_hi & 0x03))

  if debug then
    log.info("write a byte", help.hex_0x6(addr), help.hex_0x4(value))
  end

  genesis.rom_wr(0x000555 << 1, 0x00AA)
  genesis.rom_wr(0x0002AA << 1, 0x0055)
  genesis.rom_wr(0x000555 << 1, 0x00A0)
  genesis.rom_wr(addr, value)

  local rv = dict.sega("GEN_ROM_RD", addr_lo)

  local i = 0

  while (rv ~= value) do
    rv = dict.sega("GEN_ROM_RD", addr_lo)
    -- if debug then print("post write read:", help.hex(rv)) end
    i = i + 1
    if i > 30 then
      log.info("failed write, tried:", help.hex_0x4(value), "read back value:", help.hex_0x4(rv))
      return
    end
  end

  if debug then
    log.info("Done writing byte,", i .. " naks")
  end

  --TODO handle timeout for problems

  --TODO return pass/fail/info
  return rv
end

-- /ROMSEL (#C_CE) is always low for this dump
local function rom_dump(file, rom_size_kb, debug)
  -- we're dumping from 0x040000 which is second 512 kB / 256 kW bank ($080000-$0FFFFF)

  local kb_per_bank = 2 * 64 -- 2 bytes per address, 64K addresses
  local addr_base = 0x0000   -- control signals are manually controlled
  local num_banks = math.floor(rom_size_kb / kb_per_bank)
  local cur_bank = 0

  log.info("ROM size", rom_size_kb .. "KB")

  -- disable SRAM
  genesis.ram_disable()

  while cur_bank < num_banks do
    -- A "large" Genesis ROM is 24 banks, many are 8 and 16 - status every 4 is reasonable.
    -- The largest published Genesis game is Super Street Fighter 2, which is 40 banks!
    -- TODO: Accessing banks in games that are >4MB require using a mapper.
    -- See: https://plutiedev.com/beyond-4mb

    if debug then
      log.point("dumping bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- -- select desired bank
    genesis.time_wr(0xF3, cur_bank >> 2) -- 0xF3 => 0xA130F3

    -- -- set address hi bits (A23-A16)
    dict.sega("GEN_SET_ADDR_HI", 0x08 | ((cur_bank & 0x03) << 1)) -- 0x08 controls A19, set to 1 to read from bank 1 (0x80000-0xFFFFF)

    dump.dumptofile(file, kb_per_bank / 2, addr_base, "GENESIS_ROM_PAGE0", false)
    dump.dumptofile(file, kb_per_bank / 2, addr_base, "GENESIS_ROM_PAGE1", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

local function rom_write(file, rom_size_kb, debug)
  local kb_per_bank = 2 * 64 -- 2 bytes per address, 64K addresses
  local num_banks = math.floor(rom_size_kb / kb_per_bank)
  local cur_bank = 0

  log.section("Programming ROM")
  log.info("ROM size", rom_size_kb .. "KB")

  -- disable SRAM
  genesis.ram_disable()

  while cur_bank < num_banks do
    if debug then
      log.point("writing bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- select desired bank
    genesis.time_wr(0xF3, cur_bank >> 2) -- 0xF3 => 0xA130F3

    -- set address hi bits (A23-A16)
    dict.sega("GEN_SET_ADDR_HI", 0x08 | ((cur_bank & 0x03) << 1)) -- 0x08 controls A19, set to 1 to read from bank 1 (0x80000-0xFFFFF)

    flash.write_file(file, kb_per_bank, mapname, "GENESISROM", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
  log.success("Done programming ROM")
end

--[[
██████╗  █████╗ ███╗   ███╗
██╔══██╗██╔══██╗████╗ ████║
██████╔╝███████║██╔████╔██║
██╔══██╗██╔══██║██║╚██╔╝██║
██║  ██║██║  ██║██║ ╚═╝ ██║
╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝

--]]

-- dump the RAM, assumes the RAM was enabled as desired prior to calling
local function ram_dump(file, addr_hi, ram_size_kb, debug)
  local kb_per_bank =
      ram_size_kb        -- TODO: FIXME? => -- 128KByte addressable per bank, but only use lower byte of each 16bit word
  local num_banks = math.floor(ram_size_kb / kb_per_bank)
  local addr_base = 0x00 -- A15-8 address of ram start
  local cur_bank = 0

  log.info("SRAM size", ram_size_kb .. "KB")

  -- select desired bank
  -- A23-A17
  dict.sega("GEN_SET_ADDR_HI", addr_hi)

  while cur_bank < num_banks do
    if debug then
      log.point("dumping RAM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- currently don't have means of dumping RAM with A16 high
    dump.dumptofile(file, ram_size_kb, addr_base, "GENESIS_RAM_PAGE", false) -- A16 low

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

-- write to the PRG-RAM, assumes the PRG-RAM was enabled/disabled as desired prior to calling
local function ram_write(file, start_bank, ram_size_kb, debug)
  local kb_per_bank = 32 -- 128KByte addressable per bank, but only use lower byte of each 16bit word
  local num_banks = math.floor(ram_size_kb / kb_per_bank)
  local cur_bank = 0

  log.section("Programming SRAM")
  log.info("SRAM size", ram_size_kb .. "KB")

  -- enable RAM
  genesis.ram_enable()

  while cur_bank < num_banks do
    if debug then
      log.point("writing bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Writing", cur_bank, "/", num_banks - 1)
    end

    dict.sega("GEN_SET_ADDR_HI", start_bank + cur_bank)

    flash.write_file(file, ram_size_kb, mapname, "GENESISRAM", false)

    cur_bank = cur_bank + 1
  end

  -- disable SRAM
  genesis.ram_disable()

  spinner.clear()
  log.success("Done programming SRAM")
end

-- try to detect ram
local function ram_test(debug)
  local test = true
  local saved_value
  local write_value
  local read_value

  local addr_hi = 0x20

  log.section("Detecting SRAM")

  -- enable RAM
  genesis.ram_enable()

  -- save potential battery backed data first
  -- saved_value = genesis.ram_rd(0x200000)
  dict.sega("GEN_SET_ADDR_HI", addr_hi)
  saved_value = dict.sega("GEN_RAM_RD", 0x0000)
  write_value = saved_value ~ 0xff

  -- try to write and read back
  -- genesis.ram_wr(0x200000, write_value)
  -- read_value = dict.sega("GEN_RAM_RD", 0x0000)
  -- dict.sega("GEN_SET_ADDR", 0x0000, addr_hi)
  dict.sega("GEN_RAM_WR", 0x0000, write_value)
  -- dict.sega("GEN_SET_ADDR", 0x0000, addr_hi)
  read_value = dict.sega("GEN_RAM_RD", 0x0000)
  if read_value ~= write_value then
    test = false
  end

  -- put back original value
  -- genesis.ram_wr(0x200000, saved_value)
  -- read_value = genesis.ram_rd(0x200000)
  -- dict.sega("GEN_SET_ADDR", 0x0000, addr_hi)
  dict.sega("GEN_RAM_WR", 0x0000, saved_value)
  -- dict.sega("GEN_SET_ADDR", 0x0000, addr_hi)
  read_value = dict.sega("GEN_RAM_RD", 0x0000)
  if read_value ~= (saved_value) then
    test = false
  end

  -- disable RAM
  genesis.ram_disable()

  if test then
    log.success("RAM detected")
  else
    log.error("RAM not detected")
  end

  return test
end

local function ram_exercise(ram_size, retroprog_id, debug)
  --[[
  SRAM covers the $200001-$20FFFF address range, and only every other byte is used (i.e. $200001, $200003, $200005, etc.).
  This gives you a total of 32KB to work with.
  If you need to save numbers larger than fit in a byte, split it into its separate bytes.
--]]

  local addr_hi = 0x20

  dict.stuff("RESET_LFSR") -- sets it to 1

  -- enable SRAM
  genesis.ram_enable()

  -- set SRAM address high bits
  dict.sega("GEN_SET_ADDR_HI", addr_hi)

  log.section("Exercising SRAM")
  log.info("SRAM size", ram_size .. "KB")

  -- write random data to all banks
  log.point("Writing random data to SRAM")
  dict.sega("GEN_PAGE_RAM_WR_LFSR", 0x0000, ram_size)

  --dump sram into file
  local filename = opts.lua_path .. "./ignore/gen_sram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))
  log.point("Dumping SRAM")
  ram_dump(file, addr_hi, ram_size, debug)

  -- disable SRAM
  genesis.ram_disable()

  -- close the file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "./ignore/lfsr_32KB.bin"

  -- compare the flash file vs post dump file
  if files.compare(filename, goodfile, true, debug) then
    log.success("SRAM test passed")
    return true
  else
    log.error("SRAM test failed")
    return false
  end
end

--[[
███████╗██████╗  ██████╗  █████╗       ██████╗  █████╗ ███╗   ███╗
██╔════╝██╔══██╗██╔════╝ ██╔══██╗      ██╔══██╗██╔══██╗████╗ ████║
█████╗  ██████╔╝██║  ███╗███████║█████╗██████╔╝███████║██╔████╔██║
██╔══╝  ██╔═══╝ ██║   ██║██╔══██║╚════╝██╔══██╗██╔══██║██║╚██╔╝██║
██║     ██║     ╚██████╔╝██║  ██║      ██║  ██║██║  ██║██║ ╚═╝ ██║
╚═╝     ╚═╝      ╚═════╝ ╚═╝  ╚═╝      ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝

--]]


-- try to detect ram
local function fpga_ram_test(debug)
  local test = true
  local read_value
  local saved_value

  local addr_hi = 0x20

  log.section("Detecting FPGA-RAM")

  -- enable FPGA-RAM
  genesis.time_wr(R_SRAM, 0x81)

  -- save potential battery backed data first
  dict.sega("GEN_SET_ADDR_HI", addr_hi)
  saved_value = dict.sega("GEN_RAM_RD", 0x0000)

  -- try to write and read back
  dict.sega("GEN_RAM_WR", 0x0000, saved_value ~ 0xff)
  read_value = dict.sega("GEN_RAM_RD", 0x0000)
  if read_value ~= (saved_value ~ 0xff) then
    test = false
  end

  -- put back original value
  dict.sega("GEN_RAM_WR", 0x0000, saved_value)
  read_value = dict.sega("GEN_RAM_RD", 0x0000)
  if read_value ~= (saved_value) then
    test = false
  end

  -- disable RAM
  genesis.ram_disable()

  if test then
    log.success("FPGA-RAM detected")
  else
    log.error("FPGA-RAM not detected")
  end

  return test
end

local function fpga_ram_exercise(retroprog_id, debug)
  --[[
  SRAM covers the $200001-$20FFFF address range, and only every other byte is used (i.e. $200001, $200003, $200005, etc.).
  This gives you a total of 32KB to work with.
  If you need to save numbers larger than fit in a byte, split it into its separate bytes.
--]]

  local ram_size = 8
  local addr_hi = 0x20

  dict.stuff("RESET_LFSR") -- sets it to 1

  -- enable FPGA-RAM
  genesis.time_wr(R_SRAM, 0x81)

  log.section("Exercising FPGA-RAM")
  log.info("FPGA-RAM size", ram_size .. "KB")

  -- write random data to all banks
  log.point("Writing random data to FPGA-RAM")
  dict.sega("GEN_PAGE_RAM_WR_LFSR", 0x0000, (ram_size * 0x400) >> 8)

  --dump sram into file
  local filename = opts.lua_path .. "./ignore/gen_fpga_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))
  log.point("Dumping FPGA-RAM")
  ram_dump(file, addr_hi, ram_size, debug)

  -- disable SRAM
  genesis.ram_disable()

  -- close the file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "./ignore/lfsr_32KB.bin"

  -- compare the flash file vs post dump file
  if files.compare(filename, goodfile, false, debug) then
    log.success("FPGA-RAM test passed")
    return true
  else
    log.error("FPGA-RAM test failed")
    return false
  end
end

--[[
██████╗ ██████╗  ██████╗  ██████╗███████╗███████╗███████╗
██╔══██╗██╔══██╗██╔═══██╗██╔════╝██╔════╝██╔════╝██╔════╝
██████╔╝██████╔╝██║   ██║██║     █████╗  ███████╗███████╗
██╔═══╝ ██╔══██╗██║   ██║██║     ██╔══╝  ╚════██║╚════██║
██║     ██║  ██║╚██████╔╝╚██████╗███████╗███████║███████║
╚═╝     ╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚══════╝╚══════╝╚══════╝

--]]

-- Cart should be in reset state upon calling this function
-- this function processes all user requests for this specific board/mapper
local function process(process_opts, console_opts)
  -- some local variables
  local rv             = nil
  local file

  -- process options
  local DEBUG          = process_opts.debug
  local retroprog_id   = process_opts.retroprog_id
  local do_test        = process_opts.do_test
  local do_erase       = process_opts.do_erase
  local do_rom_write   = process_opts.do_rom_write
  local do_verify      = process_opts.do_verify
  local do_rom_dump    = process_opts.do_rom_dump
  local do_ram_dump    = process_opts.do_ram_dump
  local do_ram_write   = process_opts.do_ram_write
  local rom_write_file = process_opts.rom_write_file
  local verify_file    = process_opts.verify_file
  local rom_dump_file  = process_opts.rom_dump_file
  local ram_dump_file  = process_opts.ram_dump_file
  local ram_write_file = process_opts.ram_write_file
  local options        = process_opts.additional_opts

  -- console options
  local rom_size       = console_opts.rom_size_kb
  local ram_size       = console_opts.wram_size_kb

  -- Initialize device i/o
  dict.io("IO_RESET")
  dict.io("SEGA_INIT")

  -- Disable Bootrom
  genesis.time_wr(R_BOOTROM, 0x00)

  --[[
  888888 888888 .dP"Y8 888888
    88   88__   `Ybo."   88
    88   88""   o.`Y8b   88
    88   888888 8bodP'   88
  --]]

  -- test cart
  if do_test then
    log.section("Testing Rainbow")

    -- attempt to read ROM flash ID
    if options.force_flash_test or (do_rom_write and rom_size ~= 0) then
      rv = rom_manf_id()
      if not rv then
        if do_rom_write then
          log.error("Couldn't identify flash chip")
          return false
        else
          log.warning("Couldn't identify flash chip")
        end
      end
    end

    -- TEST
    -- rv = dict.sega("GEN_TIME_RD", 0xAA)
    -- log.print(help.hex_0x2(rv))
    -- genesis.dbg_rom_rd(0xA130AA)
    -- test_wifi()
    -- test_bootrom()

    -- FPGA_RAM tests
    -- rv = fpga_ram_test(DEBUG)
    -- if rv == true then
    --   rv = fpga_ram_exercise(retroprog_id, DEBUG)
    --   -- exit script if test fails
    --   if not rv then return end
    -- else
    --   log.error("Couldn't detect FPGA-RAM")
    -- end

    -- RAM tests
    rv = ram_test(DEBUG)
    if rv == true then
      if options.force_wram_test then
        log.print()
        log.warning("Flag 'force_wram_test' enabled")
      end
      if ram_size == 0 then
        ram_size = 32
      end
      local is_header_valid = genesis.file_header.is_valid or genesis.cart_header.is_valid
      local has_battery = genesis.file_header:has_battery() or genesis.cart_header:has_battery()
      if options.force_wram_test or is_header_valid then
        if not options.force_wram_test and has_battery then
          log.print()
          log.warning("Can't exercise RAM because ROM has battery backed data")
        else
          if ram_size ~= 0 then
            rv = ram_exercise(ram_size, retroprog_id, DEBUG)
            -- exit script if test fails
            if not rv then return end
          end
        end
      else
        log.warning("Can't exercise RAM because data could be battery backed")
      end
    end
  end

  -----------------------------------------------------

  -- genesis.time_wr(0xF3, 0x01)
  -- -- dict.sega("GEN_SET_ADDR_HI", 0x0a)

  -- genesis.dbg_rom_rd(0x080000 + 0x0000)
  -- genesis.dbg_rom_rd(0x080000 + 0x05BC)
  -- genesis.dbg_rom_rd(0x080000 + 0x05BE)
  -- genesis.dbg_rom_rd(0x080000 + 0x05C0)
  -- dict.io("IO_RESET")
  -- do return end

  -----------------------------------------------------

  local i = 0
  -- local step = 2

  -- rom_flash_byte(i, 0xDEAD)
  -- i = i + step
  -- rom_flash_byte(i, 0xAA55)
  -- i = i + step
  -- rom_flash_byte(i, 0x55AA)
  -- i = i + step
  -- rom_flash_byte(i, 0xFEED)

  -- i = 0
  -- log.bullet(help.hex_0x4((dict.sega("GEN_ROM_RD", i))))
  -- i = i + step
  -- log.bullet(help.hex_0x4((dict.sega("GEN_ROM_RD", i))))
  -- i = i + step
  -- log.bullet(help.hex_0x4((dict.sega("GEN_ROM_RD", i))))
  -- i = i + step
  -- log.bullet(help.hex_0x4((dict.sega("GEN_ROM_RD", i))))

  -- dict.io("IO_RESET")
  -- do return end

  -----------------------------------------------------

  -- local count = 128
  -- local base_addr = 0x000100

  -- rom_erase_sector(base_addr, DEBUG)

  -- genesis.dbg_rom_wr(0x000000, 0x00F0);

  -- genesis.dbg_rom_wr(0x000555, 0x00AA);
  -- genesis.dbg_rom_wr(0x0002AA, 0x0055);
  -- genesis.dbg_rom_wr(base_addr, 0x0025);    -- the bank set before calling sets the sector
  -- genesis.dbg_rom_wr(base_addr, count - 1); -- number of words to write minus one

  -- for w = 0, count - 1 do
  --   local byte_addr = base_addr + w
  --   local value = (((w ~ 0xff) & 0xff) << 8) | (w & 0xff)
  --   genesis.dbg_rom_wr(byte_addr, value)
  -- end

  -- -- write program buffer to flash (confirm)
  -- genesis.dbg_rom_wr(base_addr, 0x29);

  -- rv = dict.sega("GEN_ROM_RD", base_addr)

  -- while (rv ~= dict.sega("GEN_ROM_RD", base_addr)) do
  --   rv = dict.sega("GEN_ROM_RD", base_addr)
  -- end

  -- for w = 0, count - 1 do
  --   local byte_addr = base_addr + w
  --   genesis.dbg_rom_rd(byte_addr);
  -- end

  -- dict.io("IO_RESET")
  -- do return end

  -----------------------------------------------------

  --  rom_erase_sector(0x000000, DEBUG)

  --  rom_flash_byte(0x000000, 0xDEAD)

  -- Écris un mot distinct en banque 0.
  -- Sélectionne banque 32 :genesis.time_wr(0xF3, 32 >> 2) -- 0x08
  -- dict.sega("GEN_SET_ADDR_HI", 0x08 | (32 & 0x03))

  -- Lis la même adresse.
  -- Compare avec banque 0.

  --[[
  88""Yb    db    8b    d8     8888b.  88   88 8b    d8 88""Yb
  88__dP   dPYb   88b  d88      8I  Yb 88   88 88b  d88 88__dP
  88"Yb   dP__Yb  88YbdP88      8I  dY Y8   8P 88YbdP88 88"""
  88  Yb dP""""Yb 88 YY 88     8888Y"  `YbodP' 88 YY 88 88
  --]]

  -- dump cart RAM to file
  if do_ram_dump then
    -- enable RAM
    genesis.ram_enable()

    -- open file
    file = assert(io.open(ram_dump_file.filename, "wb"))

    -- dump cart to file
    local addr_hi = 0x20
    log.section("Dumping SRAM")
    time.start()
    ram_dump(file, addr_hi, ram_size, DEBUG)
    time.report(ram_size)
    log.success("SRAM dumping done")

    -- close file
    assert(file:close())

    -- disable SRAM
    genesis.ram_disable()
  end

  --[[
  88""Yb    db    8b    d8     Yb        dP 88""Yb 88 888888 888888
  88__dP   dPYb   88b  d88      Yb  db  dP  88__dP 88   88   88__
  88"Yb   dP__Yb  88YbdP88       YbdPYbdP   88"Yb  88   88   88""
  88  Yb dP""""Yb 88 YY 88        YP  YP    88  Yb 88   88   888888
  --]]

  -- write file to the cart RAM
  if do_ram_write then
    -- open file
    file = assert(io.open(ram_write_file.filename, "rb"))
    -- flash cart SRAM
    local addr_hi = 0x20
    time.start()
    ram_write(file, addr_hi, ram_size, DEBUG)
    time.report(rom_size)

    -- close file
    assert(file:close())
  end

  --[[
  88""Yb  dP"Yb  8b    d8     8888b.  88   88 8b    d8 88""Yb
  88__dP dP   Yb 88b  d88      8I  Yb 88   88 88b  d88 88__dP
  88"Yb  Yb   dP 88YbdP88      8I  dY Y8   8P 88YbdP88 88"""
  88  Yb  YbodP  88 YY 88     8888Y"  `YbodP' 88 YY 88 88
  --]]

  -- dump cart ROM to file
  if do_rom_dump then
    if rom_size ~= 0 then
      -- open file
      file = assert(io.open(rom_dump_file.filename, "wb"))

      genesis.time_wr(R_BOOTROM, 0x03)

      -- dump cart to file
      log.section("Dumping ROM")
      time.start()
      rom_dump(file, rom_size, DEBUG)
      time.report(rom_size)
      log.success("ROM dumping done")

      -- close file
      assert(file:close())

      -- parse ROM dump file header
      log.point("Parsing dumped file header")
      file = assert(io.open(rom_dump_file.filename, "rb"))
      if not genesis.parse_header_file(file) then
        log.warning("Failed to parse ROM dump file header")
      else
        log.success("ROM dump file header parsed successfully")
      end
      assert(file:close())
    end
  end

  --[[
  88""Yb  dP"Yb  8b    d8     888888 88""Yb    db    .dP"Y8 888888
  88__dP dP   Yb 88b  d88     88__   88__dP   dPYb   `Ybo." 88__
  88"Yb  Yb   dP 88YbdP88     88""   88"Yb   dP__Yb  o.`Y8b 88""
  88  Yb  YbodP  88 YY 88     888888 88  Yb dP""""Yb 8bodP' 888888
  --]]

  -- erase the cart
  if do_erase then
    -- local i = 0
    local temp
    local size_to_erase = rom_size

    -- erase ROM only if needed
    if rom_size ~= 0 then
      log.section("Erasing ROM")

      time.start()
      if (flash_chip == 0x01) then -- Cypress / Spansion
        -- [[
        log.info("erasing only needed sectors because erasing full chip takes 4 min...")

        local sectors = math.floor(rom_size / 128)
        size_to_erase = sectors * 128
        local addr
        -- TODO: save the flash chip size so we can decide if it's best to erase sctors or the whole chip

        for i = 0, sectors - 1, 1 do
          addr = (i * 128 * 1024)
          if (DEBUG) then
            log.bullet("erasing sector", i, "of", sectors - 1)
          else
            spinner.update("Erasing sector ", i, "/", sectors - 1) --, string.format("(%06X)", addr))
          end
          temp = rom_erase_sector(addr, DEBUG)
          if temp == false then
            spinner.clear()
            return false
          end
        end
        spinner.clear()
        log.success("Done erasing ROM (" .. sectors .. " sectors)")
      else
        --]]
        log.warning("Erasing full flash chip can take up to 4 minutes...")
        -- disable SRAM
        genesis.ram_disable()

        genesis.rom_wr(0x000555 << 1, 0x00AA)
        genesis.rom_wr(0x0002AA << 1, 0x0055)
        genesis.rom_wr(0x000555 << 1, 0x0080)
        genesis.rom_wr(0x000555 << 1, 0x00AA)
        genesis.rom_wr(0x0002AA << 1, 0x0055)
        genesis.rom_wr(0x000555 << 1, 0x0010)

        local nak = 1
        temp = dict.sega("GEN_ROM_RD", 0x0000)
        while (temp ~= dict.sega("GEN_ROM_RD", 0x0000)) do
          temp = dict.sega("GEN_ROM_RD", 0x0000)
          nak = nak + 1
        end
        temp = dict.sega("GEN_ROM_RD", 0x0000)
        log.success("Done erasing ROM", nak .. " naks")
      end

      time.report(size_to_erase)
    end
  end

  --[[
  88""Yb  dP"Yb  8b    d8     Yb        dP 88""Yb 88 888888 888888
  88__dP dP   Yb 88b  d88      Yb  db  dP  88__dP 88   88   88__
  88"Yb  Yb   dP 88YbdP88       YbdPYbdP   88"Yb  88   88   88""
  88  Yb  YbodP  88 YY 88        YP  YP    88  Yb 88   88   888888
  --]]

  -- program file to the cart
  if do_rom_write then
    if rom_size ~= 0 then
      --open file
      file = assert(io.open(rom_write_file.filename, "rb"))
      --determine if auto-doubling, deinterleaving, etc,
      --needs done to make board compatible with rom

      --flash cart
      time.start()
      rom_write(file, rom_size, DEBUG)
      time.report(rom_size)

      -- close file
      assert(file:close())
    end
  end

  --[[
  Yb    dP 888888 88""Yb 88 888888 Yb  dP
   Yb  dP  88__   88__dP 88 88__    YbdP
    YbdP   88""   88"Yb  88 88""     8P
     YP    888888 88  Yb 88 88      dP
  --]]

  -- verify flashed file on the cart
  if do_verify then
    if rom_size ~= 0 then
      -- open file
      file = assert(io.open(verify_file.filename, "wb"))

      -- dump cart to file
      log.section("Dumping ROM")
      time.start()
      rom_dump(file, rom_size, DEBUG)
      time.report(rom_size)

      -- close file
      assert(file:close())

      -- parse ROM dump file header
      log.point("Parsing dumped file header")
      file = assert(io.open(verify_file.filename, "rb"))
      if not genesis.parse_header_file(file) then
        log.warning("Failed to parse ROM dump file header")
      else
        log.success("ROM dump file header parsed successfully")
      end
      assert(file:close())

      -- compare the flash file vs post dump file
      log.section("Verifying data")
      if files.compare(verify_file.filename, rom_write_file.filename, true, true) then
        log.success("Flash successfully verified")
      else
        log.error("Flash verification did not match")
      end
    end
  end

  -- for a = 0x2060, 0x2080, 2 do
  --   log.bullet(help.hex_0x6(a), help.hex_0x4(dict.sega("GEN_ROM_RD", a)))
  -- end

  dict.io("IO_RESET")
end

-- global variables so other modules can use them

-- call functions desired to run when script is called/imported

-- functions other modules are able to call
rainbow.process = process

-- return the module's table
return rainbow
