#pragma once
#ifndef INI_H
#define INI_H

#include <list>
#include <string>

#include "Console.h"

namespace Ini
{
  struct t_Section
  {
    std::string name;
    std::vector<std::pair<std::string, std::string>> properties;

    void clear()
    {
      name = "";
      properties.clear();
    }
  };

  extern std::vector<t_Section> sections;

  bool load();
  bool save();
  void parse();
}

#endif
