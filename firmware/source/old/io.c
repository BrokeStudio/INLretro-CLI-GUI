#include "io.h"

//=================================================================================================
//
//	I/O operations
//	This file includes all the io functions possible to be called from the io dictionary.
//
//	See description of the commands contained here in shared/shared_dictionaries.h
//
//=================================================================================================

/* Desc:Function takes an opcode which was transmitted via USB
 * 	then decodes it to call designated function.
 * 	shared_dict_io.h is used in both host and fw to ensure opcodes/names align
 * Pre: Macros must be defined in firmware pinport.h
 * 	opcode must be defined in shared_dict_io.h
 * Post:function call complete.
 * Rtn: SUCCESS if opcode found, ERR_UNKN_IO_OPCODE_ONLY if opcode not present.
 */
uint8_t io_opcode_only( uint8_t opcode )
{
	switch (opcode) { 
		case IO_RESET:	io_reset();	break;
		case NES_INIT:	nes_init();	break;
		case SNES_INIT:	snes_init();	break;
		default:
			 //macro doesn't exist
			 return ERR_UNKN_IO_OPCODE_ONLY;
	}
	
	return SUCCESS;

}

/* Desc:Function takes an opcode which was transmitted via USB
 * 	then decodes it to call designated function.
 * 	shared_dict_io.h is used in both host and fw to ensure opcodes/names align
 * Pre: Macros must be defined in firmware pinport.h
 * 	opcode must be defined in shared_dict_io.h
 * Post:function call complete.
 * 	7bytes of return data are contained in *data pointer
 * Rtn: SUCCESS if opcode found, ERR_UNKN_IO_OPCODE_RTN if opcode not present.
 */
uint8_t io_opcode_return( uint8_t opcode, uint8_t *data )
{
	switch (opcode) { 
		case EXP0_PULLUP_TEST:	exp0_pullup_test(data);	break;
		default:
			 //macro doesn't exist
			 return ERR_UNKN_IO_OPCODE_RTN;
	}
	
	return SUCCESS;

}

//pullup as many cart pins as possible
//goal to be safe state for all hardware
//doesn't currently contain any checks to report error/success from
//this is intended to be the "reset" safest condition for the kazzo
void io_reset()
{
	//pull up addr[7:0] bus
	_ADDR_IP();
	_ADDR_HI();

	//pull up data bus
	_DATA_IP();
	_DATA_HI();

	//pull up control port
	_CTL_IP();
	_CTL_HI();

	//pull up aux port
	//Aux port contains EXP /OE control
	//pull up on EXP FF should disable FF ouput
	_AUX_IP();
	_AUX_HI();

	//EXP0 input no pullup
	//Lots of possibilities, ~safe bet it will have it's own pull-up/down if needed. 
	//SNES /RESET pin disables SRAM on first few pcb versions
	//NES PRG-ROM /OE (with pulldown) on old INL-ROM v1 boards w/pulldown
	//NED PRG-ROM /WE (with pullup) on INL-ROM v3 boards w/pullup
	//NES CPLD JTAG TDO non-5v tolerant
	//Famicom carts have APU sound (EXP6) shorted to RF sound (EXP0)
	//	-enabling EXP FF output will drive EXP0 to value of A21/EXP6
	_EXP0_FLT();

	//LED LAST displaying complete..
	//planning to have LED DIM at power on to signify kazzo is in default
	//mostly all pins pulled up state.
	//gives some insight to current state of kazzo since it doesn't reset itself
	//or if kazzo does reset itself due to WDT dim LED can help detect that.
	_LED_IP();	//DIM pulled up
	//_LED_OP();	//BRIGHT full power
	//boot with LED on/pulled up to differentiate bettwen BL/RUN
	_LED_ON();

}

//NES cartridge interfacing setup
//set outputs as required
//latch address of $0000
//disable NES cart memories
void nes_init() 
{
	//start with a reset
	//expecting user to do this but just to be sure
	io_reset();

	//enable control outputs and disable memories
	//PRG-ROM
	_ROMSEL_OP();
	_ROMSEL_HI();
	//WRAM (and state of m2 during first half of CPU cycle)
	_M2_OP();
	_M2_LO();
	//CPU RD
	_PRGRW_OP();
	_PRGRW_RD();

	//other control pins are inputs, leave as IP pullup from reset

	//disable any CHR/VRAM memories with CHR /RD /WR 
	//prior to setting PPU A13 & /A13 which are /CE pins
	//doing this helps ensure data bus is clear before 
	//using it for AHL clocking
	_CSRD_OP();
	_CSRD_HI();
	_CSWR_OP();
	_CSWR_HI();

	//memories are now disabled Data bus should be clear

	//setup AHL FF
	_AHL_OP();
	_AHL_CLK();

	//now meet conditions to call other macros
	//setup address $0000
	_ADDRH_SET(0x00);
	_ADDR_LO();

	//default state of ADDR[7:0]
	_ADDR_OP();

	//default state data bus pulled up
	_DATA_IP();
	_DATA_HI();

}


//SNES cartridge interfacing setup
//set outputs as required
//latch address of $000000
//disable cart memories
//reset high disables SRAM and puts INL carts in PRGM mode
//Excersize extreme caution calling this while NES/FC cart inserted
//probably won't work if FC inserted due to EXP0-EXP6 short due to audio jumper on cart
void snes_init() 
{
	//start with a reset
	//expecting user to do this but just to be sure
	io_reset();

	//enable control outputs and disable memories
	//ROM
	_ROMSEL_OP();
	_ROMSEL_HI();
	_CSRD_OP();
	_CSRD_HI();
	_CSWR_OP();
	_CSWR_HI();

	//disable SRAM and put cart in PRGM mode
	_SRST_OP();
	_SRST_HI();

	//other control pins are inputs or unused, leave as IP pullup from reset

	//memories are now disabled Data bus should be clear

	//setup AHL FF
	_AHL_OP();
	_AHL_CLK();
	//setup AXL FF
	_AXLOE_OP();
	_AXL_CLK();

	//now meet conditions to call other macros
	//setup address $000000
	_ADDRH_SET(0x00);
	_ADDRX_SET(0x00);
	_ADDR_LO();

	//default state of ADDR[7:0]
	_ADDR_OP();

	//default state data bus pulled up
	_DATA_IP();
	_DATA_HI();

}

//Test starts by verifying EXP0 can be driven low, if not, will return one byte of AUX_PIN
//followed by alternating 0xAA, 0x55, 0xAA...
//This test pulls up EXP0 and then reads AUX_PIN 6 times in rapid succession returning error code
//plus 6 bytes of read data.  If pull up works but is just slow, should see that in return data.
//data[0] marks bit where EXP0 resisdes to provide host with bitmask for EXP0
void	exp0_pullup_test(uint8_t *data)
{
	//provide host with bit mask of EXP0 for first byte
	data[0] = (1<<EXP0);

	//first verify EXP0 can be driven low
	_EXP0_LO();	//sets O/P and low
	NOP();		//give some time to settle
	data[1] = AUX_IN;	//port where EXP0 resides
	_EXP0_FLT();	//sets I/P w/o pullup

	if ( (data[1] & data[0]) == data[0]) {
		//EXP0 was high, couldn't drive EXP0 low
		data[2] = data[4] = data[6] = 0xAA;
		data[3] = data[5] = 0x55;
		//return this signature as indication EXP0 failed to drive low
		return;
	}

	//Driving EXP0 low was successful, now pullup and read back
	_EXP0_PU();
	data[1] = AUX_IN;
	data[2] = AUX_IN;
	data[3] = AUX_IN;
	data[4] = AUX_IN;
	data[5] = AUX_IN;
	data[6] = AUX_IN;

	//return EXP0 to floating
	_EXP0_FLT();

}
