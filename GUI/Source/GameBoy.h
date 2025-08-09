#pragma once
#ifndef GB_H
#define GB_H

#include <map>
#include <string>

#include "AppLog.h"
#include "Console.h"
#include "IconsFontAwesome6.h"
#include "imgui.h"

class GameBoy : public Console
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
  // Game Boy header specific stuff

  inline static const std::map<std::string, std::string> newLicenseeCodes{
      {"00", "None"},
      {"01", "Nintendo Research & Development 1"},
      {"08", "Capcom"},
      {"13", "EA (Electronic Arts)"},
      {"18", "Hudson Soft"},
      {"19", "B-AI"},
      {"20", "KSS"},
      {"22", "Planning Office WADA"},
      {"24", "PCM Complete"},
      {"25", "San-X"},
      {"28", "Kemco"},
      {"29", "SETA Corporation"},
      {"30", "Viacom"},
      {"31", "Nintendo"},
      {"32", "Bandai"},
      {"33", "Ocean Software/Acclaim Entertainment"},
      {"34", "Konami"},
      {"35", "HectorSoft"},
      {"37", "Taito"},
      {"38", "Hudson Soft"},
      {"39", "Banpresto"},
      {"41", "Ubi Soft1"},
      {"42", "Atlus"},
      {"44", "Malibu Interactive"},
      {"46", "Angel"},
      {"47", "Bullet-Proof Software2"},
      {"49", "Irem"},
      {"50", "Absolute"},
      {"51", "Acclaim Entertainment"},
      {"52", "Activision"},
      {"53", "Sammy USA Corporation"},
      {"54", "Konami"},
      {"55", "Hi Tech Expressions"},
      {"56", "LJN"},
      {"57", "Matchbox"},
      {"58", "Mattel"},
      {"59", "Milton Bradley Company"},
      {"60", "Titus Interactive"},
      {"61", "Virgin Games Ltd.3"},
      {"64", "Lucasfilm Games4"},
      {"67", "Ocean Software"},
      {"69", "EA (Electronic Arts)"},
      {"70", "Infogrames5"},
      {"71", "Interplay Entertainment"},
      {"72", "Broderbund"},
      {"73", "Sculptured Software6"},
      {"75", "The Sales Curve Limited7"},
      {"78", "THQ"},
      {"79", "Accolade"},
      {"80", "Misawa Entertainment"},
      {"83", "lozc"},
      {"86", "Tokuma Shoten"},
      {"87", "Tsukuda Original"},
      {"91", "Chunsoft Co.8"},
      {"92", "Video System"},
      {"93", "Ocean Software/Acclaim Entertainment"},
      {"95", "Varie"},
      {"96", "Yonezawa/s’pal"},
      {"97", "Kaneko"},
      {"99", "Pack-In-Video"},
      {"9H", "Bottom Up"},
      {"A4", "Konami (Yu-Gi-Oh!)"},
      {"BL", "MTO"},
      {"DK", "Kodansha"}};

  inline static const std::map<uint8_t, std::string> oldLicenseeCodes{
      {0x00, "None"},
      {0x01, "Nintendo"},
      {0x08, "Capcom"},
      {0x09, "HOT-B"},
      {0x0A, "Jaleco"},
      {0x0B, "Coconuts Japan"},
      {0x0C, "Elite Systems"},
      {0x13, "EA (Electronic Arts)"},
      {0x18, "Hudson Soft"},
      {0x19, "ITC Entertainment"},
      {0x1A, "Yanoman"},
      {0x1D, "Japan Clary"},
      {0x1F, "Virgin Games Ltd.3"},
      {0x24, "PCM Complete"},
      {0x25, "San-X"},
      {0x28, "Kemco"},
      {0x29, "SETA Corporation"},
      {0x30, "Infogrames5"},
      {0x31, "Nintendo"},
      {0x32, "Bandai"},
      {0x33, "Indicates that the New licensee code should be used instead."},
      {0x34, "Konami"},
      {0x35, "HectorSoft"},
      {0x38, "Capcom"},
      {0x39, "Banpresto"},
      {0x3C, "Entertainment Interactive (stub)"},
      {0x3E, "Gremlin"},
      {0x41, "Ubi Soft1"},
      {0x42, "Atlus"},
      {0x44, "Malibu Interactive"},
      {0x46, "Angel"},
      {0x47, "Spectrum HoloByte"},
      {0x49, "Irem"},
      {0x4A, "Virgin Games Ltd.3"},
      {0x4D, "Malibu Interactive"},
      {0x4F, "U.S. Gold"},
      {0x50, "Absolute"},
      {0x51, "Acclaim Entertainment"},
      {0x52, "Activision"},
      {0x53, "Sammy USA Corporation"},
      {0x54, "GameTek"},
      {0x55, "Park Place13"},
      {0x56, "LJN"},
      {0x57, "Matchbox"},
      {0x59, "Milton Bradley Company"},
      {0x5A, "Mindscape"},
      {0x5B, "Romstar"},
      {0x5C, "Naxat Soft14"},
      {0x5D, "Tradewest"},
      {0x60, "Titus Interactive"},
      {0x61, "Virgin Games Ltd.3"},
      {0x67, "Ocean Software"},
      {0x69, "EA (Electronic Arts)"},
      {0x6E, "Elite Systems"},
      {0x6F, "Electro Brain"},
      {0x70, "Infogrames5"},
      {0x71, "Interplay Entertainment"},
      {0x72, "Broderbund"},
      {0x73, "Sculptured Software6"},
      {0x75, "The Sales Curve Limited7"},
      {0x78, "THQ"},
      {0x79, "Accolade15"},
      {0x7A, "Triffix Entertainment"},
      {0x7C, "MicroProse"},
      {0x7F, "Kemco"},
      {0x80, "Misawa Entertainment"},
      {0x83, "LOZC G."},
      {0x86, "Tokuma Shoten"},
      {0x8B, "Bullet-Proof Software2"},
      {0x8C, "Vic Tokai Corp.16"},
      {0x8E, "Ape Inc.17"},
      {0x8F, "I’Max18"},
      {0x91, "Chunsoft Co.8"},
      {0x92, "Video System"},
      {0x93, "Tsubaraya Productions"},
      {0x95, "Varie"},
      {0x96, "Yonezawa19/S’Pal"},
      {0x97, "Kemco"},
      {0x99, "Arc"},
      {0x9A, "Nihon Bussan"},
      {0x9B, "Tecmo"},
      {0x9C, "Imagineer"},
      {0x9D, "Banpresto"},
      {0x9F, "Nova"},
      {0xA1, "Hori Electric"},
      {0xA2, "Bandai"},
      {0xA4, "Konami"},
      {0xA6, "Kawada"},
      {0xA7, "Takara"},
      {0xA9, "Technos Japan"},
      {0xAA, "Broderbund"},
      {0xAC, "Toei Animation"},
      {0xAD, "Toho"},
      {0xAF, "Namco"},
      {0xB0, "Acclaim Entertainment"},
      {0xB1, "ASCII Corporation or Nexsoft"},
      {0xB2, "Bandai"},
      {0xB4, "Square Enix"},
      {0xB6, "HAL Laboratory"},
      {0xB7, "SNK"},
      {0xB9, "Pony Canyon"},
      {0xBA, "Culture Brain"},
      {0xBB, "Sunsoft"},
      {0xBD, "Sony Imagesoft"},
      {0xBF, "Sammy Corporation"},
      {0xC0, "Taito"},
      {0xC2, "Kemco"},
      {0xC3, "Square"},
      {0xC4, "Tokuma Shoten"},
      {0xC5, "Data East"},
      {0xC6, "Tonkin House"},
      {0xC8, "Koei"},
      {0xC9, "UFL"},
      {0xCA, "Ultra Games"},
      {0xCB, "VAP, Inc."},
      {0xCC, "Use Corporation"},
      {0xCD, "Meldac"},
      {0xCE, "Pony Canyon"},
      {0xCF, "Angel"},
      {0xD0, "Taito"},
      {0xD1, "SOFEL (Software Engineering Lab)"},
      {0xD2, "Quest"},
      {0xD3, "Sigma Enterprises"},
      {0xD4, "ASK Kodansha Co."},
      {0xD6, "Naxat Soft14"},
      {0xD7, "Copya System"},
      {0xD9, "Banpresto"},
      {0xDA, "Tomy"},
      {0xDB, "LJN"},
      {0xDD, "Nippon Computer Systems"},
      {0xDE, "Human Ent."},
      {0xDF, "Altron"},
      {0xE0, "Jaleco"},
      {0xE1, "Towa Chiki"},
      {0xE2, "Yutaka # Needs more info"},
      {0xE3, "Varie"},
      {0xE5, "Epoch"},
      {0xE7, "Athena"},
      {0xE8, "Asmik Ace Entertainment"},
      {0xE9, "Natsume"},
      {0xEA, "King Records"},
      {0xEB, "Atlus"},
      {0xEC, "Epic/Sony Records"},
      {0xEE, "IGS"},
      {0xF0, "A Wave"},
      {0xF3, "Extreme Entertainment"},
      {0xFF, "LJN"},
  };

  inline static const std::map<uint8_t, std::string> cartridgeTypeToMapper{
      {0x00, "ROM"},           // "ROM ONLY"
      {0x01, "MBC1"},          // "MBC1"
      {0x02, "MBC1"},          // "MBC1+RAM"
      {0x03, "MBC1"},          // "MBC1+RAM+BATTERY"
      {0x05, "MBC2"},          // "MBC2"
      {0x06, "MBC2"},          // "MBC2+BATTERY"
      {0x08, "ROM"},           // "ROM+RAM 9"
      {0x09, "ROM"},           // "ROM+RAM+BATTERY 9"
      {0x0B, "MMM01"},         // "MMM01"
      {0x0C, "MMM01"},         // "MMM01+RAM"
      {0x0D, "MMM01"},         // "MMM01+RAM+BATTERY"
      {0x0F, "MBC3"},          // "MBC3+TIMER+BATTERY"
      {0x10, "MBC3"},          // "MBC3+TIMER+RAM+BATTERY 10"
      {0x11, "MBC3"},          // "MBC3"
      {0x12, "MBC3"},          // "MBC3+RAM 10"
      {0x13, "MBC3"},          // "MBC3+RAM+BATTERY 10"
      {0x19, "MBC5"},          // "MBC5"
      {0x1A, "MBC5"},          // "MBC5+RAM"
      {0x1B, "MBC5"},          // "MBC5+RAM+BATTERY"
      {0x1C, "MBC5"},          // "MBC5+RUMBLE"
      {0x1D, "MBC5"},          // "MBC5+RUMBLE+RAM"
      {0x1E, "MBC5"},          // "MBC5+RUMBLE+RAM+BATTERY"
      {0x20, "MBC6"},          // "MBC6"
      {0x22, "MBC7"},          // "MBC7+SENSOR+RUMBLE+RAM+BATTERY"
      {0xFC, "POCKET CAMERA"}, // "POCKET CAMERA"
      {0xFD, "BANDAI TAMA5"},  // "BANDAI TAMA5"
      {0xFE, "HuC3"},          // "HuC3"
      {0xFF, "HuC1"},          // "HuC1+RAM+BATTERY"
  };

  inline static uint8_t nintendoLogoData[] = {
      0xCE, 0xED, 0x66, 0x66, 0xCC, 0x0D, 0x00, 0x0B, 0x03, 0x73, 0x00, 0x83, 0x00, 0x0C, 0x00, 0x0D,
      0x00, 0x08, 0x11, 0x1F, 0x88, 0x89, 0x00, 0x0E, 0xDC, 0xCC, 0x6E, 0xE6, 0xDD, 0xDD, 0xD9, 0x99,
      0xBB, 0xBB, 0x67, 0x63, 0x6E, 0x0E, 0xEC, 0xCC, 0xDD, 0xDC, 0x99, 0x9F, 0xBB, 0xB9, 0x33, 0x3E};

  struct HeaderProperties
  {
    uint8_t bytes[80];
    bool isValid;
    uint32_t entryPoint;          // 0100-0103
    bool nintendoLogoValid;       // 0104-0133
    uint32_t manufacturerCode;    // 013f-0142
    uint8_t cgbFlag;              // 0143
    std::string newLicenseeCode;  // 0144-0145
    uint8_t sgbFlag;              // 0146
    uint8_t cartridgeType;        // 0147
    uint8_t romSize;              // 0148
    uint8_t ramSize;              // 0149
    uint8_t destinationCode;      // 014a
    uint8_t oldLicenseeCode;      // 014b
    uint8_t maskRomVersionNumber; // 014c
    uint8_t headerChecksum;       // 014d
    uint16_t globalChecksum;      // 014e-014f
    uint16_t fileGlobalChecksum;

    std::string get_title() // 0134-0143
    {
      char buf[16] = {0};
      std::string title = "";
      for (size_t i = 0; i < 16; i++)
      {
        buf[i] = bytes[0x34 + i];
      }
      title.assign(buf);
      return title;
    }

    std::string get_new_licensee_code()
    {
      auto it = newLicenseeCodes.find(this->newLicenseeCode.substr(0, 2));
      if (it != newLicenseeCodes.end())
        return newLicenseeCodes.at(this->newLicenseeCode.substr(0, 2));
      else
        return "Unknown licensee code";
    }

    std::string get_old_licensee_code()
    {
      auto it = oldLicenseeCodes.find(this->oldLicenseeCode);
      if (it != oldLicenseeCodes.end())
        return oldLicenseeCodes.at(this->oldLicenseeCode);
      else
        return "Unknown licensee code";
    }

    std::string get_mapper_name()
    {
      auto it = cartridgeTypeToMapper.find(this->cartridgeType);
      if (it != cartridgeTypeToMapper.end())
        return cartridgeTypeToMapper.at(this->cartridgeType);
      else
        return "Unknown cartridge type";
    }

    // return a value in KB
    uint32_t get_rom_size()
    {
      uint32_t _romSize = 0;

      if (this->romSize == 0x00)
        _romSize = 32;
      else if (this->romSize == 0x01)
        _romSize = 64;
      else if (this->romSize == 0x02)
        _romSize = 128;
      else if (this->romSize == 0x03)
        _romSize = 256;
      else if (this->romSize == 0x04)
        _romSize = 512;
      else if (this->romSize == 0x05)
        _romSize = 1024;
      else if (this->romSize == 0x06)
        _romSize = 2048;
      else if (this->romSize == 0x07)
        _romSize = 4096;
      else if (this->romSize == 0x08)
        _romSize = 8192;
      else if (this->romSize == 0x52)
        _romSize = 1152;
      else if (this->romSize == 0x53)
        _romSize = 1280;
      else if (this->romSize == 0x54)
        _romSize = 1536;

      return _romSize;
    }

    // return a value in KB
    uint8_t get_ram_size()
    {
      uint8_t _ramSize = 0;

      if (this->cartridgeType == 5 || this->cartridgeType == 6)
      {
        // MBC2 has 512x4bits of cart ram
        _ramSize = 1; // 0x200 // TODO: how to handle this? returning 1 for now
      }
      else
      {
        if (this->ramSize == 0x00)
          _ramSize = 0;
        else if (this->ramSize == 0x01)
          _ramSize = 2;
        else if (this->ramSize == 0x02)
          _ramSize = 8;
        else if (this->ramSize == 0x03)
          _ramSize = 32;
        else if (this->ramSize == 0x04)
          _ramSize = 128;
        else if (this->ramSize == 0x05)
          _ramSize = 64;
      }

      if (this->cartridgeType == 0xFA || this->cartridgeType == 0xFB)
      {
        // RNBW has 8KB of FPGA-RAM
        _ramSize = _ramSize + 8;
      }

      return _ramSize;
    }

    // return true or false
    bool has_battery()
    {
      if (this->cartridgeType == 0x03 ||
          this->cartridgeType == 0x06 ||
          this->cartridgeType == 0x09 ||
          this->cartridgeType == 0x0D ||
          this->cartridgeType == 0x0F ||
          this->cartridgeType == 0x10 ||
          this->cartridgeType == 0x13 ||
          this->cartridgeType == 0x1B ||
          this->cartridgeType == 0x1E ||
          this->cartridgeType == 0x22 ||
          this->cartridgeType == 0xFF)
        return true;

      return false;
    }

    // return true or false
    bool check_header_checksum()
    {
      uint32_t checksum = 0;
      for (size_t i = 0x34; i < 0x4d; i++)
      {
        checksum = checksum - this->bytes[i] - 1;
      }
      checksum = checksum & 0xff;
      if (checksum == this->headerChecksum)
        return true;
      else
        return false;
    }

    // return true or false
    bool check_global_checksum()
    {
      if (this->globalChecksum == this->fileGlobalChecksum)
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

    rom.seekg(0x100);

    for (size_t i = 0; i < 80; i++)
    {
      header.bytes[i] = (uint8_t)rom.get();
    }

    // calculate global checksum
    rom.seekg(0);
    header.fileGlobalChecksum = 0;
    uint32_t off = 0;
    while (true)
    {
      uint8_t byte = (uint8_t)rom.get();
      if (rom.eof())
        break;
      if (off != 0x14e && off != 0x14f)
        header.fileGlobalChecksum = header.fileGlobalChecksum + byte;
      off++;
    }

    // close file
    rom.close();

    header.entryPoint = (header.bytes[0x00] << 24) | (header.bytes[0x01] << 16) | (header.bytes[0x02] << 8) | (header.bytes[0x03] << 0);
    header.nintendoLogoValid = true;
    for (size_t i = 0; i < sizeof(nintendoLogoData); i++)
    {
      if (header.bytes[4 + i] != nintendoLogoData[i])
      {
        header.nintendoLogoValid = false;
        break;
      }
    }
    header.manufacturerCode = (header.bytes[0x3f] << 24) | (header.bytes[0x40] << 16) | (header.bytes[0x41] << 8) | (header.bytes[0x42] << 0);
    header.cgbFlag = header.bytes[0x43];

    this->buf[0] = header.bytes[0x44];
    this->buf[1] = header.bytes[0x45];
    this->buf[2] = 0x00;
    header.newLicenseeCode.assign(this->buf, 16);

    header.sgbFlag = header.bytes[0x46];
    header.cartridgeType = header.bytes[0x47];
    header.romSize = header.bytes[0x48];
    header.ramSize = header.bytes[0x49];
    header.destinationCode = header.bytes[0x4a];
    header.oldLicenseeCode = header.bytes[0x4b];
    header.maskRomVersionNumber = header.bytes[0x4c];
    header.headerChecksum = header.bytes[0x4d];
    header.globalChecksum = (header.bytes[0x4e] << 8) | (header.bytes[0x4f] << 0);

    // check if header is valid
    if (!header.check_global_checksum())
    {
      APP_LOG(LogTypes_Warning, "Header global checksum is not valid");
    }

    if (!header.check_header_checksum())
    {
      APP_LOG(LogTypes_Warning, "Header checksum is not valid");
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
  void render_header_content() override
  {
    if (!this->header.isValid)
      return ImGui::Text("The file header is not valid.");

    if (ImGui::BeginTable("md_header_table", 2, ImGuiTableFlags_Borders))
    {
      ImGui::TableSetupColumn("Property", ImGuiTableColumnFlags_WidthFixed, 250.0f);
      ImGui::TableSetupColumn("Value", ImGuiTableColumnFlags_WidthFixed, 250.0f);

      ImGui::TableHeadersRow();

      // Title
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Title");
      ImGui::TableSetColumnIndex(1);
      ImGui::TextUnformatted(this->header.get_title().c_str());

      // Cartridge type
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Cartridge type");
      ImGui::TableSetColumnIndex(1);
      ImGui::TextUnformatted(this->header.get_mapper_name().c_str());

      // ROM size
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("ROM size");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("%i KB", this->header.get_rom_size());

      // RAM size
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("RAM size");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("%i KB", this->header.get_ram_size());

      // SRAM
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("SRAM");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("%s", this->header.get_ram_size() != 0 ? "Yes" : "No");

      // Battery
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Battery");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("%s", this->header.has_battery() ? "Yes" : "No");

      // Nintendo logo
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Nintendo logo");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("%s", this->header.nintendoLogoValid ? "Yes" : "No");

      // CGB flag
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("CGB flag");
      ImGui::TableSetColumnIndex(1);
      if (this->header.cgbFlag == 0x80)
        ImGui::TextUnformatted("CGB mode");
      else if (this->header.cgbFlag == 0xC0)
        ImGui::TextUnformatted("CGB only");
      else
        ImGui::TextUnformatted("Non-CGB mode");
      ImGui::SameLine();
      ImGui::Text("(0x%02x)", this->header.cgbFlag);

      // New licensee code
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("New licensee code");
      ImGui::TableSetColumnIndex(1);
      ImGui::TextUnformatted(this->header.get_new_licensee_code().c_str());
      ImGui::Text("(%s)", this->header.newLicenseeCode.c_str());

      // SGB support
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("SGB support");
      ImGui::TableSetColumnIndex(1);
      if (this->header.cgbFlag == 0x03)
        ImGui::TextUnformatted("Yes");
      else
        ImGui::TextUnformatted("No");
      ImGui::SameLine();
      ImGui::Text("(0x%02x)", this->header.cgbFlag);

      // Destination code
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Destination code");
      ImGui::TableSetColumnIndex(1);
      if (this->header.destinationCode == 0x00)
        ImGui::TextUnformatted("Japan (and possibly overseas)");
      else if (this->header.destinationCode == 0x01)
        ImGui::TextUnformatted("Overseas only");
      else
        ImGui::TextUnformatted("Unknown");

      // Old licensee code
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Old licensee code");
      ImGui::TableSetColumnIndex(1);
      ImGui::TextWrapped("%s", this->header.get_old_licensee_code().c_str());
      ImGui::Text("(0x%02x)", this->header.oldLicenseeCode);

      // Mask ROM version number
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Mask ROM version number");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("0x%02x", this->header.maskRomVersionNumber);

      // Header checksum
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Header checksum");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("0x%02x (%s)", this->header.headerChecksum, this->header.check_header_checksum() ? "valid" : "invalid");

      // Global checksum
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Global checksum");
      ImGui::TableSetColumnIndex(1);
      ImGui::Text("0x%04x (%s)", this->header.globalChecksum, this->header.check_global_checksum() ? "valid" : "invalid");

      ImGui::EndTable();
    }
  }
};

#endif
