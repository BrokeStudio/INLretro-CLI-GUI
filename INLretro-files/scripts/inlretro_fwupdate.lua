-- main script that runs application logic and flow

-- initial function called from C main
function main ()

  local fwupdate = require "scripts.app.fwupdate"

  --Firmware update without bootloader
  --fwupdate.get_fw_appver(true)

  --active development path (based on makefile in use)
  --fwupdate.update_firmware("../firmware/build_stm/inlretro_stm.bin", 0x6DC, false) --INL6 skip ram pointer
  --fwupdate.update_firmware("../firmware/build_stm/inlretro_stm.bin", 0x6E8, false) --INL_NES skip ram pointer
  fwupdate.update_firmware("firmware/inlretro_stm.bin", nil, true ) --Know what I'm doing? force the update

end

main ()
