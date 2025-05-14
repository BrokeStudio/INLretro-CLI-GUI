#pragma once
#ifndef LOG_H
#define LOG_H
#include <string>
#include <vector>
#include <shared_mutex>

#define LOG_BUF_SIZE 2048
#define LOG_SPINNER_SIZE 256

#define SYMBOL_NONE "  "
#define SYMBOL_SECTION "─ "
#define SYMBOL_INFO "i "
#define SYMBOL_SUCCESS "√ "
#define SYMBOL_WARNING "‼ "
#define SYMBOL_ERROR "× "
#define SYMBOL_POINT "▸ "
#define SYMBOL_BULLET "• "

typedef int LogTypes;
enum LogTypes_ : int
{
  LogTypes_None,
  LogTypes_Section,
  LogTypes_Info,
  LogTypes_Success,
  LogTypes_Warning,
  LogTypes_Error,
  LogTypes_Point,
  LogTypes_Bullet,
  LogTypes_Count,
};

struct LogMessage
{
  LogTypes type;
  std::string message;
};

class Log
{
private:
  std::vector<LogMessage> Items;
  std::shared_mutex itemsMutex;

  std::vector<LogMessage> getCopy()
  {
    std::shared_lock<std::shared_mutex> lock(itemsMutex);
    return Items;
  }

  bool showSpinner;
  char spinner[LOG_SPINNER_SIZE];

public:
  bool cliOutput = false;

  Log(void);
  ~Log(void);

  void clear(void);
  void add(const char* fmt, ...);
  void add(const std::string &message);
  void add(LogTypes type, const char *fmt, ...);
  void add(LogTypes type, const std::string &message);
  void spinner_update(const char *fmt, ...);
  // void spinner_update(const std::string &message);
  void spinner_clear(void);
  void render();
};

#endif
