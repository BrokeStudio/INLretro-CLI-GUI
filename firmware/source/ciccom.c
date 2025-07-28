#include "ciccom.h"

//=================================================================================================
//
//	CICCOM operations
//	This file includes all the ciccom functions possible to be called from the ciccom dictionary.
//
//	See description of the commands contained here in shared/shared_dictionaries.h
//
//=================================================================================================



/* Desc:Function takes an opcode which was transmitted via USB
 * 	then decodes it to call designated function.
 * 	shared_dict_ciccom.h is used in both host and fw to ensure opcodes/names align
 * Pre: Macros must be defined in firmware pinport.h & ciccom.h
 * 	opcode must be defined in shared_dict_ciccom.h
 * Post:function call complete.
 * Rtn: SUCCESS if opcode found, error if opcode not present or other problem.
 */
uint8_t ciccom_call( uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata )
{
#define	RD_LEN	0
#define	RD0	1
#define	RD1	2
#define	RD2	3
#define	RD3	4
#define	RD4	5
#define	RD5	6
//	uint16_t *ret_hword = (uint16_t*) &rdata[1];

#define	BYTE_LEN 1
#define	HWORD_LEN 2
	switch (opcode) { 

//		case CICCOM_INIT:		ciccom_init();		break;

		default:
			 //opcode doesn't exist
			 return ERR_UNKN_CICCOM_OPCODE;
	}
	
	return SUCCESS;

}

