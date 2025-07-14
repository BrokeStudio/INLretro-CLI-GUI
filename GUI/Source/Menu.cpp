#include "imgui.h"
#include "IconsFontAwesome6.h"

// #include "AppLog.h"
#include "Console.h"
#include "Menu.h"
#include "Settings.h"

namespace Menu
{

  std::unordered_map<std::string, t_MenuItem> menu;
  std::vector<std::string> menu_order;

  /**
   * @brief Init menu structure
   *
   */
  void init()
  {
    for (auto console : Console::list)
    {
      menu_order.push_back(console->full_name);
      Menu::menu[console->full_name] = {false, nullptr};
      if (console->actions & ConsoleActions_RomDump)
        Menu::menu[console->full_name].subMenu["Dump ROM"] = {false, std::bind(&Console::render_rom_dump, console)};
      if (console->actions & ConsoleActions_RomWrite)
        Menu::menu[console->full_name].subMenu["Write ROM"] = {false, std::bind(&Console::render_rom_write, console)};
      if (console->actions & ConsoleActions_RamDump)
        Menu::menu[console->full_name].subMenu["Dump RAM"] = {false, std::bind(&Console::render_ram_dump, console)};
      if (console->actions & ConsoleActions_RamWrite)
        Menu::menu[console->full_name].subMenu["Write RAM"] = {false, std::bind(&Console::render_ram_write, console)};
    }

    menu_order.push_back("Flashers");
    Menu::menu["Flashers"] = {false, &Settings::render_flashers};

    menu_order.push_back("Settings");
    Menu::menu["Settings"] = {false, &Settings::render_settings};

    // menu_order.push_back("Log");
    // Menu::menu["Log"] = { true, &AppLog::render };

    menu_order.push_back("About");
    Menu::menu["About"] = {false, &Settings::render_about};
  }

  /**
   * @brief Renders the menu tree
   *
   */
  void render_tree(bool disabled)
  {
    ImGui::BeginChild("MenuPanel", ImVec2(220, 0), ImGuiChildFlags_Border);

    char label[32];
    ImVec2 size = ImVec2(0, 35.0f);
    ImVec2 alignment = ImVec2(0, 0.5f);
    ImGui::PushStyleVar(ImGuiStyleVar_SelectableTextAlign, alignment);
    ImGui::SeparatorText("Menu");
    ImGui::BeginChild("MenuItems");

    ImGui::BeginDisabled(disabled);

    for (auto &menu_name : Menu::menu_order)
    {
      auto &item = Menu::menu[menu_name];
      snprintf(label, sizeof(label), " %s %s", item.active ? ICON_FA_CARET_DOWN : ICON_FA_CARET_RIGHT, menu_name.c_str());
      if (ImGui::Selectable(label, item.active, 0, size))
        set_menu_active(menu_name, !item.active);

      if (item.active && item.subMenu.size() != 0)
      {
        for (auto &subItem : item.subMenu)
        {
          snprintf(label, sizeof(label), "    %s %s", subItem.second.active ? ICON_FA_CIRCLE_DOT : ICON_FA_CIRCLE, subItem.first.c_str());
          if (ImGui::Selectable(label, false, 0, size))
            set_sub_menu_active(menu_name, subItem.first);
        }
      }
    }

    ImGui::EndDisabled();

    ImGui::PopStyleVar();
    ImGui::EndChild(); // MenuItems
    ImGui::EndChild(); // MenuPanel
  }

  /**
   * @brief Set the menu active object
   *
   * @param menu_name
   * @param value
   */
  void set_menu_active(const std::string &menu_name, bool value)
  {
    for (auto &item : menu)
    {
      if (item.first == menu_name)
        item.second.active = value;
      else
        item.second.active = false;
    }
  }

  /**
   * @brief Set the sub menu active object
   *
   * @param menu_name
   * @param sub_menu_name
   */
  void set_sub_menu_active(const std::string &menu_name, const std::string &sub_menu_name)
  {
    auto menuItem = menu.find(menu_name);
    if (menuItem == menu.end())
      return;

    for (auto &subIitem : menuItem->second.subMenu)
    {
      if (subIitem.first == sub_menu_name)
        subIitem.second.active = true;
      else
        subIitem.second.active = false;
    }
  }

  /**
   * @brief Renders the content of the selected menu
   *
   */
  void render_content()
  {
    ImGui::SameLine();
    ImVec2 button_sz(50, 50);
    ImGui::BeginChild("Content", ImVec2(0, 0), ImGuiChildFlags_Border);

    for (auto &item : Menu::menu)
    {
      if (!item.second.active)
        continue;

      if (item.second.subMenu.size() == 0)
      {
        if (item.second.fn_render != nullptr)
        {
          item.second.fn_render();
          break;
        }
        else
        {
          return;
        }
      }
      for (auto &subItem : item.second.subMenu)
      {
        if (!subItem.second.active)
          continue;

        if (subItem.second.fn_render != nullptr)
        {
          subItem.second.fn_render();
          break;
        }
        else
        {
          return;
        }
      }
      break;
    }

    ImGui::EndChild(); // Content
  }
}
