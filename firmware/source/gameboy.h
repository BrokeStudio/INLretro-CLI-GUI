#ifndef _gameboy_h
#define _gameboy_h

#include "pinport.h"
#include "buffer.h"
#include "shared_dictionaries.h"
#include "shared_errors.h"

uint8_t gameboy_call(uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t* rdata);

uint8_t gameboy_rd(uint16_t addr);
void gameboy_wr(uint16_t addr, uint8_t data);
uint8_t gameboy_flash_wr(uint16_t addr, uint8_t data);
void gameboy_pin31_wr(uint16_t addr, uint8_t data);
uint8_t gameboy_flash_pin31_wr(uint16_t addr, uint8_t data);
uint8_t gameboy_unlock_3v_flash_pin31_wr(uint16_t addr, uint8_t data);
uint8_t gameboy_3v_flash_pin31_wr(uint16_t addr, uint8_t data);
void gameboy_page_wr_lfsr(uint16_t addr, uint8_t data);

uint8_t
gameboy_page_rd_poll(uint8_t* data, uint8_t addrH, uint8_t first, uint8_t len, uint8_t poll);

#endif
