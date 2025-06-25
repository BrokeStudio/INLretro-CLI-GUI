#include <iostream>
#include <thread>
#include <vector>
#include <string>

#include "AppLog.h"
#include "Flasher.h"
#include "lua.hpp"
#include "Lua.h"

#if __APPLE__
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

// static char check_device(libusb_device *dev, libusb_device_handle *handle)
// {
//   char result = '\0';
//   char inl_prod_id = '\0';
//   libusb_device_descriptor desc; // struct
//   char manf_str[256] = {0};
//   char prod_str[256] = {0};
//   char inl_manf_str[] = "InfiniteNesLives.com";
//   char inl_prod_str[] = "INL Retro-Pro"; // g"; // last character remove to support multiple flashers
//   uint16_t min_fw_ver = 0x200;
//   int ret;

//   // get device descriptor
//   ret = libusb_get_device_descriptor(dev, &desc);
//   if (ret < 0)
//   {
//     fprintf(stderr, "failed to get device descriptor");
//     return result;
//   }

//   // check device vendor id and product it
//   if ((desc.idVendor == 0x16C0) && (desc.idProduct == 0x05DC))
//   {
//     // try to open device if needed
//     if (!handle)
//     {
//       ret = libusb_open(dev, &handle);
//       if (ret < 0)
//       {
//         fprintf(stderr, "failed to open device");
//         return result;
//       }
//     }

//     // read manufacturer string
//     if (desc.iManufacturer)
//     {
//       ret = libusb_get_string_descriptor_ascii(handle, desc.iManufacturer, (unsigned char *)manf_str, sizeof(manf_str));
//       // if (ret > 0)
//       //   printf("  Manufacturer:              %s\n", manf_str);
//     }

//     // read product string
//     if (desc.iProduct)
//     {
//       ret = libusb_get_string_descriptor_ascii(handle, desc.iProduct, (unsigned char *)prod_str, sizeof(prod_str));
//       // if (ret > 0)
//       //   printf("  Product:                   %s\n", prod_str);
//     }

//     // check manufacturer id
//     if (strcmp(manf_str, inl_manf_str) == 0)
//     {
//       // save and clear the last character so we can support multiple flasher
//       // the last character is then used to differentiate the flashers
//       inl_prod_id = prod_str[13];
//       prod_str[13] = '\0';

//       // check product id
//       if (strcmp(prod_str, inl_prod_str) == 0)
//       {
//         // check firmware version
//         if (desc.bcdDevice >= min_fw_ver)
//         {
//           result = inl_prod_id;
//         }
//       }
//     }
//   }

//   if (handle)
//   {
//     libusb_close(handle);
//   }

//   return result;
// }

// void Flasher::detect_all_2()
// {
//   const char *device_name = NULL;
//   libusb_device **devs;
//   ssize_t cnt;

//   cnt = libusb_get_device_list(NULL, &devs);
//   if (cnt < 0)
//   {
//     return;
//   }

//   // search for INL flashers
//   for (int i = 0; i < cnt; i++)
//   {
//     libusb_device *dev = devs[i];
//     libusb_device_handle *handle = NULL;

//     char id = check_device(dev, handle);
//     if (id != '\0')
//     {
//       list.push_back(new Flasher(std::string(1, id), true));
//     }

//     // struct libusb_device_descriptor desc;
//     // unsigned char string[256];
//     // int ret;

//     // // get device descriptor
//     // ret = libusb_get_device_descriptor(dev, &desc);
//     // if (ret < 0)
//     // {
//     //   fprintf(stderr, "failed to get device descriptor");
//     //   return;
//     // }

//     // // check if device is INLretroprog
//     // if ((desc.idVendor == 0x16C0) && (desc.idProduct == 0x05DC))
//     // {
//     //   // try to open device if needed
//     //   if (!handle)
//     //   {
//     //     ret = libusb_open(dev, &handle);
//     //     printf("libusb_open ret val: %i\n", ret);
//     //     if (ret < 0)
//     //     {
//     //       fprintf(stderr, "failed to get open device");
//     //       return;
//     //     }
//     //   }

//     //   // read manufacturer string
//     //   if (desc.iManufacturer)
//     //   {
//     //     ret = libusb_get_string_descriptor_ascii(handle, desc.iManufacturer, string, sizeof(string));
//     //     // if (ret > 0)
//     //     printf("  Manufacturer:              %s\n", (char *)string);
//     //   }

//     //   // read product string
//     //   if (desc.iProduct)
//     //   {
//     //     ret = libusb_get_string_descriptor_ascii(handle, desc.iProduct, string, sizeof(string));
//     //     // if (ret > 0)
//     //     printf("  Product:                   %s\n", (char *)string);
//     //   }
//     // }

//     // if (handle)
//     // {
//     //   // for (int j = 0; i < sizeof(string); i++)
//     //   // {
//     //   //  if(string[j] == 0) break;
//     //   //     if(j==sizeof(string))
//     //   //     {
//     //   //       j = -1;
//     //   //       break;
//     //   //     }
//     //   //     j++;
//     //   // }
//     //   // list.push_back(new Flasher("g", true));
//     //   libusb_close(handle);
//     // }
//   }

//   libusb_free_device_list(devs, 1);
// }

void Flasher::detect_all()
{
  // clrear flasher list
  clear_list();

  // try to detect INL Retro-Prog flasher
  if (detect("g"))
  {
    list.push_back(new Flasher("g", true));
    APP_LOG(LogTypes_Success, "[SYS] Flasher 'INLretroprog' detected");
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
      APP_LOG(LogTypes_Success, "[SYS] Flasher 'INLretropro" + std::string(id) + "' detected");
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
Flasher::Flasher(const std::string &_id, bool _isActive)
{
  id = _id;
  isActive = _isActive;
  lua.setLog(&this->log);

  isFlashing = false;
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
USBtransfer *Flasher::usb_inldevice_open(int libusb_log, char *retroprog_id, Log *log)
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
bool Flasher::detect(char *retroprog_id)
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
// bool Flasher::flash(INLOptions *opts)
bool Flasher::exec(t_INLoptions_std opts)
{
  // // Check for sane user input.
  // if (strcmp("nes", opts.console_name) == 0)
  // {
  //   // ROM sizes must be non-zero, power of 2, and greater than 16.
  //   if (!is_valid_rom_size(opts.prg_rom_size_kb, 16))
  //   {
  //     printf("PRG-ROM must be non-zero power of 2, 16kb or greater.\n");
  //     return false;
  //   }
  //   // Not having CHR-ROM is normal for certain types of carts.
  //   // TODO: Update these checks with known info about mappers/carts.
  //   if (!is_valid_rom_size(opts.chr_rom_size_kb, 8) && opts.chr_rom_size_kb != 0)
  //   {
  //     printf("CHR-ROM must be zero or power of 2, 8kb or greater.\n");
  //     return false;
  //   }

  //   // Not having WRAM is very normal.
  //   if (!is_valid_rom_size(opts.wram_size_kb, 8) && opts.wram_size_kb != 0)
  //   {
  //     printf("WRAM must be zero or power of 2, 8kb or greater.\n");
  //     return false;
  //   }
  // }

  // if ((strcmp("gba", opts.console_name) == 0) ||
  //     (strcmp("n64", opts.console_name) == 0))
  // {
  //   if (opts.rom_size_kb <= 0)
  //   {
  //     printf("ROM size must be greater than 0 kilobytes.\n");
  //     return false;
  //   }
  //   if (opts.rom_size_kb % 128)
  //   {
  //     printf("ROM size for this system must translate into megabits with no kilobyte remainder.\n");
  //     return false;
  //   }
  // }

  // clear log
  log.clear();

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
    // t_INLoptions _opts = convert_INLOptions(&opts);
    inlprog_opt(opts);
  }

  return true;
}

/**
 * @brief
 *
 * @param opts
 * @return int
 */
int Flasher::t_inlprog_opt(const t_INLoptions_std &opts)
{
  // TODO...
  // t_INLoptions _opts = convert_INLOptions(&opts);
  int r = inlprog_opt(opts);
  isFlashing = false;
  return r;
  // return 0;
}

// t_INLoptions Flasher::convert_INLOptions(t_INLoptions_std *_opts)
// {
//   // convert options from t_INLoptions_std to t_INLoptions
//   t_INLoptions opts = {0};
//   opts.additional_opts = (char *)_opts->additional_opts.c_str();
//   opts.chr_rom_size_kb = _opts->chr_rom_size_kb;
//   opts.console_name = (char *)_opts->console_name.c_str();
//   opts.debug = _opts->debug;
//   opts.display_help = _opts->display_help;
//   opts.gui = _opts->gui;
//   opts.lua_file = (char *)_opts->lua_file.c_str();
//   opts.mapper_name = (char *)_opts->mapper_name.c_str();
//   opts.prg_rom_size_kb = _opts->prg_rom_size_kb;
//   opts.ram_dump_file = (char *)_opts->ram_dump_file.c_str();
//   opts.ram_write_file = (char *)_opts->ram_write_file.c_str();
//   opts.retroprog_id = (char *)_opts->retroprog_id.c_str();
//   opts.rom_dump_file = (char *)_opts->rom_dump_file.c_str();
//   opts.rom_size_kb = _opts->rom_size_kb;
//   opts.rom_write_file = (char *)_opts->rom_write_file.c_str();
//   opts.verify = _opts->verify;
//   opts.wram_size_kb = _opts->wram_size_kb;
//   return opts;
// }

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
  std::string cur_path;
  std::string resourcesPath;
  std::string luaScript = "";
  std::string luaUsbScript;

#if __APPLE__
  if (getResourcesPath(resourcesPath) == -1)
  {
    APP_LOG(LogTypes_Error, L_INI "Couldn't get resources path");
    goto error;
  }
  luaUsbScript = resourcesPath + "scripts/app/usb_device.lua";
  luaScript = resourcesPath;
#else
  luaUsbScript = "scripts/app/usb_device.lua";
#endif

  // Start up Lua.
  L = lua.init(opts);

#if __APPLE__
  // set the package path for 'require' to work correctly
  lua_getglobal(L, "package");
  lua_getfield(L, -1, "path");    // get field "path" from table at top of stack (-1)
  cur_path = lua_tostring(L, -1); // grab path string from top of stack
  cur_path.append(";");           // do your path magic here
  cur_path.append(resourcesPath);
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
  libusb_log = 0; // getglobint(L, "libusb_log");
  check(&log, ((libusb_log >= LIBUSB_LOG_LEVEL_NONE) && (libusb_log <= LIBUSB_LOG_LEVEL_DEBUG)),
        "Invalid LIBUSB_LOG_LEVEL: %d, must be from 0 to 4", libusb_log);

  transfer = usb_inldevice_open(libusb_log, (char *)opts.retroprog_id.c_str(), &log);
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

/**
 * @brief Returns true if given number is a power of 2, and at least minimum size.
 *
 * @param x
 * @param min
 * @return int
 */
// int Flasher::is_valid_rom_size(int x, int min)
// {
//   return ((x & (x - 1)) == 0) && x >= min;
// }
