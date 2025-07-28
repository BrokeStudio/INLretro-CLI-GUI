#ifndef _ciccom_h
#define _ciccom_h

#include "pinport.h"
#include "shared_dictionaries.h"
#include "shared_errors.h"


uint8_t ciccom_call( uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata );


#endif
