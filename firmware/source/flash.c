#include "flash.h"
#include "cic.h"

#if defined(NES_CONN) || defined(GB_CONN) || defined(SNES_CONN)
/* Desc: Write and verify 8-bit data at 16-bit addresses
 *       write buff->cur_byte through buff->last_idx in the page at addrH
 *       compare the byte returned by wr_func against the expected value
 *       attempt each byte up to three times before stopping on a mismatch
 * Pre:  cartridge I/O initialized and desired bank selected
 *       buff->data contains the bytes to write within the 256-byte page
 *       wr_func performs one write attempt and returns the byte read back
 *       wr_func handles any required commands and bounded completion polling
 * Post: buff->cur_byte identifies the failed byte on failure
 *       on success it advances past last_idx (wraps to 0 after index 255)
 *       bytes preceding a failed byte have been written and verified
 *       bus state determined by wr_func
 * Rtn:  SUCCESS if all bytes are written and verified, or no bytes remain
 *       STOPPED if a byte still differs after three write attempts
 */
static uint8_t write_page_verify_8(uint8_t addrH, buffer* buff, write_rv_funcptr wr_func)
{
  uint16_t cur = buff->cur_byte;
  uint16_t addr;
  uint8_t value;
  uint8_t readback;
  uint8_t retries;

  while(cur <= buff->last_idx) {
    buff->cur_byte = cur;

    addr = ((uint16_t)addrH << 8) | cur;
    value = buff->data[cur];

    retries = 3;

    do {
      readback = wr_func(addr, value);
      if(readback == value) {
        LED_IP_PU();
        cur++;
        break;
      } else {
        LED_OP();
        LED_HI();
      }
    } while(--retries);

    if(readback != value) {
      return STOPPED;
    }
  }

  buff->cur_byte = cur;
  return SUCCESS;
}

/* Desc: Program 8-bit data using the flash write buffer
 *       write buff->cur_byte through buff->last_idx in the page at addrH
 *       send unlock, buffer load and confirm commands through wr_func
 *       poll the last byte through rd_func, calling usbPoll while waiting
 * Pre:  cartridge I/O initialized and desired bank selected
 *       flash supports the 0xAA/0x55, 0x25 and 0x29 command sequence
 *       unlock addresses use offsets 0xAAA/0x555 in the destination 4KB block
 *       byte range fits the flash write buffer and its alignment requirements
 *       buff->data contains the bytes to program
 * Post: buff->cur_byte unchanged so verification can start at the same byte
 *       only the last byte is checked; use buffer_verify_page for a full check
 *       bus state determined by wr_func and rd_func
 * Rtn:  SUCCESS if the last byte matches, or no bytes remain
 *       STOPPED if the last byte still differs when polling times out
 */
uint8_t buffer_write_page(uint8_t addrH, buffer* buff, write_funcptr wr_func, read_funcptr rd_func)
{
  uint16_t cur = buff->cur_byte;
  const uint16_t last = buff->last_idx;
  const uint16_t byte_count = (last + 1 - cur);
  uint16_t addr;
  uint16_t base_addr = (uint16_t)addrH << 8;
  uint8_t value;
  uint8_t readback;
  uint16_t timeout = 0xFFFF;

  uint16_t unlock_base = base_addr & 0xF000;
  uint16_t unlock_addr1 = unlock_base | 0xAAA;
  uint16_t unlock_addr2 = unlock_base | 0x555;

  if(cur > last) {
    return SUCCESS;
  }

  // unlock and write data
  wr_func(unlock_addr1, 0xAA);
  wr_func(unlock_addr2, 0x55);
  wr_func(base_addr, 0x25);
  wr_func(base_addr, byte_count - 1);

  while(cur <= last) {
    addr = base_addr | cur;
    value = buff->data[cur + 0];

    wr_func(addr, value);

    cur++;
  }

  // write program buffer command
  wr_func(addr, 0x29);

  do {
    usbPoll();
    readback = rd_func(addr);
    if(readback == value) {
      break;
    }
  } while(--timeout);

  if(readback != value) {
    return STOPPED;
  }

  return SUCCESS;
}

/* Desc: Read and compare 8-bit data against the supplied buffer
 *       check buff->cur_byte through buff->last_idx in the page at addrH
 *       stop at the first byte that differs
 * Pre:  cartridge I/O initialized and desired bank selected
 *       memory ready for data reads through rd_func
 *       buff->data contains the expected bytes
 * Post: buff->cur_byte identifies the first mismatch on failure
 *       on success it advances past last_idx (wraps to 0 after index 255)
 *       bus state determined by rd_func
 * Rtn:  SUCCESS if all checked bytes match, or no bytes remain
 *       STOPPED on the first mismatch
 */
uint8_t buffer_verify_page(uint8_t addrH, buffer* buff, read_funcptr rd_func)
{
  uint16_t cur = buff->cur_byte;
  uint16_t addr;
  uint8_t value;
  uint8_t readback;

  cur = buff->cur_byte;
  while(cur <= buff->last_idx) {
    value = buff->data[cur + 0];
    addr = (addrH << 8) | cur;

    readback = rd_func(addr);

    if(readback != value) {
      buff->cur_byte = cur;
      return STOPPED;
    }

    cur++;
  }

  buff->cur_byte = cur;
  return SUCCESS;
}

/* Desc: Program a flash write buffer, then verify every programmed byte
 *       call buffer_write_page and verify only if programming succeeds
 * Pre:  all requirements of buffer_write_page and buffer_verify_page apply
 *       desired bank remains selected throughout programming and verification
 * Post: buff->cur_byte unchanged if programming times out
 *       otherwise it identifies the first verification mismatch, or advances
 *       past last_idx on success (wraps to 0 after index 255)
 *       bus state determined by wr_func and rd_func
 * Rtn:  SUCCESS if programming and verification succeed, or no bytes remain
 *       STOPPED on a programming timeout or verification mismatch
 */
uint8_t buffer_write_page_verify(uint8_t addrH, buffer* buff, write_funcptr wr_func, read_funcptr rd_func)
{
  uint8_t result;

  result = buffer_write_page(addrH, buff, wr_func, rd_func);

  if(result == SUCCESS) {
    result = buffer_verify_page(addrH, buff, rd_func);
  }

  return result;
}

#endif

#ifdef NES_CONN

static uint8_t nes_prgram_wr_verify(uint16_t addr, uint8_t data)
{
  nes_cpu_wr(addr, data);
  return nes_cpu_rd(addr);
}

// only used by cninja currently..
uint8_t write_page_cninja(uint8_t bank, uint8_t addrH, uint16_t unlock1, uint16_t unlock2, buffer* buff, write_funcptr wr_func, read_funcptr rd_func)
{
  uint16_t cur = buff->cur_byte;
  uint16_t addr;
  uint8_t value;
  uint8_t readback;

  while(cur <= buff->last_idx) {
    addr = (addrH << 8) | cur;
    value = buff->data[cur];

    // write unlock sequence
    wr_func(unlock1, 0xAA);
    wr_func(unlock2, 0x55);
    wr_func(unlock1, 0xA0);
    wr_func(addr, value);
    do {
      usbPoll();
      readback = rd_func(addr);
    } while(readback != rd_func(addr));

    cur++;
  }
  buff->cur_byte = cur;
  return SUCCESS;
}

// only used by MM2 currently
uint8_t write_page_mm2(uint8_t bank, uint8_t addrH, uint16_t unlock1, uint16_t unlock2, buffer* buff, write_funcptr wr_func, read_funcptr rd_func)
{
  uint16_t cur = buff->cur_byte;
  uint16_t addr;
  uint8_t value;
  uint8_t readback;

  while(cur <= buff->last_idx) {
    addr = (addrH << 8) | cur;
    value = buff->data[cur];

    nes_cpu_wr((0xFD69), 0x00);
    wr_func(unlock1, 0xAA);
    wr_func(unlock2, 0x55);
    wr_func(unlock1, 0xA0);
    nes_cpu_wr((0xFD69 + bank), bank);
    wr_func(addr, value);

    do {
      usbPoll();
      readback = rd_func(addr);
    } while(readback != rd_func(addr));
    if(readback == value) {
      cur++;
      LED_IP_PU();
      LED_LO();
    } else {
      LED_OP();
      LED_HI();
    }
  }
  buff->cur_byte = cur;
  return SUCCESS;
}

#endif

#ifdef SNES_CONN
// uint8_t snes_write_page_buffer(uint8_t addrH, buffer* buff)
// {
//   uint16_t cur = buff->cur_byte;
//   uint16_t addr = addrH << 8;
//   uint8_t value;
//   uint8_t readback;
//   uint16_t byte_count = (buff->last_idx + 1 - buff->cur_byte);
//   uint8_t romsel = 0;
//   uint16_t timeout = 0xFFFF;

// // unlock and write data
// snes_wr(0x8AAA, 0xAA, romsel);
// snes_wr(0x8555, 0x55, romsel);
// snes_wr(addr, 0x25, romsel);
// snes_wr(addr, byte_count - 1, romsel);

// while(cur <= buff->last_idx) {
//   addr = (addrH << 8) | cur;
//   value = buff->data[cur + 0];

// //write function returns when it's complete or errors out
// snes_wr(addr, value, romsel);

// cur++;
//}

// // write program buffer command
// snes_wr(addr, 0x29, romsel);

// do {
//   usbPoll();
//   readback = snes_rd(addr, romsel);
//   if(readback == value) {
//     break;
//   }
// } while(--timeout);

// if(readback != value) {
//   return STOPPED;
// }

// // control written buffer
// cur = buff->cur_byte;
// while(cur <= buff->last_idx) {
//   value = buff->data[cur + 0];
//   addr = (addrH << 8) | cur;
//   //write function returns when it's complete or errors out

// readback = snes_rd(addr, romsel);

// if(readback != value) {
//   buff->cur_byte = cur;
//   return STOPPED;
// }

// cur++;
//}

// buff->cur_byte = cur;
// return SUCCESS;
//}

  // #define PRGM_MODE() swim_wotf(SWIM_HS, 0x500F, 0x40)
  // #define PLAY_MODE() swim_wotf(SWIM_HS, 0x500F, 0x00)
  // #define PRGM_MODE() EXP0_LO()
  // #define PLAY_MODE() EXP0_HI()
  #define PRGM_MODE() NOP()
  #define PLAY_MODE() NOP()

// uint8_t snes_write_page_unlock(uint8_t bank, uint8_t addrH, buffer* buff, write_snes_funcptr wr_func, read_snes_funcptr rd_func)
// {
//   uint16_t cur = buff->cur_byte;
//   uint8_t n = buff->cur_byte;
//   uint8_t read;
//   #ifdef AVR_CORE
//   wdt_reset();
//   #endif
//   // set to program mode for first entry
//   // EXP0_LO();
//   // swim_wotf(SWIM_HS, 0x500F, 0x40)
//   PRGM_MODE();

// //; TODO I don't think all these NOPs are actually needed, but they work and don't seem to significantly affect program time on stm32
// NOP();
// NOP();
// NOP();
// NOP();
// NOP();
// NOP();
// NOP();
// NOP();
// // enter unlock bypass mode
// wr_func(0x8AAA, 0xAA, 0);
// wr_func(0x8555, 0x55, 0);
// wr_func(0x8AAA, 0x20, 0);
// while(cur <= buff->last_idx) {
//   // write unlock sequence
//   // unlocked  wr_func( 0x0AAA, 0xAA );
//   // unlocked  wr_func( 0x0555, 0x55 );
//   // wr_func( 0x0000, 0xA0 );
//   snes_wr_cur_addr(0xA0, 0); // gained ~3KBps (59.13KBps) inl6 with v3.0 proto
//   wr_func(((addrH << 8) | n), buff->data[n], 0);
//   // wr_func( ((addrH<<8)| n), cur_data );  //didn't actually speed up
//   // Targetting 2MByte 16mbit flash which doesn't have buffered writes
//   // currently have average flash speed of 21.05KBps going to start removing some of these NOPs
//   // and optimizing flash routine to get time down.
//   // exit program mode
//   //  EXP0_HI();
//   PLAY_MODE();
//   NOP();
//   NOP();
//   NOP();
//   NOP();
//   NOP();
//   NOP();
//   NOP();
//   NOP();
//   // pre-fetch next byte of data
//   // cur_data = buff->data[n+1];
// #ifdef AVR_CORE
//   wdt_reset();
// #endif
//   // wait for byte to flash
//   //  do {
//   //    usbPoll();
//   //    read = rd_func((addrH<<8)|n);
//   //
//   //  //} while( read != rd_func((addrH<<8)|n) );
//   //  } while( read != buff->data[n] );
//   // this can cause things to hang on failed programs..
//   // need a smarter flash polling algo, kind of a pain because we don't have
//   // a good way to toggle /OE or /CE quickly on v3 SNES boards
//   usbPoll();
//   read = rd_func((addrH << 8) | n, 0);
//   // prepare for upcoming write cycle, or allow for a polling read
//   // EXP0_LO();
//   PRGM_MODE();
//   NOP();
//   NOP();
//   NOP();
//   NOP();
//   NOP();
//   NOP();
//   NOP();
//   NOP();
//   // First check if already outputting final data
//   if(read != buff->data[n]) {
//     // if not, lets see if toggle is occuring
//     // EXP0_HI();
//     PLAY_MODE();
//     NOP();
//     NOP();
//     NOP();
//     NOP();
//     NOP();
//     NOP();
//     NOP();
//     NOP();
//     while(read != rd_func((addrH << 8) | n, 0)) {
//       // EXP0_LO();
//       PRGM_MODE();
//       NOP();
//       NOP();
//       NOP();
//       NOP();
//       NOP();
//       NOP();
//       NOP();
//       NOP();
//       NOP();
//       NOP();
//       NOP();
//       NOP();
//       NOP();
//       NOP();
//       NOP();
//       NOP();
//       NOP();
//       NOP();
//       NOP();
//       NOP();
//       // EXP0_HI();
//       PLAY_MODE();
//       NOP();
//       NOP();
//       NOP();
//       NOP();
//       NOP();
//       NOP();
//       NOP();
//       NOP();
//       read = rd_func((addrH << 8) | n, 0);
//     }
//     // prepare for upcoming write cycle
//     // EXP0_LO();
//     PRGM_MODE();
//     NOP();
//     NOP();
//     NOP();
//     NOP();
//     NOP();
//     NOP();
//     NOP();
//     NOP();
//   }
//   // //IDK why, but AVR will exit early sometimes
//   // //without this second check, ~20 errors per 32KByte on SNES v3.0
//   // //All error bytes are 0xFF instead of true data
//   // //may need a smarter flash polling routine..
//   // //Tried to add extra delay to read algo, and didn't change anything
//   // //Also have decent trust in read routine as it's comparable to page read
//   // //which works flawlessly for dumps.  So think it has to do with flashing specifically...
//   // //Hmm maybe the avr is missing a read..  flash /CE, /OE, and /WE never toggle
//   // //so why would flash polling output different data between polls..?
//   // //Ahh this is the issue, adding the code below only adds delay which gives flash
//   // //enough time to complete write.

// // retry if write failed
// // this helped but still seeing similar fails to dumps
// n++;
// cur++;
// // if (read == buff->data[n]) {
// //   //n++;
// //   //cur++;
// //   LED_IP_PU();
// //   LED_LO();
// // } else {
// //   LED_OP();
// //   LED_HI();
// // }
//}

// buff->cur_byte = n;

// // exit unlock bypass mode
// wr_func(0x8000, 0x90, 0);
// wr_func(0x8000, 0x00, 0);
// // reset the flash chip, supposed to exit too
// wr_func(0x8000, 0xF0, 0);

// // exit program mode
// // EXP0_HI();
// PLAY_MODE();
// return SUCCESS;
//}
#endif

#ifdef GB_CONN

static uint8_t gb_ram_wr_verify(uint16_t addr, uint8_t data)
{
  gameboy_wr(addr, data);
  return gameboy_rd(addr);
}

#endif

#ifdef SEGA_CONN
uint8_t genesis_rom_write_page_verify(buffer* buff)
{
  uint16_t cur = buff->cur_byte; // need 16 bits here so it won't overflow

  uint8_t saved_addr_hi = gen_get_addr_hi();
  uint8_t page_addr_hi = saved_addr_hi + (buff->page_num >> 8);
  uint16_t base_addr = (buff->page_num & 0x00FF) << 8; // byte address for 256 bytes

  gen_set_addr_hi(page_addr_hi);

  uint16_t addr;
  uint16_t value;
  uint16_t readback;
  uint8_t retries;

  while(cur <= buff->last_idx) {
    buff->cur_byte = cur;

    value = buff->data[cur + 0] << 8;
    value |= buff->data[cur + 1];
    addr = base_addr + cur;

    retries = 3;

    do {
      // write word
      readback = gen_sst_flash_wr(addr, value);
      if(readback == value) {
        LED_IP_PU();
        cur += 2;
        break;
      } else {
        LED_OP();
        LED_HI();
      }
    } while(--retries);

    if(readback != value) {
      gen_set_addr_hi(saved_addr_hi);
      buff->cur_byte = cur;
      return STOPPED;
    }
  }
  gen_set_addr_hi(saved_addr_hi);
  buff->cur_byte = cur;
  return SUCCESS;
}

uint8_t genesis_rom_write_page_buffer_verify(buffer* buff)
{
  uint16_t cur = buff->cur_byte; // need 16 bits here so it won't overflow

  uint8_t saved_addr_hi = gen_get_addr_hi();
  uint8_t page_addr_hi = saved_addr_hi + (buff->page_num >> 8);
  uint16_t base_addr = (buff->page_num & 0x00FF) << 8; // byte address for 256 bytes

  gen_set_addr_hi(page_addr_hi);

  uint16_t addr;
  uint16_t value;
  uint16_t word_count = (buff->last_idx + 1 - buff->cur_byte) >> 1;

  // write "write to buffer" command and sector address
  gen_rom_wr(0x0555 << 1, 0x00AA);
  gen_rom_wr(0x02AA << 1, 0x0055);
  gen_rom_wr(base_addr, 0x0025);         // the bank set before calling sets the sector
  gen_rom_wr(base_addr, word_count - 1); // number of words to write minus one

  while(cur <= buff->last_idx) {
    value = buff->data[cur + 0] << 8;
    value |= buff->data[cur + 1];
    addr = base_addr + cur;

    // add word to write buffer
    gen_rom_wr(addr, value);

    cur = cur + 2;
  }

  // write program buffer to flash
  gen_rom_wr(base_addr, 0x29);

  uint16_t timeout = 0xFFFF;

  do {
    if(gen_rom_rd(addr) == value) {
      break;
    }
  } while(--timeout);

  gen_set_addr_hi(saved_addr_hi);

  if(!timeout) {
    return STOPPED;
  }

  return SUCCESS;
}

uint8_t genesis_ram_page_write(buffer* buff)
{
  uint16_t cur = buff->cur_byte;
  uint16_t addr_base = ((buff->page_num) << 8);
  uint16_t addr;
  uint16_t value;

  while(cur <= buff->last_idx) {
    addr = addr_base | cur;
    value = buff->data[cur];
    gen_ram_wr(addr, value);
    cur++;
  }
  buff->cur_byte = cur;

  // TODO error check/report
  return SUCCESS;
}
#endif

/* Desc: Flash buffer contents on to cartridge memory
 * Pre:  buffer elements must be updated to designate how/where to flash
 *       buffer's cur_byte must be cleared or set to where to start flashing
 *       mapper registers must be initialized
 * Post: buffer page flashed/programmed to memory.
 * Rtn:  SUCCESS or ERROR# depending on if there were errors.
 */
uint8_t flash_buff(buffer* buff)
{
  uint8_t result = SUCCESS;
  uint8_t addrH = buff->page_num; // A15:8  while accessing page
  uint8_t bank;

  // #ifdef SEGA_CONN
  //  uint16_t cur ;//= buff->cur_byte;
  //  uint8_t  n ;//= buff->cur_byte;
  //  uint16_t temp;
  //  uint16_t addr;
  // #endif

  switch(buff->mem_type) {
#ifdef NES_CONN

  #if defined(STM_INL6) || defined(STM_NES)
    case CIC:
      if(buff->mapper == CIC_WRITE_BUFFER) {
        cic_write_buffer(buff);
      }
      break;
  #endif

    case PRGROM: //$8000
      if(buff->mapper == NROM) {
        // used by other 32KB PRG bank discrete mappers like BNROM, CNROM, & color dreams
        result = write_page_verify_8((addrH + 0x80), buff, nrom_prgrom_flash_wr);
      }
      if(buff->mapper == MMC1) {
        result = write_page_verify_8((addrH + 0x80), buff, mmc1_prgrom_flash_wr);
      }
      if(buff->mapper == UxROM) {
        result = write_page_verify_8((addrH + 0x80), buff, unrom_prgrom_flash_wr);
      }
      if(buff->mapper == MMC3) {
        result = write_page_verify_8((addrH + 0x80), buff, mmc3_prgrom_flash_wr);
      }
      // SOP-44
      /*
    if (buff->mapper == MMC4) {
      nes_write_page( (0x80+addrH), buff, mmc4_prgrom_sop_flash_wr);
    }
    */
      // TODO use mapper variant to differentiate between the two
      // PLCC-32
      if(buff->mapper == MMC4) {
        result = write_page_verify_8((addrH + 0x80), buff, mmc4_prgrom_flash_wr);
      }
      if(buff->mapper == MM2) {
        // addrH &= 0b1011 1111 A14 must always be low
        addrH &= 0x3F;
        addrH |= 0x80; // A15 doesn't apply to exp0 write, but needed for read back
        // write bank value
        // page_num shift by 6 bits A14 >> A8(0)
        bank = buff->page_num >> 6;
        // bank gets written inside flash algo
        write_page_mm2(bank, addrH, 0x5555, 0x2AAA, buff, disc_push_exp0_prgrom_wr, nes_cpu_rd);
      }
      if(buff->mapper == MAP30) {
        result = write_page_verify_8((addrH + 0x80), buff, map30_prgrom_flash_wr);
      }
      if(buff->mapper == CNINJA) {
        // addrH &= 0b1001 1111 A14-13 must always be low
        addrH &= 0x1F;
        addrH |= 0x80;
        // write bank value
        // page_num shift by 5 bits A13 >> A8(0)
        bank = buff->page_num >> 5;
        nes_cpu_wr((0x6000), 0xA5); // select desired bank
        nes_cpu_wr((0xFFFF), bank); // select desired bank
        write_page_cninja(0, addrH, 0xD555, 0xAAAA, buff, nes_cpu_wr, nes_cpu_rd);
      }
      if(buff->mapper == A53) {
        result = write_page_verify_8((addrH + 0x80), buff, a53_prgrom_flash_wr);
      }
      if(buff->mapper == A53_512K) {
        // write_page_verify_8( (0x80+addrH), buff, a53_512k_prgrom_flash_wr);
        result = write_page_verify_8((addrH + 0x80), buff, a53_512k_prgrom_flash_wr);
      }
      if(buff->mapper == EZNSF) {
        // enter unlock bypass mode
        nes_m2_high_wr(0x9AAA, 0xAA);
        nes_m2_high_wr(0x9555, 0x55);
        nes_m2_high_wr(0x9AAA, 0x20);

        result = write_page_verify_8((addrH + 0x90), buff, tssop_prgrom_flash_wr);

        // exit unlock bypass mode
        nes_m2_high_wr(0x9000, 0x90);
        nes_m2_high_wr(0x9000, 0x00);

        // reset the flash chip, supposed to exit too
        nes_m2_high_wr(0x9000, 0xF0);
      }
      if(buff->mapper == GTROM) {
        result = write_page_verify_8((addrH + 0x80), buff, gtrom_prgrom_flash_wr);
      }
      if(buff->mapper == RNBW) {
        if(buff->part_num == USE_BUFFER) {
          result = buffer_write_page_verify((addrH + 0x80), buff, nes_cpu_wr, nes_cpu_rd);
        } else if(buff->part_num == USE_UNLOCK_BYPASS) {
          // enter unlock mode bypass
          nes_cpu_wr(0x8AAA, 0xAA);
          nes_cpu_wr(0x8555, 0x55);
          nes_cpu_wr(0x8AAA, 0x20);

          // write data
          result = write_page_verify_8((addrH + 0x80), buff, rnbw_prgrom_flash_unlock_wr);

          // exit unlock mode bypass
          nes_cpu_wr(0x8000, 0x90);
          nes_cpu_wr(0x8000, 0x00);

          // reset the flash chip, supposed to exit too
          nes_cpu_wr(0x8000, 0xF0);
        } else {
          result = write_page_verify_8((addrH + 0x80), buff, rnbw_prgrom_flash_wr);
        }
      }
      if(buff->mapper == VRC6a || buff->mapper == VRC6b) {
        result = write_page_verify_8((addrH + 0x60), buff, vrc6_prgrom_flash_wr);
      }
      break;

    case CHRROM: //$0000
      if(buff->mapper == NROM) {
        result = write_page_verify_8(addrH, buff, nrom_chrrom_flash_wr);
      }
      if(buff->mapper == MMC1) {
        result = write_page_verify_8(addrH, buff, mmc1_chrrom_flash_wr);
      }
      if(buff->mapper == CNROM) {
        result = write_page_verify_8(addrH, buff, cnrom_chrrom_flash_wr);
      }
      if(buff->mapper == MMC3) {
        result = write_page_verify_8(addrH, buff, mmc3_chrrom_flash_wr);
      }
      if(buff->mapper == MMC4) {
        result = write_page_verify_8(addrH, buff, mmc4_chrrom_flash_wr);
      }
      if(buff->mapper == CDREAM) {
        result = write_page_verify_8(addrH, buff, cdream_chrrom_flash_wr);
      }
      if(buff->mapper == VRC6a || buff->mapper == VRC6b) {
        result = write_page_verify_8(addrH, buff, mmc3_chrrom_flash_wr);
      }
      if(buff->mapper == RNBW) {
        if(buff->part_num == USE_BUFFER) {
          result = buffer_write_page_verify(addrH, buff, nes_ppu_wr, nes_ppu_rd);
        } else if(buff->part_num == USE_UNLOCK_BYPASS) {
          // enter unlock mode bypass
          nes_ppu_wr(0x0AAA, 0xAA);
          nes_ppu_wr(0x0555, 0x55);
          nes_ppu_wr(0x0AAA, 0x20);

          // write data
          result = write_page_verify_8(addrH, buff, rnbw_chrrom_flash_unlock_wr);

          // exit unlock mode bypass
          nes_ppu_wr(0x0000, 0x90);
          nes_ppu_wr(0x0000, 0x00);

          // reset the flash chip, supposed to exit too
          nes_ppu_wr(0x0000, 0xF0);
        } else {
          result = write_page_verify_8(addrH, buff, rnbw_chrrom_flash_wr);
        }
      }
      break;

    case PRGRAM:
      result = write_page_verify_8(addrH + 0x60, buff, nes_prgram_wr_verify);
      break;
#endif

#ifdef SNES_CONN
    case SNESROM:
      if(buff->mapper == LOROM) {
        // LOROM banks start at $XX:8000
        addrH = 0x80 | buff->page_num;
      } else if(buff->mapper == HIROM) {
        // HIROM banks start at $XX:0000
        addrH = 0x00 | buff->page_num;
      }

      if(buff->part_num == USE_BUFFER) {
        // result = snes_write_page_buffer(addrH, buff);
        result = buffer_write_page_verify(addrH, buff, snes_wr_romsel_0, snes_rd_romsel_0);
      } else if(buff->part_num == USE_UNLOCK_BYPASS) {
        // enter unlock bypass mode
        snes_wr(0x8AAA, 0xAA, 0);
        snes_wr(0x8555, 0x55, 0);
        snes_wr(0x8AAA, 0x20, 0);

        result = write_page_verify_8(addrH, buff, snes_flash_unlock_wr);

        // exit unlock bypass mode
        snes_wr(0x8000, 0x90, 0);
        snes_wr(0x8000, 0x00, 0);

        // reset the flash chip, supposed to exit too
        snes_wr(0x8000, 0xF0, 0);

      } else {
        result = write_page_verify_8(addrH, buff, snes_flash_wr);
      }

    case SNESRAM:
      // warn      addrX = ((buff->page_num)>>8);
      break;
#endif

#ifdef SEGA_CONN
    case GENESISROM:
      // host sets the bank A23-A17 before each bank is written
      // page of data is 256B accounts for A7-A1
      // There is no A0, upper/lower byte 'replaces' A0 since 16bit word written at once
      // we need to map page_num to A16-A8 here before writing a page

      if(buff->mapper == BASIC) {
        if(buff->part_num == USE_BUFFER) {
          result = genesis_rom_write_page_buffer_verify(buff);
        } else {
          result = genesis_rom_write_page_verify(buff);
        }
      }

      if(buff->mapper == SSF2 || buff->mapper == RNBW) {
        if(buff->part_num == USE_BUFFER) {
          result = genesis_rom_write_page_buffer_verify(buff);
        } else {
          result = genesis_rom_write_page_verify(buff);
        }
      }

      break;

    case GENESISRAM:
      genesis_ram_page_write(buff);
      break;

#endif

#ifdef GB_CONN
    case GBROM:
      if(buff->mapper == ROMONLY) {
        result = write_page_verify_8(addrH, buff, gameboy_flash_wr);
      }

      if(buff->mapper == MBC1_DISCRETE) {
        // bank 0 address cleanup will be handled in the gameboy_flash_pin31_wr function
        result = write_page_verify_8(addrH + 0x40, buff, gameboy_flash_pin31_wr);
      }

      if(buff->mapper == MBC1 || buff->mapper == MBC5) {
        if(buff->part_num == USE_BUFFER) {
          result = buffer_write_page_verify(addrH + 0x40, buff, gameboy_pin31_wr, gameboy_rd);
        } else if(buff->part_num == USE_UNLOCK_BYPASS) {
          // enter unlock bypass mode
          gameboy_pin31_wr(0x0AAA, 0xAA);
          gameboy_pin31_wr(0x0555, 0x55);
          gameboy_pin31_wr(0x0AAA, 0x20);

          // write data
          result = write_page_verify_8(addrH + 0x40, buff, gameboy_unlock_3v_flash_pin31_wr);

          // unlock bypass reset
          gameboy_pin31_wr(0x0000, 0x90);
          gameboy_pin31_wr(0x0000, 0x00);

          // reset the flash chip, supposed to exit too
          gameboy_pin31_wr(0x0000, 0xF0);
        } else {
          result = write_page_verify_8(addrH + 0x40, buff, gameboy_3v_flash_pin31_wr);
        }
      }

      break;

    case GBRAM:
      // TODO: rename nes_write_page to something generic like write_page as before
      // or create a specific gb_write_page?
      result = write_page_verify_8(addrH + 0xA0, buff, gb_ram_wr_verify);
      break;
#endif

    default:
      return ERR_BUFF_UNSUP_MEM_TYPE;
  }

  LED_IP_PU();
  return result;
}
