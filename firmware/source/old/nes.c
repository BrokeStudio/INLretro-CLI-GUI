#include "nes.h"

//=================================================================================================
//
//	NES operations
//	This file includes all the nes functions possible to be called from the nes dictionary.
//
//	See description of the commands contained here in shared/shared_dictionaries.h
//
//=================================================================================================

/* Desc:Function takes an opcode which was transmitted via USB
 * 	then decodes it to call designated function.
 * 	shared_dict_nes.h is used in both host and fw to ensure opcodes/names align
 * Pre: Macros must be defined in firmware pinport.h
 * 	opcode must be defined in shared_dict_nes.h
 * Post:function call complete.
 * Rtn: SUCCESS if opcode found, ERR_UNKN_NES_OPCODE_24BOP if opcode not present.
 */
uint8_t nes_opcode_24b_operand( uint8_t opcode, uint8_t addrH, uint8_t addrL, uint8_t data )
{
	switch (opcode) { 
		case DISCRETE_EXP0_PRGROM_WR:	
			discrete_exp0_prgrom_wr( addrH, addrL, data );
			break;
		case NES_PPU_WR:	
			nes_ppu_wr( addrH, addrL, data );
			break;
		case NES_CPU_WR:	
			nes_cpu_wr( addrH, addrL, data );
			break;
		default:
			 //macro doesn't exist
			 return ERR_UNKN_NES_OPCODE_24BOP;
	}
	
	return SUCCESS;

}


/* Desc:Function takes an opcode which was transmitted via USB
 * 	then decodes it to call designated function.
 * 	shared_dict_nes.h is used in both host and fw to ensure opcodes/names align
 * Pre: Macros must be defined in firmware pinport.h
 * 	opcode must be defined in shared_dict_nes.h
 * Post:pointer to data updated with return value.
 * Rtn: SUCCESS if opcode found, ERR_UNKN_NES_OPCODE_16BOP_8BRV if opcode not present.
 */
uint8_t nes_opcode_16b_operand_8b_return( uint8_t opcode, uint8_t addrH, uint8_t addrL, uint8_t *data )
{
	switch (opcode) { 
		case EMULATE_NES_CPU_RD:
			*data = emulate_nes_cpu_rd( addrH, addrL );
			break;
		case NES_CPU_RD:
			*data = nes_cpu_rd( addrH, addrL );
			break;
		case NES_PPU_RD:
			*data = nes_ppu_rd( addrH, addrL );
			break;
		case CIRAM_A10_MIRROR:
			*data = ciram_a10_mirroring( );
			break;
		default:
			 //macro doesn't exist
			 return ERR_UNKN_NES_OPCODE_16BOP_8BRV;
	}
	
	return SUCCESS;

}

/* Desc: Discrete board PRG-ROM only write, does not write to mapper
 * 	PRG-ROM /WE <- EXP0 w/PU
 * 	PRG-ROM /OE <- /ROMSEL
 * 	PRG-ROM /CE <- GND
 * 	PRG-ROM write: /WE & /CE low, /OE high
 * 	mapper '161 CLK  <- /ROMSEL
 * 	mapper '161 /LOAD <- PRG R/W
 * 	mapper '161 /LOAD must be low on rising edge of CLK to latch data
 * 	This is a /WE controlled write. Address latched on falling edge, 
 *	and data latched on rising edge EXP0
 * Note:addrH bit7 has no effect (ends up on PPU /A13)
 * 	/ROMSEL, M2, & PRG R/W signals untouched
 * Pre: nes_init() setup of io pins
 * Post:data latched by PRG-ROM, mapper register unaffected
 * 	address left on bus
 * 	data left on bus, but pullup only
 * 	EXP0 left pulled up
 * Rtn:	None
 */
void	discrete_exp0_prgrom_wr( uint8_t addrH, uint8_t addrL, uint8_t data )
{
	_DATA_OP();
	DATA_OUT = addrH;
	_AHL_CLK();	//addrH latched
	ADDR_OUT = addrL;
	DATA_OUT = data;
	_EXP0_LO();	//Tas = 0ns, Tah = 30ns
	_EXP0_PU();	//Twp = 40ns, Tds = 40ns, Tdh = 0ns
	//16Mhz avr clk = 62.5ns period guarantees timing reqts
	_DATA_IP();
}


/* Desc:Emulate NES CPU Read as best possible
 * 	decode A15 from addrH to set /ROMSEL as expected
 * 	float EXP0
 * 	toggle M2 as NES would
 * 	insert some NOP's in to be slow like NES
 * Note:not the fastest read operation
 * Pre: nes_init() setup of io pins
 * Post:address left on bus
 * 	data bus left clear
 * 	EXP0 left floating
 * Rtn:	Byte read from PRG-ROM at addrHL
 */
uint8_t	emulate_nes_cpu_rd( uint8_t addrH, uint8_t addrL )
{
	uint8_t	read;	//return value

	//m2 should be low as it aids in disabling WRAM
	//this is also m2 state at beginging of CPU cycle
	//all these pins should already be in this state, but
	//go ahead and setup just to be sure since we're trying
	//to be as accurate as possible
	_EXP0_FLT();	//this could have been left pulled up
	_M2_LO();	//start of CPU cycle
	_ROMSEL_HI();	//trails M2
	_PRGRW_RD();	//happens just after M2

	//set address bus
	ADDR_OUT = addrL;
	_ADDRH_SET(addrH);
	
	//couple NOP's to wait a bit
	NOP();
	NOP();

	//set M2 and /ROMSEL
	if( addrH >= 0x80 ) {	//addressing cart rom space
		_M2_HI();	
		_ROMSEL_LO();	//romsel trails M2 during CPU operations
	} else {
		_M2_HI();
	}

	//couple more NOP's waiting for data
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();
	NOP();

	//latch data
	read = DATA_IN;

	//return bus to default
	_M2_LO();
	_ROMSEL_HI();
	
	return read;
}

/* Desc:NES CPU Read without being so slow
 * 	decode A15 from addrH to set /ROMSEL as expected
 * 	float EXP0
 * 	toggle M2 as NES would
 * Pre: nes_init() setup of io pins
 * Post:address left on bus
 * 	data bus left clear
 * 	EXP0 left floating
 * Rtn:	Byte read from PRG-ROM at addrHL
 */
uint8_t	nes_cpu_rd( uint8_t addrH, uint8_t addrL )
{
	uint8_t	read;	//return value

	//set address bus
	ADDR_OUT = addrL;
	_ADDRH_SET(addrH);
	
	//set M2 and /ROMSEL
	_M2_HI();
	if( addrH >= 0x80 ) {	//addressing cart rom space
		_ROMSEL_LO();	//romsel trails M2 during CPU operations
	}

	//couple more NOP's waiting for data
	//zero nop's returned previous databus value
	NOP();	//one nop got most of the bits right
	NOP();	//two nop got all the bits right
	NOP();	//add third nop for some extra
	NOP();	//one more can't hurt
	//might need to wait longer for some carts...

	//latch data
	read = DATA_IN;

	//return bus to default
	_M2_LO();
	_ROMSEL_HI();
	
	return read;
}

/* Desc:NES CPU Write
 *	Just as you would expect NES's CPU to perform
 *	A15 decoded to enable /ROMSEL
 *	This ends up as a M2 and/or /ROMSEL controlled write
 * Note:addrH bit7 has no effect (ends up on PPU /A13)
 *	EXP0 floating
 * Pre: nes_init() setup of io pins
 * Post:data latched by anything listening on the bus
 * 	address left on bus
 * 	data left on bus, but pullup only
 * Rtn:	None
 */
void	nes_cpu_wr( uint8_t addrH, uint8_t addrL, uint8_t data )
{
	//Float EXP0 as it should be in NES
	_EXP0_FLT();

	//need for whole function
	_DATA_OP();

	//set addrL
	ADDR_OUT = addrL;
	//latch addrH
	DATA_OUT = addrH;
	_AHL_CLK();	

	//PRG R/W LO
	_PRGRW_WR();

	//put data on bus
	DATA_OUT = data;

	//set M2 and /ROMSEL
	_M2_HI();
	if( addrH >= 0x80 ) {	//addressing cart rom space
		_ROMSEL_LO();	//romsel trails M2 during CPU operations
	}

	//give some time
	NOP();
	NOP();

	//latch data to cart memory/mapper
	_M2_LO();
	_ROMSEL_HI();

	//retore PRG R/W to default
	_PRGRW_RD();

	//Free data bus
	_DATA_IP();
}

/* Desc:NES PPU Read 
 * 	decode A13 from addrH to set /A13 as expected
 * Pre: nes_init() setup of io pins
 * Post:address left on bus
 * 	data bus left clear
 * Rtn:	Byte read from CHR-ROM/RAM at addrHL
 */
uint8_t	nes_ppu_rd( uint8_t addrH, uint8_t addrL )
{
	uint8_t	read;	//return value

	if (addrH < 0x20) { //below $2000 A13 clear, /A13 set
		_ADDRH_SET(addrH | PPU_A13N);
	} else { //above PPU $1FFF, A13 set, /A13 clear 
		_ADDRH_SET(addrH);
	}

	//set address bus
	ADDR_OUT = addrL;
	
	//set CHR /RD and /WR
	_CSRD_LO();
	//_CSWR_HI();	already done

	//couple more NOP's waiting for data
	//zero nop's returned previous databus value
	NOP();	//one nop got most of the bits right
	NOP();	//two nop got all the bits right
	NOP();	//add third nop for some extra
	NOP();	//one more can't hurt
	//might need to wait longer for some carts...

	//latch data
	read = DATA_IN;

	//return bus to default
	_CSRD_HI();
	
	return read;
}

/* Desc:NES PPU Write 
 * 	decode A13 from addrH to set /A13 as expected
 *	flash: address clocked falling edge, data rising edge of /WE
 * Pre: nes_init() setup of io pins
 * Post:data written to addrHL
 *	address left on bus
 * 	data bus left clear
 * Rtn:	None
 */
void	nes_ppu_wr( uint8_t addrH, uint8_t addrL, uint8_t data )
{
	//will need output whole function
	_DATA_OP();

	//addrH with PPU /A13
	if (addrH < 0x20) { //below $2000 A13 clear, /A13 set
		DATA_OUT = (addrH | PPU_A13N);
	} else { //above PPU $1FFF, A13 set, /A13 clear 
		DATA_OUT = addrH;
	}
	//latch addrH
	_AHL_CLK();

	//set address bus
	ADDR_OUT = addrL;

	//put data on bus
	DATA_OUT = data;

	NOP();
	
	//set CHR /RD and /WR
	//_CSRD_HI();	already done
	_CSWR_LO();

	//might need to wait longer for some carts...
	NOP();	//one can't hurt

	//latch data to memory
	_CSWR_HI();

	//clear data bus
	_DATA_IP();
	
}


/* Desc:PPU CIRAM A10 NT arrangement sense
 *	Toggle A11 and A10 and read back CIRAM A10
 *	report back if vert/horiz/1scnA/1scnB
 *	reports nesdev defined mirroring
 *	does not report Nintendo's "Name Table Arrangement"
 * Pre: nes_init() setup of io pins
 * Post:address left on bus
 * Rtn:	MIR_VERT, MIR_HORIZ, MIR_1SCNA, MIR_1SCNB
 *	errors not really possible since all combinations
 *	of CIRAM A10 level designate something valid
 */
uint8_t	ciram_a10_mirroring( void )
{
	uint8_t readV, readH;

	//will need output majority of function
	_DATA_OP();

	//set A10, clear A11
	DATA_OUT = A10;
	_AHL_CLK();
	readV = AUX_IN & (1<<CIA10);

	//set A11, clear A10
	DATA_OUT = A11;
	_AHL_CLK();
	readH = AUX_IN & (1<<CIA10);

	//return data bus clear
	_DATA_IP();

	//if CIRAM A10 was always low -> 1 screen A
	if ((readV==0) & (readH==0))	return MIR_1SCNA;
	//if CIRAM A10 was always hight -> 1screen B
	if ((readV!=0) & (readH!=0))	return MIR_1SCNB;
	//if CIRAM A10 toggled with A10 -> Vertical mirroring, horizontal arrangement
	if ((readV!=0) & (readH==0))	return MIR_VERT;
	//if CIRAM A10 toggled with A11 -> Horizontal mirroring, vertical arrangement
	if ((readV==0) & (readH!=0))	return MIR_HORIZ;

	//shouldn't be here...
	return UNKNOWN;
}

/* Desc:NES CPU Page Read with optional USB polling
 * 	decode A15 from addrH to set /ROMSEL as expected
 * 	float EXP0
 * 	toggle M2 as NES would
 *	if poll is true calls usbdrv.h usbPoll fuction
 *	this is needed to keep from timing out when double buffering usb data
 * Pre: nes_init() setup of io pins
 *	num_bytes can't exceed 256B page boundary
 * Post:address left on bus
 * 	data bus left clear
 * 	EXP0 left floating
 *	data buffer filled starting at first to last
 * Rtn:	Index of last byte read
 */
uint8_t nes_cpu_page_rd_poll( uint8_t *data, uint8_t addrH, uint8_t first, uint8_t len, uint8_t poll )
{
	uint8_t i;

	//set address bus
	_ADDRH_SET(addrH);
	
	//set M2 and /ROMSEL
	_M2_HI();
	if( addrH >= 0x80 ) {	//addressing cart rom space
		_ROMSEL_LO();	//romsel trails M2 during CPU operations
	}

	//set lower address bits
	ADDR_OUT = first;	//doing this prior to entry and right after latching
				//gives longest delay between address out and latching data
	for( i=0; i<=len; i++ ) {
		//testing shows that having this if statement doesn't affect overall dumping speed
		if ( poll == FALSE ) {
			NOP();	//couple more NOP's waiting for data
			NOP();	//one prob good enough considering the if/else
		} else {
			usbPoll();	//Call usbdrv.h usb polling while waiting for data
		}
		//latch data
		data[i] = DATA_IN;
		//set lower address bits
		ADDR_OUT = ++first;
	}

	//return bus to default
	_M2_LO();
	_ROMSEL_HI();
	
	//return index of last byte read
	return i;
}

/* Desc:NES PPU Page Read with optional USB polling
 * 	decode A13 from addrH to set /A13 as expected
 *	if poll is true calls usbdrv.h usbPoll fuction
 *	this is needed to keep from timing out when double buffering usb data
 * Pre: nes_init() setup of io pins
 *	num_bytes can't exceed 256B page boundary
 * Post:address left on bus
 * 	data bus left clear
 *	data buffer filled starting at first for len number of bytes
 * Rtn:	Index of last byte read
 */
uint8_t nes_ppu_page_rd_poll( uint8_t *data, uint8_t addrH, uint8_t first, uint8_t len, uint8_t poll )
{
	uint8_t i;

	if (addrH < 0x20) { //below $2000 A13 clear, /A13 set
		_ADDRH_SET(addrH | PPU_A13N);
	} else { //above PPU $1FFF, A13 set, /A13 clear 
		_ADDRH_SET(addrH);
	}

	//set CHR /RD and /WR
	_CSRD_LO();

	//set lower address bits
	ADDR_OUT = first;	//doing this prior to entry and right after latching
				//gives longest delay between address out and latching data
	for( i=0; i<=len; i++ ) {
		//couple more NOP's waiting for data
		if ( poll == FALSE ) {
			NOP();	//one prob good enough considering the if/else
			NOP();
		} else {
			usbPoll();
		}
		//latch data
		data[i] = DATA_IN;
		//set lower address bits
		ADDR_OUT = ++first;
	}

	//return bus to default
	_CSRD_HI();
	
	//return index of last byte read
	return i;
}
