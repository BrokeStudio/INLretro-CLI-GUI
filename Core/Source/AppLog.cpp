// #include <iostream>
// #include <stdarg.h> // va_list, va_start, va_end

#include "AppLog.h"
#include "Log.h"
// #include "termcolor.hpp"

// #define APP_LOG_BUF_SIZE 2048

namespace AppLog
{
  // bool cliOutput = true;
  Log log;

  // void sys_add(LogTypes type, const char *fmt, ...)
  // {
  //   // FIXME-OPT
  //   char buf[APP_LOG_BUF_SIZE];
  //   va_list args;
  //   va_start(args, fmt);
  //   vsnprintf(buf, APP_LOG_BUF_SIZE, fmt, args);
  //   buf[APP_LOG_BUF_SIZE - 1] = 0;
  //   va_end(args);

  //   if (cliOutput)
  //   {
  //     switch (type)
  //     {

  //     case LogTypes_Section:
  //       std::cout << termcolor::magenta << SYMBOL_SECTION;
  //       break;

  //     case LogTypes_Info:
  //       std::cout << termcolor::cyan << SYMBOL_INFO;
  //       break;

  //     case LogTypes_Success:
  //       std::cout << termcolor::green << SYMBOL_SUCCESS;
  //       break;

  //     case LogTypes_Warning:
  //       std::cout << termcolor::yellow << SYMBOL_WARNING;
  //       break;

  //     case LogTypes_Error:
  //       std::cout << termcolor::red << SYMBOL_ERROR;
  //       break;

  //     case LogTypes_Point:
  //       std::cout << termcolor::cyan << SYMBOL_POINT;
  //       break;

  //     case LogTypes_Bullet:
  //       std::cout << termcolor::cyan << SYMBOL_BULLET;
  //       break;

  //     case LogTypes_None:
  //     default:
  //       std::cout << termcolor::white << SYMBOL_NONE;
  //       break;
  //     }
  //     std::cout << buf << termcolor::reset << std::endl;
  //   }
  //   else
  //   {
  //     log.add(type, std::string(buf));
  //   }
  // }
}
