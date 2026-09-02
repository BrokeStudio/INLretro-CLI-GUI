#pragma once
#ifndef NES_H
#define NES_H

#include <string>

#include "AppLog.h"
#include "Console.h"
#include "IconsFontAwesome6.h"
#include "imgui.h"

class Nes : public Console
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
    rom_write_INLOptions.prg_rom_size_kb = header.prgRomSize / 1024;
    rom_write_INLOptions.chr_rom_size_kb = header.chrRomSize / 1024;

    if (mappers.size() != 0)
    {
      int mapperIndex = get_mapper_index_by_mapper_id(header.mapperId);
      if (mapperIndex == -1)
      {
        APP_LOG(LogTypes_Warning, "[%s] Mapper unknown: %i", this->short_name.c_str(), header.mapperId);
      }
      else
      {
        rom_write_INLOptions.mapper_name = mappers[mapperIndex].script_name;
      }
      // TODO: handle case when mapper id cannot be found in mapper list...
    }
  }

private:
  // NES header specific stuff
  enum class HeaderVersion
  {
    Archaic,
    iNes0_7,
    iNes,
    NES2_0,
    COUNT
  };

  const char *const HeaderVersionTxt[(int)HeaderVersion::COUNT] = {
      "Archaic iNes",
      "iNes 0.7",
      "iNes",
      "NES 2.0"};

  enum class MirroringType
  {
    Horizontal,
    Vertical,
    ScreenAOnly,
    ScreenBOnly,
    FourScreens,
    COUNT
  };

  const char *const MirroringTypeTxt[(int)MirroringType::COUNT] = {
      "Horizontal",
      "Vertical",
      "Screen A Only",
      "Screen B Only",
      "Four Screens"};

  struct HeaderProperties
  {
    uint8_t bytes[16];
    bool isValid = false;
    HeaderVersion version;
    uint16_t mapperId;
    uint8_t submapperId;
    uint32_t prgRomSize;
    uint32_t prgRamSize;
    uint32_t chrRomSize;
    uint32_t chrRamSize;
    bool hasBattery;
    bool hasTrainer;
    MirroringType mirroringType;
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
    for (size_t i = 0; i < 16; i++)
    {
      header.bytes[i] = (uint8_t)rom.get();
    }
    rom.close();

    // check if header is valid
    if (header.bytes[0] != 'N' || header.bytes[1] != 'E' || header.bytes[2] != 'S' || header.bytes[3] != 0x1A)
      return false;
    header.isValid = true;

    // header version
    switch (header.bytes[7] & 0x0C)
    {
    case 0x08:
      // If byte 7 AND $0C = $08, and the size taking into account byte 9 does not exceed the actual size of the ROM image, then NES 2.0.
      //  TODO: check byte 9
      header.version = HeaderVersion::NES2_0;
      break;
    case 0x04:
      header.version = HeaderVersion::Archaic;
      break;
    case 0x00:
      if (header.bytes[12] == 0 && header.bytes[13] == 0 && header.bytes[14] == 0 && header.bytes[15] == 0)
        header.version = HeaderVersion::iNes;
      else
        header.version = HeaderVersion::Archaic;
      break;
    default:
      header.version = HeaderVersion::Archaic;
      break;
    }

    // mapper ID
    header.mapperId = (header.bytes[6] >> 4) | (header.bytes[7] & 0xF0);
    if (header.version == HeaderVersion::NES2_0)
      header.mapperId |= (header.bytes[8] & 0x0F) << 8;

    // submapper ID
    if (header.version == HeaderVersion::NES2_0)
      header.submapperId = header.bytes[6] >> 4;

    // battery
    header.hasBattery = header.bytes[6] & 0x02;

    // trainer
    header.hasTrainer = header.bytes[6] & 0x04;

    // mirroring
    switch (header.bytes[6] & 0x09)
    {
    case 0:
      header.mirroringType = MirroringType::Horizontal;
      break;
    case 1:
      header.mirroringType = MirroringType::Vertical;
      break;
    case 8:
      header.mirroringType = MirroringType::ScreenAOnly; // TODO: add a OneScreen option?
      break;
    case 9:
      header.mirroringType = MirroringType::FourScreens;
      break;
    }

    // PRG ROM size
    if (header.version == HeaderVersion::NES2_0)
    {
      if ((header.bytes[9] & 0x0F) == 0x0F)
      {
        // TODO...
      }
      else
        header.prgRomSize = (((header.bytes[9] & 0x0F) << 8) | header.bytes[4]) * 0x4000;
    }
    else
      header.prgRomSize = header.bytes[4] * 0x4000;

    // CHR ROM size
    if (header.version == HeaderVersion::NES2_0)
    {
      if ((header.bytes[9] & 0xF0) == 0xF0)
      {
        // TODO...
      }
      else
        header.chrRomSize = (((header.bytes[9] & 0xF0) << 4) | header.bytes[5]) * 0x2000;
    }
    else
      header.chrRomSize = header.bytes[5] * 0x2000;

    // PRG RAM size
    if (header.version == HeaderVersion::NES2_0)
    {
      if (header.hasBattery)
        header.prgRamSize = 64 << ((header.bytes[10] & 0xF0) >> 4);
      else
        header.prgRamSize = 64 << (header.bytes[10] & 0x0F);
    }
    else if (header.version == HeaderVersion::iNes)
      header.prgRamSize = header.bytes[8] * 0x2000;

    // CHR RAM size
    if (header.version == HeaderVersion::NES2_0)
      header.chrRamSize = 64 << (header.bytes[11] & 0x0F);
    else if (header.version == HeaderVersion::iNes)
      header.chrRamSize = header.chrRomSize == 0 ? 0x2000 : 0;

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

    if (ImGui::BeginTable("nes_header_table", 2, ImGuiTableFlags_Borders))
    {
      ImGui::TableSetupColumn("Property", ImGuiTableColumnFlags_WidthFixed, 150.0f);
      ImGui::TableSetupColumn("Value", ImGuiTableColumnFlags_WidthFixed, 150.0f);

      ImGui::TableHeadersRow();

      // header version
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Header version");
      ImGui::TableSetColumnIndex(1);
      ImGui::TextUnformatted(this->HeaderVersionTxt[(int)this->header.version]);

      // mapper number
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Mapper number");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("%i", this->header.mapperId);

      // submapper
      if (header.version == HeaderVersion::NES2_0)
      {
        ImGui::TableNextRow();
        ImGui::TableSetColumnIndex(0);
        ImGui::TextUnformatted("Submapper number");
        ImGui::TableSetColumnIndex(1);
        ImGui::Text("%i", this->header.submapperId);
      }

      // mirroring type
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Mirroring type");
      ImGui::TableSetColumnIndex(1);
      ImGui::TextUnformatted(this->MirroringTypeTxt[(int)this->header.mirroringType]);

      // PRG-ROM size
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("PRG-ROM size");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("%i KB", this->header.prgRomSize / 1024);

      // CHR-ROM size
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("CHR-ROM size");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("%i KB", this->header.chrRomSize / 1024);

      // PRG-RAM size
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("PRG-RAM size");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("%i KB", this->header.prgRamSize / 1024);

      // CHR-RAM size
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("CHR-RAM size");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("%i KB", this->header.chrRamSize / 1024);

      // battery
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Battery");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("%s", this->header.hasBattery ? "Yes" : "No");

      ImGui::EndTable();
    }
  }
};

#endif
