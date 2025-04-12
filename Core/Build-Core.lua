project "Core"
kind "StaticLib"
language "C++"
cppdialect "C++17"
targetdir "Binaries/%{cfg.buildcfg}"
staticruntime "off"

files
{
  "Source/**.h", "Source/**.cpp",
  "include/**.h",
  "../INLretro-files/shared/**.h",
  "../External/lua/**.h", "../External/lua/**.c",
  "../External/libusb/include/**.h",
  "../External/termcolor/*.hpp",
}

vpaths {
  ["Lua"] = { "../External/lua/**.h", "../External/lua/**.c" },
  ["libusb"] = {"../External/libusb/include/**.h"},
  ["shared"] = {"../INLretro-files/shared/**.h"},
  ["termcolor"] = {"../External/termcolor/*.hpp"},
}

includedirs
{
  "Source",
  "include",

  "../INLretro-files/shared",

  "../External/lua",
  "../External/termcolor",
  -- "../External/libusb/include",
  "../External/libusb/INL/include",
  "../INLretro-files/shared",
}

targetdir("../Binaries/" .. OutputDir .. "/%{prj.name}")
objdir("../Binaries/Intermediates/" .. OutputDir .. "/%{prj.name}")

filter "system:windows"
  systemversion "latest"
  defines { "_CRT_SECURE_NO_WARNINGS" }
  linkoptions { "libusb-1.0.dll.a" }
  includedirs
  {
    "include",
    -- "../External/libusb/include"
    "../External/libusb/INL/include"
  }
  libdirs
  {
    -- "../External/libusb/MinGW32/static",
    "../External/libusb/INL/static",
  }

filter "system:linux"
  links { "usb-1.0", "pthread" }

filter "system:macosx"
  links { "usb-1.0", "pthread" }

filter "configurations:Debug"
  defines { "_DEBUG" }
  runtime "Debug"
  symbols "On"

filter "configurations:Release"
  defines { "_RELEASE" }
  runtime "Release"
  optimize "On"
  symbols "On"

filter "configurations:Dist"
  defines { "_DIST" }
  runtime "Release"
  optimize "On"
  symbols "Off"
