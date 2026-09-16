# INLretro firmware

This directory contains the firmware source and build files for INLretro programmers, along with bootloader tools for AVR-based hardware.

For installing a firmware update using the CLI or GUI, see the [main project README](../README.md#important-note). For the desktop applications, see the [host software README](../host/README.md).

## Build targets

The main [Makefile](Makefile) builds three hardware variants with `make all`, run from this directory:

| Hardware | Build configuration | Output from `make all` |
| --- | --- | --- |
| INLretro 6-connector programmer (STM32) | `Make_stm_inl6` | `build_stm6/inlretro_stm.bin` |
| NES-only / NESmaker programmer (STM32) | `Make_stm_nes` | `build_stmn/inlretro_stm.bin` |
| AVR Kazzo programmer (ATmega164A) | `Make_avr` | `build_avr/avr_kazzo.hex` |

Output paths in this table are relative to `firmware/` at the repository root.

Additional STM32 configurations are present in `Make_stm_inl6p` and `Make_stm_adapter`; they are not part of the default `make all` build.

## Directory layout

```text
firmware/
├── source/                    # Common code and hardware-specific implementations
├── source_stm_only/           # STM32-specific code
├── include_stm/               # STM32 headers, startup code, and linker scripts
├── usbdrv_Vusb/               # V-USB driver for AVR hardware
├── avr_bootloader/            # AVR bootloader source and flashing tools
├── Makefile                   # Build targets for the hardware variants
├── Make_avr                   # AVR build configuration
├── Make_stm_inl6               # STM32 6-connector build configuration
├── Make_stm_nes                # STM32 NES-only build configuration
├── Make_stm_inl6p              # Additional STM32 configuration
└── Make_stm_adapter            # STM32 adapter build configuration
```

Protocol definitions shared with the host software live in [`../shared/`](../shared/). The firmware build copies these files into `source/` in this directory; make protocol changes in the shared directory rather than in the copied files.

## Building

See [COMPILING.md](COMPILING.md) for prerequisites, toolchain installation, build commands, release packaging, and integration with the host applications.

## DFU release files

The firmware CI includes `.bin` and `.dfu` files for both STM32 programmer models, and `.hex` for AVR Kazzo. The STM32 `.dfu` files use the DfuSe format, target flash address `0x08000000`, alternate interface 0, and USB device ID `0483:df11`. They contain the same version-marked firmware as the release `.bin` files.

See [Create DfuSe files](COMPILING.md#create-dfuse-files) for Linux and Windows conversion commands. The host CLI/GUI updater continues to use `.bin` files.

### Bundled conversion tool

[`dfuse-pack.py`](dfuse-pack.py) comes from the [dfu-util project](https://dfu-util.sourceforge.net/dfuse.html). Its header credits Antonio Galea (2010-11-18) and specifies GNU LGPL 3.0. The bundled script is kept unchanged; CI uses this repository copy without downloading another version. The upstream release number is not recorded in the script.

Its license is included in [dfuse-pack.LICENSE.txt](dfuse-pack.LICENSE.txt), together with the GNU GPL v3 text at the [repository root](../LICENSE). Keep the original attribution and license when redistributing the script, and document any future modifications.

## Support and licenses

See [Support & feedback](../README.md#support--feedback) for bug reports and feature requests. Include the programmer model and firmware version when reporting a firmware issue.

See the [project license](../LICENSE) and the license notices included with individual components, including V-USB and the AVR bootloader sources.
