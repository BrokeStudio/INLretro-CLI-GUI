-- create the module's table
local fme7    = {}

-- import required modules
local dict    = require "scripts.app.dict"
local nes     = require "scripts.app.nes"
local dump    = require "scripts.app.dump"
local flash   = require "scripts.app.flash"
local chips   = require "scripts.app.chips"
local time    = require "scripts.app.time"
local log     = require "scripts.app.log"
local spinner = require "scripts.app.spinner"
local files   = require "scripts.app.files"
local help    = require "scripts.app.help"

-- file constants and global variables
local mapname = "FME7"

-- local functions

--[[
███╗   ███╗██╗███████╗ ██████╗    ███████╗██╗   ██╗███╗   ██╗ ██████╗███████╗
████╗ ████║██║██╔════╝██╔════╝    ██╔════╝██║   ██║████╗  ██║██╔════╝██╔════╝
██╔████╔██║██║███████╗██║         █████╗  ██║   ██║██╔██╗ ██║██║     ███████╗
██║╚██╔╝██║██║╚════██║██║         ██╔══╝  ██║   ██║██║╚██╗██║██║     ╚════██║
██║ ╚═╝ ██║██║███████║╚██████╗    ██║     ╚██████╔╝██║ ╚████║╚██████╗███████║
╚═╝     ╚═╝╚═╝╚══════╝ ╚═════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚══════╝

  --]]

local function create_header(file, prg_kb, chr_kb)
  -- write_header(file, prg_kb, chr_kb, mapper, mirroring)
  nes.write_header(file, prg_kb, chr_kb, op_buffer[mapname], 0)
end

-- disables PRG-RAM, selects Vertical mirroring
-- sets up CHR-ROM flash PT0 for DATA, Commands: $5555->$1555  $2AAA->$1AAA
-- sets up PRG-ROM flash DATA: $8000-9FFF, Commands: $5555->D555  $2AAA->$AAAA
-- leaves $8000 control reg selected to IRQ value selected so $A000 writes don't affect banking
local function init_mapper()
  -- for save data safety start by disable PRG-RAM, and map PRG-ROM to $6000
  dict.nes("NES_CPU_WR", 0x8000, 0x08)
  dict.nes("NES_CPU_WR", 0xA000, 0x00) -- RAM disabled, ROM first bank mapped to $6000

  -- set mirroring
  dict.nes("NES_CPU_WR", 0x8000, 0x0C)
  dict.nes("NES_CPU_WR", 0xA000, 0x00) --00-vert 01-horz 10-NT0 11-NT1

  -- Bank $0 - PPU $0000-$03FF
  -- Bank $1 - PPU $0400-$07FF
  -- Bank $2 - PPU $0800-$0BFF
  -- Bank $3 - PPU $0C00-$0FFF
  -- Bank $4 - PPU $1000-$13FF
  -- Bank $5 - PPU $1400-$17FF
  -- Bank $6 - PPU $1800-$1BFF
  -- Bank $7 - PPU $1C00-$1FFF

  -- For CHR-ROM flash writes, use lower 4KB (PT0) for writing data & upper 4KB (PT1) for commands
  dict.nes("NES_CPU_WR", 0x8000, 0x00)
  dict.nes("NES_CPU_WR", 0xA000, 0x00) --1KB @ PPU $0000

  dict.nes("NES_CPU_WR", 0x8000, 0x01)
  dict.nes("NES_CPU_WR", 0xA000, 0x01) --1KB @ PPU $0400

  dict.nes("NES_CPU_WR", 0x8000, 0x02)
  dict.nes("NES_CPU_WR", 0xA000, 0x02) --1KB @ PPU $0800

  dict.nes("NES_CPU_WR", 0x8000, 0x03)
  dict.nes("NES_CPU_WR", 0xA000, 0x03) --1KB @ PPU $0C00

  -- use lower half of PT1 for $5555 commands
  dict.nes("NES_CPU_WR", 0x8000, 0x04)
  dict.nes("NES_CPU_WR", 0xA000, 0x15) --1KB @ PPU $1000

  dict.nes("NES_CPU_WR", 0x8000, 0x05)
  dict.nes("NES_CPU_WR", 0xA000, 0x15) --1KB @ PPU $1400

  -- use upper half of PT1 for $2AAA commands
  dict.nes("NES_CPU_WR", 0x8000, 0x06)
  dict.nes("NES_CPU_WR", 0xA000, 0x0A) --1KB @ PPU $1800

  dict.nes("NES_CPU_WR", 0x8000, 0x07)
  dict.nes("NES_CPU_WR", 0xA000, 0x0A) --1KB @ PPU $1C00

  -- For PRG-ROM flash writes:
  -- mode 0: $C000-FFFF fixed to last 16KByte
  --         reg6 controls $8000-9FFF ($C000-DFFF in mode 1)
  --         reg7 controls $A000-BFFF (regardless of mode)
  -- Don't want to write data to $8000-9FFF because those are the bank regs
  -- writing data to $A000-BFFF is okay as that will only affect mirroring and PRG-RAM ctl

  -- $5555 commands can be written to $D555 (A14 set, A13 clear)
  -- $2AAA commands must be written through reg6/7 ($8000-BFFF) to clear A14 & set A13
  --   reg7 ($A000-BFFF) is ideal because it won't affect banking, just mirror/PRG-RAM
  --   actually $2AAA is even, so it'll only affect mirroring which is ideal
  -- DATA writes can occur at $8000-9FFF, but care must be taken to maintain banking.
  --   Setting $8000 to a CHR bank prevents DATA writes from changing PRG banks
  --   The DATA write will change the bank select if it's written to an even address though
  --   To cover this, simply select the CHR bank again with $8000 reg after the data write
  --   Those DATA writes can also corrupt the PRG/CHR modes, so just always follow
  --   DATA writes by writing 0x00 to $8000

  -- $5555 commands written to $D555
  -- $2AAA commands written to $AAAA
  dict.nes("NES_CPU_WR", 0x8000, 0x0A)
  dict.nes("NES_CPU_WR", 0xA000, 0x01) --8KB @ CPU $A000
  dict.nes("NES_CPU_WR", 0x8000, 0x0B)
  dict.nes("NES_CPU_WR", 0xA000, 0x02) --8KB @ CPU $C000

  -- DATA writes written to $8000-9FFF
  dict.nes("NES_CPU_WR", 0x8000, 0x09)
  dict.nes("NES_CPU_WR", 0xA000, 0x00) --8KB @ CPU $8000

  -- dict.nes("NES_CPU_WR", 0x8000, 0x08)
  -- dict.nes("NES_CPU_WR", 0xA000, 0x00)  --8KB @ CPU $6000

  -- set $8000 bank select register to IRQ ctl reg so $A000 writes don't change banking
  dict.nes("NES_CPU_WR", 0x8000, 0x0E)
end

-- test the mapper's mirroring modes to verify working properly
-- can be used to help identify board: returns true if pass, false if failed
local function mirror_test(debug)
  log.section("Testing mirroring settings")

  -- put mapper in known state
  init_mapper()

  -- Vertical
  dict.nes("NES_CPU_WR", 0x8000, 0x0C)
  dict.nes("NES_CPU_WR", 0xA000, 0x00) --00-vert 01-horz 10-NT0 11-NT1
  if nes.detect_mapper_mirroring(debug) ~= "VERT" then
    log.error("Vertical mirroring test failed")
    return false
  else
    log.success("Vertical mirroring test passed")
  end

  -- Horizontal
  dict.nes("NES_CPU_WR", 0x8000, 0x0C)
  dict.nes("NES_CPU_WR", 0xA000, 0x01) --00-vert 01-horz 10-NT0 11-NT1
  if nes.detect_mapper_mirroring(debug) ~= "HORZ" then
    log.error("Horizontal mirroring test failed")
    return false
  else
    log.success("Horizontal mirroring test passed")
  end

  -- 1 screen A
  dict.nes("NES_CPU_WR", 0x8000, 0x0C)
  dict.nes("NES_CPU_WR", 0xA000, 0x02) --00-vert 01-horz 10-NT0 11-NT1
  if nes.detect_mapper_mirroring(debug) ~= "1SCRNA" then
    log.error("One screen mirroring test failed (1 screen A)")
    return false
  else
    log.success("One screen mirroring test passed (1 screen A)")
  end

  -- 1 screen B
  dict.nes("NES_CPU_WR", 0x8000, 0x0C)
  dict.nes("NES_CPU_WR", 0xA000, 0x03) --00-vert 01-horz 10-NT0 11-NT1
  if nes.detect_mapper_mirroring(debug) ~= "1SCRNB" then
    log.error("One screen mirroring test failed (1 screen B)")
    return false
  else
    log.success("One screen mirroring test passed (1 screen B)")
  end

  -- passed all tests
  return true
end

--[[
██████╗ ██████╗  ██████╗       ██████╗  ██████╗ ███╗   ███╗
██╔══██╗██╔══██╗██╔════╝       ██╔══██╗██╔═══██╗████╗ ████║
██████╔╝██████╔╝██║  ███╗█████╗██████╔╝██║   ██║██╔████╔██║
██╔═══╝ ██╔══██╗██║   ██║╚════╝██╔══██╗██║   ██║██║╚██╔╝██║
██║     ██║  ██║╚██████╔╝      ██║  ██║╚██████╔╝██║ ╚═╝ ██║
╚═╝     ╚═╝  ╚═╝ ╚═════╝       ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝

  --]]

-- read PRG-ROM flash ID
local function prg_rom_manf_id()
  local manufacturer_id
  local device_id
  local device_test

  init_mapper()

  log.section("Reading PRG-ROM manufacturer/device ID")

  dict.nes("NES_CPU_WR", 0xD555, 0xAA)
  dict.nes("NES_CPU_WR", 0xAAAA, 0x55)
  dict.nes("NES_CPU_WR", 0xD555, 0x90)

  manufacturer_id = dict.nes("NES_CPU_RD", 0x8000)
  chips.display_manufacturer(manufacturer_id)

  device_id = dict.nes("NES_CPU_RD", 0x8001)
  device_test = chips.display_device(manufacturer_id, device_id)

  -- exit software
  dict.nes("NES_CPU_WR", 0x8000, 0xF0)

  if device_test == false then
    return false
  else
    return true
  end
end

-- write a single byte to PRG-ROM flash
-- PRE: assumes mapper is initialized and bank is selected as prescribed in mapper_init
-- REQ: addr must be in the first bank $8000-9FFF
local function prg_rom_flash_byte(addr, value, debug)
  if addr < 0x8000 or addr > 0x9FFF then
    log.error("ERROR! flash write to PRG-ROM", help.hex_0x4(addr), "must be $8000-$9FFF")
    return
  end

  -- send unlock command and write byte
  dict.nes("NES_CPU_WR", 0xD555, 0xAA)
  dict.nes("NES_CPU_WR", 0xAAAA, 0x55)
  dict.nes("NES_CPU_WR", 0xD555, 0xA0)
  dict.nes("NES_CPU_WR", addr, value)

  -- recover by setting $8000 reg select back to a IRQ reg
  dict.nes("NES_CPU_WR", 0x8000, 0x0E)

  local rv = dict.nes("NES_CPU_RD", addr)

  local i = 0

  while rv ~= dict.nes("NES_CPU_RD", addr) do
    rv = dict.nes("NES_CPU_RD", addr)
    i = i + 1
  end

  if debug then
    log.info("Done writing byte,", i .. " naks")
  end

  -- TODO handle timeout for problems

  -- TODO return pass/fail/info
end

-- dump PRG-ROM
local function prg_rom_dump(file, rom_size_KB, debug)
  -- PRG-ROM dump 16KB at a time through FME7 reg9&A
  local KB_per_read = 16
  local num_banks = math.floor(rom_size_KB / KB_per_read)
  local cur_bank = 0
  local addr_base = 0x80 -- $8000

  log.info("PRG-ROM size", rom_size_KB .. "KB")

  while cur_bank < num_banks do
    if debug then
      log.point("dumping PRG bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    dict.nes("NES_CPU_WR", 0x8000, 0x09)
    -- the bank is half the size of KB per read so must multiply by 2
    dict.nes("NES_CPU_WR", 0xA000, cur_bank * 2) -- 8KB @ CPU $8000

    dict.nes("NES_CPU_WR", 0x8000, 0x0A)
    -- the bank is half the size of KB per read so must multiply by 2 and add 1 for second 8KB
    dict.nes("NES_CPU_WR", 0xA000, cur_bank * 2 + 1) -- 8KB @ CPU $A000

    -- have the device dump a bank worth of data
    dump.dumptofile(file, KB_per_read, addr_base, "NESCPU_PAGE", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

-- host flash one bank at a time
local function prg_rom_flash(file, rom_size_KB, debug)
  init_mapper()

  log.section("Programming PRG-ROM")
  log.info("PRG-ROM size", rom_size_KB .. "KB")

  local bank_size = 8 -- FME7 8KByte per PRG bank
  local cur_bank = 0
  local num_banks = math.floor(rom_size_KB / bank_size)

  while cur_bank < num_banks do
    if debug then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- write the current bank to the mapper register
    -- DATA writes written to $8000-9FFF
    dict.nes("NES_CPU_WR", 0x8000, 0x09)
    dict.nes("NES_CPU_WR", 0xA000, cur_bank) -- 8KB @ CPU $8000

    --set $8000 bank select back to a IRQ register
    --keeps from having the PRG bank changing when writing data
    dict.nes("NES_CPU_WR", 0x8000, 0x0E)

    --have the device write a bank worth of data
    --MMC3 functions work perfectly for FME7
    flash.write_file(file, bank_size, "MMC3", "PRGROM", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
  log.success("Done programming PRG-ROM")
end

--[[
 ██████╗██╗  ██╗██████╗       ██████╗  ██████╗ ███╗   ███╗
██╔════╝██║  ██║██╔══██╗      ██╔══██╗██╔═══██╗████╗ ████║
██║     ███████║██████╔╝█████╗██████╔╝██║   ██║██╔████╔██║
██║     ██╔══██║██╔══██╗╚════╝██╔══██╗██║   ██║██║╚██╔╝██║
╚██████╗██║  ██║██║  ██║      ██║  ██║╚██████╔╝██║ ╚═╝ ██║
 ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝      ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝

  --]]

-- read CHR-ROM flash ID
local function chr_rom_manf_id()
  local manufacturer_id
  local device_id
  local device_test

  init_mapper()

  log.section("Reading CHR-ROM manufacturer/device ID")

  dict.nes("NES_PPU_WR", 0x1555, 0xAA)
  dict.nes("NES_PPU_WR", 0x1AAA, 0x55)
  dict.nes("NES_PPU_WR", 0x1555, 0x90)

  manufacturer_id = dict.nes("NES_PPU_RD", 0x0000)
  chips.display_manufacturer(manufacturer_id)

  device_id = dict.nes("NES_PPU_RD", 0x0001)
  device_test = chips.display_device(manufacturer_id, device_id)

  -- exit software
  dict.nes("NES_PPU_WR", 0x0000, 0xF0)

  if device_test == false then
    return false
  else
    return true
  end
end

-- write a single byte to CHR-ROM flash
-- PRE: assumes mapper is initialized and bank is selected as prescribed in mapper_init
-- REQ: addr must be in the first 2 banks $0000-0FFF
local function chr_rom_flash_byte(addr, value, debug)
  if addr < 0x0000 or addr > 0x0FFF then
    log.error("ERROR! flash write to CHR-ROM", help.hex_0x4(addr), "must be $0000-$0FFF")
    return
  end

  -- send unlock command and write byte
  dict.nes("NES_PPU_WR", 0x1555, 0xAA)
  dict.nes("NES_PPU_WR", 0x1AAA, 0x55)
  dict.nes("NES_PPU_WR", 0x1555, 0xA0)
  dict.nes("NES_PPU_WR", addr, value)

  local rv = dict.nes("NES_PPU_RD", addr)

  local i = 0

  while rv ~= dict.nes("NES_PPU_RD", addr) do
    rv = dict.nes("NES_PPU_RD", addr)
    i = i + 1
  end

  if debug then
    log.info("Done writing byte,", i .. " naks")
  end

  -- TODO handle timeout for problems

  -- TODO return pass/fail/info
end

-- dump CHR-ROM/RAM
local function chr_dump(file, rom_size_KB, debug)
  local KB_per_read = 2 -- dump one half PT at a time so only need 2 reg writes
  local num_banks = math.floor(rom_size_KB / KB_per_read)
  local cur_bank = 0
  local addr_base = 0x00 -- $0000

  log.info("CHR size", rom_size_KB .. "KB")

  while cur_bank < num_banks do
    if debug then
      log.point("dump CHR bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    dict.nes("NES_CPU_WR", 0x8000, 0x00)
    -- the bank is half the size of KB per read so must multiply by 2
    dict.nes("NES_CPU_WR", 0xA000, cur_bank * 2) -- 1KB @ PPU $0000

    dict.nes("NES_CPU_WR", 0x8000, 0x01)
    -- the bank is half the size of KB per read so must multiply by 2 and add 1 for second 1KB
    dict.nes("NES_CPU_WR", 0xA000, cur_bank * 2 + 1) -- 1KB @ PPU $0800

    -- have the device dump a bank worth of data
    dump.dumptofile(file, KB_per_read, addr_base, "NESPPU_1KB", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

-- host flash one bank at a time
local function chr_rom_flash(file, rom_size_KB, debug)
  init_mapper()

  log.section("Programming CHR-ROM")
  log.info("CHR-ROM size", rom_size_KB .. "KB")

  local bank_size = 4 -- FME7 1KByte per lower CHR bank and we're using 4 of them..
  local cur_bank = 0
  local num_banks = math.floor(rom_size_KB / bank_size)

  while cur_bank < num_banks do
    if debug then
      log.point("writing CHR bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- select bank to flash
    -- DATA writes written to $0000-0FFF
    dict.nes("NES_CPU_WR", 0x8000, 0x00)
    dict.nes("NES_CPU_WR", 0xA000, cur_bank * 4)     --1KB @ PPU $0000
    dict.nes("NES_CPU_WR", 0x8000, 0x01)
    dict.nes("NES_CPU_WR", 0xA000, cur_bank * 4 + 1) -- 1KB @ PPU $0400
    dict.nes("NES_CPU_WR", 0x8000, 0x02)
    dict.nes("NES_CPU_WR", 0xA000, cur_bank * 4 + 2) -- 1KB @ PPU $0800
    dict.nes("NES_CPU_WR", 0x8000, 0x03)
    dict.nes("NES_CPU_WR", 0xA000, cur_bank * 4 + 3) -- 1KB @ PPU $0C00

    --have the device write a bank worth of data
    --MMC3 functions work perfectly for FME7
    flash.write_file(file, 4, "MMC3", "CHRROM", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
  log.success("Done programming CHR-ROM")
end

--[[
██████╗ ██████╗  ██████╗       ██████╗  █████╗ ███╗   ███╗
██╔══██╗██╔══██╗██╔════╝       ██╔══██╗██╔══██╗████╗ ████║
██████╔╝██████╔╝██║  ███╗█████╗██████╔╝███████║██╔████╔██║
██╔═══╝ ██╔══██╗██║   ██║╚════╝██╔══██╗██╔══██║██║╚██╔╝██║
██║     ██║  ██║╚██████╔╝      ██║  ██║██║  ██║██║ ╚═╝ ██║
╚═╝     ╚═╝  ╚═╝ ╚═════╝       ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝

  --]]

-- dump the PRG-RAM, assumes the PRG-RAM was enabled as desired prior to calling
local function prg_ram_dump(file, ram_size_KB, debug)
  init_mapper()

  local KB_per_read = 8
  local num_banks = math.floor(ram_size_KB / KB_per_read)
  local addr_base = 0x60 -- $6000
  local cur_bank = 0

  log.info("PRG-RAM size", ram_size_KB .. "KB")

  dict.nes("NES_CPU_WR", 0x8000, 0x08)

  while cur_bank < num_banks do
    if debug then
      log.point("dumping PRG-RAM bank ", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    dict.nes("NES_CPU_WR", 0xA000, 0xC0 | cur_bank)

    -- have the device dump a bank worth of data
    dump.dumptofile(file, KB_per_read, addr_base, "NESCPU_PAGE", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

-- write to the PRG-RAM, assumes the PRG-RAM was enabled/disabled as desired prior to calling
local function prg_ram_write(file, ram_size_KB, debug)
  init_mapper()

  log.info("PRG-RAM size", ram_size_KB .. "KB")

  local bank_size = 8
  local cur_bank = 0
  local num_banks = math.floor(ram_size_KB / bank_size)

  dict.nes("NES_CPU_WR", 0x8000, 0x08)

  while cur_bank < num_banks do
    if debug then
      log.point("writing PRG-RAM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    dict.nes("NES_CPU_WR", 0xA000, 0xC0 | cur_bank)

    --have the device write a bank worth of data
    flash.write_file(file, bank_size, "NOVAR", "PRGRAM", false)

    cur_bank = cur_bank + 1
  end

  spinner.clear()
  log.success("Done programming PRG-RAM")
end

-- try to detect if PRG-RAM is present
local function prg_ram_test(debug)
  local test = true
  local read_value
  local saved_value

  log.section("Detecting PRG-RAM")

  -- RAM enabled, RAM first bank mapped to $6000
  dict.nes("NES_CPU_WR", 0x8000, 0x08)
  dict.nes("NES_CPU_WR", 0xA000, 0xC0)

  -- save potential battery backed data first
  saved_value = dict.nes("NES_CPU_RD", 0x6000)
  if debug then log.bullet("saved_value:", help.hex_0x2(saved_value)) end

  -- try to write and read back
  dict.nes("NES_CPU_WR", 0x6000, saved_value ~ 0xff)
  read_value = dict.nes("NES_CPU_RD", 0x6000)
  if read_value ~= (saved_value ~ 0xff) then
    test = false
  end

  -- put back original value
  dict.nes("NES_CPU_WR", 0x6000, saved_value)
  read_value = dict.nes("NES_CPU_RD", 0x6000)
  if read_value ~= (saved_value) then
    test = false
  end

  if test then
    log.success("PRG-RAM detected")
  else
    log.error("PRG-RAM not detected")
  end

  -- RAM disabled, ROM first bank mapped to $6000
  dict.nes("NES_CPU_WR", 0x8000, 0x08)
  dict.nes("NES_CPU_WR", 0xA000, 0x00)

  return test
end

-- try to detect PRG-RAM size
local function prg_ram_get_size(debug)
  -- PRG-RAM can be maximum 32KB
  -- so we'll check 8 8K banks and see if we can write to each

  local prg_ram_size = 32
  local num_banks = math.floor(prg_ram_size / 8)
  local cur_bank = num_banks - 1

  log.section("Detecting PRG-RAM size")

  -- RAM enabled, RAM first bank mapped to $6000
  dict.nes("NES_CPU_WR", 0x8000, 0x08)
  dict.nes("NES_CPU_WR", 0xA000, 0xC0)

  -- write to banks backwards
  while cur_bank >= 0 do
    if debug then
      log.point("trying to write to PRG-RAM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Writing", cur_bank, "/", num_banks - 1)
    end

    -- set bank
    dict.nes("NES_CPU_WR", 0xA000, 0xC0 | cur_bank)

    -- write data
    dict.nes("NES_CPU_WR", 0x6000, cur_bank)

    cur_bank = cur_bank - 1
  end

  spinner.clear()

  -- read back only last bank
  -- set bank
  dict.nes("NES_CPU_WR", 0xA000, 0xC0 | (num_banks - 1))
  prg_ram_size = (dict.nes("NES_CPU_RD", 0x6000) + 1) * 8

  -- RAM disabled, ROM first bank mapped to $6000
  dict.nes("NES_CPU_WR", 0x8000, 0x08)
  dict.nes("NES_CPU_WR", 0xA000, 0x00)

  if prg_ram_size >= 0 and prg_ram_size <= 32 then
    log.success("PRG-RAM size detected", prg_ram_size .. "KB")
    return prg_ram_size
  else
    log.warning("Failed to detect PRG-RAM size")
    return 0
  end
end

local function prg_ram_exercise(wram_size, retroprog_id, debug)
  dict.stuff("RESET_LFSR") -- sets it to 1

  if wram_size == 0 then
    log.warning("PRG-RAM size not provided, using default 32KB")
    wram_size = 32
  end

  local cur_bank = 0
  local num_banks = math.floor(wram_size / 8)

  log.section("Exercising PRG-RAM")
  log.info("PRG-RAM size", wram_size .. "KB")

  dict.nes("NES_CPU_WR", 0x8000, 0x08)

  -- write random data to all banks
  log.point("Writing random data to PRG-RAM")
  while cur_bank < num_banks do
    if debug then
      log.point("init PRG-RAM 8K bank", cur_bank, "of", num_banks - 1)
    end

    -- set bank
    dict.nes("NES_CPU_WR", 0xA000, 0xC0 | cur_bank)

    -- write random data
    local addr = 0x6000
    while addr < 0x8000 do
      dict.nes("CPU_PAGE_WR_LFSR", addr)
      addr = addr + 256
    end
    cur_bank = cur_bank + 1
  end

  -- open file
  local filename = opts.write_path .. "./ignore/nes_prg_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))

  -- dump PRG-RAM
  log.point("Dumping PRG-RAM")
  prg_ram_dump(file, wram_size, false)

  -- close file
  assert(file:close())

  -- RAM disabled, ROM first bank mapped to $6000
  dict.nes("NES_CPU_WR", 0xA000, 0x00)

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "./ignore/lfsr_32KB.bin"

  -- compare the flash file vs post dump file
  if files.compare(filename, goodfile, false, debug) then
    log.success("PRG-RAM test passed")
    return true
  else
    log.error("PRG-RAM test failed")
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
  local rv               = nil
  local file
  local chr_ram_detected = false
  local chr_ram_size     = 0

  -- process options
  local DEBUG            = process_opts.debug
  local retroprog_id     = process_opts.retroprog_id
  local do_test          = process_opts.do_test
  local do_erase         = process_opts.do_erase
  local do_rom_write     = process_opts.do_rom_write
  local do_verify        = process_opts.do_verify
  local do_rom_dump      = process_opts.do_rom_dump
  local do_ram_dump      = process_opts.do_ram_dump
  local do_ram_write     = process_opts.do_ram_write
  local nes_file         = process_opts.nes_file
  local rom_write_file   = process_opts.rom_write_file
  local verify_file      = process_opts.verify_file
  local rom_dump_file    = process_opts.rom_dump_file
  local ram_dump_file    = process_opts.ram_dump_file
  local ram_write_file   = process_opts.ram_write_file
  local options          = process_opts.additional_opts

  -- console options
  local prg_size         = console_opts.prg_rom_size_kb
  local chr_size         = console_opts.chr_rom_size_kb
  local wram_size        = console_opts.wram_size_kb

  -- Initialize device i/o
  dict.io("IO_RESET")
  dict.io("NES_INIT")

  -- put mapper in known state
  init_mapper()

  --[[
  888888 888888 .dP"Y8 888888
    88   88__   `Ybo."   88
    88   88""   o.`Y8b   88
    88   888888 8bodP'   88
  --]]

  -- test cart
  if do_test then
    log.section("Testing", mapname)

    -- verify mirroring is behaving as expected
    rv = mirror_test(DEBUG)
    if not rv then return false end

    chr_ram_detected = nes.ppu_ram_sense(0x1000, DEBUG)

    -- attempt to read PRG-ROM flash ID
    if options.force_flash_test or (do_rom_write and prg_size ~= 0) then
      rv = prg_rom_manf_id()
      if not rv then
        if do_rom_write then
          log.error("Couldn't identify flash chip")
          return false
        else
          log.warning("Couldn't identify flash chip")
        end
      end
    end

    -- attempt to read CHR-ROM flash ID
    if options.force_flash_test or (do_rom_write and chr_size ~= 0) then
      rv = chr_rom_manf_id()
      if not rv then
        if do_rom_write then
          log.error("Couldn't identify flash chip")
          return false
        else
          log.warning("Couldn't identify flash chip")
        end
      end
    end

    -- PRG-RAM tests
    rv = prg_ram_test(DEBUG)
    if rv == true then
      if options.force_wram_test then
        log.print()
        log.warning("Flag 'force_wram_test' enabled")
      end
      if options.force_wram_test or nes.header.is_valid then
        if not options.force_wram_test and nes.header.has_battery then
          log.print()
          log.warning("Can't exercise PRG-RAM because NES ROM has battery backed data")
        else
          if wram_size == 0 then
            wram_size = prg_ram_get_size(DEBUG)
          end
          if wram_size ~= 0 then
            rv = prg_ram_exercise(wram_size, retroprog_id, DEBUG)
            -- exit script if test fails
            if not rv then return end
          end
        end
      else
        log.warning("Can't exercise PRG-RAM because data could be battery backed")
      end
    end
  end

  --[[
  88""Yb    db    8b    d8     8888b.  88   88 8b    d8 88""Yb
  88__dP   dPYb   88b  d88      8I  Yb 88   88 88b  d88 88__dP
  88"Yb   dP__Yb  88YbdP88      8I  dY Y8   8P 88YbdP88 88"""
  88  Yb dP""""Yb 88 YY 88     8888Y"  `YbodP' 88 YY 88 88
  --]]

  -- dump cart RAM to file
  if do_ram_dump then
    init_mapper()

    log.section("Dumping PRG-RAM")

    -- open file
    file = assert(io.open(ram_dump_file.filename, "wb"))

    -- dump cart to file
    if wram_size ~= 0 then
      time.start()
      prg_ram_dump(file, wram_size, DEBUG)
      time.report(wram_size)
      log.success("PRG-RAM dumping done")
    else
      log.error("PRG-RAM size not provided")
      return
    end

    -- close file
    assert(file:close())
  end

  --[[
  88""Yb    db    8b    d8     Yb        dP 88""Yb 88 888888 888888
  88__dP   dPYb   88b  d88      Yb  db  dP  88__dP 88   88   88__
  88"Yb   dP__Yb  88YbdP88       YbdPYbdP   88"Yb  88   88   88""
  88  Yb dP""""Yb 88 YY 88        YP  YP    88  Yb 88   88   888888
  --]]

  -- write file to the cart RAM
  if do_ram_write then
    log.section("Programming PRG-RAM")

    -- open file
    file = assert(io.open(ram_write_file.filename, "rb"))

    -- flash cart
    if wram_size ~= 0 then
      time.start()
      prg_ram_write(file, wram_size, DEBUG)
      time.report(wram_size)
    else
      log.error("PRG-RAM size not provided")
      return
    end

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
    init_mapper()

    -- open file
    file = assert(io.open(rom_dump_file.filename, "wb"))

    -- create header: pass open & empty file & rom sizes
    if rom_dump_file.ext == "nes" then
      create_header(file, prg_size, chr_size)
    end

    -- dump cart to file
    if prg_size ~= 0 then
      log.section("Dumping PRG-ROM")
      time.start()
      prg_rom_dump(file, prg_size, DEBUG)
      time.report(prg_size)
      log.success("PRG-ROM dumping done")
    end

    if chr_size ~= 0 then
      log.section("Dumping CHR-ROM")
      time.start()
      chr_dump(file, chr_size, DEBUG)
      time.report(chr_size)
      log.success("CHR-ROM dumping done")
    end

    -- close file
    assert(file:close())
  end

  --[[
  88""Yb  dP"Yb  8b    d8     888888 88""Yb    db    .dP"Y8 888888
  88__dP dP   Yb 88b  d88     88__   88__dP   dPYb   `Ybo." 88__
  88"Yb  Yb   dP 88YbdP88     88""   88"Yb   dP__Yb  o.`Y8b 88""
  88  Yb  YbodP  88 YY 88     888888 88  Yb dP""""Yb 8bodP' 888888
  --]]

  -- erase the cart
  if do_erase then
    local i = 0

    -- erase PRG-ROM only if needed
    if prg_size ~= 0 then
      init_mapper()
      log.section("Erasing PRG-ROM")
      time.start()
      dict.nes("NES_CPU_WR", 0xD555, 0xAA)
      dict.nes("NES_CPU_WR", 0xAAAA, 0x55)
      dict.nes("NES_CPU_WR", 0xD555, 0x80)
      dict.nes("NES_CPU_WR", 0xD555, 0xAA)
      dict.nes("NES_CPU_WR", 0xAAAA, 0x55)
      dict.nes("NES_CPU_WR", 0xD555, 0x10)

      -- TODO create some function to pass the read value
      -- that's smart enough to figure out if the board is actually erasing or not
      rv = dict.nes("NES_CPU_RD", 0x8000)
      while rv ~= dict.nes("NES_CPU_RD", 0x8000) do
        spinner.update("Erasing")
        rv = dict.nes("NES_CPU_RD", 0x8000)
        i = i + 1
      end
      spinner.clear()
      log.success("Done erasing PRG-ROM", i .. " naks")
      time.report(prg_size)
    end

    -- erase CHR-ROM only if needed
    if chr_size ~= 0 then
      init_mapper()
      log.section("Erasing CHR-ROM")
      time.start()
      dict.nes("NES_PPU_WR", 0x1555, 0xAA)
      dict.nes("NES_PPU_WR", 0x1AAA, 0x55)
      dict.nes("NES_PPU_WR", 0x1555, 0x80)
      dict.nes("NES_PPU_WR", 0x1555, 0xAA)
      dict.nes("NES_PPU_WR", 0x1AAA, 0x55)
      dict.nes("NES_PPU_WR", 0x1555, 0x10)

      -- TODO create some function to pass the read value
      -- that's smart enough to figure out if the board is actually erasing or not
      i = 0
      rv = dict.nes("NES_PPU_RD", 0x0000)
      while rv ~= dict.nes("NES_PPU_RD", 0x0000) do
        spinner.update("Erasing")
        rv = dict.nes("NES_PPU_RD", 0x0000)
        i = i + 1
      end
      spinner.clear()
      log.success("Done erasing CHR-ROM", i .. " naks")
      time.report(chr_size)
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
    -- open file
    file = assert(io.open(rom_write_file.filename, "rb"))

    -- flash cart
    if prg_size ~= 0 then
      time.start()
      prg_rom_flash(file, prg_size, DEBUG)
      time.report(prg_size)
    end

    if chr_size ~= 0 then
      time.start()
      chr_rom_flash(file, chr_size, DEBUG)
      time.report(chr_size)
    end

    -- close file
    assert(file:close())
  end

  --[[
  Yb    dP 888888 88""Yb 88 888888 Yb  dP
   Yb  dP  88__   88__dP 88 88__    YbdP
    YbdP   88""   88"Yb  88 88""     8P
     YP    888888 88  Yb 88 88      dP
  --]]

  -- verify what we just flashed
  if do_verify then
    init_mapper()

    -- open file
    file = assert(io.open(verify_file.filename, "wb"))

    -- dump cart to file
    if prg_size ~= 0 then
      log.section("Dumping PRG-ROM")
      time.start()
      prg_rom_dump(file, prg_size, DEBUG)
      time.report(prg_size)
      log.success("PRG-ROM dumping done")
    end

    if chr_size ~= 0 then
      log.section("Dumping CHR-ROM")
      time.start()
      chr_dump(file, chr_size, DEBUG)
      time.report(chr_size)
      log.success("CHR-ROM dumping done")
    end

    -- close file
    assert(file:close())

    -- compare the flash file vs post dump file
    log.section("Verifying data")
    if files.compare(verify_file.filename, rom_write_file.filename, true, true) then
      log.success("Flash successfully verified")
    else
      log.error("Flash verification did not match")
    end
  end

  dict.io("IO_RESET")
end

-- global variables so other modules can use them

-- call functions desired to run when script is called/imported

-- functions other modules are able to call
fme7.process = process

-- return the module's table
return fme7
