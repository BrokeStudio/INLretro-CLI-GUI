#include <iostream>

#include <fstream>
#include <list>
#include <sstream>
#include <string>
#include <vector>

#include "AppLog.h"
#include "Console.h"
#include "GameBoy.h"
#include "Ini.h"
#include "Log.h"
#include "MegaDrive.h"
#include "Nes.h"
#include "Settings.h"

#if __APPLE__
#include "macos.h"
#endif

#define INI_FILENAME "INLretro.ini"

std::string &trim(std::string &s, char c, bool reverse = false)
{
  return reverse
             ? s.erase(s.find_last_not_of(c) + 1)
             : s.erase(0, s.find_first_not_of(c));
}

namespace Ini
{
  std::vector<t_Section> sections;

  /**
   * @brief Load INI file
   *
   * @return true
   * @return false
   */
  bool load()
  {

#define LINE_SIZE 256

    bool inSection = false;
    char line[LINE_SIZE];
    std::string sLine;
    t_Section section;
    section.clear();

    // try to open INI file

#ifdef __APPLE__

    std::string iniFilePath;
#ifdef _DIST
    if (getResourcesPath(iniFilePath) == -1)
#else
    if (getExecutablePath(iniFilePath) == -1)
#endif
    {
      APP_LOG(LogTypes_Error, L_INI "Couldn't get resources path");

      return false;
    }

    iniFilePath += INI_FILENAME;
#else
    std::string iniFilePath = INI_FILENAME;
#endif

    std::ifstream file(iniFilePath.c_str(), std::ifstream::in);
    if (!file)
    {
      APP_LOG(LogTypes_Error, L_INI "Couldn't open file: " INI_FILENAME);
      return false;
    }

    // parsing INI file content
    APP_LOG(LogTypes_Point, L_INI "Parsing file: " INI_FILENAME);

    while (!file.eof())
    {

      // Windows: CRLF (\r\n)
      // Linux: LF
      // Mac OS X >= 10.0: LF
      // Mac OS X < 10.0: CR

      file.getline(line, LINE_SIZE);

      if (line[strlen(line) - 1] == '\r')
      {
        line[strlen(line) - 1] = 0;
      }

      sLine = std::string(line);
      trim(sLine, ' ', false);
      if (sLine == "")
        continue; // ignore empty lines
      else if (sLine.front() == '#')
        continue;                                           // ignore comments
      else if (sLine.front() == '[' && sLine.back() == ']') // section
      {
        if (inSection)
        {
          sections.push_back(section);
          section.clear();
        }
        section.name = sLine;
        inSection = true;
      }
      else if (sLine.find("=") != std::string::npos) // property key=value
      {
        std::string key = sLine.substr(0, sLine.find("="));
        std::string value = sLine.substr(sLine.find("=") + 1);
        section.properties.push_back(std::pair<std::string, std::string>(key, value));
      }
    }

    // a bit hacky ...
    if (section.name != "")
    {
      sections.push_back(section);
      section.clear();
    }

    // close file and return
    file.close();
    APP_LOG(LogTypes_Success, L_INI "Config file parsed successfully");
    return true;
  }

  /**
   * @brief Save INI content
   *
   * @return true
   * @return false
   */
  bool save()
  {
    // try to open INI file

#if __APPLE__
    std::string iniFilePath;
    if (getResourcesPath(iniFilePath) == -1)
    {
      APP_LOG(LogTypes_Error, L_INI "Couldn't get resources path");
      return false;
    }
    iniFilePath += INI_FILENAME;
#else
    std::string iniFilePath = INI_FILENAME;
#endif

    std::ofstream file(iniFilePath.c_str(), std::ifstream::trunc);
    if (!file)
    {
      APP_LOG(LogTypes_Error, L_INI "Couldn't open file: " INI_FILENAME);
      return false;
    }

    // saving INI file
    APP_LOG(LogTypes_Point, L_INI "Saving file: " INI_FILENAME);

    for (auto &section : Ini::sections)
    {
      file << section.name << std::endl;
      for (auto &property : section.properties)
      {
        // update INI config from settings
        if (section.name == "[Settings]")
        {
          if (property.first == "theme")
            property.second = Settings::settings.theme;
          else if (property.first == "save_on_exit")
            property.second = Settings::settings.save_on_exit ? "true" : "false";
          else if (property.first == "firmware_update_script")
            property.second = Settings::settings.firmware_update_script;
#if defined _DEBUG
          else if (property.first == "imgui_demo")
            property.second = Settings::settings.imgui_demo ? "true" : "false";
#endif
        }
        file << property.first << "=" << property.second << std::endl;
      }
      file << std::endl;
    }

    // close file and return
    file.close();
    APP_LOG(LogTypes_Success, L_INI "File saved successfully");
    return true;
  }

  /**
   * @brief Parse INI data loaded
   *
   */
  void parse()
  {
    for (auto &section : Ini::sections)
    {
      if (section.name.substr(0, 9) == "[Console]")
      {
        t_Console console;
        console.clear();
        console.name = section.name.substr(10, section.name.rfind(']') - 10);
        for (auto &property : section.properties)
        {
          if (property.first == "short_name")
            console.short_name = property.second;
          else if (property.first == "full_name")
            console.full_name = property.second;
          else if (property.first == "actions")
          {
            std::stringstream ss(property.second);
            std::string str;
            while (std::getline(ss, str, ','))
            {
              if (str == "rom_dump")
                console.actions |= ConsoleActions_RomDump;
              else if (str == "rom_write")
                console.actions |= ConsoleActions_RomWrite;
              else if (str == "ram_dump")
                console.actions |= ConsoleActions_RamDump;
              else if (str == "ram_write")
                console.actions |= ConsoleActions_RamWrite;
            }
          }
          else if (property.first == "rom_file_ext")
            console.rom_file_ext = property.second;
          else if (property.first == "ram_file_ext")
            console.ram_file_ext = property.second;
          else if (property.first == "mapper")
          {
            Mapper mapper;
            std::stringstream ss(property.second);
            std::string str;
            std::getline(ss, str, ',');
            mapper.id = stoi(str);
            std::getline(ss, str, ',');
            mapper.name = str;
            std::getline(ss, str, ',');
            mapper.script_name = str;
            console.mappers.push_back(mapper);
          }
        }
        if (console.name == "nes" || console.name == "famicom" || console.name == "fc")
        {
          Console::add(new Nes(console));
          APP_LOG(LogTypes_Point, L_INI "Console '" + console.name + "' added");
        }
        else if (console.name == "dmg" || console.name == "gb" || console.name == "gbc")
        {
          Console::add(new GameBoy(console));
          APP_LOG(LogTypes_Point, L_INI "Console '" + console.name + "' added");
        }
        else if (console.name == "genesis" || console.name == "gen" || console.name == "megadrive" || console.name == "md")
        {
          Console::add(new MegaDrive(console));
          APP_LOG(LogTypes_Point, L_INI "Console '" + console.name + "' added");
        }
        else
        {
          Console::add(new Console(console));
          APP_LOG(LogTypes_Warning, L_INI "Console '" + console.name + "' added with basic support only");
        }
      }
      else if (section.name == "[Settings]")
      {
        for (auto &property : section.properties)
        {
          Settings::set_property(property.first, property.second);
        }
      }
      else
      {
        APP_LOG(LogTypes_Warning, L_INI "Don't know what to do with: " + section.name);
      }
    }
  }

}
