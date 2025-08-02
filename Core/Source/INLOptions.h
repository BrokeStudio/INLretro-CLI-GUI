#pragma once
#ifndef INLOPTIONS_H
#define INLOPTIONS_H

#include <string>

// Struct used to control functionality.
struct t_INLoptions_std
{
  std::string retroprog_id;
  std::string console_name;
  std::string mapper_name;
  bool display_help = false;
  bool debug = false;
  bool gui = false;

  // NES Functionality
  int chr_rom_size_kb = 0;
  int prg_rom_size_kb = 0;
  int wram_size_kb = 0;

  // General Functionality
  int rom_size_kb = 0;
  std::string rom_dump_file;
  std::string rom_write_file;
  std::string ram_dump_file;
  std::string ram_write_file;
  bool verify = false;
  std::string additional_opts;

  std::string lua_file;
};

#endif
