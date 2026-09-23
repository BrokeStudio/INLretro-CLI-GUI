#pragma once

#define INLRETRO_HOST_VERSION "0.1.0"

#include <cstdint>

typedef struct FirmwareVersion
{
  uint8_t major;
  uint8_t minor;
  uint8_t patch;
} FirmwareVersion;

constexpr FirmwareVersion MINIMUM_FIRMWARE = { 0, 1, 0 };

const char* get_host_build_id();
const char* get_host_version_string();
