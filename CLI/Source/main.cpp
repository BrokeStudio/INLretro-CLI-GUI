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

int main(int argc, char **argv)
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

  t_INLoptions_std *opts = new t_INLoptions_std();

  AppLog::log.cliOutput = true;

  // Setup USB
  // int usb_init = libusb_init_context(/*ctx=*/NULL, /*options=*/NULL, /*num_options=*/0);
  int usb_init = libusb_init(/*ctx=*/NULL);
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
  if (!parseOptions(argc, argv, opts))
  {
    goto error;
  }
  else
  {
    // flash
    opts->gui = false;
    Flasher flasher(std::string(opts->retroprog_id), true);
    flasher.log.cliOutput = true;
    // t_INLoptions _opts = Flasher::convert_INLOptions(opts);
    int res = flasher.inlprog_opt(*opts);
    APP_LOG_SYS(LogTypes_None, "");
    APP_LOG_SYS(LogTypes_Success, "Done !");
  }

  if (usb_init == LIBUSB_SUCCESS)
  {
    libusb_exit(NULL);
  }

#if defined(_DEBUG) || defined(_RELEASE)
  APP_LOG_SYS(LogTypes_None, "");
  APP_LOG_SYS(LogTypes_Info, "Press any key...");
  std::cin.get();
#endif

  return 0;

error:

  if (usb_init == LIBUSB_SUCCESS)
  {
    libusb_exit(NULL);
  }

#if defined(_DEBUG) || defined(_RELEASE)
  APP_LOG_SYS(LogTypes_None, "");
  APP_LOG_SYS(LogTypes_Info, "Press any key...");
  std::cin.get();
#endif

  return 1;
}

/*

88  88  88                                   88
88  ""  88                                   88                ,d                             ,d
88      88                                   88                88                             88
88  88  88,dPPYba,   88       88  ,adPPYba,  88,dPPYba,      MM88MMM  ,adPPYba,  ,adPPYba,  MM88MMM
88  88  88P'    "8a  88       88  I8[    ""  88P'    "8a       88    a8P_____88  I8[    ""    88
88  88  88       d8  88       88   `"Y8ba,   88       d8       88    8PP"""""""   `"Y8ba,     88
88  88  88b,   ,a8"  "8a,   ,a88  aa    ]8I  88b,   ,a8"       88,   "8b,   ,aa  aa    ]8I    88,
88  88  8Y"Ybbd8"'    `"YbbdP'Y8  `"YbbdP"'  8Y"Ybbd8"'        "Y888  `"Ybbd8"'  `"YbbdP"'    "Y888


*/

// #include <iostream>

// #include <stdio.h>
// #include <string.h>

// #ifdef _WIN32
// #include <libusb.h>
// #else
// #include <libusb-1.0/libusb.h>
// #endif

// int verbose = 0;

// static void print_endpoint_comp(const struct libusb_ss_endpoint_companion_descriptor *ep_comp)
// {
//   printf("      USB 3.0 Endpoint Companion:\n");
//   printf("        bMaxBurst:           %u\n", ep_comp->bMaxBurst);
//   printf("        bmAttributes:        %02xh\n", ep_comp->bmAttributes);
//   printf("        wBytesPerInterval:   %u\n", ep_comp->wBytesPerInterval);
// }

// static void print_endpoint(const struct libusb_endpoint_descriptor *endpoint)
// {
//   int i, ret;

//   printf("      Endpoint:\n");
//   printf("        bEndpointAddress:    %02xh\n", endpoint->bEndpointAddress);
//   printf("        bmAttributes:        %02xh\n", endpoint->bmAttributes);
//   printf("        wMaxPacketSize:      %u\n", endpoint->wMaxPacketSize);
//   printf("        bInterval:           %u\n", endpoint->bInterval);
//   printf("        bRefresh:            %u\n", endpoint->bRefresh);
//   printf("        bSynchAddress:       %u\n", endpoint->bSynchAddress);

//   for (i = 0; i < endpoint->extra_length;)
//   {
//     if (LIBUSB_DT_SS_ENDPOINT_COMPANION == endpoint->extra[i + 1])
//     {
//       struct libusb_ss_endpoint_companion_descriptor *ep_comp;

//       ret = libusb_get_ss_endpoint_companion_descriptor(NULL, endpoint, &ep_comp);
//       if (LIBUSB_SUCCESS != ret)
//         continue;

//       print_endpoint_comp(ep_comp);

//       libusb_free_ss_endpoint_companion_descriptor(ep_comp);
//     }

//     i += endpoint->extra[i];
//   }
// }

// static void print_altsetting(const struct libusb_interface_descriptor *interface)
// {
//   uint8_t i;

//   printf("    Interface:\n");
//   printf("      bInterfaceNumber:      %u\n", interface->bInterfaceNumber);
//   printf("      bAlternateSetting:     %u\n", interface->bAlternateSetting);
//   printf("      bNumEndpoints:         %u\n", interface->bNumEndpoints);
//   printf("      bInterfaceClass:       %u\n", interface->bInterfaceClass);
//   printf("      bInterfaceSubClass:    %u\n", interface->bInterfaceSubClass);
//   printf("      bInterfaceProtocol:    %u\n", interface->bInterfaceProtocol);
//   printf("      iInterface:            %u\n", interface->iInterface);

//   for (i = 0; i < interface->bNumEndpoints; i++)
//     print_endpoint(&interface->endpoint[i]);
// }

// static void print_2_0_ext_cap(struct libusb_usb_2_0_extension_descriptor *usb_2_0_ext_cap)
// {
//   printf("    USB 2.0 Extension Capabilities:\n");
//   printf("      bDevCapabilityType:    %u\n", usb_2_0_ext_cap->bDevCapabilityType);
//   printf("      bmAttributes:          %08xh\n", usb_2_0_ext_cap->bmAttributes);
// }

// static void print_ss_usb_cap(struct libusb_ss_usb_device_capability_descriptor *ss_usb_cap)
// {
//   printf("    USB 3.0 Capabilities:\n");
//   printf("      bDevCapabilityType:    %u\n", ss_usb_cap->bDevCapabilityType);
//   printf("      bmAttributes:          %02xh\n", ss_usb_cap->bmAttributes);
//   printf("      wSpeedSupported:       %u\n", ss_usb_cap->wSpeedSupported);
//   printf("      bFunctionalitySupport: %u\n", ss_usb_cap->bFunctionalitySupport);
//   printf("      bU1devExitLat:         %u\n", ss_usb_cap->bU1DevExitLat);
//   printf("      bU2devExitLat:         %u\n", ss_usb_cap->bU2DevExitLat);
// }

// static void print_bos(libusb_device_handle *handle)
// {
//   struct libusb_bos_descriptor *bos;
//   uint8_t i;
//   int ret;

//   ret = libusb_get_bos_descriptor(handle, &bos);
//   if (ret < 0)
//     return;

//   printf("  Binary Object Store (BOS):\n");
//   printf("    wTotalLength:            %u\n", bos->wTotalLength);
//   printf("    bNumDeviceCaps:          %u\n", bos->bNumDeviceCaps);

//   for (i = 0; i < bos->bNumDeviceCaps; i++)
//   {
//     struct libusb_bos_dev_capability_descriptor *dev_cap = bos->dev_capability[i];

//     if (dev_cap->bDevCapabilityType == LIBUSB_BT_USB_2_0_EXTENSION)
//     {
//       struct libusb_usb_2_0_extension_descriptor *usb_2_0_extension;

//       ret = libusb_get_usb_2_0_extension_descriptor(NULL, dev_cap, &usb_2_0_extension);
//       if (ret < 0)
//         return;

//       print_2_0_ext_cap(usb_2_0_extension);
//       libusb_free_usb_2_0_extension_descriptor(usb_2_0_extension);
//     }
//     else if (dev_cap->bDevCapabilityType == LIBUSB_BT_SS_USB_DEVICE_CAPABILITY)
//     {
//       struct libusb_ss_usb_device_capability_descriptor *ss_dev_cap;

//       ret = libusb_get_ss_usb_device_capability_descriptor(NULL, dev_cap, &ss_dev_cap);
//       if (ret < 0)
//         return;

//       print_ss_usb_cap(ss_dev_cap);
//       libusb_free_ss_usb_device_capability_descriptor(ss_dev_cap);
//     }
//   }

//   libusb_free_bos_descriptor(bos);
// }

// static void print_interface(const struct libusb_interface *interface)
// {
//   int i;

//   for (i = 0; i < interface->num_altsetting; i++)
//     print_altsetting(&interface->altsetting[i]);
// }

// static void print_configuration(struct libusb_config_descriptor *config)
// {
//   uint8_t i;

//   printf("  Configuration:\n");
//   printf("    wTotalLength:            %u\n", config->wTotalLength);
//   printf("    bNumInterfaces:          %u\n", config->bNumInterfaces);
//   printf("    bConfigurationValue:     %u\n", config->bConfigurationValue);
//   printf("    iConfiguration:          %u\n", config->iConfiguration);
//   printf("    bmAttributes:            %02xh\n", config->bmAttributes);
//   printf("    MaxPower:                %u\n", config->MaxPower);

//   for (i = 0; i < config->bNumInterfaces; i++)
//     print_interface(&config->interface[i]);
// }

// static void print_device(libusb_device *dev, libusb_device_handle *handle)
// {
//   struct libusb_device_descriptor desc;
//   unsigned char string[256];
//   const char *speed;
//   int ret;
//   uint8_t i;

//   switch (libusb_get_device_speed(dev))
//   {
//   case LIBUSB_SPEED_LOW:
//     speed = "1.5M";
//     break;
//   case LIBUSB_SPEED_FULL:
//     speed = "12M";
//     break;
//   case LIBUSB_SPEED_HIGH:
//     speed = "480M";
//     break;
//   case LIBUSB_SPEED_SUPER:
//     speed = "5G";
//     break;
//   case LIBUSB_SPEED_SUPER_PLUS:
//     speed = "10G";
//     break;
//   // case LIBUSB_SPEED_SUPER_PLUS_X2:
//   //   speed = "20G";
//   //   break;
//   default:
//     speed = "Unknown";
//   }

//   ret = libusb_get_device_descriptor(dev, &desc);
//   if (ret < 0)
//   {
//     fprintf(stderr, "failed to get device descriptor");
//     return;
//   }

//   printf("Dev (bus %u, device %u): %04X - %04X speed: %s\n",
//          libusb_get_bus_number(dev), libusb_get_device_address(dev),
//          desc.idVendor, desc.idProduct, speed);

//   if (!handle)
//     libusb_open(dev, &handle);

//   if (handle)
//   {
//     if (desc.iManufacturer)
//     {
//       ret = libusb_get_string_descriptor_ascii(handle, desc.iManufacturer, string, sizeof(string));
//       if (ret > 0)
//         printf("  Manufacturer:              %s\n", (char *)string);
//     }

//     if (desc.iProduct)
//     {
//       ret = libusb_get_string_descriptor_ascii(handle, desc.iProduct, string, sizeof(string));
//       if (ret > 0)
//         printf("  Product:                   %s\n", (char *)string);
//     }

//     if (desc.iSerialNumber && verbose)
//     {
//       ret = libusb_get_string_descriptor_ascii(handle, desc.iSerialNumber, string, sizeof(string));
//       if (ret > 0)
//         printf("  Serial Number:             %s\n", (char *)string);
//     }
//   }

//   if (verbose)
//   {
//     for (i = 0; i < desc.bNumConfigurations; i++)
//     {
//       struct libusb_config_descriptor *config;

//       ret = libusb_get_config_descriptor(dev, i, &config);
//       if (LIBUSB_SUCCESS != ret)
//       {
//         printf("  Couldn't retrieve descriptors\n");
//         continue;
//       }

//       print_configuration(config);

//       libusb_free_config_descriptor(config);
//     }

//     if (handle && desc.bcdUSB >= 0x0201)
//       print_bos(handle);
//   }

//   if (handle)
//     libusb_close(handle);
// }

// #ifdef __linux__
// #include <errno.h>
// #include <fcntl.h>
// #include <unistd.h>

// static int test_wrapped_device(const char *device_name)
// {
//   libusb_device_handle *handle;
//   int r, fd;

//   fd = open(device_name, O_RDWR);
//   if (fd < 0)
//   {
//     printf("Error could not open %s: %s\n", device_name, strerror(errno));
//     return 1;
//   }
//   r = libusb_wrap_sys_device(NULL, fd, &handle);
//   if (r)
//   {
//     printf("Error wrapping device: %s: %s\n", device_name, libusb_strerror(r));
//     close(fd);
//     return 1;
//   }
//   print_device(libusb_get_device(handle), handle);
//   close(fd);
//   return 0;
// }
// #else
// static int test_wrapped_device(const char *device_name)
// {
//   (void)device_name;
//   printf("Testing wrapped devices is not supported on your platform\n");
//   return 1;
// }
// #endif

// int main(int argc, char *argv[])
// {
//   const char *device_name = NULL;
//   libusb_device **devs;
//   ssize_t cnt;
//   int r, i;

//   for (i = 1; i < argc; i++)
//   {
//     if (!strcmp(argv[i], "-v"))
//     {
//       verbose = 1;
//     }
//     else if (!strcmp(argv[i], "-d") && (i + 1) < argc)
//     {
//       i++;
//       device_name = argv[i];
//     }
//     else
//     {
//       printf("Usage %s [-v] [-d </dev/bus/usb/...>]\n", argv[0]);
//       printf("Note use -d to test libusb_wrap_sys_device()\n");
//       return 1;
//     }
//   }

//   // r = libusb_init_context(//ctx=//NULL, //options=//NULL, //num_options=//0);
//   r = libusb_init_context(NULL, NULL, 0);
//   if (r < 0)
//     return r;

//   if (device_name)
//   {
//     r = test_wrapped_device(device_name);
//   }
//   else
//   {
//     cnt = libusb_get_device_list(NULL, &devs);
//     if (cnt < 0)
//     {
//       libusb_exit(NULL);
//       return 1;
//     }

//     for (i = 0; devs[i]; i++)
//       print_device(devs[i], NULL);

//     libusb_free_device_list(devs, 1);
//   }

//   libusb_exit(NULL);

// #if defined(_DEBUG) || defined(_RELEASE)
//   std::cin.get();
// #endif

//   return r;
// }
