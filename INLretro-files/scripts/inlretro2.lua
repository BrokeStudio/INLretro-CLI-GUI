-- Main application flow for interacting with cartridges via USB device.
-- Refactored version that doesn't require commenting/uncommenting to change functionality.

local help    = require "scripts.app.help"
local log     = require "scripts.app.log"
local nes     = require "scripts.app.nes"
local gb      = require "scripts.app.gb"
local genesis = require "scripts.app.genesis"
local snes    = require "scripts.app.snes"
local n64     = require "scripts.app.n64"

-- Just to avoid warnings in VS Code
if opts == nil then opts = {} end

-- Helper function that checks if a string is empty or nil.
local function isempty(s)
  return s == nil or s == ''
end

--[[
██████╗ ███████╗███████╗ █████╗ ██╗   ██╗██╗  ████████╗
██╔══██╗██╔════╝██╔════╝██╔══██╗██║   ██║██║  ╚══██╔══╝
██║  ██║█████╗  █████╗  ███████║██║   ██║██║     ██║
██║  ██║██╔══╝  ██╔══╝  ██╔══██║██║   ██║██║     ██║
██████╔╝███████╗██║     ██║  ██║╚██████╔╝███████╗██║
╚═════╝ ╚══════╝╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝

--]]

-- Wrapper for managing operations for most consoles.
local function default_exec(process_opts, console_opts)
  -- Defensively filter out any console options that aren't standard.
  local default_opts = {
    rom_size_kb = console_opts.rom_size_kb,
    wram_size_kb = console_opts.wram_size_kb,
  }
  console_opts.console_process_script.process(process_opts, default_opts)
end

--[[
███╗   ██╗ ██████╗ ██╗  ██╗
████╗  ██║██╔════╝ ██║  ██║
██╔██╗ ██║███████╗ ███████║
██║╚██╗██║██╔═══██╗╚════██║
██║ ╚████║╚██████╔╝     ██║
╚═╝  ╚═══╝ ╚═════╝      ╚═╝

--]]


-- Wrapper for managing N64 operations.
local function n64_exec(process_opts, console_opts)
  local header

  -- if a rom dump file is provided, parse the cartridge ROM header
  if process_opts.rom_dump_file ~= "" then
    -- parse cartridge ROM header
    log.section("Parsing cartridge ROM header")
    if not n64.parse_header_rom() then
      log.warning("Failed to parse cartridge ROM header")
    else
      log.success("Cartridge ROM header parsed successfully")
    end

    header = n64.rom_header
  end

  -- if header ~= nil then

  --   -- control passed ROM size vs header data
  --   if console_opts.rom_size_kb < header:get_rom_size() then
  --     log.warning("Passed ROM size (" .. console_opts.rom_size_kb .. ") is LESS than header value (" .. header:get_rom_size() .. ")")
  --   elseif console_opts.rom_size_kb > header:get_rom_size() then
  --     log.warning("Passed ROM size (" .. console_opts.rom_size_kb .. ") is MORE than header value (" .. header:get_rom_size() .. ")")
  --   end

  -- end

  -- Defensively filter out any console options that aren't standard.
  local n64_console_opts = {
    rom_size_kb = console_opts.rom_size_kb,
    wram_size_kb = console_opts.wram_size_kb,
  }

  local mappers = {
    basic = require "scripts.n64.basic",
  }

  -- if no mapper provided, use basic
  if console_opts.mapper == "" then
    console_opts.mapper = "basic"
  end

  local m = mappers[console_opts.mapper]
  if m == nil then
    log.error("UNSUPPORTED MAPPER: ", console_opts.mapper)
  else
    -- Attempt requested operations with hardware!
    -- TODO: Do plumbing for interacting with RAM.
    m.process(process_opts, n64_console_opts)
  end
end

--[[
███████╗███╗   ██╗███████╗███████╗        ██╗    ███████╗███████╗ ██████╗
██╔════╝████╗  ██║██╔════╝██╔════╝       ██╔╝    ██╔════╝██╔════╝██╔════╝
███████╗██╔██╗ ██║█████╗  ███████╗      ██╔╝     ███████╗█████╗  ██║
╚════██║██║╚██╗██║██╔══╝  ╚════██║     ██╔╝      ╚════██║██╔══╝  ██║
███████║██║ ╚████║███████╗███████║    ██╔╝       ███████║██║     ╚██████╗
╚══════╝╚═╝  ╚═══╝╚══════╝╚══════╝    ╚═╝        ╚══════╝╚═╝      ╚═════╝

--]]

-- Wrapper for managing Super Nintendo operations.
local function snes_exec(process_opts, console_opts)
  local header

  -- if a rom write file is provided, parse its header
  if process_opts.rom_write_file ~= "" then
    -- parse file header
    log.section("Parsing ROM flash file header")
    log.bullet("Filename", process_opts.rom_write_file.filename)
    local snes_file = assert(io.open(process_opts.rom_write_file.filename, "rb"))
    if not snes.parse_header_file(snes_file) then
      log.warning("Failed to parse ROM flash file header")
    else
      log.success("ROM flash file header parsed successfully")
    end
    assert(snes_file:close())

    header = snes.file_header

    if (header.file_size / 1024) ~= header:get_rom_size() then
      log.warning("ROM file size (" ..
        math.floor(header.file_size / 1024) .. ") is LESS than header value (" .. header:get_rom_size() .. ")")
    end
  end

  -- if a rom dump file is provided, parse the cartridge ROM header
  if process_opts.rom_dump_file ~= "" then
    -- parse cartridge ROM header
    log.section("Parsing cartridge ROM header")
    if not snes.parse_header_cart() then
      log.warning("Failed to parse cartridge ROM header")
    else
      log.success("Cartridge ROM header parsed successfully")
    end

    header = snes.cart_header
  end

  if header ~= nil then
    -- control passed ROM size vs header data
    if console_opts.rom_size_kb < header:get_rom_size() then
      log.warning("Passed ROM size (" ..
        console_opts.rom_size_kb .. ") is LESS than header value (" .. header:get_rom_size() .. ")")
    elseif console_opts.rom_size_kb > header:get_rom_size() then
      log.warning("Passed ROM size (" ..
        console_opts.rom_size_kb .. ") is MORE than header value (" .. header:get_rom_size() .. ")")
    end
  end

  -- Defensively filter out any console options that aren't standard.
  local snes_console_opts = {
    rom_size_kb = console_opts.rom_size_kb,
    wram_size_kb = console_opts.wram_size_kb,
  }

  local mappers = {
    auto = require "scripts.snes.auto",
  }

  -- if no mapper provided, use default one (LoRom / HiRom auto detection)
  if console_opts.mapper == "" then
    console_opts.mapper = "auto"
  end

  local m = mappers[console_opts.mapper]
  if m == nil then
    log.error("UNSUPPORTED MAPPER: ", console_opts.mapper)
  else
    -- Attempt requested operations with hardware!
    -- TODO: Do plumbing for interacting with RAM.
    m.process(process_opts, snes_console_opts)
  end
end

--[[
 ██████╗ ██████╗         ██╗     ██████╗ ██████╗  ██████╗
██╔════╝ ██╔══██╗       ██╔╝    ██╔════╝ ██╔══██╗██╔════╝
██║  ███╗██████╔╝      ██╔╝     ██║  ███╗██████╔╝██║
██║   ██║██╔══██╗     ██╔╝      ██║   ██║██╔══██╗██║
╚██████╔╝██████╔╝    ██╔╝       ╚██████╔╝██████╔╝╚██████╗
 ╚═════╝ ╚═════╝     ╚═╝         ╚═════╝ ╚═════╝  ╚═════╝

--]]

-- Wrapper for managing original Gameboy operations.
local function gb_exec(process_opts, console_opts)
  local header

  -- if a rom write file is provided, parse its header
  if process_opts.rom_write_file ~= "" then
    -- parse file header
    log.section("Parsing ROM flash file header")
    log.bullet("Filename", process_opts.rom_write_file.filename)
    local gbFile = assert(io.open(process_opts.rom_write_file.filename, "rb"))
    if not gb.parse_header_file(gbFile) then
      log.warning("Failed to parse ROM flash file header")
    else
      log.success("ROM flash file header parsed successfully")
    end
    assert(gbFile:close())

    header = gb.file_header
  end

  -- if a rom dump file is provided, parse the cartridge ROM header
  if process_opts.rom_dump_file ~= "" then
    -- parse cartridge ROM header
    log.section("Parsing cartridge ROM header")
    if not gb.parse_header_rom() then
      log.warning("Failed to parse cartridge ROM header")
    else
      log.success("Cartridge ROM header parsed successfully")
    end

    header = gb.rom_header
  end

  if header ~= nil then
    -- control passed ROM size vs header data
    if console_opts.rom_size_kb < header:get_rom_size() then
      log.warning("Passed ROM size (" ..
        console_opts.rom_size_kb .. ") is LESS than header value (" .. header:get_rom_size() .. ")")
    elseif console_opts.rom_size_kb > header:get_rom_size() then
      log.warning("Passed ROM size (" ..
        console_opts.rom_size_kb .. ") is MORE than header value (" .. header:get_rom_size() .. ")")
    end

    -- display header mapper info
    local cart_type = header:get_cartridge_type_name()
    if (cart_type == nil) then
      log.warning("Cartridge type unknown", help.hex(header.cartridge_type, 2))
    else
      log.info("Cartridge type:", header:get_cartridge_type_name())
    end
  end

  -- Defensively filter out any console options that aren't standard.
  local gb_console_opts = {
    rom_size_kb  = console_opts.rom_size_kb,
    wram_size_kb = console_opts.wram_size_kb,
  }

  local mappers = {
    rom_only      = require "scripts.gb.rom_only",
    mbc1          = require "scripts.gb.mbc1",
    mbc5          = require "scripts.gb.mbc5",

    -- romonly       = require "scripts.gb.romonly",
    -- romonly_bs    = require "scripts.gb.romonly-bs",
    mbc1_discrete = require "scripts.gb.mbc1-discrete",
    -- test          = require "scripts.gb.gb-test",
    -- rnbw_32k      = require "scripts.gb.rnbw-32k",
    -- rnbw_mbc5     = require "scripts.gb.rnbw-mbc5",
  }
  local m = mappers[console_opts.mapper]
  if m == nil then
    log.error("UNSUPPORTED MAPPER: ", console_opts.mapper)
  else
    -- Attempt requested operations with hardware!
    m.process(process_opts, gb_console_opts)
  end
end

--[[
 ██████╗ ███████╗███╗   ██╗        ██╗    ███╗   ███╗██████╗
██╔════╝ ██╔════╝████╗  ██║       ██╔╝    ████╗ ████║██╔══██╗
██║  ███╗█████╗  ██╔██╗ ██║      ██╔╝     ██╔████╔██║██║  ██║
██║   ██║██╔══╝  ██║╚██╗██║     ██╔╝      ██║╚██╔╝██║██║  ██║
╚██████╔╝███████╗██║ ╚████║    ██╔╝       ██║ ╚═╝ ██║██████╔╝
 ╚═════╝ ╚══════╝╚═╝  ╚═══╝    ╚═╝        ╚═╝     ╚═╝╚═════╝

--]]

-- Wrapper for managing original Genesis/Megadrive operations.
local function genesis_exec(process_opts, console_opts)
  local header

  -- if a rom write file is provided, parse its header
  if process_opts.rom_write_file ~= "" then
    -- parse file header
    log.section("Parsing ROM flash file header")
    log.bullet("Filename", process_opts.rom_write_file.filename)
    local genFile = assert(io.open(process_opts.rom_write_file.filename, "rb"))
    if not genesis.parse_header_file(genFile) then
      log.warning("Failed to parse ROM flash file header")
    else
      log.success("ROM flash file header parsed successfully")
    end
    assert(genFile:close())

    header = genesis.file_header
  end

  -- if a rom dump file is provided, parse the cartridge ROM header
  if process_opts.rom_dump_file ~= "" then
    -- parse cartridge ROM header
    log.section("Parsing cartridge ROM header")
    if not genesis.parse_header_rom() then
      log.warning("Failed to parse cartridge ROM header")
    else
      log.success("Cartridge ROM header parsed successfully")
    end

    header = genesis.rom_header
  end

  if header ~= nil then
    -- control passed ROM size vs header data
    if console_opts.rom_size_kb < header:get_rom_size() then
      log.warning("Passed ROM size (" ..
        console_opts.rom_size_kb .. ") is LESS than header value (" .. header:get_rom_size() .. ")")
    elseif console_opts.rom_size_kb > header:get_rom_size() then
      log.warning("Passed ROM size (" ..
        console_opts.rom_size_kb .. ") is MORE than header value (" .. header:get_rom_size() .. ")")
    end
  end

  -- Defensively filter out any console options that aren't standard.
  local genesis_console_opts = {
    rom_size_kb  = console_opts.rom_size_kb,
    wram_size_kb = console_opts.wram_size_kb,
  }

  local mappers = {
    standard = require "scripts.genesis.32mb",
    -- ssf2      = require "scripts.genesis.ssf2",
    -- rainbow   = require "scripts.genesis.rainbow",
    -- test      = require "scripts.genesis.md-test",
  }

  -- if no mapper provided, use default one (32mb)
  if console_opts.mapper == "" then
    console_opts.mapper = "standard"
  end

  local m = mappers[console_opts.mapper]
  if m == nil then
    log.error("UNSUPPORTED MAPPER: ", console_opts.mapper)
  else
    -- Attempt requested operations with hardware!
    m.process(process_opts, genesis_console_opts)
  end
end

--[[
███╗   ██╗███████╗███████╗        ██╗    ███████╗ ██████╗
████╗  ██║██╔════╝██╔════╝       ██╔╝    ██╔════╝██╔════╝
██╔██╗ ██║█████╗  ███████╗      ██╔╝     █████╗  ██║
██║╚██╗██║██╔══╝  ╚════██║     ██╔╝      ██╔══╝  ██║
██║ ╚████║███████╗███████║    ██╔╝       ██║     ╚██████╗
╚═╝  ╚═══╝╚══════╝╚══════╝    ╚═╝        ╚═╝      ╚═════╝

--]]

-- Wrapper for managing NES/Famicom operations.
local function nes_exec(process_opts, console_opts)
  -- if nes file to flash ...
  if process_opts.rom_write_file.ext == "nes" then
    -- parse header
    process_opts.nes_file = process_opts.rom_write_file
    log.section("Parsing NES flash file header")
    log.bullet("Filename", process_opts.nes_file.filename)
    local nesfile = assert(io.open(process_opts.nes_file.filename, "rb"))
    if not nes.parse_header(nesfile) then
      log.error("Failed to parse NES flash file header")
    else
      log.success("NES flash file header parsed successfully")

      -- convert nes file to bin file with padding if needed
      log.section("Creating binary file to be flashed")

      local binfile
      local prgNesRomSizeKb = math.floor(nes.header.prgRomSize / 1024)
      local chrNesRomSizeKb = math.floor(nes.header.chrRomSize / 1024)
      -- local mult = 0
      local bytesToCopy = 0
      local flash_file_bin = process_opts.rom_write_file.path ..
          process_opts.rom_write_file.base .. "-" .. process_opts.retroprog_id .. ".bin"

      process_opts.rom_write_file = help.parse_filename(flash_file_bin)

      log.bullet(flash_file_bin)
      if help.file_exists(flash_file_bin) and process_opts.additional_opts.no_bin_regen then
        log.warning("Binary file already exists")
        log.warning("Please delete it if you want it to be regenerated")
        log.warning("Or remove 'no_bin_regen' option")
      else
        binfile = assert(io.open(flash_file_bin, "w+b"))

        -- copy PRG data if needed
        if prgNesRomSizeKb > console_opts.prg_rom_size_kb then
          log.warning("Provided PRG-ROM size (" ..
            console_opts.prg_rom_size_kb .. "kB) is smaller than header PRG-ROM size (" .. prgNesRomSizeKb .. "kB)")
        elseif console_opts.prg_rom_size_kb ~= 0 and prgNesRomSizeKb == 0 then
          log.warning("Header PRG-ROM size is zero")
        end
        if console_opts.prg_rom_size_kb ~= 0 and prgNesRomSizeKb ~= 0 then
          bytesToCopy = console_opts.prg_rom_size_kb * 1024
          nesfile:seek("set", 16)
          for j = 1, bytesToCopy, 1 do
            binfile:write(nesfile:read(1))
            if (j % nes.header.prgRomSize == 0) then nesfile:seek("set", 16) end
          end

          -- mult = console_opts.prg_rom_size_kb / prgNesRomSizeKb
          -- for i = 1, mult, 1 do
          --   nesfile:seek("set", 16)
          --   for j = 1, prgNesRomSizeKb * 1024, 1 do
          --     binfile:write(nesfile:read(1))
          --   end
          -- end
        end

        -- copy CHR data if needed
        if chrNesRomSizeKb > console_opts.chr_rom_size_kb then
          log.warning("Provided CHR-ROM size (" ..
            console_opts.chr_rom_size_kb .. "kB) is smaller than header CHR-ROM size (" .. chrNesRomSizeKb .. "kB)")
        elseif console_opts.chr_rom_size_kb ~= 0 and chrNesRomSizeKb == 0 then
          log.warning("Header CHR-ROM size is zero")
        end
        if console_opts.chr_rom_size_kb ~= 0 and chrNesRomSizeKb ~= 0 then
          bytesToCopy = console_opts.chr_rom_size_kb * 1024
          nesfile:seek("set", 16 + nes.header.prgRomSize)
          for j = 1, bytesToCopy, 1 do
            binfile:write(nesfile:read(1))
            if (j % nes.header.chrRomSize == 0) then nesfile:seek("set", 16 + nes.header.prgRomSize) end
          end

          -- mult = console_opts.chr_rom_size_kb / chrNesRomSizeKb
          -- for i = 1, mult, 1 do
          --   nesfile:seek("set", 16 + prgNesRomSizeKb * 1024)
          --   for j = 1, chrNesRomSizeKb * 1024, 1 do
          --     binfile:write(nesfile:read(1))
          --   end
          -- end
        end

        if nesfile then assert(nesfile:close()) end
        if binfile then assert(binfile:close()) end

        log.success("Binary file successfully created")
      end
    end
  end

  -- flash CIC here to avoid having this piece of code in every mapper scripts
  if process_opts.additional_opts.flash_cic then
    if nes.cic:flash() ~= true then
      return false
    end
  end

  -- Defensively filter out any console options that are irrelevant to NES support.
  -- This will matter more when software support exists for other consoles.

  local nes_console_opts = {
    wram_size_kb    = console_opts.wram_size_kb,
    prg_rom_size_kb = console_opts.prg_rom_size_kb,
    chr_rom_size_kb = console_opts.chr_rom_size_kb,
  }

  local mappers = {
    -- bs_action53_tsop  = require "scripts.nes.bs_action53_tsop",
    -- action53_tsop     = require "scripts.nes.action53_tsop",
    action53       = require "scripts.nes.action53",
    bnrom          = require "scripts.nes.bnrom",
    -- cdream            = require "scripts.nes.cdream",
    -- cninja            = require "scripts.nes.cninja",
    -- cnrom             = require "scripts.nes.cnrom",
    -- dualport          = require "scripts.nes.dualport",
    -- easynsf           = require "scripts.nes.easyNSF",
    nsf_512        = require "scripts.nes.nsf_512",
    fme7           = require "scripts.nes.fme7",
    jaleco_ss88006 = require "scripts.nes.jaleco_ss88006",
    mapper30       = require "scripts.nes.mapper30",
    mmc1           = require "scripts.nes.mmc1",
    mmc2           = require "scripts.nes.mmc2",
    mmc3           = require "scripts.nes.mmc3",
    mmc4           = require "scripts.nes.mmc4",
    mmc5           = require "scripts.nes.mmc5",
    nrom           = require "scripts.nes.nrom",
    rainbow        = require "scripts.nes.rainbow",
    unrom          = require "scripts.nes.unrom",
    gtrom          = require "scripts.nes.gtrom",
    -- vrc2a             = require "scripts.nes.vrc2a",
    vrc6a          = require "scripts.nes.vrc6a",
    -- rnbw_vrc6a        = require "scripts.nes.rnbw_vrc6a",
    -- vrc6b             = require "scripts.nes.vrc6b",
  }

  local m = mappers[console_opts.mapper]
  if m == nil then
    log.error("UNSUPPORTED MAPPER: ", console_opts.mapper)
  else
    -- Attempt requested operations with hardware!
    m.process(process_opts, nes_console_opts)
  end
end

--[[
███╗   ███╗ █████╗ ██╗███╗   ██╗
████╗ ████║██╔══██╗██║████╗  ██║
██╔████╔██║███████║██║██╔██╗ ██║
██║╚██╔╝██║██╔══██║██║██║╚██╗██║
██║ ╚═╝ ██║██║  ██║██║██║ ╚████║
╚═╝     ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝

--]]

-- Point of entry from C language half of program.
local function main()
  -- Global options passed in from C:
  --  retroprog_id:         string, Retro Prog ID.
  --  console_name:         string, name of console.
  --  mapper_name:          string, name of mapper.
  --  rom_dump_file:        string, filename used for writing dumped data.
  --  rom_write_file:       string, filename containing data to write cartridge.
  --  do_verify:            bool, 0: don't verify data flashed, anything else: verify data flashed.
  --  ram_dump_file:        string, filename used for writing dumped ram data.
  --  ram_write_file:       string, filename containing data to write to ram on cartridge.
  --  nes_prg_rom_size_kb:  int, size of cartridge PRG-ROM in kilobytes.
  --  nes_chr_rom_size_kb:  int, size of cartridge CHR-ROM in kilobytes.
  --  nes_wram_size_kb:     int, size of cartridge WRAM in kilobytes.
  --  rom_size_kb:          int, size of cartridge ROM in kilobytes.
  --  additional_opts:      string, additional options (ex: for NES, bank table address for BxROM mapper).
  --  lua_path:             string, needed for macOS app package.

  -- check if options has been passed
  if (opts == nil) then
    log.error("options table not found...")
    do return end
  end

  -- TODO: This should probably be one level up.
  -- TODO: Ram probably needs a verify file as well?

  -- Print application version of the firmware for debug/support
  -- Should work on all hardware versions
  local dict = require "scripts.app.dict"
  local appver = help.hex(dict.bootload("GET_APP_VER", nil, nil, nil, true))
  log.info("firmware app ver request:", appver)
  if appver < "3" then
    log.warning("firmware is out of date, recommend updating")
  end

  --    this method only works for STM32 based devices and reads version from flash address 0x0800-0800
  --    local fwupdate = require "scripts.app.fwupdate"
  --    local appver = fwupdate.get_fw_appver(true)
  --    if appver ~= "AV03" then
  --      print("new firmware has been released, recommend upgrading")
  --    end

  -- Always test!
  local do_test = true

  -- If a dump filename was provided, dump data from cartridge to a file.
  local do_rom_dump = not isempty(opts.rom_dump_file)

  -- If a flash filename was provided, write its contents to the cartridge.
  -- TODO: Check for program and dump at same time, not permitted.
  -- TODO: Check for erase + dump at same time, not permitted.
  local do_rom_write = not isempty(opts.rom_write_file)

  -- If writing, always erase.
  local do_erase = do_rom_write

  -- If the verify flag was provided, dump data from cartridge after flash to a file and compare it to flashed file.
  local do_verify = do_rom_write and opts.verify

  local do_ram_dump = not isempty(opts.ram_dump_file)
  local do_ram_write = not isempty(opts.ram_write_file)

  -- split filenames to get basename and extension
  if opts.rom_dump_file ~= "" then opts.rom_dump_file = help.parse_filename(opts.rom_dump_file) end
  if opts.rom_write_file ~= "" then opts.rom_write_file = help.parse_filename(opts.rom_write_file) end
  if opts.ram_dump_file ~= "" then opts.ram_dump_file = help.parse_filename(opts.ram_dump_file) end
  if opts.ram_write_file ~= "" then opts.ram_write_file = help.parse_filename(opts.ram_write_file) end

  -- prepare verify file if needed
  if do_verify then
    local verify_ext = opts.rom_write_file.ext
    if opts.rom_write_file.ext == "nes" then verify_ext = "bin" end
    local verify_file = opts.rom_write_file.path ..
        opts.rom_write_file.base .. "-verify-" .. opts.retroprog_id .. "." .. verify_ext
    opts.verify_file = help.parse_filename(verify_file)
  end

  -- Pack main process state into table.
  local process_opts = {
    retroprog_id   = opts.retroprog_id,
    -- console_name    = opts.console_name,
    debug          = opts.debug,
    do_test        = do_test,
    do_erase       = do_erase,
    do_rom_dump    = do_rom_dump,
    do_rom_write   = do_rom_write,
    do_verify      = do_verify,
    do_ram_dump    = do_ram_dump,
    do_ram_write   = do_ram_write,
    rom_dump_file  = opts.rom_dump_file,
    rom_write_file = opts.rom_write_file,
    ram_dump_file  = opts.ram_dump_file,
    ram_write_file = opts.ram_write_file,
    verify_file    = opts.verify_file,
    path           = opts.lua_path,
  }

  -- parse additional options
  local success, options, error = help.parse_additional_opts(opts.additional_opts)
  if not success then
    log.error(error)
    do return end
  end
  process_opts.additional_opts = options

  local consoles = {
    -- Nintendo Game Boy
    dmg       = gb_exec,
    gb        = gb_exec,
    gba       = default_exec,

    -- SEGA MegaDrive / SEGA Genesis
    genesis   = genesis_exec,
    gen       = genesis_exec,
    megadrive = genesis_exec,
    md        = genesis_exec,

    -- Nintendo 64
    n64       = n64_exec, --default_exec,

    -- Nintendo Entertainment System / Nintendo Family Computer
    nes       = nes_exec,
    famicom   = nes_exec,
    fc        = nes_exec,

    -- Super Nintendo Entertainment System
    snes      = snes_exec,
    sfc       = snes_exec,
  }

  -- local console_scripts = {
  --   -- Nintendo Game Boy Advance
  --   gba       = require "scripts.gba.basic",

  --   -- SEGA MegaDrive / SEGA Genesis
  --   genesis   = require "scripts.app.genesis",
  --   gen       = require "scripts.app.genesis",
  --   megadrive = require "scripts.app.genesis",
  --   md        = require "scripts.app.genesis",

  --   -- Nintendo 64
  --   n64 = require "scripts.n64.basic",

  --   -- Nintendo Entertainment System / Nintendo Family Computer
  --   nes       = require "scripts.app.nes",
  --   famicom   = require "scripts.app.nes",
  --   fc        = require "scripts.app.nes",

  --   -- Super Nintendo Entertainment System
  --   snes  = require "scripts.snes.v2proto_hirom",
  --   sfc   = require "scripts.snes.v2proto_hirom",
  --   -- snes = require "scripts.snes.v2manual_hirom",
  -- }

  local console_exec = consoles[opts.console_name]
  -- local console_process_script = console_scripts[opts.console_name]
  if console_exec == nil then
    log.error("UNSUPPORTED CONSOLE: ", opts.console_name)
  else
    local console_opts = {
      wram_size_kb    = opts.nes_wram_size_kb,
      prg_rom_size_kb = opts.nes_prg_rom_size_kb,
      chr_rom_size_kb = opts.nes_chr_rom_size_kb,
      rom_size_kb     = opts.rom_size_kb,
      -- console_process_script  = opts.console_process_script,
      mapper          = opts.mapper_name,
    }
    return console_exec(process_opts, console_opts)
  end
end

-- Don't do this. Next iteration will call a function, not the whole script.
return main()
