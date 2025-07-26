#pragma once
#ifndef LUA_H
#define LUA_H

#ifdef _WIN32
#include "libusb.h"
#else
#include <libusb-1.0/libusb.h>
#endif
#include "INLOptions.h"
#include "lua.hpp"
#include "Log.h"

class Lua
{

public:
  Log *log = NULL;
  lua_State *L = NULL;
  libusb_device_handle *usb_handle = NULL;

  Lua();
  lua_State *init(const t_INLoptions_std &opts);
  // lua_State *init(t_INLoptions *opts);
  void close();
  void setLog(Log *log);

private:
  // void error(lua_State *L, const char *fmt, ...);
  void error(const char *fmt, ...);
  // int getglobint(lua_State *L, const char *var);
  int getglobint(const char *var);
  int l_log_add(lua_State *L);
  int l_log_spinner_update(lua_State *LL);
  int l_log_spinner_clear(lua_State *LL);
  int usb_vend_xfr(lua_State *L);
};

#endif
