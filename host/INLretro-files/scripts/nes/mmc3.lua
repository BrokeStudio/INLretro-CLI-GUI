-- create the module's table
local mmc3            = {}

-- import required modules
local dict            = require "scripts.app.dict"
local nes             = require "scripts.app.nes"
local dump            = require "scripts.app.dump"
local flash           = require "scripts.app.flash"
local time            = require "scripts.app.time"
local log             = require "scripts.app.log"
local spinner         = require "scripts.app.spinner"
local files           = require "scripts.app.files"
local help            = require "scripts.app.help"

-- file constants and global variables
local mapname         = "MMC3"
local prg_flash_chip
local chr_flash_chip

-- registers
local BANK_SELECT     = 0x8000
local BANK_DATA       = 0x8001
local MIRRORING       = 0xA000
local PRG_RAM_PROTECT = 0xA001
local IRQ_LATCH       = 0xC000
local IRQ_RELOAD      = 0xC001
local IRQ_DISABLE     = 0xE000

-- local functions

--[[
██╗  ██╗███████╗██╗     ██████╗ ███████╗██████╗ ███████╗
██║  ██║██╔════╝██║     ██╔══██╗██╔════╝██╔══██╗██╔════╝
███████║█████╗  ██║     ██████╔╝█████╗  ██████╔╝███████╗
██╔══██║██╔══╝  ██║     ██╔═══╝ ██╔══╝  ██╔══██╗╚════██║
██║  ██║███████╗███████╗██║     ███████╗██║  ██║███████║
╚═╝  ╚═╝╚══════╝╚══════╝╚═╝     ╚══════╝╚═╝  ╚═╝╚══════╝

--]]

local function create_header(file, prg_kb, chr_kb)
  nes.write_header(file, prg_kb, chr_kb, op_buffer[mapname], 0)
end

-- disables PRG-RAM, selects Vertical mirroring
-- sets up CHR-ROM flash PT0 for DATA, Commands: $5555->$1555  $2AAA->$1AAA
-- sets up PRG-ROM flash DATA: $8000-9FFF, Commands: $5555->D555  $2AAA->$AAAA
-- leaves reg0 selected (CHR bank & $0000) selected so PRG DATA writes don't change PRG banks
local function init_mapper()
  -- for save data safety start by disabling PRG-RAM and deny writes
  nes.cpu_wr(PRG_RAM_PROTECT, 0x40)

  -- set mirroring
  nes.cpu_wr(MIRRORING, 0x00) -- bit0 0-vert 1-horiz

  -- disable interrupts
  nes.cpu_wr(IRQ_DISABLE, 0x00) -- any value acknowledges IRQ & disables IRQs
  nes.cpu_wr(IRQ_LATCH, 0xFF)   -- set reload register
  nes.cpu_wr(IRQ_RELOAD, 0x00)  -- won't actually get updated until PPU A12 edge

  -- $8000-9FFE even
  -- MMC3 bank select:
  -- 7  bit  0
  ------------
  -- CPMx xRRR
  -- |||   |||
  -- |||   +++- Specify which bank register to update on next write to Bank Data register
  -- |||        0: Select 2 KB CHR bank at PPU $0000-$07FF (or $1000-$17FF)
  -- |||        1: Select 2 KB CHR bank at PPU $0800-$0FFF (or $1800-$1FFF)
  -- |||        2: Select 1 KB CHR bank at PPU $1000-$13FF (or $0000-$03FF)
  -- |||        3: Select 1 KB CHR bank at PPU $1400-$17FF (or $0400-$07FF)
  -- |||        4: Select 1 KB CHR bank at PPU $1800-$1BFF (or $0800-$0BFF)
  -- |||        5: Select 1 KB CHR bank at PPU $1C00-$1FFF (or $0C00-$0FFF)
  -- |||        6: Select 8 KB PRG ROM bank at $8000-$9FFF (or $C000-$DFFF)
  -- |||        7: Select 8 KB PRG ROM bank at $A000-$BFFF
  -- ||+------- Nothing on the MMC3, see MMC6
  -- |+-------- PRG ROM bank mode (0: $8000-$9FFF swappable,
  -- |                                $C000-$DFFF fixed to second-last bank;
  -- |                             1: $C000-$DFFF swappable,
  -- |                                $8000-$9FFF fixed to second-last bank)
  -- +--------- CHR A12 inversion (0: two 2 KB banks at $0000-$0FFF,
  --                                  four 1 KB banks at $1000-$1FFF;
  --                               1: two 2 KB banks at $1000-$1FFF,
  --                                  four 1 KB banks at $0000-$0FFF)

  -- For CHR-ROM flash writes, use lower 4KB (PT0) for writing data & upper 4KB (PT1) for commands
  nes.cpu_wr(BANK_SELECT, 0x00)
  nes.cpu_wr(BANK_DATA, 0x00) -- 2KB @ PPU $0000

  nes.cpu_wr(BANK_SELECT, 0x01)
  nes.cpu_wr(BANK_DATA, 0x02) -- 2KB @ PPU $0800

  -- use lower half of PT1 for $5555 commands
  nes.cpu_wr(BANK_SELECT, 0x02)
  nes.cpu_wr(BANK_DATA, 0x15) -- 1KB @ PPU $1000

  nes.cpu_wr(BANK_SELECT, 0x03)
  nes.cpu_wr(BANK_DATA, 0x15) -- 1KB @ PPU $1400

  -- use upper half of PT1 for $2AAA commands
  nes.cpu_wr(BANK_SELECT, 0x04)
  nes.cpu_wr(BANK_DATA, 0x0A) -- 1KB @ PPU $1800

  nes.cpu_wr(BANK_SELECT, 0x05)
  nes.cpu_wr(BANK_DATA, 0x0A) -- 1KB @ PPU $1C00

  -- For PRG-ROM flash writes:
  -- mode 0: $C000-FFFF fixed to last 16KByte
  --         reg6 controls $8000-9FFF ($C000-DFFF in mode 1)
  --         reg7 controls $A000-BFFF (regardless of mode)
  -- Don't want to write data to $8000-9FFF because those are the bank regs
  -- writing data to $A000-BFFF is okay as that will only affect mirroring and PRG-RAM ctl

  -- $5555 commands can be written to $D555 (A14 set, A13 clear)
  -- $2AAA commands must be written through reg6/7 ($8000-BFFF) to clear A14 & set A13
  --  reg7 ($A000-BFFF) is ideal because it won't affect banking, just mirror/PRG-RAM
  --  actually $2AAA is even, so it'll only affect mirroring which is ideal
  -- DATA writes can occur at $8000-9FFF, but care must be taken to maintain banking.
  --  Setting $8000 to a CHR bank prevents DATA writes from changing PRG banks
  --  The DATA write will change the bank select if it's written to an even address though
  --  To cover this, simply select the CHR bank again with $8000 reg after the data write
  --  Those DATA writes can also corrupt the PRG/CHR modes, so just always follow
  --  DATA writes by writing 0x00 to $8000

  -- $5555 commands written to $D555 (default due to mode 0)
  -- $2AAA commands written to $AAAA
  nes.cpu_wr(BANK_SELECT, 0x07)
  nes.cpu_wr(BANK_DATA, 0x01) -- 8KB @ CPU $A000

  -- DATA writes written to $8000-9FFF
  nes.cpu_wr(BANK_SELECT, 0x06)
  nes.cpu_wr(BANK_DATA, 0x00) -- 8KB @ CPU $8000

  -- set $8000 bank select register to a CHR reg so $8000/1 writes don't change the PRG bank
  nes.cpu_wr(BANK_SELECT, 0x00)
end

-- test the mapper's mirroring modes to verify working properly
-- can be used to help identify board: returns true if pass, false if failed
local function mirror_test()
  log.section("Testing mirroring settings")

  -- put mapper in known state
  init_mapper()

  -- Vertical
  if nes.detect_mapper_mirroring() ~= "VERT" then
    log.error("Vertical mirroring test failed")
    return false
  else
    log.success("Vertical mirroring test passed")
  end

  -- Horizontal
  nes.cpu_wr(MIRRORING, 0x01) -- bit0 0-vert 1-horiz
  if nes.detect_mapper_mirroring() ~= "HORZ" then
    log.error("Horizontal mirroring test failed")
    return false
  else
    log.success("Horizontal mirroring test passed")
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

--- Program one byte to PRG-ROM flash and poll for completion.
-- @param addr integer Address to program
-- @param value integer 8-bit value to write
local function prg_rom_flash_byte(addr, value)
  if (addr < 0x8000 or addr > 0x9FFF) then
    log.error("ERROR! flash write to PRG-ROM", help.hex_0x4(addr), "must be $8000-9FFF")
    return
  end

  -- send unlock command and write byte
  nes.cpu_wr(0xD555, 0xAA)
  nes.cpu_wr(0xAAAA, 0x55)
  nes.cpu_wr(0xD555, 0xA0)
  nes.cpu_wr(addr, value)

  -- recover by setting $8000 reg select back to a CHR reg
  nes.cpu_wr(BANK_SELECT, 0x00)

  local rv = nes.cpu_rd(addr)

  local i = 0

  while rv ~= nes.cpu_rd(addr) do
    rv = nes.cpu_rd(addr)
    i = i + 1
  end

  if DEBUG then
    log.info("Done writing byte,", i .. " naks")
  end

  -- TODO handle timeout for problems

  -- TODO return pass/fail/info
end

--- Dump PRG-ROM contents to an already-open output file.
-- @param file file* Open binary output file
-- @param rom_size_kb integer PRG-ROM size in kilobytes
local function prg_rom_dump(file, rom_size_kb)
  -- PRG-ROM dump 16KB at a time through MMC3 reg6&7 in mode 0
  local kb_per_read = 16
  local num_banks = math.floor(rom_size_kb / kb_per_read)
  local cur_bank = 0
  local addr_base = 0x80 -- $8000

  log.info("PRG-ROM size", rom_size_kb .. "KB")

  while cur_bank < num_banks do
    if DEBUG then
      log.point("dumping PRG bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- select desired bank(s) to dump
    nes.cpu_wr(BANK_SELECT, 0x06)
    -- t he bank is half the size of KB per read so must multiply by 2
    nes.cpu_wr(BANK_DATA, cur_bank * 2) -- 8KB @ CPU $8000

    nes.cpu_wr(BANK_SELECT, 0x07)
    -- the bank is half the size of KB per read so must multiply by 2 and add 1 for second 8KB
    nes.cpu_wr(BANK_DATA, cur_bank * 2 + 1) -- 8KB @ CPU $A000

    dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NES_CPU_PAGE" })

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--- Program PRG-ROM contents from an already-open input file, one bank at a time.
-- @param file file* Open binary input file
-- @param rom_size_kb integer PRG-ROM size in kilobytes
local function prg_rom_flash(file, rom_size_kb)
  init_mapper()

  log.section("Programming PRG-ROM")
  log.info("PRG-ROM size", rom_size_kb .. "KB")

  local bank_size_kb = 8 -- MMC3 8KByte per PRG bank
  local cur_bank = 0
  local num_banks = math.floor(rom_size_kb / bank_size_kb)

  local options
  if prg_flash_chip.buffer == true then
    options = "USE_BUFFER"
    log.info("Using buffer programming")
  elseif prg_flash_chip.unlock_bypass == true then
    options = "USE_UNLOCK_BYPASS"
    log.info("Using unlock bypass mode")
  end

  while cur_bank < num_banks do
    if DEBUG then
      log.point("writing PRG-ROM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- write the current bank to the mapper register
    -- DATA writes written to $8000-9FFF
    nes.cpu_wr(BANK_SELECT, 0x06)
    nes.cpu_wr(BANK_DATA, cur_bank) -- 8KB @ CPU $8000

    -- set $8000 bank select back to a CHR register
    -- keeps from having the PRG bank changing when writing data
    nes.cpu_wr(BANK_SELECT, 0x00)

    -- flash data
    flash.write_file(file, bank_size_kb, { mapper = mapname, mem_type = "NES_PRG_ROM", { options = options } })

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

--- Program one byte to CHR flash and poll for completion.
-- @param addr integer Address to program, 0x0000-0x0FFF
-- @param value integer 8-bit value to write
local function chr_rom_flash_byte(addr, value)
  if addr < 0x0000 or addr > 0x0FFF then
    log.error("ERROR! flash write to CHR-ROM", help.hex_0x4(addr), "must be $0000-0FFF")
    return
  end

  -- send unlock command and write byte
  nes.ppu_wr(0x1555, 0xAA)
  nes.ppu_wr(0x1AAA, 0x55)
  nes.ppu_wr(0x1555, 0xA0)
  nes.ppu_wr(addr, value)

  local rv = nes.ppu_rd(addr)

  local i = 0

  while (rv ~= value) do
    rv = nes.ppu_rd(addr)
    i = i + 1
  end
  if DEBUG then print(i, "naks, done writing byte.") end

  -- TODO handle timeout for problems

  -- TODO return pass/fail/info
end

--- Dump CHR contents to an already-open output file.
-- @param file file* Open binary output file
-- @param rom_size_kb integer CHR size in kilobytes
local function chr_dump(file, rom_size_kb)
  local kb_per_read = 4 -- dump one PT at a time so only need 2 reg writes
  local num_banks = math.floor(rom_size_kb / kb_per_read)
  local cur_bank = 0
  local addr_base = 0x00 -- $0000

  log.info("CHR size", rom_size_kb .. "KB")

  while cur_bank < num_banks do
    if DEBUG then
      log.point("dump CHR bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    -- the bank is half the size of KB per read so must multiply by 2
    -- but bit0 isn't used with these 2KB banks, so shift by 1
    nes.cpu_wr(BANK_SELECT, 0x00)
    nes.cpu_wr(BANK_DATA, ((cur_bank * 2) << 1)) -- 2KB @ PPU $0000

    -- the bank is half the size of KB per read so must multiply by 2 and add 1 for second 4KB
    -- but bit0 isn't used with these 2KB banks, so shift by 1
    nes.cpu_wr(BANK_SELECT, 0x01)
    nes.cpu_wr(BANK_DATA, ((cur_bank * 2 + 1) << 1)) -- 2KB @ CPU $0800

    -- 4 = number of KB to dump per loop
    -- 0x00 = starting read address A10-13 -> $0000
    -- mapper must be 0x00 or 0x04-0x3C to designate A10-13
    --  bits 7, 6, 1, & 0 CAN NOT BE SET!
    --  0x04 would designate that A10 is set -> $0400 (the second 1KB PT bank)
    --  0x20 would designate that A13 is set -> $2000 (first name table)
    dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NES_PPU_1KB_TOGGLE" })

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--- Program CHR contents from an already-open input file, one bank at a time.
-- @param file file* Open binary input file
-- @param rom_size_kb integer CHR size in kilobytes
local function chr_rom_flash(file, rom_size_kb)
  init_mapper()

  log.section("Programming CHR-ROM")
  log.info("CHR-ROM size", rom_size_kb .. "KB")

  local bank_size_kb = 4 -- MMC3 2KByte per lower CHR bank and we're using 2 of them..
  local cur_bank = 0
  local num_banks = math.floor(rom_size_kb / bank_size_kb)

  local options
  if prg_flash_chip.buffer == true then
    options = "USE_BUFFER"
    log.info("Using buffer programming")
  elseif prg_flash_chip.unlock_bypass == true then
    options = "USE_UNLOCK_BYPASS"
    log.info("Using unlock bypass mode")
  end

  while cur_bank < num_banks do
    if DEBUG then
      log.point("writing CHR bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- the bank is half the size of KB per read so must multiply by 2
    -- but bit0 isn't used with these 2KB banks, so shift by 1
    nes.cpu_wr(BANK_SELECT, 0x00)
    nes.cpu_wr(BANK_DATA, ((cur_bank * 2) << 1)) -- 2KB @ PPU $0000

    -- the bank is half the size of KB per read so must multiply by 2 and add 1 for second 4KB
    -- but bit0 isn't used with these 2KB banks, so shift by 1
    nes.cpu_wr(BANK_SELECT, 0x01)
    nes.cpu_wr(BANK_DATA, ((cur_bank * 2 + 1) << 1)) -- 2KB @ CPU $0800

    -- flash data
    flash.write_file(file, bank_size_kb, { mapper = mapname, mem_type = "NES_CHR_ROM", options = options })

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

--- Dump PRG-RAM contents to an already-open output file.
-- @param file file* Open binary output file
-- @param ram_size_kb integer PRG-RAM size in kilobytes
local function prg_ram_dump(file, ram_size_kb)
  local kb_per_read = 8
  local num_banks = math.floor(ram_size_kb / kb_per_read)
  local cur_bank = 0
  local addr_base = 0x60 -- $6000

  log.info("PRG-RAM size", ram_size_kb .. "KB")

  while cur_bank < num_banks do
    if DEBUG then
      log.point("dumping PRG-RAM bank ", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Dumping", cur_bank, "/", num_banks - 1)
    end

    dump.dumptofile(file, kb_per_read, { addr_base = addr_base, mem_type = "NES_CPU_PAGE" })

    cur_bank = cur_bank + 1
  end

  spinner.clear()
end

--- Write PRG-RAM contents from an already-open input file.
-- @param file file* Open binary input file
-- @param ram_size_kb integer PRG-RAM size in kilobytes
local function prg_ram_write(file, ram_size_kb)
  init_mapper()

  log.info("PRG-RAM size", ram_size_kb .. "KB")

  local bank_size_kb = 8
  local cur_bank = 0
  local num_banks = math.floor(ram_size_kb / bank_size_kb)

  -- enable PRG-RAM and allow writes
  nes.cpu_wr(PRG_RAM_PROTECT, 0x80)

  while cur_bank < num_banks do
    if DEBUG then
      log.point("writing PRG-RAM bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Flashing", cur_bank, "/", num_banks - 1)
    end

    -- have the device write a bank worth of data
    flash.write_file(file, bank_size_kb, { mapper = "NOVAR", mem_type = "NES_PRG_RAM" })

    cur_bank = cur_bank + 1
  end

  -- disable PRG-RAM and deny writes
  nes.cpu_wr(PRG_RAM_PROTECT, 0x40)

  spinner.clear()
  log.success("Done programming PRG-RAM")
end

--- Detect PRG-RAM by writing and reading back a test byte.
-- @return boolean success True when RAM read/write behavior is detected
local function prg_ram_detect()
  local read_value
  local saved_value

  log.section("Detecting PRG-RAM")

  -- enable PRG-RAM and allow writes
  nes.cpu_wr(PRG_RAM_PROTECT, 0x80)

  -- save potential battery backed data first
  saved_value = nes.cpu_rd(0x6000)

  -- try to write and read back
  nes.cpu_wr(0x6000, saved_value ~ 0xff)
  read_value = nes.cpu_rd(0x6000)
  if read_value ~= (saved_value ~ 0xff) then
    return false
  end

  -- put back original value
  nes.cpu_wr(0x6000, saved_value)
  read_value = nes.cpu_rd(0x6000)
  if read_value ~= (saved_value) then
    return false
  end

  -- disable PRG-RAM and deny writes
  nes.cpu_wr(PRG_RAM_PROTECT, 0x40)

  return true
end

--- Test PRG-RAM by overwriting it with pseudo-random data and comparing the dump.
-- @param wram_size_kb integer PRG-RAM size in kilobytes
-- @param retroprog_id string Programmer identifier used in the RAM dump filename
-- @return boolean success True when the dumped data matches the reference pattern
local function prg_ram_test(wram_size_kb, retroprog_id)
  dict.stuff("RESET_LFSR") -- sets it to 1

  local cur_bank = 0
  local num_banks = math.floor(wram_size_kb / 8)

  log.section("Exercising PRG-RAM")
  log.info("PRG-RAM size", wram_size_kb .. "KB")

  -- enable PRG-RAM and allow writes
  nes.cpu_wr(PRG_RAM_PROTECT, 0x80)

  -- write random data to all banks
  log.point("Writing random data to PRG-RAM")
  while cur_bank < num_banks do
    if DEBUG then
      log.point("init PRG-RAM 8K bank", cur_bank, "of", num_banks - 1)
    end

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
  prg_ram_dump(file, wram_size_kb)

  -- close file
  assert(file:close())

  -- disable PRG-RAM and deny writes
  nes.cpu_wr(PRG_RAM_PROTECT, 0x40)

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "./ignore/lfsr_32KB.bin"

  -- compare the flash file vs post dump file
  if files.compare(filename, goodfile, false) then
    log.success("PRG-RAM test passed")
    return true
  else
    log.error("PRG-RAM test failed")
    return false
  end
end

--[[
 ██████╗██╗  ██╗██████╗       ██████╗  █████╗ ███╗   ███╗
██╔════╝██║  ██║██╔══██╗      ██╔══██╗██╔══██╗████╗ ████║
██║     ███████║██████╔╝█████╗██████╔╝███████║██╔████╔██║
██║     ██╔══██║██╔══██╗╚════╝██╔══██╗██╔══██║██║╚██╔╝██║
╚██████╗██║  ██║██║  ██║      ██║  ██║██║  ██║██║ ╚═╝ ██║
 ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝      ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝

--]]

--- Test CHR by overwriting it with pseudo-random data and comparing the dump.
-- @param chr_ram_size_kb integer CHR size in kilobytes
-- @param retroprog_id string Programmer identifier used in the RAM dump filename
-- @return boolean success True when the dumped data matches the reference pattern
local function chr_ram_test(chr_ram_size_kb, retroprog_id)
  dict.stuff("RESET_LFSR") -- sets it to 1

  local cur_bank = 0
  local num_banks = math.floor(chr_ram_size_kb / 4)

  log.section("Exercising CHR-RAM")
  log.info("CHR-RAM size", chr_ram_size_kb .. "KB")

  -- write random data to all banks
  log.point("Writing random data to CHR-RAM")
  while cur_bank < num_banks do
    if DEBUG then
      log.point("init CHR-RAM 8K bank", cur_bank, "of", num_banks - 1)
    else
      spinner.update("Writing", cur_bank, "/", num_banks - 1)
    end

    -- the bank is half the size of KB per read so must multiply by 2
    -- but bit0 isn't used with these 2KB banks, so shift by 1
    nes.cpu_wr(BANK_SELECT, 0x00)
    nes.cpu_wr(BANK_DATA, ((cur_bank * 2) << 1)) -- 2KB @ PPU $0000

    -- the bank is half the size of KB per read so must multiply by 2 and add 1 for second 4KB
    -- but bit0 isn't used with these 2KB banks, so shift by 1
    nes.cpu_wr(BANK_SELECT, 0x01)
    nes.cpu_wr(BANK_DATA, ((cur_bank * 2 + 1) << 1)) -- 2KB @ CPU $0800

    -- write data
    local addr = 0x0000
    while addr < 0x1000 do
      dict.nes("PPU_PAGE_WR_LFSR", addr)
      addr = addr + 256
    end

    cur_bank = cur_bank + 1
  end

  spinner.clear()

  -- dump CHR-RAM
  local filename = opts.write_path .. "./ignore/nes_chr_ram_dump-" .. retroprog_id .. ".bin"
  local file = assert(io.open(filename, "wb"))
  log.point("Dumping CHR-RAM")
  chr_dump(file, chr_ram_size_kb)

  -- close the file
  assert(file:close())

  -- re-open & compare dump with known lsfr bitstream
  local goodfile = opts.lua_path .. "./ignore/lfsr_32KB.bin"

  -- compare the flash file vs post dump file
  if files.compare(filename, goodfile, false) then
    log.success("CHR-RAM test passed")
    return true
  else
    log.error("CHR-RAM test failed")
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

--- Process all requested operations for this cartridge board/mapper.
-- @param process_opts table Parsed operation options from the main application
-- @param console_opts table Console/cartridge size options
-- @return false|nil result False on explicitly reported failure; otherwise no value
local function process(process_opts, console_opts)
  -- some local variables
  local rv               = nil
  local file
  local chr_ram_detected = false
  local chr_ram_size_kb  = 0

  -- process options
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
  local prg_size_kb      = console_opts.prg_rom_size_kb
  local chr_size_kb      = console_opts.chr_rom_size_kb
  local wram_size_kb     = console_opts.wram_size_kb

  -- Initialize device i/o
  dict.io("IO_RESET")
  dict.io("NES_INIT")

  --[[
  888888 888888 .dP"Y8 888888
    88   88__   `Ybo."   88
    88   88""   o.`Y8b   88
    88   888888 8bodP'   88
  --]]

  -- test cart
  if do_test then
    log.section("Testing ", mapname)

    -- verify mirroring is behaving as expected
    rv = mirror_test()
    if not rv then return false end

    chr_ram_detected = nes.ppu_ram_sense(0x1000)
    -- print("EXP0 pull-up test:", dict.io("EXP0_PULLUP_TEST"))

    -- attempt to read PRG-ROM flash ID
    if options.force_flash_test or (do_rom_write and prg_size_kb ~= 0) then
      init_mapper()
      rv, prg_flash_chip = nes.prg_rom_get_chip()
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
    if options.force_flash_test or (do_rom_write and chr_size_kb ~= 0) then
      init_mapper()
      rv, chr_flash_chip = nes.chr_rom_get_chip()
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
    if options.force_ram_test then
      log.print()
      log.warning("Additional option 'force_ram_test' enabled")
    end

    rv = prg_ram_detect()

    if rv == false then -- PRG RAM not found
      if do_ram_dump or do_ram_write then
        log.error("PRG-RAM not detected")
        return false
      elseif do_rom_write then
        if options.force_ram_test then
          log.warning("Additional option 'force_ram_test' implies PRG-RAM presence")
          log.error("PRG-RAM not detected")
          return false
        elseif nes.header.is_valid and nes.header.has_prg_ram then
          log.warning("ROM header settings implies PRG-RAM")
          log.error("PRG-RAM not detected")
          return false
        elseif wram_size_kb ~= 0 then
          log.warning("CLI options specify " .. wram_size_kb .. "KB of PRG-RAM")
          log.error("PRG-RAM not detected")
          return false
        else
          log.info("PRG-RAM not detected")
        end
      end
    else -- PRG RAM found
      log.success("PRG-RAM detected")

      -- force wram size to 8KB because it's MMC3 maximum
      wram_size_kb = 8

      if options.force_ram_test and (do_rom_dump or do_ram_dump) then
        log.warning("Additional option 'force_ram_test' is ignored when dumping PRG-ROM or PRG-RAM")
      elseif do_rom_write or do_ram_write then
        if options.force_ram_test or do_ram_write then
          rv = prg_ram_test(wram_size_kb, retroprog_id)
          if not rv then return false end
        elseif nes.header.is_valid and nes.header.has_prg_ram then
          if nes.header.has_battery then
            log.warning("Can't test PRG-RAM because ROM header specifies battery backed data")
            log.warning("Use additional option 'force_ram_test' to force PRG-RAM test")
          else
            rv = prg_ram_test(wram_size_kb, retroprog_id)
            if not rv then return false end
          end
        else
          log.warning("Can't test PRG-RAM because data could be battery backed")
          log.warning("Use additional option 'force_ram_test' to force PRG-RAM test")
        end
      end
    end

    -- CHR-RAM tests
    if chr_ram_detected then
      -- force size to 8KB
      chr_ram_size_kb = 8

      -- test CHR-RAM
      if chr_ram_size_kb ~= 0 then
        rv = chr_ram_test(chr_ram_size_kb, retroprog_id)
        -- exit script if test fails
        if not rv then return end
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

    -- enable PRG-RAM and deny writes
    nes.cpu_wr(PRG_RAM_PROTECT, 0xC0)

    file = assert(io.open(ram_dump_file.filename, "wb"))

    -- dump cart to file
    prg_ram_dump(file, wram_size_kb)

    -- disable PRG-RAM and deny writes
    nes.cpu_wr(PRG_RAM_PROTECT, 0x40)

    -- close file
    assert(file:close())

    log.success("Done dumping PRG-RAM")
  end

  --[[
  88""Yb    db    8b    d8     Yb        dP 88""Yb 88 888888 888888
  88__dP   dPYb   88b  d88      Yb  db  dP  88__dP 88   88   88__
  88"Yb   dP__Yb  88YbdP88       YbdPYbdP   88"Yb  88   88   88""
  88  Yb dP""""Yb 88 YY 88        YP  YP    88  Yb 88   88   888888
  --]]

  -- write file to the cart RAM
  if do_ram_write then
    log.section("Writing to PRG-RAM")

    init_mapper()

    -- enable PRG-RAM and allow writes
    nes.cpu_wr(PRG_RAM_PROTECT, 0x80)

    file = assert(io.open(ram_write_file.filename, "rb"))

    flash.write_file(file, wram_size_kb, { mapper = "NOVAR", mem_type = "NES_PRG_RAM" })

    -- disable PRG-RAM and deny writes
    nes.cpu_wr(PRG_RAM_PROTECT, 0x40)

    -- close file
    assert(file:close())

    log.success("Done writing PRG-RAM")
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
      -- create header: pass open & empty file & rom sizes
      create_header(file, prg_size_kb, chr_size_kb)
    end

    -- dump cart to file
    if prg_size_kb ~= 0 then
      log.section("Dumping PRG-ROM")
      time.start()
      prg_rom_dump(file, prg_size_kb)
      time.report(prg_size_kb)
      log.success("PRG-ROM dumping done")
    end

    if chr_size_kb ~= 0 then
      log.section("Dumping CHR-ROM")
      time.start()
      chr_dump(file, chr_size_kb)
      time.report(chr_size_kb)
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
    -- erase PRG-ROM only if needed
    if prg_size_kb ~= 0 then
      rv = nes.prg_rom_erase(prg_flash_chip)
      if not rv then
        log.error("PRG-ROM couldn't be erased")
        return false
      end
    end

    -- erase CHR-ROM only if needed
    if chr_size_kb ~= 0 then
      rv = nes.chr_rom_erase(chr_flash_chip)
      if not rv then
        log.error("CHR-ROM couldn't be erased")
        return false
      end
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

    -- flash PRG-ROM
    if prg_size_kb ~= 0 then
      time.start()
      prg_rom_flash(file, prg_size_kb)
      time.report(prg_size_kb)
    end

    -- flash CHR-ROM
    if chr_size_kb ~= 0 then
      time.start()
      chr_rom_flash(file, chr_size_kb)
      time.report(chr_size_kb)
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
    if prg_size_kb ~= 0 then
      log.section("Dumping PRG-ROM")
      time.start()
      prg_rom_dump(file, prg_size_kb)
      time.report(prg_size_kb)
      log.success("PRG-ROM dumping done")
    end

    if chr_size_kb ~= 0 then
      log.section("Dumping CHR-ROM")
      time.start()
      chr_dump(file, chr_size_kb)
      time.report(chr_size_kb)
      log.success("CHR-ROM dumping done")
    end

    -- close file
    assert(file:close())

    -- compare the flash file vs post dump file
    log.section("Verifying data")
    if files.compare(verify_file.filename, rom_write_file.filename, true) then
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
mmc3.process = process

-- return the module's table
return mmc3
