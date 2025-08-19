#include <iostream>
#include <thread>
#include <vector>
#include <string>

#include "AppLog.h"
#include "Flasher.h"
#include "lua.hpp"
#include "Lua.h"

#ifdef __APPLE__
#include "macos.h"
#endif

std::vector<Flasher *> Flasher::list;

void Flasher::clear_list()
{
  for (auto &flasher : list)
  {
    delete flasher;
  }

  list.clear();
}

void Flasher::detect_all()
{
  // clear flasher list
  clear_list();

  // try to detect INL Retro-Prog flasher
  if (detect("g"))
  {
    list.push_back(new Flasher("g", true));
    APP_LOG(LogTypes_Success, L_SYS "Flasher 'INLretroprog' detected");
  }

  // try to detect INL Retro-Pro[0-9] flashers
  for (size_t i = 0; i <= 9; i++)
  {
    char id[2];
    id[0] = '0' + (char)i;
    id[1] = 0;
    if (detect(id))
    {
      list.push_back(new Flasher(id, true));
      APP_LOG(LogTypes_Success, L_SYS "Flasher 'INLretropro%c' detected", id[0]);
    }
  }
}

bool Flasher::is_flashing()
{
  for (auto &flasher : list)
  {
    if (flasher->isFlashing)
    {
      return true;
      break;
    }
  }
  return false;
}

int Flasher::count_flashing()
{
  int count = 0;
  for (auto &flasher : list)
  {
    if (flasher->isFlashing)
    {
      count++;
    }
  }
  return count;
}

void Flasher::exec_all(t_INLoptions_std opts)
{
  for (auto &flasher : list)
  {
    if (flasher->isActive && !flasher->isFlashing)
    {
      flasher->exec(opts);
    }
  }
}

/**
 * @brief Construct a new Flasher:: Flasher object
 *
 * @param id Flasher ID, last character of the USB device name (INL Retro-Pro_)
 * @param isActive Flasher to be used or not
 */
Flasher::Flasher(const std::string &id, bool isActive)
{
  this->id = id;
  this->isActive = isActive;
  this->firmwareVersion = get_device_version(this->id.c_str()[0]);
  this->hardwareType = get_device_hardware_type(this->id.c_str()[0]);
  lua.setLog(&this->log);

  this->isFlashing = false;
}

/**
 * @brief Destroy the Flasher:: Flasher object
 *
 */
Flasher::~Flasher() {}

/**
 * @brief Setup INL USB Device
 *
 * @param libusb_log
 * @param retroprog_id
 * @return USBtransfer*
 */
USBtransfer *Flasher::usb_inldevice_open(int libusb_log, const char *retroprog_id, Log *log)
{
  // Create USBtransfer struct to hold all transfer info
  USBtransfer *transfer = (USBtransfer *)calloc(1, sizeof(USBtransfer));

  // Create USB device handle pointer to interact with retro-prog.
  transfer->handle = open_usb_device(libusb_log, retroprog_id, log);

  return transfer;
}

/**
 * @brief Close and cleanup INL USB Device
 *
 * @param transfer
 */
void Flasher::usb_inldevice_close(USBtransfer *transfer)
{
  if (transfer)
  {
    close_usb(transfer->handle);
  }

  if (transfer)
  {
    free(transfer);
  }
}

/**
 * @brief Detects a specific INL Retro-Prog flasher
 *
 * @param retroprog_id Character to be used in the device name (INL Retro-Pro?)
 * @return true if USB device has been detected
 * @return false if USB device has NOT been detected
 */
bool Flasher::detect(const char *retroprog_id)
{
  // USB variables
  USBtransfer *transfer = NULL;

  // Default to no libusb logging.
  int libusb_log = LIBUSB_LOG_LEVEL_NONE;

  transfer = usb_inldevice_open(libusb_log, retroprog_id, &AppLog::log);
  if (!transfer)
  {
    return false;
  }

  if (transfer->handle == NULL)
  {
    return false;
  }

  // USB device is open, we can clean up and return
  usb_inldevice_close(transfer);

  return true;
}

/**
 * @brief Starts flashing
 *
 * @param opts
 */
bool Flasher::exec(t_INLoptions_std opts)
{
  // clear log
  log.clear();

  // update path if on macOS
#ifdef __APPLE__
  std::string applePath;

#ifdef _DIST
  if (getResourcesPath(applePath) == -1)
  {
    APP_LOG(LogTypes_Error, L_SYS "Couldn't get resources path");
    return false;
  }
#else
  if (getExecutablePath(applePath) == -1)
  {
    APP_LOG(LogTypes_Error, L_SYS "Couldn't get executable path");
    return false;
  }
#endif
  opts.lua_path = applePath;
#else
  opts.lua_path = "./";
#endif

  // start script in a separate thread
  isFlashing = true;
  opts.retroprog_id = id;
  if (opts.gui)
  {
    std::thread t(&Flasher::t_inlprog_opt, this, opts);
    t.detach();
  }
  else
  {
    inlprog_opt(opts);
  }

  return true;
}

void Flasher::update_firmware(std::string firmware_file)
{
  t_INLoptions_std firmware_INLOptions;
  firmware_INLOptions.gui = true;
  firmware_INLOptions.retroprog_id = this->id;
  firmware_INLOptions.rom_write_file = firmware_file;
  firmware_INLOptions.lua_file = "scripts/inlretro_fwupdate.lua";
  this->exec(firmware_INLOptions);
}

/**
 * @brief
 *
 * @param opts
 * @return int
 */
int Flasher::t_inlprog_opt(const t_INLoptions_std &opts)
{
  int r = inlprog_opt(opts);
  isFlashing = false;
  return r;
}

/**
 * @brief
 *
 * @param opts
 * @return int
 */
int Flasher::inlprog_opt(const t_INLoptions_std &opts)
{
  // USB variables
  USBtransfer *transfer = NULL;

  // Default to no libusb logging.
  int libusb_log = LIBUSB_LOG_LEVEL_NONE;

  // Lua variables.
  lua_State *L = NULL;

  // Default script
  std::string luaScript = "";
  std::string luaUsbScript;

#ifdef __APPLE__
  luaUsbScript = opts.lua_path + "scripts/app/usb_device.lua";
  luaScript = opts.lua_path;
#else
  luaUsbScript = "scripts/app/usb_device.lua";
#endif

  // Start up Lua.
  L = lua.init(opts);

#ifdef __APPLE__
  // set the package path for 'require' to work correctly
  std::string cur_path;
  lua_getglobal(L, "package");
  lua_getfield(L, -1, "path");    // get field "path" from table at top of stack (-1)
  cur_path = lua_tostring(L, -1); // grab path string from top of stack
  cur_path.append(";");           // do your path magic here
  cur_path.append(opts.lua_path);
  cur_path.append("?.lua");
  lua_pop(L, 1);                       // get rid of the string on the stack we just pushed on line 5
  lua_pushstring(L, cur_path.c_str()); // push the new one
  lua_setfield(L, -2, "path");         // set the field "path" in table at -2 with value at top of stack
  lua_pop(L, 1);                       // get rid of package table from top of stack
#endif

  // Setup and check connection to USB Device.
  // TODO get usb device settings from usb_device.lua

  // Lua script arg to set different libusb debugging options.
  check(&log, !(luaL_loadfile(L, luaUsbScript.c_str()) || lua_pcall(L, 0, 0, 0)),
        "Cannot run config. file: %s", lua_tostring(L, -1));

  // Any value > 0 for libusb_log also prints debug statements in open_usb_device function.
  // libusb_log = 0; // getglobint(L, "libusb_log");
  check(&log, ((libusb_log >= LIBUSB_LOG_LEVEL_NONE) && (libusb_log <= LIBUSB_LOG_LEVEL_DEBUG)),
        "Invalid LIBUSB_LOG_LEVEL: %d, must be from 0 to 4", libusb_log);

  // USBtransfer *transfer = (USBtransfer *)calloc(1, sizeof(USBtransfer));

  transfer = usb_inldevice_open(libusb_log, (char *)opts.retroprog_id.c_str(), &log);

  // transfer->handle = usb_open(opts.retroprog_id.c_str()[0]);

  check_mem(&log, transfer);
  /*if (transfer->handle == NULL) {
    printf("oops");
  }*/

  if (transfer->handle == NULL)
  {
    // std::cout << "Unable to open INL retro-prog usb device handle" << std::endl;
    goto error;
  }
  // check(transfer->handle != NULL, "Unable to open INL retro-prog usb device handle.");

  // pass USB handle to Lua object
  lua.usb_handle = transfer->handle;

  // USB device is open, pass args and control over to Lua.
  // If lua_filename isn't set from args, use default script.
  if (strlen(opts.lua_file.c_str()))
  {
    luaScript += opts.lua_file;
  }
  else
  {
    luaScript += "scripts/inlretro2.lua";
  }

  check(&log, !(luaL_loadfile(L, luaScript.c_str()) || lua_pcall(L, 0, 0, 0)),
        "cannot run config. file: %s", lua_tostring(L, -1));
  // if (!(!(luaL_loadfile(L, script) || lua_pcall(L, 0, 0, 0))))
  // {
  //   std::string luaErr = std::string(lua_tostring(L, -1));
  //   log_err("cannot run config. file: %s", luaErr.c_str());
  //   log.add(LogTypes_Error, luaErr);
  //   errno = 0;
  //   goto error;
  // }

  // Program flow doesn't come back to this point until script call ends/returns.
  cleanup(transfer);
  return 0;

  // 'check' macros goto this label if they fail.
error:
  log_err(&log, "Fatal error encountered, exiting.");
  cleanup(transfer);
  return 1;
}

/**
 * @brief Safely cleanup for exiting program and release resources
 *
 * @param transfer
 * @param L
 */
void Flasher::cleanup(USBtransfer *transfer)
{
  usb_inldevice_close(transfer);
  lua.close();
}
