
#include "usb.h"
#include "io.h"
#include "buffer.h"
#include "bootload.h"
#include "jtag.h"

#ifdef AVR_CORE
	#include <avr/interrupt.h>
	#include <avr/wdt.h>
	#include <util/delay.h>
	#include "usbdrv.h"
#endif

#ifdef STM_CORE
	#include <stm32f0xx.h>
	#include "../source_stm_only/stm_init.h"
#endif


#ifdef AVR_CORE
void wdt_off(void)
{
//	__disable_interrupt();
//	__watchdog_reset();
	/* Clear WDRF in MCUSR */
	MCUSR &= ~(1<<WDRF);
	/* Write logical one to WDCE and WDE */
	/* Keep old prescaler setting to prevent unintentional
	 * time-out */
	WDTCSR |= (1<<WDCE) | (1<<WDE);
	/* Turn off WDT */
	WDTCSR = 0x00;
//	__enable_interrupt();
}
#endif

int main(void)
{

#ifdef AVR_CORE
	//set watch dog timer with 1 second timer
	wdt_enable(WDTO_1S);
//	wdt_off();
	/* Even if you don't use the watchdog, turn it off here. On newer devices,
	 * the status of the watchdog (on/off, period) is PRESERVED OVER RESET!
	 */
	/* RESET status: all port bits are inputs without pull-up.
	 * That's the way we need D+ and D-. Therefore we don't need any
	 * additional hardware initialization.
	 */

	//initialize V-usb driver before interupts enabled and entering main loop
	usbInit();
	//disconnect from host enforce re-enumeration, interupts must be disabled during this.
	usbDeviceDisconnect();

	//fake USB disconnect for over 250ms
	uint8_t index = 0;
	while(--index){		//loop 256 times
		wdt_reset();	//keep wdt happy during this time
		_delay_ms(1);	//delay 256msec
	}

	//reconnect to host
	usbDeviceConnect();


	//enable interrupts
	sei();
#endif

#ifdef STM_CORE

	//INDEPENDENT WATCH DOG TIMER
	//has it's own clock circuit so even if the main clock fails the WDT
	//will keep running, it's not as accurate as the System Window WDT
	//but we don't care about accuracy for our needs.
	//
	//I can't make sense of the window option, so let's not bother with it..
	//
	//Configuring the IWDG when the window option is disabled
	// When the window option it is not used, the IWDG can be configured as follows:
	// 1.Enable the IWDG by writing 0x0000 CCCC in the IWDG_KR register.
#define wdt_enable() 	IWDG->KR = 0x0000CCCC
	wdt_enable();
	// 2. Enable register access by writing 0x00005555 in the IWDG_KR register.
	IWDG->KR = 0x00005555;
	//After this point the IWDG timer can NEVER be shut off, except via reset..
	// 3. Write the IWDG prescaler by programming IWDG_PR from 0 to 7.
	// default is zero divider / 4
	// 40Khz clock input to prescaler
	// divided by 4 = 10Khz
	IWDG->PR = 2;	// divided by 16 = 2.5Khz
	// 4. Write the reload register (IWDG_RLR).
	//12bit value that gets loaded into WDcounter each time counter is refreshed
	//10Khz clock -> 1sec, need a value of 10,000 = 0x2710 too big
	//12bit counter has max value of 4095
	//2.5Khz clock -> 1sec, need value of 2500 ~= 2560 = 0xA00
	IWDG->RLR = 0x0A00;
	// 5. Wait for the registers to be updated (IWDG_SR = 0x00000000).
	while( IWDG->SR ) { /* forever */ }
	// 6. Refresh the counter value with IWDG_RLR (IWDG_KR = 0x0000 AAAA)
	wdt_reset();
	//call this function atleast once a second to keep the device from resetting

	//remap system memory (including vector table)
//	SYSCFG->CFGR1 = 0x00000002;	//boot value (BOOT1:0 = 0b10	
//	SYSCFG->CFGR1 = 0x00000001;	//map sysmem bootloader to 0x00000000
	//SYSCFG->CFGR1 |= SYSCFG_CFGR1_MEM_MODE_ | 0x0001;	
	//jump to bootloader
//	jump_to_bootloader();
//	jump_to_addr(0x1FFFC519);

	//System is running at reset defaults
	
	//Default clock is in operation
	//Change system clock as needed
	init_clock();

	
	//now enable GPIO and set

//trying to move to 48Mhz clock for all STM32 cores
	//If >24Mhz SYSCLK, must add wait state to flash
	//can also enable prefetch buffer
	FLASH->ACR = FLASH_ACR_PRFTBE | 0x0001;	
	//switch to 48Mhz
	RCC->CFGR = (RCC->CFGR & ~RCC_CFGR_SW) | RCC_CFGR_SW_PLL;
	
	//Initialize periphery clocks as needed
	//tried to have this done but usb code but wasn't working..
	//having the main handle this prob makes more sense anyway, but would like to know
	//why this didn't work..
	init_usb_clock();
	
	
	//init_usb();
	//don't call the USB code directly,
	//instead set the usb flag to tell it to initialize then jump to the USB ISR
	//we know where the USB ISR is because of the vector table	
	usbflag = INITUSB;

	typedef void (*pFunction)(void);
	pFunction JumpToApplication;
	//interrupts should already be disabled
	JumpToApplication = (void (*)(void)) (*((uint32_t *) ((0x000000BC))));	//USB ISR vector location

	//Jump to the USB ISR
	JumpToApplication();

	//set the usb_buff ram function pointers to USB ISR can use them
	usbfuncwrite = (uint32_t) &usbFunctionWrite;  //should only assign lower 16bits
	usbfuncsetup = (uint32_t) &usbFunctionSetup;    //should only assign lower 16bits

	//Initialize WDT, core features, etc

	//enable interrupts
	__enable_irq();		//clear's processor PRIMASK register bit to allow interrupts to be taken
	//I think this gets done automatically when enabling individual IRQs
	
	//Initialize io, periphery, etc
	//setup LED as outputs and turn them on
	//setup user switch as input


#endif

	//intialize i/o and LED to pullup state
	io_reset();

//this is just a quick hack to allow measuring HSE with a scope w/o loading the circuit with probes.
//#define DRIVE_MCO
#ifdef DRIVE_MCO
	//drive HSE (8Mhz) divided by 8 = 1Mhz for crystal load capacitor calibration
	RCC->CFGR = (RCC->CFGR & ~RCC_CFGR_MCOPRE) | RCC_CFGR_MCOPRE_DIV8; 	/* MCO prescaler = div 8 */
	//RCC->CFGR = (RCC->CFGR & ~RCC_CFGR_MCOPRE) | RCC_CFGR_MCOPRE_DIV16; 	/* MCO prescaler = div 16 */
	RCC->CFGR = (RCC->CFGR & ~RCC_CFGR_MCO) | RCC_CFGR_MCO_HSE; 		/* MCO source HSE */
	//enable GPIO pin PA8 MCO AF0
	//RCC->AHBENR |= RCC_AHBENR_GPIOAEN;
	//CTL_ENABLE();
	nes_init();
	//GPIOA->MODER = MODER_AF << (2*8U);	//set PA8 to AF
	GPIOA->MODER = 0x28020000;	//set PA14, PA13, (SWD) &  PA8 (MCO) to AF
	//AF0 is the default value of GPIOx_AFRH/L registers so MCO is already selected as AF in use
#endif

	//initialize jtag engine to be off
	pbje_status = PBJE_OFF;

	//=================
	//MAIN LOOP
	//=================
	while (1) {

		//pet the watch doggie to keep him happy
#ifdef STM_CORE
		wdt_reset();	
#endif

#ifdef AVR_CORE
		wdt_reset();	
		//must call at regular intervals no longer than 50msec
		//keeps 8Byte EP buffer moving from what I understand
		usbPoll();	
#endif

		//check buffer status' and instruct them to 
		//flash/dump as needed to keep data moving
		//currently assuming this operation doesn't take longer
		//than 50msec to meet usbPoll's req't
		//considering using a timer counter interupt to call
		//usbPoll more often but going to see how speed is 
		//impacted first..
		//256Bytes * 20usec Tbp = 5.12msec programming time 
		//+ cpu operations that can't be hid behind flash wait time
		//another thought would be to call usbPoll mid programming
		//a few times to prevent incoming data from being delayed too long
		update_buffers();

		//if paul's basic jtag engine "PBJE" is running, main
		//thread needs to call engine at periodic intervals to keep it
		//running.
		if (pbje_status != PBJE_OFF) {
			jtag_run_pbje();
		}
	}
}
