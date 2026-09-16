# Building the firmware

This guide follows the repository's [firmware CI workflow](../.github/workflows/build-firmware.yml), which builds on Linux. See the [firmware README](README.md) for the source layout and hardware variants.

## Prerequisites

For the complete build, install:

- GNU Make and standard Unix tools.
- ARM GNU Embedded GCC **7.3.1** (`7-2018-q2-update`) for STM32 targets.
- AVR GCC and avr-libc for the AVR Kazzo target.
- Python 3 for creating STM32 DfuSe release files from binaries; no Python packages are required for this conversion.

On Ubuntu/Debian:

```sh
sudo apt-get update
sudo apt-get install make gcc-avr avr-libc wget tar bzip2 python3
```

From the repository root, enter the firmware build directory:

```sh
cd firmware
```

The following commands use this directory as their working directory.

### Install the ARM toolchain used by CI

The following Linux commands reproduce the toolchain download in CI and add it to the current shell's `PATH`:

```sh
wget https://developer.arm.com/-/media/Files/downloads/gnu-rm/7-2018q2/gcc-arm-none-eabi-7-2018-q2-update-linux.tar.bz2
tar -xjf gcc-arm-none-eabi-7-2018-q2-update-linux.tar.bz2
export PATH="$PWD/gcc-arm-none-eabi-7-2018-q2-update/bin:$PATH"
arm-none-eabi-gcc --version
avr-gcc --version
```

Use the pinned ARM toolchain to match CI; newer compiler versions are not validated by this guide. Native Windows and macOS firmware builds are not covered by the current CI workflow.

## Build all standard variants

```sh
make all
```

The top-level firmware Makefile performs clean builds in sequence and preserves each STM32 variant in a separate directory:

| Hardware                        | Main output                   |
| ------------------------------- | ----------------------------- |
| NES-only / NESmaker programmer  | `build_stmn/inlretro_stm.bin` |
| INLretro 6-connector programmer | `build_stm6/inlretro_stm.bin` |
| AVR Kazzo programmer            | `build_avr/avr_kazzo.hex`     |

STM32 builds also generate `.axf`, `.elf`, `.hex`, and `.map` files. The commands above compile firmware without programming a connected device.

## Build a single variant

| Command          | Target                                     | Main output                   |
| ---------------- | ------------------------------------------ | ----------------------------- |
| `make stm6clean` | Clean build for the 6-connector programmer | `build_stm6/inlretro_stm.bin` |
| `make stmn`      | Clean build for the NES-only programmer    | `build_stm/inlretro_stm.bin`  |
| `make avr`       | Clean build for AVR Kazzo                  | `build_avr/avr_kazzo.hex`     |

Unlike `make all`, `make stmn` does not copy its output into `build_stmn/`.

The STM32 variants share object files and the `build_stm/` directory. Build sequentially, without `-j`, and use a clean build when switching hardware configurations. The `make stm6` target is an incremental build; use `make stm6clean` when switching back from another variant.

Additional targets `stm6p` and `stmad` use `Make_stm_inl6p` and `Make_stm_adapter`, respectively. They are outside the default CI build.

Protocol headers are copied from the repository's `shared/` directory into `source/` during the build. Edit the originals in `shared/`; the copied files can be removed or replaced by clean/build steps.

## Prepare release binaries

A plain `make all` does not add the STM32 version signature used by release packaging. The current CI writes `AV04` at byte offset `0x800`, then distributes the signed binaries with versioned filenames.

After `make all`, the following produces equivalent release files while leaving the original build outputs unchanged:

```sh
mkdir -p release
cp build_stm6/inlretro_stm.bin release/inlretro_stm6_AV04.bin
cp build_stmn/inlretro_stm.bin release/inlretro_stmn_AV04.bin
printf 'AV04' | dd of=release/inlretro_stm6_AV04.bin bs=1 seek=2048 conv=notrunc
printf 'AV04' | dd of=release/inlretro_stmn_AV04.bin bs=1 seek=2048 conv=notrunc
cp build_avr/*.hex release/
```

Here, the signature is a firmware version marker, not a cryptographic signature. `AV04` matches the current workflow; keep it consistent with the firmware version and packaging configuration when preparing a new release.

CI uploads the contents of `release/`, including the DfuSe files generated below, as the `INLretro-firmware-AV04` artifact. See the [historical release notes](firmware%20release%20notes.txt) for earlier releases.

## Create DfuSe files

All commands in this section run from `firmware/`. A local build creates `build_stm6/inlretro_stm.bin` and `build_stmn/inlretro_stm.bin` after `make all`; it does not create `release/inlretro_stm6_AV04.bin` or `release/inlretro_stmn_AV04.bin` automatically.

On Linux, first run the commands in [Prepare release binaries](#prepare-release-binaries), then convert those version-marked copies:

```sh
python3 dfuse-pack.py -b 0x08000000:release/inlretro_stm6_AV04.bin -D 0x0483:0xdf11 release/inlretro_stm6_AV04.dfu
python3 dfuse-pack.py -b 0x08000000:release/inlretro_stmn_AV04.bin -D 0x0483:0xdf11 release/inlretro_stmn_AV04.dfu
```

On Windows, install Python 3. First create the release directory and copy each locally built binary with the `AV04` marker inserted at offset `0x800`. These commands work in cmd.exe and PowerShell and leave the build outputs unchanged:

```cmd
py -3 -c "from pathlib import Path; Path('release').mkdir(exist_ok=True)"
py -3 -c "from pathlib import Path; data = bytearray(Path('build_stm6/inlretro_stm.bin').read_bytes()); assert len(data) >= 0x804, 'Firmware too short'; data[0x800:0x804] = b'AV04'; Path('release/inlretro_stm6_AV04.bin').write_bytes(data)"
py -3 -c "from pathlib import Path; data = bytearray(Path('build_stmn/inlretro_stm.bin').read_bytes()); assert len(data) >= 0x804, 'Firmware too short'; data[0x800:0x804] = b'AV04'; Path('release/inlretro_stmn_AV04.bin').write_bytes(data)"
```

Run only the command for the model you built. If you used `make stmn` instead of `make all`, its input is `build_stm/inlretro_stm.bin`: replace the `build_stmn/` input path in the NESmaker command above. The shared `build_stm/` directory contains the last STM32 variant built, so use it only for that model.

Then convert the prepared files (or run just the command for your model):

```cmd
py -3 dfuse-pack.py -b 0x08000000:release/inlretro_stm6_AV04.bin -D 0x0483:0xdf11 release/inlretro_stm6_AV04.dfu
py -3 dfuse-pack.py -b 0x08000000:release/inlretro_stmn_AV04.bin -D 0x0483:0xdf11 release/inlretro_stmn_AV04.dfu
```

The input `.bin` files must already contain the `AV04` marker at offset `0x800`; conversion does not insert it. You can use release binaries downloaded from CI on Windows without installing the firmware compilers.

The converter packages each binary for flash address `0x08000000` (matching `include_stm/nokeep.ld`), alternate interface 0, and the STM32 DFU USB ID `0483:df11`. It creates files without accessing connected hardware. No intermediate `.hex` file or `intelhex` Python package is needed when using binary inputs.

To inspect a generated file, run `python3 dfuse-pack.py release/inlretro_stm6_AV04.dfu` (or `py -3` on Windows). The script displays the target address, device identifiers and CRC information.

Keep `.bin` files for updates through the host CLI/GUI; `.dfu` files are for DfuSe-compatible tools. AVR Kazzo continues to use `.hex`. See the [tool attribution and license](README.md#bundled-conversion-tool).

## Include firmware in a host build

From the same `firmware/` working directory:

```sh
mkdir -p ../host/INLretro-files/firmware
cp release/inlretro_stm6_AV04.bin ../host/INLretro-files/firmware/inlretro_stm6.bin
cp release/inlretro_stmn_AV04.bin ../host/INLretro-files/firmware/inlretro_stmn.bin
```

These are the filenames used by the CLI and GUI firmware update functions. Continue with the [host build guide](../host/COMPILING.md) to include them in an application build.

For updating a connected programmer, follow the [main README's firmware update instructions](../README.md#important-note) and select the matching hardware model. The AVR bootloader tools are separate from the STM32 update procedure.
