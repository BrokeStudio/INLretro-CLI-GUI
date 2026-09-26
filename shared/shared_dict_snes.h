#ifndef _shared_dict_snes_h
#define _shared_dict_snes_h

//define dictionary's reference number in the shared_dictionaries.h file
//then include this dictionary file in shared_dictionaries.h
//The dictionary number is literally used as usb transfer request field
//the opcodes and operands in this dictionary are fed directly into usb setup packet's wValue wIndex fields

//=============================================================================================
//=============================================================================================
// SNES DICTIONARY
//
// opcodes contained in this dictionary must be implemented in firmware/source/snes.c
//
//=============================================================================================
//=============================================================================================

//set A16-23 aka bank number
#define SNES_SET_BANK 0x00

//read from current bank at provided address
//SNES reset is unaffected
#define SNES_RD 0x01 //RL=3

//write from current bank at provided address with /ROMSEL set to lo
//SNES reset is unaffected
#define SNES_WR_LO 0x02

//write from current bank at provided address with /ROMSEL set to hi
//SNES reset is unaffected
#define SNES_WR_HI 0x03

#define SNES_FLASH_WR 0x04 // flash algo

//similar to ROM RD/WR above, but /ROMSEL doesn't go low
// #define SNES_SYS_RD 0x04 //RL=3
// #define SNES_SYS_WR 0x05

#define SNES_PAGE_WR_LFSR 0x05

#endif
