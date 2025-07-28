#include "buffer.h"

//used by buffer manager to know what buffer to send to USB/memory
buffer *cur_buff;

//used to communicate to usbFunctionWrite which buffer object
//it should be filling
buffer *cur_usb_load_buff;
//used to determine number of bytes left to finish current
//OUT transfer utilized by usbFunctionWrite
//uint16_t incoming_bytes_remain;
uint8_t incoming_bytes_remain;

//host means of communicating to buffer manager
//uint8_t operation;

//min define of two buffers
buffer buff0;
buffer buff1;
#if ( defined(NUM_BUFFERS_4) || (defined(NUM_BUFFERS_8)) )
buffer buff2;
buffer buff3;
#endif
#ifdef NUM_BUFFERS_8
buffer buff4;
buffer buff5;
buffer buff6;
buffer buff7;
#endif

//max raw buffer size is only limited based on buffer struct
//raw buffer memory to which smaller buffers will be created from
//set pointers and lengths to prevent buffer conflicts
uint8_t raw_buffer[NUM_RAW_BANKS * RAW_BANK_SIZE];	//8 banks of 32bytes each 256Bytes total

//buffer status stores allocation status of each raw buffer 32Byte bank
uint8_t raw_bank_status[NUM_RAW_BANKS]; 



/* Desc:Bridge between usb.c and buffer.c functions
 * 	usb.c calls this function providing setup packet info
 * 	usb.c also provides pointer to small 'rv' return value buffer of 8bytes
 * 	and pointer to rlen so buffer.c can decide wether to utilize the 
 * 	small 8byte generic return buffer or point usbMsgPtr to some larger buffer of sram.
 * 	this function interprets opcode type to call proper opcode switch function
 * Pre: opcode must be defined in shared_dict_buffer.h
 * Post:function call complete.
 * 	rlen updated to lenght of return data
 * 	rv[0] contains SUCCESS/ERROR code
 * 	rv buffer filled with return data for small data requests
 * Rtn: pointer to ram buffer to be returned over USB
 */
//uint8_t	* buffer_usb_call( setup_packet *spacket, uint8_t *rv, uint16_t *rlen)
uint8_t	* buffer_usb_call( setup_packet *spacket, uint8_t *rv, uint8_t *rlen)
{
	buffer *called_buff = &buff0; //used to point to buffer that was called based on opcode init no warn
	uint8_t *rptr = rv; //used for return pointer set to small rv buffer by default

	//some opcodes place buffer number in misc/data
	if ( (spacket->opcode >= BUFFN_INMISC_MIN) && (spacket->opcode <= BUFFN_INMISC_MAX) ) {
//		called_buff = &buff1;
		switch ( spacket->miscdata ) {
			//2 buffers minimum support
			case 0:	called_buff = &buff0;	break;
			case 1:	called_buff = &buff1;	break;
#			if ( defined(NUM_BUFFERS_4) || (defined(NUM_BUFFERS_8)) )
			//4-8 buffers
			case 2:	called_buff = &buff2;	break;
			case 3:	called_buff = &buff3;	break;
#			endif
#			ifdef NUM_BUFFERS_8
			//8 buffers
			case 4:	called_buff = &buff4;	break;
			case 5:	called_buff = &buff5;	break;
			case 6:	called_buff = &buff6;	break;
			case 7:	called_buff = &buff7;	break;
#			endif
			default:	//opcode sent for non-existent buffer 
				rv[RV_ERR_IDX] = ERR_BUFN_DOES_NOT_EXIST;
				//don't decode opcode, just return error to host
				*rlen = 1;
				return rptr;
		}
	}

	switch (spacket->opcode) {

		//now that buffer obtained, decode opcode and make call with called_buff if needed.
		case BUFF_OPCODE_NRV_MIN ... BUFF_OPCODE_NRV_MAX:
			rv[RV_ERR_IDX] = buffer_opcode_no_return( spacket->opcode, called_buff,
			spacket->operandMSB, spacket->operandLSB, spacket->miscdata );	
			*rlen = 1;
		break;

		case BUFF_PAYLOADN_MIN ... BUFF_PAYLOADN_MAX:
		//designate what buffer to fill with miscdata byte
			rptr = buffer_payload( spacket, called_buff, ~FALSE, rlen);
		//TODO
		break;

		case BUFF_OPCODE_RV_MIN ... BUFF_OPCODE_RV_MAX:
			rv[RV_ERR_IDX] = buffer_opcode_return( spacket->opcode, called_buff,
			spacket->operandMSB, spacket->operandLSB, spacket->miscdata, 
								&rv[RV_DATA0_IDX], rlen );	
			// set *rlen in function depending on opcode
		break;

		case BUFF_PAYLOAD_MIN ... BUFF_PAYLOAD_MAX:
		//let buffer.c decide what buffer to fill
			rptr = buffer_payload( spacket, called_buff, FALSE, rlen);
		//TODO
		break;

		//opcodes which include designation of which buffer is being called in lower bits of opcode
		case BUFF_OPCODE_BUFN_MIN ... BUFF_OPCODE_BUFN_MAX:
			//mask out last three bits to detect buffer being called based on opcode number
			switch ( (spacket->opcode) & 0x07) {
				//2 buffers minimum support
				case 0:	called_buff = &buff0;	break;
				case 1:	called_buff = &buff1;	break;
#				if ( defined(NUM_BUFFERS_4) || (defined(NUM_BUFFERS_8)) )
				//4-8 buffers
				case 2:	called_buff = &buff2;	break;
				case 3:	called_buff = &buff3;	break;
#				endif
#				ifdef NUM_BUFFERS_8
				//8 buffers
				case 4:	called_buff = &buff4;	break;
				case 5:	called_buff = &buff5;	break;
				case 6:	called_buff = &buff6;	break;
				case 7:	called_buff = &buff7;	break;
#				endif
				default:	//opcode sent for non-existent buffer 
					rv[RV_ERR_IDX] = ERR_BUFN_DOES_NOT_EXIST;
					//don't decode opcode, just return error to host
					*rlen = 1;
					return rptr;
			}
			//now that we have pointer to buffer object call associated function
			switch ( spacket->opcode ) {
				case BUFF_OPCODE_BUFN_NRV_MIN ... BUFF_OPCODE_BUFN_NRV_MAX:
					rv[RV_ERR_IDX] = buffer_opcode_buffnum_no_return( 
					spacket->opcode, called_buff,
					spacket->operandMSB, spacket->operandLSB, spacket->miscdata );	
				break;
				case BUFF_OPCODE_BUFN_RV_MIN ... BUFF_OPCODE_BUFN_RV_MAX:
					//returnlength  = somereturn value( spacket->opcode, &called_buff,
					//spacket->operandMSB, spacket->operandLSB, spacket->miscdata );	
					//return pointer to buffer's data
					rptr = called_buff->data;
					*rlen = (spacket->wLength);
				break;
				case BUFF_PAYLOAD0 ... BUFF_PAYLOAD7:
					rptr = buffer_payload( spacket, called_buff, ~FALSE, rlen);
				break;
				default: 
					rv[RV_ERR_IDX] = ERR_BAD_BUFF_OP_MINMAX;
			}
		break;

		default:	//nes opcode min/max definition error 
			rv[RV_ERR_IDX] = ERR_BAD_BUFF_OP_MINMAX;
	}

	return rptr;
}



/* Desc:Function takes an opcode which was transmitted via USB
 * 	then decodes it to call designated function.
 * 	shared_dict_buffer.h is used in both host and fw to ensure opcodes/names align
 * Pre: Macros must be defined in firmware pinport.h
 * 	opcode must be defined in shared_dict_buffer.h
 * Post:function call complete.
 * Rtn: SUCCESS if opcode found, ERR_UNKN_BUFF_OPCODE_NRV if opcode not present.
 */
uint8_t buffer_opcode_no_return( uint8_t opcode, buffer *buff, 
				uint8_t operMSB, uint8_t operLSB, uint8_t miscdata )
{

	switch (opcode) { 
		case RAW_BUFFER_RESET:	
			raw_buffer_reset();	
			break;
		//case SET_BUFFER_OPERATION:	
		//	operation = operLSB;
		//	break;
		case SET_MEM_N_PART:	
			buff->mem_type = operMSB;
			buff->part_num = operLSB;
			break;
		case SET_MULT_N_ADDMULT:	
			buff->multiple = operMSB;
			buff->add_mult = operLSB;
			break;
		case SET_MAP_N_MAPVAR:	
			buff->mapper = operMSB;
			buff->mapvar = operLSB;
			break;
		case SET_FUNCTION:	
			buff->function = operLSB;
			break;
		default:
			 //opcode doesn't exist
			 return ERR_UNKN_BUFF_OPCODE_NRV;
	}
	
	return SUCCESS;

}

/* Desc:Function takes an opcode which was transmitted via USB
 * 	then decodes it to call designated function.
 * 	shared_dict_buffer.h is used in both host and fw to ensure opcodes/names align
 * Pre: Macros must be defined in firmware pinport.h
 * 	opcode must be defined in shared_dict_buffer.h
 * Post:function call complete.
 * Rtn: SUCCESS if opcode found, ERR_UNKN_BUFF_OPCODE_RV if opcode not present.
 */
uint8_t buffer_opcode_return( uint8_t opcode, buffer *buff, 
				uint8_t operMSB, uint8_t operLSB, uint8_t miscdata, 
				//uint8_t *rvalue, uint16_t *rlength )
				uint8_t *rvalue, uint8_t *rlength )
{
	switch (opcode) { 
		case RAW_BANK_STATUS:	
				*rvalue = raw_bank_status[operLSB];	
				*rlength += 1;
			break;
		case GET_CUR_BUFF_STATUS:	
				*rvalue = cur_buff->status;	
				*rlength += 1;
			break;
		case GET_PRI_ELEMENTS:	
				rvalue[0] = buff->last_idx;
				rvalue[1] = buff->status;
				rvalue[2] = buff->cur_byte;
				rvalue[3] = buff->reload;
				rvalue[4] = buff->id;
				rvalue[5] = buff->page_num;	//pretty sure this assigns next line too
				rvalue[6] = (buff->page_num>>8);//little endian
				*rlength += 7;
			break;
		case GET_SEC_ELEMENTS:	
				rvalue[0] = buff->mem_type;
				rvalue[1] = buff->part_num;
				rvalue[2] = buff->multiple;
				rvalue[3] = buff->add_mult;
				rvalue[4] = buff->mapper;
				rvalue[5] = buff->mapvar;
				rvalue[6] = buff->function;
				*rlength += 7;
			break;
		default:
			 //opcode doesn't exist
			 return ERR_UNKN_BUFF_OPCODE_RV;
	}
	
	return SUCCESS;

}

/* Desc:Function takes an opcode which was transmitted via USB
 * 	then decodes it to call designated function.
 * 	shared_dict_buffer.h is used in both host and fw to ensure opcodes/names align
 * 	This function is for opcodes which use their opcode lower bits to
 * 	denote which buffer to be operated on.
 * Pre: Macros must be defined in firmware pinport.h
 * 	opcode must be defined in shared_dict_buffer.h
 * Post:function call complete.
 * Rtn: SUCCESS if opcode found, ERR_UNKN_BUFF_OPCODE_BUFN_NRV if opcode not present.
 */
uint8_t buffer_opcode_buffnum_no_return( uint8_t opcode, buffer *buff, 
					uint8_t operMSB, uint8_t operLSB, uint8_t miscdata )
{
	switch (opcode) { 
		case ALLOCATE_BUFFER0 ... ALLOCATE_BUFFER7:	
			return allocate_buffer( buff, operMSB, operLSB, miscdata );
			//uint8_t allocate_buffer( *buff, new_id, base_bank, num_banks )
			break;
		case SET_RELOAD_PAGENUM0 ... SET_RELOAD_PAGENUM7:	
			buff->reload = miscdata; 
			buff->page_num = (operMSB<<8);
			buff->page_num |= operLSB;
			break;
		default:
			 //opcode doesn't exist
			 return ERR_UNKN_BUFF_OPCODE_BUFN_NRV;
	}
	
	return SUCCESS;

}

/* Desc:
 * Pre: 
 * Post:
 * Rtn: 
 */
uint8_t * buffer_payload( setup_packet *spacket, buffer *buff, uint8_t hostsetbuff, uint8_t *rlength )
{

	uint8_t *rtnpointer = buff0.data;	//default to remove warnings..
	uint8_t endpoint = (spacket->bmRequestType & ENDPOINT_BIT);

	//return length and incoming_bytes_remain only depends on endpoint direction
	if ( endpoint == ENDPOINT_IN) {
		//read/dump from device to host
		*rlength = (spacket->wLength); 
	} else { //write to device from host
		//return USB_NO_MSG to get usbFunctionWrite
		//called on incoming packets
		*rlength = USB_NO_MSG;
		incoming_bytes_remain = (spacket->wLength); 
	}

	//buffer in use depends on opcode which was decoded prior to calling into hostsetbuff
	//if buffer number not designated by host buffer.c gets to decide
	if ( hostsetbuff == FALSE ) {
		//buffer.c gets to decide buffer in use
		//buffer manager sets cur_buff
		if ( endpoint == ENDPOINT_IN) {
			//reads
			if ( cur_buff->status == DUMPED ) {
				rtnpointer = cur_buff->data;
				cur_buff->status = USB_UNLOADING;
			} else {
				//problem, buffers not prepared or initialized 
				*rlength = USB_NO_MSG;
				set_operation( PROBLEM );
			}
		} else {//writes
			if ( cur_buff->status == EMPTY ) {
				//send cur_buff to usbFunctionWrite to be filled
				cur_usb_load_buff = cur_buff;
				cur_buff->status = USB_LOADING;
			} else {
				//both buffers are in use
				//last buffer is flashing, and cur is full, need to wait on last to finish
				set_operation( PROBLEM );
			}
		}
		cur_buff->cur_byte = 0;

	} else { //host determined the buffer to use
		if ( endpoint == ENDPOINT_IN) {
			//reads
			rtnpointer = buff->data;
			buff->status = USB_UNLOADING;
		} else {//writes
			cur_usb_load_buff = buff;
			buff->status = USB_LOADING;
		}
		buff->cur_byte = 0;
	}

	//now only thing left to do is stuff 2 bytes from setup packet into the buffer if designated by the opcode
	if ( (cur_buff->status == USB_LOADING) &&
	     ((spacket->opcode == BUFF_OUT_PAYLOAD_2B_INSP)||(spacket->opcode == BUFF_OUT_PAYLOADN_2B_INSP)) ) {
	//operandMSB:LSB actually contains first 2 bytes
	//these two bytes don't count as part of transfer OUT byte count
	//but they do count as part of buffer's byte count.
		cur_usb_load_buff->data[0] = spacket->operandMSB;
		cur_usb_load_buff->data[1] = spacket->operandLSB;
		cur_usb_load_buff->cur_byte += 2;
	}

	return rtnpointer;

}

/* Desc:Blindly resets all buffer allocation and values
 * 	Host instructs this to be called.
 * Pre: static instantitions of raw_buffer, raw_bank_status, and buff0-7
 * Post:all raw buffer ram unallocated
 * 	buffer status updated to UNALLOC
 *	operation set to RESET
 * Rtn:	None
 */
void raw_buffer_reset( )
{
	uint8_t i;

	//unallocate raw buffer space
	for( i=0; i<NUM_RAW_BANKS; i++) {
		raw_bank_status[i] = UNALLOC;
	}

	//unallocate all buffer objects
	//set buffer id to UNALLOC
//min 2 buffers
	buff0.status = UNALLOC;
	buff1.status = UNALLOC;
	buff0.id = UNALLOC;
	buff1.id = UNALLOC;
// 4-8 buffers
#if ( defined(NUM_BUFFERS_4) || (defined(NUM_BUFFERS_8)) )
	buff2.status = UNALLOC;
	buff3.status = UNALLOC;
	buff2.id = UNALLOC;
	buff3.id = UNALLOC;
#endif	//8 buffers
#ifdef NUM_BUFFERS_8
	buff4.status = UNALLOC;
	buff5.status = UNALLOC;
	buff6.status = UNALLOC;
	buff7.status = UNALLOC;
	buff4.id = UNALLOC;
	buff5.id = UNALLOC;
	buff6.id = UNALLOC;
	buff7.id = UNALLOC;
#endif

	//operation = RESET;
	set_operation( RESET );

}

/* Desc:Embeded subtitute for malloc of a buffer object
 * 	Host instructs this to be called so the host
 * 	is in charge of what buffers are for what
 * 	and how things are used.  This function does
 * 	keep track of each bank of the raw buffer.
 * 	It will not allocate buffer space and return error
 * 	if host is trying to allocate buffer on top of 
 * 	another buffer or bank already allocated.
 * 	pass in pointer to buffer object to be allocated
 * 	pass base bank number and number of banks in buffer
 * 	This function works with various sizes of raw buffer
 * 	as it works based on NUM_RAW_BANKS and RAW_BANK_SIZE
 * Pre: static instantitions of raw_buffer raw_bank_status,
 * 	and buff0-7 above.
 * 	Buffer must be unallocated.
 * 	new id cannot be 0xFF/255 "UNALLOC"
 * 	bank allocation request can't go beyond raw ram space
 * Post:section of raw buffer allocated for host use
 * 	status of raw buffer updated to prevent future collisions
 * 	bank status byte contains buffer's id
 * 	buffer status updated from UNALLOC to EMPTY
 *	buffer size set according to allocation
 * 	all other buffer values cleared to zero
 * Rtn:	SUCCESS or ERROR code if unable to allocate
 */
uint8_t allocate_buffer( buffer *buff, uint8_t new_id, uint8_t base_bank, uint8_t num_banks )
{
	uint8_t i;

	//check incoming args
	if ( (base_bank+num_banks) > NUM_RAW_BANKS ) {
		//trying to allocate SRAM past end of raw_buffer
		return ERR_BUFF_ALLOC_RANGE;
	}
	if ( (num_banks) == 0  ) {
		//trying to allocate buffer with zero banks
		return ERR_BUFF_ALLOC_SIZE_ZERO;
	}

	//check that buffer isn't already allocated
	if ( buff->status != UNALLOC) {
		return ERR_BUFF_STATUS_ALREADY_ALLOC;
	}
	if ( buff->id != UNALLOC) {
		return ERR_BUFF_ID_ALREADY_ALLOC;
	}

	//check that raw banks aren't allocated
	for ( i=0; i<num_banks; i++) {
		if ( raw_bank_status[base_bank+i] != UNALLOC ) {
			return ERR_BUFF_RAW_ALREADY_ALLOC;
		}
	}

	//seems that buffer and raw are free allocate them as requested
	buff->id = new_id;
	buff->status = EMPTY;
	//buff->size = num_banks * RAW_BANK_SIZE;	//16bit value (256 = 9bits)
	buff->last_idx = (num_banks * RAW_BANK_SIZE) - 1;	//give the last index of the array

	//zero out other elements
	buff->cur_byte = 0;
	buff->reload = 0;
	buff->page_num = 0;
	buff->mem_type = 0;
	buff->part_num = 0;
	buff->multiple = 0;
	buff->add_mult = 0;
	buff->mapper = 0;
	buff->mapvar = 0;
	buff->function = 0;

	//set buffer data pointer to base ram address
	buff->data = &raw_buffer[base_bank*RAW_BANK_SIZE];

	//set bank status to bank's id
	for ( i=0; i<num_banks; i++) {
		raw_bank_status[base_bank+i] = new_id;
	}

	return SUCCESS;	

}


//used to copy contents of buffer to another sram location
void copy_buff0_to_data( uint8_t *data, uint8_t length )
{
	uint8_t i;

	for ( i=0; i<length; i++ ) {
		data[i] = buff0.data[i];
	}
	
}

//used to copy data to buff0 from another location
void copy_data_to_buff0( uint8_t *data, uint8_t length )
{
	uint8_t i;

	for ( i=0; i<length; i++ ) {
		buff0.data[i] = data[i];
	}
	
}

//used to determine how many buffers are in use at start of new operation
//assume buffers are instantiated in order starting with zero.
uint8_t num_alloc_buffers( void )
{
	uint8_t rv = 0;
	if ( buff0.status != UNALLOC ) rv = 1;
	if ( buff1.status != UNALLOC ) rv = 2;
#if ( defined(NUM_BUFFERS_4) || (defined(NUM_BUFFERS_8)) )
	if ( buff2.status != UNALLOC ) rv = 3;
	if ( buff3.status != UNALLOC ) rv = 4;
#endif
#ifdef NUM_BUFFERS_8
	if ( buff4.status != UNALLOC ) rv = 5;
	if ( buff5.status != UNALLOC ) rv = 6;
	if ( buff6.status != UNALLOC ) rv = 7;
	if ( buff7.status != UNALLOC ) rv = 8;
#endif

	return rv;
}

//get next buffer provide a buffer pointer and number of buffers in use
//return pointer to next buffer in sequence
buffer * get_next_buff( buffer *buff, uint8_t num )
{

	//if there's 2 buffers need to toggle between 0 & 1
	if ( num == 2 ) {
		if ( buff == &buff0 ) return &buff1;
		if ( buff == &buff1 ) return &buff0;
	}
#if ( defined(NUM_BUFFERS_4) || (defined(NUM_BUFFERS_8)) )
	//if there's 3-4 buffers cycle through
	if ( num == 3 ) {
		if ( buff == &buff0 ) return &buff1;
		if ( buff == &buff1 ) return &buff2;
		if ( buff == &buff2 ) return &buff0;
	}
	if ( num == 4 ) {
		if ( buff == &buff0 ) return &buff1;
		if ( buff == &buff1 ) return &buff2;
		if ( buff == &buff2 ) return &buff3;
		if ( buff == &buff3 ) return &buff0;
	}
#endif
#ifdef NUM_BUFFERS_8
	if ( num == 5 ) {
		if ( buff == &buff0 ) return &buff1;
		if ( buff == &buff1 ) return &buff2;
		if ( buff == &buff2 ) return &buff3;
		if ( buff == &buff3 ) return &buff4;
		if ( buff == &buff4 ) return &buff0;
	}
	if ( num == 6 ) {
		if ( buff == &buff0 ) return &buff1;
		if ( buff == &buff1 ) return &buff2;
		if ( buff == &buff2 ) return &buff3;
		if ( buff == &buff3 ) return &buff4;
		if ( buff == &buff4 ) return &buff5;
		if ( buff == &buff5 ) return &buff0;
	}
	if ( num == 7 ) {
		if ( buff == &buff0 ) return &buff1;
		if ( buff == &buff1 ) return &buff2;
		if ( buff == &buff2 ) return &buff3;
		if ( buff == &buff3 ) return &buff4;
		if ( buff == &buff4 ) return &buff5;
		if ( buff == &buff5 ) return &buff6;
		if ( buff == &buff6 ) return &buff0;
	}
	if ( num == 8 ) {
		if ( buff == &buff0 ) return &buff1;
		if ( buff == &buff1 ) return &buff2;
		if ( buff == &buff2 ) return &buff3;
		if ( buff == &buff3 ) return &buff4;
		if ( buff == &buff4 ) return &buff5;
		if ( buff == &buff5 ) return &buff6;
		if ( buff == &buff6 ) return &buff7;
		if ( buff == &buff7 ) return &buff0;
	}
#endif

	//if there's only one buffer, or if some other error, just return sent buffer ptr 
	//if ( num == 1 ) return buff;
	return buff;

}

//check buffer status' and instruct them to 
//flash/dump as needed to keep data moving
void update_buffers() 
{
	uint8_t result = 0;
	static uint8_t num_buff;
	buffer *last_buff;

	//when dumping we don't actually know when the buffer has been fully
	//read back through USB IN transfer.  But we know when the next buffer
	//is requested to read back, so we'll dump the second page into the second buffer
	//after the first page has been requested for IN transfer
	//need to get data dumped before in transfer..


	//operations start by host resetting and initializing buffers
	//this buffer manager is blind to the size of buffers and other such details
	//this manager only needs to know which buffers are active
	//but the host sets operation when it wants this manager to send 
	//little buffers out to start dumping/flashing
	if ( (get_operation() == STARTDUMP) || (get_operation() == STARTFLASH ) ) {
		//only want to do this once per operation at the start
		//figure out how many buffers are in operation
		//assume buff0 is first and follows 1, 2, etc
		num_buff = num_alloc_buffers();

		//now that we know how many buffers there are in use
		//we always start with buff0
		cur_buff = &buff0;
		//now we can get_next_buff by passing cur_buff

	}
	if (get_operation() == STARTDUMP) {
		//prepare both buffers to dump
			
		//do all the same things that would happen between buffers to start things moving
		//pretend the last buffer is unloading via USB right now
		//so that operation == DUMPING code gets run for the first time but appears like
		//it's not the first time.
		//to do this, set cur_buff to last buff and set it's status to USB_UNLOADING
		for ( result=1; result<num_buff; result++ ) {
			cur_buff = get_next_buff( cur_buff, num_buff );
		}
		cur_buff->status = USB_UNLOADING;
		//that will now trigger operation == DUMPING to dump first buffer

		//don't want to reenter start initialiation again
		//operation = DUMPING;
		set_operation( DUMPING );
	}
	if (get_operation() == STARTFLASH) {
		//don't want to reenter start initialiation again
		//operation = FLASHING;
		set_operation( FLASHING );

		//not much else to do, just waiting on payload OUT transfer
		//current buffer prepared to be sent to usbFunctionWrite
		cur_buff->status = EMPTY;

		//TODO
		//perhaps this is where the mapper registers should be initialized as needed
		//for all buffer writes.
		//but this will bloat firmware code with each mapper..
		//so prob best for host to handle this with series of single byte write opcodes

	}
	
	//this will get entered on first and all successive calls
	if ( get_operation() == DUMPING ) {
		//buffer_payload will pass cur_buff to usb driver on next IN transfer
		//on receipt of the IN transfer buffer_payload sets: 
		// cur_buff->status = USB_UNLOADING;
		// So that's what we're waiting on before sending next buffer to dump
		if ( cur_buff->status == USB_UNLOADING ) {
			//move on to next buffer now that last one is at USB
			//WARNING!!! this current design won't work well if there's only one buffer
			//Because the buffer getting read via USB will get stopped on by next dump
			//So things won't really work with only one buffer
			cur_buff = get_next_buff( cur_buff, num_buff );
			cur_buff->cur_byte = 0;
			cur_buff->status = DUMPING;
			//send buffer off to dump 
			result = dump_buff( cur_buff );
			if (result != SUCCESS) {
				cur_buff->status = result;
			} else {
				cur_buff->status = DUMPED;
				//increment page_num so everything is ready for next dump
				//TODO make buffer_update function to handle everything
				cur_buff->page_num += cur_buff->reload;
			}
		}
		
	}

	if ( get_operation() == FLASHING ) {
		//cur_buff will get sent to usbFunctionWrite on next payload OUT transfer
		//All we need to do here is monitor usbFWr's status via incoming_bytes_remain
		//which gets set to 254 on wr transfers once gets to zero buffer is filled
		//if ( (incoming_bytes_remain == 0) && (cur_buff->status != EMPTY) ) {
		//	incoming_bytes_remain--;	//don't want to re-enter
		if ( cur_buff->status == USB_FULL) {

			//buffer full, send to flash routine
			last_buff = cur_buff;
			//but first want to update cur_buff to next buffer so it can 
			//start loading on next OUT transfer
			cur_buff = get_next_buff( cur_buff, num_buff );

			//the other buffer must be complete if we've gotten to this point
			//because this function only gets called from main
			//so we can now change it from FLASHED to EMPTY
			cur_buff->status = EMPTY;
			
			last_buff->status = FLASHING;
			//last_buff->cur_byte = 0;
			result = flash_buff( last_buff );
			if (result != SUCCESS) {
				last_buff->status = result;
			} else {
				last_buff->status = FLASHED;
				last_buff->page_num += last_buff->reload;
			}
			//page should be flashed to memory now
			//the next buffer should be in process of getting filled
			//once full we'll end up back here again
		}
	}

	//to start let's sense dumping operation by buffer status
	//host updates status of buffer, then we go off and dump as appropriate
	//might be best to add some opcode to kick things off.
//	if ( buff->function == DUMPING ) {

//		buff->cur_byte = 0;
//		//to start lets just dump the first page of PRG-ROM
//		result = dump_page( buff );
//
//		if (result == SUCCESS) {
//			buff->status = DUMPED;
//		}
//	
//		//now it can be read back in next IN transfer
//	}

	//for now lets use one buffer to flash a cartridge
	//later try a second one to double buffer, might not actually matter much..
//	buffer *buff = &buff0;
	
	//check if buffer is full and update status accordingly
//	if (cur_usb_load_buff->last_idx == cur_usb_load_buff->cur_byte) {
//		cur_usb_load_buff->status = USB_FULL;
//
//	//update other buffer so it can be filled by incoming USB data now
//	//if buffer size is smaller than data transfer lengths this must be done quickly
//	//enough for usbFunction write to not notice
//	} else {
//		//if there are no full buffers yet simply exit
//		//return;
//	}
	
	//found a buffer that's full and ready to flash onto cart
	
	//set it's page number to the proper value
	//perhaps this should be done after it's flashed as we want to start at zero.
	
	//update any other necessary elements
	
	//send it off to it's flashing routine
//	if ( buff->function == FLASHING ) {
//
//
//		buff->cur_byte = 0;
//		//to start lets just dump the first page of PRG-ROM
//		result = flash_page( buff );
//
//		if (result == SUCCESS) {
//			buff->status = FLASHED;
//		} else {
//			buff->status = PROBLEM;
//		}
//	
//		//now it can be read back in next IN transfer
//	}
	
	//now that it's flashed perform verifications if needed
	
	//adjust multiple/page num to program to another location if
	//buffer is supposed to be flashed to multiple locations
	
	//send it off to flash again as many times as needed

	//complete any remaining checks desired

	//set it's page number to the proper value
	//perhaps this should be done after it's flashed as we want to start at zero.
	
	//update it's status so buffer is ready for reuse.

	return;


}


