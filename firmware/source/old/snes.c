#include "snes.h"

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
 * Rtn: SUCCESS if opcode found, ERR_UNKN_SNES_OPCODE_24BOP if opcode not present.
 */
uint8_t snes_opcode_24b_operand( uint8_t opcode, uint8_t addrH, uint8_t addrL, uint8_t data )
{
	switch (opcode) { 
		case SNES_A15_A0_PRGM_WR:	
			snes_a15_a0_wr( PRGM, ~FALSE, addrH, addrL, data );
			break;
		case SNES_A15_A0_PLAY_WR:	
			snes_a15_a0_wr( PLAY, ~FALSE, addrH, addrL, data );
			break;
		case SNES_A15_A0_NO_ROMSEL_PLAY_WR:	
			snes_a15_a0_wr( PLAY, FALSE, addrH, addrL, data );
			break;
		default:
			 //macro doesn't exist
			 return ERR_UNKN_SNES_OPCODE_24BOP;
	}
	
	return SUCCESS;

}


/* Desc:Function takes an opcode which was transmitted via USB
 * 	then decodes it to call designated function.
 * 	shared_dict_snes.h is used in both host and fw to ensure opcodes/names align
 * Pre: Macros must be defined in firmware pinport.h
 * 	opcode must be defined in shared_dict_snes.h
 * Post:pointer to data updated with return value.
 * Rtn: SUCCESS if opcode found, ERR_UNKN_SNES_OPCODE_24BOP_8BRV if opcode not present.
 */
uint8_t snes_opcode_24b_operand_8b_return( 
		uint8_t opcode, uint8_t addrX, uint8_t addrH, uint8_t addrL, uint8_t *data )
{
	switch (opcode) { 
		case SNES_PRGM_RD:
			*data = snes_a15_a0_rd( PRGM, ~FALSE, addrX, addrH, addrL );
			break;
		case SNES_PLAY_RD:
			*data = snes_a15_a0_rd( PLAY, ~FALSE, addrX, addrH, addrL );
			break;
		case SNES_NO_ROMSEL_PLAY_RD:
			*data = snes_a15_a0_rd( PLAY, FALSE, addrX, addrH, addrL );
			break;
		default:
			 //macro doesn't exist
			 return ERR_UNKN_SNES_OPCODE_24BOP_8BRV;
	}
	
	return SUCCESS;

}


/* Desc:SNES CPU Write in program and play mode
 *	only provide A15-0, A23-16 use last latched value
 *	Pass in mode= PRGM/PLAY to determine /RESET (EXP0)
 *	*in program mode:
 *		/RESET pin held low for PRGM mode
 *		SRAM not visibile
 *		INL boards rom aligned linearly doesn't rely on Hi/Lo switch
 *	*in play mode:
 *		/RESET pin held high for PRGM mode
 *		SRAM visibile
 *		all boards rom aligned based on mapping 
 *		INL board rely on Hi/Lo switch
 *	/ROMSEL goes low depending on passed in romsel variable
 *	SNES /WR controlled write (rom /WE pin)
 *	SYS CLK not affected
 * Pre: snes_init() setup of io pins
 *	No NES cart inserted without 5v tolerant EXP0 pin
 * Post:data written to ROM at addrHL
 * 	address left on bus
 * 	data bus left clear
 *	/RESET low, left in PRGM mode
 * Rtn:	None
 */
void	snes_a15_a0_wr( uint8_t mode, uint8_t romsel, uint8_t addrH, uint8_t addrL, uint8_t data )
{
	//EXP0 default low to disable SRAM aiding in bus clearing
	if (mode == PLAY) {
		_SRST_HI();
	} else {
		_SRST_LO();	//go ahead and set to be safe
	}

	//need for whole function
	_DATA_OP();

	//set addrL
	ADDR_OUT = addrL;
	//latch addrH
	DATA_OUT = addrH;
	_AHL_CLK();	

	//put data on bus
	DATA_OUT = data;

	//let higher level function/caller decide if /ROMSEL is active
	if ( romsel == ~FALSE ) {
		_ROMSEL_LO();
	}

	//set SNES /RD and /WR
	//_CSRD_HI();	already done
	_CSWR_LO();

	//give some time
	NOP();
	NOP();

	//latch data to cart 
	_CSWR_HI();
	_ROMSEL_HI();

	//Free data bus
	_DATA_IP();
	//default mode
	_SRST_LO();
}


/* Desc:SNES CPU Read in program and play mode
 *	entire 24bit address bus provided
 *	Pass in mode= PRGM/PLAY to determine /RESET (EXP0)
 *	*in program mode:
 *		/RESET pin held low for PRGM mode
 *		SRAM not visibile
 *		INL boards rom aligned linearly doesn't rely on Hi/Lo switch
 *	*in play mode:
 *		/RESET pin held high for PRGM mode
 *		SRAM visibile
 *		all boards rom aligned based on mapping 
 *		INL board rely on Hi/Lo switch
 *	/ROMSEL goes low depending on passed in romsel variable
 *	SNES /RD controlled read (rom /OE pin)
 *	SYS CLK not affected
 * Pre: snes_init() setup of io pins
 *	No NES cart inserted without 5v tolerant EXP0 pin
 * Post:address left on bus
 * 	data bus left clear
 *	/RESET low, left in PRGM mode
 * Rtn:	Byte read from cart at addrXHL
 */
uint8_t	snes_a15_a0_rd( uint8_t mode, uint8_t romsel, uint8_t addrX, uint8_t addrH, uint8_t addrL )
{
	uint8_t	read;	//return value

	//EXP0 default low to disable SRAM aiding in bus clearing
	if (mode == PLAY) {
		_SRST_HI();
	} else {
		_SRST_LO();	//go ahead and set to be safe
	}

	//need for address latching
	_DATA_OP();

	//set addrL
	ADDR_OUT = addrL;
	//latch addrH
	DATA_OUT = addrH;
	_AHL_CLK();	
	//latch addrX
	DATA_OUT = addrX;
	_AXL_CLK();	

	//clear bus
	_DATA_IP();	

	//let higher level function/caller decide if /ROMSEL is active
	if ( romsel == ~FALSE ) {
		_ROMSEL_LO();
	}

	//set SNES /RD and /WR
	_CSRD_LO();	
	//_CSWR_HI();	already done

	//give some time
	NOP();
	NOP();
	NOP();
	NOP();

	//latch data from cart 
	read = DATA_IN;
	
	//Free data bus
	_CSRD_HI();
	_ROMSEL_HI();

	//default mode
	_SRST_LO();

	return read;
}

