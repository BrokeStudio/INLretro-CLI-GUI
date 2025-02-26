// #include <string.h>
#include <stdlib.h>

#include "usb_operations.h"
// #include "Log.h"
#include "Lua.h"

typedef int (Lua::*mem_func)(lua_State *L);

// This template wraps a member function into a C-style "free" function compatible with lua.
template <mem_func func>
int dispatch(lua_State *L)
{
  Lua *ptr = *static_cast<Lua **>(lua_getextraspace(L));
  return ((*ptr).*func)(L);
}

/**
 * @brief Construct a new Lua:: Lua object
 *
 */
Lua::Lua()
{
}

/**
 * @brief Set log pointer
 *
 * @param _log
 */
void Lua::setLog(Log *_log)
{
  this->log = _log;
}

/**
 * @brief Setup Lua environment
 *
 * @param opts
 * @return lua_State*
 */
// lua_State *Lua::init(t_INLoptions *opts)
lua_State *Lua::init(const t_INLoptions_std &opts)
{
  this->L = luaL_newstate(); // opens Lua
  luaL_openlibs(this->L);    // opens the standard libraries

  // register log function
  *static_cast<Lua **>(lua_getextraspace(this->L)) = this;

  // const luaL_Reg regs[] = {
  // { "callback_1", &dispatch<&my_class::callback_1> },
  // { NULL, NULL }
  // };
  // luaL_register(this->L, regs);
  // lua_register(this->L, "print", &dispatch<&Lua::l_log_add>);
  if (opts.gui)
  {
    lua_register(this->L, "gui_log_add", &dispatch<&Lua::l_log_add>);
    lua_register(this->L, "gui_spinner_update", &dispatch<&Lua::l_log_spinner_update>);
    lua_register(this->L, "gui_spinner_clear", &dispatch<&Lua::l_log_spinner_clear>);
  }

  // Register C functions that can be called from Lua.
  lua_pushcfunction(this->L, &dispatch<&Lua::usb_vend_xfr>);
  lua_setglobal(this->L, "usb_vend_xfr");

  // Pass args to Lua

  // register options table
  lua_newtable(this->L);

  lua_pushstring(this->L, opts.console_name.c_str());
  lua_setfield(this->L, -2, "console_name");

  lua_pushstring(this->L, opts.mapper_name.c_str());
  lua_setfield(this->L, -2, "mapper_name");

  lua_pushstring(this->L, opts.rom_dump_file.c_str());
  lua_setfield(this->L, -2, "rom_dump_file");

  lua_pushstring(this->L, opts.rom_write_file.c_str());
  lua_setfield(this->L, -2, "rom_write_file");

  lua_pushboolean(this->L, opts.verify);
  lua_setfield(this->L, -2, "verify");

  lua_pushstring(this->L, opts.ram_dump_file.c_str());
  lua_setfield(this->L, -2, "ram_dump_file");

  lua_pushstring(this->L, opts.ram_write_file.c_str());
  lua_setfield(this->L, -2, "ram_write_file");

  lua_pushinteger(this->L, opts.rom_size_kb);
  lua_setfield(this->L, -2, "rom_size_kb");

  lua_pushinteger(this->L, opts.wram_size_kb);
  lua_setfield(this->L, -2, "nes_wram_size_kb");

  lua_pushinteger(this->L, opts.prg_rom_size_kb);
  lua_setfield(this->L, -2, "nes_prg_rom_size_kb");

  lua_pushinteger(this->L, opts.chr_rom_size_kb);
  lua_setfield(this->L, -2, "nes_chr_rom_size_kb");

  lua_pushstring(this->L, opts.retroprog_id.c_str());
  lua_setfield(this->L, -2, "retroprog_id");

  lua_pushboolean(this->L, opts.debug);
  lua_setfield(this->L, -2, "debug");

  lua_pushstring(this->L, opts.additional_opts.c_str());
  lua_setfield(this->L, -2, "additional_opts");

  lua_pushboolean(this->L, opts.gui);
  lua_setfield(this->L, -2, "gui");

  lua_setglobal(this->L, "opts"); // set options table as global variable

  return this->L;
}

/**
 * @brief Close lua state
 *
 */
void Lua::close()
{
  if (this->L)
  {
    lua_close(this->L);
  }
}

/*
void load(lua_State *L, const char *fname, int *w, int *h)
{
  if (luaL_loadfile(this->L, fname) || lua_pcall(this->L, 0, 0, 0))
    error_lua(this->L, "cannot run config. file: %s", lua_tostring(this->L, -1));
  *w = getglobint(this->L, "width");
  *h = getglobint(this->L, "height");
}
*/

// private

// void Lua::error(lua_State *L, const char *fmt, ...)
void Lua::error(const char *fmt, ...)
{
  va_list argp;
  va_start(argp, fmt);
  vfprintf(stderr, fmt, argp);
  va_end(argp);
  char errmsg[1024];
  // sprintf_s(errmsg, fmt, argp);
  sprintf(errmsg, fmt, argp);
  this->log->add(LogTypes_Error, errmsg);
  lua_close(this->L);
  exit(EXIT_FAILURE);
}

// int Lua::getglobint(lua_State *L, const char *var)
int Lua::getglobint(const char *var)
{
  int isnum, result;
  lua_getglobal(this->L, var);
  result = (int)lua_tointegerx(this->L, -1, &isnum);
  if (!isnum)
    this->error("'%s' should be a number", var);
  lua_pop(this->L, 1); /* remove result from the stack */
  return result;
}

/**
 * @brief Add entry to log
 *
 * @param L lua state
 * @return int
 */
int Lua::l_log_add(lua_State *LL)
{
  if (this->log == NULL)
  {
    return 0;
  }

  std::string logMessage = "";
  int logType = 0;
  int nArgs = lua_gettop(LL);
  for (int i = 1; i <= nArgs; i++)
  {
    // if (lua_isinteger(LL, i))
    if (lua_type(LL, i) == LUA_TNUMBER)
    {
      logType = lua_tointeger(LL, i);
    }
    // else if (lua_isstring(LL, i))
    else if (lua_type(LL, i) == LUA_TSTRING)
    {
      // Pop the next arg using lua_tostring(L, i) and do your print
      logMessage = lua_tostring(LL, i);
    }
    else
    {
      // Do something with non-strings if you like
      this->log->add(LogTypes_Warning, "unsupported type");
      return 0;
    }
  }
  this->log->add(logType, logMessage);

  return 0;
}

/**
 * @brief Update log spinner
 *
 * @param LL lua state
 * @return int
 */
int Lua::l_log_spinner_update(lua_State *LL)
{
  if (this->log == NULL)
  {
    return 0;
  }

  int nArgs = lua_gettop(LL);
  for (int i = 1; i <= nArgs; i++)
  {
    // if (lua_isstring(LL, i))
    if (lua_type(LL, i) == LUA_TSTRING)
    {
      // Pop the next arg using lua_tostring(L, i)
      this->log->spinner_update(lua_tostring(LL, i));
    }
    else
    {
      // Do something with non-strings if you like
      char tmp[] = "unsupported type";
      this->log->add(LogTypes_Warning, tmp);
    }
  }
  return 0;
}

/**
 * @brief Clear log spinner
 *
 * @param LL lua state
 * @return int
 */
int Lua::l_log_spinner_clear(lua_State *LL)
{
  if (this->log == NULL)
  {
    return 0;
  }

  int nArgs = lua_gettop(LL);
  this->log->spinner_clear();
  return 0;
}

/**
 * @brief initialize usb transfer based on args passed in from lua and transfer setup packet over USB
 *
 * @param L lua state
 * @return int
 */
int Lua::usb_vend_xfr(lua_State *L)
{
  /*
  typedef struct USBtransfer {
    libusb_device_handle *handle;
    uint8_t		endpoint;
    uint8_t		request;
    uint16_t	wValue;
    uint16_t	wIndex;
    uint16_t	wLength;
    unsigned char	*data;
  } USBtransfer;
  */
  uint8_t data_buff[MAX_VUSB];
  int i;
  const char *lua_out_string;
  int xfr_count = 0; // return count
  int rv = 0;        // number of return values

  USBtransfer usb_xfr;
  usb_xfr.handle = this->usb_handle;         // lua_usb_handle;
  usb_xfr.endpoint = luaL_checknumber(L, 1); /* get endpoint argument */
  usb_xfr.request = luaL_checknumber(L, 2);  /* get request argument */
  usb_xfr.wValue = luaL_checknumber(L, 3);   /* get wValue argument */
  usb_xfr.wIndex = luaL_checknumber(L, 4);   /* get wIndex argument */
  usb_xfr.wLength = luaL_checknumber(L, 5);  /* get wLength argument */
  check(this->log, (usb_xfr.wLength <= MAX_VUSB), "Can't transfer more than %d bytes!", MAX_VUSB);
  if (usb_xfr.endpoint == LIBUSB_ENDPOINT_OUT)
  {
    // OUT transfer sending data to device
    lua_out_string = luaL_checkstring(L, 6); /* get data argument */
    // 2 rules for lua strings in C: don't pop it, and don't modify it!!!
    // copy lua string over to data buffer
    for (i = 0; i < usb_xfr.wLength; i++)
    {
      data_buff[i] = lua_out_string[i];
    }
  }
  else
  {
    // IN transfer, zero out buffer
    for (i = 0; i < MAX_VUSB; i++)
    {
      data_buff[i] = 0;
    }
  }
  usb_xfr.data = data_buff;

  // printf("\nep %d, req %d", usb_xfr.endpoint, usb_xfr.request);
  // printf("wValue %d, wIndex %d", usb_xfr.wValue, usb_xfr.wIndex);
  // printf("wLength %d \n", usb_xfr.wLength);
  // printf("predata: %d, %d, %d, %d, %d, %d, %d, %d \n",  usb_xfr.data[0], usb_xfr.data[1],usb_xfr.data[2],usb_xfr.data[3],usb_xfr.data[4],usb_xfr.data[5], usb_xfr.data[6], usb_xfr.data[7]);

  // check( lua_usb_handle != NULL, "usb device handle pointer not initialized.\n")
  check(this->log, this->usb_handle != NULL, "usb device handle pointer not initialized.")

      xfr_count = usb_vendor_transfer(&usb_xfr, this->log);

  // printf("postdata: %d, %d, %d, %d, %d, %d, %d, %d \n",  usb_xfr.data[0], usb_xfr.data[1],usb_xfr.data[2],usb_xfr.data[3],usb_xfr.data[4],usb_xfr.data[5], usb_xfr.data[6], usb_xfr.data[7]);
  // printf("bytes xfrd: %d\n", xfr_count);

  lua_pushnumber(L, xfr_count); /* push first result */
  rv++;

  if (usb_xfr.endpoint == LIBUSB_ENDPOINT_IN)
  {
    // push second result if data was read from device
    lua_pushlstring(L, (const char *)data_buff, xfr_count);
    rv++;
  }

  return rv; /* number of results */

error:
  printf("lua USB transfer went to error\n");
  lua_pushstring(L, "ERROR"); /* push result */
  return 1;
}
