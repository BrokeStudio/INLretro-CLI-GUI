#include <iostream>
#include <mutex>
#include <string>
#include <stdarg.h> // va_list, va_start, va_end

#include "Log.h"
#include "termcolor.hpp"

Log::Log(void)
{
  clear();
}

Log::~Log(void)
{
  clear();
}

void Log::clear(void)
{
  std::lock_guard<std::mutex> lock(stateMutex);

  Items.clear();
  spinner.clear();
  showSpinner = false;
}

void Log::add(const char* fmt, ...)
{
  // FIXME-OPT
  char buf[LOG_BUF_SIZE];
  va_list args;
  va_start(args, fmt);
  vsnprintf(buf, LOG_BUF_SIZE, fmt, args);
  buf[LOG_BUF_SIZE - 1] = 0;
  va_end(args);
  add(LogTypes_None, std::string(buf));
}

void Log::add(const std::string& message)
{
  add(LogTypes_None, message);
}

void Log::add(LogTypes type, const char* fmt, ...)
{
  // FIXME-OPT
  char buf[LOG_BUF_SIZE];
  va_list args;
  va_start(args, fmt);
  vsnprintf(buf, LOG_BUF_SIZE, fmt, args);
  buf[LOG_BUF_SIZE - 1] = 0;
  va_end(args);
  add(type, std::string(buf));
}

void Log::add(LogTypes type, const std::string& message)
{
  if(!cliOutput) {
    std::lock_guard<std::mutex> lock(stateMutex);
    Items.push_back({ type, message });
  } else {
    switch(type) {
      case LogTypes_Section:
        std::cout << termcolor::magenta << SYMBOL_SECTION;
        break;

      case LogTypes_Info:
        std::cout << termcolor::cyan << SYMBOL_INFO;
        break;

      case LogTypes_Success:
        std::cout << termcolor::green << SYMBOL_SUCCESS;
        break;

      case LogTypes_Warning:
        std::cout << termcolor::yellow << SYMBOL_WARNING;
        break;

      case LogTypes_Error:
        std::cout << termcolor::red << SYMBOL_ERROR;
        break;

      case LogTypes_Point:
        std::cout << termcolor::cyan << SYMBOL_POINT;
        break;

      case LogTypes_Bullet:
        std::cout << termcolor::cyan << SYMBOL_BULLET;
        break;

      case LogTypes_None:
      default:
        std::cout << termcolor::white << SYMBOL_NONE;
        break;
    }
    std::cout << message << termcolor::reset << std::endl;
  }
}

void Log::spinner_update(const char* fmt, ...)
{
  char buffer[LOG_SPINNER_SIZE];

  va_list args;
  va_start(args, fmt);
  vsnprintf(buffer, sizeof(buffer), fmt, args);
  va_end(args);

  buffer[sizeof(buffer) - 1] = '\0';

  std::lock_guard<std::mutex> lock(stateMutex);
  spinner = buffer;
  showSpinner = true;
}

void Log::spinner_clear()
{
  std::lock_guard<std::mutex> lock(stateMutex);
  spinner.clear();
  showSpinner = false;
}

LogSnapshot Log::get_snapshot()
{
  std::lock_guard<std::mutex> lock(stateMutex);

  return {
    Items,
    showSpinner,
    spinner,
  };
}
