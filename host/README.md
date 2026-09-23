# INLretro host software

This directory contains the desktop software for the INLretro programmer-dumper: a command-line interface (CLI), a graphical user interface (GUI), and their shared core library.

For supported systems and mappers, screenshots, firmware update instructions, and troubleshooting, see the [main project README](../README.md).

## Architecture

The host software is split into three projects:

| Project | Purpose                                                                | Output                   |
| ------- | ---------------------------------------------------------------------- | ------------------------ |
| `Core`  | Shared code for communicating with INLretro hardware.                  | Static library           |
| `CLI`   | Command-line interface, linked against `Core`.                         | `INLretro` executable    |
| `GUI`   | Graphical interface, linked against `Core`, using SDL2 and Dear ImGui. | `INLretroGUI` executable |

Lua scripts in `INLretro-files/scripts/` implement cartridge operations and firmware updates.

## Directory layout

```text
host/
├── Core/                 # Shared host library
├── CLI/                  # Command-line application
├── GUI/                  # Graphical application and UI assets
├── INLretro-files/       # Runtime files copied into build outputs
│   ├── scripts/          # Lua scripts for systems, mappers, and operations
│   └── INLretro.ini      # Default application settings
├── External/             # Third-party dependencies
├── drivers/              # Device drivers included with host distributions
├── Scripts/              # Platform-specific project generation scripts
├── Vendor/               # Build tools, including Premake
├── Windows/              # Windows-specific files
├── macOS/                # macOS-specific files and app resources
├── tests/                # Automated checks
├── Build.lua             # Premake workspace configuration
└── COMPILING.md          # Build instructions
```

Related directories at the repository root:

- [`firmware/`](../firmware/README.md): firmware source and Makefiles, built directly from that directory; see the [firmware build guide](../firmware/COMPILING.md).
- [`shared/`](../shared/): protocol definitions shared by the host software and firmware.

## Building

See [COMPILING.md](COMPILING.md) for platform-specific prerequisites and build instructions.

[Build.lua](Build.lua) defines the Premake workspace and includes the build configuration for each project. Available configurations are `Debug`, `Release`, and `Dist`. Generated binaries are placed under `Binaries/`.

The CI workflows also document the automated build and packaging process:

- [Host build](../.github/workflows/build-host.yml)
- [Firmware build](../.github/workflows/build-firmware.yml)
- [Build and release pipeline](../.github/workflows/pipeline.yml)

## Additional options

The CLI accepts mapper and operation-specific options through `-o` or `--additional_opts`. The GUI exposes the same options in its **Additional Options** field.

Write options as a comma-separated list with no spaces. Options that take a value use the `key=value` format:

```text
-o bank_table=0x8000,force_ram_test=true
--additional_opts=bank_table=0x8000,force_ram_test
```

Boolean options accept `true` or `false`. Omitting the value enables the option, so `force_ram_test` and `force_ram_test=true` are equivalent. Any other value is treated as `false`.

| Option                 | Description                                                                                                                                                                                                                        |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bank_table=<address>` | Sets the bank-table address used to handle bus conflicts with NES mappers such as BNROM and UNROM. The address may be decimal (`bank_table=32768`) or hexadecimal (`bank_table=0x8000`).                                           |
| `force_ram_test`       | Forces cartridge RAM (SRAM/WRAM/PRG-RAM) tests even when the ROM header indicates battery-backed data or when a raw binary file is used as the source.                                                                             |
| `force_flash_test`     | Forces ROM-chip identification even when no data is being flashed.                                                                                                                                                                 |
| `no_bin_regen`         | NES only for now. Reuses an existing generated binary instead of regenerating it when **Write** is selected. This can save time with large ROM files; delete the generated file or remove this option when regeneration is needed. |
| `flash_cic`            | NES only. Attempts to flash an ATtiny13A CIC chip whose pin 1 is connected to EXP5 (pin 55 of the NES connector). Reflashing may fail depending on the fuse settings used during the first programming.                            |

## Runtime files

The applications use the Lua scripts and settings from `INLretro-files/`, together with the shared protocol definitions. Keep the runtime files supplied with a build alongside the executables, or inside the application bundle on macOS.

The CI pipeline builds the firmware before the host software and includes the resulting firmware binaries in the host packages. For updating a connected programmer, see the [firmware update instructions](../README.md#important-note).

## Support and license

See [Support & feedback](../README.md#support--feedback) for bug reports and feature requests.

INLretro CLI/GUI is licensed under the [GNU General Public License, version 3 or later](../LICENSE).
