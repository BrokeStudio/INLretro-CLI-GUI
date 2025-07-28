#ifndef _gba_h
#define _gba_h

#include "pinport.h"
#include "shared_dictionaries.h"
#include "shared_errors.h"

uint8_t gba_call( uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata );

uint16_t gba_rd();
void gba_latch_addr( uint16_t addr_lo, uint8_t addr_hi);
uint8_t gba_page_rd( uint16_t *data, uint8_t len);

#endif
