#pragma once
#ifndef GB_H
#define GB_H

#include <map>
#include <string>

#include "AppLog.h"
#include "Console.h"
#include "IconsFontAwesome6.h"
#include "imgui.h"

class GameBoy: public Console
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

      if(mappers.size() != 0)
      {
        int mapperIndex = get_mapper_index_by_mapper_name(header.get_mapper_name());
        if(mapperIndex == -1) {
          APP_LOG(LogTypes_Warning, "[%s] Mapper unknown: %s", this->short_name.c_str(), header.get_mapper_name().c_str());
        } else {
          rom_write_INLOptions.mapper_name = mappers[mapperIndex].script_name;
        }
      }
    }

  private:

    // Game Boy header specific stuff
    inline static const std::map<uint8_t, std::string> cartridgeTypeToMapper{
      {0x00, "ROM"}, // "ROM ONLY"
      {0x01, "MBC1"}, // "MBC1"
      {0x02, "MBC1"}, // "MBC1+RAM"
      {0x03, "MBC1"}, // "MBC1+RAM+BATTERY"
      {0x05, "MBC2"}, // "MBC2"
      {0x06, "MBC2"}, // "MBC2+BATTERY"
      {0x08, "ROM"}, // "ROM+RAM 9"
      {0x09, "ROM"}, // "ROM+RAM+BATTERY 9"
      {0x0B, "MMM01"}, // "MMM01"
      {0x0C, "MMM01"}, // "MMM01+RAM"
      {0x0D, "MMM01"}, // "MMM01+RAM+BATTERY"
      {0x0F, "MBC3"}, // "MBC3+TIMER+BATTERY"
      {0x10, "MBC3"}, // "MBC3+TIMER+RAM+BATTERY 10"
      {0x11, "MBC3"}, // "MBC3"
      {0x12, "MBC3"}, // "MBC3+RAM 10"
      {0x13, "MBC3"}, // "MBC3+RAM+BATTERY 10"
      {0x19, "MBC5"}, // "MBC5"
      {0x1A, "MBC5"}, // "MBC5+RAM"
      {0x1B, "MBC5"}, // "MBC5+RAM+BATTERY"
      {0x1C, "MBC5"}, // "MBC5+RUMBLE"
      {0x1D, "MBC5"}, // "MBC5+RUMBLE+RAM"
      {0x1E, "MBC5"}, // "MBC5+RUMBLE+RAM+BATTERY"
      {0x20, "MBC6"}, // "MBC6"
      {0x22, "MBC7"}, // "MBC7+SENSOR+RUMBLE+RAM+BATTERY"
      {0xFC, "POCKET CAMERA"}, // "POCKET CAMERA"
      {0xFD, "BANDAI TAMA5"}, // "BANDAI TAMA5"
      {0xFE, "HuC3"}, // "HuC3"
      {0xFF, "HuC1"}, // "HuC1+RAM+BATTERY"
    };

    struct HeaderProperties
    {
      uint8_t bytes[28];
      bool isValid;
      uint8_t cartridgeType;
      uint32_t romSize;
      uint32_t ramSize;
      uint32_t headerChecksum;
      uint32_t globalChecksum;
      uint32_t fileGlobalChecksum;

      std::string get_mapper_name() {
        return cartridgeTypeToMapper.at(this->cartridgeType);
      }

      // return a value in KB
      uint32_t get_rom_size() {
        uint32_t _romSize = 0;

              if(this->romSize == 0x00) _romSize = 32;
        else  if(this->romSize == 0x01) _romSize = 64;
        else  if(this->romSize == 0x02) _romSize = 128;
        else  if(this->romSize == 0x03) _romSize = 256;
        else  if(this->romSize == 0x04) _romSize = 512;
        else  if(this->romSize == 0x05) _romSize = 1024;
        else  if(this->romSize == 0x06) _romSize = 2048;
        else  if(this->romSize == 0x07) _romSize = 4096;
        else  if(this->romSize == 0x08) _romSize = 8192;
        else  if(this->romSize == 0x52) _romSize = 1152;
        else  if(this->romSize == 0x53) _romSize = 1280;
        else  if(this->romSize == 0x54) _romSize = 1536;

        return _romSize;
      }

      // return a value in KB
      uint8_t get_ram_size() {
        uint8_t _ramSize = 0;

        if(this->cartridgeType == 5 || this->cartridgeType == 6) {
          // MBC2 has 512x4bits of cart ram
          _ramSize = 1; // 0x200 // TODO: how to handle this? returning 1 for now
        }
        else {
                if(this->ramSize == 0x00) _ramSize = 0;
          else  if(this->ramSize == 0x01) _ramSize = 2;
          else  if(this->ramSize == 0x02) _ramSize = 8;
          else  if(this->ramSize == 0x03) _ramSize = 32;
          else  if(this->ramSize == 0x04) _ramSize = 128;
          else  if(this->ramSize == 0x05) _ramSize = 64;
        }

        if(this->cartridgeType == 0xFA || this->cartridgeType == 0xFB) {
          // RNBW has 8KB of FPGA-RAM
          _ramSize = _ramSize + 8;
        }

        return _ramSize;
      }

      // return true or false
      bool has_battery() {
        if
          (this->cartridgeType == 0x03 ||
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
      bool check_header_checksum() {
        uint32_t checksum = 0;
        for (size_t i = 0; i < 25; i++)
        {
          checksum = checksum - this->bytes[i] - 1;
        }
        checksum = checksum & 0xff;
        if(checksum == this->headerChecksum)
          return true;
        else
          return false;
      }

      // return true or false
      bool check_global_checksum() {
        if(this->globalChecksum == this->fileGlobalChecksum)
          return true;
        else
          return false;
      }

    };

    HeaderProperties header;

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

      // skip entry point and nintendo logo
      rom.seekg(0x134);

      for (size_t i = 0; i < 27; i++)
      {
        header.bytes[i] = (uint8_t)rom.get();
      }
      rom.close();

      header.cartridgeType = header.bytes[19];
      header.romSize = header.bytes[20];
      header.ramSize = header.bytes[21];
      header.headerChecksum = header.bytes[25];
      header.globalChecksum = ( header.bytes[26] << 8 ) | header.bytes[27];

      // check if header is valid
      if(!header.check_global_checksum()) {
        APP_LOG(LogTypes_Warning, "Header global checksum is not valid");
      }

      if(!header.check_header_checksum()) {
        APP_LOG(LogTypes_Warning, "Header checksum is not valid");
        header.isValid = false;
      } else {
        header.isValid = true;
      }

      return true;
    }

};

#endif
