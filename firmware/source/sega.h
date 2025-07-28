#ifndef _sega_h
#define _sega_h

#include "pinport.h"
#include "shared_dictionaries.h"
#include "shared_errors.h"
#include "stuff.h"

uint8_t sega_call( uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata );

uint16_t gen_rom_rd( uint16_t addr );
void gen_wr_lo( uint16_t addr, uint8_t data );
void gen_wr_hi( uint16_t addr, uint8_t data );
void gen_flash_wr( uint16_t addr, uint16_t data );
void gen_sst_flash_wr( uint16_t addr, uint16_t data );
void gen_set_ram( uint16_t data );
void gen_ram_wr( uint16_t addr, uint8_t data );
uint8_t gen_ram_rd( uint16_t addr );
void gen_set_bank( uint8_t bank );
uint16_t gen_time_wr( uint16_t addr, uint16_t data );

uint8_t genesis_page_rd( uint8_t *data, uint16_t addrH, uint8_t first, uint8_t len );
uint8_t genesis_ram_page_rd( uint8_t *data, uint16_t addrH, uint8_t first, uint8_t len );
void gen_page_ram_wr_lfsr(uint16_t addr, uint8_t data);

#endif
