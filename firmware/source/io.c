#include "io.h"

#ifdef STM_CORE
uint8_t stm_debug_disable = 0;
#endif

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
 * Rtn: SUCCESS if opcode found, error if opcode not present or other problem.
 */
uint8_t io_call(uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata)
{
#define RD_LEN 0
#define RD0 1
#define RD1 2

#define BYTE_LEN 1
#define HWORD_LEN 2
	switch (opcode)
	{
	case IO_RESET:
#ifdef STM_CORE
		// operand sets whether to disable SWCLK/SWDIO on subequent io_reset calls
		stm_debug_disable = operand;
#endif
		io_reset();
		break;
#ifdef NES_CONN
	case NES_INIT:
		nes_init();
		break;
#endif
#ifdef SNES_CONN
	case SNES_INIT:
		snes_init();
		break;
#endif
#ifdef GB_CONN
	case GB_POWER_3V:
		GBP_OP();
		GBP_3V();
		break;
	case GB_POWER_5V:
		GBP_OP();
		GBP_5V();
		break;
	case GAMEBOY_INIT:
		gameboy_init();
		break;
	case GBA_INIT:
		gba_init();
		break;
#endif
#ifdef SEGA_CONN
	case SEGA_INIT:
		sega_init();
		break;
#endif
#ifdef N64_CONN
	case N64_INIT:
		n64_init();
		break;
#endif
#ifdef STM_CORE
	case SWIM_INIT:
		return swim_init(operand);
		break;
#endif
	case JTAG_INIT:
		return jtag_init(operand);
		break;

	case EXP0_PULLUP_TEST:
		rdata[RD_LEN] = BYTE_LEN;
		rdata[RD0] = exp0_pullup_test();
		break;
	default:
		// opcode doesn't exist
		return ERR_UNKN_IO_OPCODE;
	}

	return SUCCESS;
}

// pullup as many cart pins as possible
// goal to be safe state for all hardware
// doesn't currently contain any checks to report error/success from
// this is intended to be the "reset" safest condition for the kazzo
void io_reset()
{

#ifdef STM_CORE
	// reset GPIO perif blocks to default state
	RCC->AHBRSTR |= (RCC_AHBRSTR_GPIOARST | RCC_AHBRSTR_GPIOBRST | RCC_AHBRSTR_GPIOCRST | RCC_AHBRSTR_GPIODRST | RCC_AHBRSTR_GPIOFRST);
	RCC->AHBRSTR &= ~(RCC_AHBRSTR_GPIOARST | RCC_AHBRSTR_GPIOBRST | RCC_AHBRSTR_GPIOCRST | RCC_AHBRSTR_GPIODRST | RCC_AHBRSTR_GPIOFRST);
#endif

	// enable the GPIO blocks before can access them
	CTL_ENABLE();

#ifdef STM_CORE
	if (stm_debug_disable == DISABLE_STM_DEBUG)
	{
		// make the SWC/SWD pins like other GPIO
		GPIOA->MODER = 0;
		GPIOA->OSPEEDR = 0;
		GPIOA->PUPDR = 0;
	}
#endif

#ifndef C16nodef
	// First set gameboy/GBA power, default to 3v (safe for both)
	// pull up the GB power control pin
	// prevents conflicts, but also pulls up the
	// Pmosfet gate which turns off the mosfet
	// leaving the 3v power diode to supply the gameboy cart
	GBP_IP_PU();
	// If there's a load on the gameboy cart power there will be ~3v present.
	// If no load/cart, the voltage will will float up to 5v because of Rds_off of the mosfet.
#endif

	// pull up control port
	M2_IP_PU();
	ROMSEL_IP_PU();
	PRGRW_IP_PU();
	CSRD_IP_PU();
	CSWR_IP_PU();
	CICE_IP_PU();
	IRQ_IP_PU();
	CIA10_IP_PU();
#ifndef C3nodef
	FREE_IP_PU();
#endif

	// pull up on FF /OE should disable FF ouput
#ifndef C7nodef
	AHL_IP_PU();
#endif
#ifndef C13nodef
	EXP_DISABLE();
#endif
#ifndef C19nodef
	AFL_IP_PU();
#endif

	// EXP0 input no pullup
	// Lots of possibilities, ~safe bet it will have it's own pull-up/down if needed.
	// SNES /RESET pin disables SRAM on first few pcb versions
	// NES PRG-ROM /OE (with pulldown) on old INL-ROM v1 boards w/pulldown
	// NED PRG-ROM /WE (with pullup) on INL-ROM v3 boards w/pullup
	// NES CPLD JTAG TDO non-5v tolerant
	// Famicom carts have APU sound (EXP6) shorted to RF sound (EXP0)
	//	-enabling EXP FF output will drive EXP0 to value of A21/EXP6
	EXP0_IP_FL();

	// pull up addr[7:0] bus
	ADDR_ENABLE();
	ADDR_IP();
	ADDR_PU();

	// pull up data bus
	DATA_ENABLE();
	DATA_IP_PU();

	// LED LAST displaying complete..
	// planning to have LED DIM at power on to signify kazzo is in default
	// mostly all pins pulled up state.
	// gives some insight to current state of kazzo since it doesn't reset itself
	// or if kazzo does reset itself due to WDT dim LED can help detect that.
	LED_IP_PU(); // DIM pulled up
}

// NES cartridge interfacing setup
// set outputs as required
// latch address of $0000
// disable NES cart memories
#ifdef NES_CONN
void nes_init()
{
	// start with a reset
	// expecting user to do this but just to be sure
	io_reset();

	// enable control outputs and disable memories
	// PRG-ROM
	ROMSEL_HI();
	ROMSEL_OP();
	// WRAM (and state of m2 during first half of CPU cycle)
	M2_LO();
	M2_OP();
	// CPU RD
	PRGRW_HI();
	PRGRW_OP();

	// other control pins are inputs, leave as IP pullup from reset

	// disable any CHR/VRAM memories with CHR /RD /WR
	// prior to setting PPU A13 & /A13 which are /CE pins
	// doing this helps ensure data bus is clear before
	// using it for AHL clocking
	CSRD_HI();
	CSRD_OP();
	CSWR_HI();
	CSWR_OP();

	// memories are now disabled Data bus should be clear
	DATA_ENABLE();
	DATA_IP_PU();

	// now meet conditions to call other macros
	// setup address $0000
	ADDR_ENABLE();
	ADDR_SET(0x0000);
}
#endif

// SNES cartridge interfacing setup
// set outputs as required
// latch address of $00:0000
// disable cart memories
// reset high disables SRAM and puts INL carts in PRGM mode
// Excersize caution calling this while NES/FC cart inserted on old kazzo versions
// probably won't work if FC inserted due to EXP0-EXP6 short due to audio jumper on cart
#ifdef SNES_CONN
void snes_init()
{
	// start with a reset
	// expecting user to do this but just to be sure
	io_reset();

	// enable control outputs and disable memories
	// ROM
	ROMSEL_OP();
	ROMSEL_HI();
	CSRD_OP();
	CSRD_HI();
	CSWR_OP();
	CSWR_HI();

	// disable SRAM and put cart in PLAY mode
	EXP0_HI();
	EXP0_OP();
	// if SWIM is active, EXP0 must be set to pullup prior to SWIM transfers

	// other control pins are inputs or unused, leave as IP pullup from reset

	// memories are now disabled Data bus should be clear
	DATA_ENABLE();
	DATA_IP_PU();

	// now meet conditions to call other macros
	// setup address $0000
	ADDR_ENABLE();
	ADDR_SET(0x0000);

	// setup HIGH ADDR with bank $00
	HADDR_ENABLE();
	HADDR_SET(0x00);
}
#endif

// GAMEBOY cartridge interfacing setup
// set outputs as required
// latch address of $0000
// disable cart memories
#ifdef GB_CONN
void gameboy_init()
{
	// start with a reset
	// expecting user to do this but just to be sure
	io_reset();

	// enable control outputs and disable memories
	// ROM-RAM
	ROMSEL_OP();
	ROMSEL_HI(); // gameboy pin 5 "SRAM /CS"
	CSRD_OP();
	CSRD_HI(); // gameboy pin 4 /RD
	CSWR_OP();
	CSWR_HI(); // gameboy pin 3 /WR

	// Set #RESET pin low
	EXP0_OP();
	EXP0_HI(); // gameboy pin 30 "GAMEBOY /RESET" (GBA /CS2)

	// AUDIO IN (from cart) gameboy pin 31
	// if the cart generates audio it will drive this pin
	// this pin is also used for ROM /WE on some carts
	// such carts should have a pullup on this pin though..
	// use "AUDR" ctl pin to access this pin
	CTL_IP_FL(AUDRbank, AUDR);

	// CLK is a 1MHz signal from the gameboy
	// INL6 connects this to GPIO PA8, haven't even assigned this in pinport yet..
	// don't think any carts even need it though..
	// This is also the MCO pin from the STM32

	// other control pins are inputs or unused, leave as IP pullup from reset

	// memories are now disabled Data bus should be clear
	DATA_ENABLE();
	DATA_IP_PU();

	// now meet conditions to call other macros
	// setup address $0000
	ADDR_ENABLE();
	ADDR_SET(0x0000);

	// want to control this separately
	// #ifndef C16nodef
	//	//set GB/GBA power to 5v
	//	GBP_OP();
	//	GBP_5V();
	// #endif
}
#endif

// GBA cartridge interfacing setup
// set outputs as required
// latch address of $0000
// disable cart memories
#ifdef GB_CONN
void gba_init()
{
	// start with a reset
	// expecting user to do this but just to be sure
	// this also sets power to 3v
	io_reset();

	// enable control outputs and disable memories
	// ROM-RAM
	ROMSEL_OP();
	ROMSEL_HI(); // gameboy pin 5 ADDRESS LATCH
	CSRD_OP();
	CSRD_HI(); // gameboy pin 4 /RD
	CSWR_OP();
	CSWR_HI(); // gameboy pin 3 /WR

	// Set #RESET pin low
	EXP0_LO();
	EXP0_HI(); // gameboy pin 30 "GAMEBOY /RESET" (GBA /CS2)

	// other control pins are inputs or unused, leave as IP pullup from reset

	// memories are now disabled Data bus should be clear
	DATA_ENABLE();
	DATA_IP_PU();

	// now meet conditions to call other macros
	ADDR_ENABLE();		// turns on GPIO block & sets to output
	ADDR_IP();				// ad0-15 input
	ADDR_PU();				// ad0-15 pullup
	ADDR_SET(0x0000); // output set to zero, but won't take effect until outputed

	// All AD0-15 & D0-7 are bidir pins, don't drive them until ready

	// default is 3v on gameboy/GBA port
}
#endif

// SEGA Genesis/MegaDrive cartridge interfacing setup
// set outputs as required
// latch address of $00:0000
// disable cart memories
#ifdef SEGA_CONN
void sega_init()
{
	// start with a reset
	// expecting user to do this but just to be sure
	io_reset();

	// enable control outputs and disable memories

	// CONSOLE OUTPUTS:
	// #C_CE B17  CPU access $00_0000 - 03_FFFF 4MByte cart space
	// 		address decode depends on #CART
	// 		cart normally drives low (00-03),
	// 		but if driven high (like CD sram cart) decodes to $04_0000 - 07_FFFF
	GEN_C_CE_OP();
	GEN_C_CE_HI();

	// #C_OE B16  CPU access $00_0000 - 0D_FFFF entire 68k map except bank 0E-FF (64K RAM)
	GEN_C_OE_OP();
	GEN_C_OE_HI();

	// #AS B18  CPU access entire memory map, indicating address bus valid
	// TODO create another macro over the top of this..
	GBP_OP();
	GBP_HI();

	// #LO_MEM B26 CPU access $00_0000 - 07_FFFF 8MByte cart space
	// TODO FF2

	// #RESET (aka vRES) B27  resets cart logic, stays low in SMS mode
	EXP0_OP();
	EXP0_HI();

	// #LDSW B28  CPU D0-7 data strobe
	GEN_LDSW_OP();
	GEN_LDSW_HI();

	// #UDSW B29  CPU D8-15 data strobe
	GEN_UDSW_OP();
	GEN_UDSW_HI();

	// #TIME B31  CPU access $A1_3000 - A1_30FF "SSF2 mapper" uses this to decode mapper register writes
	// TODO FF7

	// CLK B19 7Mhz clock?
	// HS_CLK B15 13/53Mhz clock?
	// TODO PA8 both clock pins are wired to this mcu pin

	// #CAS B21 when CPU is halted, pulses at 60Khz probably refreshing some DRAM..
	// 	mcu ties with CPU A1 (address)
	//
	// VIDEO B12 non-NTSC EGA?
	// 	mcu ties with CPU A3 (address)
	//
	// Vsync B13 60Khz?
	// 	mcu ties with CPU A2 (address)
	//
	// Hsync B14 16Khz?
	// 	mcu ties with AFL (for A17+ flipflop clk/oen)

	// CONSOLE INPUTS:
	// #H_RESET B2 (aka nMRES)  console input, causes a hard reset, like what happens at power up
	// 		enables the OS rom which verifies "SEGA" present
	//
	// #S_RESET B30 (aka SEL0) console input, causes a soft reset, like pressing reset on the console
	// 		SMS power adapter grounds this pin
	// TODO SWCLK PA14
	//
	// #CART_IN B32 controls the address mapping of #C_CE, most carts ground this pin, CD ram adapter ties VCC
	// TODO PD2 (COUT)
	//
	// SOUND_LEFT B1 cart audio output
	// TODO ADC IN PA4 (AUDL)
	//
	// SOUND_RIGHT B3 cart audio output
	// TODO ADC IN PA5 (AUDR)

	// CONSOLE BIDIR:
	// #DTACK B20 bidirectional indicates end of data transfer, think the CPU stalls till memory drives
	// 		for non-cart space (wired to mcu pin PA13 (SWDIO)

	// now meet conditions to call other macros
	// setup address $00_0000
	ADDR_ENABLE(); // A1-16

	// behind AFL
	FFADDR_ENABLE();
	// bit 7 ... bit 0
	// #TIME, A23, A22, A21, A20, #LO_MEM, A18, A17
	// 0b1000_0100	#TIME and #LO_MEM high
// TODO put those defines in pinport?
#define LOMEM_TIME_MASK 0x84
#define LOMEM_MASK 0x04 // B26 /ASEL
#define TIME_MASK 0x80  // B31 /TIME
	FFADDR_SET(LOMEM_TIME_MASK); // corrupts A1-16

	// A1-16
	ADDR_SET(0x0000);

	// A19 (pin B7) SMS power adapter drives this pin for #IORQ
	GEN_A19_OP();
	GEN_A19_LO(); // A19 low

	// memories are now disabled Data bus should be clear

	//	// SEGA D0-7
	//	DATA_ENABLE();
	//	DATA_IP_PU();
	//
	//	//SEGA D8-15
	//	HADDR_ENABLE();
	//	HADDR_IP();
	//	HADDR_PU();
	DATA16_ENABLE();
	//	DATA16_IP();
	//	DATA16_PU();
}
#endif

// N64 cartridge interfacing setup
// set outputs as required
// latch address of $0000
// disable cart memories
#ifdef N64_CONN
void n64_init()
{
	// start with a reset
	// expecting user to do this but just to be sure
	// this also sets power to 3v
	io_reset();

	// enable control outputs and disable memories
	// ROM-RAM

	// ALE_L
	ALE_L_OP(); // ROMSEL_OP();
	ALE_L_HI(); // ROMSEL_HI();

	// ALE_H
	ALE_H_OP(); // PRGRW_OP();
	ALE_H_OP(); // PRGRW_HI();

	// RD
	CSRD_OP();
	CSRD_HI();

	// WR
	CSWR_OP();
	CSWR_HI();

	// COLD #RESET
	EXP0_OP();
	EXP0_HI();

	// TODO
	// 1.6Mhz clock -> D4 (PB12)
	// S_DAT -> D5 (PB13)
	// CIC_D2 -> D14 (PA9)
	// JTAG_CLK_44 -> D15 (PA10)
	// BLANK 14 & 39 -> D9/D10 (PB3/4)
	// CIC_D1 -> D11 (PB5)
	// VIDEO_CLK_46 -> D12 (PB6)
	// OS_EVENT -> D13 (PB7)
	//
	//  SOUND_LEFT
	//  TODO ADC IN PA4 (AUDL)
	//
	//  SOUND_RIGHT
	//  TODO ADC IN PA5 (AUDR)

	// AD0-15 leave as input pullup
	ADDR_ENABLE();		// turns on GPIO block & sets to output
	ADDR_IP();				// ad0-15 input
	ADDR_PU();				// ad0-15 pullup
	ADDR_SET(0x0000); // output set to zero, but won't take effect until outputed
}
#endif

// Initialization of SWIM "single wire interface module" communications
// the SWIM pin depends on INL board design.
// dict call must provide the "swim_lane"
// that swim lane will be used for all subsequent communications.
// TODO setup to control SWIM pin as (psuedo) open drain.
// if swim lane is unknown or other problem return error, else return SUCCESS
#ifdef STM_CORE
uint8_t swim_init(uint8_t swim_lane)
{
	switch (swim_lane)
	{
	case SWIM_ON_A0: // Most NES & Famicom carts
		// Enable A0 pin on EXT PORT
		EXT_A0_ENABLE();
		// set A0 to open drain with pull-up enabled
		A0_IP_PU();
#ifdef STM_CORE
		A0_OD(); // set type to open drain
		A0_HI(); // set output high (deasserted)
		A0_OP(); // enable as output to have above take effect
#endif
		swim_pin = A0;
		swim_base = A0bank;
		// swim_mask = 1<<A0;
		// set set as output high
		// define the swim pin, base, & mask
		break;
	case SWIM_ON_EXP0: // SNES carts
		// set to define used by shared_dict_pinport.h
		// that way we can call pinport_call(opcode, null, swim_pin, null)
		CTL_ENABLE();
		EXP0_IP_PU(); // this enables pullup for stm
#ifdef STM_CORE
		EXP0_OD(); // set type to open drain
		EXP0_HI(); // set output high (deasserted)
		EXP0_OP(); // enable as output to have above take effect
#endif
		swim_pin = EXP0;
		swim_base = EXP0bank;
		// swim_mask = 1<<EXP0;
		break;
	case SWIM_ON_D0: // NES/FC carts with CICOprocesor
		break;
	default:
		return ERR_UNKN_SWIM_LANE;
	}
	return SUCCESS;
}
#endif

// Initialization of JTAG communications
// the JTAG pin depends on INL board design.
// dict call must provide the "jtag_lane"
// that jtag lane will be used for all subsequent communications.
// if jtag lane is unknown or other problem return error, else return SUCCESS
uint8_t jtag_init(uint8_t jtag_lane)
{
	switch (jtag_lane)
	{
	case JTAG_ON_EXP0_3: // Most NES carts

#ifdef STM_INL6
											 // set base & masks
		tdo_base = EXP0bank;
		tdo_pin = EXP0;
		tdi_base = D8bank;
		tdi_pin = D8;
		tms_base = D9bank;
		tms_pin = D9;
		tck_base = D10bank;
		tck_pin = D10;
#else
#endif

		// enable GPIO banks
		// EXT_D8_10_ENABLE();	//EXP0 is also on this GPIO bank
		EXP_ENABLE();
		CTL_ENABLE(); // not really needed..

		// initialize PBJE
		jtag_init_pbje();
		break;

	case JTAG_ON_SNES_CTL: // SNES v2.0proto2 SYSCLK-TCK, RESET/EXP0-TMS, WR-TDI, RD-TDO

#ifdef STM_INL6
												 // set base & masks
		tdo_base = CSRDbank;
		tdo_pin = CSRD;
		tdi_base = CSWRbank;
		tdi_pin = CSWR;
		tms_base = EXP0bank;
		tms_pin = EXP0;
		tck_base = PRGRWbank; // TODO make better ctl pin definition for this pin!
		tck_pin = PRGRW;
#else
												 // TODO
#endif

		// enable GPIO banks
		// EXP_ENABLE();
		CTL_ENABLE(); // SYSCLK done..?

		break;
	default:
		return ERR_UNKN_JTAG_LANE;
	}

	// initialize PBJE
	jtag_init_pbje();

	return SUCCESS;
}

// Test starts by verifying EXP0 can be driven low, if not, will return one byte of AUX_PIN
// followed by alternating 0xAA, 0x55, 0xAA...
// This test pulls up EXP0 and then reads AUX_PIN 6 times in rapid succession returning error code
// plus 6 bytes of read data.  If pull up works but is just slow, should see that in return data.
// data[0] marks bit where EXP0 resisdes to provide host with bitmask for EXP0
uint8_t exp0_pullup_test()
{
	uint16_t temp0, temp1, temp2, temp3, temp4, temp5;

	// first verify EXP0 can be driven low
	EXP0_LO(); // sets O/P and low
	EXP0_OP();
	NOP(); // give some time to settle

	EXP0_RD(temp0);
	// data[1] = AUX_IN;	//port where EXP0 resides
	EXP0_IP_FL(); // sets I/P w/o pullup

	// if ( (data[1] & data[0]) == data[0]) {
	if (temp0)
	{
		// EXP0 was high, couldn't drive EXP0 low
		// data[2] = data[4] = data[6] = 0xAA;
		// data[3] = data[5] = 0x55;
		// return this signature as indication EXP0 failed to drive low
		return EXP0_STUCK_HI;
	}

	// Driving EXP0 low was successful, now pullup and read back
	EXP0_IP_PU();
	EXP0_RD(temp0);
	EXP0_RD(temp1);
	NOP();
	EXP0_RD(temp2); // 3cycles
	NOP();
	NOP();
	EXP0_RD(temp3); // 6cycles
	NOP();
	NOP();
	NOP();
	EXP0_RD(temp4); // 10cycles
	NOP();
	NOP();
	NOP();
	NOP();
	EXP0_RD(temp5); // 15cycles

	// return EXP0 to floating
	EXP0_IP_FL();

	// return the number of cycles it took for EXP0 to go high
	if (temp0)
		return 0;
	if (temp1)
		return 1;
	if (temp2)
		return 3;
	if (temp3)
		return 6;
	if (temp4)
		return 10;
	if (temp5)
		return 15;
	else
		return CANNOT_PULLUP_EXP0;
}
