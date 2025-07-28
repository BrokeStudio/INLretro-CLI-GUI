#ifndef _buffer_h
#define _buffer_h

#include "pinport.h"
#include "shared_dictionaries.h"
#include "shared_errors.h"
#include "types.h"
#include "operation.h"
#include "usb.h"
#include "dump.h"
#include "flash.h"

#define FALSE  0x00 //TODO remove this junk!

uint8_t	* buffer_usb_call( setup_packet *spacket, uint8_t *rv, uint8_t *rlen);
uint8_t * buffer_payload( setup_packet *spacket, buffer *buff, uint8_t hostsetbuff, uint8_t *rlength );

void raw_buffer_reset( );
uint8_t allocate_buffer( buffer *buff, uint8_t new_id, uint8_t base_bank, uint8_t num_banks );

//void copy_buff0_to_data( uint8_t *data, uint8_t length );
//void copy_data_to_buff0( uint8_t *data, uint8_t length );

uint8_t num_alloc_buffers( void );
buffer * get_next_buff( buffer *buff, uint8_t num );

void update_buffers();


#endif
