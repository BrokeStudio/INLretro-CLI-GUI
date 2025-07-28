#include "gba.h"

//only need this file if connector is present on the device
#ifdef GB_CONN 

uint16_t cur_addr_lo;
uint8_t cur_addr_hi;

//=================================================================================================
//
//	GBA operations
//	This file includes all the gba functions possible to be called from the gba dictionary.
//
//	See description of the commands contained here in shared/shared_dictionaries.h
//
//=================================================================================================

/* Desc:Function takes an opcode which was transmitted via USB
 * 	then decodes it to call designated function.
 * 	shared_dict_gba.h is used in both host and fw to ensure opcodes/names align
 * Pre: Macros must be defined in firmware pinport.h
 * 	opcode must be defined in shared_dict_gba.h
 * Post:function call complete.
 * Rtn: SUCCESS if opcode found and completed, error if opcode not present or other problem.
 */
uint8_t gba_call( uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata )
{

#define	RD_LEN	0
#define	RD0	1
#define	RD1	2
//resist temptation to make these 16bit indexes
//will break rule of accessing usb_buff in half word aligned access
//would have to use RD1-RD2 for 16bit aligned access..
//Actually.. that's not true.  return & RD_LEN are index 0-1, so RD0-1 would be index 2-3
//so it should be half word aligned..

#define	BYTE_LEN 1
#define	HWORD_LEN 2
	
	switch (opcode) { 
//		//no return value:
		case LATCH_ADDR:	
			//operand A0-15, miscdata A16-23->D0-7
			gba_latch_addr( operand, miscdata );
			break;
		case RELEASE_BUS:
			ROMSEL_HI();
			DATA_IP();	//A16-23 are output here during reads
			break;

		//8bit return values:
		case GBA_RD:
			//address must have been latched already
			rdata[RD_LEN] = HWORD_LEN;
			//can use operand as a variable
			operand = gba_rd();
			rdata[RD0] = operand;
			rdata[RD1] = operand>>8;
			break;
		default:
			 //macro doesn't exist
			 return ERR_UNKN_GBA_OPCODE;
	}
	
	return SUCCESS;

}

//latches A0-23, leaves /CS low for subsequent accesses
void gba_latch_addr( uint16_t addr_lo, uint8_t addr_hi)
{
	//store address so other functions can keep track of incrementing
	cur_addr_lo = addr_lo;
	cur_addr_hi = addr_hi;
	
	//set addr & data bus to output
	ADDR_OP();
	DATA_OP();

	//place addr on the bus
	ADDR_SET(addr_lo);
	DATA_SET(addr_hi);

	//latch the address
	//leave it low for subsequent access
	ROMSEL_LO();

	//leave AD0-15 as input for subsequent access
	ADDR_IP();

	//leave A16-23 as output for subsequent access

	return;
}

//address must already have been latched
//will increment address variables and A16-23
//ready to read next byte
uint16_t gba_rd()
{
	uint16_t read;

	if( cur_addr_lo == 0xFFFF ) {
		//going to have a roll over when incrementing
		cur_addr_hi++;
		//don't output it till this access is done though
	}

	CSRD_LO();
	cur_addr_lo++;	//increment to next byte that will be read
	read = ADDR_VAL;
	CSRD_HI();

	//if we had a 16bit addr roll over, need to increment A16-23
	DATA_SET(cur_addr_hi);

	return read;
}

//can only read 255 bytes, len can't be 255 else it would create infinite loop
// I think the byte read version is actually slightly faster...?
uint8_t gba_page_rd( uint16_t *data, uint8_t len)
{
	uint8_t i;
	uint16_t read;

	for( i=0; i<=len; i++ ) {

		//usbPoll();	//Call usbdrv.h usb polling while waiting for data

		//read 16bits
		read = gba_rd();

		//store lower byte little endian
		//now stores entire 16bit read at once
		data[i] = read;

		//upper byte
		//i++;

		//store upper byte
		//data[i] = read>>8;
	}

	//return index of last byte read
	return i;
}



#endif //GB_CONN
