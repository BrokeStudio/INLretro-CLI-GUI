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
//uint8_t raw_buffer[NUM_RAW_BANKS * RAW_BANK_SIZE];	//8 banks of 32bytes each 256Bytes total
//create raw array of 16bit uints to ensure compatabity with stm32 USB driver
uint16_t raw_buffer16[NUM_RAW_BANKS * RAW_BANK_SIZE / 2];
//create 8bit pointer to access above array ensuring half word alignment
uint8_t *raw_buffer = (uint8_t*) raw_buffer16;

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
				rv[RETURN_ERR_IDX] = ERR_BUFN_DOES_NOT_EXIST;
				//don't decode opcode, just return error to host
				//*rlen = 1;
				return rptr;
		}
	}

	//now that buffer obtained, decode opcode and make call with called_buff if needed.
	switch (spacket->opcode) {

		//no return value aside from SUCCESS/ERROR
		case RAW_BUFFER_RESET:	
			raw_buffer_reset();	
			rv[RETURN_ERR_IDX] = SUCCESS;
			break;
		case SET_MEM_N_PART:	
			called_buff->mem_type = (spacket->operand)>>8;	//operMSB;
			called_buff->part_num = spacket->operand;	//operLSB;
			rv[RETURN_ERR_IDX] = SUCCESS;
			break;
		case SET_MULT_N_ADDMULT:	
			called_buff->multiple = (spacket->operand)>>8;	//operMSB;
			called_buff->add_mult = spacket->operand;	//operLSB;
			rv[RETURN_ERR_IDX] = SUCCESS;
			break;
		case SET_MAP_N_MAPVAR:	
			called_buff->mapper = (spacket->operand)>>8;	//operMSB;
			called_buff->mapvar = spacket->operand;		//operLSB;
			rv[RETURN_ERR_IDX] = SUCCESS;
			break;
		case SET_FUNCTION:	
			called_buff->function = spacket->operand;	//operLSB;
			rv[RETURN_ERR_IDX] = SUCCESS;
			break;

		//opcode calls for return data besides SUCCESS/ERROR
		case GET_RAW_BANK_STATUS:	//operand contains bank number to obtain status of	
				rv[RETURN_ERR_IDX] = SUCCESS;
				rv[RETURN_LEN_IDX] = 1;
				rv[RETURN_DATA] = raw_bank_status[spacket->operand];	
			break;
		case GET_CUR_BUFF_STATUS:	
				rv[RETURN_ERR_IDX] = SUCCESS;
				rv[RETURN_LEN_IDX] = 1;
				rv[RETURN_DATA] = cur_buff->status;	
			break;
		case GET_PRI_ELEMENTS:	
				rv[RETURN_ERR_IDX] = SUCCESS;
				rv[RETURN_LEN_IDX] = 6;
				rv[RETURN_DATA+0] = called_buff->last_idx;
				rv[RETURN_DATA+1] = called_buff->status;
				rv[RETURN_DATA+2] = called_buff->cur_byte;
				rv[RETURN_DATA+3] = called_buff->reload;
				rv[RETURN_DATA+4] = called_buff->id;
				rv[RETURN_DATA+5] = called_buff->function;
			break;
		case GET_SEC_ELEMENTS:	
				rv[RETURN_ERR_IDX] = SUCCESS;
				rv[RETURN_LEN_IDX] = 6;
				rv[RETURN_DATA+0] = called_buff->mem_type;
				rv[RETURN_DATA+1] = called_buff->part_num;
				rv[RETURN_DATA+2] = called_buff->multiple;
				rv[RETURN_DATA+3] = called_buff->add_mult;
				rv[RETURN_DATA+4] = called_buff->mapper;
				rv[RETURN_DATA+5] = called_buff->mapvar;
			break;
		case GET_PAGE_NUM:	
				rv[RETURN_ERR_IDX] = SUCCESS;
				rv[RETURN_LEN_IDX] = 2;
				rv[RETURN_DATA+0] = called_buff->page_num;	//pretty sure this assigns next line too
				rv[RETURN_DATA+1] = (called_buff->page_num>>8);//little endian
			break;

//		case BUFF_PAYLOADN_MIN ... BUFF_PAYLOADN_MAX:
//		//designate what buffer to fill with miscdata byte
//			rptr = buffer_payload( spacket, called_buff, ~FALSE, rlen);
//		break;
//
		case BUFF_PAYLOAD_MIN ... BUFF_PAYLOAD_MAX:
		//let buffer.c decide what buffer to fill
			rptr = buffer_payload( spacket, called_buff, FALSE, rlen);
		//TODO
		break;

		//opcodes which include designation of which buffer is being called in lower bits of opcode
		//TODO get rid of these opcodes, and just always put buffer number in miscdata!!
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
					rv[RETURN_ERR_IDX] = ERR_BUFN_DOES_NOT_EXIST;
					//don't decode opcode, just return error to host
					return rptr;
			}
			//now that we have pointer to buffer object call associated function
			switch ( spacket->opcode ) {
				case ALLOCATE_BUFFER0 ... ALLOCATE_BUFFER7:	
					rv[RETURN_ERR_IDX] = allocate_buffer( called_buff, 
							//MSB bank ID		 LSB base bank	   size (num banks)
							((spacket->operand)>>8), spacket->operand, spacket->miscdata );
					break;
				case SET_RELOAD_PAGENUM0 ... SET_RELOAD_PAGENUM7:	
					rv[RETURN_ERR_IDX] = SUCCESS;
					called_buff->reload = spacket->miscdata; 
					called_buff->page_num = spacket->operand;
					break;
//				case BUFF_OPCODE_BUFN_RV_MIN ... BUFF_OPCODE_BUFN_RV_MAX:
//					//returnlength  = somereturn value( spacket->opcode, &called_buff,
//					//spacket->operandMSB, spacket->operandLSB, spacket->miscdata );	
//					//return pointer to buffer's data
//					rptr = called_buff->data;
//					*rlen = (spacket->wLength);
//				break;
//				case BUFF_PAYLOAD0 ... BUFF_PAYLOAD7:
//					rptr = buffer_payload( spacket, called_buff, ~FALSE, rlen);
//				break;
			}
			break;

		default:	//buffer opcode definition error 
			rv[RETURN_ERR_IDX] = ERR_UNKN_BUFF_OPCODE;
			return rptr;
	}

	return rptr;
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
			} else if ( cur_buff->status == DUMPING) {
				*rlength = 0;
//if current buffer is in dumping process, send STALL so host tries again
//to ignore the host need to return 0 in V-usb functionSetup
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
			} else if ( cur_buff->status == USB_FULL ) {
				*rlength = 0;
//if cur buffer is USB_FULL because buffer manager hasn't acted on it yet
//and last buffer is still FLASHING, need to send STALL so host tries again
//to ignore the host need to return 0 in V-usb functionSetup
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
	//operandLSB:MSB actually contains first 2 bytes
	//these two bytes don't count as part of transfer OUT byte count
	//but they do count as part of buffer's byte count.
		cur_usb_load_buff->data[0] = spacket->operand;
		cur_usb_load_buff->data[1] = (spacket->operand)>>8;
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


////used to copy contents of buffer to another sram location
//void copy_buff0_to_data( uint8_t *data, uint8_t length )
//{
//	uint8_t i;
//
//	for ( i=0; i<length; i++ ) {
//		data[i] = buff0.data[i];
//	}
//	
//}
//
////used to copy data to buff0 from another location
//void copy_data_to_buff0( uint8_t *data, uint8_t length )
//{
//	uint8_t i;
//
//	for ( i=0; i<length; i++ ) {
//		buff0.data[i] = data[i];
//	}
//	
//}

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

		//also need to reset buffer status' incase they're now outdated
		//from previous operation
		//for ( result=0; result<num_buff; result++ ) {
		//	cur_buff->status = EMPTY;
		//	cur_buff = get_next_buff( cur_buff, num_buff );
		//}

		//go back to buff0
		//cur_buff = &buff0;

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
				//increment page_num so everything is ready for next dump
				//TODO make buffer_update function to handle everything
				cur_buff->page_num += cur_buff->reload;
				cur_buff->status = DUMPED;
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

	return;
}


