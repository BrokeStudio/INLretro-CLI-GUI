#include <vector>
#include <functional>

#include "imgui.h"
#include "imgui_stdlib.h"
#include "IconsFontAwesome6.h"

#include "cli.h"
#include "Console.h"
#include "Dialog.h"
#include "Flasher.h"
#include "trim.h"

#define IM_MAX(A, B) (((A) >= (B)) ? (A) : (B))

using namespace std::placeholders; // for `_1`, `_2`

std::vector<Console *> Console::list;

/**
 * @brief Add a console to the list
 *
 * @param console
 */
void Console::add(Console *console)
{
  Console::list.push_back(console);
}

/**
 * @brief Clear the console list
 *
 */
void Console::clear_list()
{
  for (auto &console : Console::list)
  {
    delete console;
  }
  Console::list.clear();
}

Console::Console(const t_Console &console)
{
  this->name = console.name;
  this->short_name = console.short_name;
  this->full_name = console.full_name;
  this->actions = console.actions;
  this->rom_file_ext = console.rom_file_ext;
  this->ram_file_ext = console.ram_file_ext;
  this->mappers = console.mappers;
  memset(buf, 0, sizeof(buf));

  rom_dump_INLOptions.prg_rom_size_kb = rom_write_INLOptions.prg_rom_size_kb = ram_dump_INLOptions.prg_rom_size_kb = ram_write_INLOptions.prg_rom_size_kb = 0;
  rom_dump_INLOptions.chr_rom_size_kb = rom_write_INLOptions.chr_rom_size_kb = ram_dump_INLOptions.chr_rom_size_kb = ram_write_INLOptions.chr_rom_size_kb = 0;
  rom_dump_INLOptions.rom_size_kb = rom_write_INLOptions.rom_size_kb = ram_dump_INLOptions.rom_size_kb = ram_write_INLOptions.rom_size_kb = 0;
  rom_dump_INLOptions.wram_size_kb = rom_write_INLOptions.wram_size_kb = ram_dump_INLOptions.wram_size_kb = ram_write_INLOptions.wram_size_kb = 0;
  rom_dump_INLOptions.verify = ram_dump_INLOptions.verify = ram_write_INLOptions.verify = false;
  rom_write_INLOptions.verify = true;
  rom_dump_INLOptions.debug = rom_write_INLOptions.debug = ram_dump_INLOptions.debug = ram_write_INLOptions.debug = false;
  rom_dump_INLOptions.display_help = rom_write_INLOptions.display_help = ram_dump_INLOptions.display_help = ram_write_INLOptions.display_help = false;
  rom_dump_INLOptions.console_name = rom_write_INLOptions.console_name = ram_dump_INLOptions.console_name = ram_write_INLOptions.console_name = name;
  rom_dump_INLOptions.rom_dump_file = rom_write_INLOptions.rom_dump_file = ram_dump_INLOptions.rom_dump_file = ram_write_INLOptions.ram_dump_file = "";
  rom_dump_INLOptions.rom_write_file = rom_write_INLOptions.rom_write_file = ram_dump_INLOptions.rom_write_file = ram_write_INLOptions.rom_write_file = "";
  rom_dump_INLOptions.ram_dump_file = rom_write_INLOptions.ram_dump_file = ram_dump_INLOptions.ram_dump_file = ram_write_INLOptions.ram_dump_file = "";
  rom_dump_INLOptions.ram_write_file = rom_write_INLOptions.ram_write_file = ram_dump_INLOptions.ram_write_file = ram_write_INLOptions.ram_write_file = "";
  // TODO: should it be done only in the flasher file?
  rom_dump_INLOptions.gui = rom_write_INLOptions.gui = ram_dump_INLOptions.gui = ram_write_INLOptions.gui = true;
}

/**
 * @brief Destroy the Console:: Console object
 *
 */
Console::~Console() {}

/**
 * @brief Render the additional options popup
 *
 * @param INLoptions depends on the current view (rom dump, rom write, ram dump, ram write)
 */
void Console::render_additional_options_popup(t_INLoptions_std *INLoptions)
{
  // Additional options
  if (ImGui::BeginPopupContextItem("additional_options_popup"))
  {
    trim(INLoptions->additional_opts);
    if (ImGui::Selectable("force_wram_test"))
      INLoptions->additional_opts += ",force_wram_test";

    if (ImGui::Selectable("force_flash_test"))
      INLoptions->additional_opts += ",force_flash_test";

    if (ImGui::Selectable("bank_table"))
      INLoptions->additional_opts += ",bank_table=0x0000";

    trim(INLoptions->additional_opts);
    if (INLoptions->additional_opts != "" && INLoptions->additional_opts.at(0) == ',')
      INLoptions->additional_opts.erase(0, 1);

    ImGui::Separator();

    if (ImGui::Selectable("Clear"))
      INLoptions->additional_opts = "";

    ImGui::EndPopup();
  }
}

/**
 * @brief Render the rom dump view
 *
 */
void Console::render_rom_dump(std::string droppedFilename)
{
  bool isFlashing = Flasher::is_flashing();
  snprintf(this->buf, sizeof(this->buf), "%s - ROM dump", this->full_name.c_str());
  ImGui::SeparatorText(this->buf);

  ImGui::BeginChild("ConsoleContent");

  ImGui::BeginDisabled(isFlashing);

  if (ImGui::BeginTable("rom_dump_table", 2, ImGuiTableFlags_SizingStretchProp))
  {
    // Setup table columns sizes
    ImVec2 text_max_size = ImGui::CalcTextSize("Additional options");
    ImGui::TableSetupColumn("one", ImGuiTableColumnFlags_WidthFixed, text_max_size.x);
    ImGui::TableSetupColumn("two", ImGuiTableColumnFlags_WidthStretch);

    // Destination file
    ImGui::TableNextRow();
    ImGui::TableSetColumnIndex(0);
    ImGui::TextUnformatted("Destination file");
    ImGui::TableSetColumnIndex(1);
    ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
    if (droppedFilename != "")
      rom_dump_INLOptions.rom_dump_file = droppedFilename;
    Browse("##rom_dump_rom_write_file", rom_dump_INLOptions.rom_dump_file, false, std::bind(&Console::cb_rom_dump_file_dialog, this, _1, _2));

    // Mapper
    if (mappers.size() != 0)
    {
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Mapper");
      ImGui::TableSetColumnIndex(1);
      int mapper_idx = get_mapper_index_by_script_name(rom_dump_INLOptions.mapper_name);
      if (mapper_idx == -1)
      {
        mapper_idx = 0;
        rom_dump_INLOptions.mapper_name = mappers[mapper_idx].script_name;
      }
      snprintf(this->buf, sizeof(this->buf), "%i - %s\n", mappers[mapper_idx].id, mappers[mapper_idx].name.c_str());
      ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
      if (ImGui::BeginCombo("##rom_dump_mapper", this->buf, 0))
      {
        for (size_t n = 0; n < mappers.size(); n++)
        {
          const bool is_selected = (mapper_idx == n);
          snprintf(this->buf, sizeof(this->buf), "%i - %s\n", mappers[n].id, mappers[n].name.c_str());
          if (ImGui::Selectable(this->buf, is_selected))
            rom_dump_INLOptions.mapper_name = mappers[n].script_name;

          // Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
          if (is_selected)
            ImGui::SetItemDefaultFocus();
        }
        ImGui::EndCombo();
      }
    }

    // Sizes
    if (this->name == "nes" || this->name == "famicom" || this->name == "fc")
    {
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("PRG-ROM size (KB)");
      ImGui::TableSetColumnIndex(1);
      ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
      ImGui::InputInt("##rom_dump_prg_rom_size_kb", &rom_dump_INLOptions.prg_rom_size_kb);

      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("CHR-ROM size (KB)");
      ImGui::TableSetColumnIndex(1);
      ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
      ImGui::InputInt("##rom_dump_chr_rom_size_kb", &rom_dump_INLOptions.chr_rom_size_kb);
    }
    else
    {
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("ROM size (KB)");
      ImGui::TableSetColumnIndex(1);
      ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
      ImGui::InputInt("##rom_dump_rom_size_kb", &rom_dump_INLOptions.rom_size_kb);
    }

    // Additional options
    ImGui::TableNextRow();
    ImGui::TableSetColumnIndex(0);
    ImGui::TextUnformatted("Additional Options");
    ImGui::TableSetColumnIndex(1);
    ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
    AdditionalOptions("##rom_dump_additional_opts", &rom_dump_INLOptions);

    // Command line
    ImGui::TableNextRow();
    ImGui::TableSetColumnIndex(0);
    ImGui::TextUnformatted("Command line");
    ImGui::TableSetColumnIndex(1);
    std::string cli = get_cli(rom_dump_INLOptions);
    ImGui::SetNextItemWidth(-FLT_MIN);
    ImGui::InputText("##rom_dump_command_line", &cli, ImGuiInputTextFlags_ReadOnly);

    ImGui::EndTable();
  }

  ImGui::EndDisabled();

  ImGui::BeginDisabled(Flasher::count_flashing() == Flasher::list.size());
  if (ImGui::Button(ICON_FA_DOWNLOAD " Dump", ImVec2(-FLT_MIN, 50)))
  {
    trim(rom_write_INLOptions.additional_opts);
    Flasher::exec_all(rom_dump_INLOptions);
  }
  ImGui::EndDisabled();

  ImGui::EndChild(); // ConsoleContent
}

/**
 * @brief Render the rom write view
 *
 */
void Console::render_rom_write(std::string droppedFilename)
{
  bool isFlashing = Flasher::is_flashing();
  snprintf(this->buf, sizeof(this->buf), "%s - ROM write", this->full_name.c_str());
  ImGui::SeparatorText(this->buf);

  ImGui::BeginChild("ConsoleContent");

  ImGui::BeginDisabled(isFlashing);

  if (ImGui::BeginTable("rom_write_table", 2, ImGuiTableFlags_SizingStretchProp))
  {
    // Setup table columns sizes
    ImVec2 text_max_size = ImGui::CalcTextSize("Additional options");
    ImGui::TableSetupColumn("one", ImGuiTableColumnFlags_WidthFixed, text_max_size.x);
    ImGui::TableSetupColumn("two", ImGuiTableColumnFlags_WidthStretch);

    // Source file
    ImGui::TableNextRow();
    ImGui::TableSetColumnIndex(0);
    ImGui::TextUnformatted("Source file");
    ImGui::TableSetColumnIndex(1);
    ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
    if (droppedFilename != "")
      rom_write_INLOptions.rom_write_file = droppedFilename;
    Browse("##rom_write_rom_write_file", rom_write_INLOptions.rom_write_file, true, std::bind(&Console::cb_rom_write_file_dialog, this, _1, _2));

    // Mapper
    if (mappers.size() != 0)
    {
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Mapper");
      ImGui::TableSetColumnIndex(1);
      int mapper_idx = get_mapper_index_by_script_name(rom_write_INLOptions.mapper_name);
      if (mapper_idx == -1)
      {
        mapper_idx = 0;
        rom_write_INLOptions.mapper_name = mappers[mapper_idx].script_name;
      }
      snprintf(this->buf, sizeof(this->buf), "%i - %s\n", mappers[mapper_idx].id, mappers[mapper_idx].name.c_str());
      ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
      if (ImGui::BeginCombo("##rom_write_mapper", buf, 0))
      {
        for (size_t n = 0; n < mappers.size(); n++)
        {
          const bool is_selected = (mapper_idx == n);
          snprintf(this->buf, sizeof(this->buf), "%i - %s\n", mappers[n].id, mappers[n].name.c_str());
          if (ImGui::Selectable(buf, is_selected))
            rom_write_INLOptions.mapper_name = mappers[n].script_name;

          // Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
          if (is_selected)
            ImGui::SetItemDefaultFocus();
        }
        ImGui::EndCombo();
      }
    }

    // Sizes
    if (this->name == "nes" || this->name == "famicom" || this->name == "fc")
    {
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("PRG-ROM size (KB)");
      ImGui::TableSetColumnIndex(1);
      ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
      ImGui::InputInt("##rom_write_prg_rom_size_kb", &rom_write_INLOptions.prg_rom_size_kb);

      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("CHR-ROM size (KB)");
      ImGui::TableSetColumnIndex(1);
      ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
      ImGui::InputInt("##rom_write_chr_rom_size_kb", &rom_write_INLOptions.chr_rom_size_kb);
    }
    else
    {
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("ROM size (KB)");
      ImGui::TableSetColumnIndex(1);
      ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
      ImGui::InputInt("##rom_write_rom_size_kb", &rom_write_INLOptions.rom_size_kb);
    }

    // Additional options
    ImGui::TableNextRow();
    ImGui::TableSetColumnIndex(0);
    ImGui::TextUnformatted("Additional Options");
    ImGui::TableSetColumnIndex(1);
    ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
    AdditionalOptions("##rom_write_additional_opts", &rom_write_INLOptions);

    // Verify
    ImGui::TableNextRow();
    ImGui::TableSetColumnIndex(0);
    ImGui::TextUnformatted("Verify");
    ImGui::TableSetColumnIndex(1);
    ImGui::Checkbox("##rom_write_verify", &rom_write_INLOptions.verify);

    // Command line
    ImGui::TableNextRow();
    ImGui::TableSetColumnIndex(0);
    ImGui::TextUnformatted("Command line");
    ImGui::TableSetColumnIndex(1);
    std::string cli = get_cli(rom_write_INLOptions);
    ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
    ImGui::InputText("##rom_write_command_line", &cli, ImGuiInputTextFlags_ReadOnly);

    ImGui::EndTable();
  }

  ImGui::EndDisabled();

  ImGui::BeginDisabled(Flasher::count_flashing() == Flasher::list.size());
  snprintf(this->buf, sizeof(this->buf), ICON_FA_UPLOAD " Write");
  if (ImGui::Button(buf, ImVec2(-FLT_MIN, 50)))
  {
    trim(rom_write_INLOptions.additional_opts);
    Flasher::exec_all(rom_write_INLOptions);
  }
  ImGui::EndDisabled();

  if (Flasher::list.size() > 1)
  {
    if (ImGui::BeginTable("rom_dump_table", static_cast<int>(Flasher::list.size()), ImGuiTableFlags_SizingStretchSame))
    {
      ImGui::TableNextRow();
      int i = 0;
      for (auto &flasher : Flasher::list)
      {
        ImGui::TableSetColumnIndex(i);
        ImGui::BeginDisabled(flasher->isFlashing);

        snprintf(this->buf, sizeof(this->buf), ICON_FA_UPLOAD " Write (%s)##write_btn_%s", flasher->id.c_str(), flasher->id.c_str());
        if (ImGui::Button(buf, ImVec2(-FLT_MIN, 50)))
        {
          flasher->exec(rom_write_INLOptions);
        }

        ImGui::EndDisabled();
        i++;
      }
      ImGui::EndTable();
    }
  }

  ImGui::EndChild(); // ConsoleContent
}

/**
 * @brief Render the ram dump view
 *
 */
void Console::render_ram_dump(std::string droppedFilename)
{
  bool isFlashing = Flasher::is_flashing();
  snprintf(this->buf, sizeof(this->buf), "%s - RAM dump", this->full_name.c_str());
  ImGui::SeparatorText(this->buf);

  ImGui::BeginChild("ConsoleContent");

  ImGui::BeginDisabled(isFlashing);

  if (ImGui::BeginTable("ram_dump_table", 2, ImGuiTableFlags_SizingStretchProp))
  {
    // Setup table columns sizes
    ImVec2 text_max_size = ImGui::CalcTextSize("Additional options");
    ImGui::TableSetupColumn("one", ImGuiTableColumnFlags_WidthFixed, text_max_size.x);
    ImGui::TableSetupColumn("two", ImGuiTableColumnFlags_WidthStretch);

    // Destination file
    ImGui::TableNextRow();
    ImGui::TableSetColumnIndex(0);
    ImGui::TextUnformatted("Destination file");
    ImGui::TableSetColumnIndex(1);
    ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
    if (droppedFilename != "")
      ram_dump_INLOptions.ram_dump_file = droppedFilename;
    Browse("##ram_dump_ram_dump_file", ram_dump_INLOptions.ram_dump_file, false, std::bind(&Console::cb_ram_dump_file_dialog, this, _1, _2));

    // Mapper
    if (mappers.size() != 0)
    {
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Mapper");
      ImGui::TableSetColumnIndex(1);
      int mapper_idx = get_mapper_index_by_script_name(ram_dump_INLOptions.mapper_name);
      if (mapper_idx == -1)
      {
        mapper_idx = 0;
        ram_dump_INLOptions.mapper_name = mappers[mapper_idx].script_name;
      }
      snprintf(this->buf, sizeof(this->buf), "%i - %s\n", mappers[mapper_idx].id, mappers[mapper_idx].name.c_str());
      ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
      if (ImGui::BeginCombo("##ram_dump_mapper", buf, 0))
      {
        for (size_t n = 0; n < mappers.size(); n++)
        {
          const bool is_selected = (mapper_idx == n);
          snprintf(this->buf, sizeof(this->buf), "%i - %s\n", mappers[n].id, mappers[n].name.c_str());
          if (ImGui::Selectable(buf, is_selected))
            ram_dump_INLOptions.mapper_name = mappers[n].script_name;

          // Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
          if (is_selected)
            ImGui::SetItemDefaultFocus();
        }
        ImGui::EndCombo();
      }
    }

    // Size
    ImGui::TableNextRow();
    ImGui::TableSetColumnIndex(0);
    ImGui::TextUnformatted("RAM size (KB)");
    ImGui::TableSetColumnIndex(1);
    ImGui::SetNextItemWidth(-FLT_MIN);
    ImGui::InputInt("##ram_dump_wram_size_kb", &ram_dump_INLOptions.wram_size_kb);

    // Additional options
    ImGui::TableNextRow();
    ImGui::TableSetColumnIndex(0);
    ImGui::TextUnformatted("Additional Options");
    ImGui::TableSetColumnIndex(1);
    ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
    AdditionalOptions("##ram_dump_additional_opts", &ram_dump_INLOptions);

    // Command line
    ImGui::TableNextRow();
    ImGui::TableSetColumnIndex(0);
    ImGui::TextUnformatted("Command line");
    ImGui::TableSetColumnIndex(1);
    std::string cli = get_cli(ram_dump_INLOptions);
    ImGui::SetNextItemWidth(-FLT_MIN);
    ImGui::InputText("##ram_dump_command_line", &cli, ImGuiInputTextFlags_ReadOnly);

    ImGui::EndTable();
  }

  ImGui::EndDisabled();

  ImGui::BeginDisabled(Flasher::count_flashing() == Flasher::list.size());
  if (ImGui::Button(ICON_FA_DOWNLOAD " Dump", ImVec2(-FLT_MIN, 50)))
  {
    trim(rom_write_INLOptions.additional_opts);
    Flasher::exec_all(ram_dump_INLOptions);
  }

  ImGui::EndDisabled();

  ImGui::EndChild(); // ConsoleContent
}

/**
 * @brief Render the ram write view
 *
 */
void Console::render_ram_write(std::string droppedFilename)
{
  bool isFlashing = Flasher::is_flashing();
  snprintf(this->buf, sizeof(this->buf), "%s - RAM write", this->full_name.c_str());
  ImGui::SeparatorText(this->buf);

  ImGui::BeginChild("ConsoleContent");

  ImGui::BeginDisabled(isFlashing);

  if (ImGui::BeginTable("ram_write_table", 2, ImGuiTableFlags_SizingStretchProp))
  {
    // Setup table columns sizes
    ImVec2 text_max_size = ImGui::CalcTextSize("Additional options");
    ImGui::TableSetupColumn("one", ImGuiTableColumnFlags_WidthFixed, text_max_size.x);
    ImGui::TableSetupColumn("two", ImGuiTableColumnFlags_WidthStretch);

    // Source file
    ImGui::TableNextRow();
    ImGui::TableSetColumnIndex(0);
    ImGui::TextUnformatted("Source file");
    ImGui::TableSetColumnIndex(1);
    ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
    if (droppedFilename != "")
      ram_write_INLOptions.ram_write_file = droppedFilename;
    Browse("##ram_write_ram_write_file", ram_write_INLOptions.ram_write_file, true, std::bind(&Console::cb_ram_write_file_dialog, this, _1, _2));

    // Mapper
    if (mappers.size() != 0)
    {
      ImGui::TableNextRow();
      ImGui::TableSetColumnIndex(0);
      ImGui::TextUnformatted("Mapper");
      ImGui::TableSetColumnIndex(1);
      int mapper_idx = get_mapper_index_by_script_name(ram_write_INLOptions.mapper_name);
      if (mapper_idx == -1)
      {
        mapper_idx = 0;
        ram_write_INLOptions.mapper_name = mappers[mapper_idx].script_name;
      }
      snprintf(this->buf, sizeof(this->buf), "%i - %s\n", mappers[mapper_idx].id, mappers[mapper_idx].name.c_str());
      ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
      if (ImGui::BeginCombo("##ram_write_mapper", buf, 0))
      {
        for (size_t n = 0; n < mappers.size(); n++)
        {
          const bool is_selected = (mapper_idx == n);
          snprintf(this->buf, sizeof(this->buf), "%i - %s\n", mappers[n].id, mappers[n].name.c_str());
          if (ImGui::Selectable(buf, is_selected))
            ram_write_INLOptions.mapper_name = mappers[n].script_name;

          // Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
          if (is_selected)
            ImGui::SetItemDefaultFocus();
        }
        ImGui::EndCombo();
      }
    }

    // Size
    ImGui::TableNextRow();
    ImGui::TableSetColumnIndex(0);
    ImGui::TextUnformatted("RAM size (KB)");
    ImGui::TableSetColumnIndex(1);
    ImGui::SetNextItemWidth(-FLT_MIN);
    ImGui::InputInt("##ram_write_wram_size_kb", &ram_write_INLOptions.wram_size_kb);

    // Additional options
    ImGui::TableNextRow();
    ImGui::TableSetColumnIndex(0);
    ImGui::TextUnformatted("Additional Options");
    ImGui::TableSetColumnIndex(1);
    ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
    AdditionalOptions("##ram_write_additional_opts", &ram_write_INLOptions);

    // Command line
    ImGui::TableNextRow();
    ImGui::TableSetColumnIndex(0);
    ImGui::TextUnformatted("Command line");
    ImGui::TableSetColumnIndex(1);
    std::string cli = get_cli(ram_write_INLOptions);
    ImGui::SetNextItemWidth(-FLT_MIN);
    ImGui::InputText("##ram_write_command_line", &cli, ImGuiInputTextFlags_ReadOnly);

    ImGui::EndTable();
  }

  ImGui::EndDisabled();

  ImGui::BeginDisabled(Flasher::count_flashing() == Flasher::list.size());
  snprintf(this->buf, sizeof(this->buf), ICON_FA_UPLOAD " Write");
  if (ImGui::Button(buf, ImVec2(-FLT_MIN, 50)))
  {
    trim(rom_write_INLOptions.additional_opts);
    Flasher::exec_all(ram_write_INLOptions);
  }
  ImGui::EndDisabled();

  ImGui::EndChild(); // ConsoleContent
}

/**
 * @brief Get the mapper index by mapper id
 *
 * @param mapper_id
 * @return int mapper index, -1 if not found
 */
int Console::get_mapper_index_by_mapper_id(int mapper_id)
{
  for (size_t i = 0; i < this->mappers.size(); i++)
  {
    if (this->mappers[i].id == mapper_id)
    {
      return static_cast<int>(i);
    }
  }
  return -1;
}

/**
 * @brief Get the mapper index by mapper name
 *
 * @param mapper_name
 * @return int mapper index, -1 if not found
 */
int Console::get_mapper_index_by_mapper_name(const std::string &mapper_name)
{
  for (size_t i = 0; i < this->mappers.size(); i++)
  {
    if (this->mappers[i].name == mapper_name)
    {
      return static_cast<int>(i);
    }
  }
  return -1;
}

/**
 * @brief Get the mapper index by mapper script name
 *
 * @param mapper_name
 * @return int mapper index, -1 if not found
 */
int Console::get_mapper_index_by_script_name(const std::string &script_name)
{
  for (size_t i = 0; i < this->mappers.size(); i++)
  {
    if (this->mappers[i].script_name == script_name)
    {
      return static_cast<int>(i);
    }
  }
  return -1;
}

void Console::Browse(const char *label, std::string &file, bool openFile, std::function<void(const std::string &path, const std::string &filename)> callback)
{
#define BROWSE_TEXT "Browse..."

  ImGuiStyle &style = ImGui::GetStyle();

  const float browse_text_size = ImGui::CalcTextSize(BROWSE_TEXT).x;

  ImGui::PushID(label);
  ImGui::SetNextItemWidth(IM_MAX(1.0f, ImGui::CalcItemWidth() - browse_text_size - style.FramePadding.x * 2.0f)); // -style.ItemInnerSpacing.x));

  ImGui::InputText(label, &file);
  const ImVec2 backup_frame_padding = style.FramePadding;
  style.FramePadding.x = style.FramePadding.y;
  ImGui::SameLine(0, style.ItemInnerSpacing.x);
  if (ImGui::Button(BROWSE_TEXT))
  {
    Dialog::fileExt = this->rom_file_ext;
    Dialog::callback = callback;
    Dialog::showFileOpen = openFile;
    Dialog::showFileSave = !openFile;
  }
  style.FramePadding = backup_frame_padding;

  ImGui::PopID();
}

void Console::AdditionalOptions(const char *label, t_INLoptions_std *INLoptions)
{
  ImGuiStyle &style = ImGui::GetStyle();

  const float button_size = ImGui::GetFrameHeight();

  ImGui::PushID(label);
  ImGui::SetNextItemWidth(IM_MAX(1.0f, ImGui::CalcItemWidth() - button_size - style.ItemInnerSpacing.x));

  ImGui::InputText(label, &INLoptions->additional_opts);

  const ImVec2 backup_frame_padding = style.FramePadding;
  style.FramePadding.x = style.FramePadding.y;
  ImGui::SameLine(0, style.ItemInnerSpacing.x);
  if (ImGui::Button("+", ImVec2(button_size, button_size)))
    ImGui::OpenPopup("additional_options_popup");

  style.FramePadding = backup_frame_padding;

  render_additional_options_popup(INLoptions);

  ImGui::PopID();
}
