#ifndef _types_h
#define _types_h

typedef struct setup_packet{
	uint8_t		bmRequestType;	//contains endpoint
	uint8_t		bRequest;	//designates dictionary of opcode
	uint8_t		opcode;		//wValueLSB (little endian)
	uint8_t		miscdata;	//wValueMSB 
	uint16_t	operand;	//16bit operand "wIndex"
	uint16_t	wLength;
}setup_packet;


//write function pointers
//typedef	void	(*write_funcptr) 	( uint8_t addrH, uint8_t addrL, uint8_t data );
//typedef	uint8_t	(*read_funcptr)		( uint8_t addrH, uint8_t addrL );
typedef	void	(*write_funcptr) 	( uint16_t addr, uint8_t data );
typedef	void	(*write_funcptr_pg) 	( uint16_t addr, uint8_t *data );
typedef	uint8_t	(*write_rv_funcptr) 	( uint16_t addr, uint8_t data );
typedef	uint8_t	(*read_funcptr)		( uint16_t addr );
typedef	void	(*write_snes_funcptr) 	( uint16_t addr, uint8_t data, uint8_t romsel );
typedef	uint8_t	(*read_snes_funcptr)	( uint16_t addr, uint8_t romsel );


//~16 bytes per buffer...
typedef struct buffer {

	uint16_t 	page_num;	//address bits beyond buffer's size and buff_num A23-A8
					//MSB A23-16, LSB A15-8

	uint8_t 	id;		//address bits between buffer size and page number
					//ie need 2x128 byte buffers making buff_num = A7
					//ie need 4x64 byte buffers making buff_num = A7:6
					//ie need 8x32 byte buffers making buff_num = A7:5
					
	uint8_t		status;		//current status of buffer USB load/unload, flashing, waiting, erase

	uint8_t 	*data;		//pointer to base buffer's allocated sram

	//uint8_t 	size;		//size of buffer in bytes (max 256 bytes) THIS DOESN'T work 256B = 9bit value
	uint8_t 	last_idx;	//index of last byte in buffer used to determine when at end of buffer


	uint8_t 	cur_byte;	//byte currently being loaded/unloaded/flashed/read

	uint8_t		reload;		//add this number to page_num for next loading

	uint8_t		mem_type;	//SNES ROM, SNES RAM, PRG ROM, PRG RAM, CHR ROM, CHR RAM, CPLD, SPI
	
	uint8_t		part_num;	//used to define unlock commands, sector erase, etc

	//currently unused
	uint8_t		multiple;	//number of times to program this page

	//currently unused
	uint8_t		add_mult;	//add this number to page_num for multiple programs
					//CHR shift LSb to A13 (max 2MByte)
					//PRG shift LSb to A14 (max 4MByte)
					//SNES add to MSB of page_num (max 16MByte)

	uint8_t		mapper;		//mapper number of board
					//some mem_types like NESCPU_4KB use this to specify address range
					//because they're mapper independent

	//currently unused
	uint8_t		mapvar;		//mapper variant 

	//currently unused
	uint8_t		function;	//function "pointer" for flash/dump operation control
}buffer;


typedef struct operation_info {
	uint8_t		operation;	//overall type of operation being performed
	uint8_t		addrH_dmask;	//mask page_num lower byte to get directly addressable A15:A8 bits
	uint8_t		pg2bank_shright; //shift page_num to right this many bits to get cur bank value
	uint8_t		valid_addr_msb;	//most significant bit that must be valid for operation (ie A14 SST)	//unlock sequence SST $5555 0xAA
	uint8_t		unlock1_bank;	//unlock sequence #1 bank number for mapper reg
	uint8_t		unlock1_AH;	//unlock sequence #1 A15:A8
	uint8_t		unlock1_AL;	//unlock sequence #1 A7:A0
	uint8_t		unlock1_data;	//unlock sequence #1 D7:D0
//unlock sequence SST $2AAA 0x55
	uint8_t		unlock2_bank;	//unlock sequence #1 bank number for mapper reg
	uint8_t		unlock2_AH;	//unlock sequence #2 A15:A8
	uint8_t		unlock2_AL;	//unlock sequence #2 A7:A0
	uint8_t		unlock2_data;	//unlock sequence #2 D7:D0
//command SST byte write $5555 0xA0,  SST sector/chip erase $5555 0x80
	uint8_t		command_bank;	//flash command bank (ie bank to write byte write, sector erase cmd)
	uint8_t		command_AH;	//flash command A15:A8
	uint8_t		command_AL;	//flash command A7:A0
	uint8_t		command1_data;	//flash command D7:D0 command 1 data (ie SST sect erase 0x80)
	uint8_t		command2_data;	//flash command D7:D0 command 2 data (ie SST sect erase 0x30)
//actual byte operation (ie Byte address bank and addr)
	uint8_t		oper_bank;	//current bank value for actual operation to be done (ie write byte)
	uint8_t		oper_AH;	//operation A15:A8 (ie actual byte write address)
	//uint8_t		oper_AL;	//operation A7:A0
	//uint8_t		oper_data;	//operation D7:D0 (ie actual byte data)
//TODO	oper_funcptr	op_func;	//function used for overall operation
	read_funcptr	rd_func;	//function used to read memory
	write_funcptr	wr_mem_func;	//function used to write to memory
	write_funcptr	wr_map_func;	//function used to write to mapper
}operation_info;


#endif
