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
    //   std::string serial_number;
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

    std::string system_type;
    std::string copyright_release_date;
    std::string game_title_domestic;
    std::string game_title_overseas;
    // SerialNumber serial_number;
    std::string serial_number;
    uint16_t rom_checksum;
    std::string device_support;
    AddressRange rom_address_range;
    AddressRange ram_address_range;
    ExtraMemory extra_memory;
    std::string modem_support;
    std::string region_support;

    uint16_t file_checksum;
    std::streamoff file_size;

    std::string get_mapper_name()
    {
      return "32mb";
    }

    // return a value in KB
    uint32_t get_rom_size()
    {
      return (this->rom_address_range.end + 1 - this->rom_address_range.start) >> 10;
    }

    // return a value in KB
    uint32_t get_ram_size()
    {
      return (this->ram_address_range.end + 1 - this->ram_address_range.start) >> 10;
    }

    bool has_sram()
    {
      if (
          this->extra_memory.ra == "RA" &&
          this->extra_memory._x20 == 0x20 &&
          (this->extra_memory.type == 0xA0 || // no save  16-bit
           this->extra_memory.type == 0xB0 || // no save   8-bit  even addresses
           this->extra_memory.type == 0xB8 || // no save   8-bit  odd addresses
           this->extra_memory.type == 0xE0 || // save     16-bit
           this->extra_memory.type == 0xF0 || // save      8-bit  even addresses
           this->extra_memory.type == 0xF8    // save      8-bit  odd addresses
           ))
        return true;
      else
        return false;
    }

    // return true or false
    bool has_battery()
    {
      if (this->extra_memory.type == 0xE0 || // save     16-bit
          this->extra_memory.type == 0xF0 || // save      8-bit  even addresses
          this->extra_memory.type == 0xF8)   // save      8-bit  odd addresses
        return true;

      return false;
    }

    // return true or false
    bool check_rom_checksum()
    {
      if (this->rom_checksum == this->file_checksum)
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
    for (size_t i = 0; i < 16; i++)
    {
      this->buf[i] = header.bytes[i];
    }
    header.system_type.assign(this->buf, 16);

    // copyright and release_date
    for (size_t i = 0; i < 16; i++)
    {
      this->buf[i] = header.bytes[i + 0x10];
    }
    header.copyright_release_date.assign(this->buf, 16);

    // game title (domestic)
    for (size_t i = 0; i < 48; i++)
    {
      this->buf[i] = header.bytes[i + 0x20];
    }
    header.game_title_domestic.assign(this->buf, 48);

    // game title (overseas)
    for (size_t i = 0; i < 48; i++)
    {
      this->buf[i] = header.bytes[i + 0x50];
    }
    header.game_title_overseas.assign(this->buf, 48);

    // serial number
    for (size_t i = 0; i < 14; i++)
    {
      this->buf[i] = header.bytes[i + 0x80];
    }
    header.serial_number.assign(this->buf, 14);

    // rom checksum
    header.rom_checksum = header.bytes[0x8E] << 8;
    header.rom_checksum |= header.bytes[0x8F];

    // device support
    for (size_t i = 0; i < 16; i++)
    {
      this->buf[i] = header.bytes[i + 0x90];
    }
    header.device_support.assign(this->buf, 16);

    // rom address range
    header.rom_address_range.start = header.bytes[0xA0] << 24;
    header.rom_address_range.start |= header.bytes[0xA1] << 16;
    header.rom_address_range.start |= header.bytes[0xA2] << 8;
    header.rom_address_range.start |= header.bytes[0xA3];

    header.rom_address_range.end = header.bytes[0xA4] << 24;
    header.rom_address_range.end |= header.bytes[0xA5] << 16;
    header.rom_address_range.end |= header.bytes[0xA6] << 8;
    header.rom_address_range.end |= header.bytes[0xA7];

    // ram address range
    header.ram_address_range.start = header.bytes[0xA8] << 24;
    header.ram_address_range.start |= header.bytes[0xA9] << 16;
    header.ram_address_range.start |= header.bytes[0xAA] << 8;
    header.ram_address_range.start |= header.bytes[0xAB];

    header.ram_address_range.end = header.bytes[0xAC] << 24;
    header.ram_address_range.end |= header.bytes[0xAD] << 16;
    header.ram_address_range.end |= header.bytes[0xAE] << 8;
    header.ram_address_range.end |= header.bytes[0xAF];

    // extra memory
    this->buf[0] = header.bytes[0xB0];
    this->buf[1] = header.bytes[0xB1];
    header.extra_memory.ra.assign(this->buf, 2);
    header.extra_memory.type = header.bytes[0xB2];
    header.extra_memory._x20 = header.bytes[0xB3];

    header.extra_memory.start = header.bytes[0xB4] << 24;
    header.extra_memory.start |= header.bytes[0xB5] << 16;
    header.extra_memory.start |= header.bytes[0xB6] << 8;
    header.extra_memory.start |= header.bytes[0xB7];

    header.extra_memory.end = header.bytes[0xB8] << 24;
    header.extra_memory.end |= header.bytes[0xB9] << 16;
    header.extra_memory.end |= header.bytes[0xBA] << 8;
    header.extra_memory.end |= header.bytes[0xBB];

    // modem support
    for (size_t i = 0; i < 12; i++)
    {
      this->buf[i] = header.bytes[i + 0xBC];
    }
    header.device_support.assign(this->buf, 12);

    // region support
    for (size_t i = 0; i < 12; i++)
    {
      this->buf[i] = header.bytes[i + 0xF0];
    }
    header.device_support = std::string(this->buf);

    // check if ROM checksum is valid
    if (!header.check_rom_checksum())
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
};

#endif
