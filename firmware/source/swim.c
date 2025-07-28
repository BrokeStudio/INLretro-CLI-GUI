#include "swim.h"

#ifdef STM_CORE

//=================================================================================================
//
//	SWIM operations
//	This file includes all the swim functions possible to be called from the swim dictionary.
//
//	See description of the commands contained here in shared/shared_dictionaries.h
//
//=================================================================================================

uint8_t swim_pin;
//uint16_t swim_mask;
GPIO_TypeDef *swim_base;

/* Desc:Function takes an opcode which was transmitted via USB
 * 	then decodes it to call designated function.
 * 	shared_dict_swim.h is used in both host and fw to ensure opcodes/names align
 * Pre: Macros must be defined in firmware pinport.h & swim.h
 * 	opcode must be defined in shared_dict_swim.h
 * Post:function call complete.
 * Rtn: SUCCESS if opcode found, error if opcode not present or other problem.
 */
uint8_t swim_call( uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata )
{
#define	RD_LEN	0
#define	RD0	1
#define	RD1	2
	uint16_t *ret_hword = (uint16_t*) &rdata[1];

#define	BYTE_LEN 1
#define	HWORD_LEN 2
	switch (opcode) { 
		case SWIM_ACTIVATE:	swim_activate();	break;
		case SWIM_RESET:	swim_reset();		break;
		case SWIM_SRST:			
			rdata[RD_LEN] = BYTE_LEN;
			//assumes low speed
			rdata[RD0] = swim_xfr( 0x0000, ((SWIM_WR<<16) | 4), swim_base, 1<<swim_pin);	break;
		case WOTF:		
			rdata[RD_LEN] = BYTE_LEN;
			rdata[RD0] = swim_wotf( SWIM_LS, operand, miscdata );	break;
		case WOTF_HS:		
			rdata[RD_LEN] = BYTE_LEN;
			rdata[RD0] = swim_wotf( SWIM_HS, operand, miscdata );	break;
		case ROTF:	
			rdata[RD_LEN] = HWORD_LEN;
			//this assignment actually undoes the byte swap
			//first index of data includes NAK/ACK just like write routines which only return ACK/NAK
			//second index of data includes actual byte read back
			*ret_hword = swim_rotf( SWIM_LS, operand );	break;
		case ROTF_HS:	
			rdata[RD_LEN] = HWORD_LEN;
			//this assignment actually undoes the byte swap
			//first index of data includes NAK/ACK just like write routines which only return ACK/NAK
			//second index of data includes actual byte read back
			*ret_hword = swim_rotf( SWIM_HS, operand );	break;
		default:
			 //opcode doesn't exist
			 return ERR_UNKN_SWIM_OPCODE;
	}
	
	return SUCCESS;

}

//Doesn't actually delay exact usec, but it's proportional which is good enough for SWIM activation
void delay_us( uint16_t delay )
{
	uint16_t i = 0;

	delay = delay *4;

	//calling and pin toggling overhead is 0.1usec

	for( i=0; i<delay; i++) { 
		NOP(); 
		NOP(); 		//with delay * 4, and 2x NOP, 10 -> 10.64us, 100 -> 100.62us, 1k -> 1.0001 ms including pin delay
	//	NOP(); 
	//	NOP(); 		//with delay * 4, adding this NOP, adds 84nsec per delay
		//NOP(); 
		//NOP(); 	//6x NOP, 48Mhz, delay = 10 -> 2.92usec + overhead

			
	}

}

void delay( uint16_t delay )
{
	uint16_t i = 0;

	for( i=0; i<delay; i++) { 
		NOP(); 
		NOP(); 
	}	 //16->11.8 on stmad

}

/* Desc:Initiate SWIM activate sequence
 * Pre: swim_pin must be set and initialized via io.h
 * Post:STM8 mcu SWIM active
 * Rtn: SUCCESS if able to enter sucessfully.
 */
void swim_activate()
{
	uint16_t i;
	
//TODO probably should disable interrupts during this process as they would muck up timing
	
	//pulse low for 16usec  spec says 16usec
	//but looking at working programmers they do twice the delays below
	SWIM_SET_LO();
	delay_us(16);
	SWIM_SET_HI();

	//toggle high->low T=1msec 4x
	for( i = 0; i < 4; i++) {
	delay_us(500);
	SWIM_SET_LO();
	delay_us(500);
	SWIM_SET_HI();
	}

	//toggle high->low T=0.5msec 4x
	for( i = 0; i < 4; i++) {
	delay_us(250);
	SWIM_SET_LO();
	delay_us(250);
	SWIM_SET_HI();
	}



	//wait for device to take swim_pin low for ~16usec
	//it's low for 128 SWIM clock sync pulse
	//Best way to do this would be to wait for an interrupt
	//on the swim pin going low, then have the isr count
	//low time.  If anything takes too long timeout.
	
	//TODO
	//return SUCCESS/FAIL depending on wether that ~16usec pulse was obtained
//	return SUCCESS;

}

/* Desc:Hold swim pin low for >128 SWIM clocks (16usec)
 * Pre: swim must be activated by
 * Post:STM8 mcu SWIM comms are reset
 * Rtn: SUCCESS if device responds with sync window.
 */
void swim_reset()
{

	//pulse low for 16usec  spec says 16usec
	//but looking at working programmers they do very long resets 
	SWIM_SET_LO();
	delay_us(16);
	SWIM_SET_HI();

}



//#define mov_swim_mask_r0()	__asm 		("mov  r0, %[val]" : : [val] "r" (swim_mask) 	: "r0" )
//#define mov_pushpull_r6()	__asm 		("mov  r6, %[val]" : : [val] "r" (pushpull) 	: "r6" )
//#define mov_opendrain_r7()	__asm 		("mov  r7, %[val]" : : [val] "r" (opendrain) 	: "r7" )
//
////BSRR 0x18
//#define str_r0_bset() 		__asm volatile 	("strh r0, [%[mmio], #0x18]" : : [mmio] "r" (swim_base))
////BRR  0x28
//#define str_r0_bres() 		__asm volatile 	("strh r0, [%[mmio], #0x28]" : : [mmio] "r" (swim_base))
////OTYPER 0x04
//#define pp_swim()		__asm volatile 	("strh r6, [%[mmio], #0x04]" : : [mmio] "r" (swim_base))
//#define od_swim()		__asm volatile 	("strh r7, [%[mmio], #0x04]" : : [mmio] "r" (swim_base))

#define NO_RESP	0xFF
#define ACK	0x01
#define NAK	0x00
	
/* Function to get parity of number n. It returns 0
 * if n has odd parity, and returns 0xFF if n has even
 * parity */
uint16_t append_pairity(uint8_t n)
{
	//shift incoming data to upper byte
	uint16_t data_pb = (n<<8);
	uint8_t parity = 0;

	while (n) {
		parity = ~parity;
		n = n & (n - 1);
	}        

	if ( parity ) {
		return (data_pb | 0x80);
	} else {
		return data_pb;
	}
}

/* Desc:read byte from SWIM
 * Pre: swim must be activated
 * Post:
 * Rtn: should return success/error and value read
 */
uint16_t swim_rotf(uint8_t speed, uint16_t addr)
{
	uint32_t ack_data = 0;

	uint16_t data_pb;
	uint32_t spddir_len;
	//bit sequence:
	//1bit header "0" Host comm
	//3bit command b2-1-0 "001" ROTF
	//1bit pairity xor of cmd "1"
	//1bit ACK "1" or NAK "0" from device
	// 0b0_0011
	data_pb = 0x3000;
	spddir_len = ((SWIM_WR|speed)<<16) | 4; //data + pairity ( '0' header not included)
	ack_data = swim_xfr( data_pb, spddir_len, swim_base, 1<<swim_pin);
	if (ack_data != ACK) goto end_swim; 

	//write N "number of bytes for ROTF"
	data_pb = 0x0180;
	spddir_len = ((SWIM_WR|speed)<<16) | 9;
	ack_data = swim_xfr( data_pb, spddir_len, swim_base, 1<<swim_pin);
	if (ack_data != ACK) goto end_swim; 

	//write @E extended address of write
	//always 0x00 since targetting stm8s003 which only has one section
	data_pb = 0x0000;
	spddir_len = ((SWIM_WR|speed)<<16) | 9;
	ack_data = swim_xfr( data_pb, spddir_len, swim_base, 1<<swim_pin);
	if (ack_data != ACK) goto end_swim; 

	//write @H high address of write
	data_pb = append_pairity( addr>>8 );
	spddir_len = ((SWIM_WR|speed)<<16) | 9;
	ack_data = swim_xfr( data_pb, spddir_len, swim_base, 1<<swim_pin);
	if (ack_data != ACK) goto end_swim; 

	//write @L high address of write
	data_pb = append_pairity( addr );
	//this is a read xfr because device will output data immediately after 
	//writting last byte of command info
	spddir_len = ((SWIM_RD|speed)<<16) | 9;
	ack_data = swim_xfr( data_pb, spddir_len, swim_base, 1<<swim_pin);

	//read DATA portion of write

	//More bytes can be written 
	//any time NAK is recieved must resend byte
end_swim:

	return ack_data;


}

uint8_t swim_wotf(uint8_t speed, uint16_t addr, uint8_t data)
{
	uint32_t ack_data = 0;
	uint16_t data_pb;
	uint32_t spddir_len;
	//bit sequence:
	//1bit header "0" Host comm
	//3bit command b2-1-0 "010" WOTF
	//1bit pairity xor of cmd "1"
	//1bit ACK "1" or NAK "0" from device
	// 0b0_0101
	data_pb = 0x5000;
	spddir_len = ((SWIM_WR|speed)<<16) | 4; //data + pairity ( '0' header not included)
	ack_data = swim_xfr( data_pb, spddir_len, swim_base, 1<<swim_pin);
	if (ack_data != ACK) goto end_swim; 

	//write N "number of bytes for ROTF"
	data_pb = 0x0180;
	spddir_len = ((SWIM_WR|speed)<<16) | 9;
	ack_data = swim_xfr( data_pb, spddir_len, swim_base, 1<<swim_pin);
	if (ack_data != ACK) goto end_swim; 

	//write @E extended address of write
	//always 0x00 since targetting stm8s003 which only has one section
	data_pb = 0x0000;
	spddir_len = ((SWIM_WR|speed)<<16) | 9;
	ack_data = swim_xfr( data_pb, spddir_len, swim_base, 1<<swim_pin);
	if (ack_data != ACK) goto end_swim; 

	//write @H high address of write
	data_pb = append_pairity( addr>>8 );
	spddir_len = ((SWIM_WR|speed)<<16) | 9;
	ack_data = swim_xfr( data_pb, spddir_len, swim_base, 1<<swim_pin);
	if (ack_data != ACK) goto end_swim; 

	//write @L high address of write
	data_pb = append_pairity( addr );
	//writting last byte of command info
	spddir_len = ((SWIM_WR|speed)<<16) | 9;
	ack_data = swim_xfr( data_pb, spddir_len, swim_base, 1<<swim_pin);

	//DATA portion of write
	data_pb = append_pairity( data );
	spddir_len = ((SWIM_WR|speed)<<16) | 9;
	ack_data = swim_xfr( data_pb, spddir_len, swim_base, 1<<swim_pin);

	//More bytes can be written 
	//any time NAK is recieved must resend byte
end_swim:

	return ack_data;

}


#ifdef AVR_CORE

//TODO write assembly function that runs on AVR core....
uint32_t swim_xfr( uint16_t data_pb, uint32_t spddir_len, GPIO_TypeDef *swim_base, uint16_t swim_mask)
{
	return 0;
}

#endif

/* Desc:Transfer SWIM bit stream
 * 	Always outputs '0' as first bit for header "from host"
 * 	Will output len number of bits plus one for header
 * Pre: swim_pin must be set and initialized via io.h
 * 	stream has first data bit stored in bit15 - bit[15-len+2]
 * 	pairity bit must be last bit in stream sequence bit[15-len+1]
 * 	ie bit7 contains pairity bit for 8bit data stream
 * Post:STM8 mcu SWIM active
 * Rtn: 0xFF if no response, 0-NAK, 1-ACK.
 */
/*
uint8_t swim_out(uint16_t stream, uint8_t len)//, GPIO_TypeDef *base)
{
//__asm("swim_out_begin:\n\t");

#ifdef STM_CORE
	uint8_t return_val;

	uint16_t pushpull = swim_base->OTYPER & ~swim_mask;
	uint16_t opendrain = swim_base->OTYPER |  swim_mask;

	mov_swim_mask_r0();	//will store r0 to BSRR or BRR to set/clear
	mov_pushpull_r6();	//will store r7 to OTYPER to drive high
	mov_opendrain_r7();	//will store r6 to OTYPER to allow device to drive low

	//store len in r5
	__asm volatile ("mov r5, %[val]" : : [val] "r" (len) : "r5" );

	//set flags so first bit is header '0' "from host"
	//the stream comes in as 16bit value with stream bit 7 in bit position 15
	//shift the stream left so the current transfer bit is in bit position 31
	//15 -> 30 is 15bit shifts, this leaves header zero in bit position 31
	//store stream in r4
	__asm volatile ("mov r4, %[val]" : : [val] "r" (stream) : "r4" );
	__asm volatile ("lsl r4, #15" : : : "r4", "cc" );

	//NOTE!  cortex M0 only supports 'S' versions of lsl, sub, and, etc type
	//opcodes.  I get compiler error for including the 's' at end of instruction
	//but lsl is same as lsls on M0, so just use lsl to avoid compiler error...

// bit start:
__asm("bit_start:\n\t");

	//always start going low
	str_r0_bres();

	//current bit is stored in bit31 and Negative flag is set if 
	//current bit is '1'
	__asm volatile ("bpl cur_bit_zero\n\t");
	//go high since current bit is '1' 
	pp_swim();
	str_r0_bset();
	od_swim();
	__asm volatile ("b det_next_bit\n\t");

__asm("cur_bit_zero:\n\t");
	//must delay same amount of time as instructions above since branch
	//add delay here until '1' and '0' are same length
	NOP(); NOP(); NOP(); NOP(); NOP(); NOP();
	NOP();

__asm("det_next_bit:\n\t");

	//determine if this is the last bit
	__asm volatile ("sub r5, #0x01" : : : "r5", "cc" );

	//if last bit, go to stream end to prepare for ACK/NAK latch
	__asm volatile ("bmi stream_end\n\t");
	
	//determine next bit value
	__asm volatile ("lsl r4, #1" : : : "r4", "cc" );
	//Negative flag is now set for '1', and clear for '0'

	//delay until 'go high' time for '0'
	//add delay here to make all bit transfers longer
	NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP();
	NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP();
	NOP(); NOP(); NOP(); NOP();
	
	//always go high for '0' (no effect if already high for '1')
	pp_swim();
	str_r0_bset();
	od_swim();
	
	//go to bit start
	__asm volatile ("b bit_start\n\t");

//stream end:
__asm("stream_end:\n\t");

	//delay until 'go high' time for '0'
	NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP();
	NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP();
	NOP(); NOP(); NOP();
	
	//always go high for '0' (no effect if already high for '1')
	pp_swim();
	str_r0_bset();
	od_swim();

	//delay until time to latch ACK/NAK from device
	NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP();	
	//8x NOP's misread at times...
	//6x NOP's always misread, so must be too early
	NOP();	//9x NOP's and we're getting stable reads

	//first need to ensure device is actually responding
	//sample when output should be low for a 1 or 0
	//str_r0_bres(); //debug set low to denote when swim pin is being sampled with logic anaylzer
	//sampling ~100nsec into bit transfer (low for 125nsec min)

	//latch SWIM pin value from IDR 0x10
	__asm volatile ("ldrh r3, [%[mmio], #0x10]" : : [mmio] "r" (swim_base) : "r3");
	__asm volatile ("and  r3, r0"	       : : : "r3", "cc" );
	
	//if it wasn't low, then the device didn't respond, so return error designating that
	//__asm volatile ("bne no_response\n\t");

	__asm ("mov %[rv], r3" : [rv] "=r" (return_val) );
	if (return_val != 0) {
		return NO_RESP;
	}

	//now delay until ~half way through bit transfer to sense 1-ACK or 0-NAK
	NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP();
	NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP();
	//sampling 1.35usec into bit transfer (~half way)
	NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP();
	//sampling 2.00usec into bit transfer oscope shows 2.7volts on stmad w/open drain

	//debug set low to denote when swim pin is being sampled with logic anaylzer
	//str_r0_bres();
	//pp_swim();

	//latch SWIM pin value from IDR 0x10
	__asm volatile ("ldr  r3, [%[mmio], #0x10]" : : [mmio] "r" (swim_base) : "r3");
	__asm volatile ("and  r3, r0"	       : : : "r3", "cc" );

	//move r3 to return val reg
	__asm volatile ("mov %[rv], r3" : [rv] "=r" (return_val) );
	//mask out swim pin so return value is 0 or non-zero based on device output
	//return_val &= swim_mask;

	if (return_val == 0x00) {
		return NAK;
	} 

#endif
	//made it to here then we got an ACK
	return ACK;
}
*/

#endif
