#ifndef _pinport_al_h
#define _pinport_al_h

//Define the board type in makefile
//#define AVR_KAZZO
//#define STM_ADAPTER
//#define STM_INL6_PROTO
//#define STM_INL6
//#define STM_NES

//define the connectors present on each device
//these are used to exclude unecessary code from devices which don't have the connectors present
#if defined(AVR_KAZZO) || defined(STM_ADAPTER)
  #define NES_CONN //includes famicom as definitions are effectively the same
  #define SNES_CONN
#endif

#ifdef STM_NES
  #define NES_CONN //famicom isn't actually present but a pin adapter should work
#endif

//#if defined(STM_INL6) || defined(STM_INL6_PROTO)
#if defined(STM_INL6)
  #define NES_CONN //includes famicom as definitions are effectively the same
  #define SNES_CONN
  #define SEGA_CONN
  #define GB_CONN
  #define N64_CONN
#endif

#if defined(STM_INL6_PROTO)
  #define NES_CONN //includes famicom as definitions are effectively the same
  #define SNES_CONN
  //	#define SEGA_CONN	//don't feel like fixing these definitions right now..
  #define GB_CONN
  #define N64_CONN
#endif

#ifdef AVR_CORE
  #include "avr_gpio.h"
  #include <avr/wdt.h>
#elif STM_CORE
  #include <stm32f0xx.h>
  //STM32 GPIO ports are effectively 16bits wide
  //Use this type when need an int to hold pin mask
  #define GPIO_PinMask	uint16_t
  #define wdt_reset() 	IWDG->KR = 0x0000AAAA
#endif

//This file contains pinout translations from AVR names to "kazzo" names
//this file also works to make all kazzo versions compatible and "alike"
//There are defines for kazzo version, turns out unique early versions
//can be differentiated by solder mask color.
//Final version is default and doesn't need any defines
//#define PURPLE_KAZZO
//#define GREEN_KAZZO	//GREEN needs PURPLE defined at same time

#ifdef GREEN_KAZZO
void software_AHL_CLK();
void software_AXL_CLK();
#endif

//=======================================================
//History of PCB revsisions produced by InfiniteNesLives
//=======================================================
//
// uncomment define if buiding for either of the first two versions
//#define PURPLE_KAZZO

// First printed circuit board version
// only handful made (less than 10?)
// Purple solder mask
// Labeled "Kazzo PCB rev 3.0"
// Dated 8/22/2011
// * Only contained NES and Famicom connectors
// * Had bug where USB data lines mixed up
// 	-manually fixed during component assembly
// * Naruko determined this should have still been v1 board
// 	-due to it's overall design and conflicting with someother v3 board
// * This was my first ever PCB design and one of the first
// 	times designing something for the NES/FC.  Looking
// 	back at the design there were some very noob decisions...
// * INPUT/OUTPUT differences:
// 	EXP9 - PD1/LED jumper
// 		when closed, PD1 controls NES EXP9 and LED
// 		when open, EXP9 is floating PD1 only controls LED
// 		NES EXP9 was connected to GND pin #16 on FC
// 		-I must have thought that GND pin could serve
// 			different purpose..
// 		-Result is PD1 is shorted to GND when FC cart inserted
// 			and jumper closed..
// 		Believe I closed this jumper on units I shipped
// 			prob should have left it open..
//		Suggested fix: leave open and ground EXP9
//			-prevents issue with LED when FC cart inserted
//			-minor draw back no access to EXP9
// 	ALOG - EXP6 - DIGI jumper
// 		another noob jumper decision...
// 		ALOG is the MCU AREF pin which should be tied to VCC
// 			-I thought it was an analog in apparently...
// 		DIGI is EXP flip flop Q6 output
// 		Best position for this jumper is EXP6-DIGI
// 		ALOG pad should be tied to VCC with jumper..
// 		Doing that would make it similar to future designs.
// 		Don't think I shipped any with ALOG jumper closed
// 		NES EXP6 is tied to Famicom pin 46 (Sound to RF)
// 	Expansion port FlipFlop /OE - CLK
// 		Aside from lame jumper design above, biggest difference
// 		between this PCB version and future ones.
// 		-EXP FF /OE controlled by MCU PD7
// 		-EXP FF CLK controlled by MCU PC3
// 		Future versions control both /OE and CLK with PD7
// 			-this frees PC3 for user use
// 	Both FlipFlops D i/p are driven by Data bus (PORT B)
//
//
// Second printed circuit board version
// only handful made (about a dozen?)
// Purple solder mask
// Labeled "Kazzo PCB rev 1.1"
// Dated 8/22/2011
// * Only contained NES and Famicom connectors
// * Identical to version above aside from the following
// * Corrected bug where USB data lines mixed up
// * Changed silkscreen to v1.1 as suggested by naruko
// * INPUT/OUTPUT differences:
//	-Same as version above as far as I know.
//
//
// uncomment define if buiding for this versions
//#define GREEN_KAZZO
//
// Third printed circuit board version
// only handful made (about ten?) used primarily as SNES prototype
// Green solder mask
// Labeled "Retro programmer/dumper v1.2"  "Kazzo 1.x"
// Dated Apr 2013
// * First version to add SNES connector along with NES & FC
// * Removed noob jumpers from purple versions above.
// 	-grouned FC pin16 as it should have been.
// * INPUT/OUTPUT differences:
//	-EXP FF /OE still controlled by MCU PD7
//	-MCU PC7 controls both CLK on both FF's.
//	-EXP FF D inputs are PORTA
//		all other versions are driven by PORTB
//		This means you always have to clock both flipflops
//		Place desired value on PORTA/B respectively and clock with PD7
//	-PC3 is free for user use.
//	-SNES /RESET pin not controlled by PD0 (EXP0)
//		instead it's controlled by A20 (EXPFF Q4)
//		prevents putting INL SNES boards in program mode unless A20 is also low
//		pretty much makes flashing SNES boards a royal PITA/impossible
//		Suggested fix is to have PD0 (EXP0) control SNES /RESET
//		would have to free /RESET and wire to EXP0/PD0 to permit flashing/reading  INL SNES board.
//
//
// Fourth printed circuit board version
// First volume PCB run ~300 copies
// Yellow solder mask
// Labeled "Retro programmer/dumper v1.2b"  "Kazzo 1.x"
// Dated May 2013
// * Includes NES, Famicom, & SNES connector
// * SNES board must be removed from case and slid all the way to right
// * Pitch offset on SNES connector makes it difficult to connect with original SNES boards.
// 	-Connector designed to only provide support for INL SNES Hi/Lo-ROM boards.
// * Care must be excersized not to insert SNES board backwards applying reverse power.
// * Effectively Final circuit design after lessons learned on small batches that preceeded.
// * INPUT/OUTPUT differences:
//	-EXP FF /OE & CLK controlled by MCU PD7
//	-MCU PC7 only controls CLK on ADDR HIGH FF.
//	-EXP & ADDRHI FF D inputs both on Data bus PORTB
//	-PC3 is free for user use.
//	-SNES /RESET pin controlled by PD0 (EXP0)
//	-Retains prev ver fixes, nothing funny going on with jumpers FC GND pin #16
//
//
// Fifth printed circuit board version
// Second volume PCB run ~500 copies
// Yellow solder mask
// Labeled "Retro programmer/dumper v1.2b"  "Kazzo 1.x"
// Dated OCT 2014
// * Includes NES, Famicom, & SNES connector
// * SNES connector setup/cautions just like the prev version.
// * No significant changes from previous version.
// 	-Changed MCU clock to Crystal instead of resonator in prev ver.
// 	-Added screw mount holes, although not very well placed.
// * INPUT/OUTPUT differences:
// 	-None from previous version
//
//
// Sixth printed circuit board version
// Third volume PCB run in production as of 1NOV2016
// Orange solder mask
// Labeled "Retro programmer/dumper v1.4"  "Kazzo 1.x"
// Dated OCT 2016
// Addition of fancy INL logo for first time
// * Includes NES, Famicom, & SNES connector
// * SNES connector improvement to correct pitch issue with prev ver.
// * Addition of PCT resettable fuse on incoming power.
// 	-Provides protection to SNES boards inserted backwards.
// * Rearrangement of BL/RUN switch and screw holes for better case design.
// * Cut out buzzer pads (PD6) from under MCU which was never developed.
// * INPUT/OUTPUT differences:
// 	-None from previous version
//
//
// STM32F070C6T6 KAZZO USB 2.0 ADAPTER board prototype
// designed to retrofit all previous kazzo versions
// updates to arm cortex M0 core and hardware USB 2.0
// Green solder mask
// Labeled "KAZZO USB 2.0 ADAPTER" "V1.P"
// Dated JAN 2017
// Pins out to all DIP-40 pins:
// AVR reset -> STM reset
// AVR BOOTLOADn -> STM BOOT0 (not sure if this actually works...)
// AVR XTAL1/2 -> STM oscOUT/IN (PF1/0)
//
// ascii art board connections setup:
//AVR PIN #40<.                                                        .-> AVR PIN #20
//          __|__|__|__|__|__|__|__|__|__|__|__|__|__|__|__|__|__|__|__|_
//          | O  O  O  O  O  O  O  O  O  O  O  O  O  O  O  O  O  O  O  O|
//          |     "KAZZO USB 2.0 ADAPTER"                               |
// kazzo    | programming header           /\          6pin extra port  | kazzo
// rst butn | O- /RESET                   /  \         EMPTY -O O- PA6  | AVR PA6 "FREE"
// CIRAM_A10| O- SWD (PA13) CIRAM A10    /STM \        EMPTY -O O- PC15 | nc
// GND      | O- GND                     \ 32 /          3v3 -O O- PC14 | nc
// nc       | O- SWC (PA14)               \ ./           GND -O O- PA1  | nc
// nc       | O- 3v3                       \/             5v -O O- PA0  | EXP0
//          |                                                           |
//          | O  O  O  O  O  O  O  O  O  O  O  O  O  O  O  O  O  O  O  O|
//          -------------------------------------------------------------
//            |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
//AVR PIN #1<-`                                                        `-> AVR PIN #19
//
//
//
// STM32F070RBT6 "INL RETRO 6" prototype
// completely new design with 6 connectors:
// 	GBA/DMG, SNES/SFC, NES, N64, Sega gen, Famicom
// updates to arm cortex M0 core and hardware USB 2.0
// Green solder mask
// Labeled "INL RETRO PROGRAMMER DUMPER V2.0P"
// Dated MAY 2017
// Unlike all previous version above this has direct access to most pins
// Only exception is one Flipflop for SegaGen A17-18, 20-23, #LO_MEM, & #TIME
// 	flipflop also drives SNES PA0-7
//
// This version had 16bit data bus mapped to PB2-15 & PA9-10 (D0-15 linearly)
// for 5v tolerance.  This kept the data bits linear, but doesn't have
// much benefit and comes at the cost of slowing all 8bit data transfers.
// The final version below changed this mapping.
//
// PA8: NES connected to M2 & 21.4Mhz SYSTEM CLOCK
// 	SNES connected to both SYSCLK & MASTER CLOCK
// PA10: NES- CIRAM_CE
// PB1: NES CIC CLK & LED, this caused problems when SWIM needed to be on CICCLK
// SNES PA0-7 are behind flipflop, some of other expansion pins are SW alt signals or shared
// PA4: AUDIOL is connected to NES/famicom audio out which may conflict with GB pin31 irq/audio
//
//
// STM32F070RBT6 "INL RETRO 6" First Release
// minor changes to prototype above still has 6 connectors:
// 	GBA/DMG, SNES/SFC, NES, N64, Sega gen, Famicom
// Orange solder mask
// Labeled "INL RETRO PROGRAMMER DUMPER V2.0"
// Dated APR 2018
// Like prototype this has direct access to most pins but some are behind a flipflop
// It changed pinouts to gain connection to *ALL* cartridge pins unlike the prototype
// This version also added P-mos transistor and schottky diode for software control
// of Gameboy/GBA supply voltage.
//
// PB8-15: DATA 0-7
// PB2-7 and PA9-10: DATA 8-15
//
// NES changes:
// Expansion port connections are affected by rearrangement of DATA PORT
// 	but the assignment of D# to EXP# are the same
// NES M2 & SYSTEM CLOCK split up & CIRAM /CE moved
// PA8: 21Mhz SYSCLK
// PA10: M2 (can now be driven independent of software with TIM1_CH3)
// PA13: CIRAM /CE
// CIC CLK moved off of LED signal since will be used for SWIM
// PC0: Drives both A0 & CIC CLK
// PB1: LED doesn't share any NES signals
//
// SNES changes:
// Expansion PA0-7 are no longer behind flipflop, connected to AD0-7 instead
// PA /RD, PA /WR, /REFRESH, & /WRAMSEL are now mapped to FLIPFLOP:4-7
// SYSCLK & MASTER CLOCK split up
// PA1: SYSCLK (pin 57)
// PA8: 21Mhz MASTER CLOCK
// PA7: unused to keep from conflicting with GB power sel
// PA13: connected to EXPAND now
// PC0: Drives both A0 & CIC CLK
//
// SEGA GENESIS changes:
// PC0: AD0 is connected to A1 & #CAS
// PC1: AD1 is connected to A2 & Vsync
// PC2: AD2 is connected to A3 & Video
// PB1: LED is connected to #H_RESET (bidirectional hard reset should be open drain)
//
//
// GAMEBOY/GBA changes:
// pin31 GBirq/GBAaudio PA5 (AUDIOR) because NES/famicom may drive PA4 (audioL)
// PA7: selects GB voltage supply via Pmos & diode
//   mcu pin connects to pmos gate with source connected to 5v
//   schottky diode between 3v3 and GB power
//   -PA7 low: Vgs = -5v, mosfet on, GB power ~5v
//   -PA7 high: Vgs = -1.7v mosfet mostly off
//    diode supplies power ~3v
//   without a load on the GB slot, ~5v is present regardless of PA7
// BSS84 mosfet has max Id of 130mA with Rds of ~10ohm
//  can support up to 520mA pulsed
// RB521S30T schottky diode has Vf of 0.5v @ 200mA
//  @ 25C 20ma: Vf= 0.3v, 100mA: Vf= 0.37v
//  testing data 47ohm load:
//  	PA7 low (0v @ gate) 90mA 4.74v (~2.8Rds plus fuse cable etc)
//  	PA7 hi (3.3v @ gate) 54mA 2.97v (~0.33Vf)
//  testing data 23ohm load:
//  	PA7 low (0v @ gate) 159mA 4.51v (~2.8Rds plus fuse cable etc)
//  		Vusb = 4.84, Vfuse = 4.77, -> Vds = 260mV -> Rds = 1.6ohm
//  	PA7 hi (3.3v @ gate) 103mA 2.94v (~0.36Vf)
//  in practice should be able to expect GB power to be 2.9v / 4.5v
//  this more than satisfies 2.7v requirement for 3v flash
//  and 4.5v is more than adequate for 5v chips/regulators
//
//
//
// STM32F070C6T6 "INL RETRO NES" V2.0N NESmaker edition
// Orange solder mask
// Labeled "INL RETRO PROGRAMMER DUMPER V2.0N"
// Dated AUG 2018
// Comparable to INL6, but only has NES connector
// uses Flipflop for io expansion for A8-15 similar to original kazzos
// this device is setup very similarly to STM_ADAPTER
// AHL/AHLOE, AXL, EXP port, and CIC port are main differences
//
// AHL_OEn controls AHL flipflop clock and /OE
// 	-also tied to CIC RESET, but this creates problems with CICs that wire OR RESET and DOUT
// 	Only viable solution is to cut AHL_OEn away from CIC RESET
// 	Don't have any reason that CIC RESET is needed at this point, and in reality it's the same
// 	CIC mcu pin for stm8s001 CICs..  Perhaps I should have used stm32 pin PA1 shared with EXP1 (JTAG TDI)
// 	CIC CLK connected to A0
// 	CIC KEY DIN shared with NTSC 24Mhz
// 	CIC KEY DOUT is also SWCLK
// AXL does not exist
// EXP0-3,6 has dedicated mcu pin
// EXP4-5,7-8 connect to A4-7
// EXP9 is shared with LED
//

//=============================================================================================
//
// PINPORT ABSTRACTION LAYER
//
//=============================================================================================
//
//	The pinport abstraction layer creates definitions of generic device GPIO ports.
//	These generic ports are designed to make high level firmware generic to the
//	actual underlying hardware.  The ports created have defined sizes and access rules
//	that keeps firmware from growing in complexity based on the specific hardware.
//
//	Idea is to define ports which are available on all hardware, but also create ports
//	which may not be available to other hardwares.  If the firmware is instructed to
//	perform an operation on a port that's not present, or not initialized/setup error
//	codes will be sent back to the host to designate the lack of port presence.
//

// STM32 GPIO registers are quite different than AVR style
// they are more flexible/capable, but a little tricky to interface with
// some features present on STM32 pins, but not AVR
//  - PULL-DOWN ability (and PULL-UP like AVR)
//  - Speed/Slew rate selection
//  - Open drain outputs (and push/pull like AVR)
//  - Bit set/reset registers to remove necessity of RMW operations
//  - Lockability to keep port config bits from changing until reset
//  - GPIO blocks must be provided a clock and enabled to "turn on"
//    failing to do so will cause hard faults when accessing registers!!
//
//  All GPIO registers can be accessed in byte, halfword, or 32bit full words
//  	unless otherwise noted
//
//  GPIOx->MODER[1:0] 32bit registers control direction/type of driver
//  00- Input (default reset state, except SWC-PA15 & SWD-PA13 default AF)
//  01- Gen Purp Output
//  10- Alternate func (SPI, I2C, etc)
//  11- reserved
//  MODER[1] typically leave clear unless using AltFunc
//  MODER[0] becomes equivalent of AVR DDR
#define MODER_OP	0x01
#define MODER_OP_ALL	0x55555555
#define MODER_AF	0x10
//
//  GPIOx->OTYPER 16bit registers control driver type
//  0- Push Pull (default reset state)
//  1- Open Drain
//  N/A when MODER is set to "00" INPUT
//  we can generally just ignore this register and use pushpull as AVR does
//  but using open drain mode makes things like SWIM much simpler to control
//#define	OTYPER_PP	0x00
#define OTYPER_OD	0x01
//
//  GPIOx->OSPEEDR[1:0] 32bit registers control pin driver speed/slew
//  x0- Low speed (default reset state, except SWD-PA13 default High Spd)
//  01- Medium speed
//  11- High speed
//  N/A when MODER is set to "00" INPUT
//  we can generally just ignore this register and use slow speed
//
//  GPIOx->PUPDR[1:0] 32bit registers control pull-up/down resistors
//  this register is in effect even when alternate functions are enabled
//  00- floating/disabled, no pull-up/down  (default for most pins except below)
//  01- Pull-up enabled			    (default SWD-PA13)	also CIRAM A10
//  10- Pull-down enabled		    (default SWC-PA14)
//  11- Reserved, don't use (prob enables both which would be bad...)
//  PUPDR[0] is kinda like AVR PORT when DDR is set to INPUT, and PUPDR[1]=0
//  This ends up being a little cleaner than AVR i/o interfacing
//  Can probably just enable pull-ups on everything and leave it like that
//  -only exception being USB pins (PA11/12) better leave those floating
//#define PUPDR_FL	0x00
#define PUPDR_PU	0x01
#define PUPDR_PD	0x10
#define PUPDR_PU_ALL	0x55555555
//
//  GPIOx->IDR 16bit register used to read current input level on pin
//  	this register is read only
//
//  GPIOx->ODR 16bit register used to set output of pin if enabled by MODER
//  	this register is read/writeable
//
//  GPIOx->BSRR 32bit register to only set/clear pins
//  	BR[31:16] upper halfword is will reset/clear pin if written to '1' value
//  	BS[15:00] lower halfword is will set pin if written to '1' value
//  	writing 0 to any bit has no effect
//  	if setting both BS register has priority (bit will be set)
//  	this register is write only!
//
//  GPIO->BRR 16bit register equivalent to upper word of BSRR register above
//      provides convinent separate BR register that doesn't need shifted
//
//  GPIOx->LCKR 17bit register MUST BE ACCESSED in 32bit full words!!!
//	complex sequence needed to set, but once done lock config/altfunc
//	bits for that GPIO.  I interpret this to mean the registers above
//	plus AF registers, exception of IDR, ODR, BSRR registers
//	Good to use this for things than we don't want to accidentally change:
//	 - USB & XTAL pins come to mind as good candidates
//
//  GPIOx->AFRL/H 2 sets of 32bit registers to determine alternate function
//  	of GPIO if enabled with MODER registers. Default is AF0 at reset

// AVR GPIO are rather simple in comparison to STM32 GPIO:
//
// DDRx 8bit direction register
// 	Determines 'direction' of pin driver
// 	set for output, clear of input
// 	reads give current status of register
//
// PORTx 8bit output/pullup register
// 	writes set/clear pin if DDR is set/OP
// 	write '1' to enable pull-up if DDR is clear/IP
// 	write '0' to disable pull-up if DDR is clear/IP
// 	reads give current status of register
// 	bit access must be done by means of RMW/shadow reg
//
// PINx 8bit read register
// 	read when DDR is clear/IP to get current pin level
// 	reading when O/P is of little use, as should be value of PORTx
// 	read only register

//	---------------------------------------------------------------------------------------
//	CONTROL PORT
//
//	This port is present on all devices, however not all pins are present depending on device
//	Keeping this port as bit access only makes it so there is no limit to number of pins.
//	Directionality: All pins are able to be toggled between input/output individually
//	Driver: All pins indiv selectable pull-up or float for input. Output always push pull.
//	Write/Output: Bit access only, no byte/word accesses
//	Read/Input: Bit access only, returned byte/word will be zero if clear, non-zero if set
//
//	PORT C pin definitions
//	Try not to assign one mcu pin to more than one pin in this port.
//	mcu pin can be assigned in other ports, as initializing
//	those ports will 'disable' the pin in this port.
//	if the pin has multiple purposes and would like to give
//	it different names based on the cart inserted, just create
//	multiple defines/names for the one PCn pin.
//	If a ctl pin is needed that's mapped to different mcu pins based on the board,
//	create a new control port pin and violate the first rule with caution.
//
//	Creation of new signals:
//	1) Create PC# -> mcupin assignment below
//	2) map pin name to PC# which follows assignments below
//	3) add applicable macro calls to pinport.c
//	4) add pin name to shared_dict_pinport.h operands for simple calling from host
//	5) add shortcut macros to pinport.h if desired
//	6) ensure CTL PORT ENABLE macro enables new pin adequately
//
//	---------------------------------------------------------------------------------------

#ifdef STM_INL6_PROTO

  // PC0  "M2"	mcupinA8
  #define C0bank 		GPIOA
  #define C0		(8U)

  // PC6  "CICE" 	mcupinA10
  #define C6bank 		GPIOA
  #define C6		(10U)

#endif

#ifdef STM_INL6

  // PC0  "M2"	mcupinA10
  #define C0bank 		GPIOA
  #define C0		(10U)

  // PC6  "CICE" 	mcupinA13
  #define C6bank 		GPIOA
  #define C6		(13U)

#endif

#if defined(STM_INL6_PROTO) || defined(STM_INL6)

  // PC1  "ROMSEL"	mcupinA0
  #define C1bank 		GPIOA
  #define C1		(0U)

  // PC2  "PRGRW"	mcupinA1
  #define C2bank 		GPIOA
  #define C2		(1U)

  // PC3  "FREE"
  // Not defined
  #define C3nodef

  // PC4  "CSRD"	mcupinA2
  #define C4bank 		GPIOA
  #define C4		(2U)

  // PC5  "CSWR"	mcupinA3
  #define C5bank 		GPIOA
  #define C5		(3U)

  // PC7  "AHL"
  // Not defined
  #define C7nodef

  // PC8  "EXP0" 	mcupinA6
  #define C8bank 		GPIOA
  #define C8		(6U)

  // PC9  "LED" 	mcupinB1
  #define C9bank 		GPIOB
  #define C9		(1U)

  // PC10 "IRQ"	mcupinA15
  #define C10bank 	GPIOA
  #define C10		(15U)

  // PC11 "CIA10" 	mcupinA9
  #define C11bank 	GPIOA
  #define C11		(9U)

  // PC12 "BL"
  // Not defined
  #define C12nodef

  // PC13 "AXL"
  // Not defined
  #define C13nodef

  // PC14 "AUDL"	mcupinA4
  #define C14bank 	GPIOA
  #define C14		(4U)

  // PC15 "AUDR"	mcupinA5
  #define C15bank 	GPIOA
  #define C15		(5U)

  // PC16 "GBP" 	mcupinA7
  #define C16bank 	GPIOA
  #define C16		(7U)

  // PC17 "SWD" 	mcupinA13
  #define C17bank 	GPIOA
  #define C17		(13U)

  // PC18 "SWC" 	mcupinA14
  #define C18bank 	GPIOA
  #define C18		(14U)

  // PC19 "AFL" 	mcupinB0
  #define C19bank 	GPIOB
  #define C19		(0U)

  // PC20 "COUT" 	mcupinD2
  #define C20bank 	GPIOD
  #define C20		(2U)

  // PC21 "FCAPU" 	double mapping of AUDR
  #define C21bank 	C15bank
  #define C21		C15

  // BROKE STUDIO
  //     PC22 "EXP5" mcupinB6
  #define C22bank 	GPIOB
  #define C22		(6U)
  // BROKE STUDIO

  /* NEED MORE UNIQUE names for these pins to not conflict with Data port definitions...
 * these changed around from proto to final
  //     PCxx "D8" 	mcupinB10
  #define Cxxbank 	GPIOB
  #define Cxx		(10U)

  //     PC22 "D9" 	mcupinB11
  #define C22bank 	GPIOB
  #define C22		(11U)

  //     PC23 "D10" 	mcupinB12
  #define C23bank 	GPIOB
  #define C23		(12U)

  //     PC24 "D11" 	mcupinB13
  #define C24bank 	GPIOB
  #define C24		(13U)

  //     PC25 "D12" 	mcupinB14
  #define C25bank 	GPIOB
  #define C25		(14U)

  //     PC26 "D13" 	mcupinB15
  #define C26bank 	GPIOB
  #define C26		(15U)
*/

  #define RCC_AHBENR_CTL		(RCC_AHBENR_GPIOAEN | RCC_AHBENR_GPIOBEN | RCC_AHBENR_GPIODEN)
  #define RCC_AHBENR_ADDR	 	 RCC_AHBENR_GPIOCEN
  #define RCC_AHBENR_HADDR 	(RCC_AHBENR_GPIOAEN | RCC_AHBENR_GPIOBEN)
  #define RCC_AHBENR_DATA	 	 RCC_AHBENR_GPIOBEN
  #define RCC_AHBENR_DATA16 	(RCC_AHBENR_GPIOAEN | RCC_AHBENR_GPIOBEN)
  #define RCC_AHBENR_EXP		(RCC_AHBENR_GPIOAEN | RCC_AHBENR_GPIOBEN)

#endif //STM_INL6 & PROTO

//STM_NES & STM_ADAPTER, they're predominantly the same
//AHL-AHLOE, AXL, EXP port, and CIC port are only differences
//The recommended wiring for STM_ADAPTER to CIC pins brings them even closer together..

#ifdef STM_ADAPTER
  // PC13 "AXL"	mcupinA2
  #define C13bank 	GPIOA
  #define C13		(2U)
#endif

#ifdef STM_NES
  // PC13 "AXL"
  // Not present on STM_NES, it uses this pin for EXP6 instead
  #define C13nodef
#endif

#if defined(STM_ADAPTER) || defined(STM_NES)

  // PC0  "M2"	mcupinA3
  #define C0bank 		GPIOA
  #define C0		(3U)

  // PC1  "ROMSEL"	mcupinA4
  #define C1bank 		GPIOA
  #define C1		(4U)

  // PC2  "PRGRW"	mcupinA5
  #define C2bank 		GPIOA
  #define C2		(5U)

  // PC3  "FREE"	mcupinA6
  // No connection on kazzo/stm adapter (recommend wire connection to CIC KEY DIN (pin34)
  // STM NES connects to CIC KEY DIN (pin34) & NTSC 24Mhz Clock
  #define C3bank 		GPIOA
  #define C3		(6U)
  #ifdef PURPLE_KAZZO
    #define C3nodef //assigned to PAXL instead which is tied to AXL /OE in software
  #endif

  // PC4  "CSRD"	mcupinA7
  #define C4bank 		GPIOA
  #define C4		(7U)

  // PC5  "CSWR"	mcupinB0
  #define C5bank 		GPIOB
  #define C5		(0U)

  // PC6  "CICE" 	mcupinA10
  #define C6bank 		GPIOA
  #define C6		(10U)

  // PC7  "AHL"	mcupinB1
  // AH Flipflop /OE is grounded on kazzo/stmadapter
  // AH Flipflop /OE is tied to CLK with this "AHL_OEN" signal
  #define C7bank 		GPIOB
  #define C7		(1U)

  // PC8  "EXP0" 	mcupinA0
  #define C8bank 		GPIOA
  #define C8		(0U)

  // PC9  "LED" 	mcupinC13
  // This is also EXP9 on kazzo, stm adapter, and stm NES
  #define C9bank 		GPIOC
  #define C9		(13U)

  // PC10 "IRQ"	mcupinA15
  #define C10bank 	GPIOA
  #define C10		(15U)

  // PC11 "CIA10" 	mcupinA13
  // This is also SWDIO pin
  #define C11bank 	GPIOA
  #define C11		(13U)

  // PC12 "BL"
  // Not defined because it's an MCU dedicated pin44 "BOOT0"
  #define C12nodef

  // PC13 "AXL"
  // Differs between STM_ADAPTER and STM_NES so defined above

  // PC14 "AUDL"
  // Not defined
  #define C14nodef

  // PC15 "AUDR"
  // Not defined
  #define C15nodef

  // PC16 "GBP"
  // Not defined
  #define C16nodef

  // PC17 "SWD" 	mcupinA13
  // Not defined due to shared with CIRAM A10
  #define C17nodef

  // PC18 "SWC" 	mcupinA14
  // This has no connection on STM_ADAPTER, recommended wire connection to CIC KEY DOUT (pin35)
  // STM_NES connects this to CIC KEY DOUT
  // PROBLEM...  INL STM8 CIC cuts mcu pins by wire ORing RESET & DOUT...
  #define C18bank 	GPIOA
  #define C18		(14U)

  // PC19 "AFL"
  // Not defined
  #define C19nodef

  // PC20 "COUT"
  // Not defined but maybe it should be in place of SWC..
  #define C20nodef

  // PC21 "FCAPU" 	double mapping of EXP0
  #define C21bank 	C8bank
  #define C21		C8

  // BROKE STUDIO
  //     PC22 "EXP5" mcupinB6
  #define C22bank 	GPIOB
  #define C22		(6U)
  // BROKE STUDIO

  #define RCC_AHBENR_CTL	(RCC_AHBENR_GPIOAEN | RCC_AHBENR_GPIOBEN | RCC_AHBENR_GPIOCEN)
  #define RCC_AHBENR_ADDR	(RCC_AHBENR_GPIOAEN | RCC_AHBENR_GPIOBEN)
  #define RCC_AHBENR_DATA	 RCC_AHBENR_GPIOBEN

#endif //STM_ADAPTER & STM_NES

#ifdef AVR_KAZZO

  // PC0  "M2"	mcupinC0
  #define C0bank 		GPIOC
  #define C0		(0U)

  // PC1  "ROMSEL"	mcupinC1
  #define C1bank 		GPIOC
  #define C1		(1U)

  // PC2  "PRGRW"	mcupinC2
  #define C2bank 		GPIOC
  #define C2		(2U)

  // PC3  "FREE"	mcupinC3
  #define C3bank 		GPIOC
  #define C3		(3U)
  #ifdef PURPLE_KAZZO
    #define C3nodef //assigned to PAXL instead which is tied to AXL /OE in software
  #endif

  // PC4  "CSRD"	mcupinC4
  #define C4bank 		GPIOC
  #define C4		(4U)

  // PC5  "CSWR"	mcupinC5
  #define C5bank 		GPIOC
  #define C5		(5U)

  // PC6  "CICE" 	mcupinC6
  #define C6bank 		GPIOC
  #define C6		(6U)

  // PC7  "AHL"	mcupinC7
  #define C7bank 		GPIOC
  #define C7		(7U)

  // PC8  "EXP0" 	mcupinD0
  #define C8bank 		GPIOD
  #define C8		(0U)

  // PC9  "LED" 	mcupinD1
  #define C9bank 		GPIOD
  #define C9		(1U)

  // PC10 "IRQ"	mcupinD3
  #define C10bank 	GPIOD
  #define C10		(3U)

  // PC11 "CIA10" 	mcupinD5
  #define C11bank 	GPIOD
  #define C11		(5U)

  // PC12 "BL"	mcupinD6
  #define C12bank 	GPIOD
  #define C12		(6U)

  // PC13 "AXL"	mcupinD7	//PURPLE KAZZO uses this for /OE only
  #define C13bank 	GPIOD
  #define C13		(7U)

  // PC14 "AUDL"
  // not defined
  #define C14nodef

  // PC15 "AUDR"
  // not defined
  #define C15nodef

  // PC16 "GBP"
  // not defined
  #define C16nodef

  // PC17 "SWD"
  // not defined
  #define C17nodef

  // PC18 "SWC"
  // not defined
  #define C18nodef

  // PC19 "AFL"
  // not defined
  #define C19nodef

  // PC20 "COUT"
  // not defined
  #define C20nodef

  // PC21 "FCAPU" 	double mapping of EXP0
  #define C21bank 	C8bank
  #define C21		C8

  // BROKE STUDIO
  //     PC21 "???"
  //     not defined
  #define C22nodef
  // BROKE STUDIO

#endif //AVR_KAZZO

////////////////////////////////////////////////////////////////////////////////
//	PORT C pin mappings
////////////////////////////////////////////////////////////////////////////////
//
//	PC0-13 are defined based on majority of avr kazzos PORTC-PORTD
//	PC0  "M2"	NES M2/phi2
#define M2 		C0
#define M2bank		C0bank

//	PC1  "ROMSEL"	Cartridge rom enable
#define ROMSEL 		C1
#define ROMSELbank	C1bank

//	PC2  "PRGRW"	NES CPU R/W signal
#define PRGRW 		C2
#define PRGRWbank	C2bank

//	PC3  "FREE"	purple kazzo EXP flipflop latch, FREE on most kazzos
#define FREE 		C3
#define FREEbank	C3bank

//	PC4  "CSRD"	NES CHR/SNES /RD
#define CSRD 		C4
#define CSRDbank	C4bank

//	PC5  "CSWR"	NES CHR/SNES /WR
#define CSWR 		C5
#define CSWRbank	C5bank

//	PC6  "CICE" 	NES CIRAM /CE
#define CICE 		C6
#define CICEbank	C6bank

//	PC7  "AHL" 	ADDR HI Latch
#define AHL 		C7
#define AHLbank		C7bank

//	PC8  "EXP0" 	NES EXP0, FC APU sound, cart-console /RESET, GENESIS /S_RESET (pin 27)
#define EXP0 		C8
#define EXP0bank	C8bank

//	PC9  "LED" 	kazzos tied this to NES EXP9
#define LED 		C9
#define LEDbank		C9bank

//	PC10 "IRQ"	console CPU interrupt from cart
#define IRQ 		C10
#define IRQbank		C10bank

//	PC11 "CIA10" 	NES CIRAM A10
#define CIA10 		C11
#define CIA10bank	C11bank

//	PC12 "BL" 	Bootloader pin
#define BL 		C12
#define BLbank		C12bank

//	PC13 "AXL" 	EXP FF latch and /OE, purple kazzos this was only /OE
#define AXL 		C13
#define AXLbank		C13bank

//	 INLretro6 adds following pins
//	PC14 "AUDL"	cart audio
#define AUDL 		C14
#define AUDLbank	C14bank

//	PC15 "AUDR"	cart audio
#define AUDR 		C15
#define AUDRbank	C15bank

//	PC16 "GBP"	Gameboy power select
#define GBP 		C16
#define GBPbank		C16bank

//	PC17 "SWD" 	mcu debug
#define SWD 		C17
#define SWDbank		C17bank

//	PC18 "SWC" 	mcu debug
#define SWC 		C18
#define SWCbank		C18bank

//	PC19 "AFL" 	flipflop addr expansion for FF0-7
#define AFL 		C19
#define AFLbank		C19bank

//	PC20 "COUT" CIC data out
#define COUT 		C20
#define COUTbank	C20bank

//	PC21 "FCAPU" cart audio in
#define FCAPU 		C21
#define FCAPUbank	C21bank

// BROKE STUDIO
//	PC22  "EXP5" 	NES EXP5
#define EXP5 		C22
#define EXP5bank	C22bank
// BROKE STUDIO

//	 INLretro6 gains direct control over NES EXP port and is used for N64 control pins:
/*
//	PCxx "D8"
#define D8 		Cxx
#define D8bank		Cxxbank

//	PC22 "D9"
#define D9 		C22
#define D9bank		C22bank

//	PC23 "D10"
#define D10 		C23
#define D10bank		C23bank

//	PC24 "D11"
#define D11 		C24
#define D11bank		C24bank

//	PC25 "D12"
#define D12 		C25
#define D12bank		C25bank

//	PC26 "D13"
#define D12 		C26
#define D12bank		C26bank

//	PC27 "D14"
#define D12 		C27
#define D12bank		C27bank

//		D15 & D16 are defined as CICE/CIA10 above
*/

#ifdef STM_CORE

  #define CTL_IP_PU(bank, pin)		bank->MODER &= ~(MODER_OP<<(pin*2)); bank->PUPDR |=  (PUPDR_PU<<(pin*2))
  #define CTL_IP_FL(bank, pin)		bank->MODER &= ~(MODER_OP<<(pin*2)); bank->PUPDR &= ~(PUPDR_PU<<(pin*2))
  #define CTL_OP(bank, pin)		bank->MODER |=  (MODER_OP<<(pin*2))
  #define CTL_OD(bank, pin)		bank->OTYPER |=  (OTYPER_OD<<(pin))	//open drain has no effect when pin is input
  #define CTL_PP(bank, pin)		bank->OTYPER &= ~(OTYPER_OD<<(pin))
  #define CTL_SET_LO(bank, pin)		bank->BRR = 1<<pin
  #define CTL_SET_HI(bank, pin)		bank->BSRR = 1<<pin
  #define CTL_RD(bank, pin, val)		val = (bank->IDR & (1<<pin))
  //NOTE: STM registers are 16bit "halfwords" so must provide a 16bit val

  #define CTL_ENABLE()	RCC->AHBENR |= RCC_AHBENR_CTL

#endif //STM_CORE

#ifdef AVR_CORE

  #define CTL_IP_PU(bank, pin)		bank->DDR &= ~(1<<pin); bank->PORT |=  (1<<pin)
  #define CTL_IP_FL(bank, pin)		bank->DDR &= ~(1<<pin); bank->PORT &= ~(1<<pin)
  #define CTL_OP(bank, pin)		bank->DDR |=  (1<<pin)
  #define CTL_SET_LO(bank, pin)		bank->PORT &= ~(1<<pin)
  #define CTL_SET_HI(bank, pin)		bank->PORT |=  (1<<pin)
  #define CTL_RD(bank, pin, val)		val = (uint16_t) (bank->PIN & (1<<pin))

  #define CTL_ENABLE() //nothing to be done for AVR

#endif //AVR_CORE

// CONTROL PORT MACROS to simplify flipflop operations
//

//#ifndef STM_INL6
#if !defined(STM_INL6_PROTO) && !defined(STM_INL6)

  #ifdef GREEN_KAZZO
    #define AHL_CLK()      software_AHL_CLK()
    #define AXL_CLK()      software_AXL_CLK()
  #elif defined PURPLE_KAZZO
    #define AHL_CLK()      CTL_SET_HI(AHLbank, AHL); CTL_SET_LO(AHLbank, AHL)
    #define AXL_CLK()      CTL_SET_HI(FREEbank, FREE); CTL_SET_LO(FREEbank, FREE)
  #else //STM_NES ties AHL to the flipflop's /OE pin as well, so default should be low when address bus is enabled
    #define AHL_CLK()      CTL_SET_HI(AHLbank, AHL); CTL_SET_LO(AHLbank, AHL)
    #define AXL_CLK()      CTL_SET_HI(AXLbank, AXL); CTL_SET_LO(AXLbank, AXL)
  #endif
#endif

//	---------------------------------------------------------------------------------------
//	DATA PORT 8bit
//
//	This port is present on all devices
//	Directionality: All pins are bidirectional controlled as a whole
//	Driver: All pins are push-pull, and unknown floating/pull-up when input
//		main reason to be unknown is AVR uses PORT for pull-up enable
//		don't want to require re-enabling pullups for every data access
//		STM32 are default to pull-up, AVR requires manually pulling up
//		by calling DATA_IP_PU() if pullups required, otherwise unknown
//	Write/Output: Byte access only, no bit accesses.  Must be returned to input after read!
//	Read/Input: Default condition, byte access only
//
//	---------------------------------------------------------------------------------------
//
#ifdef STM_INL6

  //All 8bits are on upper byte of GPIOB inorder
  //PB8-15 map to D0-7
  //PB2-7 map to D8-13
  //PA9-10 map to D14-15 (unchanged from prototype)
  #define Dbank 		GPIOB

  //IP and OP assume MODER[1] is clear (ie not set to Alt Func)
  //also assume PUPDR is reset default floating
  #define DATA_IP_PU()	Dbank->MODER &= ~(MODER_OP_ALL & 0xFFFF0000); Dbank->PUPDR |= (PUPDR_PU_ALL & 0xFFFF0000)
  #define DATA_IP()	Dbank->MODER &= ~(MODER_OP_ALL & 0xFFFF0000)
  #define DATA_OP()	Dbank->MODER |=  (MODER_OP_ALL & 0xFFFF0000)
  #define DATA_SET(data)	Dbank->ODR = (Dbank->ODR & 0x00FF) | (data<<8)
  #define DATA_RD(data)	data = (Dbank->IDR>>8) & 0x00FF

  #define DATA_EN_CLK()	RCC->AHBENR |= RCC_AHBENR_DATA
  #define DATA_ENABLE()	DATA_EN_CLK(); DATA_IP_PU();

#endif //STM_INL6

#ifdef STM_INL6_PROTO

  //All 8bits are on GPIOB inorder, but mapped to bits9-2 for 5v tolerance
  //I get why I designed it that way so D8-13 could follow in order..
  //But with D8-15 required to be broken up anyways, perhaps it would have
  //made more sense to map D0-7 to bits 9-15 so byte access could be performed
  //without shifting on Data7-0...
  //This is what I did for final production version v2.0 above
  #define Dbank 		GPIOB

  //IP and OP assume MODER[1] is clear (ie not set to Alt Func)
  //also assume PUPDR is reset default floating
  #define DATA_IP_PU()	Dbank->MODER &= ~(MODER_OP_ALL & 0x000FFFF0); Dbank->PUPDR |= (PUPDR_PU_ALL & 0x000FFFF0)
  #define DATA_IP()	Dbank->MODER &= ~(MODER_OP_ALL & 0x000FFFF0)
  #define DATA_OP()	Dbank->MODER |=  (MODER_OP_ALL & 0x000FFFF0)
  #define DATA_SET(data)	Dbank->ODR = (Dbank->ODR & 0xFC03) | (data<<2)
  #define DATA_RD(data)	data = (Dbank->IDR>>2) & 0x00FF

  #define DATA_EN_CLK()	RCC->AHBENR |= RCC_AHBENR_DATA
  #define DATA_ENABLE()	DATA_EN_CLK(); DATA_IP_PU();

#endif //STM_INL6_PROTO

#if defined(STM_ADAPTER) || defined(STM_NES)

  //All 8bits are on GPIOB in order, but mapped to bits15-8
  #define Dbank 		GPIOB

  //IP and OP assume MODER[1] is clear (ie not set to Alt Func)
  //also assume PUPDR is reset default floating
  //TODO for input MODER=00 why not just clear both bits???
  #define DATA_IP_PU()	Dbank->MODER &= ~(MODER_OP_ALL & 0xFFFF0000); Dbank->PUPDR |= (PUPDR_PU_ALL & 0xFFFF0000)
  #define DATA_IP()	Dbank->MODER &= ~(MODER_OP_ALL & 0xFFFF0000)
  #define DATA_OP()	Dbank->MODER |=  (MODER_OP_ALL & 0xFFFF0000)
  //TODO create byte wide port structs to grant byte accesses so doesn't need shifted
  #define DATA_SET(data)	Dbank->ODR = (Dbank->ODR & 0x00FF) | (data<<8)
  //TODO the 0x00FF mask shouldn't be necessary as they're reserved and expected to be clear
  #define DATA_RD(data)	data = (Dbank->IDR>>8) & 0x00FF

  #define DATA_EN_CLK()	RCC->AHBENR |= RCC_AHBENR_DATA
  #define DATA_ENABLE()	DATA_EN_CLK(); DATA_IP_PU()

#endif //STM_ADAPTER or STM_NES

#ifdef AVR_KAZZO

  //All 8bits are on GPIOB aligned perfectly
  #define Dbank 		GPIOB

  #define DATA_SET(data) Dbank->PORT = data
  #define DATA_IP_PU()   Dbank->DDR = 0x00; DATA_SET(0xFF)
  #define DATA_IP()      Dbank->DDR = 0x00
  #define DATA_OP()      Dbank->DDR = 0xFF
  #define DATA_RD(data)  data = Dbank->PIN

  #define DATA_ENABLE()	DATA_IP_PU()

#endif //AVR_KAZZO

//	---------------------------------------------------------------------------------------
//	ADDRESS PORT 16bit
//
//	This port is present on all devices
//	Directionality: All pins are forced output
//	Driver: All pins are push-pull
//	Write/Output: Byte/half word access only, no bit accesses
//	Read/Input: Not supported
//
//	Broke the rules above for devices with GBA ports, let them be inputs
//	don't really need to define a whole new port, just need to be able to
//	read from the current definition.  Old kazzo's and STM_NES can't
//	do these functions, but they don't have GBA/N64 connectors..
//
//	---------------------------------------------------------------------------------------

#if defined(STM_INL6_PROTO) || defined(STM_INL6)

  //All 16bits are on GPIOC in perfect alignment
  #define Abank 		GPIOC

  #define ADDR_PU()	Abank->PUPDR |=  PUPDR_PU_ALL
  #define ADDR_IP()	Abank->MODER &= ~MODER_OP_ALL
  #define ADDR_OP()	Abank->MODER |=  MODER_OP_ALL
  #define ADDRL(low)	Abank->ODR = (Abank->ODR & 0xFF00) | low
  #define ADDRH(high)	Abank->ODR = (Abank->ODR & 0x00FF) | (high<<8)
  //Not sure why but this wasn't working on inl6 detection of vertical mirroring was failing..
  //seems to not be reading the ODR, maybe getting optimized out..?
  //works fine on stmad and AVR which have ADDRH behind flipflop
  //Appears to be working for setting A10, but not A11 reguardless of order of execution..
  //TODO really these macros should be making byte writes to the registers, not 16bit RMW
  #define ADDR_SET(hword)	Abank->ODR = hword
  #define ADDR_CUR	(Abank->ODR)		//can use this to determine current address
  #define ADDR_RD(hword)	hword = Abank->IDR	//can use this as a function ADDR_RD(data)
  #define ADDR_VAL	(Abank->IDR)		//can use this to assign:  data = ADDR_VAL

  #define ADDR_EN_CLK()	RCC->AHBENR |= RCC_AHBENR_ADDR
  #define ADDR_ENABLE()	ADDR_EN_CLK(); ADDR_OP()

#endif //STM_INL6 & PROTO

#if defined(STM_ADAPTER) || defined(STM_NES)

  // A15-8 are behind AHL flipflop
  // A7-6 are on GPIO A9-8
  // A5-0 are on GPIO A7-2
  #define A76bank 	GPIOA
  #define A50bank 	GPIOB

  #define ADDR_PU()	A76bank->PUPDR |=  (PUPDR_PU_ALL & 0x000F0000); A50bank->PUPDR |=  (PUPDR_PU_ALL & 0x0000FFF0)
  #define ADDR_IP()	A76bank->MODER &= ~(MODER_OP_ALL & 0x000F0000); A50bank->MODER &= ~(MODER_OP_ALL & 0x0000FFF0)
  #define ADDR_OP()	A76bank->MODER |=  (MODER_OP_ALL & 0x000F0000); A50bank->MODER |=  (MODER_OP_ALL & 0x0000FFF0)
  //WARNING!!!  Don't use pre/post increment on passed in argument as macro expands to double inc/decrement variable!!!
  #define ADDRL(low)	A76bank->ODR = (A76bank->ODR & 0xFCFF) | ((low & 0xC0)<<2);A50bank->ODR = (A50bank->ODR & 0xFF03) | ((low & 0x3F)<<2)
  //clocks must be initialized, Data bus clear
  #define ADDRH(high)	DATA_OP(); DATA_SET(high); AHL_CLK(); DATA_IP()
  #define ADDR_SET(hword)	ADDRL(hword); ADDRH(hword>>8)

  #define ADDR_EN_CLK()	RCC->AHBENR |= RCC_AHBENR_ADDR
  #define ADDR_EN_FF()	CTL_OP(AHLbank, AHL); CTL_SET_LO(AHLbank, AHL)
  #define ADDR_ENABLE()	DATA_ENABLE(); ADDR_EN_CLK(); ADDR_EN_FF(); ADDR_OP()

#endif //STM_ADAPTER or STM_NES

#ifdef AVR_KAZZO

  // A15-8 are behind AHL flipflop
  // A7-0 are on GPIOA perfectly aligned
  #define ALbank 	GPIOA

  #define ADDR_PU()      	ALbank->PORT = 0xFF
  #define ADDR_IP()      	ALbank->DDR = 0x00
  #define ADDR_OP()      	ALbank->DDR = 0xFF
  #define ADDRL(low)	GPIOA->PORT = low
  //clocks must be initialized, Data bus clear
  #define ADDRH(high)	DATA_OP(); DATA_SET(high); AHL_CLK(); DATA_IP();
  #define ADDR_SET(hword)	ADDRL(hword); ADDRH(hword>>8)

  #define ADDR_EN_FF()	CTL_OP(AHLbank, AHL); CTL_SET_LO(AHLbank, AHL)
  #define ADDR_ENABLE()	DATA_ENABLE(); ADDR_EN_FF(); ADDR_OP();

#endif //AVR_KAZZO

//	---------------------------------------------------------------------------------------
//	FLIPFLOP ADDR PORT 8bit
//
//	This port is present on devices with sega connectors, and SNES if supports EXP pins
//	It's behind the 8x Flipflop to give access to Sega A17-18, #AS, A20-23, #TIME
//	SNES doesn't connect to FF0-3, but FF4-7 connect to /PARD, /PAWR, REFRESH, /WRAMSEL
//	Directionality: All pins are forced output
//	Driver: All pins are push-pull
//	Write/Output: Byte access only, no bit accesses
//	Read/Input: Not supported
//
//	---------------------------------------------------------------------------------------

#if defined(STM_INL6) || defined(STM_INL6_PROTO)

  //These are behind the AFL flipflop similar to how the STM_NES has A8-15 behind AHL flipflop
  //But the Flipflop's inputs are AD0-7
  #define FFADDR_ENABLE()		CTL_OP(AFLbank, AFL); CTL_SET_LO(AFLbank, AFL)
  #define FFADDR_DISABLE()	CTL_IP_PU(AFLbank, AFL);

  //FFADDR must already be enabled
  #define AFL_CLK()		CTL_SET_HI(AFLbank, AFL); CTL_SET_LO(AFLbank, AFL)

  //assumes A0-7 are enabled & outputs, corrupts AD0-15 (sega A1-16), AFL must be enabled & low/clocked
  #define FFADDR_SET(high)	ADDR_SET(high); AFL_CLK();

#endif //STM_INL6

//	---------------------------------------------------------------------------------------
//	EXPANSION PORT 8bit pins #1-8
//
//	This port is present on all devices but implemented differently.
//	This port is primarily targeted as a NES cartridge port to connect to EXP1-8
//	EXP0 has it's own dedicated pin in CTL PORT, EXP9 is dual purposed with LED on AVR/adapters
//	AVR & ADAPTER connect EXP6 to Famicom RF audio (cart output)
//	INL6 dual purposes EXP6, 8, & 9 with CLT PORT AUDL, SWCLK, & AUDR respectively
//	Need some sort of interlock to ensure CTL PORT & EXP PORT don't stop on eachother's shared pins
//	Extra macros are needed to make this port compatible on early versions of AVR KAZZO
//	AVR & Adapter have access via 8x Flipflop
//		-these devices also map these pins to A16-23
//	INL6 has direct pin access
//		-these pins also act as Data8-15 for Sega Genesis
//		-has separate pins dedicated to A16-23
//	STM_NES doesn't use a flipflop, has direct access or dual purposed pinning
// 		EXP1-3,6 has dedicated mcu pin
// 		EXP4-5,7-8 connect to A4-7
//	Directionality: All pins are forced output, or tristate.  This maintains compatability
//		between all devices
//	Driver: All pins are push-pull, AVR & STM ADAPTER drive with 5v signals, INL6 drives with 3.3v
//	Write/Output: Byte access only, no bit accesses
//	Read/Input: Not supported
//
//	---------------------------------------------------------------------------------------

#ifdef STM_INL6_PROTO

  //pins1-5 = GPIOB10-14 (D8-12), pin6 = GPIOA4 (AUDL), pin7 = GPIOB15 (D13), pin8 = GPIOA14 (SWCLK)
  //these defines are quite the mess currently due to pins all over the place
  //there is no real benefit to defining this port as byte wide but defining them this way 'degrades'
  //them to the same quality as AVR making all devices mostly compatible.
  //These can be redefined as CONTROL PORT for simpler pin granuarity access
  #define E157bank 	GPIOB
  #define E68bank 	GPIOA

  #define EXP_PU()	E157bank->PUPDR |= (PUPDR_PU_ALL & 0xFFF00000); E68bank->PUPDR |= (PUPDR_PU_ALL & 0x30000300)
  #define EXP_IP()	E157bank->MODER &=~(MODER_OP_ALL & 0xFFF00000); E68bank->MODER &=~(MODER_OP_ALL & 0x30000300)
  #define EXP_OP()	E157bank->MODER |= (MODER_OP_ALL & 0xFFF00000); E68bank->MODER |= (MODER_OP_ALL & 0x30000300)
  //not sure these bit shift accesses will work if the value passed in is a uint8_t variable...
  #define EXP_SET(val)	E157bank->ODR = ((E157bank->ODR & 0x03FF) | (val<<10 & 0x7C00) | (val<<9 & 0x8000)); E68bank->ODR = ((E68bank->ODR & 0xBFEF) | (val>>1 & 0x0010) | (val<<7 & 0x4000))

  #define EXP_EN_CLK()	RCC->AHBENR |= RCC_AHBENR_EXP
  #define EXP_ENABLE()	ADDR_EN_CLK(); EXP_OP()
  #define EXP_DISABLE()	EXP_PU(); EXP_IP()

#endif //STM_INL6_PROTO

#ifdef STM_INL6

  //pins1-5 = GPIOB2-6 (D8-12), pin6 = GPIOA4 (AUDL), pin7 = GPIOB7 (D13), pin8 = GPIOA14 (SWCLK)
  //these defines are quite the mess currently due to pins all over the place
  //there is no real benefit to defining this port as byte wide but defining them this way 'degrades'
  //them to the same quality as AVR making all devices mostly compatible.
  //These can be redefined as CONTROL PORT for simpler pin granuarity access
  #define E157bank 	GPIOB
  #define E68bank 	GPIOA

  //TODO this is not complete!!!  it's still a copy paste from the prototype
  #define EXP_PU() //E157bank->PUPDR |= (PUPDR_PU_ALL & 0xFFF00000); E68bank->PUPDR |= (PUPDR_PU_ALL & 0x30000300)
  #define EXP_IP() //E157bank->MODER &=~(MODER_OP_ALL & 0xFFF00000); E68bank->MODER &=~(MODER_OP_ALL & 0x30000300)
  #define EXP_OP() //E157bank->MODER |= (MODER_OP_ALL & 0xFFF00000); E68bank->MODER |= (MODER_OP_ALL & 0x30000300)
  //not sure these bit shift accesses will work if the value passed in is a uint8_t variable...
  #define EXP_SET( \
    val) //E157bank->ODR = ((E157bank->ODR & 0x03FF) | (val<<10 & 0x7C00) | (val<<9 & 0x8000)); E68bank->ODR = ((E68bank->ODR & 0xBFEF) | (val>>1 & 0x0010) | (val<<7 & 0x4000))

  #define EXP_EN_CLK()  //RCC->AHBENR |= RCC_AHBENR_EXP
  #define EXP_ENABLE()  //ADDR_EN_CLK(); EXP_OP()
  #define EXP_DISABLE() //EXP_PU(); EXP_IP()

#endif //STM_INL6

#ifdef STM_NES
  //EXP1-3,6 has dedicated mcu pin
  // EXP1:PA1, EXP2:PC14, EXP3:PC15, EXP6:PA2
  //EXP4-5,7-8 connect to A4-7
  // EXP4:A4->PB6, EXP5:A5->PB7, EXP7:A6->PA8, EXP8:A7->PA9
  #define E1678bank 	GPIOA
  #define E45bank 	GPIOB
  #define E23bank 	GPIOC

  //TODO
  #define EXP_PU() //	E157bank->PUPDR |= (PUPDR_PU_ALL & 0xFFF00000); E68bank->PUPDR |= (PUPDR_PU_ALL & 0x30000300)
  #define EXP_IP() //	E157bank->MODER &=~(MODER_OP_ALL & 0xFFF00000); E68bank->MODER &=~(MODER_OP_ALL & 0x30000300)
  #define EXP_OP() //	E157bank->MODER |= (MODER_OP_ALL & 0xFFF00000); E68bank->MODER |= (MODER_OP_ALL & 0x30000300)
  //not sure these bit shift accesses will work if the value passed in is a uint8_t variable...
  #define EXP_SET( \
    val) //	E157bank->ODR = ((E157bank->ODR & 0x03FF) | (val<<10 & 0x7C00) | (val<<9 & 0x8000)); E68bank->ODR = ((E68bank->ODR & 0xBFEF) | (val>>1 & 0x0010) | (val<<7 & 0x4000))

  #define EXP_EN_CLK()  //	RCC->AHBENR |= RCC_AHBENR_EXP
  #define EXP_ENABLE()  //	ADDR_EN_CLK(); EXP_OP()
  #define EXP_DISABLE() //	EXP_PU(); EXP_IP()

#endif //STM_NES

#if defined(STM_ADAPTER) || defined(AVR_KAZZO)

  // EXP1-8 are behind AXL flipflop

  //clocks must be initialized, Data bus clear
  #define EXP_SET(val)	DATA_OP(); DATA_SET(val); AXL_CLK(); DATA_IP()

  #ifdef PURPLE_KAZZO
    #define EXP_EN_FF()	CTL_OP(AXLbank, AXL); CTL_SET_LO(AXLbank, AXL); CTL_OP(FREEbank, FREE); CTL_SET_LO(FREEbank, FREE);
    #define EXP_DISABLE()	CTL_IP_PU(AXLbank, AXL); CTL_IP_PU(FREEbank, FREE)
  #else
    #define EXP_EN_FF()	CTL_OP(AXLbank, AXL); CTL_SET_LO(AXLbank, AXL)
    #define EXP_DISABLE()	CTL_IP_PU(AXLbank, AXL)
  #endif

  #define EXP_ENABLE()	DATA_ENABLE(); CTL_ENABLE(); EXP_EN_FF()

#endif //AVR_KAZZO or STM_ADAPTER

//	---------------------------------------------------------------------------------------
//	DATA PORT 16bit
//
//	This port is only present on later devices typically with Sega connectors
//	Even though early devices have DATA0-7 + EXP1-8, the EXP port is unidirectional
//	Directionality: All pins are bidirectional controlled as a whole
//	Driver: All pins are push-pull, and unknown floating/pull-up when input
//		main reason to be unknown is AVR uses PORT for pull-up enable
//		don't want to require re-enabling pullups for every data access
//		STM32 are default to pull-up, AVR requires manually pulling up
//		by calling DATA16_IP_PU() if pullups required, otherwise unknown
//	Write/Output: Byte access only, no bit accesses.  Must be returned to input after read!
//	Read/Input: Default condition, byte access only
//
//	---------------------------------------------------------------------------------------
//
#ifdef STM_INL6

  //Combine 8bit DATA0-7 and 8bit EXP1-8
  //	//A16-21 are on PB10-15	these also map to EXP1-5, & 7
  //	//A22-23 are on PA9-10 these also map to CIRAM A10 & CIRAM /CE respectively
  //	#define A16_21bank	GPIOB
  //	#define A22_23bank 	GPIOA
  //
  //D0-7 are on PB8-15, D8-13 are on PB2-7
  // MSByte: 7654_3210 LSByte: 13-12-11-10_9-8-X-X
  #define D0_13bank	GPIOB  //all of B except PB0-1
  //D14-15 are on PA9-10
  #define D14_15bank	GPIOA

  //
  //	#define HADDR_PU()	A16_21bank->PUPDR |= (PUPDR_PU_ALL & 0xFFF00000); A22_23bank->PUPDR |= (PUPDR_PU_ALL & 0x003C0000)
  //	#define HADDR_IP()	A16_21bank->MODER &=~(MODER_OP_ALL & 0xFFF00000); A22_23bank->MODER &=~(MODER_OP_ALL & 0x003C0000)
  //	#define HADDR_OP()	A16_21bank->MODER |= (MODER_OP_ALL & 0xFFF00000); A22_23bank->MODER |= (MODER_OP_ALL & 0x003C0000)
  //
  //	#define HADDR_SET(val)	A16_21bank->ODR = ((A16_21bank->ODR&0x03FF) | (val<<10 & 0xFC00)); A22_23bank->ODR = ((A22_23bank->ODR & 0xF9FF) | (val<<3 & 0x0600))

  //IP and OP assume MODER[1] is clear (ie not set to Alt Func)
  //also assume PUPDR is reset default floating
  #define DATA16_IP()	D0_13bank->MODER &= 0x0000000F; D14_15bank->MODER &= 0xFFC3FFFF
  #define DATA16_OP()	D0_13bank->MODER |= (MODER_OP_ALL & 0xFFFFFFF0); D14_15bank->MODER |= (MODER_OP_ALL & 0x003C0000)
  #define DATA16_PU()	D0_13bank->PUPDR |= (PUPDR_PU_ALL & 0xFFFFFFF0); D14_15bank->PUPDR |= (PUPDR_PU_ALL & 0x003C0000)
  //	#define DATA16_IP_PU()	DATA16_IP(); DATA16_PU()

  //	#define DATA_SET(data)		Dbank->ODR = (Dbank->ODR & 0x00FF) | (data<<8)
  #define DATA16L_RD(data) data = ((D0_13bank->IDR >> 8) & 0x00FF)
  // MSByte: 7654_3210 LSByte: 13-12-11-10_9-8-X-X
  #define DATA16H_RD(data)	data = ((D0_13bank->IDR>>2)&0x003F) | ((D14_15bank->IDR>>3)&0x00C0)

  #define DATA16L_SET(data) \
		D0_13bank->ODR = (D0_13bank->ODR & 0x00FF) | ((data & 0x00FF) << 8)

  #define DATA16H_SET(data) \
		D0_13bank->ODR = (D0_13bank->ODR & 0xFF03) | ((data & 0x003F) << 2); \
		D14_15bank->ODR = (D14_15bank->ODR & 0xF9FF) | ((data & 0x00C0) << 3)

  #define DATA16_EN_CLK()	RCC->AHBENR |= RCC_AHBENR_DATA16
  #define DATA16_ENABLE()	DATA16_EN_CLK(); DATA16_IP(); DATA16_PU()

#endif //STM_INL6

//	---------------------------------------------------------------------------------------
//	HIGH ADDRESS PORT 8bits A16-23
//
//	This port is present on all devices with SNES connector
//	Restrictions: CANNOT be used when EXPANSION PORT is enabled
//		CIRAM_A10 & CIRAM /CE cannot be used on CONTROL PORT
//	Directionality: All pins are forced output
//	Driver: All pins are push-pull
//	Write/Output: Byte access only, no bit accesses
//	Read/Input: Not supported
//
//	INL6 dual purposes A22-23 for CIRAM_A10 & CIRAM_CE respectively
//		EXP1-5, & 7 are mapped to A16-21 respectively
//
//	AVR_KAZZO & STM_ADATPER use dual purpose the EXPANSION PORT for this PORT
//		EXP1-8 map to A16-23 respectively
//
//	---------------------------------------------------------------------------------------

#ifdef STM_INL6_PROTO

  //A16-21 are on PB10-15	these also map to EXP1-5, & 7
  //A22-23 are on PA9-10 these also map to CIRAM A10 & CIRAM /CE respectively
  #define A16_21bank	GPIOB
  #define A22_23bank 	GPIOA

  #define HADDR_PU()	A16_21bank->PUPDR |= (PUPDR_PU_ALL & 0xFFF00000); A22_23bank->PUPDR |= (PUPDR_PU_ALL & 0x003C0000)
  #define HADDR_IP()	A16_21bank->MODER &=~(MODER_OP_ALL & 0xFFF00000); A22_23bank->MODER &=~(MODER_OP_ALL & 0x003C0000)
  #define HADDR_OP()	A16_21bank->MODER |= (MODER_OP_ALL & 0xFFF00000); A22_23bank->MODER |= (MODER_OP_ALL & 0x003C0000)

  #define HADDR_SET(val)	A16_21bank->ODR = ((A16_21bank->ODR&0x03FF) | (val<<10 & 0xFC00)); A22_23bank->ODR = ((A22_23bank->ODR & 0xF9FF) | (val<<3 & 0x0600))

  #define HADDR_EN_CLK()	RCC->AHBENR |= RCC_AHBENR_HADDR
  #define HADDR_ENABLE()	HADDR_EN_CLK(); HADDR_OP()
  #define HADDR_DISABLE()	HADDR_PU(); HADDR_IP()

#endif //STM_INL6_PROTO

#ifdef STM_INL6

  //A16-21 are on PB2-7	these also map to EXP1-5, & 7 (changed from prototype)
  //A22-23 are on PA9-10 these also map to CIRAM A10 & CIRAM /CE respectively
  #define A16_21bank	GPIOB
  #define A22_23bank 	GPIOA

  #define HADDR_PU()	A16_21bank->PUPDR |= (PUPDR_PU_ALL & 0x0000FFF0); A22_23bank->PUPDR |= (PUPDR_PU_ALL & 0x003C0000)
  #define HADDR_IP()	A16_21bank->MODER &=~(MODER_OP_ALL & 0x0000FFF0); A22_23bank->MODER &=~(MODER_OP_ALL & 0x003C0000)
  #define HADDR_OP()	A16_21bank->MODER |= (MODER_OP_ALL & 0x0000FFF0); A22_23bank->MODER |= (MODER_OP_ALL & 0x003C0000)

  #define HADDR_SET(val)	A16_21bank->ODR = ((A16_21bank->ODR&0xFF03) | (val<<2 & 0x00FC)); A22_23bank->ODR = ((A22_23bank->ODR & 0xF9FF) | (val<<3 & 0x0600))

  //sega reading D8-15
  //D8-13  are on PB2-7
  //D14-15 are on PA9-10
  #define HDATA_VAL	(((A16_21bank->IDR)&0x00FC)>>2)	| (((A22_23bank->IDR)&0x0600) >>3)
  //can use this to assign:  data = HDATA_VAL

  #define HADDR_EN_CLK()	RCC->AHBENR |= RCC_AHBENR_HADDR
  #define HADDR_ENABLE()	HADDR_EN_CLK(); HADDR_OP()
  #define HADDR_DISABLE()	HADDR_PU(); HADDR_IP()

#endif //STM_INL6

#ifdef STM_NES
//HADDR is NOT PRESENT!
#endif

//#else	//AVR_KAZZO or STM_ADAPTER
#if defined(AVR_KAZZO) || defined(STM_ADAPTER)

  // ADDR16-23 are behind AXL flipflop

  //clocks must be initialized, Data bus clear
  #define HADDR_SET(val)	EXP_SET(val)

  #define HADDR_EN_FF()	EXP_EN_FF()
  #define HADDR_ENABLE()	EXP_ENABLE()
  #define HADDR_DISABLE()	EXP_DISABLE()

#endif //AVR_KAZZO or STM_ADAPTER

//	---------------------------------------------------------------------------------------
//	EXTRA (EXT) PORT
//
//	This port is present on all devices, but all pins aren't necessarily available
//	Intention is for pins on this port to act similar to CONTROL PORT, but require
//	individual enabling as these pins may conflict with other ports.  This is a port
//	that allows rules of other ports to be broken.  For example a single address pin
//	can become bidirectional open drain; which doesn't fit the ADDRESS PORT definition.
//	Another use for this would be to establish a SPI port on a few DATA BUS pins.
//	Other things that make sense here are serial protocols which need conveinent pin
//	macros, but don't make any sense to have individual bit control from host PC.
//	The low level protocol is handled from the firmware side since you would never want
//	to bit bang these from the host.
//
//	Restrictions: Great care must be used when utilizing this port, doing so will often
//		break other ports which the pins are shared with.  Best to disable this port
//		when done with it to then allow the other port to be enabled and initialized.
//		Each pin (set) needs it's own enable, the EXT PORT doesn't get enabled with one
//		macro since typically only one pin (set) is of interest.
//	Directionality: Any allowed, defined separately for each pin
//	Driver: Any allowed, defined separately for each pin
//	Write/Output: Depends on pins, any allowed
//	Read/Input: Depends on pins, any allowed
//
//
//	---------------------------------------------------------------------------------------

#if STM_INL6_PROTO

  // PE0  "A0"	mcupinC0
  #define E0bank 		GPIOC
  #define E0		(0U)

  // PE1  "D0"	mcupinB2
  #define E1bank 		GPIOB
  #define E1		(2U)

  // PE2  "D8"	mcupinB10
  #define E2bank 		GPIOB
  #define E2		(10U)

  // PE3  "D9"	mcupinB11
  #define E3bank 		GPIOB
  #define E3		(11U)

  // PE4  "D10"	mcupinB12
  #define E4bank 		GPIOB
  #define E4		(12U)

#endif //STM_INL6_PROTO

#ifdef STM_INL6

  // PE0  "A0"	mcupinC0
  #define E0bank 		GPIOC
  #define E0		(0U)

  // PE1  "D0"	mcupinB8
  #define E1bank 		GPIOB
  #define E1		(8U)

  // PE2  "D8"	mcupinB2
  #define E2bank 		GPIOB
  #define E2		(2U)

  // PE3  "D9"	mcupinB3
  #define E3bank 		GPIOB
  #define E3		(3U)

  // PE4  "D10"	mcupinB4
  #define E4bank 		GPIOB
  #define E4		(4U)

#endif //STM_INL6

#ifdef STM_NES
  //TODO BLINDLY COPIED FROM STM6, will not work AS-IS
  //TODO actually do this

  // PE0  "A0"	mcupinB2
  // 			TODO!!!
  #define E0bank 		GPIOB
  #define E0		(2U)

  // PE1  "D0"	mcupinB2
  #define E1bank 		GPIOB
  #define E1		(2U)

  // PE2  "D8"	mcupinB10
  #define E2bank 		GPIOB
  #define E2		(10U)

  // PE3  "D9"	mcupinB11
  #define E3bank 		GPIOB
  #define E3		(11U)

  // PE4  "D10"	mcupinB12
  #define E4bank 		GPIOB
  #define E4		(12U)

#endif

#ifdef STM_ADAPTER

  // PE0  "A0"	mcupinB2
  #define E0bank 		GPIOB
  #define E0		(2U)

  // PE1  "D0"	mcupinB8
  #define E1bank 		GPIOB
  #define E1		(8U)

  #define E2nodef
  #define E3nodef
  #define E4nodef

#endif //STM_ADAPTER

#ifdef AVR_KAZZO

  // PE0  "A0"	mcupinA0
  #define E0bank 		GPIOA
  #define E0		(0U)

  // PE1  "D0"	mcupinB0
  #define E1bank 		GPIOB
  #define E1		(0U)

  #define E2nodef
  #define E3nodef
  #define E4nodef

#endif //AVR_KAZZO

////////////////////////////////////////////////////////////////////////////////
//	PORT E pin mappings
////////////////////////////////////////////////////////////////////////////////

//STM8 SWIM PINS A0 & D0 depending on cartridge
#define A0 		E0
#define A0bank		E0bank

#define D0 		E1
#define D0bank		E1bank

//JTAG pins for INL6
#if defined(STM_INL6_PROTO) || defined(STM_INL6)

  //TDI
  #define D8 		E2
  #define D8bank		E2bank

  //TMS
  #define D9 		E3
  #define D9bank		E3bank

  //TCK
  #define D10 		E4
  #define D10bank		E4bank

#endif //JTAG INL6

//#ifdef STM_CORE
#if defined(STM_INL6_PROTO) || defined(STM_INL6)

  #define EXT_IP_PU(bank, pin)		bank->MODER &= ~(MODER_OP<<(pin*2)); bank->PUPDR |=  (PUPDR_PU<<(pin*2))
  #define EXT_IP_FL(bank, pin)		bank->MODER &= ~(MODER_OP<<(pin*2)); bank->PUPDR &= ~(PUPDR_PU<<(pin*2))
  #define EXT_OP(bank, pin)		bank->MODER |=  (MODER_OP<<(pin*2))
  #define EXT_OD(bank, pin)		bank->OTYPER |=  (OTYPER_OD<<(pin))	//open drain has no effect when pin is input
  #define EXT_PP(bank, pin)		bank->OTYPER &= ~(OTYPER_OD<<(pin))
  #define EXT_SET_LO(bank, pin)		bank->BRR = 1<<pin
  #define EXT_SET_HI(bank, pin)		bank->BSRR = 1<<pin
  #define EXT_RD(bank, pin, val)		val = (bank->IDR & (1<<pin))
  //NOTE: STM registers are 16bit "halfwords" so must provide a 16bit val

  //each pin needs it's own enable macro
  #define EXT_A0_ENABLE()		ADDR_EN_CLK()	//unnecessarily enables both GPIO banks for STM adapter, oh well
  #define EXT_D0_ENABLE()		DATA_EN_CLK()
  #define EXT_D8_10_ENABLE()	DATA_EN_CLK()

#endif //STM_CORE

#if defined(STM_NES) || defined(STM_ADAPTER)

  #define EXT_IP_PU(bank, pin)		bank->MODER &= ~(MODER_OP<<(pin*2)); bank->PUPDR |=  (PUPDR_PU<<(pin*2))
  #define EXT_IP_FL(bank, pin)		bank->MODER &= ~(MODER_OP<<(pin*2)); bank->PUPDR &= ~(PUPDR_PU<<(pin*2))
  #define EXT_OP(bank, pin)		bank->MODER |=  (MODER_OP<<(pin*2))
  #define EXT_OD(bank, pin)		bank->OTYPER |=  (OTYPER_OD<<(pin))	//open drain has no effect when pin is input
  #define EXT_PP(bank, pin)		bank->OTYPER &= ~(OTYPER_OD<<(pin))
  #define EXT_SET_LO(bank, pin)		bank->BRR = 1<<pin
  #define EXT_SET_HI(bank, pin)		bank->BSRR = 1<<pin
  #define EXT_RD(bank, pin, val)		val = (bank->IDR & (1<<pin))
  //NOTE: STM registers are 16bit "halfwords" so must provide a 16bit val

  //each pin needs it's own enable macro
  #define EXT_A0_ENABLE()		ADDR_EN_CLK()	//unnecessarily enables both GPIO banks for STM adapter, oh well
  #define EXT_D0_ENABLE()		DATA_EN_CLK()
  #define EXT_D8_10_ENABLE()	DATA_EN_CLK()

#endif

#ifdef AVR_CORE

  #define EXT_IP_PU(bank, pin)		bank->DDR &= ~(1<<pin); bank->PORT |=  (1<<pin)
  #define EXT_IP_FL(bank, pin)		bank->DDR &= ~(1<<pin); bank->PORT &= ~(1<<pin)
  #define EXT_OP(bank, pin)		bank->DDR |=  (1<<pin)
  #define EXT_SET_LO(bank, pin)		bank->PORT &= ~(1<<pin)
  #define EXT_SET_HI(bank, pin)		bank->PORT |=  (1<<pin)
  #define EXT_RD(bank, pin, val)		val = (uint16_t) (bank->PIN & (1<<pin))

  //each pin needs it's own enable macro
  #define EXT_A0_ENABLE() //nothing to be done for AVR
  #define EXT_D0_ENABLE() //nothing to be done for AVR

#endif //AVR_CORE

#endif //file end
