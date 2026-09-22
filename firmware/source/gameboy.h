#ifndef _gameboy_h
#define _gameboy_h

#include "pinport.h"
#include "buffer.h"
#include "shared_dictionaries.h"
#include "shared_errors.h"

uint8_t gb_call(uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t* rdata);

uint8_t gb_rd(uint16_t addr);
void gb_wr(uint16_t addr, uint8_t data);
void gb_wr_pin31(uint16_t addr, uint8_t data);
uint8_t gb_flash_wr_long(uint16_t addr, uint8_t data);
uint8_t gb_flash_wr_pin31_long(uint16_t addr, uint8_t data);
uint8_t gb_flash_wr_pin31_unlock(uint16_t addr, uint8_t data);
uint8_t gb_flash_wr_pin31_short(uint16_t addr, uint8_t data);
void gb_page_wr_lfsr(uint16_t addr);

uint8_t gb_page_rd(uint8_t* data, uint8_t addrH, uint8_t first, uint8_t len);

#endif
