#pragma once
#ifndef SETTINGS_H
#define SETTINGS_H

#include <string>

#include "imgui.h"
#include "imgui_stdlib.h"

namespace Settings
{

  struct t_Settings
  {
    std::string theme;
    std::string firmware_update_script;
    int font;
    bool save_on_exit;
    bool imgui_demo;
  };

  extern t_Settings settings;

  void set_property(const std::string &key, const std::string &value);

  void render_flashers();
  void render_settings();
  void render_about();

}

#endif
