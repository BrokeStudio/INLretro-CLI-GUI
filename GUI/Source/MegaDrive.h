#pragma once
#ifndef MD_H
#define MD_H

#include <map>
#include <string>

#include "AppLog.h"
#include "Console.h"
#include "IconsFontAwesome6.h"
#include "imgui.h"

class MegaDrive : public Console
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
      rom_write_INLOptions.rom_size_kb = static_cast<int>(header.file_size >> 10);
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
  // Mega Drive/Genesis header specific stuff
  inline static const std::map<std::string, std::string> softwareTypes{
      {"GM", "Game"},
      {"AI", "Aid"},
      {"OS", "Boot ROM (TMSS)"},
      {"BR", "Boot ROM (Sega CD)"},
  };

  inline static const std::map<std::string, std::string> deviceTypes{
      {"J", "3-button controller"},
      {"6", "6-button controller"},
      {"0", "Master System controller"},
      {"A", "Analog joystick"},
      {"4", "Multitap"},
      {"G", "Lightgun"},
      {"L", "Activator"},
      {"M", "Mouse"},
      {"B", "Trackball"},
      {"T", "Tablet"},
      {"V", "Paddle"},
      {"K", "Keyboard or keypad"},
      {"R", "RS-232"},
      {"P", "Printer"},
      {"C", "CD-ROM (Sega CD)"},
      {"F", "Floppy drive"},
      {"D", "Download?"},
  };

  inline static const std::map<std::string, std::string> regionTypes{
      {"J", "Japan"},
      {"U", "Americas"},
      {"E", "Europe"},
  };

  struct HeaderProperties
  {
    // struct SerialNumber {
    //   std::string software_type;
    //   std::string serialNumber;
    //   std::string revision;
    // };

    struct AddressRange
    {
      uint32_t start;
      uint32_t end;
    };

    struct ExtraMemory
    {
      std::string ra;
      uint8_t type;
      uint8_t _x20;
      uint32_t start;
      uint32_t end;
    };

    uint8_t bytes[256];
    bool isValid;

    std::string systemType;
    std::string copyrightReleaseDate;
    std::string gameTitleDomestic;
    std::string gameTitleOverseas;
    // SerialNumber serialNumber;
    std::string serialNumber;
    uint16_t romChecksum;
    std::string deviceSupport;
    AddressRange romAddressRange;
    AddressRange ramAddressRange;
    ExtraMemory extraMemory;
    std::string modemSupport;
    std::string regionSupport;

    uint16_t file_checksum;
    std::streamoff file_size;

    std::string get_mapper_name()
    {
      return "32mb";
    }

    std::string get_software_type()
    {
      auto it = softwareTypes.find(this->serialNumber.substr(0, 2));
      if (it != softwareTypes.end())
        return softwareTypes.at(this->serialNumber.substr(0, 2));
      else
        return "Unknown software type";
    }

    std::string get_device_type()
    {
      auto it = deviceTypes.find(this->deviceSupport.substr(0, 1));
      if (it != deviceTypes.end())
        return deviceTypes.at(this->deviceSupport.substr(0, 1));
      else
        return "Unknown device type";
    }

    std::string get_regions()
    {
      std::string regions = "";
      for (size_t i = 0; i < 3; i++)
      {
        auto it = regionTypes.find(this->regionSupport.substr(i, 1));
        if (it != regionTypes.end())
        {
          if (i)
            regions += ", ";
          regions += regionTypes.at(this->regionSupport.substr(i, 1));
        }
      }
      return regions;
    }

    // return a value in KB
    uint32_t get_rom_size()
    {
      return (this->romAddressRange.end + 1 - this->romAddressRange.start) >> 10;
    }

    // return a value in KB
    uint32_t get_ram_size()
    {
      return (this->ramAddressRange.end + 1 - this->ramAddressRange.start) >> 10;
    }

    bool has_sram()
    {
      if (
          this->extraMemory.ra == "RA" &&
          this->extraMemory._x20 == 0x20 &&
          (this->extraMemory.type == 0xA0 || // no save  16-bit
           this->extraMemory.type == 0xB0 || // no save   8-bit  even addresses
           this->extraMemory.type == 0xB8 || // no save   8-bit  odd addresses
           this->extraMemory.type == 0xE0 || // save     16-bit
           this->extraMemory.type == 0xF0 || // save      8-bit  even addresses
           this->extraMemory.type == 0xF8    // save      8-bit  odd addresses
           ))
        return true;
      else
        return false;
    }

    // return true or false
    bool has_battery()
    {
      if (this->extraMemory.type == 0xE0 || // save     16-bit
          this->extraMemory.type == 0xF0 || // save      8-bit  even addresses
          this->extraMemory.type == 0xF8)   // save      8-bit  odd addresses
        return true;

      return false;
    }

    // return true or false
    bool check_romChecksum()
    {
      if (this->romChecksum == this->file_checksum)
        return true;
      else
        return false;
    }

    // return true or false
    bool check_rom_size()
    {
      if (this->get_rom_size() == (this->file_size >> 10))
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
    // reset header properties
    header = {};

    // read header from file
    std::ifstream rom(filename, std::fstream::binary);
    // TODO: check if file is valid

    // get length of file
    rom.seekg(0, rom.end);
    header.file_size = rom.tellg();
    rom.seekg(0, rom.beg);

    // skip vectors and copy header bytes
    rom.seekg(0x100, rom.beg);
    for (size_t i = 0; i < 256; i++)
    {
      header.bytes[i] = (uint8_t)rom.get();
    }

    // calculate rom file checksum
    uint16_t checksum = 0;
    // rom.seekg(0x200, rom.beg);
    while (true)
    {
      uint16_t val = (uint8_t)rom.get() << 8;
      val |= (uint8_t)rom.get();
      if (rom.eof())
        break;
      checksum += val;
    }
    header.file_checksum = checksum;

    rom.close();

    // system type
    memset(this->buf, 0, sizeof(this->buf));
    for (size_t i = 0; i < 16; i++)
    {
      this->buf[i] = header.bytes[i];
    }
    header.systemType.assign(this->buf, 16);

    // copyright and release_date
    memset(this->buf, 0, sizeof(this->buf));
    for (size_t i = 0; i < 16; i++)
    {
      this->buf[i] = header.bytes[i + 0x10];
    }
    header.copyrightReleaseDate.assign(this->buf, 16);

    // game title (domestic)
    memset(this->buf, 0, sizeof(this->buf));
    for (size_t i = 0; i < 48; i++)
    {
      this->buf[i] = header.bytes[i + 0x20];
    }
    header.gameTitleDomestic.assign(this->buf, 48);

    // game title (overseas)
    memset(this->buf, 0, sizeof(this->buf));
    for (size_t i = 0; i < 48; i++)
    {
      this->buf[i] = header.bytes[i + 0x50];
    }
    header.gameTitleOverseas.assign(this->buf, 48);

    // serial number
    memset(this->buf, 0, sizeof(this->buf));
    for (size_t i = 0; i < 14; i++)
    {
      this->buf[i] = header.bytes[i + 0x80];
    }
    header.serialNumber.assign(this->buf, 14);

    // rom checksum
    header.romChecksum = header.bytes[0x8E] << 8;
    header.romChecksum |= header.bytes[0x8F];

    // device support
    memset(this->buf, 0, sizeof(this->buf));
    for (size_t i = 0; i < 16; i++)
    {
      this->buf[i] = header.bytes[i + 0x90];
    }
    header.deviceSupport.assign(this->buf, 16);

    // rom address range
    header.romAddressRange.start = header.bytes[0xA0] << 24;
    header.romAddressRange.start |= header.bytes[0xA1] << 16;
    header.romAddressRange.start |= header.bytes[0xA2] << 8;
    header.romAddressRange.start |= header.bytes[0xA3];

    header.romAddressRange.end = header.bytes[0xA4] << 24;
    header.romAddressRange.end |= header.bytes[0xA5] << 16;
    header.romAddressRange.end |= header.bytes[0xA6] << 8;
    header.romAddressRange.end |= header.bytes[0xA7];

    // ram address range
    header.ramAddressRange.start = header.bytes[0xA8] << 24;
    header.ramAddressRange.start |= header.bytes[0xA9] << 16;
    header.ramAddressRange.start |= header.bytes[0xAA] << 8;
    header.ramAddressRange.start |= header.bytes[0xAB];

    header.ramAddressRange.end = header.bytes[0xAC] << 24;
    header.ramAddressRange.end |= header.bytes[0xAD] << 16;
    header.ramAddressRange.end |= header.bytes[0xAE] << 8;
    header.ramAddressRange.end |= header.bytes[0xAF];

    // extra memory
    this->buf[0] = header.bytes[0xB0];
    this->buf[1] = header.bytes[0xB1];
    header.extraMemory.ra.assign(this->buf, 2);
    header.extraMemory.type = header.bytes[0xB2];
    header.extraMemory._x20 = header.bytes[0xB3];

    header.extraMemory.start = header.bytes[0xB4] << 24;
    header.extraMemory.start |= header.bytes[0xB5] << 16;
    header.extraMemory.start |= header.bytes[0xB6] << 8;
    header.extraMemory.start |= header.bytes[0xB7];

    header.extraMemory.end = header.bytes[0xB8] << 24;
    header.extraMemory.end |= header.bytes[0xB9] << 16;
    header.extraMemory.end |= header.bytes[0xBA] << 8;
    header.extraMemory.end |= header.bytes[0xBB];

    // modem support
    memset(this->buf, 0, sizeof(this->buf));
    for (size_t i = 0; i < 12; i++)
    {
      this->buf[i] = header.bytes[i + 0xBC];
    }
    header.modemSupport.assign(this->buf, 12);

    // region support
    memset(this->buf, 0, sizeof(this->buf));
    for (size_t i = 0; i < 12; i++)
    {
      this->buf[i] = header.bytes[i + 0xF0];
    }
    header.regionSupport = std::string(this->buf);

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
      // APP_LOG(LogTypes_Warning, "Header ROM size is not valid (header says %06X, file is %06X)", header.get_rom_size(), header.file_size >> 10);
      APP_LOG(LogTypes_Warning, "Header ROM size is not valid (header says %i KiB, file is %i KiB)", header.get_rom_size(), header.file_size >> 10);
      header.isValid = false;
    }
    else
    {
      header.isValid = true;
    }

    return true;
  }

  /**
   * @brief render header properties
   *
   */
  void render_header_content()
  {
    if (!this->header.isValid)
      return ImGui::Text("The file header is not valid.");

    if (ImGui::BeginTable("md_header_table", 2, ImGuiTableFlags_Borders))
    {
      ImGui::TableSetupColumn("Property", ImGuiTableColumnFlags_WidthFixed, 250.0f);
      ImGui::TableSetupColumn("Value", ImGuiTableColumnFlags_WidthFixed, 250.0f);

      ImGui::TableHeadersRow();

      // system type
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("System type");
      ImGui::TableSetColumnIndex(1);
      ImGui::TextUnformatted(this->header.systemType.c_str());

      // Copyright and release date
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Copyright and release date");
      ImGui::TableSetColumnIndex(1);
      ImGui::TextUnformatted(this->header.copyrightReleaseDate.c_str());

      // Game title (domestic)
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Game title (domestic)");
      ImGui::TableSetColumnIndex(1);
      ImGui::TextUnformatted(this->header.gameTitleDomestic.c_str());

      // Game title (overseas)
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Game title (overseas)");
      ImGui::TableSetColumnIndex(1);
      ImGui::TextUnformatted(this->header.gameTitleOverseas.c_str());

      // Serial number
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Serial number");
      ImGui::TableSetColumnIndex(1);
      ImGui::TextUnformatted(this->header.serialNumber.c_str());

      // Software type
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Software type");
      ImGui::TableSetColumnIndex(1);
      ImGui::TextUnformatted(this->header.get_software_type().c_str());

      // ROM checksum
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("ROM checksum");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("0x%04x", this->header.romChecksum);

      // Device support
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Device support");
      ImGui::TableSetColumnIndex(1);
      ImGui::TextUnformatted(this->header.deviceSupport.c_str());

      // Device type
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Device type");
      ImGui::TableSetColumnIndex(1);
      ImGui::TextUnformatted(this->header.get_device_type().c_str());

      // ROM address range
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("ROM address range");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("0x%08x", this->header.romAddressRange);

      // RAM address range
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("RAM address range");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("0x%08x", this->header.ramAddressRange);

      // SRAM
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("SRAM");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("%s", this->header.has_sram() ? "Yes" : "No");

      // Battery
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Battery");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("%s", this->header.has_battery() ? "Yes" : "No");

      // Modem support
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Modem support");
      ImGui::TableSetColumnIndex(1);
      ImGui::TextUnformatted(this->header.modemSupport.c_str());

      // Region support
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Region support");
      ImGui::TableSetColumnIndex(1);
      ImGui::TextUnformatted(this->header.regionSupport.c_str());

      // Region type
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Region type");
      ImGui::TableSetColumnIndex(1);
      ImGui::TextUnformatted(this->header.get_regions().c_str());
      ImGui::Text("(%s)", this->header.regionSupport.c_str());

      ImGui::EndTable();
    }
  }
};

#endif
