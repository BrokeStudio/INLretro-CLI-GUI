#ifndef _buffer_h
#define _buffer_h

#include <avr/io.h>
#include "usbdrv.h"
#include "types.h"
#include "logic.h"
#include "usb.h"
#include "flash.h"
#include "dump.h"
#include "operation.h"
#include "shared_dictionaries.h"
#include "shared_enums.h"
#include "shared_errors.h"


//uint8_t	* buffer_usb_call( setup_packet *spacket, uint8_t *rv, uint16_t *rlen);
uint8_t	* buffer_usb_call( setup_packet *spacket, uint8_t *rv, uint8_t *rlen);
uint8_t buffer_opcode_no_return( uint8_t opcode, buffer *buff, 
				uint8_t operMSB, uint8_t operLSB, uint8_t miscdata );

uint8_t buffer_opcode_return( uint8_t opcode, buffer *buff, 
				uint8_t operMSB, uint8_t operLSB, uint8_t miscdata, 
				//uint8_t *rvalue, uint16_t *rlength );
				uint8_t *rvalue, uint8_t *rlength );

uint8_t buffer_opcode_buffnum_no_return( uint8_t opcode, buffer *buff, 
					uint8_t operMSB, uint8_t operLSB, uint8_t miscdata );

void raw_buffer_reset( );
uint8_t allocate_buffer( buffer *buff, uint8_t new_id, uint8_t base_bank, uint8_t num_banks );
void copy_buff0_to_data( uint8_t *data, uint8_t length );
void copy_data_to_buff0( uint8_t *data, uint8_t length );

uint8_t * buffer_payload( setup_packet *spacket, buffer *buff, uint8_t hostsetbuff, uint8_t *rlength );

void update_buffers();


#endif
