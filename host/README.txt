INLretro Programmer-Dumper - Quick Start Guide
================================================

INLretro provides a graphical application (INLretroGUI) and, where
included, a command-line application (INLretro) for dumping cartridges,
programming compatible flash cartridges, and backing up or restoring save
data.

Project page and current compatibility list:
https://github.com/BrokeStudio/INLretro


1. BEFORE FIRST USE
-------------------

Windows:
  1. Open the DriverPackages folder supplied with this release.
  2. Run InstallDriver.exe.

All platforms:
  The programmer must run firmware compatible with this software. If the GUI
  reports that its firmware is incompatible, open the Flashers menu, locate
  the connected programmer, and select Update firmware. Choose the correct
  model when prompted:

  - 6-connector flasher
  - NESmaker flasher

  Firmware can also be updated with the CLI:

  6-connector flasher:
    INLretro -s scripts/inlretro_fwupdate.lua -p firmware/inlretro_stm6.bin

  NESmaker flasher:
    INLretro -s scripts/inlretro_fwupdate.lua -p firmware/inlretro_stmn.bin


2. USING THE GUI
----------------

  1. Connect the INLretro programmer and insert the cartridge.
  2. Start INLretroGUI.
  3. Open the menu for the cartridge system.
  4. Select Dump ROM, Write ROM, Dump RAM, or Write RAM.
  5. Select the mapper and sizes when they cannot be detected automatically.
  6. Select the input or output file, then click the action button.

Use the Flashers menu to refresh the device list, select a programmer, or
update its firmware. When multiple programmers are connected, the GUI can
run an operation on all of them or on an individual device.

Writing ROM requires a compatible flash cartridge or development board.
Writing RAM replaces the save data stored on the cartridge. Back up important
save data before writing, and check the selected system, mapper, sizes, and
file carefully.


3. USING THE CLI
----------------

Run the following command for the complete list of arguments:

  INLretro --help

Common arguments:

  -c, --console                 Cartridge system
  -m, --mapper                  Mapper or cartridge type
  -d, --rom_dump_file           ROM dump destination
  -p, --rom_write_file          ROM file to program
  -a, --ram_dump_file           RAM/save dump destination
  -b, --ram_write_file          RAM/save file to restore
  -v, --verify                  Verify the ROM after programming
  -x, --nes_prg_rom_size_kbyte  NES PRG-ROM size in kilobytes
  -y, --nes_chr_rom_size_kbyte  NES CHR-ROM size in kilobytes
  -w, --wram_size_kbyte         NES cartridge RAM size in kilobytes
  -k, --rom_size_kbyte          ROM size for non-NES systems, in kilobytes
  -z, --rom_size_mbit           ROM size for non-NES systems, in megabits
  -o, --additional_opts         Comma-separated advanced options
  -i, --retroprog_id            Select a specific programmer
  -g, --debug                   Display additional diagnostic information

Examples:

  Dump a 256 KB NES MMC3 PRG-ROM and an 8 KB CHR-ROM:
    INLretro -c nes -m mmc3 -x 256 -y 8 -d game.nes

  Program the same cartridge and verify the result:
    INLretro -c nes -m mmc3 -x 256 -y 8 -p game.nes -v

  Back up 8 KB of NES cartridge RAM:
    INLretro -c nes -m mmc3 -w 8 -a save.sav

Quote file names that contain spaces.


4. ADDITIONAL OPTIONS
---------------------

Pass additional options as a comma-separated list with no spaces. Options
that take a value use key=value syntax. Boolean options can be enabled by
writing only their name.

Example:
  INLretro -c nes -m unrom -x 256 -y 0 -d game.nes -o bank_table=0x8000,force_flash_test

Available common options:

  bank_table=<address>
    Sets the bank-table address used to handle bus conflicts with NES mappers
    such as BNROM and UNROM. Accepts decimal or hexadecimal addresses.

  force_ram_test
    Forces cartridge RAM tests (SRAM/WRAM/PRG-RAM), including when the ROM
    header indicates battery-backed data or a raw binary file is used.

  force_flash_test
    Forces ROM-chip identification even when no data is being programmed.

  no_bin_regen
    Reuses an existing generated binary instead of regenerating it before a
    write operation. Remove this option or delete the generated file when a
    new binary must be created.

  flash_cic
    NES only. Attempts to program an ATtiny13A CIC chip whose pin 1 is tied to
    EXP5 (pin 55 of the NES connector). Reprogramming can fail depending on
    the fuse settings used during the first programming.


5. TROUBLESHOOTING
------------------

Programmer not detected:
  - Check the USB cable and reconnect the programmer.
  - On Windows, install the driver supplied in DriverPackages.
  - In the GUI, open Flashers and refresh the device list.
  - Close other software that may already be using the programmer.

Programmer reported as incompatible:
  - Update its firmware from the Flashers menu or with the CLI commands in
    section 1.
  - Make sure the firmware matches the programmer model.

Dump or write operation fails:
  - Confirm the cartridge system, mapper, memory sizes, and file selection.
  - Clean the cartridge connector and reseat the cartridge.
  - Retry with debug logging enabled and keep the complete error output.


6. SUPPORT AND LICENSE
----------------------

Report bugs and request mapper or system support at:
https://github.com/BrokeStudio/INLretro/issues

Include the operating system, application version, programmer model, firmware
version, cartridge and mapper, operation performed, and complete error output.

Community support:
https://discord.gg/FffVMAuhTX

INLretro is based on the original INLretro programmer-dumper created by
Paul Molloy of Infinite NES Lives:
https://gitlab.com/InfiniteNesLives/INL-retro-progdump

INLretro CLI/GUI is distributed under the GNU General Public License,
version 3 or later.

Copyright (C) 2024-2026 Broke Studio
