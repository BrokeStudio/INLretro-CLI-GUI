#pragma once

#include <cstdint>

typedef struct FirmwareVersion
{
  uint8_t major;
  uint8_t minor;
  uint8_t patch;
} FirmwareVersion;

constexpr FirmwareVersion MINIMUM_FIRMWARE = { 0, 1, 0 };
