

//want this to be in first 2KByte of USB boot space so the handler should typically be present
#define HARDFAULT __attribute__ ((section (".hardfault")))
HARDFAULT void HardFault_Handler(void)
{

	//TODO test out this function
	//should retrieve PC of the instruction that follows whatever caused the hardfault
	//This didn't work for me earlier bc the stack itself was broke
//	asm(
//	"movs r0, #4	\n"
//	"movs r1, lr	\n"
//	"tst r0, r1	\n"
//	"beq _MSP	\n"
//	"mrs r0, psp	\n"
//	"b _HALT	\n"
//	"_MSP:		\n"
//	"	mrs r0, msp	\n"
//	"_HALT:	\n"
//	"	ldr r1, [r0,#20]	\n"
//	//"	bkpt #0	\n"
//	);

	asm(
		"ldr     r0, dead\n"
		"b loop\n"
      		//"bkpt\n"
		".p2align 2\n"
		"dead:\n"
		".word        0xDEAD0123\n"	//MSP for bootloader
		"loop:\n"
	   );

	while (1) {
	}
}
