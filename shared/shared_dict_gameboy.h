#ifndef _shared_dict_gameboy_h
#define _shared_dict_gameboy_h

// define dictionary's reference number in the shared_dictionaries.h file
// then include this dictionary file in shared_dictionaries.h
// The dictionary number is literally used as usb transfer request field
// the opcodes and operands in this dictionary are fed directly into usb setup packet's wValue wIndex fields

//=============================================================================================
//=============================================================================================
// GAMEBOY DICTIONARY
//
// opcodes contained in this dictionary must be implemented in firmware/source/gameboy.c
//
//=============================================================================================
//=============================================================================================

#define GAMEBOY_RD 0 // RL=3  return error code, data len = 1, 1 byte of data
#define GAMEBOY_WR 1
#define GAMEBOY_FLASH_WR 2
#define GAMEBOY_PIN31_WR 3
#define GAMEBOY_FLASH_PIN31_WR 4
#define GAMEBOY_UNLOCK_3V_FLASH_PIN31_WR 5
#define GAMEBOY_3V_FLASH_PIN31_WR 6
#define GAMEBOY_PAGE_WR_LFSR 7

#define GAMEBOY_SET_CUR_BANK 0x20

#endif
