#include <iostream>
#include <algorithm>
#include <cctype>
#include <string>
#ifdef _MSC_VER
#include "win_getopt.h"
#else
#include <getopt.h>
#endif
#include "trim.h"
#include "INLOptions.h"
// #include "Flasher.h"

#define SYMBOL_SUCCESS "√ "
#define SYMBOL_ERROR "× "
#define SYMBOL_INFO "i "
#define SYMBOL_POINT "▸ " // ">"
#define SYMBOL_WARNING "‼ "

// On Windows, due to internal usage of <windows.h>, global namespace could be polluted with min/max macros.
// If such effect is desireable, please consider using #define NOMINMAX before #include <termcolor.hpp>
#include "termcolor.hpp"

// uncomment to DEBUG this file alone
// #define DEBUG // NOTE: collision with project defined DEBUG
//"make debug" to get DEBUG msgs on entire program
#include "dbg.h"

const char *HELP = "Usage: INLretro [options]\n\n"
                   "Options/Flags:\n"
                   "  --help, -h                                   Displays this message\n"
                   "  --retroprog_id=id, -i id                     Retro-Prog ID\n"
                   "  --console=console, -c console                Console: GBA, GENESIS, NES\n" // SNES, N64
                   "  --mapper=mapper, -m mapper                   NES, SNES, GB consoles only, mapper ASIC on cartridge\n"
                   "                                               NES:    action53, bnrom, cdream, cninja, cnrom, dualport,\n"
                   "                                                       easynsf, fme7, mapper30, mmc1, mmc3, mmc4, mmc5,\n"
                   "                                                       nrom, rainbow, unrom\n"
                   "                                               GB:     mbc1, mbc1_discrete, mbc5\n"
                   //  "                                               SNES:   lorom, hirom\n"
                   "                                               GENESIS:32mb\n" //, ssf2, rainbow\n"
                   "  --rom_dump_file=filename, -d filename        If provided, dump cartridge ROMs to this filename\n"
                   "  --rom_write_file=filename, -p filename       If provided, write this data to cartridge\n"
                   "  --ram_dump_file=filename, -a filename        If provided, dump ram to this filename\n"
                   "  --ram_write_file=filename, -b filename       If provided write this file's contents to ram\n"
                   "  --verify, -v                                 Dump ROM after flashing and verify it against flashed file\n"
                   "  --nes_prg_rom_size_kbyte=size, -x size       NES-only, size of PRG-ROM in kilobytes\n"
                   "  --nes_chr_rom_size_kbyte=size, -y size       NES-only, size of CHR-ROM in kilobytes\n"
                   "  --rom_size_kbyte=size, -k size               Size of ROM in kilobytes, non-NES systems\n"
                   "  --rom_size_mbit=size, -z size                Size of ROM in megabits, non-NES systems\n"
                   "  --wram_size_kbyte=size, -w size              NES-only, size of WRAM in kilobytes\n"
                   "  --additional_opts=opts, -o opts              Can be used to provide more options/data to a specific mapper script\n"
                   "                                               NES: used for bank table address for mapper BxROM\n"
                   "  --lua_file=filename, -s filename             If provided, use this script for main application logic\n"
                   "  --debug, -g                                  Debug mode, displays more details\n";

/**
 * @brief Take a mixed-case string and convert to only lowercase.
 *
 * @param str
 */
// void strToLower(char *str)
// {
//   while (*str)
//   {
//     *str = (char)tolower(*str);
//     str++;
//   }
// }

/**
 * @brief Parse options and flags, create struct to drive program.
 *
 * @param argc
 * @param argv
 * @return bool true if we could parse the options, false if not
 */
bool parseOptions(int argc, char *argv[], t_INLoptions_std *opts)
{
  // Declare command line flags/options.
  static struct option longopts[] = {
      {"ram_dump_file", required_argument, NULL, 'a'},
      {"ram_write_file", required_argument, NULL, 'b'},
      {"console", required_argument, NULL, 'c'},
      {"rom_dump_file", required_argument, NULL, 'd'},
      {"debug", no_argument, NULL, 'g'},
      {"help", no_argument, NULL, 'h'},
      {"retroprog_id", required_argument, NULL, 'i'},
      {"rom_size_kbyte", required_argument, NULL, 'k'},
      {"mapper", required_argument, NULL, 'm'},
      {"additional_opts", required_argument, NULL, 'o'},
      {"rom_write_file", required_argument, NULL, 'p'},
      {"lua_file", required_argument, NULL, 's'},
      {"verify", no_argument, NULL, 'v'}, // optional_argument
      {"wram_size_kbyte", required_argument, NULL, 'w'},
      {"nes_prg_rom_size_kbyte", required_argument, NULL, 'x'},
      {"nes_chr_rom_size_kbyte", required_argument, NULL, 'y'},
      {"rom_size_mbit", required_argument, NULL, 'z'},
      {0, 0, 0, 0} // longopts must end in {0, 0, 0, 0}
  };

  char buf[256];

  // FLAG_FORMAT must be kept in sync with any short options used in longopts.
  const char *FLAG_FORMAT = "a:b:c:d:ghi:k:m:o:p:s:vw:x:y:z:";
  int index = 0;
  int rv = 0;
  int kbyte = 0;
  opterr = 0;

  // init options struct
  // INLOptions *opts = calloc(1, sizeof(INLOptions));
  // t_INLoptions *opts = (t_INLoptions *)calloc(1, sizeof(t_INLoptions));
  // t_INLoptions_std opts; // (t_INLoptions*)malloc(sizeof(t_INLoptions));
  opts->retroprog_id = "g";
  opts->console_name = "";
  opts->mapper_name = "";
  opts->rom_dump_file = "";
  opts->rom_write_file = "";
  opts->ram_dump_file = "";
  opts->ram_write_file = "";
  opts->verify = false;
  opts->additional_opts = "";
  opts->lua_file = "";
  opts->debug = false;
  opts->gui = false;
  opts->display_help = false;

  if (argc <= 1)
  {
    opts->display_help = true;
  }

  // getopt returns args till done then returns -1
  // string of possible args : denotes 1 required additional arg
  //:: denotes optional additional arg follows
  while ((rv = getopt_long(argc, argv, FLAG_FORMAT, longopts, NULL)) != -1)
  {
    switch (rv)
    {
    case 'a':
      opts->ram_dump_file.assign(optarg);
      break;

    case 'b':
      opts->ram_write_file.assign(optarg);
      break;

    case 'h':
      opts->display_help = true;
      break;

    case 'c':
      opts->console_name.assign(optarg);
      break;

    case 'd':
      opts->rom_dump_file.assign(optarg);
      break;

    case 'g':
      opts->debug = true;
      break;

    case 'i':
      opts->retroprog_id.assign(optarg);
      break;

    case 'k':
      opts->rom_size_kb = atoi(optarg);
      break;

    case 'm':
      opts->mapper_name.assign(optarg);
      break;

    case 'o':
      opts->additional_opts.assign(optarg);
      break;

    case 'p':
      opts->rom_write_file.assign(optarg);
      break;

    case 's':
      opts->lua_file.assign(optarg);
      break;

    case 'v':
      opts->verify = true;
      break;

    case 'w':
      opts->wram_size_kb = atoi(optarg);
      break;

    case 'x':
      opts->prg_rom_size_kb = atoi(optarg);
      break;

    case 'y':
      opts->chr_rom_size_kb = atoi(optarg);
      break;

    case 'z':
      kbyte = atoi(optarg) * 128;
      if (opts->rom_size_kb && opts->rom_size_kb != kbyte)
      {
        printf("rom_size_mbit disagrees with rom_size_kbyte! Using %d Kb as rom size.\n", kbyte);
      }
      opts->rom_size_kb = kbyte;
      break;

    case '?':
      if ((optopt == 'c') || (optopt == 'd') || (optopt == 'm') || (optopt == 'o') || (optopt == 'p') || (optopt == 's'))
      {
        snprintf(buf, sizeof(buf), "Option -%c requires an argument", optopt);
        std::cout << termcolor::red << SYMBOL_ERROR << buf << termcolor::reset << std::endl;
        // log_err("Option -%c requires an argument.", optopt);
        // return false;
        opts->display_help = true;
      }
      else if (isprint(optopt))
      {
        snprintf(buf, sizeof(buf), "Unknown option -%c", optopt);
        std::cout << termcolor::red << SYMBOL_ERROR << buf << termcolor::reset << std::endl;
        // log_err("Unknown option -%c .", optopt);
        // return false;
        opts->display_help = true;
      }
      else
      {
        snprintf(buf, sizeof(buf), "Unknown option character '\\x%x'", optopt);
        std::cout << termcolor::red << SYMBOL_ERROR << buf << termcolor::reset << std::endl;
        // log_err("Unknown option character '\\x%x'", optopt);
        // return false;
        opts->display_help = true;
      }
      std::cout << termcolor::red << SYMBOL_ERROR << "Improper arguments passed" << termcolor::reset << std::endl;
      // log_err("Improper arguments passed");
      // return false;
      opts->display_help = true;
      break;

    default:
      std::cout << termcolor::red << SYMBOL_ERROR << "getopt failed to catch all arg cases" << termcolor::reset << std::endl;
      // printf("getopt failed to catch all arg cases");
      // return 0;
      // return false;
      opts->display_help = true;
    }
  }

  for (index = optind; index < argc; index++)
  {
    snprintf(buf, sizeof(buf), "Non-option argument: %s \n", argv[index]);
    std::cout << termcolor::red << SYMBOL_ERROR << buf << termcolor::reset << std::endl;
    // log_err("Non-option argument: %s \n", argv[index]);
  }

  if (opts->display_help)
  {
    std::cout << HELP << std::endl;
    // printf("%s", HELP);
    return false;
  }

  // Handle console, mapper as case-insensitive configuration.
  std::transform(opts->console_name.begin(), opts->console_name.end(), opts->console_name.begin(), [](unsigned char c)
                 { return std::tolower(c); });
  std::transform(opts->mapper_name.begin(), opts->mapper_name.end(), opts->mapper_name.begin(), [](unsigned char c)
                 { return std::tolower(c); });

  return true;
}

// /**
//  * @brief
//  *
//  * @param argc
//  * @param argv
//  * @return int
//  */
// int inlprog_cli(int argc, char *argv[])
// {
//   // Parse command-line options and flags.
//   t_INLoptions *opts = parseOptions(argc, argv);
//   if (!opts)
//   {
//     // If unparseable, exit.
//     return 1;
//   }
//   // TODO / FIXME
//   // Flasher flasher(std::string(opts->retroprog_id), true);
//   // flasher.inlprog_opt(*opts);
//   return 0;
// }

/**
 * @brief Get the cli object
 *
 * @param INLoptions
 * @return std::string
 */
std::string get_cli(t_INLoptions_std INLoptions)
{
  std::string cli;
  cli = "inlretro.exe";

  // console name
  cli += " -c " + INLoptions.console_name;

  // mapper
  if (INLoptions.mapper_name != "")
  {
    cli += " -m " + INLoptions.mapper_name;
  }

  // rom size
  if (INLoptions.rom_write_file != "" || INLoptions.rom_dump_file != "")
  {
    if (INLoptions.console_name == "nes" || INLoptions.console_name == "famicom" || INLoptions.console_name == "fc")
    {
      cli += " -x " + std::to_string(INLoptions.prg_rom_size_kb);
      cli += " -y " + std::to_string(INLoptions.chr_rom_size_kb);
    }
    else
    {
      cli += " -k " + std::to_string(INLoptions.rom_size_kb);
    }
  }

  // rom dump file?
  if (INLoptions.rom_dump_file != "")
  {
    cli += " -d \"" + INLoptions.rom_dump_file + "\"";
  }

  // rom write file?
  if (INLoptions.rom_write_file != "")
  {
    cli += " -p \"" + INLoptions.rom_write_file + "\"";
  }

  // verify?
  if (INLoptions.verify)
  {
    cli += " -v";
  }

  // ram size?
  if (INLoptions.wram_size_kb != 0)
  {
    cli += " -w " + std::to_string(INLoptions.wram_size_kb);
  }

  // ram dump file?
  if (INLoptions.ram_dump_file != "")
  {
    cli += " -a \"" + INLoptions.ram_dump_file + "\"";
  }

  // ram write file?
  if (INLoptions.ram_write_file != "")
  {
    cli += " -b \"" + INLoptions.ram_write_file + "\"";
  }

  // additional options?
  trim(INLoptions.additional_opts);
  if (INLoptions.additional_opts != "")
  {
    cli += " -o \"" + INLoptions.additional_opts + "\"";
  }

  return cli;
}
