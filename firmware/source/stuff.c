#include "stuff.h"

uint32_t lfsr;	//all bits set is an invalid state, initialize to a valid state

uint8_t stuff_call( uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata )
{

#define	RD_LEN	0
#define	RD0	1
#define	RD1	2

#define	BYTE_LEN 1
#define	HWORD_LEN 2

	
	switch (opcode) { 
		case SET_LFSR_H_CLR_L:	
			lfsr = operand;
			lfsr = lfsr<<16;
			break;
		case SET_LFSR_L:	
			lfsr = (lfsr & 0xFFFF0000) | operand;
			break;
		case RESET_LFSR:	
			lfsr = 1;
			break;
		default:
			 //opcode doesn't exist
			 return ERR_UNKN_MISC_OPCODE;
	}
	
	return SUCCESS;

}

void set_lfsr(uint32_t seed)
{
	lfsr = seed;
}

//32bit linear feedback shift register
//has a total of 4Gbit random stream / 8bit = 512MByte
//call to get the next random byte from the lfsr
//http://www.xilinx.com/support/documentation/application_notes/xapp052.pdf
uint8_t lfsr_32()
{
	//taps are LFSR bits 32, 22, 2, 1 when counting from 1
	//taps are LFSR bits 31, 21, 1, 0 when counting from 0
	
	uint8_t lsb;
	uint8_t temp;
	uint8_t count = 7;

	while (count) {
	
		count--;

		//get bit0
		lsb = lfsr;
	
		//get bit1
		temp = lfsr>>1;
		//xor bits 0 & 1
		lsb = lsb ^ temp;
	
		//get bit21
		temp = lfsr>>21;
		//xor bits 0, 1, 21
		lsb = lsb ^ temp;
	
		//get bit31
		temp = lfsr>>31;
		//xor bits 0, 1, 21, 31
		lsb = lsb ^ temp;
	
		//shift the register and OR in the lsbit
		lfsr = lfsr<<1 | (lsb&0x01);
	}

	//8bit return value
	return lfsr;

}
