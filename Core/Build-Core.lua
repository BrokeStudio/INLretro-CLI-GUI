project "Core"
kind "StaticLib"
language "C++"
cppdialect "C++17"
targetdir "Binaries/%{cfg.buildcfg}"
staticruntime "off"

files
{
  "./Source/**.h", "./Source/**.cpp",
  "./include/**.h",

  "../INLretro-files/shared/**.h",
  "../External/lua/**.h", "../External/lua/**.c",
  "../External/libusb/INL/include/**.h",
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
  "./Source",
  "./include",

  "../INLretro-files/shared",

  "../External/lua",
  "../External/termcolor",
  "../INLretro-files/shared",
}

targetdir("../Binaries/" .. OutputDir .. "/%{prj.name}")
objdir("../Binaries/Intermediates/" .. OutputDir .. "/%{prj.name}")

-- Windows / Linux / macOS

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

-- Windows

filter { "system:windows" }
  staticruntime "on"

filter "system:windows"
  systemversion "latest"
  defines { "_CRT_SECURE_NO_WARNINGS" }
  includedirs
  {
    "include",
    "../External/libusb/include"
  }

filter { "system:windows", "configurations:Debug", "platforms:x86" }
  links { "libusb-1.0" }
  libdirs { "../External/libusb/VS2022/MS32/static" }

filter { "system:windows", "configurations:Debug", "platforms:x86_64" }
  links { "libusb-1.0" }
  libdirs { "../External/libusb/VS2022/MS64/static" }

filter { "system:windows", "configurations:Release or Dist", "platforms:x86" }
  links { "libusb-1.0" }
  libdirs { "../External/libusb/VS2022/MS32/static" }

filter { "system:windows", "configurations:Release or Dist", "platforms:x86_64" }
  links { "libusb-1.0" }
  libdirs { "../External/libusb/VS2022/MS64/static" }

-- Linux or macOS

filter "system:linux or macosx"
  includedirs
  {
    "../macOS"
  }
  links { "usb-1.0", "pthread" }
