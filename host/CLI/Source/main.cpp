#include <iostream>

// On Windows, due to internal usage of <windows.h>, global namespace could be polluted with min/max macros.
// If such effect is desireable, please consider using #define NOMINMAX before #include <termcolor.hpp>
#include "termcolor.hpp"
#include "version.h"
#include "build.h"

// Core files
#include "cli.h"
#include "INLOptions.h"
#include "Flasher.h"

int main(int argc, char** argv)
{
#if defined(_WIN32)
  // allows for ANSI codes to be output correctly on Windows
  // SetConsoleCP(65001);
  SetConsoleOutputCP(65001);
  HANDLE hInput = GetStdHandle(STD_INPUT_HANDLE);
  SetConsoleMode(hInput, ENABLE_PROCESSED_INPUT | ENABLE_LINE_INPUT); // | ENABLE_VIRTUAL_TERMINAL_INPUT);
  HANDLE hOutput = GetStdHandle(STD_OUTPUT_HANDLE);
  SetConsoleMode(hOutput, ENABLE_PROCESSED_OUTPUT | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
#endif

  std::cout << termcolor::bright_yellow
            << " ___ _  _ _            _           " << std::endl
            << "|_ _| \\| | |   _ _ ___| |_ _ _ ___ " << std::endl
            << " | || .` | |__| '_/ -_)  _| '_/ _ \\" << std::endl
            << "|___|_|\\_|____|_| \\___|\\__|_| \\___/" << std::endl
            << termcolor::reset
#if defined(_DEBUG) || defined(_RELEASE)
            << "v" << INLRETRO_CLI_VERSION << "-dev+build." << INLRETRO_CLI_BUILD << std::endl
#else
            << "v" << INLRETRO_CLI_VERSION << std::endl
#endif
            << std::endl;

  t_INLoptions_std* opts = new t_INLoptions_std();

  AppLog::log.cliOutput = true;

  // Setup USB
  int usb_init = libusb_init(NULL);
  // if (usb_init < 0)
  // {
  //   printf("Error: %s\n", libusb_error_name(usb_init));
  //   exitCode = usb_init;
  //   goto done;
  //   // printf("Error: %s\n", libusb_error_name(usb_init));
  //   // return usb_init;
  // }
  // libusb_set_option(NULL, LIBUSB_OPTION_LOG_LEVEL, LIBUSB_LOG_LEVEL_DEBUG);
  check(&AppLog::log, usb_init == LIBUSB_SUCCESS, "Failed to initialize libusb: %s", libusb_strerror((libusb_error)usb_init));

  // Parse command-line options and flags.
  if(!parseOptions(argc, argv, opts)) {
    goto error;
  } else {
    // flash
    opts->gui = false;
    Flasher flasher(std::string(opts->retroprog_id), true);
    flasher.log.cliOutput = true;
    int res = flasher.inlprog_opt(*opts);
    APP_LOG_SYS(LogTypes_None, "");
    APP_LOG_SYS(LogTypes_Success, "Done !");
  }

  if(usb_init == LIBUSB_SUCCESS) {
    libusb_exit(NULL);
  }

#if defined(_DEBUG) || defined(_RELEASE)
  APP_LOG_SYS(LogTypes_None, "");
  APP_LOG_SYS(LogTypes_Info, "Press any key...");
  std::cin.get();
#endif

  return 0;

error:

  if(usb_init == LIBUSB_SUCCESS) {
    libusb_exit(NULL);
  }

#if defined(_DEBUG) || defined(_RELEASE)
  APP_LOG_SYS(LogTypes_None, "");
  APP_LOG_SYS(LogTypes_Info, "Press any key...");
  std::cin.get();
#endif

  return 1;
}
