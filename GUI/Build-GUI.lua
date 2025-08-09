project "GUI"
language "C++"
cppdialect "C++17"
targetdir "Binaries/%{cfg.buildcfg}"
debugdir "Binaries/%{cfg.targetdir}"
staticruntime "off"
targetname "INLretroGUI"

files
{
  "./Source/**.h", "./Source/**.cpp",
  "./fonts/**.h",

  "../External/SDL2/include/**.h",
  "../External/imgui/*.h", "../External/imgui/*.cpp",
  "../External/imgui/backends/**.h", "../External/imgui/backends/**.cpp",
  "../External/imgui/misc/cpp/**.h", "../External/imgui/misc/cpp/**.cpp",
  "../External/FileBrowser/**.h", "../External/FileBrowser/**.cpp",
}

vpaths {
  ["SDL2"] = {
    "../External/SDL2/include/**.h",
  },
  ["ImGui"] = {
    "../External/imgui/**.h",
    "../External/imgui/**.cpp",
    "../External/imgui/backends/**.h",
    "../External/imgui/backends/**.cpp",
    "../External/imgui/misc/cpp/*.h",
    "../External/imgui/misc/cpp/*.cpp",
    "../External/FileBrowser/**.h",
    "../External/FileBrowser/**.cpp",
  },
  ["shared"] = {
    "../INLretro-files/shared/**.h",
  }
}

includedirs
{
  "./Source",
  "./fonts",

  "../Core/Source",

  "../INLretro-files/shared",

  "../External/imgui",
  "../External/imgui/backends",
  "../External/imgui/misc/cpp",
  "../External/FileBrowser",
  "../External/lua",
}

links
{
  "Core",
}

targetdir("../Binaries/" .. OutputDir .. "/%{prj.name}")
objdir("../Binaries/Intermediates/" .. OutputDir .. "/%{prj.name}")

-- Windows / Linux / macOS

filter "configurations:Debug"
  kind "ConsoleApp"
  defines { "_DEBUG" }
  runtime "Debug"
  symbols "On"


filter "configurations:Release"
  kind "ConsoleApp"
  defines { "_RELEASE" }
  runtime "Release"
  optimize "On"
  symbols "On"

filter "configurations:Debug or Release or Dist"
  postbuildcommands
  {
    "{COPYDIR} \"../INLretro-files\\.\" \"%{cfg.targetdir}\""
  }

filter "configurations:Debug or Release"
  postbuildcommands
  {
    "{COPYDIR} \"../Roms\" \"%{cfg.targetdir}/roms\""
  }

-- Windows

filter { "system:windows" }
  staticruntime "on"

filter { "system:windows", "platforms:x86" }
  linkoptions { "/SAFESEH:NO" } -- Image Has Safe Exception Handers: No

filter { "system:windows", "configurations:Dist" }
  kind "WindowedApp"
  defines { "_DIST" }
  runtime "Release"
  optimize "On"
  symbols "Off"
  targetdir("../Binaries/" .. OutputDir .. "/INLretro")
  entrypoint "mainCRTStartup"

filter "system:windows"
  files { '../Windows/Resources/resources.rc', '**.ico' }
  vpaths { ["Resources"] = { "../Windows/Resources/*.rc", "../Windows/Resources/*.ico" } }
  systemversion "latest"
  defines {
    "_CRT_SECURE_NO_WARNINGS",
    "SDL_MAIN_HANDLED", -- to avoid SDL_main
  }
  includedirs {
    "../External/SDL2/include",
    "../External/libusb/include"
  }
  links {
    "winmm.lib",
    "setupapi.lib",
    "version.lib",
    -- "Imm32.lib",
    "opengl32",
  }
  libdirs {
    "../External/libusb/INL/static",
  }
  prebuildcommands {
    "powershell -ExecutionPolicy Bypass -File increment-build.ps1"
  }

filter { "system:windows", "configurations:Debug", "platforms:x86" }
  links {
    "SDL2-staticd",
    "libusb-1.0"
  }
  libdirs {
    "../External/SDL2/lib/x86-static-debug",
    "../External/libusb/VS2022/MS32/static",
  }

filter { "system:windows", "configurations:Debug", "platforms:x86_64" }
  links {
    "SDL2-staticd",
    "libusb-1.0"
  }
  libdirs {
    "../External/SDL2/lib/x64-static-debug",
    "../External/libusb/VS2022/MS64/static",
  }

filter { "system:windows", "configurations:Release or Dist", "platforms:x86" }
  links {
    "SDL2-static",
    "libusb-1.0"
  }
  libdirs {
    "../External/SDL2/lib/x86-static-release",
    "../External/libusb/VS2022/MS32/static",
  }

filter { "system:windows", "configurations:Release or Dist", "platforms:x86_64" }
  links {
    "SDL2-static",
    "libusb-1.0"
  }
  libdirs {
    "../External/SDL2/lib/x64-static-release",
    "../External/libusb/VS2022/MS64/static",
  }

-- Linux

filter "system:linux"
  buildoptions { "`sdl2-config --cflags`" }
  linkoptions { "`sdl2-config --libs`" }
  links {
    "usb-1.0",
    "GL",
    -- "dl",
    "pthread",
    "SDL2"
  }
  prebuildcommands {
    "sh ./increment-build.sh"
  }

filter { "system:linux", "configurations:Dist" }
  kind "WindowedApp"
  defines { "_DIST" }
  runtime "Release"
  optimize "On"
  symbols "Off"
  targetdir("../Binaries/" .. OutputDir .. "/INLretro")

-- macOS

filter "system:macosx"
  buildoptions { "`sdl2-config --cflags`" }
  linkoptions {
    "`sdl2-config --libs`",
    "-framework OpenGL",
    "-framework CoreFoundation"
  }
  links {
    "usb-1.0",
  }
  includedirs
  {
    "../macOS"
  }
  prebuildcommands {
    "sh ./increment-build.sh"
  }

filter { "system:macosx", "configurations:Dist" }
  kind "ConsoleApp"
  defines { "_DIST" }
  runtime "Release"
  optimize "On"
  symbols "Off"
  targetdir("../Binaries/" .. OutputDir .. "/INLretro")
  postbuildcommands
  {
    "{RMDIR} \"%{cfg.targetdir}/../app/INLretroGUI.app\"",
    "{MKDIR} \"%{cfg.targetdir}/../app/INLretroGUI.app\"",
    "{MKDIR} \"%{cfg.targetdir}/../app/INLretroGUI.app/Contents\"",
    "{MKDIR} \"%{cfg.targetdir}/../app/INLretroGUI.app/Contents/MacOS\"",
    "{MKDIR} \"%{cfg.targetdir}/../app/INLretroGUI.app/Contents/Resources\"",
    "{COPY} \"../macOS/Info.plist\" \"%{cfg.targetdir}/../app/INLretroGUI.app/Contents\"",
    "{COPY} \"%{cfg.targetdir}/INLretroGUI\" \"%{cfg.targetdir}/../app/INLretroGUI.app/Contents/MacOS\"",
    "{COPY} \"../macOS/INL.png\" \"%{cfg.targetdir}/../app/INLretroGUI.app/Contents/Resources\"",
    "{COPYDIR} \"../INLretro-files/\" \"%{cfg.targetdir}/../app/INLretroGUI.app/Contents/Resources\"",
  }
