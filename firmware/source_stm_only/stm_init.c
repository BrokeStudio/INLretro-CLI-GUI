
#include "stm_init.h"


/* stm32f0x2 devices have HSI48 available which isn't on stm32f0x0 devices
 * I'm primarily targetting f070 devices which will require external xtal
 * Most generic setup would be to use HSI 8MHz * PLL which is available on all devices
 * but can't keep all devices running at 16Mhz while also properly clocking usb with that setup.
 *
 * After reset all devices select HSI 8MHz as SYSCLK
 * To prevent usb over/under run problems, APB clock must be atleast 10Mhz
 * 070 can only use PLL to feed USB clock.
 *
 * Current goal is to have PLL output 48Mhz from a 16Mhz HSE to support 070 devices
 * 072 devices won't have ext xtal though, and use HSI 48Mhz for usb block
 * Would like to have SYSCLK = 16Mhz to align stm32 and avr kazzo devices core clocks for now
 * Have to also supply APB with 10Mhz or more, which is derived from SYSCLK with AHB & APB dividers
 *
 * While these goals are possible, we have to code them based on 072/070 devices
 * 072: HSI 8Mhz -> PLL * 2 = 16Mhz -> SYSCLK -> no division to AHB & APB clocks
 * 	HSI 48Mhz -> USB block
 * 070: HSE 16Mhz -> PLL * 4 = 48Mhz -> USB block
 * 	HSE 16Mhz -> SYSCLK -> no division to AHB & APB clocks
 *
 * 	Difference between these two is the PLL.  
 * 	072 uses PLL to create 16Mhz SYSCLK from HSI, USB fed directly from HSI 48Mhz
 * 		-HSE not available/used on 072
 * 	070 uses PLL to create 48Mhz for USB from HSE, SYSCLK fed directly from 16Mhz HSE.
 * 		-HSI not used for anything on 070
 */

//pick define based on xtal setup for init_clock and init_usb_clock functions
//#define NO_XTAL
#ifdef STM_INL6
	#define XTAL_8Mhz
#else	//kaz6 prototype & stm adapter have 16Mhz xtal
	//#define XTAL_16Mhz
	#define XTAL_8Mhz
#endif
void init_clock()
{
#ifdef NO_XTAL // setup PLL for HSI * 2 = 16Mhz and set SYSCLK to use it
	
	// To modify the PLL configuration, proceed as follows:
	// 1.Disable the PLL by setting PLLON to 0.
	// 2. Wait until PLLRDY is cleared. The PLL is now fully stopped.
	// * PLL is off and unlocked after reset
	
	// 3. Change the desired parameter.
	// * PLL MUL is set to *2 at reset

	// 4. Enable the PLL again by setting PLLON to 1.
	// 5. Wait until PLLRDY is set.
	
//Copied from reference manual optimizations possible assuming post-reset
//Cut out parts not needed due to values @ reset, saved 60Bytes!
//	/* (1) Test if PLL is used as System clock */
//	if ((RCC->CFGR & RCC_CFGR_SWS) == RCC_CFGR_SWS_PLL) {
//		RCC->CFGR &= (uint32_t) (~RCC_CFGR_SW); /* (2) Select HSI as system clock */
//		while ((RCC->CFGR & RCC_CFGR_SWS) != RCC_CFGR_SWS_HSI) /* (3) Wait for HSI switched */
//		{ /* For robust implementation, add here time-out management */ }
//	}
//
//	RCC->CR &= (uint32_t)(~RCC_CR_PLLON);/* (4) Disable the PLL */
//	while((RCC->CR & RCC_CR_PLLRDY) != 0) /* (5) Wait until PLLRDY is cleared */
//	{ /* For robust implementation, add here time-out management */ }
//
//	/* (6) Set the PLL multiplier to 2-16 all integers */
//	RCC->CFGR = (RCC->CFGR & ~RCC_CFGR_PLLMUL) | RCC_CFGR_PLLMUL2; /* PLLMUL set to *2 at reset) */

//	// PLL PREDIV should be getting set to zero too!  They just assumed not present/reset values...
//	RCC->CFGR = (RCC->CFGR & ~RCC_CFGR_PLLSRC) | RCC_CFGR_PLLSRC_HSI_PREDIV; /* PLLMUL set to *2 at reset) */

//	// They also didn't address flash wait states!
//	FLASH->ACR |= (uint32_t) 0x01;	//If >24Mhz SYSCLK, must add wait state to flash

//	PREDIV is / 2 post reset, so PLL is being sourced with 4Mhz
	RCC->CFGR = (RCC->CFGR & ~RCC_CFGR_PLLMUL) | RCC_CFGR_PLLMUL4; /* PLLMUL set to *2 at reset) */
	RCC->CR |= RCC_CR_PLLON; /* (7) Enable the PLL */
	while((RCC->CR & RCC_CR_PLLRDY) == 0) /* (8) Wait until PLLRDY is set */
	{ /* For robust implementation, add here time-out management */ }

	RCC->CFGR |= (uint32_t) (RCC_CFGR_SW_PLL); /* (9) Select PLL as system clock */
	while ((RCC->CFGR & RCC_CFGR_SWS) != RCC_CFGR_SWS_PLL) /* (10) Wait until the PLL is switched on */
	{ /* For robust implementation, add here time-out management */ }

#endif
	
#ifdef XTAL_8Mhz

	//Turn on HSE
	/* (2) Enable the CSS
	 * Enable the HSE and set HSEBYP to use the internal clock
	 * Enable HSE */
	RCC->CR |= (RCC_CR_CSSON | RCC_CR_HSEON); /* (2) */

	/* (1) Check the flag HSE ready */
	while ((RCC->CR & RCC_CR_HSERDY) == 0) /* (1) */
	{ /*spin while waiting for HSE to be ready */	}


	/* (3) Switch the system clock to HSE */
	//at startup HSI is selected SW = 00
	RCC->CFGR |= RCC_CFGR_SW_HSE;

	//TODO poll RCC->CFGR SWS bits to ensure sysclk switched over

	//Now the SYSCLK is running directly off the HSE 16Mhz xtal

	/* (1) Test if PLL is used as System clock */
//	if ((RCC->CFGR & RCC_CFGR_SWS) == RCC_CFGR_SWS_PLL) {
//		RCC->CFGR &= (uint32_t) (~RCC_CFGR_SW); /* (2) Select HSI as system clock */
//		while ((RCC->CFGR & RCC_CFGR_SWS) != RCC_CFGR_SWS_HSI) /* (3) Wait for HSI switched */
//		{ /* For robust implementation, add here time-out management */ }
//	}
//
//	RCC->CR &= (uint32_t)(~RCC_CR_PLLON);/* (4) Disable the PLL */
//	while((RCC->CR & RCC_CR_PLLRDY) != 0) /* (5) Wait until PLLRDY is cleared */
//	{ /* For robust implementation, add here time-out management */ }

	//Set PLL Source to HSE, the PLL must be off to do this
	RCC->CFGR |= RCC_CFGR_PLLSRC_HSE_PREDIV;	//by default HSE isn't divided
	
	////Set PLL to 16 * 3 = 48Mhz for USB
	////RCC->CFGR = (RCC->CFGR & ~RCC_CFGR_PLLMUL) | RCC_CFGR_PLLMUL3; /* PLLMUL set to *2 at reset) */
	//RCC->CFGR |= RCC_CFGR_PLLMUL3; /* PLLMUL set to *2 at reset) */
	//RCC->CR |= RCC_CR_PLLON; /* (7) Enable the PLL */
	//while((RCC->CR & RCC_CR_PLLRDY) == 0) /* (8) Wait until PLLRDY is set */
	//{ /* For robust implementation, add here time-out management */ }
	//
	//Set PLL to 8 * 6 = 48Mhz for USB
	//RCC->CFGR = (RCC->CFGR & ~RCC_CFGR_PLLMUL) | RCC_CFGR_PLLMUL3; /* PLLMUL set to *2 at reset) */
	RCC->CFGR |= RCC_CFGR_PLLMUL6; /* PLLMUL set to *2 at reset) */
	RCC->CR |= RCC_CR_PLLON; /* (7) Enable the PLL */
	while((RCC->CR & RCC_CR_PLLRDY) == 0) /* (8) Wait until PLLRDY is set */
	{ /* For robust implementation, add here time-out management */ }

	//test SYSCLK with 48Mhz
//	FLASH->ACR |= (uint32_t) 0x01;	//If >24Mhz SYSCLK, must add wait state to flash
//	RCC->CFGR = (RCC->CFGR & ~RCC_CFGR_SW) | RCC_CFGR_SW_PLL; /* (9) Select PLL as system clock */
//	while ((RCC->CFGR & RCC_CFGR_SWS) != RCC_CFGR_SWS_PLL) /* (10) Wait until the PLL is switched on */
//	{ /* For robust implementation, add here time-out management */ }

#endif


#ifdef XTAL_16Mhz

	//Turn on HSE
	/* (2) Enable the CSS
	 * Enable the HSE and set HSEBYP to use the internal clock
	 * Enable HSE */
	RCC->CR |= (RCC_CR_CSSON | RCC_CR_HSEON); /* (2) */

	/* (1) Check the flag HSE ready */
	while ((RCC->CR & RCC_CR_HSERDY) == 0) /* (1) */
	{ /*spin while waiting for HSE to be ready */	}


	/* (3) Switch the system clock to HSE */
	//at startup HSI is selected SW = 00
	RCC->CFGR |= RCC_CFGR_SW_HSE;

	//TODO poll RCC->CFGR SWS bits to ensure sysclk switched over

	//Now the SYSCLK is running directly off the HSE 16Mhz xtal

	/* (1) Test if PLL is used as System clock */
//	if ((RCC->CFGR & RCC_CFGR_SWS) == RCC_CFGR_SWS_PLL) {
//		RCC->CFGR &= (uint32_t) (~RCC_CFGR_SW); /* (2) Select HSI as system clock */
//		while ((RCC->CFGR & RCC_CFGR_SWS) != RCC_CFGR_SWS_HSI) /* (3) Wait for HSI switched */
//		{ /* For robust implementation, add here time-out management */ }
//	}
//
//	RCC->CR &= (uint32_t)(~RCC_CR_PLLON);/* (4) Disable the PLL */
//	while((RCC->CR & RCC_CR_PLLRDY) != 0) /* (5) Wait until PLLRDY is cleared */
//	{ /* For robust implementation, add here time-out management */ }

	//Set PLL Source to HSE, the PLL must be off to do this
	RCC->CFGR |= RCC_CFGR_PLLSRC_HSE_PREDIV;	//by default HSE isn't divided
	
	//Set PLL to 16 * 3 = 48Mhz for USB
	//RCC->CFGR = (RCC->CFGR & ~RCC_CFGR_PLLMUL) | RCC_CFGR_PLLMUL3; /* PLLMUL set to *2 at reset) */
	RCC->CFGR |= RCC_CFGR_PLLMUL3; /* PLLMUL set to *2 at reset) */
	RCC->CR |= RCC_CR_PLLON; /* (7) Enable the PLL */
	while((RCC->CR & RCC_CR_PLLRDY) == 0) /* (8) Wait until PLLRDY is set */
	{ /* For robust implementation, add here time-out management */ }

	//test SYSCLK with 48Mhz
//	FLASH->ACR |= (uint32_t) 0x01;	//If >24Mhz SYSCLK, must add wait state to flash
//	RCC->CFGR = (RCC->CFGR & ~RCC_CFGR_SW) | RCC_CFGR_SW_PLL; /* (9) Select PLL as system clock */
//	while ((RCC->CFGR & RCC_CFGR_SWS) != RCC_CFGR_SWS_PLL) /* (10) Wait until the PLL is switched on */
//	{ /* For robust implementation, add here time-out management */ }

#endif

	// The USB peripheral logic uses a dedicated clock. The frequency of this
	// dedicated clock is fixed by the requirements of the USB standard at 48 MHz, 
	// and this can be different from the clock used for the interface to the APB bus. 
	// Different clock configurations are possible where the APB clock frequency can be higher or lower than the USB peripheral
	// one.
	// Due to USB data rate and packet memory interface requirements, 
	// the APB clock must have a minimum frequency of 10 MHz to avoid data overrun/underrun problems.
	
	//AHB APB clock setup:
	//these are not divided by default
	
}

//pick define based on xtal setup for init_clock and init_usb_clock functions
//#define NO_XTAL
#define EXTERNAL_XTAL
void init_usb_clock()
{
	// stm32f0x2 devices have HSI 48Mhz available to clock usb block, or PLL if it's source accurate enough
	// stm32f0x0 devices must have ext xtal and use PLL output to drive usb block
	
#ifdef EXTERNAL_XTAL
	//by default the 072 has HSI 48Mhz selected as USB clock
	//on the 070 this equates to off, so 070 must set USBSW bit
	RCC->CFGR3 |= RCC_CFGR3_USBSW_PLLCLK;
#endif

#ifdef NO_XTAL
	//Turn on HSI48 supposedly it will turn itself on if USB is enabled with HSI48 selected as clock
	RCC->CR2 |= RCC_CR2_HSI48ON;

	while ((RCC->CR2 & RCC_CR2_HSI48RDY) != RCC_CR2_HSI48RDY) /* (10) Wait until the HSI48 is stable */
	{ /* For robust implementation, add here time-out management */ }

	//by default the 072 has HSI 48Mhz selected as USB clock
	RCC->CFGR3 &= ~RCC_CFGR3_USBSW_Msk;
	//on the 070 this equates to off, so 070 must set USBSW bit
	//CRS system must be turned on to keep HSI 48Mhz calibrated
	RCC->APB1ENR |= RCC_APB1ENR_CRSEN;
	//Default settings are good using SOF packets for calibration
#endif

	//enable USB block by providing clock
	RCC->APB1ENR |= RCC_APB1ENR_USBEN;


}


