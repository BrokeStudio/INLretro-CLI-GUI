#include "dump.h"

/* Desc:Dump cart memory into buffer's data array
 * Pre: buffer elements must be updated to designate how/where to dump
 * 	buffer's cur_byte must be cleared or set to where to start dumping
 * Post:page dumped from cart memory to buffer.
 * Rtn: SUCCESS or ERROR# depending on if there were errors.
 */
uint8_t dump_buff( buffer *buff ) {

	uint8_t addrH = buff->page_num;	//A15:8  while accessing page
//warn	uint8_t addrX;	//A23:16 while accessing page

	//TODO use mapper to set mapper controlled address bits

	//use mem_type to set addrH/X as needed for dump loop
	//also use to get read function pointer
	switch ( buff->mem_type ) {
		case PRGROM:
			addrH |= 0x80;	//$8000
	//uint8_t nes_cpu_page_rd( uint8_t *data, uint8_t addrH, uint8_t first, uint8_t last, uint8_t poll )
			buff->cur_byte = nes_cpu_page_rd_poll( buff->data, addrH, buff->id, 
								//id contains MSb of page when <256B buffer
								buff->last_idx, ~FALSE );
			break;
		case CHRROM:		//$0000
			buff->cur_byte = nes_ppu_page_rd_poll( buff->data, addrH, buff->id,
								buff->last_idx, ~FALSE );
			break;
		case PRGRAM:
			addrH |= 0x60;	//$6000
			buff->cur_byte = nes_cpu_page_rd_poll( buff->data, addrH, buff->id,
								buff->last_idx, ~FALSE );
			break;
		case SNESROM:
		case SNESRAM:
//warn			addrX = ((buff->page_num)>>8);
			break;
		default:
			return ERR_BUFF_UNSUP_MEM_TYPE;
	}


	//lets start just reading first page of PRG-ROM then get fancy
//	while (buff->cur_byte < buff->last_idx) {
//
//		//might be faster to put some of these in new pointers, but not sure..
//		buff->data[buff->cur_byte] = nes_cpu_rd( addrH, buff->cur_byte );
//		buff->cur_byte++;
//	}

	return SUCCESS;
}
