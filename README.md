# INLretro Programmer-Dumper (CLI + GUI)

This project is based on the original [INLretro programmer-dumper](https://gitlab.com/InfiniteNesLives/INL-retro-progdump) by InfiniteNesLives.

It provides both a command-line interface (CLI) and a graphical user interface (GUI) for interacting with INLretro hardware programmers/dumpers.

**If you already own an INLretro programmer-dumper and want to switch to this CLI/GUI solution, please read the _IMPORTANT NOTE_ below.**

[![build](https://github.com/BrokeStudio/INLretro/actions/workflows/build.yml/badge.svg)](https://github.com/BrokeStudio/INLretro/actions/workflows/build.yml)
![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-blue)

---

## Features

- CLI version: command-line tool.
- GUI version: user friendly tool.
- Works on Windows, Linux, and macOS.
- Build system using Premake for simple multi-platform setup.
- Supports multiple flashers.

---

## Console/mapper support

| System           | Mapper         | ROM dump | ROM write | RAM dump | RAM write |
| ---------------- | -------------- | -------- | --------- | -------- | --------- |
| NES / FC         | 0 - NROM       | ✓        | ✓         | ✓        | ✓         |
|                  | 1 - MMC1       | ✓        | ✓         | ✓        | ✓         |
|                  | 2 - UxROM      | ✓        | ✓         | ✓        | ✓         |
|                  | 3 - CxROM      | ✓        | ✓         | ✓        | ✓         |
|                  | 4 - MMC3       | ✓        | ✓         | ✓        | ✓         |
|                  | 18 - SS880066  | ✓        | ✓         | ✓        | ✓         |
|                  | 24 - VRC6a     | ✓        | ✓         | ✓        | ✓         |
|                  | 28 - Action 53 | ✓        | ✓         | ✓        | ✓         |
|                  | 30 - UNROM-512 | ✓        | ✓         | ✓        | ✓         |
|                  | 34 - BNROM     | ✓        | ✓         | ✓        | ✓         |
|                  | 111 - GTROM    | ✓        | ✓         | ✓        | ✓         |
|                  | 682 - Rainbow  | ✓        | ✓         | ✓        | ✓         |
|                  |                |          |           |          |           |
| Game Boy (Color) | 32KB           | ✓        | ✓         | ✓        | ✓         |
|                  | MBC1           | ✓        | ✓         | ✓        | ✓         |
|                  | MBC5           | ✓        | ✓         | ✓        | ✓         |
|                  |                |          |           |          |           |
| Genesis / MD     | 32Mb (+SRAM)   | ✓        | ✓         | ✓        | ✓         |
|                  |                |          |           |          |           |
| SNES / SFC       | LoRom / HiRom  | ✓        | ✖         | ✖        | ✖         |
|                  |                |          |           |          |           |
| N64              |                | ✓        | ✖         | ✖        | ✖         |

I'll try to add support to more mapper in the future but feel free to let me know if you have specific needs.

---

## Important note

If you own an INLretro programmer-dumper and want to use this CLI/GUI solution, please follow these steps:

- If you're on Windows you need to install the new driver:
  - Go to the `Windows/WinUSB_driver/` folder
  - Right click on the `.inf` file and then click on `Install`
- You need to update the flasher's firmware so it's compatible with the CLI/GUI
  - Using the CLI: run the command `INLretro -s scripts/inlretro_fwupdate.lua`
  - Using the GUI:
    - Go to the `Flashers` menu
    - Make sure your flasher is plugged in
    - Refresh the list if you can't find your flasher in the list
    - Click on `Update firmware`

---

## Credits

Developed by Antoine GOHIN / Broke Studio.

This project is based on:

- [INLretro prog-dump](https://gitlab.com/InfiniteNesLives/INL-retro-progdump) by InfiniteNesLives

This project uses:

- [libusb](https://libusb.info/)
- [SDL2](https://www.libsdl.org/)
- [Dear ImGui](https://github.com/ocornut/imgui)
- [Premake](https://premake.github.io/)

---

## Compiling

See [COMPILING.md](COMPILING.md)

## License

INLretro CLI/GUI is available under the GPL V3 license. Full text here: http://www.gnu.org/licenses/gpl-3.0.en.html

Copyright (C) 2024-2025 Broke Studio

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

## Contact

You can join Broke Studio's Discord server https://discord.gg/FffVMAuhTX.
