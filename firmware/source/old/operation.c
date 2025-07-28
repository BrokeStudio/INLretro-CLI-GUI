#include "operation.h"

//struct to hold all operation info
operation_info oper_info_struct;
operation_info *oper_info = &oper_info_struct;


/* Desc:Bridge between usb.c and operation.c functions
 * 	usb.c calls this function providing setup packet info
 * 	usb.c also provides pointer to small 'rv' return value buffer of 8bytes
 * 	and pointer to rlen so operation.c can decide wether to utilize the 
 * 	small 8byte generic return buffer or point usbMsgPtr to some larger buffer of sram.
 * 	this function interprets opcode type to call proper opcode switch function
 * Pre: opcode must be defined in shared_dict_operation.h
 * Post:function call complete.
 * 	rlen updated to lenght of return data
 * 	rv[RV_ERR_IDX] contains SUCCESS/ERROR code
 * 	rv buffer filled with return data for small data requests
 * Rtn: pointer to ram buffer to be returned over USB
 */
uint8_t	* operation_usb_call( setup_packet *spacket, uint8_t *rv, uint8_t *rlen)
{
	uint8_t *rptr = rv; //used for return pointer set to small rv buffer by default

	switch (spacket->opcode) {

		case OPER_OPCODE_NRV_MIN ... OPER_OPCODE_NRV_MAX:
			rv[RV_ERR_IDX] = oper_opcode_no_return( spacket->opcode,
			spacket->operandMSB, spacket->operandLSB, spacket->miscdata );	
			*rlen = RV_ERR_IDX+1;
		break;

		case OPER_OPCODE_RV_MIN ... OPER_OPCODE_RV_MAX:
			rv[RV_ERR_IDX] = oper_opcode_return( spacket->opcode,
			spacket->operandMSB, spacket->operandLSB, spacket->miscdata, 
								&rv[RV_DATA0_IDX], rlen );	
		break;


		default:	//nes opcode min/max definition error 
			rv[RV_ERR_IDX] = ERR_BAD_OPER_OP_MINMAX;
	}

	return rptr;
}

read_funcptr	decode_rdfunc_num(uint8_t dict, uint8_t func_num ) 
{

	if ( dict == DICT_NES ) {
		switch( func_num ) {
			case NES_CPU_RD: return nes_cpu_rd;
			case NES_PPU_RD: return nes_ppu_rd;
			case EMULATE_NES_CPU_RD: return emulate_nes_cpu_rd;
			default:
				return (void*)~SUCCESS;
		}
	} else {
		//dictionary not supported
		return (void*)~SUCCESS;
	}
}

write_funcptr	decode_wrfunc_num(uint8_t dict, uint8_t func_num ) 
{
	if ( dict == DICT_NES ) {
		switch( func_num ) {
			case DISCRETE_EXP0_PRGROM_WR: 
				return discrete_exp0_prgrom_wr;
			case NES_CPU_WR: 
				return nes_cpu_wr;
			case NES_PPU_WR: 
				return nes_ppu_wr;
			default:
				return (void*)~SUCCESS;
		}
	} else {
		//dictionary not supported
		return (void*)~SUCCESS;
	}
}


/* Desc:Function takes an opcode which was transmitted via USB
 * 	then decodes it to call designated function.
 * 	shared_dict_operation.h is used in both host and fw to ensure opcodes/names align
 * Pre: Macros must be defined in firmware pinport.h
 * 	opcode must be defined in shared_dict_operation.h
 * Post:function call complete.
 * Rtn: SUCCESS if opcode found, ERR_UNKN_OPER_OPCODE_NRV if opcode not present.
 */
uint8_t oper_opcode_no_return( uint8_t opcode, uint8_t operMSB, uint8_t operLSB, uint8_t miscdata )
{

	switch (opcode) { 
		case SET_OPERATION:	
			oper_info->operation = operLSB;
			break;
		case COPY_BUFF0_TO_ELEMENTS:	
			//copy over buff0 to oper_info elements
			//this should work for all byte variables, but not functions
			copy_buff0_to_data( (uint8_t *)oper_info, OPER_DATA_NUM_BYTE_ELEMENTS );
			break;
		case COPY_ELEMENTS_TO_BUFF0:	
			copy_data_to_buff0( (uint8_t *)oper_info, OPER_DATA_NUM_BYTE_ELEMENTS );
			break;
		//operMSB contains dictionary, operLSB contains function number
		//decode that into proper function pointer
		case SET_OPER_FUNC:	
			//oper_info->oper_func = decode_opfunc_num( operLSB );
			break;
		case SET_RD_FUNC:	
			oper_info->rd_func = decode_rdfunc_num( operMSB, operLSB );
			break;
		case SET_WR_MEM_FUNC:	
			oper_info->wr_mem_func = decode_wrfunc_num( operMSB, operLSB );
			break;
		case SET_WR_MAP_FUNC:	
			oper_info->wr_map_func = decode_wrfunc_num( operMSB, operLSB );
			break;
		default:
			 //opcode doesn't exist
			 return ERR_UNKN_OPER_OPCODE_NRV;
	}
	
	return SUCCESS;

}


/* Desc:Function takes an opcode which was transmitted via USB
 * 	then decodes it to call designated function.
 * 	shared_dict_operation.h is used in both host and fw to ensure opcodes/names align
 * Pre: Macros must be defined in firmware pinport.h
 * 	opcode must be defined in shared_dict_operation.h
 * Post:function call complete.
 * Rtn: SUCCESS if opcode found, ERR_UNKN_OPER_OPCODE_RV if opcode not present.
 */
uint8_t oper_opcode_return( uint8_t opcode, uint8_t operMSB, uint8_t operLSB, uint8_t miscdata, 
				uint8_t *rvalue, uint8_t *rlength )
{
	switch (opcode) { 
		case GET_OPERATION:	
			*rvalue = oper_info->operation;	
			*rlength += 1;
			break;
		default:
			 //opcode doesn't exist
			 return ERR_UNKN_OPER_OPCODE_RV;
	}
	
	return SUCCESS;

}

void set_operation( uint8_t op ) 
{
	oper_info->operation = op;
}

uint8_t get_operation( void ) 
{
	return oper_info->operation;
}
