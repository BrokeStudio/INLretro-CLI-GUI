#ifndef _snes_h
#define _snes_h

#include <avr/io.h>
#include "pinport.h"
#include "shared_dictionaries.h"
#include "shared_errors.h"

//mode of snes /RESET pin
#define PRGM 1
#define PLAY 0

uint8_t snes_opcode_24b_operand( uint8_t opcode, uint8_t addrH, uint8_t addrL, uint8_t data );
uint8_t snes_opcode_24b_operand_8b_return( 
		uint8_t opcode, uint8_t addrX, uint8_t addrH, uint8_t addrL, uint8_t *data );

void	snes_a15_a0_wr( uint8_t mode, uint8_t romsel, uint8_t addrH, uint8_t addrL, uint8_t data );
uint8_t	snes_a15_a0_rd( uint8_t mode, uint8_t romsel, uint8_t addrX, uint8_t addrH, uint8_t addrL );

#endif
