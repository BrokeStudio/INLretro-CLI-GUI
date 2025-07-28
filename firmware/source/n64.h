#ifndef _n64_h
#define _n64_h

#include "pinport.h"
#include "shared_dictionaries.h"
#include "shared_errors.h"

uint8_t n64_call( uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata );

uint16_t	n64_rd();
void	n64_wr( uint16_t addr, uint8_t data );

void n64_latch_addr( uint16_t addr_lo );
uint8_t n64_page_rd( uint8_t *data, uint8_t addrH, uint8_t first, uint8_t len );

#endif
