#pragma once
#ifndef CONSOLE_H
#define CONSOLE_H

#include <vector>
#include <fstream>
#include "INLOptions.h"
#include "Dialog.h"

typedef int ConsoleActions;
enum ConsoleActions_
{
  ConsoleActions_RomDump = 1 << 0,
  ConsoleActions_RomWrite = 1 << 1,
  ConsoleActions_RamDump = 1 << 2,
  ConsoleActions_RamWrite = 1 << 3,
};

struct Mapper
{
  int id;
  std::string name;
  std::string script_name;
};

struct t_Console
{
  std::string name;
  std::string short_name;
  std::string full_name;
  ConsoleActions actions;
  std::string rom_file_ext;
  std::string ram_file_ext;
  std::vector<Mapper> mappers;

  t_Console() { clear(); }

  void clear()
  {
    this->name = "";
    this->short_name = "";
    this->full_name = "";
    this->actions = 0;
    this->ram_file_ext = ".bin";
    this->ram_file_ext = ".bin";
    this->mappers.clear();
  }
};

class Console : public t_Console
{

public:
  Console(const t_Console &console);
  ~Console();

  static std::vector<Console *> list;
  static void add(Console *console);
  static void clear_list();

  void render_rom_dump(std::string droppedFilename = "");
  void render_rom_write(std::string droppedFilename = "");
  void render_ram_dump(std::string droppedFilename = "");
  void render_ram_write(std::string droppedFilename = "");

protected:
  char buf[256] = {0};
  bool display_header_window = false;

  t_INLoptions_std rom_dump_INLOptions;
  t_INLoptions_std rom_write_INLOptions;
  t_INLoptions_std ram_dump_INLOptions;
  t_INLoptions_std ram_write_INLOptions;

  virtual void cb_rom_dump_file_dialog(const std::string &path, const std::string &filename)
  {
    rom_dump_INLOptions.rom_dump_file = path;
  }
  virtual void cb_rom_write_file_dialog(const std::string &path, const std::string &filename)
  {
    rom_write_INLOptions.rom_write_file = path;

    // get file size
    std::ifstream file(rom_write_INLOptions.ram_write_file, std::fstream::binary);
    // TODO: check if file is valid
    file.seekg(0, file.end);
    rom_write_INLOptions.rom_size_kb = static_cast<int>(file.tellg() >> 10);
    file.seekg(0, file.beg);
    file.close();
  }
  virtual void cb_ram_dump_file_dialog(const std::string &path, const std::string &filename)
  {
    ram_dump_INLOptions.ram_dump_file = path;
  }
  virtual void cb_ram_write_file_dialog(const std::string &path, const std::string &filename)
  {
    ram_write_INLOptions.ram_write_file = path;

    // get file size
    std::ifstream file(ram_write_INLOptions.ram_write_file, std::fstream::binary);
    // TODO: check if file is valid
    file.seekg(0, file.end);
    ram_write_INLOptions.wram_size_kb = static_cast<int>(file.tellg() >> 10);
    file.seekg(0, file.beg);
    file.close();
  }

  virtual void render_header_content()
  {
    ImGui::Text("No header view defined for this console yet...");
  }

  int get_mapper_index_by_mapper_id(int mapper_id);
  int get_mapper_index_by_mapper_name(const std::string &mapper_name);
  int get_mapper_index_by_script_name(const std::string &script_name);

private:
  void Browse(const char *label, std::string &file, bool openFile, bool startFade, std::function<void(const std::string &path, const std::string &filename)> callback);
  void AdditionalOptions(const char *label, t_INLoptions_std *INLoptions, ConsoleActions consoleAction);
  void render_additional_options_popup(t_INLoptions_std *INLoptions, ConsoleActions consoleAction);
  void render_header_window();
};

#endif
