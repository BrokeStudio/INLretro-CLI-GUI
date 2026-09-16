# Building the host software

The host workspace contains the `Core` library and the `CLI` and `GUI` applications. See the [host README](README.md) for the architecture and directory layout.

Project files are generated from [Build.lua](Build.lua) using Premake. Regenerate them after changing the build configuration, rather than editing generated project files directly.

Unless otherwise stated, run the commands below from the `host/` directory.

## Common requirements

- A C++20-capable compiler for the GUI (`Core` and `CLI` use C++17).
- Premake 5, either available as `premake5` on `PATH` or invoked from `Vendor/Binaries/Premake/`.
- Platform-specific dependencies listed below.

The [host CI workflow](../.github/workflows/build-host.yml) currently uses these Premake versions:

| Target | Premake version | Generator |
| --- | --- | --- |
| Windows | 5.0.0-beta8 | `vs2026` |
| Linux x86_64 | 5.0.0-beta2 | `gmake` |
| macOS Apple Silicon | 5.0.0-beta8 | `gmake` |
| macOS Intel | 5.0.0-beta2 | `gmake` |

The examples below follow the CI generators. The helper scripts in `Scripts/` must be run from that directory because they change to their parent directory; the Linux helper currently uses `gmake2` instead of the CI's `gmake`.

## Firmware files

To include firmware updates in a local application build, prepare these files before building:

```text
INLretro-files/firmware/inlretro_stm6.bin
INLretro-files/firmware/inlretro_stmn.bin
```

Use the packaged firmware binaries for the corresponding hardware models. The CI downloads the `INLretro-firmware-AV04` artifact and copies `inlretro_stm6_AV04.bin` and `inlretro_stmn_AV04.bin` to the names above.

For building firmware from source in `../firmware/` and preparing its version signature, see the [firmware build guide](../firmware/COMPILING.md). Compiling the host applications does not build the firmware.

## Windows

### Prerequisites

- Visual Studio 2026 with the C++ desktop build tools and Windows SDK.
- Premake 5.0.0-beta8, matching the current CI.

Precompiled SDL2 and libusb libraries are included under `External/`.

### Generate and build

From a Visual Studio developer PowerShell, run:

```powershell
.\Vendor\Binaries\Premake\Windows\premake5.exe --file=Build.lua vs2026
msbuild INLretro.slnx -m -t:Rebuild -p:Configuration=Dist -p:Platform=x64
```

Use `-p:Platform=Win32` for the 32-bit build. You can also open the generated `INLretro.slnx` in Visual Studio, select the configuration and platform, and build the solution. Set `GUI` as the startup project to run the graphical application.

The `Dist` output directories are:

- `Binaries/windows-x86_64/Dist/INLretro/`
- `Binaries/windows-x86/Dist/INLretro/`

### Include the driver installer

The CI copies the Windows driver package into the distribution after compilation. To do the same for a local x64 build:

```powershell
Copy-Item -Path drivers/Windows/DriverPackages -Destination Binaries/windows-x86_64/Dist/INLretro/DriverPackages -Recurse -Force
```

Use the `windows-x86` output path for a 32-bit build. Driver installation instructions are in the [main README](../README.md#important-note).

## Linux

### Prerequisites

The CI builds on Ubuntu 22.04. For an Ubuntu/Debian development environment:

```sh
sudo apt-get update
sudo apt-get install build-essential clang pkg-config libsdl2-dev libusb-1.0-0-dev libudev-dev libgl-dev
```

Install Premake separately using the version listed above. The build uses `sdl2-config` and `pkg-config` to obtain dependency flags. libusb is linked through its static archive; SDL2 link flags come from `sdl2-config --static-libs`. Development libraries required by those flags must also be available.

Check that the static libusb archive is installed:

```sh
test -f "$(pkg-config --variable=libdir libusb-1.0)/libusb-1.0.a"
```

### Generate and build

```sh
premake5 --cc=clang --file=Build.lua gmake
make config=dist
```

The distribution is written to `Binaries/linux-x86_64/Dist/INLretro/`.

## macOS

### Prerequisites

- Xcode Command Line Tools, including Clang and Make.
- Premake for your architecture, using the version listed above.
- libusb and pkg-config, for example through Homebrew:

```sh
brew install libusb pkg-config
```

The build expects the SDL2 framework at `External/SDL2-macOS/SDL2.framework`. The current CI uses SDL2 **2.32.10**. To prepare the same framework from `host/`:

```sh
curl -L -o /tmp/INLretro-SDL2.dmg \
  https://github.com/libsdl-org/SDL/releases/download/release-2.32.10/SDL2-2.32.10.dmg
mkdir -p /tmp/INLretro-SDL2-mount
hdiutil attach /tmp/INLretro-SDL2.dmg -readonly -nobrowse \
  -mountpoint /tmp/INLretro-SDL2-mount
mkdir -p External/SDL2-macOS
ditto /tmp/INLretro-SDL2-mount/SDL2.framework External/SDL2-macOS/SDL2.framework
hdiutil detach /tmp/INLretro-SDL2-mount
```

libusb must provide a static archive for the target architecture:

```sh
test -f "$(pkg-config --variable=libdir libusb-1.0)/libusb-1.0.a"
```

### Generate and build

For Apple Silicon:

```sh
premake5 --arch=arm64 --file=Build.lua gmake
make config=dist
```

For Intel, use `--arch=x86_64` instead. The CI builds each architecture on a matching runner; local libraries must likewise match the selected architecture.

The `Dist` build creates `INLretroGUI.app` under `Binaries/<system>-<architecture>/Dist/app/`. It includes SDL2 as an embedded framework and places the runtime files inside the bundle. libusb is linked statically. The standalone executables are placed in the adjacent `INLretro/` directory.

Signing and archive creation are additional CI steps after compilation. See the [host workflow](../.github/workflows/build-host.yml) for the exact commands used to package the macOS release.

## Configurations and runtime files

The workspace provides `Debug`, `Release`, and `Dist`. With Make, select them using `config=debug`, `config=release`, or `config=dist`. With MSBuild or Visual Studio, use the corresponding capitalized configuration name.

Use `Dist` to reproduce the application layout used for releases. Output paths for other configurations can differ by project.

Keep the Lua scripts, settings, firmware files, and shared protocol definitions with the built applications. The build copies runtime resources from `INLretro-files/` and the repository's `shared/` directory; on macOS, the GUI bundle contains its own resources.

For the complete firmware-to-host build and release sequence, see the [pipeline workflow](../.github/workflows/pipeline.yml).
