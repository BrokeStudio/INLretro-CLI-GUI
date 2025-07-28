#ifndef _operation_h
#define _operation_h

#include <avr/io.h>
#include "usbdrv.h"
#include "types.h"
#include "logic.h"
#include "usb.h"
#include "flash.h"
#include "dump.h"
#include "shared_dictionaries.h"
#include "shared_enums.h"
#include "shared_errors.h"


uint8_t	* operation_usb_call( setup_packet *spacket, uint8_t *rv, uint8_t *rlen);
read_funcptr	decode_rdfunc_num( uint8_t dict, uint8_t func_num ); 
write_funcptr	decode_wrfunc_num( uint8_t dict, uint8_t func_num );
uint8_t oper_opcode_no_return( uint8_t opcode, uint8_t operMSB, uint8_t operLSB, uint8_t miscdata );
uint8_t oper_opcode_return( uint8_t opcode, uint8_t operMSB, uint8_t operLSB, uint8_t miscdata, 
				uint8_t *rvalue, uint8_t *rlength );
void set_operation( uint8_t op );
uint8_t get_operation( void );


#endif
