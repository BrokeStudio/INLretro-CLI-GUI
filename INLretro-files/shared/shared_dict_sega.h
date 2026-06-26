#ifndef _shared_dict_sega_h
#define _shared_dict_sega_h

// define dictionary's reference number in the shared_dictionaries.h file
// then include this dictionary file in shared_dictionaries.h
// The dictionary number is literally used as usb transfer request field
// the opcodes and operands in this dictionary are fed directly into usb setup packet's wValue wIndex fields

//=============================================================================================
//=============================================================================================
// SEGA (genesis/megadrive) DICTIONARY
//
// opcodes contained in this dictionary must be implemented in firmware/source/sega.c
//
//=============================================================================================
//=============================================================================================

#define GEN_SET_ADDR_LO 0
#define GEN_SET_ADDR_HI 1
#define GEN_SET_ADDR 2

#define GEN_ROM_RD 3 // RL=4 return error code, data len = 1, 2 byte of data (16bit word)
#define GEN_ROM_WR 4

#define GEN_RAM_RD 5 // RL=3 return error code, data len = 1, 1 byte of data
#define GEN_RAM_WR 6
#define GEN_PAGE_RAM_WR_LFSR 7

#define GEN_TIME_RD 8 // RL=3 return error code, data len = 1, 1 byte of data
#define GEN_TIME_WR 9

#endif
