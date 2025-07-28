#include "sega.h"

//only need this file if connector is present on the device
#ifdef SEGA_CONN 

uint16_t sega_addr = 0;
uint16_t sega_bank = 0;

//=================================================================================================
//
//	SEGA operations
//	This file includes all the sega functions possible to be called from the sega dictionary.
//
//	See description of the commands contained here in shared/shared_dictionaries.h
//
//=================================================================================================

/* Desc:Function takes an opcode which was transmitted via USB
 * 	then decodes it to call designated function.
 * 	shared_dict_sega.h is used in both host and fw to ensure opcodes/names align
 * Pre: Macros must be defined in firmware pinport.h
 * 	opcode must be defined in shared_dict_sega.h
 * Post:function call complete.
 * Rtn: SUCCESS if opcode found and completed, error if opcode not present or other problem.
 */
uint8_t sega_call( uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata )
{

#define	RD_LEN	0
#define	RD0	1
#define	RD1	2

#define	BYTE_LEN 1
#define	HWORD_LEN 2

	uint16_t temp;
	
	switch (opcode) { 
//		//no return value:
		case GEN_SET_ADDR:
			sega_addr = operand;
			ADDR_SET(sega_addr);
			break;
/*
		case GEN_WR_LO:
			sega_addr = operand;
			gen_wr_lo( operand, miscdata );
			break;
		case GEN_WR_HI:
			sega_addr = operand;
			gen_wr_hi( operand, miscdata );
			break;
*/
		case GEN_SET_BANK:
			sega_bank = operand;
			gen_set_bank( operand );
			break;

		case GEN_FLASH_WR_ADDROFF:
			sega_addr += miscdata;
			gen_flash_wr(sega_addr, operand);
			break;

		case GEN_SST_FLASH_WR_ADDROFF:
			sega_addr += miscdata;
			gen_sst_flash_wr(sega_addr, operand);
			break;

		case GEN_SET_RAM:
			gen_set_ram(operand);
			break;

		case GEN_RAM_WR:
			sega_addr = operand;
			gen_ram_wr(sega_addr, miscdata);
			break;

		case GEN_RAM_RD:
			sega_addr = operand;
			rdata[RD_LEN] = BYTE_LEN;
			rdata[RD0] = gen_ram_rd( sega_addr );
			break;

		//8bit return values:
		case GEN_ROM_RD:
			sega_addr = operand;
			rdata[RD_LEN] = HWORD_LEN;
			temp = gen_rom_rd( operand );
			rdata[RD0] = temp;
			rdata[RD1] = temp>>8;
			break;

		case GEN_TIME_WR:
			gen_time_wr( operand, miscdata );
			break;

		case GEN_PAGE_RAM_WR_LFSR:
			gen_page_ram_wr_lfsr(operand, miscdata);
			break;

		default:
			 //macro doesn't exist
			 return ERR_UNKN_SEGA_OPCODE;
	}
	
	return SUCCESS;

}

void gen_set_bank( uint8_t bank )
{
#define LOMEM_TIME_MASK 0x84
#define LOMEM_MASK 0x04
#define TIME_MASK 0x80
	//A17-18, 20-23
	FFADDR_SET( (bank & 0x7B) | TIME_MASK | LOMEM_MASK );	//TODO decode #TIME & LO_MEM
#define SEGA_A19_MASK 0x04
	//A19
	if ( bank & SEGA_A19_MASK ) {
		IRQ_HI();
	} else {
		IRQ_LO();
	}
	//use of flip-flop corrupts A1-A16, restore it
	ADDR_SET(sega_addr);
}

void gen_ram_wr( uint16_t addr, uint8_t data )
{
	//enable RAM access
	gen_time_wr(0x0001, 0x01);

	//set address and A21 to 1
	gen_set_bank( 0x10 );
	ADDR_SET(sega_addr);

	//put data on bus
	DATA_OP();
	DATA_SET(data); //lower byte D0-7

	//set #C_OE
	CSRD_HI();

	//clear #WE - #LDSW
	PRGRW_LO();

	//clear #C_CE
	ROMSEL_LO();

	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	
	//set #WE/#LDSW - latch data
	PRGRW_HI();

	//set #C_CE
	ROMSEL_HI();

	//Free data bus
	DATA_IP();

	//disable RAM access
	gen_time_wr(0x0001, 0x00);

}

uint8_t gen_ram_rd( uint16_t addr )
{
	uint8_t read; //return value

	//enable RAM access
	gen_time_wr(0x0001, 0x01);

	//set address and A21 to 1
	gen_set_bank( 0x10 );
	ADDR_SET(sega_addr);

	//set data bus as input
	DATA_IP();

	//clear #C_OE
	CSRD_LO();

	//set #WE/#LDSW
	PRGRW_HI();

	//clear #C_CE
	ROMSEL_LO();

	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();

	DATA_RD(read);

	//set #WE/#LDSW
	PRGRW_HI();

	//set #C_OE
	CSRD_HI();

	//set #C_CE
	ROMSEL_HI();

	//disable RAM access
	gen_time_wr(0x0001, 0x00);

	return read;
}

uint16_t gen_rom_rd( uint16_t addr )
{
	uint16_t rv;
	uint8_t temp;

	//set data bus as input
	DATA16_IP();

	//set address
	gen_set_bank( sega_bank );
	//ADDR_SET(addr); // should be done by gen_set_bank above

	//set #WE/#LDSW
	PRGRW_HI();

	//set #WE/#UDSW B29  CPU D8-15 data strobe
	CSWR_HI();

	//clear #C_OE
	CSRD_LO();

	//clear #C_CE
	ROMSEL_LO();

	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	//6 above were working, trying more
	NOP();
	NOP();
	NOP();
	// NOP();
	// NOP();
	// NOP();
	// // all of these NOPs are needed because of the inverter on the SRAM proto board...
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();

	DATA16L_RD(rv);
	DATA16H_RD(temp);
	rv |= temp << 8;

	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();

	//set #C_CE
	ROMSEL_HI();

	//set #C_OE
	CSRD_HI();

	return rv;
}

/*
void gen_wr_lo( uint16_t addr, uint8_t data )
{

	ADDR_SET(addr);

	//put data on bus
	DATA_OP();
	DATA_SET(data); //lower byte D0-7

	//set #C_CE
	ROMSEL_LO();

	//set #C_OE
	//CSRD_LO();

	//set #LDSW
	PRGRW_LO();	

	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	
	//latch data with /WE - #LDSW
	PRGRW_HI();	

	//return bus to default
	//CSRD_HI();
	ROMSEL_HI();

	//Free data bus
	DATA_IP();
}

//TODO this function is untested, but I think it'll work..
void gen_wr_hi( uint16_t addr, uint8_t data )
{

	ADDR_SET(addr);

	//put data on bus
	//DATA_OP();
	//DATA_SET(data); //lower byte D0-7
	
	//set data bus to output
//TODO maybe want a function that only sets upper byte to output..?
	DATA16_OP();
	//DATA16L_SET(data);
	DATA16H_SET(data); //put 8bits of data on high byte

	//set #C_CE
	ROMSEL_LO();  //enables level shifter

	//wait for data to get to flash before latching
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();

	//set #UDSW
	CSWR_LO();	

	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	
	//latch data with /WE - #UDSW
	CSWR_HI();

	NOP();
	NOP();
	NOP();

	//return bus to default
	ROMSEL_HI();

	//Free data bus
	DATA16_IP();
}
*/

void gen_flash_wr( uint16_t addr, uint16_t data )
{

	uint8_t temp = data;

	//sega_addr = addr;

	//set address
	//gen_set_bank( 0x00 );
	ADDR_SET(addr);

	//put data on bus
	//DATA_OP();
	//DATA_SET(temp); //lower byte D0-7
	DATA16_OP();
	DATA16L_SET(data);
	data = data>>8;
	DATA16H_SET(data); //put 8bits of data on high byte

	//TODO figure out why this is needed...
	//guessing macro expansion or something with setting both bytes separately
	DATA_SET(temp); //lower byte D0-7

	//clear #WE/#LDSW
	PRGRW_LO();

	//clear #WE/#UDSW B29  CPU D8-15 data strobe
	CSWR_LO();

	//set #C_OE
	CSRD_HI();

	//clear #C_CE
	ROMSEL_LO();

	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	//6 above were working, testing more
	//NOP();
	//NOP();
	//NOP();
	//NOP();
	//NOP();
	//NOP();

	//set #WE/#LDSW
	PRGRW_HI();

	//set #WE/#UDSW
	//latch data with /WE - #LDSW
	CSWR_HI();

	//set #C_CE
	//return bus to default
	ROMSEL_HI();

	//Free data bus
	//DATA_IP();
	DATA16_IP();
}

void gen_set_ram( uint16_t data )
{
	gen_time_wr(0x0001, data);
	return;

	#define LOMEM_MASK 0x04
	#define TIME_MASK 0x80

	data = data & 0x0001;

	DATA_OP();
	DATA_SET(data);
	FFADDR_SET(LOMEM_MASK);
	ROMSEL_LO(); // controls level shifters #OE
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	FFADDR_SET(LOMEM_MASK | TIME_MASK);
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	ROMSEL_HI(); // controls level shifters #OE
	//Free data bus
	DATA_IP();
}

/* Desc:SEGA GENESIS ROM Page Read with optional USB polling
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
uint8_t genesis_page_rd( uint8_t *data, uint16_t addrH, uint8_t first, uint8_t len )
{
	uint8_t i;

	uint16_t address = first>>1; //shift because there is no A0

	//address = ((addrH<<8) | first)>>1;	//shift because there is no A0
	address = (addrH<<7) | address;	//shift because there is no A0

	//set address
	//ADDRH(addrH);
	ADDRH(address>>8);
	
	//set #C_CE
	ROMSEL_LO();

	//set #C_OE
	CSRD_LO();

	first = address;

	//set lower address bits
	ADDRL(first);		//doing this prior to entry and right after latching
				//gives longest delay between address out and latching data
	for( i=0; i<=len; i++ ) {

		//genesis needed some extra NOPS
		// NOP();
		// NOP();
		// NOP();
		// NOP();
		// NOP();
		// NOP();
		// NOP();
		// NOP();
		
		//latch data high byte
		data[i] = HDATA_VAL;

		i++;

		//latch data low byte
		DATA_RD(data[i]);

		//set lower address bits
		//ADDRL(++first);	THIS broke things, on stm adapter because macro expands it twice!
		first++;
		ADDRL(first);
	}

	//return bus to default
	CSRD_HI();		// #C_OE
	ROMSEL_HI();	// #C_CE
	
	//return index of last byte read
	return i;
}

/* Desc:SEGA GENESIS RAM Page Read with optional USB polling
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
uint8_t genesis_ram_page_rd( uint8_t *data, uint16_t addrH, uint8_t first, uint8_t len )
{
	uint8_t i;

	//set address bus
	ADDRH(addrH);

	//set #C_OE
	CSRD_LO();

	//set #C_CE
	ROMSEL_LO();

	//set lower address bits
	ADDRL(first);		//doing this prior to entry and right after latching
				//gives longest delay between address out and latching data

	for( i=0; i<=len; i++ ) {

		//genesis needed some extra NOPS
		NOP();
		NOP();
		NOP();
		NOP();
		NOP();
		NOP();
		NOP();
		NOP();
		
		//latch data high byte
		//data[i] = HDATA_VAL;

		//i++;

		//latch data low byte
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

void	gen_sst_flash_wr( uint16_t addr, uint16_t data )
{
	uint16_t rv;

	gen_flash_wr(0x5555, 0x00AA);
	gen_flash_wr(0x2AAA, 0x0055);
	gen_flash_wr(0x5555, 0x00A0);
	gen_flash_wr(addr, data);

	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();

	do {
		rv = gen_rom_rd(addr);
	//	usbPoll();	//orignal kazzo needs this frequently to slurp up incoming data
	} while (rv != gen_rom_rd(addr));

	return;
	
}

uint16_t gen_time_wr( uint16_t addr, uint16_t data )
{
	uint16_t rv;
	uint8_t temp;

	// set data bus as input
	DATA16_OP();
	DATA16L_SET(data);
	data = data >> 8;
	DATA16H_SET(data); //put 8bits of data on high byte

	// #AS B18  CPU access entire memory map, indicating address bus valid
	GBP_LO();

	// clear #WE/#UDSW B29  CPU D8-15 data strobe
	CSWR_LO();

	// clear #WE/#LDSW
	PRGRW_LO();

	// clear address, clear #TIME signal, set #LOMEM
	FFADDR_SET(0x04);
	ADDR_SET(addr);

	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	//6 above were working, trying more
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();
	// NOP();

	// set #WE/#LDSW
	PRGRW_HI();

	// set #WE/#UDSW B29  CPU D8-15 data strobe
	CSWR_HI();

	// set #TIME signal
	//FFADDR_SET(0x84);
	gen_set_bank(sega_bank);

	// #AS B18  CPU access entire memory map, indicating address bus valid
	GBP_HI();

	//Free data bus
	DATA16_IP();
}

void gen_page_ram_wr_lfsr(uint16_t addr, uint8_t data)
{
	uint16_t i;

	// get the first byte of data
	//data = lfsr_32();

	for (i = 0; i < 0x8000; i++)
	{
		// gen_ram_wr(addr, data);

		DATA_OP();
		ADDR_SET(addr);

		//put data on bus
		data = lfsr_32();
		DATA_SET(data); //lower byte D0-7

		//set #C_OE
		CSRD_HI();

		//clear #WE - #LDSW
		PRGRW_LO();

		//clear #C_CE
		ROMSEL_LO();

		NOP();
		NOP();
		NOP();
		NOP();
		NOP();
		NOP();
		
		//set #WE/#LDSW - latch data
		PRGRW_HI();

		//set #C_CE
		ROMSEL_HI();

		//Free data bus
		DATA_IP();

		// do some things that take time
		//data = lfsr_32();
		addr++;
	}

}

#endif //SEGA_CONN
