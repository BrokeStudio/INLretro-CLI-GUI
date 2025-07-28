#include "n64.h"

//only need this file if connector is present on the device
#ifdef N64_CONN 

uint16_t n64_bank;	//A16-31 the upper 16bits that gets latched with ALE_H

//=================================================================================================
//
//	N64 operations
//	This file includes all the n64 functions possible to be called from the n64 dictionary.
//
//	See description of the commands contained here in shared/shared_dictionaries.h
//
//=================================================================================================

/* Desc:Function takes an opcode which was transmitted via USB
 * 	then decodes it to call designated function.
 * 	shared_dict_n64.h is used in both host and fw to ensure opcodes/names align
 * Pre: Macros must be defined in firmware pinport.h
 * 	opcode must be defined in shared_dict_n64.h
 * Post:function call complete.
 * Rtn: SUCCESS if opcode found and completed, error if opcode not present or other problem.
 */
uint8_t n64_call( uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata )
{

#define	RD_LEN	0
#define	RD0	1
#define	RD1	2

#define	BYTE_LEN 1
#define	HWORD_LEN 2
	
	switch (opcode) { 
//		//no return value:
	// TODO	case N64_WR:	
	//		n64_wr( operand, miscdata );
	//		break;

		case N64_SET_BANK:
			n64_bank = operand;
			break;

		case N64_LATCH_ADDR:	
			//operand A0-15, use SET_ADDR_HI above to set upper address (aka "bank")
			n64_latch_addr( operand );
			break;

		case N64_RELEASE_BUS:
			//latch addr will do this for us so maybe not needed..
			ALE_H_HI();
			NOP();
			NOP();
			NOP();
			NOP();
			NOP();
			ALE_L_HI();
			break;

		//8bit return values:
		case N64_RD:
			rdata[RD_LEN] = HWORD_LEN;
			//can use operand as a variable
			operand = n64_rd();
			rdata[RD0] = operand;
			rdata[RD1] = operand>>8;
			break;

		default:
			 //macro doesn't exist
			 return ERR_UNKN_N64_OPCODE;
	}
	
	return SUCCESS;

}

void	n64_wr( uint16_t addr, uint8_t data )
{
	return;
}

//latches AD1-15, leaves ALE_L/H low for subsequent accesses
//RD shouldn't be left low, assuming high
void n64_latch_addr( uint16_t addr_lo )
{
	//store address so other functions can keep track of incrementing
	//cur_addr_lo = addr_lo;
	
	//set ALE high incase it wasn't
	ALE_H_HI();
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	ALE_L_HI();
	
	//set addr & data bus to output
	ADDR_OP();

	//IDK if the order ALE_H/L matters, docs have H first
	ADDR_SET(n64_bank);
	NOP();
	ALE_H_LO();

	//latch low address A0 is effectively ignored
	ADDR_SET(addr_lo);
	NOP();
	ALE_L_LO();

	//leave AD0-15 as input for subsequent access
	ADDR_IP();

	//give the address decoder some time before permitting data to be read out
	//The N64 system supposedly waits ~1.040usec
	//STM32 @ 48Mhz = 20.8nsec cycle time -> would be ~50cycles
	//But that seems crazy long... and not necessary
	NOP(); NOP(); NOP(); NOP();
	NOP(); NOP(); NOP(); NOP();
//	NOP(); NOP(); NOP(); NOP();
//	NOP(); NOP(); NOP(); NOP();
//	NOP(); NOP(); NOP(); NOP();
//	NOP(); NOP(); NOP(); NOP();
//	NOP(); NOP(); NOP(); NOP();
//	NOP(); NOP(); NOP(); NOP();

	return;
}

//address must already have been latched
//will increment address variables and A16-23
//ready to read next byte
uint16_t n64_rd()
{
	uint16_t read;

	//if( cur_addr_lo == 0xFFFF ) {
	//	//going to have a roll over when incrementing
	//	cur_addr_hi++;
	//	//don't output it till this access is done though
	//}

	CSRD_LO();
	//cur_addr_lo++;	//increment to next byte that will be read
	
	NOP();
	NOP();
	//added more delay helps RE2 second read and some other bad reads
	NOP();
	NOP();

	//N64 console appears to have a /RD low time of 300nsec
	//But that seems crazy long... and not necessary


	read = ADDR_VAL;
	CSRD_HI();

	return read;
}

//can only read 255 bytes, len can't be 255 else it would create infinite loop
// I think the byte read version is actually slightly faster...?
uint8_t n64_page_rd( uint8_t *data, uint8_t addrH, uint8_t first, uint8_t len )
{
	uint16_t read;
	uint8_t i;

	//need to set the addr every 512Bytes, else will wrap around
	//effectively every 0x0200 bytes, the address needs latched
	//read0 addrH=0 first=0 (128B read)
	//read0 addrH=0 first=128 (128B read)
	//read0 addrH=1 first=0 (128B read)  <-- odd addrH values don't need address latched
	//read0 addrH=1 first=128 (128B read)
	//read0 addrH=2 first=0 (128B read) <== latch addrH again
	if ((first == 0) && (addrH|0x01))
		n64_latch_addr( addrH<<8 | first );
		//only need to latch address on even buffers
		//odd buffers are reading second half of 256Byte page, 
		//so the previous latching should be valid

	//now can call n64_rd to get 16bits of data
	
	//needed a delay between latching address, and reading data for the first time
	//NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); // --> Moved to the n64_latch_addr function

	for( i=0; i<=len; i++ ) {

		//usbPoll();	//Call usbdrv.h usb polling while waiting for data

		//read 16bits
		read = n64_rd();

		//store upper byte big endian
		data[i] = read>>8;

		//lower byte
		i++;

		//store lower byte
		data[i] = read;
	}

	//return index of last byte read
	return i;
}



#endif //N64_CONN
