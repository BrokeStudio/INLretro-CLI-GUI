#ifndef _shared_dict_gb_h
#define _shared_dict_gb_h

// define dictionary's reference number in the shared_dictionaries.h file
// then include this dictionary file in shared_dictionaries.h
// The dictionary number is literally used as usb transfer request field
// the opcodes and operands in this dictionary are fed directly into usb setup packet's wValue wIndex fields

//=============================================================================================
//=============================================================================================
// GAME BOY DICTIONARY
//
// opcodes contained in this dictionary must be implemented in firmware/source/gb.c
//
//=============================================================================================
//=============================================================================================

#define GB_RD 0 // RL=3  return error code, data len = 1, 1 byte of data
#define GB_WR 1
#define GB_FLASH_WR 2
#define GB_PIN31_WR 3
#define GB_FLASH_WR_PIN31 4
#define GB_FLASH_WR_PIN31_UNLOCK 5
#define GB_FLASH_WR_PIN31_SHORT 6
#define GB_PAGE_WR_LFSR 7

#define GB_SET_CUR_BANK 0x20

#endif
