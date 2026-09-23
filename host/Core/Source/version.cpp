#include "version.h"

#if __has_include("build_info.h")
  #include "build_info.h"
#else
  #define INLRETRO_BUILD_ID "unknown"
#endif

const char* get_host_build_id()
{
  return INLRETRO_BUILD_ID;
}

const char* get_host_version_string()
{
#if defined(_DEBUG) || defined(_RELEASE)
  return INLRETRO_HOST_VERSION "-dev+" INLRETRO_BUILD_ID;
#else
  return INLRETRO_HOST_VERSION;
#endif
}
