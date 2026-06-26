#pragma once
#ifndef SNES_H
#define SNES_H

#include <algorithm>
#include <cstdint>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>

#include "AppLog.h"
#include "Console.h"
#include "IconsFontAwesome6.h"
#include "imgui.h"

class Snes : public Console
{

public:
  using Console::Console;

protected:
  void cb_rom_write_file_dialog(const std::string &path, const std::string &filename) override
  {
    rom_write_INLOptions.rom_write_file = path;

    APP_LOG(LogTypes_Point, "[%s] Opening: %s", this->short_name.c_str(), filename.c_str());

    // parse rom file header
    parse_header(rom_write_INLOptions.rom_write_file);

    // set default values
    if (!header.check_rom_size())
      rom_write_INLOptions.rom_size_kb = static_cast<int>(header.fileSize >> 10);
    else
      rom_write_INLOptions.rom_size_kb = header.get_rom_size();

    if (mappers.size() != 0)
    {
      int mapperIndex = get_mapper_index_by_mapper_name(header.get_mapper_name());
      if (mapperIndex == -1)
      {
        APP_LOG(LogTypes_Warning, "[%s] Mapper unknown: %s", this->short_name.c_str(), header.get_mapper_name().c_str());
      }
      else
      {
        rom_write_INLOptions.mapper_name = mappers[mapperIndex].script_name;
      }
    }
  }

private:
  static bool is_power_of_two(std::size_t value)
  {
    return value != 0 && (value & (value - 1)) == 0;
  }

  static std::size_t floor_power_of_two(std::size_t value)
  {
    if (value == 0)
      throw std::invalid_argument("Value must not be zero.");

    std::size_t result = 1;

    while ((result << 1) <= value)
      result <<= 1;

    return result;
  }

  static std::size_t ceil_power_of_two(std::size_t value)
  {
    if (value == 0)
      throw std::invalid_argument("Value must not be zero.");

    if (is_power_of_two(value))
      return value;

    std::size_t result = 1;

    while (result < value)
      result <<= 1;

    return result;
  }

  bool expand_snes_rom_mirroring(std::vector<uint8_t> &romData)
  {
    const std::size_t fileSize = romData.size();

    // if (fileSize == 0)
    //   throw std::invalid_argument("ROM data is empty.");

    if (is_power_of_two(fileSize))
      return true;

    const std::size_t firstPartSize = floor_power_of_two(fileSize);
    const std::size_t remainderSize = fileSize - firstPartSize;
    const std::size_t secondPartSize = ceil_power_of_two(remainderSize);

    if (secondPartSize > firstPartSize)
      return false;
    // throw std::runtime_error("Invalid SNES ROM mirroring layout.");

    if ((firstPartSize % secondPartSize) != 0)
      return false;
    // throw std::runtime_error("Invalid SNES ROM mirroring ratio.");

    const std::size_t repeatCount = firstPartSize / secondPartSize;
    const std::size_t secondPartOffset = firstPartSize;
    const std::size_t expandedSize = firstPartSize * 2;

    romData.reserve(expandedSize);

    // Pad the second part if the remainder is not already a power of two.
    romData.resize(firstPartSize + secondPartSize, 0x00);

    // The original second part is already present once.
    for (std::size_t repeatIndex = 1; repeatIndex < repeatCount; repeatIndex++)
    {
      const std::size_t dstOffset = romData.size();

      romData.resize(dstOffset + secondPartSize);

      for (std::size_t byteIndex = 0; byteIndex < secondPartSize; byteIndex++)
        romData[dstOffset + byteIndex] = romData[secondPartOffset + byteIndex];
    }

    if (romData.size() != expandedSize)
      return false;
    // throw std::runtime_error("Unexpected expanded ROM size.");

    return true;
  }

  // SNES/SFC header specific stuff
  inline static const std::map<uint8_t, std::string> mapModes{
      {0x00, "LoROM"},
      {0x01, "HiROM"},
      {0x02, "S-DD1"},
      {0x03, "SA-1"},
      {0x05, "ExHiROM"},
      {0x0A, "SPC7110"},
  };

  inline static const std::map<uint8_t, std::string> chipsets{
      {0x00, "ROM only"},
      {0x01, "ROM + RAM"},
      {0x02, "ROM + RAM + battery"},
      // %????vvvv => use a mask
      {0x03, "ROM + coprocessor"},
      {0x04, "ROM + coprocessor + RAM"},
      {0x05, "ROM + coprocessor + RAM + battery"},
      {0x06, "ROM + coprocessor + battery"},
      // %vvvv???? => use a mask
      {0x00, "Coprocessor is DSP (DSP-1, 2, 3 or 4)"},
      {0x10, "Coprocessor is GSU (SuperFX)"},
      {0x20, "Coprocessor is OBC1"},
      {0x30, "Coprocessor is SA-1"},
      {0x40, "Coprocessor is S-DD1"},
      {0x50, "Coprocessor is S-RTC"},
      {0xE0, "Coprocessor is Other (Super Game Boy/Satellaview)"},
      {0xF0, "Coprocessor is Custom (specified with $FFBF)"},
      // When coprocessor is Custom, $FFBF selects from:
      //
      // $00 - SPC7110
      // $01 - ST010/ST011
      // $02 - ST018
      // $03 - CX4
  };

  inline static const std::map<uint8_t, std::string> countryCodes{
      {0x00, "Japan (J)"},
      {0x01, "North America (E)"},        // originally covered USA and Canada
      {0x02, "Europe (P)"},               // originally covered Europe, Oceania, and Asia
      {0x03, "Scandinavia (W)"},          // originally specific to Sweden
      {0x04, "Finland (undefined)"},      // per uCON64 source[1]
      {0x05, "Denmark (undefined)"},      // per uCON64 source[1]
      {0x06, "Europe (French only) (F)"}, //	originally specific to France
      {0x07, "Dutch (H)"},                // originally specific to the Netherlands
      {0x08, "Spanish (S)"},              // originally specific to Spain
      {0x09, "German (D)"},               // originally specific to Germany, Austria, and Switzerland
      {0x0A, "Italian (I)"},              // originally specific to Italy
      {0x0B, "Chinese (C)"},              // originally specific to Hong Kong and mainland China
      {0x0C, "Indonesia (undefined)"},    // per uCON64 source[1]
      {0x0D, "South Korea (K)"},
      {0x0E, "Common (A)"},
      {0x0F, "Canada (N)"},
      {0x10, "Brazil (B)"},
      {0x10, "Nintendo Gateway System (G)"},
      {0x11, "Australia (U)"},
      {0x12, "Other variation (X)"},
      {0x13, "Other variation (Y)"},
      {0x14, "Other variation (Z)"},
  };

  struct HeaderProperties
  {
    // struct SerialNumber {
    //   std::string software_type;
    //   std::string serialNumber;
    //   std::string revision;
    // };

    struct RomType
    {
      uint8_t byte;
      uint8_t speed;
      uint8_t mode;
    };

    struct Vectors65c816
    {
      uint16_t COP;
      uint16_t BRK;
      uint16_t ABORT;
      uint16_t NMI;
      uint16_t NONE;
      uint16_t IRQ;
    };

    struct Vectors6502
    {
      uint16_t COP;
      uint16_t NONE;
      uint16_t ABORT;
      uint16_t NMI;
      uint16_t RESET;
      uint16_t IRQ;
    };

    struct Vectors
    {
      Vectors65c816 _65c816;
      Vectors6502 _6502;
    };

    uint8_t bytes[64];
    bool isValid;

    std::string cartridgeTitle;
    RomType romType;
    uint8_t chipset;
    uint8_t romSize;
    uint8_t sramSize;
    uint8_t country;
    uint8_t developerId;
    uint8_t romVersion;
    uint16_t checksumComplement;
    uint16_t checksum;

    Vectors vectors;

    uint16_t fileChecksum;
    std::streamoff fileSize;

    std::string get_mapper_name()
    {
      return "auto";
    }

    std::string get_map_mode()
    {
      auto it = mapModes.find(this->romType.mode);
      if (it != mapModes.end())
        return mapModes.at(this->romType.mode);
      else
        return "Unknown map mode";
    }

    std::string get_chipset()
    {
      auto it = chipsets.find(this->chipset);
      if (it != chipsets.end())
        return chipsets.at(this->chipset);
      else
        return "Unknown map mode";
    }

    std::string get_country()
    {
      auto it = countryCodes.find(this->country);
      if (it != countryCodes.end())
        return countryCodes.at(this->country);
      else
        return "Unknown country code";
    }

    // return a value in KB
    uint32_t get_rom_size()
    {
      return 1 << this->romSize;
    }

    std::string get_rom_speed()
    {
      return this->romType.speed == 0 ? "SlowROM" : "FastROM";
    }

    // return a value in KB
    uint32_t get_ram_size()
    {
      return this->sramSize == 0 ? 0 : 1 << this->sramSize;
    }

    bool has_sram()
    {
      if (
          (this->chipset & 0x0F) == 0x01 ||
          (this->chipset & 0x0F) == 0x02 ||
          (this->chipset & 0x0F) == 0x04 ||
          (this->chipset & 0x0F) == 0x05)
        return true;
      else
        return false;
    }

    // return true or false
    bool has_battery()
    {
      if ((this->chipset & 0x0F) == 0x02 ||
          (this->chipset & 0x0F) == 0x05 ||
          (this->chipset & 0x0F) == 0x06)
        return true;

      return false;
    }

    // return true or false
    bool check_romChecksum()
    {
      if (this->checksum == this->fileChecksum)
        return true;
      else
        return false;
    }

    // return true or false
    bool check_rom_size()
    {
      if (this->get_rom_size() == (this->fileSize >> 10))
        return true;
      else
        return false;
    }
  };

  HeaderProperties header = {};

  /**
   * @brief Parse the header data from the current ROM file
   *
   * @return true if the header is valid
   * @return false if the header is not valid
   */
  bool parse_header(const std::string &filename)
  {
    const std::size_t SMC_HEADER_SIZE = 512;

    // reset header properties
    header = {};

    // read header from file
    std::ifstream rom(filename, std::fstream::binary);
    // TODO: check if file is valid

    // get length of file
    rom.seekg(0, rom.end);
    header.fileSize = rom.tellg();

    // copy ROM data to vector
    std::vector<uint8_t> romData;
    romData.reserve(header.fileSize);
    rom.seekg(0, rom.beg);
    while (true)
    {
      uint8_t byte = (uint8_t)rom.get();
      if (rom.eof())
        break;
      romData.push_back(byte);
    }
    rom.close();

    // try to find ROM header
    // lorom/hirom + headerless/headered combinations
    // taken from Mesen source code
    std::vector<uint32_t> baseAddresses = {0, 0x200, 0x8000, 0x8200, 0x400000, 0x400200, 0x408000, 0x408200};
    bool foundRomHeader = false;
    bool hasSmcHeader = false;
    bool isLoRom = true;
    bool isExRom = true;
    uint32_t headerOffset = 0;
    for (uint32_t baseAddress : baseAddresses)
    {
      uint16_t checksumComplement = 0;
      uint16_t checksum = 0;

      checksumComplement = romData[baseAddress + 0x7FC0 + 0x1C];
      checksumComplement |= romData[baseAddress + 0x7FC0 + 0x1D] << 8;
      checksum = romData[baseAddress + 0x7FC0 + 0x1E];
      checksum |= romData[baseAddress + 0x7FC0 + 0x1F] << 8;

      if (checksum + checksumComplement == 0xFFFF && checksum != 0 && checksumComplement != 0)
      {
        isLoRom = (baseAddress & 0x8000) == 0;
        isExRom = (baseAddress & 0x400000) != 0;
        hasSmcHeader = (baseAddress & 0x200) != 0;
        foundRomHeader = true;

        if (hasSmcHeader && romData.size() >= SMC_HEADER_SIZE)
          romData.erase(romData.begin(), romData.begin() + SMC_HEADER_SIZE);

        headerOffset = baseAddress + 0x7FC0;
        break;
      }
    }

    // not found?
    if (!foundRomHeader)
    {
      APP_LOG(LogTypes_Warning, "Couldn't find ROM header");
      return false;
    }

    // // check if it's HiROM/LoROM/ExHiRom
    // bool isLoRom = false;
    // bool isHiRom = false;
    // bool isExHiRom = false;
    // uint16_t headerStartAddress;
    // uint16_t checksumComplement;
    // uint16_t checksum;

    // // test for LoRom
    // if (header.fileSize < 0x7FFF)
    // {
    //   rom.close();
    //   return false;
    // }
    // rom.seekg(0x7FDC, rom.beg);
    // checksumComplement = (uint8_t)rom.get();
    // checksumComplement |= (uint8_t)rom.get() << 8;
    // checksum = (uint8_t)rom.get();
    // checksum |= (uint8_t)rom.get() << 8;
    // if (checksum + checksumComplement == 0xFFFF && checksum != 0 && checksumComplement != 0)
    // {
    //   isLoRom = true;
    //   headerStartAddress = 0x7FC0;
    // }
    // else
    // {
    //   isLoRom = false;
    // }

    // // test for HiROM (if needed)
    // if (!isLoRom)
    // {
    //   if (header.fileSize < 0xFFFF)
    //   {
    //     rom.close();
    //     return false;
    //   }
    //   rom.seekg(0xFFDC, rom.beg);
    //   checksumComplement = (uint8_t)rom.get();
    //   checksumComplement |= (uint8_t)rom.get() << 8;
    //   checksum = (uint8_t)rom.get();
    //   checksum |= (uint8_t)rom.get() << 8;
    //   if (checksum + checksumComplement == 0xFFFF && checksum != 0 && checksumComplement != 0)
    //   {
    //     isHiRom = true;
    //     headerStartAddress = 0xFFC0;
    //   }
    //   else
    //   {
    //     return false;
    //   }
    // }

    // skip vectors and copy header bytes
    for (size_t i = 0; i < 64; i++)
    {
      header.bytes[i] = romData[headerOffset + i];
    }

    // expand ROM data if needed
    if (!expand_snes_rom_mirroring(romData))
    {
      // TODO add error message
      return false;
    }

    // calculate rom file checksum
    header.fileChecksum = 0;
    uint32_t off = 0;
    for (std::size_t offset = 0; offset < romData.size(); offset++)
    {
      const uint8_t byte = romData[offset];
      if (offset == (headerOffset + 0x1C) || offset == (headerOffset + 0x1D))
        header.fileChecksum = header.fileChecksum + 0x00;
      else if (offset == (headerOffset + 0x1E) || offset == (headerOffset + 0x1F))
        header.fileChecksum = header.fileChecksum + 0xFF;
      else
        header.fileChecksum = header.fileChecksum + byte;
    }

    // cartridge title
    memset(this->buf, 0, sizeof(this->buf));
    for (size_t i = 0; i < 21; i++)
    {
      this->buf[i] = header.bytes[i];
    }
    header.cartridgeTitle.assign(this->buf, 21);

    // ROM type
    header.romType.byte = header.bytes[0x15];
    header.romType.mode = header.bytes[0x15] & 0x0F;
    header.romType.speed = header.bytes[0x15] & 0x10;

    // chipset
    header.chipset = header.bytes[0x16];

    // ROM size
    header.romSize = header.bytes[0x17];

    // RAM size
    header.sramSize = header.bytes[0x18];

    // country code
    header.country = header.bytes[0x19];

    // developer ID
    header.developerId = header.bytes[0x1A];

    // ROM version
    header.romVersion = header.bytes[0x1B];

    // checksum complement
    header.checksumComplement = header.bytes[0x1C] | (header.bytes[0x1D] << 8);

    // checksum
    header.checksum = header.bytes[0x1E] | (header.bytes[0x1F] << 8);

    // check if ROM checksum is valid
    if (!header.check_romChecksum())
    {
      APP_LOG(LogTypes_Warning, "Header ROM checksum is not valid");
      header.isValid = false;
    }
    else
    {
      header.isValid = true;
    }

    // check if ROM size is valid
    if (!header.check_rom_size())
    {
      // APP_LOG(LogTypes_Warning, "Header ROM size is not valid (header says %06X, file is %06X)", header.get_rom_size(), header.fileSize >> 10);
      APP_LOG(LogTypes_Warning, "Header ROM size is not valid (header says %i KiB, file is %i KiB)", header.get_rom_size(), header.fileSize >> 10);
      // header.isValid = false;
    }
    // else
    // {
    //   header.isValid = true;
    // }

    return true;
  }

  /**
   * @brief render header properties
   *
   */
  void render_header_content() override
  {
    if (!this->header.isValid)
      return ImGui::Text("The file header is not valid.");

    if (ImGui::BeginTable("SNES_header_table", 2, ImGuiTableFlags_Borders))
    {
      ImGui::TableSetupColumn("Property", ImGuiTableColumnFlags_WidthFixed, 250.0f);
      ImGui::TableSetupColumn("Value", ImGuiTableColumnFlags_WidthFixed, 250.0f);

      ImGui::TableHeadersRow();

      // cartridge title
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Cartridge Title");
      ImGui::TableSetColumnIndex(1);
      ImGui::TextUnformatted(this->header.cartridgeTitle.c_str());

      // country
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Country");
      ImGui::TableSetColumnIndex(1);
      ImGui::TextUnformatted(this->header.get_country().c_str());

      // map mode
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Map Mode");
      ImGui::TableSetColumnIndex(1);
      ImGui::TextUnformatted(this->header.get_map_mode().c_str());

      // ROM speed
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("ROM speed");
      ImGui::TableSetColumnIndex(1);
      ImGui::TextUnformatted(this->header.get_rom_speed().c_str());

      // chipset
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Chipset");
      ImGui::TableSetColumnIndex(1);
      ImGui::TextUnformatted(this->header.get_chipset().c_str());

      // ROM size
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("ROM Size");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("%d KiB", this->header.get_rom_size());

      // file size
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("File Size");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("%d KiB", this->header.fileSize / 1024);

      // SRAM
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("SRAM");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("%s", this->header.has_sram() ? "Yes" : "No");

      if (this->header.has_sram())
      {
        // Battery
        ImGui::TableNextRow();
        ImGui::TableSetColumnIndex(0);
        ImGui::TextUnformatted("Battery");
        ImGui::TableSetColumnIndex(1);
        ImGui::Text("%s", this->header.has_battery() ? "Yes" : "No");

        // SRAM size
        ImGui::TableNextRow();
        ImGui::TableSetColumnIndex(0);
        ImGui::TextUnformatted("SRAM Size");
        ImGui::TableSetColumnIndex(1);
        ImGui::Text("%d KiB", this->header.get_ram_size());
      }

      // ROM checksum
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("ROM checksum");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("0x%04x", this->header.checksum);

      // ROM checksum complement
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("ROM checksum complement");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("0x%04x", this->header.checksumComplement);

      ImGui::EndTable();
    }
  }
};

#endif
