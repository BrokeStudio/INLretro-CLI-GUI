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
  const uint16_t last = buff->last_idx;

  if(cur > last) {
    return SUCCESS;
  }

  uint16_t addr;
  uint8_t value;
  uint8_t readback;
  uint8_t retries;

  while(cur <= last) {
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
 *       only the last byte is checked; use page_buffer_verify_8 for a full check
 *       bus state determined by wr_func and rd_func
 * Rtn:  SUCCESS if the last byte matches, or no bytes remain
 *       STOPPED if the last byte still differs when polling times out
 */
static uint8_t write_page_buffer_8(uint8_t addrH, buffer* buff, write_funcptr wr_func, read_funcptr rd_func)
{
  uint16_t cur = buff->cur_byte;
  const uint16_t last = buff->last_idx;

  if(cur > last) {
    return SUCCESS;
  }

  const uint16_t byte_count = (last + 1 - cur);
  uint16_t addr;
  uint16_t base_addr = (uint16_t)addrH << 8;
  uint8_t value;
  uint8_t readback;
  uint16_t timeout = 0xFFFF;

  uint16_t unlock_base = base_addr & 0xF000;
  uint16_t unlock_addr1 = unlock_base | 0xAAA;
  uint16_t unlock_addr2 = unlock_base | 0x555;

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
static uint8_t page_buffer_verify_8(uint8_t addrH, buffer* buff, read_funcptr rd_func)
{
  uint16_t cur = buff->cur_byte;
  const uint16_t last = buff->last_idx;

  if(cur > last) {
    return SUCCESS;
  }

  uint16_t addr;
  uint8_t value;
  uint8_t readback;

  while(cur <= last) {
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
 *       call write_page_buffer_8 and verify only if programming succeeds
 * Pre:  all requirements of write_page_buffer_8 and page_buffer_verify_8 apply
 *       desired bank remains selected throughout programming and verification
 * Post: buff->cur_byte unchanged if programming times out
 *       otherwise it identifies the first verification mismatch, or advances
 *       past last_idx on success (wraps to 0 after index 255)
 *       bus state determined by wr_func and rd_func
 * Rtn:  SUCCESS if programming and verification succeed, or no bytes remain
 *       STOPPED on a programming timeout or verification mismatch
 */
static uint8_t write_page_buffer_verify_8(uint8_t addrH, buffer* buff, write_funcptr wr_func, read_funcptr rd_func)
{
  uint8_t result;

  result = write_page_buffer_8(addrH, buff, wr_func, rd_func);

  if(result == SUCCESS) {
    result = page_buffer_verify_8(addrH, buff, rd_func);
  }

  return result;
}

#endif

#ifdef NES_CONN

/* Desc: Write one byte to NES PRG RAM and read it back
 * Pre:  cartridge I/O initialized and target PRG RAM bank selected
 * Post: data written at addr; bus state determined by nes_cpu_rd
 * Rtn:  byte read back from PRG RAM
 */
static uint8_t nes_prgram_wr_verify(uint16_t addr, uint8_t data)
{
  nes_cpu_wr(addr, data);
  return nes_cpu_rd(addr);
}

/* Desc: Program 8-bit PRG ROM data through the CNINJA mapper path,
 *       issuing an unlock and byte-program sequence per byte
 * Pre:  cartridge I/O initialized and desired bank selected
 *       unlock1 and unlock2 address the flash command locations
 *       buff->data contains the bytes to program in the page at addrH
 * Post: buff->cur_byte advances past last_idx on success
 *       each write is polled until two consecutive reads are identical
 *       bus state determined by rd_func
 * Rtn:  SUCCESS when all requested bytes have been processed, or none remain
 */
static uint8_t write_page_cninja(uint8_t bank, uint8_t addrH, uint16_t unlock1, uint16_t unlock2, buffer* buff, write_funcptr wr_func, read_funcptr rd_func)
{
  uint16_t cur = buff->cur_byte;
  const uint16_t last = buff->last_idx;

  if(cur > last) {
    return SUCCESS;
  }

  uint16_t addr;
  uint8_t value;
  uint8_t readback;

  while(cur <= last) {
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

/* Desc: Program 8-bit PRG ROM data through the MM2 mapper path,
 *       selecting the target bank for each byte write
 * Pre:  cartridge I/O initialized
 *       unlock1 and unlock2 address the flash command locations
 *       buff->data contains the bytes to program in the page at addrH
 * Post: buff->cur_byte advances past last_idx on success
 *       a mismatching byte is retried until it reads back correctly
 *       bus state determined by rd_func
 * Rtn:  SUCCESS when all requested bytes have been written, or none remain
 */
static uint8_t write_page_mm2(uint8_t bank, uint8_t addrH, uint16_t unlock1, uint16_t unlock2, buffer* buff, write_funcptr wr_func, read_funcptr rd_func)
{
  uint16_t cur = buff->cur_byte;
  const uint16_t last = buff->last_idx;

  if(cur > last) {
    return SUCCESS;
  }
  uint16_t addr;
  uint8_t value;
  uint8_t readback;

  while(cur <= last) {
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

#endif

#ifdef GB_CONN

/* Desc: Write one byte to Game Boy cartridge RAM and read it back
 * Pre:  cartridge I/O initialized and target RAM bank selected
 * Post: data written at addr; bus state determined by gb_rd
 * Rtn:  byte read back from cartridge RAM
 */
static uint8_t gb_ram_wr_verify(uint16_t addr, uint8_t data)
{
  gb_wr(addr, data);
  return gb_rd(addr);
}

#endif

#ifdef SEGA_CONN
/* Desc: Program and verify Genesis ROM data one 16-bit word at a time
 *       attempt each word up to three times before stopping on a mismatch
 * Pre:  cartridge I/O initialized and upper address bank selected
 *       cur_byte and last_idx delimit an even-sized, word-aligned range
 *       buff->data stores each word in big-endian byte order
 * Post: the original upper address bank is restored
 *       buff->cur_byte identifies the failed word on failure
 *       on success it advances past last_idx (wraps to 0 after index 255)
 * Rtn:  SUCCESS if all words are written and verified, or no words remain
 *       STOPPED if a word still differs after three write attempts
 */
static uint8_t genesis_rom_write_page_verify(buffer* buff)
{
  uint16_t cur = buff->cur_byte; // need 16 bits here so it won't overflow
  const uint16_t last = buff->last_idx;

  if(cur > last) {
    return SUCCESS;
  }

  uint8_t saved_addr_hi = gen_get_addr_hi();
  uint8_t page_addr_hi = saved_addr_hi + (buff->page_num >> 8);
  uint16_t base_addr = (buff->page_num & 0x00FF) << 8; // byte address for 256 bytes

  gen_set_addr_hi(page_addr_hi);

  uint16_t addr;
  uint16_t value;
  uint16_t readback;
  uint8_t retries;

  while(cur <= last) {
    buff->cur_byte = cur;

    value = buff->data[cur + 0] << 8;
    value |= buff->data[cur + 1];
    addr = base_addr + cur;

    retries = 3;

    do {
      // write word
      readback = gen_rom_flash_wr_short(addr, value);
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

/* Desc: Program Genesis ROM data using the flash write-buffer sequence
 *       load 16-bit words, confirm the operation and poll the final word
 * Pre:  cartridge I/O initialized and upper address bank selected
 *       flash supports the 0xAA/0x55, 0x25 and 0x29 command sequence
 *       cur_byte and last_idx delimit a non-empty, even-sized, word-aligned
 *       range that fits the flash write buffer
 *       buff->data stores each word in big-endian byte order
 * Post: the original upper address bank and buff->cur_byte are unchanged
 *       only the final word is checked; use genesis_rom_page_buffer_verify
 *       for a full check
 * Rtn:  SUCCESS if the final word matches
 *       STOPPED if it still differs when polling times out
 */
static uint8_t genesis_rom_write_page_buffer(buffer* buff)
{
  uint16_t cur = buff->cur_byte; // need 16 bits here so it won't overflow
  const uint16_t last = buff->last_idx;

  if(cur > last) {
    return SUCCESS;
  }

  const uint16_t word_count = (last + 1 - cur) >> 1;

  const uint8_t saved_addr_hi = gen_get_addr_hi();
  uint8_t page_addr_hi = saved_addr_hi + (buff->page_num >> 8);
  uint16_t base_addr = (buff->page_num & 0x00FF) << 8; // byte address for 256 bytes

  uint16_t addr_lo;
  uint16_t value;
  uint16_t readback;
  uint16_t timeout = 0xFFFF;

  gen_set_addr_hi(page_addr_hi);

  // write "write to buffer" command and sector address
  gen_rom_wr(0x0555 << 1, 0x00AA);
  gen_rom_wr(0x02AA << 1, 0x0055);
  gen_rom_wr(base_addr, 0x0025);         // the bank set before calling sets the sector
  gen_rom_wr(base_addr, word_count - 1); // number of words to write minus one

  while(cur <= last) {
    value = buff->data[cur + 0] << 8;
    value |= buff->data[cur + 1];
    addr_lo = base_addr + cur;

    // add word to write buffer
    gen_rom_wr(addr_lo, value);

    cur = cur + 2;
  }

  // write program buffer to flash
  gen_rom_wr(base_addr, 0x29);

  do {
    readback = gen_rom_rd(addr_lo);
    if(readback == value) {
      break;
    }
  } while(--timeout);

  gen_set_addr_hi(saved_addr_hi);

  if(readback != value) {
    return STOPPED;
  }

  return SUCCESS;
}

/* Desc: Read and compare 16-bit Genesis ROM words against the supplied buffer
 *       stop at the first word that differs
 * Pre:  cartridge I/O initialized and upper address bank selected
 *       cur_byte and last_idx delimit an even-sized, word-aligned range
 *       buff->data stores each expected word in big-endian byte order
 * Post: the original upper address bank is restored
 *       buff->cur_byte identifies the first mismatch on failure
 *       on success it advances past last_idx (wraps to 0 after index 255)
 * Rtn:  SUCCESS if all words match, or no words remain
 *       STOPPED on the first mismatch
 */
static uint8_t genesis_rom_page_buffer_verify(buffer* buff)
{
  uint16_t cur = buff->cur_byte; // need 16 bits here so it won't overflow
  const uint16_t last = buff->last_idx;

  if(cur > last) {
    return SUCCESS;
  }

  uint8_t saved_addr_hi = gen_get_addr_hi();
  uint8_t page_addr_hi = saved_addr_hi + (buff->page_num >> 8);
  uint16_t base_addr = (buff->page_num & 0x00FF) << 8; // byte address for 256 bytes

  gen_set_addr_hi(page_addr_hi);

  uint16_t addr_lo;
  uint16_t value;
  uint16_t readback;

  while(cur <= last) {
    value = buff->data[cur + 0] << 8;
    value |= buff->data[cur + 1];
    addr_lo = base_addr + cur;

    readback = gen_rom_rd(addr_lo);

    if(readback != value) {
      buff->cur_byte = cur;
      gen_set_addr_hi(saved_addr_hi);
      return STOPPED;
    }

    cur = cur + 2;
  }

  buff->cur_byte = cur;
  gen_set_addr_hi(saved_addr_hi);
  return SUCCESS;
}

/* Desc: Program a Genesis flash write buffer, then verify every written word
 *       verify only when the write-buffer operation succeeds
 * Pre:  all requirements of genesis_rom_write_page_buffer and
 *       genesis_rom_page_buffer_verify apply
 * Post: buff->cur_byte is unchanged if programming times out
 *       otherwise it identifies the first mismatch, or advances past
 *       last_idx on success (wraps to 0 after index 255)
 *       the original upper address bank is restored
 * Rtn:  SUCCESS if programming and verification succeed, or no words remain
 *       STOPPED on a programming timeout or verification mismatch
 */
static uint8_t genesis_rom_write_page_buffer_verify(buffer* buff)
{
  uint8_t result;

  result = genesis_rom_write_page_buffer(buff);

  if(result == SUCCESS) {
    result = genesis_rom_page_buffer_verify(buff);
  }

  return result;
}

/* Desc: Write one byte to Genesis cartridge RAM and read it back
 * Pre:  cartridge I/O initialized and upper address bank selected
 * Post: data written at addr_lo; bus state determined by gen_ram_rd
 * Rtn:  byte read back from cartridge RAM
 */
static uint8_t genesis_ram_wr_verify(uint16_t addr_lo, uint8_t data)
{
  gen_ram_wr(addr_lo, data);
  return gen_ram_rd(addr_lo);
}

/* Desc: Write and verify 8-bit Genesis cartridge RAM data
 *       attempt each byte up to three times before stopping on a mismatch
 * Pre:  cartridge I/O initialized and upper address bank selected
 *       buff->data contains the bytes to write in the selected page
 * Post: buff->cur_byte identifies the failed byte on failure
 *       on success it advances past last_idx (wraps to 0 after index 255)
 *       bytes preceding a failed byte have been written and verified
 * Rtn:  SUCCESS if all bytes are written and verified, or no bytes remain
 *       STOPPED if a byte still differs after three write attempts
 */
static uint8_t genesis_ram_page_write(buffer* buff)
{
  uint16_t cur = buff->cur_byte;
  const uint16_t last = buff->last_idx;

  if(cur > last) {
    return SUCCESS;
  }

  uint16_t addr_base = ((buff->page_num) << 8);
  uint16_t addr_lo;
  uint8_t value;
  uint8_t readback;
  uint8_t retries;

  while(cur <= last) {
    buff->cur_byte = cur;

    addr_lo = addr_base | cur;
    value = buff->data[cur];

    retries = 3;

    do {
      readback = genesis_ram_wr_verify(addr_lo, value);
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
#endif

/* Desc: Dispatch a buffered page write to the selected cartridge memory type,
 *       mapper and flash programming mode
 * Pre:  cartridge I/O initialized and required mapper bank selected
 *       buff identifies the memory type, mapper, page and programming mode
 *       buff->data contains the bytes from cur_byte through last_idx
 * Post: buff->cur_byte is updated according to the selected write routine
 *       the activity LED is returned to its input/pull-up state
 * Rtn:  SUCCESS when the selected operation completes
 *       STOPPED when programming or verification fails
 *       ERR_BUFF_PART_NUM_RANGE for an unsupported mapper/programming mode
 *       ERR_BUFF_UNSUP_MEM_TYPE for an unsupported memory type
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
      if(buff->part_num == USE_BUFFER) {
        if(buff->mapper == A53 || buff->mapper == EZNSF || buff->mapper == RNBW) {
          result = write_page_buffer_verify_8((addrH + 0x80), buff, nes_cpu_wr, nes_cpu_rd);
        } else {
          return ERR_BUFF_PART_NUM_RANGE;
        }
      } else if(buff->part_num == USE_UNLOCK_BYPASS) {
        if(buff->mapper == A53 || buff->mapper == EZNSF || buff->mapper == RNBW) {
          // enter unlock mode bypass
          nes_cpu_wr(0x8AAA, 0xAA);
          nes_cpu_wr(0x8555, 0x55);
          nes_cpu_wr(0x8AAA, 0x20);

          // write data
          result = write_page_verify_8((addrH + 0x80), buff, nes_prgrom_flash_wr_unlock);

          // exit unlock mode bypass
          nes_cpu_wr(0x8000, 0x90);
          nes_cpu_wr(0x8000, 0x00);

          // reset the flash chip, supposed to exit too
          nes_cpu_wr(0x8000, 0xF0);
        } else {
          return ERR_BUFF_PART_NUM_RANGE;
        }
      } else {
        if(buff->mapper == NROM) {
          // used by other 32KB PRG bank discrete mappers like BNROM, CNROM, & color dreams
          result = write_page_verify_8((addrH + 0x80), buff, nrom_prgrom_flash_wr);
        } else if(buff->mapper == MMC1) {
          result = write_page_verify_8((addrH + 0x80), buff, mmc1_prgrom_flash_wr);
        } else if(buff->mapper == UxROM) {
          result = write_page_verify_8((addrH + 0x80), buff, unrom_prgrom_flash_wr);
        } else if(buff->mapper == MMC3) {
          result = write_page_verify_8((addrH + 0x80), buff, mmc3_prgrom_flash_wr);
        } else if(buff->mapper == MMC4) {
          result = write_page_verify_8((addrH + 0x80), buff, mmc4_prgrom_flash_wr);
        } else if(buff->mapper == MM2) {
          // addrH &= 0b1011 1111 A14 must always be low
          addrH &= 0x3F;
          addrH |= 0x80; // A15 doesn't apply to exp0 write, but needed for read back
          // write bank value
          // page_num shift by 6 bits A14 >> A8(0)
          bank = buff->page_num >> 6;
          // bank gets written inside flash algo
          write_page_mm2(bank, addrH, 0x5555, 0x2AAA, buff, disc_push_exp0_prgrom_wr, nes_cpu_rd);
        } else if(buff->mapper == MAP30) {
          result = write_page_verify_8((addrH + 0x80), buff, map30_prgrom_flash_wr);
        } else if(buff->mapper == CNINJA) {
          // addrH &= 0b1001 1111 A14-13 must always be low
          addrH &= 0x1F;
          addrH |= 0x80;
          // write bank value
          // page_num shift by 5 bits A13 >> A8(0)
          bank = buff->page_num >> 5;
          nes_cpu_wr((0x6000), 0xA5); // select desired bank
          nes_cpu_wr((0xFFFF), bank); // select desired bank
          write_page_cninja(0, addrH, 0xD555, 0xAAAA, buff, nes_cpu_wr, nes_cpu_rd);
        } else if(buff->mapper == A53 || buff->mapper == EZNSF) {
          result = write_page_verify_8((addrH + 0x80), buff, nes_prgrom_flash_wr_long);
        } else if(buff->mapper == JALECO_SS88006) {
          result = write_page_verify_8((addrH + 0x80), buff, nes_prgrom_flash_wr_m2_high);
        } else if(buff->mapper == GTROM) {
          result = write_page_verify_8((addrH + 0x80), buff, gtrom_prgrom_flash_wr);
        } else if(buff->mapper == RNBW) {
          // TODO: we should be able to use nes_prgrom_flash_wr_long instead
          result = write_page_verify_8((addrH + 0x80), buff, nes_prgrom_flash_wr_short);
        } else if(buff->mapper == VRC6a || buff->mapper == VRC6b) {
          result = write_page_verify_8((addrH + 0x60), buff, nes_prgrom_flash_wr_long);
        } else {
          return ERR_BUFF_PART_NUM_RANGE;
        }
      }
      break;

    case CHRROM: //$0000
      if(buff->part_num == USE_BUFFER) {
        // TODO: we're using the same call for every mapper
        //       but some may need a different unlock sequence

        result = write_page_buffer_verify_8(addrH, buff, nes_ppu_wr, nes_ppu_rd);
      } else if(buff->part_num == USE_UNLOCK_BYPASS) {
        // TODO: we're using the same call for every mapper
        //       but some may need a different unlock sequence

        // enter unlock mode bypass
        nes_ppu_wr(0x0AAA, 0xAA);
        nes_ppu_wr(0x0555, 0x55);
        nes_ppu_wr(0x0AAA, 0x20);

        // write data
        result = write_page_verify_8(addrH, buff, nes_chrrom_flash_wr_unlock);

        // exit unlock mode bypass
        nes_ppu_wr(0x0000, 0x90);
        nes_ppu_wr(0x0000, 0x00);

        // reset the flash chip, supposed to exit too
        nes_ppu_wr(0x0000, 0xF0);
      } else {
        if(buff->mapper == NROM) {
          result = write_page_verify_8(addrH, buff, nrom_chrrom_flash_wr);
        } else if(buff->mapper == MMC1) {
          result = write_page_verify_8(addrH, buff, mmc1_chrrom_flash_wr);
        } else if(buff->mapper == CNROM) {
          result = write_page_verify_8(addrH, buff, cnrom_chrrom_flash_wr);
        } else if(buff->mapper == MMC3 || buff->mapper == VRC6a || buff->mapper == VRC6b) {
          result = write_page_verify_8(addrH, buff, mmc3_chrrom_flash_wr);
        } else if(buff->mapper == MMC4) {
          result = write_page_verify_8(addrH, buff, mmc4_chrrom_flash_wr);
        } else if(buff->mapper == CDREAM) {
          result = write_page_verify_8(addrH, buff, cdream_chrrom_flash_wr);
        } else if(buff->mapper == RNBW) {
          result = write_page_verify_8(addrH, buff, rnbw_chrrom_flash_wr);
        } else {
          return ERR_BUFF_PART_NUM_RANGE;
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
        result = write_page_buffer_verify_8(addrH, buff, snes_wr_romsel_0, snes_rd_romsel_0);
      } else if(buff->part_num == USE_UNLOCK_BYPASS) {
        // enter unlock bypass mode
        snes_wr(0x8AAA, 0xAA, 0);
        snes_wr(0x8555, 0x55, 0);
        snes_wr(0x8AAA, 0x20, 0);

        result = write_page_verify_8(addrH, buff, snes_flash_wr_unlock);

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

      // same code for buff->mapper BASIC, SSF2 and RNBW
      if(buff->part_num == USE_BUFFER) {
        result = genesis_rom_write_page_buffer_verify(buff);
      } else {
        result = genesis_rom_write_page_verify(buff);
      }
      break;

    case GENESISRAM:
      result = genesis_ram_page_write(buff);
      break;

#endif

#ifdef GB_CONN
    case GBROM:
      if(buff->mapper == ROMONLY) {
        result = write_page_verify_8(addrH, buff, gb_flash_wr_long);
      }

      if(buff->mapper == MBC1_DISCRETE) {
        // bank 0 address cleanup is handled in the gb_flash_wr_pin31_long function
        result = write_page_verify_8(addrH + 0x40, buff, gb_flash_wr_pin31_long);
      }

      if(buff->mapper == MBC1 || buff->mapper == MBC5) {
        if(buff->part_num == USE_BUFFER) {
          result = write_page_buffer_verify_8(addrH + 0x40, buff, gb_wr_pin31, gb_rd);
        } else if(buff->part_num == USE_UNLOCK_BYPASS) {
          // enter unlock bypass mode
          gb_wr_pin31(0x0AAA, 0xAA);
          gb_wr_pin31(0x0555, 0x55);
          gb_wr_pin31(0x0AAA, 0x20);

          // write data
          result = write_page_verify_8(addrH + 0x40, buff, gb_flash_wr_pin31_unlock);

          // unlock bypass reset
          gb_wr_pin31(0x0000, 0x90);
          gb_wr_pin31(0x0000, 0x00);

          // reset the flash chip, supposed to exit too
          gb_wr_pin31(0x0000, 0xF0);
        } else {
          result = write_page_verify_8(addrH + 0x40, buff, gb_flash_wr_pin31_short);
        }
      }

      break;

    case GBRAM:
      result = write_page_verify_8(addrH + 0xA0, buff, gb_ram_wr_verify);
      break;
#endif

    default:
      return ERR_BUFF_UNSUP_MEM_TYPE;
  }

  LED_IP_PU();
  return result;
}
