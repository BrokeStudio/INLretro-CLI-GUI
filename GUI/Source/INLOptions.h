#pragma once
#ifndef INLOPTIONS_H
#define INLOPTIONS_H

#include <string>

// Struct used to control functionality.
typedef struct
{
  char *retroprog_id;
  char *console_name;
  char *mapper_name;
  bool display_help;
  bool debug;
  bool gui;

  // NES Functionality
  int chr_rom_size_kb;
  int prg_rom_size_kb;
  int wram_size_kb;

  // General Functionality
  int rom_size_kb;
  char *rom_dump_file;
  char *rom_write_file;
  char *ram_dump_file;
  char *ram_write_file;
  bool verify;
  char* additional_opts;

  char *lua_file;
} t_INLoptions;

typedef struct
{
  std::string retroprog_id;
  std::string console_name;
  std::string mapper_name;
  bool display_help;
  bool debug;
  bool gui;

  // NES Functionality
  int chr_rom_size_kb;
  int prg_rom_size_kb;
  int wram_size_kb;

  // General Functionality
  int rom_size_kb;
  std::string rom_dump_file;
  std::string rom_write_file;
  std::string ram_dump_file;
  std::string ram_write_file;
  bool verify;
  std::string additional_opts;

  std::string lua_file;
} t_INLoptions_std;

#endif
