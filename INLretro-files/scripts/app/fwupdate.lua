
-- create the module's table
local fwupdate = {}

-- import required modules
local dict  = require "scripts.app.dict"
local help  = require "scripts.app.help"
local log   = require "scripts.app.log"

-- file constants and global variables

-- local functions

local function erase_main()

  --dict.fwupdate("ERASE_1KB_PAGE", 2)	--page 0 & 1 (first 2KByte) are forbidden
  --dict.fwupdate("ERASE_1KB_PAGE", 3)	--this is redundant for RB (aligns C6 to RB when done with above)
  --dict.fwupdate("ERASE_1KB_PAGE", 4)	--0x0800_1000 - 0x0800_17FF
  --dict.fwupdate("ERASE_1KB_PAGE", 5)	--redundant RB
  --dict.fwupdate("ERASE_1KB_PAGE", 6)	--0x0800_1800 - 0x0800_1FFF
  --dict.fwupdate("ERASE_1KB_PAGE", 7)
  --dict.fwupdate("ERASE_1KB_PAGE", 8)	--0x0800_2000 - 0x0800_27FF
  --dict.fwupdate("ERASE_1KB_PAGE", 9)

  log.section("Erasing device main application flash..")

  local curpage = 2	--skip the first pages
  local rv = dict.fwupdate("GET_FLASH_ADDR")
  log.info("flash addr:", string.format("%X", rv) )

  while curpage < 32 do
--	while (curpage<128) do	--RB has 128KB but last 96KB isn't used (yet)
    if curpage % 4 ==0 then
      log.point("erasing page:", curpage)
    end
    dict.fwupdate("ERASE_1KB_PAGE", curpage)

    --rv = dict.fwupdate("GET_FLASH_ADDR")
    --log.info("flash addr:", string.format("%X", rv) )

    curpage = curpage + 1
  end

end

local function get_fw_appver(printit)

  dict.bootload("SET_PTR_HI", 0x0800)
  dict.bootload("SET_PTR_LO", 0x0800) --application version 0x08000800 "AV00"
  local av = dict.bootload("RD_PTR_OFFSET")
  local ver = dict.bootload("RD_PTR_OFFSET",1)
  local avstring = string.format(
                      "%s%s%s%s",
                      string.char(av & 0x00FF),
                      string.char(av >> 8),
                      string.char(ver & 0x00FF),
                      string.char(ver >> 8)
                    )

  if printit then
    log.info("device firmware app ver:", avstring)
  end

  return avstring

end

--skip is used because there is a ram pointer that often varies between builds
--we're never going back to main so this mismatch is allowed
local function update_firmware(newbuild, skip, forceup)

  local error = false

  --open new file first, don't bother continuing if can't find it.
  local file = assert(io.open(newbuild, "rb"))

  --TODO REPORT build time stamp so can be certain it was a build just made if desired

  --TODO read the fwupdater & app version from the provided file
  --compare to current device and determine if they're compatible
  -- log.info("current firmware prior to update:")
  local avstring = get_fw_appver(true)

  -- if avstring == nil then
  --   avstring = help.hex(dict.bootload("GET_APP_VER", nil, nil, nil, true))
  -- end

  if string.sub(avstring, 1, 2) ~= "AV" then
    log.info("current firmware is not versioned, may need to update to firmware v2.3 or later using STmicro dfuse")
    log.info("may be running nightly build in which case can probably ignore")
  else
    log.info("current firmware", avstring, "expected to support USB update process")
  end

  --verify the first 2KByte match, don't continue if not..
  --use the bootload dictionary to complete this
  --want to wait to enter firmware updater

  --set bootloader 16bit pointer to start of flash
  dict.bootload("SET_PTR_HI", 0x0800)
  dict.bootload("SET_PTR_LO", 0x0000)
  local offset = 0 --first read has no offset

  --advance the file past first 2KByte
  local buffsize = 1
  local byte, data
  local byte_num = 0
  local readdata
  local data_l

  log.section("Verifying first 2KByte of updater...")
  while byte_num < (2 * 1024) do

    --read next byte from the file and convert to binary
    --gotta be a better way to read a half word (16bits) at a time but don't care right now...
    local byte_str = file:read(buffsize)
    if byte_str then
      data_l = string.unpack("B", byte_str, 1)
    else
      --should only have to make this check for lower byte
      --binary file should be even
      log.info("There's a problem, file provided is smaller than 2KB fwupdater..")
      --TODO test this
      error = true
      break
    end
    byte_str = file:read(buffsize)
    data = string.unpack("B", byte_str, 1)
    data = (data << 8) + data_l

    if true then
      --both these options work, but the later is limited to reading 64KByte space
      readdata = dict.bootload("RD_PTR_OFF_UP", offset)
      --readdata = dict.bootload("RD_PTR_OFFSET", byte_num>>1) --shift by one 16bit read

      --log.info("read data:", string.format("%X", readdata) )
      if readdata ~= data then
        log.warning("Unable to verify byte number", help.hex(byte_num),
          " to flash expected:", help.hex(data), "was:", help.hex(readdata))
        if forceup then
          log.info("continuing anyway because force update was set...")
        elseif byte_num == skip then
          log.info("there was an expected mismatch at byte:", help.hex(byte_num))
        else
          log.error("PROBLEM! with firmware updater verification exiting")
          log.error("exiting because it's not safe to proceed...")
          log.error("no changes to device flash were made")
          error = true
          break
        end
      --else
      --	log.info("verified byte number", help.hex(byte_num),
      --		" of flash ", help.hex(data), help.hex(readdata))
      end
    end

    offset = 1 --this is zero for first byte, but one for all others..
    byte_num = byte_num + 2
  end

  if not error then
    log.success("Successfully verified first 2KB of provided file matches the device's firmware updater section")
  end

  --enter fwupdate mode
  dict.bootload("PREP_FWUPDATE")

  --now the device will only respond to FWUPDATE dictionary commands

  --erase 30KByte of application code
  if not error then
    erase_main()
  end

  --Set FLASH->AR to beginging of application section
  --this can be done be re-erasing it..
  --maybe we could have skipped page 2 in erase_main
  --or have erase_main count down..
  if not error then
    dict.fwupdate("ERASE_1KB_PAGE", 2)
    log.info("flash addr:", help.hex(dict.fwupdate("GET_FLASH_ADDR")))
  end

  offset = 0 --first write has no offset

  if not error then
    log.section("Updating device main application flash..")
    while byte_num < (32 * 1024) do

      --read next byte from the file and convert to binary
      --gotta be a better way to read a half word (16bits) at a time but don't care right now...
      local byte_str = file:read(buffsize)
      if byte_str then
        data_l = string.unpack("B", byte_str, 1)
      else
        --should only have to make this check for lower byte
        --binary file should be even
        log.info("end of file")
        break
      end
      byte_str = file:read(buffsize)
      data = string.unpack("B", byte_str, 1)
      data = (data << 8) + data_l

      if ( byte_num % ( 4 * 1024 ) ) == 0 then
        log.point("flashing KB", math.floor(byte_num / 1024))
      end

      --log.info("writing:", string.format("%X", data), "addr:", string.format("%X", byte_num))

      --write the data
      dict.fwupdate("WR_HWORD", data, offset)

      if true then
        readdata = dict.fwupdate("READ_FLASH", byte_num, 0x00)
      --	log.info("read data:", string.format("%X", readdata) )
        if readdata ~= data then
          log.error("ERROR!!!! flashing byte number", help.hex(byte_num),
            " to flash expected:", help.hex(data), "was:", help.hex(readdata))
          log.error("exiting before causing more damage...")
          error = true
          break
        --else
        --	log.info("verified byte number", help.hex(byte_num),
        --		" to flash ", help.hex(data), help.hex(readdata))
        end
      end

      offset = 1 --this is zero for first write, but one for all others..
      byte_num = byte_num + 2
    end
  end

  if not error then
    log.success("Successfully updated the device firmware!")
  end

  -- close file
  assert(file:close())

  log.section("Reseting device")
  log.warning("IGNORE the errors that comes next...")

  if(opts.gui) then
    log.warning("You should refresh the flasher list after a firmware update.")
  end

  --TODO maybe don't reset if we got an error, allow for correction while fwupdate still has control..?
  dict.fwupdate("RESET_DEVICE")

  --write build to flash

  log.info("updated")	--this doesn't print because reset errored us out..
end

-- global variables so other modules can use them

-- call functions desired to run when script is called/imported

-- functions other modules are able to call
fwupdate.update_firmware = update_firmware
fwupdate.get_fw_appver = get_fw_appver

-- return the module's table
return fwupdate
