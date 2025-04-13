-- premake5.lua
workspace "INLretro"
  -- architecture "x64"
  configurations { "Debug", "Release", "Dist" }
  startproject "GUI"

  -- Workspace-wide build options for MSVC
  filter "system:windows"
    architecture "x86"
    buildoptions { "/EHsc", "/Zc:preprocessor", "/Zc:__cplusplus" }
    linkoptions { "/SAFESEH:NO" } -- Image Has Safe Exception Handers: No

  filter "system:linux"
    architecture "x64"

  filter "system:macosx"
    architecture "universal"

OutputDir = "%{cfg.system}-%{cfg.architecture}/%{cfg.buildcfg}"

group "Core"
  include "Core/Build-Core.lua"
group ""

include "CLI/Build-CLI.lua"
include "GUI/Build-GUI.lua"
