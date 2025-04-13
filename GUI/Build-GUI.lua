project "GUI"
language "C++"
cppdialect "C++17"
targetdir "Binaries/%{cfg.buildcfg}"
debugdir "Binaries/%{cfg.targetdir}"
staticruntime "off"
targetname "INLretroGUI"

files
{
  "Source/**.h", "Source/**.cpp",
  "fonts/**.h",

  "../External/SDL2/include/**.h",
  "../External/imgui/**.h", "../External/imgui/**.cpp",
  "../External/imgui/backends/**.h", "../External/imgui/backends/**.cpp",
  "../External/imgui/FileBrowser/**.h", "../External/imgui/FileBrowser/**.cpp",
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
    "../External/imgui/FileBrowser/**.h",
    "../External/imgui/FileBrowser/**.cpp",
  },
  ["shared"] = {
    "../INLretro-files/shared/**.h",
  }
}

includedirs
{
  "Source",
  "fonts",

  "../Core/Source",

  "../INLretro-files/shared",

  "../External/imgui",
  "../External/imgui/backends",
  "../External/imgui/FileBrowser",
  "../External/lua",
}

links
{
  "Core",
}

targetdir("../Binaries/" .. OutputDir .. "/%{prj.name}")
objdir("../Binaries/Intermediates/" .. OutputDir .. "/%{prj.name}")

filter "system:windows"
  systemversion "latest"
  defines { "_CRT_SECURE_NO_WARNINGS" }
  linkoptions { "libusb-1.0.dll.a" }
  links {
    "opengl32",
    "SDL2",
    "SDL2main",
  }
  includedirs
  {
    -- Include SDL2
    "../External/SDL2/include",

    -- Include libusb
    -- "../External/libusb/include",
    "../External/libusb/INL/include",
  }
  libdirs
  {
    -- SDL2
    "../External/SDL2/x86",

    -- libusb
    -- "../External/libusb/MinGW32/static",
    "../External/libusb/INL/static",
  }
  prebuildcommands {
    -- "{COPYFILE} \"../External/libusb/MinGW32/dll/libusb-1.0.dll\" \"%{cfg.targetdir}\"",
    "{COPYFILE} \"../External/libusb/INL/dll/libusb-1.0.dll\" \"%{cfg.targetdir}\"",
    "{COPYFILE} \"../External/SDL2/x86/SDL2.dll\" \"%{cfg.targetdir}\"",
  }

filter "system:linux"
  buildoptions "`sdl2-config --cflags`"
  linkoptions "-lGL `sdl2-config --libs`"
  links { "usb-1.0", "pthread" }

filter "system:macosx"
  buildoptions "`sdl2-config --cflags`"
  linkoptions "-framework OpenGL -framework CoreFoundation `sdl2-config --libs`"
  links { "usb-1.0", "pthread" }

filter "configurations:Debug"
  kind "ConsoleApp"
  defines { "_DEBUG" }
  runtime "Debug"
  symbols "On"
  prebuildcommands
  {
    "{COPYDIR} \"../INLretro-files\" \"%{cfg.targetdir}\"",
    "{COPYDIR} \"../Roms\" \"%{cfg.targetdir}/roms\""
  }

filter "configurations:Release"
  kind "ConsoleApp"
  defines { "_RELEASE" }
  runtime "Release"
  optimize "On"
  symbols "On"
  prebuildcommands
  {
    "{COPYDIR} \"../INLretro-files\" \"%{cfg.targetdir}\"",
    "{COPYDIR} \"../Roms\" \"%{cfg.targetdir}/roms\""
  }

filter { "configurations:Dist", "system:windows or linux" }
  kind "WindowedApp"
  defines { "_DIST" }
  runtime "Release"
  optimize "On"
  symbols "Off"
  targetdir("../Binaries/" .. OutputDir .. "/INLretro")
  prebuildcommands
  {
    "{COPYDIR} \"../INLretro-files\" \"%{cfg.targetdir}\"",
  }

filter { "configurations:Dist", "system:macosx" }
  kind "ConsoleApp"
  defines { "_DIST" }
  runtime "Release"
  optimize "On"
  symbols "Off"
  targetdir("../Binaries/" .. OutputDir .. "/INLretro")
  -- prebuildcommands
  -- {
  --   "{COPYDIR} \"../INLretro-files\" \"%{cfg.targetdir}\"",
  -- }
  postbuildcommands
  {
    "{MKDIR} \"%{cfg.targetdir}/INLretroGUI.app\"",
    "{MKDIR} \"%{cfg.targetdir}/INLretroGUI.app/Contents\"",
    "{MKDIR} \"%{cfg.targetdir}/INLretroGUI.app/Contents/MacOS\"",
    "{MKDIR} \"%{cfg.targetdir}/INLretroGUI.app/Contents/Resources\"",
    "{COPY} \"../macOS/info.plist\" \"%{cfg.targetdir}/INLretroGUI.app/Contents\"",
    "{COPY} \"%{cfg.targetdir}/INLretroGUI\" \"%{cfg.targetdir}/INLretroGUI.app/Contents/MacOS\"",
    "{COPY} \"../macOS/icon.icns\" \"%{cfg.targetdir}/INLretroGUI.app/Contents/Resources\"",
    "{COPYDIR} \"../INLretro-files/\" \"%{cfg.targetdir}/INLretroGUI.app/Contents/Resources\"",
  }
