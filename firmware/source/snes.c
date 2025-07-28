#include "snes.h"

//only need this file if connector is present on the device
#ifdef SNES_CONN 

//=================================================================================================
//
//	SNES operations
//	This file includes all the snes functions possible to be called from the snes dictionary.
//
//	See description of the commands contained here in shared/shared_dictionaries.h
//
//=================================================================================================

/* Desc:Function takes an opcode which was transmitted via USB
 * 	then decodes it to call designated function.
 * 	shared_dict_snes.h is used in both host and fw to ensure opcodes/names align
 * Pre: Macros must be defined in firmware pinport.h
 * 	opcode must be defined in shared_dict_snes.h
 * Post:function call complete.
 * Rtn: SUCCESS if opcode found and completed, error if opcode not present or other problem.
 */
uint8_t snes_call( uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata )
{

#define	RD_LEN	0
#define	RD0	1
#define	RD1	2

#define	BYTE_LEN 1
#define	HWORD_LEN 2
	
	switch (opcode) { 
		//no return value:
		case SNES_SET_BANK:	
			HADDR_SET( operand );
			break;
		case SNES_ROM_WR:	
			snes_wr( operand, miscdata, 0 );	//last arg is romsel state
			break;
		case SNES_SYS_WR:	
			snes_wr( operand, miscdata, 1 );	//last arg is romsel state
			break;
		case FLASH_WR_5V:	
			snes_5v_flash_wr( operand, miscdata );
			break;
		case FLASH_WR_3V:	
			snes_3v_flash_wr( operand, miscdata );
			break;

		//8bit return values:
		case SNES_ROM_RD:
			rdata[RD_LEN] = BYTE_LEN;
			rdata[RD0] = snes_rd( operand, 0 );	//last arg is romsel state
			break;
		case SNES_SYS_RD:
			rdata[RD_LEN] = BYTE_LEN;
			rdata[RD0] = snes_rd( operand, 1 );	//last arg is romsel state
			break;
		default:
			 //macro doesn't exist
			 return ERR_UNKN_SNES_OPCODE;
	}
	
	return SUCCESS;

}

/* Desc:SNES ROM Read without changing high bank
 * 	/ROMSEL set based on romsel arg
 * 	EXP0/RESET not affected
 * 	NOTE: this will access addresses when /ROMSEL isn't low on the console
 * Pre: snes_init() setup of io pins
 * Post:address left on bus
 * 	data bus left clear
 * Rtn:	Byte read from ROM at addr
 */
uint8_t	snes_rd( uint16_t addr, uint8_t romsel )
{
	uint8_t	read;	//return value

	//set address bus
	ADDR_SET(addr);
	
	if (romsel==0)
		ROMSEL_LO();

	CSRD_LO();

	//couple more NOP's waiting for data
	//zero nop's returned previous databus value
	NOP();	//one nop got most of the bits right
	NOP();	//two nop got all the bits right
	NOP();	//add third nop for some extra
	NOP();	//one more can't hurt
	//might need to wait longer for some carts...
	//this was long enough for AVR
	
	//SNES v2.0p needed 6 more NOPs compared to v3.x & v1.x
	//seems like a crazy long time...
	NOP();	//v2.0p gets prod & density ID correct with addition of this NOP
	//not sure why manf ID and sector ID are so much slower on v2 board
	NOP();
	NOP();	//v2.0p gets most bits right after 3 NOPs
	NOP();
	NOP();	//more after 5 extra...
	NOP();	//all after 6 extra..
	//sounds like 1 AVR NOP needs to equal 2STM32
	//AVR running at 16Mhz, STM32 running at 48Mhz (3x as fast)
	NOP();	//4MB proto needed this to get manfID, sector still bad
	NOP();	//all good on 4MB proto
	NOP();	//swapped for OR gate and takes a little longer now..?

	//latch data
	DATA_RD(read);

	//return bus to default
	CSRD_HI();
	ROMSEL_HI();
	
	return read;
}

/* Desc:SNES ROM Write
 * 	/ROMSEL set based on romsel arg
 * 	EXP0/RESET unaffected
 * 	write value to currently selected bank
 * 	NOTE: this will access addresses when /ROMSEL isn't low on the console
 * Pre: snes_init() setup of io pins
 * Post:data latched by anything listening on the bus
 * 	address left on bus
 * Rtn:	None
 */
void	snes_wr( uint16_t addr, uint8_t data, uint8_t romsel )
{

	ADDR_SET(addr);

	//put data on bus
	DATA_OP();
	DATA_SET(data);

	//set /WR low first as this sets direction of 
	//level shifter on v3.0 boards
	CSWR_LO();
	//Then set romsel as this enables output of level shifter
	if (romsel==0)
		ROMSEL_LO();
	//Doing the other order creates bus conflict between ROMSEL low -> WR low

	//give some time
	NOP();
	NOP();
	NOP();		//3x total NOPs fails ~2Bytes per 2MByte on v3.0 proto and inl6
	//swaping /WR /ROMSEL order above helped greatly
	//but still had 2 byte fails adding NOPS
	NOP();		//4x total NOPs passed all bytes v3.0 SNES and inl6
	NOP();
	NOP();	//6x total NOPs passed all bytes
	NOP();
	NOP();
	

	//latch data to cart memory/mapper
	CSWR_HI();
	ROMSEL_HI();

	//Free data bus
	DATA_IP();
}

/* Desc:SNES ROM Write to current address
 * 	/ROMSEL set based on romsel arg
 * 	EXP0/RESET unaffected
 * 	write value to currently selected bank, and current address
 * 	Mostly used when address is don't care
 * Pre: snes_init() setup of io pins
 * Post:data latched by anything listening on the bus
 * 	address left on bus
 * Rtn:	None
 */
void	snes_wr_cur_addr( uint8_t data, uint8_t romsel)
{

//	ADDR_SET(addr);

	//put data on bus
	DATA_OP();
	DATA_SET(data);

	//set /WR low first as this sets direction of 
	//level shifter on v3.0 boards
	CSWR_LO();
	//Then set romsel as this enables output of level shifter
	if (romsel==0)
		ROMSEL_LO();
	//Doing the other order creates bus conflict between ROMSEL low -> WR low

	//give some time
	NOP();
	NOP();
	NOP();		//3x total NOPs fails ~2Bytes per 2MByte on v3.0 proto and inl6
	//swaping /WR /ROMSEL order above helped greatly
	//but still had 2 byte fails adding NOPS
	NOP();		//4x total NOPs passed all bytes v3.0 SNES and inl6
	//NOP();
	//NOP();	//6x total NOPs passed all bytes

	//latch data to cart memory/mapper
	CSWR_HI();
	ROMSEL_HI();

	//Free data bus
	DATA_IP();
}


/* Desc:SNES ROM Page Read with optional USB polling
 * 	/ROMSEL based on romsel arg, EXP0/RESET unaffected
 *	if poll is true calls usbdrv.h usbPoll fuction
 *	this is needed to keep from timing out when double buffering usb data
 * Pre: snes_init() setup of io pins
 *	num_bytes can't exceed 256B page boundary
 * Post:address left on bus
 * 	data bus left clear
 *	data buffer filled starting at first to last
 * Rtn:	Index of last byte read
 */
uint8_t snes_page_rd_poll( uint8_t *data, uint8_t addrH, uint8_t romsel, uint8_t first, uint8_t len, uint8_t poll )
{
	uint8_t i;

	//set address bus
	ADDRH(addrH);
	
	//set /ROMSEL and /RD
	CSRD_LO();

	if (romsel==0) {
		ROMSEL_LO();
	}

	//set lower address bits
	ADDRL(first);		//doing this prior to entry and right after latching
				//gives longest delay between address out and latching data
	for( i=0; i<=len; i++ ) {
		//testing shows that having this if statement doesn't affect overall dumping speed
		if ( poll == FALSE ) {
			NOP();	//couple more NOP's waiting for data
			NOP();	//one prob good enough considering the if/else
			NOP();
			NOP();
		} else {
			usbPoll();	//Call usbdrv.h usb polling while waiting for data
			NOP();
			NOP();
			NOP();
		}

		//gameboy needed some extra NOPS
		//I cut these back out because didn't want the delay in SNES
//		NOP();
//		NOP();
//		NOP();
//		NOP();
//		NOP();
//		NOP();
		//latch data
		DATA_RD(data[i]);

		//set lower address bits
		//ADDRL(++first);	THIS broke things, on stm adapter because macro expands it twice!
		first++;
		ADDRL(first);
	}

	//return bus to default
	CSRD_HI();
	ROMSEL_HI();
	
	//return index of last byte read
	return i;
}


/* Desc:SNES 5v ROM FLASH Write
 * 	NOTE: /ROMSEL is always taken low
 * 	NOTE: if the byte isn't erased it will stop over current value
 * 	NOTE: doesn't hang if write fails, just returns, goal is to be fast
 * Pre: snes_init() setup of io pins
 * 	desired bank must already be selected
 * Post:Byte written and ready for another write
 * Rtn:	None
 */
void snes_5v_flash_wr( uint16_t addr, uint8_t data )
{

	uint8_t rv;

	//unlock and write data
	snes_wr(0x5555, 0xAA, 0);
	snes_wr(0x2AAA, 0x55, 0);
	snes_wr(0x5555, 0xA0, 0);
	snes_wr(addr, data, 0);

	do {
		rv = snes_rd(addr, 0);
		usbPoll();	//orignal kazzo needs this frequently to slurp up incoming data
	} while (rv != snes_rd(addr, 0));

	return;
}

/* Desc:SNES 3v ROM FLASH Write
 * 	NOTE: /ROMSEL is always taken low
 * 	NOTE: if the byte isn't erased it will stop over current value
 * 	NOTE: doesn't hang if write fails, just returns, goal is to be fast
 * Pre: snes_init() setup of io pins
 * 	desired bank must already be selected
 * Post:Byte written and ready for another write
 * Rtn:	None
 */
void snes_3v_flash_wr( uint16_t addr, uint8_t data )
{

	uint8_t rv;

	//unlock and write data
	snes_wr(0x8AAA, 0xAA, 0);
	snes_wr(0x8555, 0x55, 0);
	snes_wr(0x8AAA, 0xA0, 0);
	snes_wr(addr, data, 0);

	do {
		rv = snes_rd(addr, 0);
		usbPoll();	//orignal kazzo needs this frequently to slurp up incoming data
	} while (rv != snes_rd(addr, 0));

	return;
}

/* Desc:SNES 3v ROM FLASH VERIFY Write
 * 	NOTE: /ROMSEL is always taken low
 * 	NOTE: if the byte isn't erased it will stop over current value
 * 	NOTE: doesn't hang if write fails, just returns, goal is to be fast
 * Pre: snes_init() setup of io pins
 * 	desired bank must already be selected
 * Post:Byte written and ready for another write
 * Rtn:	None
 */
uint8_t snes_3v_verify_wr( uint16_t addr, uint8_t data )
{

	uint8_t rv;

	//unlock and write data
	snes_wr(0x8AAA, 0xAA, 0);
	snes_wr(0x8555, 0x55, 0);
	snes_wr(0x8AAA, 0xA0, 0);
	snes_wr(addr, data, 0);

	do {
		rv = snes_rd(addr, 0);
		usbPoll();	//orignal kazzo needs this frequently to slurp up incoming data
	} while (rv != snes_rd(addr, 0));

	return rv;
}

/* Desc:SNES 3v ROM FLASH BUFFER Write 32Bytes at a time
 * 	NOTE: /ROMSEL is always taken low
 * 	NOTE: if the byte isn't erased it will stop over current value
 * 	NOTE: doesn't hang if write fails, just returns, goal is to be fast
 * Pre: snes_init() setup of io pins
 * 	desired bank must already be selected
 * Post:Byte written and ready for another write
 * Rtn:	None
 */
void snes_3v_buffer_wr( uint16_t addr, uint8_t *data )
{

	/* TODO, actually implement this, currently everything is done on flash.c side
	uint8_t rv;

	//unlock and write data
	snes_wr(0x8AAA, 0xAA, 0);
	snes_wr(0x8555, 0x55, 0);
	//write buffer write to SA
	snes_wr(addr, 0x25, 0);
	//write number of words - 1 to SA
	
	//write first data to first address
	snes_wr(addr, data[1], 0);

	do {
		rv = snes_rd(addr, 0);
		usbPoll();	//orignal kazzo needs this frequently to slurp up incoming data
	} while (rv != snes_rd(addr, 0));

	return;
	*/
}


#endif //SNES_CONN
