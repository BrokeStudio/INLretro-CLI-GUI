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

  filter { "configurations:Dist", "system:windows or linux" }
  kind "ConsoleApp"
  defines { "_DIST" }
  runtime "Release"
  optimize "On"
  symbols "Off"
  targetdir("../Binaries/" .. OutputDir .. "/INLretro")
  prebuildcommands
  {
    "{COPYDIR} \"../INLretro-files\\.\" \"%{cfg.targetdir}\""
  }

filter { "configurations:Dist", "system:macosx" }
  kind "ConsoleApp"
  defines { "_DIST" }
  runtime "Release"
  optimize "On"
  symbols "Off"
  targetdir("../Binaries/" .. OutputDir .. "/INLretro")

filter "configurations:*"
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
  prebuildcommands {
    "powershell -ExecutionPolicy Bypass -File increment-build.ps1"
  }

filter "platforms:x86"
  system "Windows"
  architecture "x86"

filter "platforms:x86_64"
  system "Windows"
  architecture "x86_64"

filter "system:windows"
  files { '../Windows/Resources/resources.rc', '**.ico' }
  vpaths { ["Resources"] = { "../Windows/Resources/*.rc", "../Windows/Resources/*.ico" } }
  systemversion "latest"
  defines { "_CRT_SECURE_NO_WARNINGS" }
  includedirs { "../External/libusb/include" }
  links {
    "opengl32",
    "libusb-1.0"
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

-- Linux

filter "system:linux"
  links {
    "usb-1.0",
    "pthread"
  }
  prebuildcommands {
    "sh ./increment-build.sh"
  }

-- macOS

filter "system:macosx"
  links {
    "usb-1.0",
    "pthread"
  }
  prebuildcommands {
    "sh ./increment-build.sh"
  }
