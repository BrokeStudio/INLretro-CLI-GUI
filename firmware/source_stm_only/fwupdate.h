#ifndef _fwupdate_h
#define _fwupdate_h


//include target chip port definition library files
#include <stm32f0xx.h>

#include "../source/shared_dictionaries.h"
#include "../source/shared_errors.h"
#include "../source/types.h"
#include "usbstm.h"

#define FWUPDATE __attribute__ ((section (".fw_update")))	//allow inline functions
#define FWUPDATE_NOIN __attribute__ ((section (".fw_update"), noinline, noclone))	//separate usb funcs from main
#define FWUPMAIN __attribute__ ((section (".fw_up_main"), noinline, noclone))


//bootloader in main application needs to be able to call this
//inorder to exit main application code
FWUPMAIN uint8_t fwupdate_forever();

#endif
