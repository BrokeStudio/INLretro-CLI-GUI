project "CLI"
language "C++"
cppdialect "C++17"
targetdir "Binaries/%{cfg.buildcfg}"
debugdir "Binaries/%{cfg.targetdir}"
staticruntime "off"
targetname "INLretro"

files
{
  "Source/**.h", "Source/**.cpp",
  "../External/termcolor/*.hpp",
}

vpaths {
  ["termcolor"] = {"../External/termcolor/*.hpp"},
}

includedirs
{
  "Source",

  "../Core/Source",

  "../INLretro-files/shared",

  "../External/lua",
  "../External/termcolor",
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
  }
  includedirs
  {
    -- "include",
    -- "../External/libusb/include"
    "../External/libusb/INL/include",
  }
  libdirs {
    -- libusb
    -- "../External/libusb/MinGW32/static",
    "../External/libusb/INL/static",
  }
  prebuildcommands {
    -- "{COPYFILE} \"../External/libusb/MinGW32/dll/libusb-1.0.dll\" \"%{cfg.targetdir}\"",
    "{COPYFILE} \"../External/libusb/INL/dll/libusb-1.0.dll\" \"%{cfg.targetdir}\"",
  }

filter "system:linux"
  links { "usb-1.0", "pthread" }

filter "system:macosx"
  links { "usb-1.0", "pthread" }

filter "configurations:Debug"
  kind "ConsoleApp"
  defines { "_DEBUG" }
  runtime "Debug"
  symbols "On"
  prebuildcommands
  {
    "{COPYDIR} \"../INLretro-files\" \"%{cfg.targetdir}\"",
    "{DELETE} \"%{cfg.targetdir}\\INLretro.ini\"",
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
    "{DELETE} \"%{cfg.targetdir}\\INLretro.ini\"",
    "{COPYDIR} \"../Roms\" \"%{cfg.targetdir}/roms\""
  }

filter "configurations:Dist"
  kind "ConsoleApp"
  defines { "_DIST" }
  runtime "Release"
  optimize "On"
  symbols "Off"
  targetdir("../Binaries/" .. OutputDir .. "/INLretro")
  prebuildcommands
  {
    "{COPYDIR} \"../INLretro-files\" \"%{cfg.targetdir}\""
  }
