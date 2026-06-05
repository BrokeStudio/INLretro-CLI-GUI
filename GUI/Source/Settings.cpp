#include "IconsFontAwesome6.h"

#include "AppLog.h"
#include "Dialog.h"
#include "Flasher.h"
#include "Ini.h"
#include "Settings.h"
#include "version.h"
#include "build.h"

#include "SDL_version.h"
#if defined(_WIN32)
#include "libusb.h"
#else
#include <libusb-1.0/libusb.h>
#endif

#define STM6_FIRMWARE "firmware/inlretro_stm6.bin"
#define STMN_FIRMWARE "firmware/inlretro_stmn.bin"

using namespace std::placeholders; // for `_1`, `_2`

namespace Settings
{

  t_Settings settings = {
      "dark", // theme
      "",     // firmware_update_script
      0,      // Roboto Mono Regular as default font
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
    else if (key == "font")
    {
      int font;
      try
      {
        font = std::stoi(value);
      }
      catch (const std::exception &e)
      {
        font = 0;
      }
      settings.font = (font == 0 || font == 1) ? font : 0;
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

      if (ImGui::BeginTable("flashers_table", 5, ImGuiTableFlags_SizingStretchProp))
      {
        // Header
        ImGui::TableSetupColumn("Name");
        ImGui::TableSetupColumn("Active");
        ImGui::TableSetupColumn("Type");
        ImGui::TableSetupColumn("Firmware");
        ImGui::TableSetupColumn("");
        ImGui::TableHeadersRow();

        // Flashers
        for (auto &flasher : Flasher::list)
        {
          ImGui::BeginDisabled(flasher->isFlashing);

          ImGui::TableNextRow();
          ImGui::TableSetColumnIndex(0);
          char label[32];
          snprintf(label, sizeof(label), "INL Retro-Pro%s", flasher->id.c_str());
          if (flasher->hardwareType == HW_UNKW)
          {
            ImGui::BeginGroup();
            ImGui::TextColored(ImVec4(1.0f, 0.734f, 0.189f, 1.0f), ICON_FA_TRIANGLE_EXCLAMATION);
            ImGui::SameLine();
            ImGui::TextUnformatted(label);
            ImGui::EndGroup();
            ImGui::SetItemTooltip("The firmware is outdated and needs to be updated to be compatible.");
          }
          else
          {
            ImGui::TextUnformatted(label);
          }
          ImGui::TableSetColumnIndex(1);
          snprintf(label, sizeof(label), "##flasher_is_active%s", flasher->id.c_str());
          ImGui::Checkbox(label, &flasher->isActive);
          ImGui::TableSetColumnIndex(2);
          const char *models[] = {"UNKNOWN", "HW_STM6", "HW_STMN", "HW_STM6P", "HW_AVR"};
          ImGui::Text("%s", models[flasher->hardwareType]);
          ImGui::TableSetColumnIndex(3);
          ImGui::Text("v2.%d", flasher->firmwareVersion);
          // ImGui::Text("v%d.%d", (flasher->firmwareVersion & 0xff00) >> 8, flasher->firmwareVersion & 0xff);
          ImGui::TableSetColumnIndex(4);
          if (!flasher->isActive)
            ImGui::BeginDisabled();

          snprintf(label, sizeof(label), "Update firmware...##inlretropro%s", flasher->id.c_str());

          if (ImGui::BeginPopupContextItem("custom update firmware"))
          {
            ImGui::Text("Select your flasher model:");
            ImGui::Separator();
            if (flasher->hardwareType == HW_UNKW || flasher->hardwareType == HW_STM6)
              if (ImGui::Selectable("INLretro 6 connectors"))
                flasher->update_firmware(STM6_FIRMWARE);

            if (flasher->hardwareType == HW_UNKW || flasher->hardwareType == HW_STMN)
              if (ImGui::Selectable("INLretro NESmaker edition"))
                flasher->update_firmware(STMN_FIRMWARE);

            // ImGui::BeginDisabled(true);
            // ImGui::Selectable("INL Kazzo");
            // ImGui::EndDisabled();
            ImGui::Separator();

            if (ImGui::Selectable("Use custom file..."))
            {
              Dialog::fileExt = ".bin";
              Dialog::callback = std::bind(&Flasher::cb_custom_firmware_update, flasher, _1, _2);
              Dialog::showFileOpen = true;
              Dialog::showFileSave = false;
            }

            ImGui::EndPopup();
          }

          if (ImGui::Button(label))
            ImGui::OpenPopup("custom update firmware");

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

    // Always center this window when appearing
    ImVec2 center = ImGui::GetMainViewport()->GetCenter();
    ImGui::SetNextWindowPos(center, ImGuiCond_Appearing, ImVec2(0.5f, 0.5f));
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
      ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
      static int style_idx = 0;
      if (ImGui::Combo("##settings_theme", &style_idx, "Dark\0Light\0Classic\0"))
      {
        set_theme(style_idx);
      }

      // font
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Font");
      ImGui::TableSetColumnIndex(1);
      ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
      ImGui::Combo("##settings_font", &settings.font, "Roboto Mono Regular\0Rubik Regular\0");

      // firmware update script
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Firmware update script");
      ImGui::TableSetColumnIndex(1);
      ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
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
    ImGui::Text(ICON_FA_MICROCHIP " INLretro GUI v%s", INLRETRO_GUI_VERSION);
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
    ImGui::Separator();
    ImGui::Text("SDL2 v%d.%d.%d", SDL_MAJOR_VERSION, SDL_MINOR_VERSION, SDL_PATCHLEVEL);
    const libusb_version *libusbVersion = libusb_get_version();
    ImGui::Text("libusb v%d.%d.%d", libusbVersion->major, libusbVersion->minor, libusbVersion->micro);

    ImGui::EndChild();
  }

}
