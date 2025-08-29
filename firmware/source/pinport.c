#include "pinport.h"

//This file was created based on pinport.h
//the close relationship between these two files must be kept in mind when making changes.
//This file is also very dependent on shared_dict_pinport.h
//the shared_dict_pinport.h was generated from this file, so any changes here must be forwarded.

/* Desc:Decode pinport dictionary calls transmitted via USB and call requested operation
 * 	shared_dict_pinport.h is used in both host and fw to ensure opcodes/names align
 * Pre: Macros must be defined in firmware pinport.h
 * 	opcode must be defined in shared_dict_pinport.h
 * Post:opcode command complete, return data & length stored if used.
 * Rtn: SUCCESS if opcode found and completed, error code if not.
 */
uint8_t pinport_call( uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata )
{

#define	RD_LEN	0
#define	RD0	1
#define	RD1	2

#define	BYTE_LEN 1
#define	HWORD_LEN 2

	//create pointer to first two bytes of return data array
	uint16_t *ret_hword = (uint16_t*) &rdata[RD0];

	switch (opcode) {

		//============================
		//CONTROL PORT INDIVIDUAL PIN ACCESS
		//opcode: type of pin operation
		//operand: pin number to act on
		//============================
		case CTL_ENABLE_:	CTL_ENABLE();		break;
		case CTL_IP_PU_:
			switch ( operand ) {
				case 0:  CTL_IP_PU(C0bank, C0);  break;
				case 1:  CTL_IP_PU(C1bank, C1);  break;
				case 2:  CTL_IP_PU(C2bank, C2);  break;
				#ifndef C3nodef
				case 3:  CTL_IP_PU(C3bank, C3);  break;
				#endif
				case 4:  CTL_IP_PU(C4bank, C4);  break;
				case 5:  CTL_IP_PU(C5bank, C5);  break;
				case 6:  CTL_IP_PU(C6bank, C6);  break;
				#ifndef C7nodef
				case 7:  CTL_IP_PU(C7bank, C7);  break;
				#endif
				case 8:  CTL_IP_PU(C8bank, C8);  break;
				case 9:  CTL_IP_PU(C9bank, C9);  break;
				case 10: CTL_IP_PU(C10bank,C10); break;
				case 11: CTL_IP_PU(C11bank,C11); break;
				#ifndef C12nodef
				case 12: CTL_IP_PU(C12bank,C12); break;
				#endif
				#ifndef C13nodef
				case 13: CTL_IP_PU(C13bank,C13);
					#ifdef PURPLE_KAZZO
					CTL_IP_PU(C3bank,C3);
					#endif
					 break;
				#endif
				#ifndef C14nodef
				case 14: CTL_IP_PU(C14bank,C14); break;
				#endif
				#ifndef C15nodef
				case 15: CTL_IP_PU(C15bank,C15); break;
				#endif
				#ifndef C16nodef
				case 16: CTL_IP_PU(C16bank,C16); break;
				#endif
				#ifndef C17nodef
				case 17: CTL_IP_PU(C17bank,C17); break;
				#endif
				#ifndef C18nodef
				case 18: CTL_IP_PU(C18bank,C18); break;
				#endif
				#ifndef C19nodef
				case 19: CTL_IP_PU(C19bank,C19); break;
				#endif
				#ifndef C20nodef
				case 20: CTL_IP_PU(C20bank,C20); break;
				#endif
				case 21: CTL_IP_PU(C21bank,C21); break;
// BROKE STUDIO
#ifndef STM_NES
				#ifndef C22nodef
				case 22: CTL_IP_PU(C22bank,C22); break;
				#endif
#endif
// BROKE STUDIO

				default: return ERR_CTL_PIN_NOT_PRESENT;
			}
			break;
		case CTL_IP_FL_:
			switch ( operand ) {
				case 0:  CTL_IP_FL(C0bank, C0);  break;
				case 1:  CTL_IP_FL(C1bank, C1);  break;
				case 2:  CTL_IP_FL(C2bank, C2);  break;
				#ifndef C3nodef
				case 3:  CTL_IP_FL(C3bank, C3);  break;
				#endif
				case 4:  CTL_IP_FL(C4bank, C4);  break;
				case 5:  CTL_IP_FL(C5bank, C5);  break;
				case 6:  CTL_IP_FL(C6bank, C6);  break;
				#ifndef C7nodef
				case 7:  CTL_IP_FL(C7bank, C7);  break;
				#endif
				case 8:  CTL_IP_FL(C8bank, C8);  break;
				case 9:  CTL_IP_FL(C9bank, C9);  break;
				case 10: CTL_IP_FL(C10bank,C10); break;
				case 11: CTL_IP_FL(C11bank,C11); break;
				#ifndef C12nodef
				case 12: CTL_IP_FL(C12bank,C12); break;
				#endif
				#ifndef C13nodef
				case 13: CTL_IP_FL(C13bank,C13);
					#ifdef PURPLE_KAZZO
					CTL_IP_FL(C3bank,C3);
					#endif
					 break;
				#endif
				#ifndef C14nodef
				case 14: CTL_IP_FL(C14bank,C14); break;
				#endif
				#ifndef C15nodef
				case 15: CTL_IP_FL(C15bank,C15); break;
				#endif
				#ifndef C16nodef
				case 16: CTL_IP_FL(C16bank,C16); break;
				#endif
				#ifndef C17nodef
				case 17: CTL_IP_FL(C17bank,C17); break;
				#endif
				#ifndef C18nodef
				case 18: CTL_IP_FL(C18bank,C18); break;
				#endif
				#ifndef C19nodef
				case 19: CTL_IP_FL(C19bank,C19); break;
				#endif
				#ifndef C20nodef
				case 20: CTL_IP_FL(C20bank,C20); break;
				#endif
				case 21: CTL_IP_FL(C21bank,C21); break;
// BROKE STUDIO
#ifndef STM_NES
				#ifndef C22nodef
				case 22: CTL_IP_FL(C22bank,C22); break;
				#endif
#endif
// BROKE STUDIO
				default: return ERR_CTL_PIN_NOT_PRESENT;
			}
			break;
		case CTL_OP_:
			switch ( operand ) {
				case 0:  CTL_OP(C0bank, C0);  break;
				case 1:  CTL_OP(C1bank, C1);  break;
				case 2:  CTL_OP(C2bank, C2);  break;
				#ifndef C3nodef
				case 3:  CTL_OP(C3bank, C3);  break;
				#endif
				case 4:  CTL_OP(C4bank, C4);  break;
				case 5:  CTL_OP(C5bank, C5);  break;
				case 6:  CTL_OP(C6bank, C6);  break;
				#ifndef C7nodef
				case 7:  CTL_OP(C7bank, C7);  break;
				#endif
				case 8:  CTL_OP(C8bank, C8);  break;
				case 9:  CTL_OP(C9bank, C9);  break;
				case 10: CTL_OP(C10bank,C10); break;
				case 11: CTL_OP(C11bank,C11); break;
				#ifndef C12nodef
				case 12: CTL_OP(C12bank,C12); break;
				#endif
				#ifndef C13nodef
				case 13: CTL_OP(C13bank,C13);
					#ifdef PURPLE_KAZZO
					CTL_OP(C3bank,C3);
					#endif
					 break;
				#endif
				#ifndef C14nodef
				case 14: CTL_OP(C14bank,C14); break;
				#endif
				#ifndef C15nodef
				case 15: CTL_OP(C15bank,C15); break;
				#endif
				#ifndef C16nodef
				case 16: CTL_OP(C16bank,C16); break;
				#endif
				#ifndef C17nodef
				case 17: CTL_OP(C17bank,C17); break;
				#endif
				#ifndef C18nodef
				case 18: CTL_OP(C18bank,C18); break;
				#endif
				#ifndef C19nodef
				case 19: CTL_OP(C19bank,C19); break;
				#endif
				#ifndef C20nodef
				case 20: CTL_OP(C20bank,C20); break;
				#endif
				case 21: CTL_OP(C21bank,C21); break;
// BROKE STUDIO
#ifndef STM_NES
				#ifndef C22nodef
				case 22: CTL_OP(C22bank,C22); break;
				#endif
#endif
// BROKE STUDIO
				default: return ERR_CTL_PIN_NOT_PRESENT;
			}
			break;
		#ifdef STM_CORE
		//AVR Doesn't have open drain mode, it must be simulated by
		//toggling between input with pullup and output push-pull
		case CTL_OD_:
			switch ( operand ) {
				//currently only defining pins which utilize open drain function
				//C8 -> EXP0 (SNES /RESET)
				case 8:  CTL_OD(C8bank, C8);  break;
				default: return ERR_CTL_PIN_NOT_PRESENT;
			}
			break;
		case CTL_PP_:
			switch ( operand ) {
				case 8:  CTL_PP(C8bank, C8);  break;
				default: return ERR_CTL_PIN_NOT_PRESENT;
			}
			break;
		#endif
		case CTL_SET_LO_:
			switch ( operand ) {
				case 0:  CTL_SET_LO(C0bank, C0);  break;
				case 1:  CTL_SET_LO(C1bank, C1);  break;
				case 2:  CTL_SET_LO(C2bank, C2);  break;
				#ifndef C3nodef
				case 3:  CTL_SET_LO(C3bank, C3);  break;
				#endif
				case 4:  CTL_SET_LO(C4bank, C4);  break;
				case 5:  CTL_SET_LO(C5bank, C5);  break;
				case 6:  CTL_SET_LO(C6bank, C6);  break;
				#ifndef C7nodef
				case 7:  CTL_SET_LO(C7bank, C7);  break;
				#endif
				case 8:  CTL_SET_LO(C8bank, C8);  break;
				case 9:  CTL_SET_LO(C9bank, C9);  break;
				case 10: CTL_SET_LO(C10bank,C10); break;
				case 11: CTL_SET_LO(C11bank,C11); break;
				#ifndef C12nodef
				case 12: CTL_SET_LO(C12bank,C12); break;
				#endif
				#ifndef C13nodef
				case 13: CTL_SET_LO(C13bank,C13);
					#ifdef PURPLE_KAZZO
					CTL_SET_LO(C3bank,C3);
					#endif
					 break;
				#endif
				#ifndef C14nodef
				case 14: CTL_SET_LO(C14bank,C14); break;
				#endif
				#ifndef C15nodef
				case 15: CTL_SET_LO(C15bank,C15); break;
				#endif
				#ifndef C16nodef
				case 16: CTL_SET_LO(C16bank,C16); break;
				#endif
				#ifndef C17nodef
				case 17: CTL_SET_LO(C17bank,C17); break;
				#endif
				#ifndef C18nodef
				case 18: CTL_SET_LO(C18bank,C18); break;
				#endif
				#ifndef C19nodef
				case 19: CTL_SET_LO(C19bank,C19); break;
				#endif
				#ifndef C20nodef
				case 20: CTL_SET_LO(C20bank,C20); break;
				#endif
				case 21: CTL_SET_LO(C21bank,C21); break;
// BROKE STUDIO
#ifndef STM_NES
				#ifndef C22nodef
				case 22: CTL_SET_LO(C22bank,C22); break;
				#endif
#endif
// BROKE STUDIO
				default: return ERR_CTL_PIN_NOT_PRESENT;
			}
			break;
		case CTL_SET_HI_:
			switch ( operand ) {
				case 0:  CTL_SET_HI(C0bank, C0);  break;
				case 1:  CTL_SET_HI(C1bank, C1);  break;
				case 2:  CTL_SET_HI(C2bank, C2);  break;
				#ifndef C3nodef
				case 3:  CTL_SET_HI(C3bank, C3);  break;
				#endif
				case 4:  CTL_SET_HI(C4bank, C4);  break;
				case 5:  CTL_SET_HI(C5bank, C5);  break;
				case 6:  CTL_SET_HI(C6bank, C6);  break;
				#ifndef C7nodef
				case 7:  CTL_SET_HI(C7bank, C7);  break;
				#endif
				case 8:  CTL_SET_HI(C8bank, C8);  break;
				case 9:  CTL_SET_HI(C9bank, C9);  break;
				case 10: CTL_SET_HI(C10bank,C10); break;
				case 11: CTL_SET_HI(C11bank,C11); break;
				#ifndef C12nodef
				case 12: CTL_SET_HI(C12bank,C12); break;
				#endif
				#ifndef C13nodef
				case 13: CTL_SET_HI(C13bank,C13);
					#ifdef PURPLE_KAZZO
					CTL_SET_HI(C3bank,C3);
					#endif
					 break;
				#endif
				#ifndef C14nodef
				case 14: CTL_SET_HI(C14bank,C14); break;
				#endif
				#ifndef C15nodef
				case 15: CTL_SET_HI(C15bank,C15); break;
				#endif
				#ifndef C16nodef
				case 16: CTL_SET_HI(C16bank,C16); break;
				#endif
				#ifndef C17nodef
				case 17: CTL_SET_HI(C17bank,C17); break;
				#endif
				#ifndef C18nodef
				case 18: CTL_SET_HI(C18bank,C18); break;
				#endif
				#ifndef C19nodef
				case 19: CTL_SET_HI(C19bank,C19); break;
				#endif
				#ifndef C20nodef
				case 20: CTL_SET_HI(C20bank,C20); break;
				#endif
				case 21: CTL_SET_HI(C21bank,C21); break;
// BROKE STUDIO
#ifndef STM_NES
				#ifndef C22nodef
				case 22: CTL_SET_HI(C22bank,C22); break;
				#endif
#endif
// BROKE STUDIO
				default: return ERR_CTL_PIN_NOT_PRESENT;
			}
			break;
		case CTL_RD_:
			rdata[RD_LEN] = HWORD_LEN;
			switch ( operand ) {
				case 0:  CTL_RD(C0bank, C0,  *ret_hword); break;
				case 1:  CTL_RD(C1bank, C1,  *ret_hword); break;
				case 2:  CTL_RD(C2bank, C2,  *ret_hword); break;
				#ifndef C3nodef
				case 3:  CTL_RD(C3bank, C3,  *ret_hword); break;
				#endif
				case 4:  CTL_RD(C4bank, C4,  *ret_hword); break;
				case 5:  CTL_RD(C5bank, C5,  *ret_hword); break;
				case 6:  CTL_RD(C6bank, C6,  *ret_hword); break;
				#ifndef C7nodef
				case 7:  CTL_RD(C7bank, C7,  *ret_hword); break;
				#endif
				case 8:  CTL_RD(C8bank, C8,  *ret_hword); break;
				case 9:  CTL_RD(C9bank, C9,  *ret_hword); break;
				case 10: CTL_RD(C10bank,C10, *ret_hword); break;
				case 11: CTL_RD(C11bank,C11, *ret_hword); break;
				#ifndef C12nodef
				case 12: CTL_RD(C12bank,C12, *ret_hword); break;
				#endif
				#ifndef C13nodef
				case 13: CTL_RD(C13bank,C13, *ret_hword); break;
				#endif
				#ifndef C14nodef
				case 14: CTL_RD(C14bank,C14, *ret_hword); break;
				#endif
				#ifndef C15nodef
				case 15: CTL_RD(C15bank,C15, *ret_hword); break;
				#endif
				#ifndef C16nodef
				case 16: CTL_RD(C16bank,C16, *ret_hword); break;
				#endif
				#ifndef C17nodef
				case 17: CTL_RD(C17bank,C17, *ret_hword); break;
				#endif
				#ifndef C18nodef
				case 18: CTL_RD(C18bank,C18, *ret_hword); break;
				#endif
				#ifndef C19nodef
				case 19: CTL_RD(C19bank,C19, *ret_hword); break;
				#endif
				#ifndef C20nodef
				case 20: CTL_RD(C20bank,C20, *ret_hword); break;
				#endif
				case 21: CTL_RD(C21bank,C21, *ret_hword); break;
// BROKE STUDIO
#ifndef STM_NES
				#ifndef C22nodef
				case 22: CTL_RD(C22bank,C22, *ret_hword); break;
				#endif
#endif
// BROKE STUDIO
				default: rdata[RD_LEN] = 0;
					return ERR_CTL_PIN_NOT_PRESENT;
			}
			break;

		//============================
		//DATA PORT BYTE WIDE ACCESS
		//opcode: type of operation
		//operand: value to place on bus
		//============================
		case DATA_ENABLE_:	DATA_ENABLE();		break;
		case DATA_IP_PU_: 	DATA_IP_PU();		break;
		case DATA_IP_: 		DATA_IP();		break;
		case DATA_OP_: 		DATA_OP();		break;
		case DATA_SET_: 	DATA_SET(operand);	break;
		case DATA_RD_:		DATA_RD(rdata[RD0]);
					rdata[RD_LEN] = 1;	break;

		//============================
		//DATA PORT 16bit WIDE ACCESS
		//opcode: type of operation
		//operand: value to place on bus
		//============================
#ifdef STM_INL6	//DATA16 not present when there's no 16bit console connector
		case DATA16_ENABLE_:	DATA16_ENABLE();		break;
		//case DATA16_IP_PU_: 	DATA16_IP_PU();		break;
		case DATA16_IP_: 		DATA16_IP();		break;
		case DATA16_OP_: 		DATA16_OP();		break;
		case DATA16_SET_: 	DATA16L_SET(operand); operand = operand >> 8; DATA16H_SET(operand); break;
		case DATA16_RD_:		DATA16L_RD(rdata[RD0]); DATA16H_RD(rdata[RD1]);
					rdata[RD_LEN] = 2;	break;
#endif

		//============================
		//ADDR PORT 16bit WIDE ACCESS
		//opcode: type of operation
		//operand: value to place on bus
		//============================
		case ADDR_ENABLE_:	ADDR_ENABLE();		break;
		case ADDR_PU_: 		ADDR_PU();		break;
		case ADDR_IP_: 		ADDR_IP();		break;
		case ADDR_OP_: 		ADDR_OP();		break;
		case ADDR_SET_:		ADDR_SET(operand);	break;
		#ifdef ADDR_VAL
		case ADDR_RD_:		rdata[RD_LEN] = 1;
					rdata[RD0] = ADDR_VAL;
					rdata[RD1] = ADDR_VAL>>8;	break;
		#endif


		//============================
		//EXP PORT 8bit ACCESS (bits1-8)
		//opcode: type of operation
		//operand: value to place on bus
		//============================
		case EXP_ENABLE_:	EXP_ENABLE();		break;
		case EXP_DISABLE_:	EXP_DISABLE();		break;
		case EXP_SET_:		EXP_SET(operand);	break;


		//============================
		//HIGH ADDR PORT 8bit WIDE ACCESS
		//opcode: type of operation
		//operand: value to place on bus
		//============================
		#ifndef STM_NES	//HADDR not present when there's no 16bit console connector
		case HADDR_ENABLE_:	HADDR_ENABLE();		break;
		case HADDR_DISABLE_:	HADDR_DISABLE();	break;
		case HADDR_SET_:	HADDR_SET(operand);	break;
		#endif


		//============================
		//FLIPFLOP ADDR PORT 8bit WIDE ACCESS
		//opcode: type of operation
		//operand: value to place on bus
		//============================
		#ifdef SEGA_CONN
		case FFADDR_ENABLE_:	FFADDR_ENABLE();	break;
		case FFADDR_DISABLE_:	FFADDR_DISABLE();	break;
		case FFADDR_SET_:	FFADDR_SET(operand);	break;
		#endif


		default:
			 //macro doesn't exist or isn't on this PCB version
			 return ERR_UNKN_PP_OPCODE;
	}

	return SUCCESS;
}

#ifdef GREEN_KAZZO

/* Desc:
 * 	other board versions have PORTB "DATA" feed into both FF's
 * 	this board feeds EXP FF with PORTA "ADDR" instead
 * 	goal is to make board versions 'identical'
 * 	to do this we assume higher level functions will have already
 * 	placed desired latch value on PORTB "Dbank->PORT"
 * 	we need to juggle this data around and not stomp on anything
 * Pre: DATA_OP() set
 * 	curAHLaddr set by software_AHL_CLK
 * 	Dbank->PORT contains desired value to be latched by EXP FF
 * 	AXHL might not be set as O/P
 * 	AXHL might not be low ready for AXHL_CLK
 * Post:Both FF's have desired value latched
 * 	ADDR_OP() left set
 * 	curAXLaddr updated for use by software_AHL_CLK
 * 	Dbank->PORT and ALbank->PORT replaced with original values
 * 	AXHL left as O/P and ready for subsequent CLK
 */

//these variables are updated each time the FF's are clocked
//that way we can retain the value of other FF as both must be clocked at once
static uint8_t curAHLaddr;
static uint8_t curAXLaddr;

void software_AXL_CLK()
{
	//first store current DATA & ADDR values
	curAXLaddr = Dbank->PORT;	//This is desired AXL value
	uint8_t orig_addr = ALbank->PORT;	//PORTA

	//Put current AHL latched value on DATA as that's where it'll be relatched
	//software_AHL_CLK function is one to maintain this value
	Dbank->PORT = curAHLaddr;

	//set ADDR as O/P and place desired value on bus
	ADDR_OP();	//prob already be set, but in case not
	ALbank->PORT = curAXLaddr;

	//Clock both latches
	AHL_OP();	//can't be sure "AHL" is OP as assumption is AXL will be used as latch
	AHL_LO();	//can't be sure it's low either
	//_AXHL_CLK();	//clock values
	CTL_SET_HI(AHLbank, AHL); CTL_SET_LO(AHLbank, AHL);

	//finally restore original DATA & ADDR values
	Dbank->PORT = curAXLaddr;
	ALbank->PORT = orig_addr;

}

/* Desc: Same premise as software_AXL_CLK above.
 * 	this is a little simpler as data has already been feed with AHL value.
 * 	just need to make sure AXL latch doesn't get corrupted.
 * Pre: DATA_OP() set
 * 	curAXLaddr set by software_AXL_CLK
 * 	Dbank->PORT contains desired value to be latched by ADDRMID FF
 * 	AXHL is already set to O/P
 * 	AXHL already low ready for AXHL_CLK
 * Post:Both FF's have desired value latched
 * 	curAHLaddr updated for use by software_AXL_CLK
 * 	Dbank->PORT and ALbank->PORT replaced with original values
 * 	AXHL left as O/P and ready for subsequent CLK
 */
void software_AHL_CLK()
{
	//first store current DATA & ADDR values
	curAHLaddr = Dbank->PORT;	//This is desired AHL value (store it for other function's use)
	uint8_t orig_addr = ALbank->PORT;	//PORTA

	//Desired AHL latch value should have already been placed on Dbank->PORT.

	//set ADDR as O/P and place curAXLaddr on bus other function should have updated it last latch
	ADDR_OP();	//should already be set, but in case not
	ALbank->PORT = curAXLaddr;

	//Clock both latches
	//Can assume AHL is OP as other versions would require it to latch AHL
	//Can also assume it was left low, if not causes issues in all board versions
	//_AXHL_CLK();	//clock values
	CTL_SET_HI(AHLbank, AHL); CTL_SET_LO(AHLbank, AHL);

	//finally restore original DATA & ADDR values
	//never changed: Dbank->PORT = curAHLaddr;
	ALbank->PORT = orig_addr;

}

#endif	//GREEN_KAZZO
