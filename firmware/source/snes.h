#ifndef _snes_h
#define _snes_h

#include "pinport.h"
#include "buffer.h"	//TODO remove this junk when get rid of FALSE
#include "shared_dictionaries.h"
#include "shared_errors.h"

uint8_t snes_call( uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata );
uint8_t	snes_rd( uint16_t addr, uint8_t romsel );
void	snes_wr( uint16_t addr, uint8_t data, uint8_t romsel );
void	snes_wr_cur_addr( uint8_t data, uint8_t romsel );
uint8_t snes_page_rd_poll( uint8_t *data, uint8_t addrH, uint8_t romsel, uint8_t first, uint8_t len, uint8_t poll );

void 	snes_5v_flash_wr( uint16_t addr, uint8_t data );
void 	snes_3v_flash_wr( uint16_t addr, uint8_t data );
uint8_t	snes_3v_verify_wr( uint16_t addr, uint8_t data );
void 	snes_3v_buffer_wr( uint16_t addr, uint8_t *data );

#endif
