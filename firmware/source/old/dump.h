#ifndef _dump_h
#define _dump_h

#include <avr/io.h>
#include "usbdrv.h"
#include "types.h"
#include "logic.h"
#include "usb.h"
#include "nes.h"
#include "shared_dictionaries.h"
#include "shared_errors.h"
#include "shared_enums.h"

uint8_t dump_buff( buffer *buff ) ;

#endif
