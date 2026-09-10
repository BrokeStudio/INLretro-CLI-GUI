/* Linker script to configure memory regions.
 * Need modifying for a specific board.
 *   FLASH.ORIGIN: starting address of flash
 *   FLASH.LENGTH: length of flash
 *   RAM.ORIGIN: starting address of RAM bank 0
 *   RAM.LENGTH: length of RAM bank 0
 */
MEMORY
{
	/* STM32F07x */
	/* $0000 0000 128KB of flash/sram depending on BOOT */
	/* $0002 0000 ~128MB of system reserved */
	/* $0800 0000 always flash size depends on part */
/*  FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 128K */ 		/* 0x20000 128K 070RB */
  FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 32K  		/* 0x08000 32K  070C6 */
/*  FLASH0 (rx) : ORIGIN = 0x08000000, LENGTH = 2K  */ /* 0x0800 2K vectors, usb, firmware update, etc */
/*  FLASH1 (rx) : ORIGIN = 0x08000800, LENGTH = 30K */ /* 0x7800 30K reset, main, & application code */
/*  FLASH2 (rx) : ORIGIN = 0x08008000, LENGTH = 96K */ /* RB ONLY 0x18000 96K */
	/* $0802 0000 ~384MB of system reserved */
  	/* $1FFF C400 13KB of system memory (bootloader and etc) 070C6 */
  	/* $1FFF C800 12KB of system memory (bootloader and etc) 070RB */
  	/* $1FFF F800 2KB of option bytes */
  	/* $2000 0000 always SRAM size depends on part */
/*  RAM  (rwx) : ORIGIN = 0x20000000, LENGTH = 16K */ 		/* 0x04000  16K 070RB */
  RAM  (rwx) : ORIGIN = 0x20000000, LENGTH = 6K 		/* 0x01800  6K  070C6 */
	/* $2000 4000 ~512MB of system reserved */
	/* $4000 0000 128KB of APB perif regs & reserved */
	/* $4002 0000 17KB of AHB1 perif regs & reserved */
  	/* $4002 4400 ~128MB system reserved */
  	/* $4800 0000 6KB AHB2 GPIO perif refs */
  	/* $4800 1800 ~384MB system reserved */
  	/* $E000 0000 1MB Cortex M0 internal peripherals */
  	/* $E010 0000 511MB system reserved */
}

/* Linker script to place sections and symbol values. Should be used together
 * with other linker script that defines memory regions FLASH and RAM.
 * It references following symbols, which must be defined in code:
 *   Reset_Handler : Entry of reset handler
 *
 * It defines following symbols, which code can use without definition:
 *   __exidx_start
 *   __exidx_end
 *   __copy_table_start__
 *   __copy_table_end__
 *   __zero_table_start__
 *   __zero_table_end__
 *   __etext
 *   __data_start__
 *   __preinit_array_start
 *   __preinit_array_end
 *   __init_array_start
 *   __init_array_end
 *   __fini_array_start
 *   __fini_array_end
 *   __data_end__
 *   __bss_start__
 *   __bss_end__
 *   __end__
 *   end
 *   __HeapLimit
 *   __StackLimit
 *   __StackTop
 *   __stack
 */
ENTRY(Reset_Handler)

SECTIONS
{
	.text :
	{
		/* First 2KByte of flash EXCLUDES all application & main code */
		/* start with vector table */
		KEEP(*(.isr_vector))

		/* then USB code & desc tables */
		*(.usb_driver)
		*(.usb_desc)

		/* hardfault & dummy handlers */
		*(.hardfault)

		/*this contains vital code for fwupdater appears to be some case statement helper..*/
		*_thumb1_case_uqi.o	/* about 50 bytes */
		/* his freinds are 50 Bytes each as well don't seem to be required
		 * but lets include them for now anyway.  Perhaps we can move them
		 * if we're ~100 bytes short at some point */
		*_thumb1_case_shi.o	/*this disappeared when updating from gcc version 6.2.1 20161205
					 *to version 7.3.1 20180622 but we'll keep it here anyway */
		*_thumb1_case_uhi.o

		/* put firmware update code at end of first 2KByte
		 * should allow for easier updating of that code alone
		 * by the application code if desired */
		*(.fw_update)

		/* when created there was about 132 Bytes of free space here */

		/* fwupdate main needs to be in a fixed location */
		. = 0x0770;
		*(.fw_up_main)

		/* when created there was about 32Bytes free space here */

		/* THIS IS THE END OF THE USB DRIVER & FIRMWARE UDPATER SECTION */


		. = 0x0800;	/*update the location counter to the 3rd KByte */

		*(.appver)	/* 4 Bytes characters ie: "AV01" */
		/* can't get this to work right now, just manually add to binary before releasing.. */

		. = 0x0804;
		/* reset handler fixed to 0x08000804
		 * that way the vector table should always be accurate */
		*(.reset_handler)

		/* usbFunctionSetup & usbFunctionWrite must be in first 64KByte of flash
		 * make Write first, and Setup last since Write is less likely to change
		 * or maybe we just want to make them fixed addresses and avoid use of usb_buff
		 * function pointers, possible future TODO for speedup? */
		*(.usbFuncWrite)
		*(.usbFuncSetup)

		/* then everything else (application code) follows */

		*(.text*)

		/* GCC LIBRARIES */
		/* Had issues with fwupdater breaking when my switch case got so big
		 * turns out it must have been calling _thumb1_case_uqi.o library function
		 * because whenever the sector with that library got stomped the mcu went
		 * to hard fault (code that was being executed got erased)
		 * 'quick' fix was to move that library function to fw_update section
		 * went ahead and moved his case freinds as well.
		 *
		 * Possible that this issue could arise again if the fwupdate code calls
		 * other library functions.  I was able to move most of them with the
		 * linker script, but not the libgcc.a ones.  Kept getting a linker
		 * error with .text having both .exidx and .extab sections.  Apparently
		 * these are for some C++ stack unrolling and exception handling
		 * I don't even think I want these, and the fwupdater certainly shouldn't
		 * need them.  So just leave them were they land normally at the end of .text
		 * section.  If we run out of flash space some day they can probably
		 * just get left out of the binary.  I tried to turn them off but failed..
		 * don't care anymore, fixed my problem, I've banged my head enough for today
		 */

		/* *\lib*.a:*  */
		/* *\libgcc.a:* */
		/* these are causing compiler issues, but honestly I don't want them anyway! */
		/* some C++ junk about unwinding the stack and raising exeptions. */
		/* *unwind-arm.o */
		/* *pr-support.o */
		/* *libunwind.o */  /*this one is movable I don't think I want it anyway!*/

		/* some movable library code that doesn't seem to be relied upon by fwupdater
		 * if the fwupdater fails at somepoint may want to see if it's calling
		 * code from these libraries and move them to fwupdate space
		*\libg.a:*	 <- includes things like memcpy
		*\libnosys.a:*
		*\crti.o:*
		*/

		/*	these got moved to fwupdate section, but so far only the first is used
		*_thumb1_case_uqi.o
		*_thumb1_case_shi.o
		*_thumb1_case_uhi.o
		*/

		*(.init)
		*(.fini)

		/* .ctors */
		*crtbegin.o(.ctors)
		*crtbegin?.o(.ctors)
		*(EXCLUDE_FILE(*crtend?.o *crtend.o) .ctors)
		*(SORT(.ctors.*))
		*(.ctors)

		/* .dtors */
 		*crtbegin.o(.dtors)
 		*crtbegin?.o(.dtors)
 		*(EXCLUDE_FILE(*crtend?.o *crtend.o) .dtors)
 		*(SORT(.dtors.*))
 		*(.dtors)

		*(.rodata*)

		*(.eh_frame*)
	} > FLASH = 0xFF	/* fill with 0xFF 'erased' */

	.ARM.extab :
	{
		*(.ARM.extab* .gnu.linkonce.armextab.*)
	} > FLASH

	__exidx_start = .;
	.ARM.exidx :
	{
		*(.ARM.exidx* .gnu.linkonce.armexidx.*)
	} > FLASH
	__exidx_end = .;

	/* To copy multiple ROM to RAM sections,
	 * uncomment .copy.table section and,
	 * define __STARTUP_COPY_MULTIPLE in startup_ARMCMx.S */
	/*
	.copy.table :
	{
		. = ALIGN(4);
		__copy_table_start__ = .;
		LONG (__etext)
		LONG (__data_start__)
		LONG (__data_end__ - __data_start__)
		LONG (__etext2)
		LONG (__data2_start__)
		LONG (__data2_end__ - __data2_start__)
		__copy_table_end__ = .;
	} > FLASH
	*/

	/* To clear multiple BSS sections,
	 * uncomment .zero.table section and,
	 * define __STARTUP_CLEAR_BSS_MULTIPLE in startup_ARMCMx.S */
	/*
	.zero.table :
	{
		. = ALIGN(4);
		__zero_table_start__ = .;
		LONG (__bss_start__)
		LONG (__bss_end__ - __bss_start__)
		LONG (__bss2_start__)
		LONG (__bss2_end__ - __bss2_start__)
		__zero_table_end__ = .;
	} > FLASH
	*/

	/* Location counter can end up 2byte aligned with narrow Thumb code but
	   __etext is assumed by startup code to be the LMA of a section in RAM
	   which must be 4byte aligned */
	__etext = ALIGN (4);

	.data : AT (__etext)
	{
		__data_start__ = .;
		*(vtable)
		*(.data*)

		. = ALIGN(4);
		/* preinit data */
		PROVIDE_HIDDEN (__preinit_array_start = .);
		*(.preinit_array)
		PROVIDE_HIDDEN (__preinit_array_end = .);

		. = ALIGN(4);
		/* init data */
		PROVIDE_HIDDEN (__init_array_start = .);
		*(SORT(.init_array.*))
		*(.init_array)
		PROVIDE_HIDDEN (__init_array_end = .);


		. = ALIGN(4);
		/* finit data */
		PROVIDE_HIDDEN (__fini_array_start = .);
		*(SORT(.fini_array.*))
		*(.fini_array)
		PROVIDE_HIDDEN (__fini_array_end = .);

		. = ALIGN(4);
		*(.fastrun) /*Placing functions in .fastrun section in RAM */
		/* This kind of breaks arm-none-eabi-size look at .map file __data_end__ for actual data size*/
		/* Really size is just combining text & data together */
		/* use a function attr like the following:
		 * #define RAMFUNC __attribute__ ((section (".fastrun"), noinline, noclone))
		 * RAMFUNC void myramfunction(){ code executes from ram }
		 * or for assembly functions: .section ".ramfunctions"
		 * the noinline is important so your function doesn't get inline optimized into
		 * or so that clones of your function don't end up in different places/sections
		 * whatever flash code is exectuting it.  However if you have a ram functions
		 * calling other ram functions you may not need noinline and can benefit from
		 * it's optimization
		 * /

		*(.jcr)
		. = ALIGN(4);
		/* All data end */
		__data_end__ = .;

	} > RAM

	.bss :
	{
		. = ALIGN(4);
		__bss_start__ = .;
		*(.bss*)
		*(COMMON)
		. = ALIGN(4);
		__bss_end__ = .;
	} > RAM

	.heap (COPY):
	{
		__end__ = .;
		PROVIDE(end = .);
		*(.heap*)
		__HeapLimit = .;
	} > RAM

	/* .stack_dummy section doesn't contains any symbols. It is only
	 * used for linker to calculate size of stack sections, and assign
	 * values to stack symbols later */
	.stack_dummy (COPY):
	{
		*(.stack*)
	} > RAM

	/* Set stack top to end of RAM, and stack limit move down by
	 * size of stack_dummy section */
	__StackTop = ORIGIN(RAM) + LENGTH(RAM);
	__StackLimit = __StackTop - SIZEOF(.stack_dummy);
	PROVIDE(__stack = __StackTop);

	/* Check if data + heap + stack exceeds RAM limit */
	ASSERT(__StackLimit >= __HeapLimit, "region RAM overflowed with stack")
}
