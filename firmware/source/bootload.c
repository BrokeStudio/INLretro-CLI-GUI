#include "bootload.h"

//=================================================================================================
//
//	BOOTLOAD operations
//	This file includes all the bootload functions possible to be called from the bootload dictionary.
//
//	See description of the commands contained here in shared/shared_dictionaries.h
//
//=================================================================================================


//const uint32_t fixed_const  __attribute__((at(0x0800F000)));
//fixed_const= 0xDEADBEEF;

//int gSquared __attribute__((at(0x5000)));  // Place at 0x5000


/* Desc:Function takes an opcode which was transmitted via USB
 * 	then decodes it to call designated function.
 * 	shared_dict_bootload.h is used in both host and fw to ensure opcodes/names align
 * Pre: Macros must be defined in firmware pinport.h & bootload.h
 * 	opcode must be defined in shared_dict_bootload.h
 * Post:function call complete.
 * Rtn: SUCCESS if opcode found, error if opcode not present or other problem.
 */

uint16_t addrh;
uint16_t *addr_ptr;

typedef void (*pFunction)(void);

uint8_t bootload_call( uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata )
{
#define	RD_LEN	0
#define	RD0	1
#define	RD1	2
#define	RD2	3
#define	RD3	4

#define	BYTE_LEN 1
#define	HWORD_LEN 2
#define	WORD_LEN 4

	pFunction JumpToApplication;

	switch (opcode) { 
#ifdef STM_CORE
		//case JUMP_BL:		jump_to_bootloader();		break;
					//device won't respond after this point so actually expect an error to result

		case LOAD_ADDRH:	addrh = operand;		break;

		case JUMP_ADDR:		//jump2addr((addrh<<16) | (operand));	break;
			JumpToApplication = (void (*)(void)) ((addrh<<16|operand));  //Base of flash
	      		//JumpToApplication = (void (*)(void)) (*((uint32_t *) ((0x1FFFC400 + 4))));	//jump to vector
			JumpToApplication();
			break;
					//device may not respond depending on the address/function being jumped to
		
		case PREP_FWUPDATE:	
			//while we are directly jumping to fwupdate section
			//it should be okay since it's in a fixed location
			return fwupdate_forever();	break;	
			//this function hijacked the stack frame to steal execution
			//after returing from the current USB ISR
			//it returns SUCCESS if it found and modified
			//the stack frame successfully
			//if it didn't find the stack frame it probably exceeded SRAM
			//space and caused a hardfault.
			//Once the USB ISR is completed, exectution left main application code for good
			//will respond to usb interrupts, but are directed to fwupdater
			
		case SET_PTR_HI:
			addr_ptr = (uint16_t*) ((((uint32_t)addr_ptr) & 0x0000FFFF) | (operand<<16));
			break;

		case SET_PTR_LO:
			addr_ptr = (uint16_t*) ((((uint32_t)addr_ptr) & 0xFFFF0000) | (operand));
			break;

		case GET_PTR:
			//update ptr with offset
			rdata[RD_LEN] = WORD_LEN;
			rdata[RD0] = (uint32_t)addr_ptr;
			rdata[RD1] = ((uint32_t)addr_ptr)>>8;
			rdata[RD2] = ((uint32_t)addr_ptr)>>16;
			rdata[RD3] = ((uint32_t)addr_ptr)>>24;
			break;

		case RD_PTR_OFFSET:
			//use offset from current pointer but don't change it
			rdata[RD_LEN] = HWORD_LEN;
			rdata[RD0] = addr_ptr[operand];
			rdata[RD1] = (addr_ptr[operand])>>8;
			break;

		case WR_PTR_OFFSET:
			//use offset from current pointer but don't change it
			addr_ptr[miscdata] = operand;
			break;

		case RD_PTR_OFF_UP:
			//update ptr with offset
			addr_ptr += operand;
			rdata[RD_LEN] = HWORD_LEN;
			rdata[RD0] = *addr_ptr;
			rdata[RD1] = (*addr_ptr)>>8;
			break;

		case WR_PTR_OFF_UP:
			//update ptr with miscdata
			addr_ptr += miscdata;
			//write operand to address that's being pointed to
			*addr_ptr = operand;
			break;

			//can't get this to go where I want 0x08000800
			//so for now I'll just put it there manually post-build
			//can use the pointer to read 4bytes at 0x08000800
			//which is the begining of application code space
			//should include ascii "AV00" with the digits for version
#endif //STM_CORE
			//application version supported by all devices starting with AV03
		case GET_APP_VER:
			rdata[RD_LEN] = BYTE_LEN;
			rdata[RD0] = APP_VERSION; //defined in shared_dict_bootload.h
			//rdata[RD_LEN] = WORD_LEN;
			//rdata[RD0] = (uint8_t)'A';
			//rdata[RD1] = (uint8_t)'V';
			//rdata[RD2] = (uint8_t)'0';
			//rdata[RD3] = (uint8_t)'3';
			break;

		default:
			 //opcode doesn't exist
			 return ERR_UNKN_BOOTLOAD_OPCODE;
	}
	
	return SUCCESS;

}

//void jump_to_bootloader()
//{
//
//#ifdef STM_INL6
//// 070C6 jump to:	0x1FFFC519
//// 070RB jump to:	0x1FFFCBC1
//
//
//	asm(
//			//"ldr     pc, boot_addr\n\t"
////			"ldr    r0, =0x12345678\n\t"
////			"mov     r0, r0\n\t"
////			"mov     r0, r0\n\t"
//			//".p2align 2\n\t"
//			//"boot_addr:\n\t"
//			//".word	0x1FFFC519"
//			"ldr    r0, [pc, #8]\n\t"//    @ remember pc is 8 bytes ahead
//			"mov	r13, r0\n\t"	//load main stack pointer
//			"ldr    r0, [pc, #8]\n\t"//    @ remember pc is 8 bytes ahead
//			//"mov	lr, r0\n\t"
//			//"bx	lr    	\n\t"//               @ function return
//			//"bkpt\n\t"
//			"mov	r0, r0\n\t"
//			//"mov	pc, r0\n\t"
//			"bx	r0\n\t"
//			//"bootaddr\n\t"//
//			//".word	0x1FFFC519"	//070C6
//			".p2align 2\n\t"
//			".word	0x20001278\n\t"	//C6 MSP @ reset
////			".word	0x00010002\n\t"
//			//".word	0x00030004\n\t"
//			//".word	0x1FFFC519\n\t"	//C6 AN2606
//			".word	0x1FFFCAC5\n\t"	//C6 BL reset vector
//			//".word	0x1FFFCBC1\n\t"		//stlink PC when connecting with BL grounded
//			//".word	0x1FFFC919\n\t"	//best guess based on C6
//			//".word	0x1FFFCBC1\n\t"		//bootloader reset vector
//			".word	0x00050006\n\t"
//			".word	0x00070008\n\t"
////			".word	0x1FFFC919\n\t"
////			".word	0x1FFFC919\n\t"
////			".word	0x1FFFC919\n\t"
////			".word	0x1FFFC919\n\t"
////			".word	0x1FFFC919\n\t"
//			".word	0x1FFFC919"
//			//".word	0x1FFFCBC1"
//	   );
//bootaddr:
//	asm(
//			".word	0xDEADBEEF"
//	   );
//
//#endif
//
//
//}
