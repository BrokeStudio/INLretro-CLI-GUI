#include "fwupdate.h"


#define unlock_flash() 	FLASH->KEYR = FLASH_KEY1; FLASH->KEYR = FLASH_KEY2

#define lock_flash() 	FLASH->CR = FLASH_CR_LOCK
//	//The FLASH_CR register can be locked again by user software by writing the 
//	//LOCK bit in the FLASH_CR register to 1.



//flash must be erased prior to calling
FWUPDATE void wr_hword(uint16_t *addr, uint16_t data)
{
	//Trying to get by with out a static variable
	//writes to the current address of FLASH_AR, 
	//plus an 8bit address offset.
	//the host can set the address by erasing a page
	//that's really only useful when starting from a blank page though.
	//it can also set the address by writing 0xFFFF to a byte that's already erased
	
	unlock_flash();
	
	//The main Flash memory programming sequence in standard mode is as follows:
	// 1.Check that no main Flash memory operation is ongoing by checking the BSY bit in the FLASH_SR register.
	while ( FLASH->SR & FLASH_SR_BSY ) { /* forever */ }

	// 2. Set the PG bit in the FLASH_CR register.
	FLASH->CR = FLASH_CR_PG;	//shouldn't need to mask, all other bits clear by default

	// 3. Perform the data write (half-word) at the desired address.
	*addr = data;

	// 4. Wait until the BSY bit is reset in the FLASH_SR register.
	while ( FLASH->SR & FLASH_SR_BSY ) { /* forever */ }

	// 5. Check the EOP flag in the FLASH_SR register (it is set when the programming operation has succeeded), and then clear it by software.
	FLASH->SR = FLASH_SR_EOP;

	// Note:The registers are not accessible in write mode when the BSY bit of the FLASH_SR register is set.
	
	lock_flash();
}

FWUPDATE void erase_page(uint16_t page_num_1KB) 
{
	//usb driver & this code resisdes in first 2KByte of last (0x0800_0800)
	//The smaller STMF070C6 has 32KByte of flash, and larger STMF070RB has 128KByte
	//C6 flash is split into 1KB pages
	//RB flash is split into 2KB pages
	//So the C6 must leave first two pages alone, and RB only the first page
	//But they're both leaving the first 2KByte untouched
	//And erasing the 30KByte that follows
	//For now we're ignoring the extra 96KByte of additional flash that the RB contains
	
	//The program and erase operations can be performed over the whole product voltage range. 
	//They are managed through the following seven Flash registers:
	//
	// Key register (FLASH_KEYR)
	// Option byte key register (FLASH_OPTKEYR)
	// Flash control register (FLASH_CR)
	// Flash status register (FLASH_SR)
	// Flash address register (FLASH_AR)
	// Option byte register (FLASH_OBR)
	// Write protection register (FLASH_WRPR)
	//
	//An ongoing Flash memory operation will not block the CPU as long as the CPU does not access the Flash memory.
	//On the contrary, during a program/erase operation to the Flash memory, any attempt to read the Flash memory 
	//will stall the bus. The read operation will proceed correctly once the program/erase operation has completed. 
	//This means that code or data fetches cannot be made while a program/erase operation is ongoing.
	//
	//For program and erase operations on the Flash memory (write/erase), the internal RC oscillator (HSI) must be ON.
//should be running on it right now...
	//
	//Unlocking the Flash memory
	//After reset, the Flash memory is protected against unwanted write or erase operations. 
	//The FLASH_CR register is not accessible in write mode, except for the OBL_LAUNCH bit, 
	//used to reload the option bits. An unlocking sequence should be written to the FLASH_KEYR 
	//register to open the access to the FLASH_CR register. This sequence consists of two write operations:
	// Write KEY1 = 0x45670123
	//FLASH->KEYR = FLASH_KEY1;
	// Write KEY2 = 0xCDEF89AB
	//FLASH->KEYR = FLASH_KEY2;
	unlock_flash();
	//
	//Any wrong sequence locks up the FLASH_CR register until the next reset.
	//In the case of a wrong key sequence, a bus error is detected and a Hard Fault interrupt is generated. 
	//This is done after the first write cycle if KEY1 does not match, or during the second write cycle if 
	//KEY1 has been correctly written but KEY2 does not match.
	//
	//The FLASH_CR register can be locked again by user software by writing the 
	//LOCK bit in the FLASH_CR register to 1.
	//FLASH->CR = FLASH_CR_LOCK;

	//Page Erase
	// To erase a page, the procedure below should be followed:
	// 1.Check that no Flash memory operation is ongoing by checking the BSY bit in the FLASH_CR register.
	// 	Think they mean the FLASH_SR register...?
	// 	the BSY bit is supposed to clear itself when flash operation is complete, or errored out
	// 	So it should never remain set forever..
	while ( FLASH->SR & FLASH_SR_BSY ) { /* forever */ }

	// 2. Set the PER bit in the FLASH_CR register.
	FLASH->CR = FLASH_CR_PER;	//shouldn't need to mask, all other bits clear by default

	// 3. Program the FLASH_AR register to select a page to erase.
	FLASH->AR = 0x08000000 + (page_num_1KB<<10);	//page 2 (3rd KByte)

	// 4. Set the STRT bit in the FLASH_CR register (see note below).
	FLASH->CR = (FLASH_CR_PER | FLASH_CR_STRT);

	// 5. Wait for the BSY bit to be reset.
	__asm__ __volatile__ ("nop");
	while ( FLASH->SR & FLASH_SR_BSY) { /* forever */ }

	// 6. Check the EOP flag in the FLASH_SR register (it is set when the erase operation has succeeded).
	// 7. Clear the EOP flag.
	FLASH->SR = FLASH_SR_EOP;
	// Note:The software should start checking if the BSY bit equals ÎéÎí0ÎéÎí at least one CPU cycle after setting the STRT bit.

	//The FLASH_CR register can be locked again by user software by writing the 
	//LOCK bit in the FLASH_CR register to 1.
	lock_flash();
}



FWUPDATE uint8_t fwupdate_call( uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata )
{
#define	RD_LEN	0
#define	RD0	1
#define	RD1	2
#define	RD2	3
#define	RD3	4

#define	BYTE_LEN 1
#define	HWORD_LEN 2
#define	WORD_LEN 4

	//pointer to flash address space
	//inialize to the last accessed flash address
	uint16_t *flash_addr = (uint16_t *)FLASH->AR;

	switch (opcode) { 
		case ERASE_1KB_PAGE:	
			#ifdef STM32F070x6	
			if( (operand>1) && (operand<32))  { //only has 32KByte of flash
			#else			
			if( (operand>1) && (operand<128)) { //RB has 128KByte of flash
			#endif
			       erase_page(operand); 
			}else{  
				//don't want to erase ourselves!
				//or hardfault
				return ERR_FWUPDATE_BAD_ADDR; }
			break;

		//Don't really want to leave flash in an unlocked state..
//		case UNLOCK_FLASH:	
//			unlock_flash(); break;
//
//		case LOCK_FLASH:	
//			lock_flash(); break;

		case WR_HWORD:	
			//the address is based on previous
			//miscdata is the provided offset from last
			flash_addr += miscdata;
			wr_hword(flash_addr, operand); 
			break;

		case SET_FLASH_ADDR:	
			//sets FLASH->AR to desired address by writing 0xFFFF to that address
			//so it MUST already be erased!
			#ifdef STM32F070x6	//only has 32KByte of flash
				if (miscdata) { return ERR_FWUPDATE_BAD_ADDR; }
				if (operand>0x7FFF) { return ERR_FWUPDATE_BAD_ADDR; }
			#else
				if (miscdata>1) { return ERR_FWUPDATE_BAD_ADDR; }	//only 128KByte of flash
			#endif
			flash_addr = (uint16_t *) (0x08000000 + (miscdata<<16) + operand);
			wr_hword(flash_addr, 0xFFFF); 

			break;

		case GET_FLASH_ADDR:	
			rdata[RD_LEN] = WORD_LEN;
			rdata[RD0] = FLASH->AR;
			rdata[RD1] = FLASH->AR>>8;
			rdata[RD2] = FLASH->AR>>16;
			rdata[RD3] = FLASH->AR>>24;
			break;

		case GET_FLASH_DATA:	
			rdata[RD_LEN] = HWORD_LEN;
			rdata[RD0] = *flash_addr;
			rdata[RD1] = (*flash_addr)>>8;
			break;

		case READ_FLASH:	
			#ifdef STM32F070x6	//only has 32KByte of flash
				if (miscdata) { return ERR_FWUPDATE_BAD_ADDR; }
				if (operand>0x7FFF) { return ERR_FWUPDATE_BAD_ADDR; }
			#else
				if (miscdata>1) { return ERR_FWUPDATE_BAD_ADDR; }	//only 128KByte of flash
			#endif
			flash_addr = (uint16_t *) (0x08000000 + (miscdata<<16) + operand);
			rdata[RD_LEN] = HWORD_LEN;
			rdata[RD0] = *flash_addr;
			rdata[RD1] = (*flash_addr)>>8;
			break;

		case RESET_DEVICE:	
			SCB->AIRCR = 0x05FA0004;
			//device will not actually return from this..
			//although we could get it to by having it issue reset once back
			//in the fwupdate forever loop:
			//usbfuncwrite = RESETME;
			//shouldn't need this variable till after reset..
			//couldn't get that method to work though, so just don't bother returning for now..
			break;


		default: //opcode doesn't exist
			 return ERR_UNKN_FWUPDATE_OPCODE;
	}
	
	return SUCCESS;

}


FWUPDATE_NOIN uint16_t usb_fwupdate_setup(uint8_t data[8])
{
	//cast incoming data to a setup_packet
	setup_packet *spacket = (void *)data;

	//create a return array for data
	static uint16_t rv16[RETURN_BUFF_SIZE/2];
	uint8_t *rv = (uint8_t*)rv16;


	//create a usbMsgPtr variable from the stack which we can use convienently
	//but then at end of the function we'll need to copy the value over to usb_buff usbMsgPtr_H/L
	usbMsgPtr_t usbMsgPtr;

	rv[RETURN_ERR_IDX] = GEN_FAIL;	//default to error till opcode updates.
	rv[RETURN_LEN_IDX] = 0; 	//reset to zero, number of bytes in return data (excluding ERR & LEN)

	usbMsgPtr = (usbMsgPtr_t)rv;

	uint8_t rlen = (uint8_t) spacket->wLength;

	switch(spacket->bRequest) {
		case DICT_FWUPDATE:
			rv[RETURN_ERR_IDX] = fwupdate_call( spacket->opcode, spacket->miscdata, spacket->operand, &rv[RETURN_LEN_IDX] );	
			break;
		default:
			//request (aka dictionary) is unknown
			rv[RETURN_ERR_IDX] = ERR_UNKN_DICTIONARY;
	}

	usbMsgPtr_L = (uint32_t)usbMsgPtr;
	usbMsgPtr_H = ((uint32_t)usbMsgPtr)>>16;

	return rlen;
}


FWUPDATE_NOIN uint8_t usb_fwupdate_write(uint8_t *data, uint8_t len)
{

}



//This function has a fixed location so the application code knows where to find it
//and it shouldn't change
FWUPMAIN uint8_t fwupdate_forever()
{

	//need to turn off any interrupt sources except USB
	
	//Cannot turn off the WDT not possible!  We must keep petting him!
	
	//update usb function pointers to fwupdate functions
	//this file is compiled at same time as the the setup/write functions
	//so it's okay to refernce them at compile time
	usbfuncsetup = (uint32_t) &usb_fwupdate_setup;	//should only assign lower 16bits
	usbfuncwrite = (uint32_t) &usb_fwupdate_write;	//should only assign lower 16bits

	//need to return back to the bootloader PREP_FWUPDATE call that got us here
	//but when that's done we want to hijack execution so the USB ISR returns here
	//instead of the application main
	
	//modify the return PC/LR that's on the stack for the USB interrupt that's
	//currently being handled
	//
	//APSR bits 31-28 NZCV processor flags (could be any value)
	//EPSR bit 24 Thumb	(should be set)
	//IPSR bits 5-0 Exception number (should be zero if not in nested interrupt)
	//bits 27-25 & 23-6 should all be cleared for the stacked xPSR
	//bit 24 should be set (always in thumb mode)
	//bits 5-0 are probably clear if the device was in main (thread mode)
	//probably don't want to jump into the fw updater if it wasn't anyway..!
	//
	//so we don't necessarily know how far the stack pointer has decremented away
	//from the current processor stack frame created for the current exception 
	//
	//but if we search back far enough, we'll find stack frame that looks like:
	// R0, R1, R2, R3, R12, LR, PC, xPSR
	// The PC should be 0x0800_????, and the LR probably is to..?
	// PC could be something else if it happened to be executing from RAM
	// or we're on a processor with more than 64KByte of flash
	// The xPSR should be 0b????0001_00000000_00000000_00000000
	//
	// we're going to play it safe and require PC == 0x0800???? and the xPSR == 0x?1000000
	// we're also going to stop the LR just so it can't cause any troubles
	//
	// once the PC & LR are hijacked to get back here, we need to return to the
	// PREP_FWUPDATE call, and let it know all was well.
	asm(
			//use r0 as our pointer to the stack
			"mov     r0, r13\n"

			//xPSR has to be atleast 8 words back/up
			"add	r0, #28\n"

			"ldr	r2, psr_mask\n"
			"ldr	r3, psr_expect\n"

			"skip_2words:\n"
			"add	r0, #4\n"

			"next_word:\n"
			"add	r0, #4\n"
			"ldr	r1, [r0]\n"
			"and	r1, r1, r2\n"
			"sub	r1, r1, r3\n"
			"bne	next_word\n"

			//now r0 should be pointing to xPSR
			//
			//decrement to PC and verify 0x0800????
			"ldr	r2, pc_mask\n"
			"ldr	r3, pc_expect\n"
			"sub	r0, #4\n"

			"ldr	r1, [r0]\n"
			"and	r1, r1, r2\n"
			"sub	r1, r1, r3\n"
			"bne	skip_2words\n"	//the PC didn't match the expected, xPSR must have been false positive
			//if we go past the end of SRAM we'll get a hardfault and quit

			//PC matched expectation, we've found it!

			//stomp the PC and then the LR with 
			//loop forever PC
			"mov	r3, pc\n"	//pc currently points to next instruction

			"add	r3, #10\n"	//forever loop is 6 instructions ahead of here
						//minus one as if the PC was executing the "b done" instruction
						//and it should enter at fwupdateloop

			//stomp the PC in stack frame
			"str	r3, [r0]\n"
			"sub	r0, #4\n"
			//stomp the LR in the stack frame
			"add	r3, #1\n"	//LR need to be Thumb
			"str	r3, [r0]\n"

			"b	done\n"

			"fwupdateloop:\n");

	//the forever main loop is here!

		//when USB interrupts occur they should return back to here

		//if fwupdate is done, intitate system reset
		//maybe it's safer to have the user do this by unpluggig the device..?

			//pet watchdog
			IWDG->KR = 0x0000AAAA;

			//Couldn't get this to work for some reason...
//			if (usbfuncwrite == RESETME ) {
//				SCB->AIRCR = 0x05FA0004;
//			}


		
			asm( "b	fwupdateloop\n"
			
			".p2align 2\n"
			"pc_mask:\n"
			".word        0xFFFF0000\n"	//bits of the PC we want to match
			"pc_expect:\n"
			".word        0x08000000\n"	//bits of the PC we want to match
			"psr_mask:\n"
			".word        0x0FFFFFFF\n"	//bits of the xPSR we want to match
			"psr_expect:\n"
			".word        0x01000000\n"	//bits of the xPSR we want to match

		//	"beef:\n"
		//	".word        0xBEAD5678\n"

			"done:\n"
//			"bkpt\n"


	   );

		//return the PREP_FWUPDATE call that got us here
		return SUCCESS;
	
}

