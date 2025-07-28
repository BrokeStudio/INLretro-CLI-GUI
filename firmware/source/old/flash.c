#include "flash.h"


uint8_t	write_page( uint8_t bank, uint8_t addrH, buffer *buff, write_funcptr wr_func, read_funcptr rd_func )
{
	uint16_t cur = buff->cur_byte;
	uint8_t	n = buff->cur_byte;
	uint8_t read;
	extern operation_info *oper_info;

	while ( cur <= buff->last_idx ) {
		//write unlock sequence
		//need to make address and unlock data variable
		//best for host to communcate these values
		//actual value is part mapper dependent and part flash dependent
		//mapper controlled address bits dictate where split is
		//32KB banking A14-0 NES ctl, A15+ mapper ctl "bank" NROM, BNROM, ANROM
		//addrH_dmask   = 0b0111 1111 directly addressable addrH bits
		//page2bankshft = A14->A8 = 7 shifts (equal to number of set bits in addrH_mask
		//16KB banking A13-0 NES ctl, A14+ mapper ctl "bank" UxROM, MMC1
		//addrH_dmask   = 0b0011 1111
		//page2bankshft = A13->A8 = 6 shifts
		// 8KB banking A12-0 NES ctl, A13+ mapper ctl "bank" MMC3, FME7
		//addrH_dmask   = 0b0001 1111
		//page2bankshft = A12->A8 = 5 shifts
		// 4KB banking A11-0 NES ctl, A12+ mapper ctl "bank" ezNSF
		//addrH_dmask   = 0b0000 1111
		//page2bankshft = A11->A8 = 4 shifts
		//wr_func( 0x55, 0x55, 0xAA );
		wr_func( oper_info->unlock1_AH, oper_info->unlock1_AL, oper_info->unlock1_data );
		//wr_func( 0x2A, 0xAA, 0x55 );
		wr_func( oper_info->unlock2_AH, oper_info->unlock2_AL, oper_info->unlock2_data );
		//wr_func( 0x55, 0x55, 0xA0 );
		wr_func( oper_info->command_AH, oper_info->command_AL, oper_info->command1_data );
		wr_func( addrH, n, buff->data[n] );
	
		do {
			usbPoll();
			read = rd_func( addrH, n );
	
		} while( read != rd_func( addrH, n) );
		//TODO verify byte is value that was trying to be flashed
		//move on to next byte
		n++;
		cur++;

	}

	buff->cur_byte = n;

	return SUCCESS;

} 

/* Desc:Flash buffer contents on to cartridge memory
 * Pre: buffer elements must be updated to designate how/where to flash
 * 	buffer's cur_byte must be cleared or set to where to start flashing
 *	mapper registers must be initialized
 * Post:buffer page flashed/programmed to memory.
 * Rtn: SUCCESS or ERROR# depending on if there were errors.
 */
uint8_t flash_buff( buffer *buff ) {

	uint8_t addrH = buff->page_num;	//A15:8  while accessing page

	//First need to initialize mapper register bits
	//Perhaps this only needs to be done on first buffer though..?
	//Actually think this is best handled from buffer.c in operation == STARTFLASH

	//TODO use mapper to set mapper controlled address bits

	//need to calculate current bank and addrH

	//TODO set unlock addresses based on what works for that mapper and how it's banks are initialized

	//use mem_type to set addrH/X as needed for dump loop
	//also use to get read function pointer
	switch ( buff->mem_type ) {
		case PRGROM:		//$8000
			write_page( 0, (0x80 | addrH), buff, discrete_exp0_prgrom_wr, nes_cpu_rd );
			break;
		case CHRROM:		//$0000
			write_page( 0, addrH, buff, nes_ppu_wr, nes_ppu_rd );
			break;
		case PRGRAM:
			//addrH |= 0x60;	//$6000
			//buff->cur_byte = nes_cpu_page_wr_poll( buff->data, addrH, buff->id,
		//						buff->last_idx, ~FALSE );
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

