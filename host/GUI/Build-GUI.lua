project "GUI"
language "C++"
cppdialect "C++20"
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
  buildoptions {
    "`sdl2-config --cflags`",
    "`pkg-config --cflags libusb-1.0`",
  }
  linkoptions {
    "`sdl2-config --static-libs`",
    "-Wl,--whole-archive,`pkg-config --variable=libdir libusb-1.0`/libusb-1.0.a,--no-whole-archive",
    "`pkg-config --static --libs-only-L --libs-only-other libusb-1.0`",
  }
  links {
    "GL",
    "udev",
    "pthread",
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
  includedirs {
    "../macOS",
    "../External/SDL2-macOS/SDL2.framework/Headers",
  }

  buildoptions {
    "-mmacosx-version-min=12.0",
    "-F../External/SDL2-macOS",
    "`pkg-config --cflags libusb-1.0`",
  }

  linkoptions {
    "-mmacosx-version-min=12.0",
    "-F../External/SDL2-macOS",
    "-framework SDL2",
    "-Wl,-rpath,@executable_path/../Frameworks",
    "-framework OpenGL",
    "-framework CoreFoundation",
    "-Wl,-force_load,`pkg-config --variable=libdir libusb-1.0`/libusb-1.0.a",
    "`pkg-config --static --libs-only-L --libs-only-other libusb-1.0`",
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
    "{MKDIR} \"%{cfg.targetdir}/../app/INLretroGUI.app/Contents/MacOS\"",
    "{MKDIR} \"%{cfg.targetdir}/../app/INLretroGUI.app/Contents/Resources\"",
    "{MKDIR} \"%{cfg.targetdir}/../app/INLretroGUI.app/Contents/Frameworks\"",

    "ditto \"../External/SDL2-macOS/SDL2.framework\" \"%{cfg.targetdir}/../app/INLretroGUI.app/Contents/Frameworks/SDL2.framework\"",
    "{COPY} \"../macOS/info.plist\" \"%{cfg.targetdir}/../app/INLretroGUI.app/Contents/Info.plist\"",
    "{COPY} \"../macOS/AppIcon.icns\" \"%{cfg.targetdir}/../app/INLretroGUI.app/Contents/Resources/AppIcon.icns\"",
    "{COPY} \"%{cfg.targetdir}/INLretroGUI\" \"%{cfg.targetdir}/../app/INLretroGUI.app/Contents/MacOS/INLretroGUI\"",
    "{COPYDIR} \"../INLretro-files/\" \"%{cfg.targetdir}/../app/INLretroGUI.app/Contents/Resources\"",
  }
