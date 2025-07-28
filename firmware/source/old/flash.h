#ifndef _flash_h
#define _flash_h

#include <avr/io.h>
#include "usbdrv.h"
#include "types.h"
#include "logic.h"
#include "usb.h"
#include "nes.h"
#include "shared_dictionaries.h"
#include "shared_errors.h"
#include "shared_enums.h"

uint8_t flash_buff( buffer *buff ) ;

#endif
