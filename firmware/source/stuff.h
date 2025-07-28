#ifndef _stuff_h
#define _stuff_h

#include "pinport.h"
#include "shared_dictionaries.h"
#include "shared_errors.h"

uint8_t stuff_call( uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata );
void set_lfsr(uint32_t seed);
uint8_t lfsr_32();

#endif
