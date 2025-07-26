#include "IconsFontAwesome6.h"

#include "AppLog.h"
#include "Flasher.h"
#include "Ini.h"
#include "Settings.h"
#include "version.h"
#include "build.h"

namespace Settings
{

  t_Settings settings = {
      "dark", // theme
      "",     // firmware_update_script
      true,   // save_on_exit
      false   // imgui_demo
  };

  /**
   * @brief Set theme
   *
   * @param style_idx
   */
  void set_theme(int style_idx)
  {
    switch (style_idx)
    {
    case 0:
      settings.theme = "dark";
      ImGui::StyleColorsDark();
      break;
    case 1:
      settings.theme = "light";
      ImGui::StyleColorsLight();
      break;
    case 2:
      settings.theme = "classic";
      ImGui::StyleColorsClassic();
      break;
    }
  }

  /**
   * @brief Set settings property
   *
   * @param key
   * @param value
   */
  void set_property(const std::string &key, const std::string &value)
  {
    if (key == "theme")
    {
      if (value == "dark")
        set_theme(0);
      else if (value == "light")
        set_theme(1);
      else if (value == "classic")
        set_theme(2);
    }
    else if (key == "save_on_exit")
      settings.save_on_exit = value == "true" ? true : false;
    else if (key == "firmware_update_script")
      settings.firmware_update_script = value;
#if defined(_DEBUG)
    else if (key == "imgui_demo")
      settings.imgui_demo = value == "true" ? true : false;
#endif
    else
    {
      APP_LOG(LogTypes_Warning, "[SETTINGS] Don't know what to do with: " + key + "=" + value);
    }
  }

  /**
   * @brief Renders the flasher list
   *
   */
  void render_flashers()
  {
    // ImGui::BeginGroup();
    ImGui::SeparatorText("Flasher(s)");
    ImGui::BeginChild("Flasher(s)");
    ImGui::TextWrapped("Detected flashers are listed below.");
    ImGui::TextWrapped("Use checkbox to enable/disable a flasher.");
    ImGui::TextWrapped("Press refresh to refresh the list.");
    ImGui::Separator();

    // flasher tab/list
    if (Flasher::list.size() == 0)
    {
      ImGui::Text("No flasher found...");
    }
    else
    {

      if (ImGui::BeginTable("flashers_table", 3, ImGuiTableFlags_SizingStretchProp))
      {
        // Header
        ImGui::TableSetupColumn("Name");
        ImGui::TableSetupColumn("Active");
        ImGui::TableSetupColumn("Firmware");
        ImGui::TableHeadersRow();

        // Flashers
        for (auto &flasher : Flasher::list)
        {
          ImGui::BeginDisabled(flasher->isFlashing);

          ImGui::TableNextRow();
          ImGui::TableSetColumnIndex(0);
          char label[32];
          snprintf(label, sizeof(label), "INL Retro-Pro%s", flasher->id.c_str());
          ImGui::TextUnformatted(label);
          ImGui::TableSetColumnIndex(1);
          snprintf(label, sizeof(label), "##flasher_is_active%s", flasher->id.c_str());
          ImGui::Checkbox(label, &flasher->isActive);
          ImGui::TableSetColumnIndex(2);
          if (!flasher->isActive)
            ImGui::BeginDisabled();
          snprintf(label, sizeof(label), "Update firmware##inlretropro%s", flasher->id.c_str());
          if (ImGui::Button(label))
          {
            // scripts/inlretro_inl6fwupdate.lua
            t_INLoptions_std firmware_INLOptions;
            firmware_INLOptions.gui = true;
            firmware_INLOptions.retroprog_id = flasher->id;
            firmware_INLOptions.lua_file = Settings::settings.firmware_update_script; // "scripts/inlretro_fwupdate.lua";
            flasher->exec(firmware_INLOptions);
          }
          if (!flasher->isActive)
            ImGui::EndDisabled();

          ImGui::EndDisabled();
        }

        ImGui::EndTable();
      }
    }
    // ImGui::Separator();
    // ImGui::Checkbox("Debug", &INLoptions.debug); // FIXME
    ImGui::Separator();
    ImGui::BeginDisabled(Flasher::is_flashing());
    if (ImGui::Button("Refresh flasher list")) //, ImVec2(ImGui::GetContentRegionAvail().x, 0)))
    {
      Flasher::detect_all();
    }
    ImGui::EndDisabled();
    ImGui::EndChild();
  }

  /**
   * @brief Renders the settings
   *
   */
  void render_settings()
  {
    ImGui::SeparatorText("Settings");
    ImGui::BeginChild("Settings");

    if (ImGui::BeginTable("rom_dump_table", 2, ImGuiTableFlags_SizingStretchProp))
    {
      // Setup table columns sizes
      ImVec2 text_max_size = ImGui::CalcTextSize("Firmware update script");
      ImGui::TableSetupColumn("one", ImGuiTableColumnFlags_WidthFixed, text_max_size.x);
      ImGui::TableSetupColumn("two", ImGuiTableColumnFlags_WidthStretch);

      // theme
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Theme");
      ImGui::TableSetColumnIndex(1);
      // ImGuiStyle &style = ImGui::GetStyle();
      static int style_idx = 0;
      if (ImGui::Combo("##settings_theme", &style_idx, "Dark\0Light\0Classic\0"))
      {
        set_theme(style_idx);
      }

      // firmware update script
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Firmware update script");
      ImGui::TableSetColumnIndex(1);
      ImGui::InputText("##settings_firmware_update_script", &settings.firmware_update_script);

      // save settings on exit
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Save settings on exit");
      ImGui::TableSetColumnIndex(1);
      ImGui::Checkbox("##seting_save_on_exit", &settings.save_on_exit);

#if defined(_DEBUG)
      // ImGui demo window
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("ImGui demo window");
      ImGui::TableSetColumnIndex(1);
      ImGui::Checkbox("##settings_imgui_demo_window", &settings.imgui_demo);
#endif

      ImGui::EndTable();
    }

    ImGui::NewLine();
    if (ImGui::Button("Save settings"))
    {
      Ini::save();
    }

    ImGui::EndChild();
  }

  /**
   * @brief Renders the About section
   *
   */
  void render_about()
  {
    ImGui::SeparatorText("About");
    ImGui::BeginChild("About");
#if defined(_DEBUG) || defined(_RELEASE)
    ImGui::Text(ICON_FA_MICROCHIP " INLretro GUI v%s-dev+build.%d", INLRETRO_GUI_VERSION, INLRETRO_GUI_BUILD);
#else
    ImGui::Text(ICON_FA_MICROCHIP " INLretro GUI v%s", INLRETRO_GUI_VERSION, INLRETRO_GUI_BUILD);
#endif
    ImGui::Separator();
    ImGui::Text("2024-2025, Broke Studio");
    ImGui::Text("Developed by Antoine Gohin");
    ImGui::Separator();
    ImGui::Text("Based on the original");
    ImGui::SameLine();
    ImGui::TextLinkOpenURL("INLretro Dumper-Programmer", "https://www.infiniteneslives.com/inlretro.php");
    ImGui::Text("by Paul Molloy / InfiniteNesLives");
    ImGui::Separator();
    ImGui::Text("Powered by");
    ImGui::SameLine();
    ImGui::TextLinkOpenURL("Dear ImGui", "https://github.com/ocornut/imgui");
    ImGui::SameLine();
    ImGui::Text("v" IMGUI_VERSION);
    ImGui::Text("by Omar Cornut");
    ImGui::EndChild();
  }

}
