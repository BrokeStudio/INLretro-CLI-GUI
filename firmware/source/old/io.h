#ifndef _io_h
#define _io_h

#include <avr/io.h>
#include "pinport.h"
#include "shared_dictionaries.h"
#include "shared_errors.h"

uint8_t io_opcode_only( uint8_t opcode );
uint8_t io_opcode_return( uint8_t opcode, uint8_t *data );

void io_reset();
void nes_init();
void snes_init();
void exp0_pullup_test(uint8_t *data);

#endif
