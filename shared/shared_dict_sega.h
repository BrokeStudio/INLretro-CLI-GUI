#ifndef _shared_dict_sega_h
#define _shared_dict_sega_h

//define dictionary's reference number in the shared_dictionaries.h file
//then include this dictionary file in shared_dictionaries.h
//The dictionary number is literally used as usb transfer request field
//the opcodes and operands in this dictionary are fed directly into usb setup packet's wValue wIndex fields


//=============================================================================================
//=============================================================================================
// SEGA (genesis/megadrive) DICTIONARY
//
// opcodes contained in this dictionary must be implemented in firmware/source/sega.c
//
//=============================================================================================
//=============================================================================================

//TODO THESE ARE JUST PLACE HOLDERS...
//oper=A1-15 update firmware address variable for FLASH_WR_ADDROFF use on subsequent calls
#define	GEN_SET_ADDR_LO	0
#define	GEN_SET_ADDR_HI	1
#define	GEN_SET_ADDR	2

//oper=A1-A16 C_CE & C_OE go low (update firmware address var ie GEN_SET_ADDR)
#define	GEN_ROM_RD	3	//RL=4 return error code, data len = 1, 2 byte of data (16bit word)
#define	GEN_ROM_WR	4

// GENESIS ADDR A17-23 along with #LO_MEM & #TIME
// TODO separate #LO_MEM & #TIME, they're currently fixed high
// #define GEN_SET_BANK 3

//miscdata=D0-7, oper=A1-A16 C_CE & C_OE go low, #LDSW goes low (update firmware address var ie GEN_SET_ADDR)
#define	GEN_WR_LO	5
//miscdata=D8-15, oper=A1-A16 C_CE & C_OE go low, #UDSW goes low (update firmware address var ie GEN_SET_ADDR)
#define	GEN_WR_HI	6
//oper=D0-D15, miscdata=addroffset C_CE & C_OE go low, #UDSW goes low (update firmware address var ie GEN_SET_ADDR)
// #define	GEN_FLASH_WR_ADDROFF	7
// #define	GEN_SST_FLASH_WR_ADDROFF	8

//enable/disable RAM in ROM upper part (>=0x200000)
#define	GEN_SET_RAM	7
#define	GEN_RAM_WR	8
#define	GEN_RAM_RD	9	//RL=3

#define GEN_TIME_WR 10

#define GEN_PAGE_RAM_WR_LFSR 11

#endif
