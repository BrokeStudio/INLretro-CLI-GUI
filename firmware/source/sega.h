#ifndef _sega_h
#define _sega_h

#include "pinport.h"
#include "shared_dictionaries.h"
#include "shared_errors.h"
#include "stuff.h"

uint8_t sega_call(uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata);

void gen_set_addr_lo(uint16_t addr_lo);
void gen_set_addr_hi(uint8_t addr_hi);
void gen_refresh_addr(uint8_t force_set_time);
uint8_t gen_get_addr_hi(void);

uint16_t gen_rom_rd(uint16_t addr_lo);
uint8_t gen_rom_page_rd(uint8_t *data, uint16_t addrH, uint8_t first, uint8_t len);
void gen_rom_wr(uint16_t addr_lo, uint16_t data);
uint16_t gen_sst_flash_wr(uint16_t addr_lo, uint16_t data);

uint8_t gen_time_rd(uint16_t addr_lo);
void gen_time_wr(uint16_t addr_lo, uint8_t data);

uint8_t gen_ram_rd(uint16_t addr_lo);
uint8_t gen_ram_page_rd(uint8_t *data, uint16_t addrH, uint8_t first, uint8_t len);
void gen_ram_wr(uint16_t addr_lo, uint8_t data);
void gen_ram_page_wr_lfsr(uint16_t addr, uint8_t sizeH);

#endif
