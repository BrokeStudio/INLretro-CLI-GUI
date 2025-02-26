#pragma once
#ifndef APPLOG_H
#define APPLOG_H

#include "Log.h"

#define APP_LOG(...) AppLog::log.add(__VA_ARGS__)
#define APP_LOG_SYS(...) AppLog::log.add(__VA_ARGS__)

#define L_INI "[INI] "
#define L_SYS "[SYS] "

namespace AppLog
{
  // extern bool cliOutput;
  extern Log log;
  // void render();
  // void sys_add(LogTypes type, const char *fmt, ...);
}

#endif
