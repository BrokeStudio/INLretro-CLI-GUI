#ifndef _ramfuncs_h
#define _ramfuncs_h


#include "pinport.h"

//#define RAMFUNC __attribute__ ((long_call, section (".ramfunctions")))
//#define RAMFUNC __attribute__ ((long_call, section (".data")))

//void ledRAM(void )  __attribute__ ((section(".data")))
//__attribute__ ((section(".ram"))) void ledRAM(void ) 


//__attribute__ ((section(".fastrun"), noinline, noclone)) void ledRAM() //david
//__attribute__ ((section(".ramfunctions"), noinline, noclone )) void ledRAM() //paul works! if in nokeep.ld
//__attribute__ ((section(".ramfunctions"), noinline)) void ledRAM() //paul works! if in nokeep.ld
//noinline seems to be required, I guess gcc optimizes it out of ram negating our effort..
//noclone seems like a good idea too based on what it appears to mean: The function attribute noinline no longer prevents GCC from cloning the function. A new attribute noclone has been introduced for this purpose. Cloning a function means that it is duplicated and the new copy is specialized for certain contexts (for example when a parameter is a known constant).
//void ledRAM()
//void ledRAM()

//#define RAMFUNC (__attribute__ ((section(".fastrun"), noinline, noclone))) //void ledRAM() //david
//#define RAMFUNC __attribute__ ((long_call, section (".ramfunctions")))
//#define RAMFUNC __attribute__ ((noinline, noclone, section (".fastrun")))

//This site helped me understand basics of sections and linker script:
// https://ez.analog.com/dsp/software-and-development-tools/gnu-toolchain-blackfin/f/q-a/68624/run-a-specific-function-from-sram-gnu-gcc-compilation-tools
//David Viens of Plogue helped me with the tip on noinline which was keeping things from working for me
//
//Here's how ez.analog.com recommends setting up assembly functions:
//.section ".ramfunctions"
//.align 8
//.global PutOneChar
//.thumb
//.thumb_func
//.type     PutOneChar, %function

//NOTE executing code from SRAM does seem to break arm-none-eabi-size as it pushes all .data to .text
//you can determine data size based on .map file __data_end__ location

#define RAMFUNC __attribute__ ((section (".fastrun"), noinline, noclone))

RAMFUNC void ledRAM();

#endif
