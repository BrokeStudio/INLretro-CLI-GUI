#ifndef _io_h
#define _io_h

#include "pinport.h"
#include "swim.h"
#include "jtag.h"
#include "shared_dictionaries.h"
#include "shared_errors.h"

uint8_t io_call( uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata );

void io_reset();
void nes_init();
void snes_init();
void gameboy_init();
void gba_init();
void sega_init();
void n64_init();
uint8_t swim_init(uint8_t opcode);
uint8_t jtag_init(uint8_t opcode);
uint8_t exp0_pullup_test();

#endif
