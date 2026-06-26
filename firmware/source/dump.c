#include "dump.h"

/* Desc:Dump cart memory into buffer's data array
 * Pre: buffer elements must be updated to designate how/where to dump
 * 	buffer's cur_byte must be cleared or set to where to start dumping
 * Post:page dumped from cart memory to buffer.
 * Rtn: SUCCESS or ERROR# depending on if there were errors.
 */
uint8_t dump_buff(buffer *buff)
{

  uint8_t addrH = buff->page_num; // A15:8  while accessing page
  uint8_t bank;

  switch (buff->mem_type)
  {
#ifdef NES_CONN
  case NESCPU_4KB:
    // mapper lower nibble specifies NES CPU A12-15
    if (buff->mapper > 0x0F)
    {
      // mapper can only be 4bits (0-15)
      return ERR_BUFF_PART_NUM_RANGE;
    }
    addrH |= (buff->mapper << 4); // 8 << 12 = shift by 4
    buff->cur_byte = nes_cpu_page_rd_poll(buff->data, addrH, buff->id,
                                          // id contains MSb of page when <256B buffer
                                          buff->last_idx, ~FALSE);
    break;

  case NESCPU_4KB_TOGGLE:
    // mapper lower nibble specifies NES CPU A12-15
    if (buff->mapper > 0x0F)
    {
      // mapper can only be 4bits (0-15)
      return ERR_BUFF_PART_NUM_RANGE;
    }
    addrH |= (buff->mapper << 4); // 8 << 12 = shift by 4
    buff->cur_byte = nes_cpu_page_rd_toggle(buff->data, addrH, buff->id,
                                            // id contains MSb of page when <256B buffer
                                            buff->last_idx, ~FALSE);
    break;

  case NESPPU_1KB:
    // mapper bits 2-5 specifies NES PPU A10-13
    if (buff->mapper & 0xC3)
    { // make sure bits 7, 6, 1, & 0 aren't set
      // mapper can only have bits 2-5 set
      return ERR_BUFF_PART_NUM_RANGE;
    }
    addrH |= buff->mapper; // PPU A10-13 get set based on mapper
    buff->cur_byte = nes_ppu_page_rd_poll(buff->data, addrH, buff->id,
                                          buff->last_idx, ~FALSE);
    break;

  case NESPPU_1KB_TOGGLE:
    // mapper bits 2-5 specifies NES PPU A10-13
    if (buff->mapper & 0xC3)
    { // make sure bits 7, 6, 1, & 0 aren't set
      // mapper can only have bits 2-5 set
      return ERR_BUFF_PART_NUM_RANGE;
    }
    addrH |= buff->mapper; // PPU A10-13 get set based on mapper
    buff->cur_byte = nes_ppu_page_rd_toggle(buff->data, addrH, buff->id,
                                            buff->last_idx, ~FALSE);
    break;

  case NESCPU_PAGE:
    // mapper byte specifies CPU A15-8
    addrH |= buff->mapper;
    buff->cur_byte = nes_cpu_page_rd_poll(buff->data, addrH, buff->id,
                                          // id contains MSb of page when <256B buffer
                                          buff->last_idx, ~FALSE);
    break;

  case NESCPU_PAGE_TOGGLE:
    // mapper byte specifies CPU A15-8
    addrH |= buff->mapper;
    buff->cur_byte = nes_cpu_page_rd_toggle(buff->data, addrH, buff->id,
                                            // id contains MSb of page when <256B buffer
                                            buff->last_idx, ~FALSE);
    break;

  case NESPPU_PAGE:
    // mapper byte specifies PPU A13-8
    if (buff->mapper & 0xC0)
    { // make sure bits 7, 6 aren't set
      // mapper can only have bits 5-0 set
      return ERR_BUFF_PART_NUM_RANGE;
    }
    addrH |= buff->mapper; // PPU A10-13 get set based on mapper
    buff->cur_byte = nes_ppu_page_rd_poll(buff->data, addrH, buff->id,
                                          buff->last_idx, ~FALSE);
    break;

#ifdef STM_INL6
  case CIC_READ_BUFFER:
    buff->cur_byte = cic_read_buffer(buff);
    if (buff->cur_byte <= buff->last_idx)
    {
      return GEN_FAIL;
    }
    break;
#endif

    // case PRGROM:
    //   addrH |= 0x80; //$8000
    //   if (buff->mapper == MAP30)
    //   {
    //     // addrH &= 0b1011 1111 A14 must always be low
    //     addrH &= 0xBF;
    //     // write bank value to bank table
    //     // page_num shift by 6 bits A14 >> A8(0)
    //     bank = (buff->page_num) >> 6;
    //     // mapper register $C000-FFFF
    //     nes_cpu_wr(0xC000, bank);

    //     buff->cur_byte = nes_cpu_page_rd_poll(buff->data, addrH, buff->id,
    //                                           // id contains MSb of page when <256B buffer
    //                                           buff->last_idx, ~FALSE);
    //     break;
    //   }
    //   if (buff->mapper == A53)
    //   {
    //     // write bank value to bank table
    //     // page_num shift by 7 bits A15 >> A8(0)
    //     bank = (buff->page_num) >> 7;
    //     // Setup as CNROM, then scroll through outer banks.
    //     // cpu_wr(0x5000, 0x80); //reg select mode
    //     //    xxSSPPMM   SS-size: 0-32KB, PP-prg mode: 0,1 32KB, MM-mirror
    //     // cpu_wr(0x8000, 0b00000000);   //reg value 256KB inner, 32KB banks
    //     nes_cpu_wr(0x5000, 0x81); // outer reg select mode
    //     nes_cpu_wr(0x8000, bank); // outer bank
    //     nes_cpu_wr(0x5000, 0x00); // chr reg select act like CNROM
    //   }
    //   /* migrated to script controlled
    //   if (buff->mapper == EZNSF) {
    //     //addrH &= 0b1000 1111 A14-12 must always be low
    //     addrH &= 0x8F;
    //     //write bank value to bank table
    //     //page_num shift by 4 bits A12 >> A8(0)
    //     bank = (buff->page_num)>>4;
    //     nes_cpu_wr(0x5000, bank);	  //bank @ $8000-8FFF
    //   }
    //   buff->cur_byte = nes_cpu_page_rd_poll( buff->data, addrH, buff->id,
    //             //id contains MSb of page when <256B buffer
    //             buff->last_idx, ~FALSE );
    //   */
    //   break;

  case CHRROM: //$0000

    if (buff->mapper == DPROM)
    {
      // select bank
      // 8KB banks $0000-1FFF
      // page_num shift by 5 bits A13 >> A8(0)
      bank = (buff->page_num) >> 5;

      // write bank to register
      nes_ppu_wr(0x3FFF, bank);

      addrH &= 0x1F; // only A12-8 are directly addressable
      buff->cur_byte = nes_dualport_page_rd_poll(buff->data, addrH, buff->id,
                                                 buff->last_idx, ~FALSE);
    }
    break;

  case PRGRAM:
    addrH |= 0x60; //$6000
    buff->cur_byte = nes_cpu_page_rd_poll(buff->data, addrH, buff->id,
                                          buff->last_idx, ~FALSE);
    break;

#endif

#ifdef SNES_CONN
  case SNESROM_PAGE: // ROMSEL is always taken low
    // mapper byte specifies SNES CPU A15-8
    addrH |= (buff->mapper); // no shift needed
    buff->cur_byte = snes_page_rd_poll(buff->data, addrH, 0, buff->id,
                                       // id contains MSb of page when <256B buffer
                                       buff->last_idx, ~FALSE);
    break;

  case SNESSYS_PAGE: // ROMSEL stays high
    // mapper byte specifies SNES CPU A15-8
    addrH |= (buff->mapper); // no shift needed
    buff->cur_byte = snes_page_rd_poll(buff->data, addrH, 1, buff->id,
                                       // id contains MSb of page when <256B buffer
                                       buff->last_idx, ~FALSE);
    break;

  case SNESROM:
    if (buff->mapper == LOROM)
    {
      addrH |= 0x80; //$8000 LOROM space
      // need to split page_num
      // A14-8 page_num[6-0]
      // A15 high (LOROM)
      // A23-16 page_num[14-7]
      bank = (buff->page_num) >> 7;
    }
    if (buff->mapper == HIROM)
    {
      // need to split page_num
      // A15-8 page_num[7-0]
      // A21-16 page_num[13-8]
      // A22 high (HIROM)
      // A23 ~page_num[14] (bank CO starts first half, bank 40 starts second)
      bank = ((((buff->page_num) >> 8) | 0x40) & 0x7F);
    }
    HADDR_SET(bank);
    buff->cur_byte = snes_page_rd_poll(buff->data, addrH, 0, buff->id,
                                       // id contains MSb of page when <256B buffer
                                       buff->last_idx, ~FALSE);
    break;
#endif

#ifdef GB_CONN
  case GAMEBOY_PAGE:
    // mapper byte specifies CPU A15-8
    addrH |= buff->mapper;
    buff->cur_byte = gameboy_page_rd_poll(buff->data, addrH, buff->id,
                                          // id contains MSb of page when <256B buffer
                                          buff->last_idx, 1);
    break;
  case GBA_ROM_PAGE:
    // address must have already been latched
    // we're only telling page_rd the number of bytes to read, and where to put it
    //  takes 16bit pointer, 127 / 2 = 63.5 -> 63 so it works
    buff->cur_byte = gba_page_rd((uint16_t *)buff->data, (buff->last_idx >> 1));
    // buff->cur_byte = gba_page_rd( buff->data, buff->last_idx );
    break;
#endif

#ifdef SEGA_CONN
  case GENESIS_ROM_PAGE0: // A16=0 first half of A1-A16 BANK
    // mapper byte specifies Genesis CPU A15-8
    addrH |= (buff->mapper); // no shift needed
    buff->cur_byte = gen_rom_page_rd(buff->data, addrH, buff->id,
                                     // id contains MSb of page when <256B buffer
                                     buff->last_idx);
    break;
  case GENESIS_ROM_PAGE1: // A16=1 second half of A1-A16 BANK
    // mapper byte specifies Genesis CPU A15-8
    addrH |= (buff->mapper); // no shift needed
    buff->cur_byte = gen_rom_page_rd(buff->data, addrH + 0x0100, buff->id,
                                     // id contains MSb of page when <256B buffer
                                     buff->last_idx);
    break;
  case GENESIS_RAM_PAGE: // Only read data from lower Byte D0-7
    // mapper byte specifies Genesis CPU A15-8
    addrH |= (buff->mapper); // no shift needed
    buff->cur_byte = gen_ram_page_rd(buff->data, addrH, buff->id,
                                     // id contains MSb of page when <256B buffer
                                     buff->last_idx);
    break;
#endif

#ifdef N64_CONN
  case N64_ROM_PAGE:
    // mapper byte specifies SNES CPU A15-8
    // uint8_t addrH = buff->page_num;	//A15:8  while accessing page
    //		addrH |= (buff->mapper); //no shift needed
    buff->cur_byte = n64_page_rd(buff->data, addrH, buff->id,
                                 // id contains MSb of page when <256B buffer
                                 buff->last_idx);
    break;
#endif

  default:
    return ERR_BUFF_UNSUP_MEM_TYPE;
  }

  return SUCCESS;
}
