## Build Instructions

This project uses a Core/App project architecture. There are three included projects - one called _Core_, one called _CLI_ and one called _GUI_. [Premake](https://github.com/premake/premake-core) is used to generate project files.

- Core builds into a static library and contains the main code to interact with the flasher.
- CLI builds into an executable and links the Core static library. It provides a way to interact with the flasher using command-line commands.
- GUI builds into an executable and links the Core static library. It provides a way to interact with the flasher using a graphical user interface.

The `Scripts/` directory contains build scripts for Windows and Linux, and the `Vendor/` directory contains Premake binaries (currently version `5.0-beta2`).

## Project Structure

```bash
.
├── Core/                   # Core source code
├── CLI/                    # Command-line tool source code
├── GUI/                    # Graphical user interface source code
├── INLretro-files/         # Files that are copied to build folder
│   ├── firmware/           # Firmware binaries
│   ├── ignore/             # Work folder, contains a pre-filled lfsr file (32KB)
│   ├── scripts/            # Lua scripts
│   ├── shared/             # Shared header files
│   ├── INLretro.ini        # GUI settings
├── External/               # Libraries: SDL2, libusb, imgui
├── macOS/                  # macOS specific files
├── Windows/                # Windows specific files
│   ├── WinUSB_driver/      # Windows USB driver
├── Vendor/                 # Premake and build tools
├── Build.lua               # Build configuration
└── README.md
```

## Windows

1. Open the solution in Visual Studio 2022
2. Compile as `Dist`/`x64` or `Dist`/`Win32` (you can also compile as `Debug` or `Release`)
3. Build the solution to build both the CLI and the GUI or set the startup project to `GUI` and run

For Windows, _SDL2_ and _libusb_ pre-compiled libraries are included in `External/` folder.

## Linux

To build under Linux you need a version of Clang or GCC that supports C++17.
Additionally, SDL2 and libusb must also be installed.
Once SDL2 and libusb are installed, run `make config=release` to compile with Clang.
`config` can be set to `debug`, `release` or `dist` depending on what you want to do.

## macOS

To build under macOS, install SDL2 and libusb (i.e via Homebrew).
Once SDL2 and libusb are installed, run `make config=release`.
`config` can be set to `debug`, `release` or `dist` depending on what you want to do.
On macOS, `make config=dist` will build `.app` packaged application for the GUI.
