#pragma once
#ifndef MENU_H
#define MENU_H

#include <functional>
#include <string>
#include <unordered_map>

namespace Menu
{

  struct t_MenuSubItem
  {
    bool active = false;
    std::function<void()> fn_render;
  };


  struct t_MenuItem
  {
    bool active = false;
    std::function<void()> fn_render;
    std::unordered_map<std::string, t_MenuSubItem> subMenu;
  };

  extern std::unordered_map<std::string, t_MenuItem> menu;

  void init();
  void render_tree(bool disabled);
  void render_content();

  void set_menu_active(const std::string &menu_name, bool value);
  void set_sub_menu_active(const std::string &menu_name, const std::string &sub_menu_name);

}

#endif
