#include "flash.h"
#include "cic.h"

#ifdef NES_CONN
// TODO replace all use of this function with write_page_verify below
uint8_t nes_write_page(uint8_t addrH, buffer* buff, write_funcptr wr_func)
{
  uint16_t cur = buff->cur_byte;
  uint8_t n = buff->cur_byte;
  // uint8_t read;

  while(cur <= buff->last_idx) {
    wr_func(((addrH << 8) | n), buff->data[n]);
    // write function returns when it's complete or errors out

    n++;
    cur++;
  }
  buff->cur_byte = n;

  // TODO error check/report
  return SUCCESS;
}
/*
uint8_t  nes_write_page_mmc5( uint8_t addrH, buffer *buff, write_funcptr wr_func )
{
  uint16_t cur = buff->cur_byte;
  uint8_t  n = buff->cur_byte;
//  uint8_t read;

  //enable PRG-RAM writing and then quickly write to it and make sure don't timeout
  //disable write protection, and enable WRAM
  //for save data safety start by disabling WRAM writes
  //dict.nes("NES_CPU_WR", 0x5102, 0x02)    --bits 1&0 must be '01' (ie 0x02) to allow writes to WRAM
  //dict.nes("NES_CPU_WR", 0x5103, 0x01)    --bits 1&0 must be '10' (ie 0x01) to allow writes to WRAM
  __disable_irq();    //clear's processor PRIMASK register bit to allow interrupts to be taken
  nes_cpu_wr(0x5102, 0x02);
  nes_cpu_wr(0x5103, 0x01);
  nes_cpu_wr(0x5102, 0x02);
  nes_cpu_wr(0x5103, 0x01);
  while ( cur <= buff->last_idx ) {

    wr_func( ((addrH<<8)| n), buff->data[n] );
    //write function returns when it's complete or errors out

        n++;
        cur++;
  }
  __enable_irq();    //clear's processor PRIMASK register bit to allow interrupts to be taken
  buff->cur_byte = n;

  //TODO error check/report
  return SUCCESS;
}
*/

uint8_t nes_write_page_verify(uint8_t addrH, buffer* buff, write_rv_funcptr wr_func)
{
  uint16_t cur = buff->cur_byte;
  uint8_t n = buff->cur_byte;
  uint8_t read;

  while(cur <= buff->last_idx) {
    // write function returns read back data post flash attempt
    read = wr_func(((addrH << 8) | n), buff->data[n]);

    // TODO create flag/static variable to determine what behavior to have
    // if write fails
    if(read != buff->data[n]) {
      LED_OP();
      LED_HI();
    } else { // next byte
      LED_IP_PU();
      // LED_LO();
      // if there's a WDT the device should reset if get stuck here
      n++;
      cur++;
    }
    // put this increment only in pass case if want to retry
    // n++;
    // cur++;
  }
  buff->cur_byte = n;

  // TODO error check/report
  return SUCCESS;
}

uint8_t nes_cpu_write_page_buffer_verify(uint8_t addrH, buffer* buff)
{
  uint16_t cur = buff->cur_byte; // need 16 bits here so it won't overflow
  uint16_t base_addr = (uint16_t)addrH << 8;
  uint16_t addr;
  uint8_t value;
  uint16_t byte_count = (buff->last_idx + 1 - buff->cur_byte);

  // write "write to buffer" command and sector address
  nes_cpu_wr(0x8AAA, 0xAA);
  nes_cpu_wr(0x8555, 0x55);
  nes_cpu_wr(base_addr, 0x25);
  nes_cpu_wr(base_addr, byte_count - 1);

  while(cur <= buff->last_idx) {
    value = buff->data[cur + 0];
    addr = base_addr + cur;

    // add word to write buffer
    nes_cpu_wr(addr, value);

    cur++;
  }
  buff->cur_byte = cur;

  // write program buffer to flash (confirm)
  nes_cpu_wr(base_addr, 0x29);

  // TODO: add timeout
  do {
    value = nes_cpu_rd(addr);
  } while(value != nes_cpu_rd(addr));

  // TODO: add flash control

  // TODO error check/report
  return SUCCESS;
}

uint8_t nes_ppu_write_page_buffer_verify(uint8_t addrH, buffer* buff)
{
  uint16_t cur = buff->cur_byte; // need 16 bits here so it won't overflow
  uint16_t base_addr = (uint16_t)addrH << 8;
  uint16_t addr;
  uint8_t value;
  uint16_t byte_count = (buff->last_idx + 1 - buff->cur_byte);

  // write "write to buffer" command and sector address
  nes_ppu_wr(0x0AAA, 0xAA);
  nes_ppu_wr(0x0555, 0x55);
  nes_ppu_wr(base_addr, 0x25);
  nes_ppu_wr(base_addr, byte_count - 1);

  while(cur <= buff->last_idx) {
    value = buff->data[cur + 0];
    addr = base_addr + cur;

    // add word to write buffer
    nes_ppu_wr(addr, value);

    cur++;
  }
  buff->cur_byte = cur;

  // write program buffer to flash (confirm)
  nes_ppu_wr(base_addr, 0x29);

  // TODO: add timeout
  do {
    value = nes_ppu_rd(addr);
  } while(value != nes_ppu_rd(addr));

  // TODO: add flash control

  // TODO error check/report
  return SUCCESS;
}

#endif

#ifdef SNES_CONN
uint8_t snes_write_page_buffer(uint8_t addrH, buffer* buff, write_funcptr_pg wr_func)
{
  uint16_t cur = buff->cur_byte;
  uint8_t n = buff->cur_byte;
  uint8_t i;
  uint8_t rv;
  uint8_t rv1;
  // uint8_t read;
  //

  uint16_t addr = addrH << 8;

  while(cur <= buff->last_idx) {
    // wr_func( ((addrH<<8)| n), &(buff->data[n]) );
    //write function returns when it's complete or errors out

    // unlock and write data
    snes_wr(0x8AAA, 0xAA, 0);
    snes_wr(0x8555, 0x55, 0);
    // write buffer write to SA
    snes_wr(addr | n, 0x25, 0);
    // write number of words - 1 to SA
    snes_wr(addr | n, 31, 0);

    // write first data to first address, then write others to their address
    // snes_wr(addr|n, data, 0);

    // write 31 more bytes of data
    for(i = 0; i < 32; i++) {
      snes_wr(addr + i + n, buff->data[n + i], 0);
    }

    // write program buffer command
    snes_wr(addr | n, 0x29, 0);

    // LED_IP_PU();
    // LED_LO();
    // LED_OP();
    // LED_HI();

    do {
      rv = snes_rd(addr, 0);
      rv1 = snes_rd(addr, 0);
      usbPoll(); // orignal kazzo needs this frequently to slurp up incoming data
                 // wdt_reset();
                 ////} while (rv != snes_rd(addr, 0));
    } while(rv != rv1);

    // n++;
    n += 32;
    cur += 32;
  }
  buff->cur_byte = n;

  // TODO error check/report
  return SUCCESS;
}
#endif

// only used by cninja currently..
uint8_t write_page_cninja(uint8_t bank, uint8_t addrH, uint16_t unlock1, uint16_t unlock2, buffer* buff, write_funcptr wr_func, read_funcptr rd_func)
{
  uint16_t cur = buff->cur_byte;
  uint8_t n = buff->cur_byte;
  uint8_t read;
  while(cur <= buff->last_idx) {
    // write unlock sequence
    wr_func(unlock1, 0xAA);
    wr_func(unlock2, 0x55);
    wr_func(unlock1, 0xA0);
    wr_func(((addrH << 8) | n), buff->data[n]);
    do {
      usbPoll();
      read = rd_func((addrH << 8) | n);
    } while(read != rd_func((addrH << 8) | n));
  }
  buff->cur_byte = n;
  return SUCCESS;
}

// only used by MM2 currently
uint8_t write_page_mm2(uint8_t bank, uint8_t addrH, uint16_t unlock1, uint16_t unlock2, buffer* buff, write_funcptr wr_func, read_funcptr rd_func)
{
  uint16_t cur = buff->cur_byte;
  uint8_t n = buff->cur_byte;
  uint8_t read;
  while(cur <= buff->last_idx) {
    nes_cpu_wr((0xFD69), 0x00);
    wr_func(unlock1, 0xAA);
    wr_func(unlock2, 0x55);
    wr_func(unlock1, 0xA0);
    nes_cpu_wr((0xFD69 + bank), bank);
    wr_func(((addrH << 8) | n), buff->data[n]);
    do {
      usbPoll();
      read = rd_func((addrH << 8) | n);
    } while(read != rd_func((addrH << 8) | n));
    if(read == buff->data[n]) {
      n++;
      cur++;
      LED_IP_PU();
      LED_LO();
    } else {
      LED_OP();
      LED_HI();
    }
  }
  buff->cur_byte = n;
  return SUCCESS;
}

uint8_t write_page_a53(uint8_t bank, uint8_t addrH, buffer* buff, write_funcptr wr_func, read_funcptr rd_func)
{
  uint16_t cur = buff->cur_byte;
  uint8_t n = buff->cur_byte;
  uint8_t read;
  // enter unlock bypass mode
  wr_func(0x8AAA, 0xAA);
  wr_func(0x8555, 0x55);
  wr_func(0x8AAA, 0x20);
  while(cur <= buff->last_idx) {
    // TODO FIX THIS!  It shouldn't be needed!
    // but for some reason the mapper is loosing it's setting for $5000 register to
    // permit flash writes.  Many writes go through, but at somepoint it gets lost..
    // maybe the best fix it to require address to be equal to $5555 to write to flash enable register..
    // but for now, this rewrite hack solves the issue.
    nes_cpu_wr(0x5000, 0x54); // chr reg select act like CNROM & enable flash writes
    // AVR didn't need this patch so maybe is a speed issue
    // stmadapter didn't have problems either..
    // added time delay before m2 rising edge and it didn't change anything for stm6
    //  curaddresswrite( 0xA0 );  //gained ~3KBps (59.13KBps) inl6 with v3.0 proto
    wr_func(((addrH << 8) | n), 0xA0);
    wr_func(((addrH << 8) | n), buff->data[n]);
    do {
      usbPoll();
      read = rd_func((addrH << 8) | n);
    } while(read != rd_func((addrH << 8) | n));
    // retry if write failed
    // this helped but still seeing similar fails to dumps
    if(read == buff->data[n]) {
      n++;
      cur++;
      LED_IP_PU();
      LED_LO();
    } else {
      // kaz6 final needs a retry, but proto doesn't...
      nes_cpu_wr(0x5000, 0x81); // outer reg select mode
      nes_cpu_wr(0x8000, bank); // outer bank
      nes_cpu_wr(0x5000, 0x54); // chr reg select act like CNROM & enable flash writes
      LED_OP();
      LED_HI();
    }
  }
  buff->cur_byte = n;
  // exit unlock bypass mode
  wr_func(0x8000, 0x90);
  wr_func(0x8000, 0x00);
  // reset the flash chip, supposed to exit too
  wr_func(0x8000, 0xF0);
  return SUCCESS;
}

// uint8_t write_page_tssop(uint8_t bank, uint8_t addrH, buffer* buff, write_funcptr wr_func, read_funcptr rd_func)
// {
//   uint16_t cur = buff->cur_byte;
//   uint8_t n = buff->cur_byte;
//   uint8_t read;
//   // enter unlock bypass mode
//   wr_func(0x8AAA, 0xAA);
//   wr_func(0x8555, 0x55);
//   wr_func(0x8AAA, 0x20);
//   while(cur <= buff->last_idx) {
//     // curaddresswrite( 0xA0 );  //gained ~3KBps (59.13KBps) inl6 with v3.0 proto
//     wr_func(((addrH << 8) | n), 0xA0);
//     wr_func(((addrH << 8) | n), buff->data[n]);
//     do {
//       usbPoll();
//       read = rd_func((addrH << 8) | n);
//     } while(read != rd_func((addrH << 8) | n));
//     // retry if write failed
//     // this helped but still seeing similar fails to dumps
//     if(read == buff->data[n]) {
//       n++;
//       cur++;
//       LED_IP_PU();
//       LED_LO();
//     } else {
//       // kaz6 final needs a retry, but proto doesn't...
//       //  nes_cpu_wr(0x5000, 0x81); //outer reg select mode
//       //  nes_cpu_wr(0x8000, bank);    //outer bank
//       //  nes_cpu_wr(0x5000, 0x54); //chr reg select act like CNROM & enable flash writes
//       LED_OP();
//       LED_HI();
//     }
//   }
//   buff->cur_byte = n;
//   // exit unlock bypass mode
//   wr_func(0x8000, 0x90);
//   wr_func(0x8000, 0x00);
//   // reset the flash chip, supposed to exit too
//   wr_func(0x8000, 0xF0);
//   return SUCCESS;
// }

// uint8_t nes_write_page_dualport(uint8_t bank, uint8_t addrH, buffer* buff, write_funcptr wr_func, read_funcptr rd_func)
// {
//   uint16_t cur = buff->cur_byte;
//   uint8_t n = buff->cur_byte;
//   uint8_t read;
//   // enter unlock bypass mode
//   wr_func(0x0AAA, 0xAA);
//   wr_func(0x0555, 0x55);
//   wr_func(0x0AAA, 0x20);
//   while(cur <= buff->last_idx) {
//     wr_func(((addrH << 8) | n), 0xA0);
//     wr_func(((addrH << 8) | n), buff->data[n]);
//     do {
//       usbPoll();
//       read = rd_func((addrH << 8) | n);
//     } while(read != rd_func((addrH << 8) | n));
//     // TODO verify byte is value that was trying to be flashed
//     // move on to next byte
//     // n++;
//     // cur++;
//     if(read == buff->data[n]) {
//       n++;
//       cur++;
//       LED_IP_PU();
//       LED_LO();
//     } else {
//       LED_OP();
//       LED_HI();
//     }
//   }
//   buff->cur_byte = n;
//   // exit unlock bypass mode
//   wr_func(0x0000, 0x90);
//   wr_func(0x0000, 0x00);
//   // reset the flash chip, supposed to exit too
//   wr_func(0x0000, 0xF0);
//   return SUCCESS;
// }

// #define PRGM_MODE() swim_wotf(SWIM_HS, 0x500F, 0x40)
// #define PLAY_MODE() swim_wotf(SWIM_HS, 0x500F, 0x00)
// #define PRGM_MODE() EXP0_LO()
// #define PLAY_MODE() EXP0_HI()
#define PRGM_MODE() NOP()
#define PLAY_MODE() NOP()

#ifdef SNES_CONN
uint8_t snes_write_page(uint8_t bank, uint8_t addrH, buffer* buff, write_snes_funcptr wr_func, read_snes_funcptr rd_func)
{
  uint16_t cur = buff->cur_byte;
  uint8_t n = buff->cur_byte;
  uint8_t read;
  #ifdef AVR_CORE
  wdt_reset();
  #endif
  // set to program mode for first entry
  // EXP0_LO();
  // swim_wotf(SWIM_HS, 0x500F, 0x40)
  PRGM_MODE();

  //; TODO I don't think all these NOPs are actually needed, but they work and don't seem to significantly affect program time on stm32
  NOP();
  NOP();
  NOP();
  NOP();
  NOP();
  NOP();
  NOP();
  NOP();
  // enter unlock bypass mode
  wr_func(0x8AAA, 0xAA, 0);
  wr_func(0x8555, 0x55, 0);
  wr_func(0x8AAA, 0x20, 0);
  while(cur <= buff->last_idx) {
    // write unlock sequence
    // unlocked  wr_func( 0x0AAA, 0xAA );
    // unlocked  wr_func( 0x0555, 0x55 );
    // wr_func( 0x0000, 0xA0 );
    snes_wr_cur_addr(0xA0, 0); // gained ~3KBps (59.13KBps) inl6 with v3.0 proto
    wr_func(((addrH << 8) | n), buff->data[n], 0);
    // wr_func( ((addrH<<8)| n), cur_data );  //didn't actually speed up
    // Targetting 2MByte 16mbit flash which doesn't have buffered writes
    // currently have average flash speed of 21.05KBps going to start removing some of these NOPs
    // and optimizing flash routine to get time down.
    // exit program mode
    //  EXP0_HI();
    PLAY_MODE();
    NOP();
    NOP();
    NOP();
    NOP();
    NOP();
    NOP();
    NOP();
    NOP();
    // pre-fetch next byte of data
    // cur_data = buff->data[n+1];
  #ifdef AVR_CORE
    wdt_reset();
  #endif
    // wait for byte to flash
    //  do {
    //    usbPoll();
    //    read = rd_func((addrH<<8)|n);
    //
    //  //} while( read != rd_func((addrH<<8)|n) );
    //  } while( read != buff->data[n] );
    // this can cause things to hang on failed programs..
    // need a smarter flash polling algo, kind of a pain because we don't have
    // a good way to toggle /OE or /CE quickly on v3 SNES boards
    usbPoll();
    read = rd_func((addrH << 8) | n, 0);
    // prepare for upcoming write cycle, or allow for a polling read
    // EXP0_LO();
    PRGM_MODE();
    NOP();
    NOP();
    NOP();
    NOP();
    NOP();
    NOP();
    NOP();
    NOP();
    // First check if already outputting final data
    if(read != buff->data[n]) {
      // if not, lets see if toggle is occuring
      // EXP0_HI();
      PLAY_MODE();
      NOP();
      NOP();
      NOP();
      NOP();
      NOP();
      NOP();
      NOP();
      NOP();
      while(read != rd_func((addrH << 8) | n, 0)) {
        // EXP0_LO();
        PRGM_MODE();
        NOP();
        NOP();
        NOP();
        NOP();
        NOP();
        NOP();
        NOP();
        NOP();
        NOP();
        NOP();
        NOP();
        NOP();
        NOP();
        NOP();
        NOP();
        NOP();
        NOP();
        NOP();
        NOP();
        NOP();
        // EXP0_HI();
        PLAY_MODE();
        NOP();
        NOP();
        NOP();
        NOP();
        NOP();
        NOP();
        NOP();
        NOP();
        read = rd_func((addrH << 8) | n, 0);
      }
      // prepare for upcoming write cycle
      // EXP0_LO();
      PRGM_MODE();
      NOP();
      NOP();
      NOP();
      NOP();
      NOP();
      NOP();
      NOP();
      NOP();
    }
    // //IDK why, but AVR will exit early sometimes
    // //without this second check, ~20 errors per 32KByte on SNES v3.0
    // //All error bytes are 0xFF instead of true data
    // //may need a smarter flash polling routine..
    // //Tried to add extra delay to read algo, and didn't change anything
    // //Also have decent trust in read routine as it's comparable to page read
    // //which works flawlessly for dumps.  So think it has to do with flashing specifically...
    // //Hmm maybe the avr is missing a read..  flash /CE, /OE, and /WE never toggle
    // //so why would flash polling output different data between polls..?
    // //Ahh this is the issue, adding the code below only adds delay which gives flash
    // //enough time to complete write.

    // retry if write failed
    // this helped but still seeing similar fails to dumps
    n++;
    cur++;
    // if (read == buff->data[n]) {
    //   //n++;
    //   //cur++;
    //   LED_IP_PU();
    //   LED_LO();
    // } else {
    //   LED_OP();
    //   LED_HI();
    // }
  }

  buff->cur_byte = n;

  // exit unlock bypass mode
  wr_func(0x8000, 0x90, 0);
  wr_func(0x8000, 0x00, 0);
  // reset the flash chip, supposed to exit too
  wr_func(0x8000, 0xF0, 0);

  // exit program mode
  // EXP0_HI();
  PLAY_MODE();
  return SUCCESS;
}
#endif

#ifdef GB_CONN

uint8_t gb_write_page_flash(uint8_t addrH, buffer* buff, write_rv_funcptr wr_func)
{
  uint16_t cur = buff->cur_byte;
  uint8_t n = buff->cur_byte;
  uint8_t read;

  while(cur <= buff->last_idx) {
    // write function returns read back data post flash attempt
    read = wr_func(((addrH << 8) | n), buff->data[n]);

    // TODO create flag/static variable to determine what behavior to have
    // if write fails
    if(read != buff->data[n]) {
      LED_OP();
      LED_HI();
    } else { // next byte
      LED_IP_PU();
      // LED_LO();
      // if there's a WDT the device should reset if get stuck here
      n++;
      cur++;
    }
    // put this increment only in pass case if want to retry
    // n++;
    // cur++;
  }
  buff->cur_byte = n;

  // TODO error check/report
  return SUCCESS;
}

uint8_t gb_write_page_buffer(uint8_t addrH, buffer* buff)
{
  uint16_t cur = buff->cur_byte; // need 16 bits here so it won't overflow
  uint16_t base_addr = (uint16_t)addrH << 8;
  uint16_t addr;
  uint8_t value;
  uint16_t byte_count = (buff->last_idx + 1 - buff->cur_byte);

  // write "write to buffer" command and sector address
  gameboy_pin31_wr(0x0AAA, 0xAA);
  gameboy_pin31_wr(0x0555, 0x55);
  gameboy_pin31_wr(base_addr, 0x25);           // the bank set before calling sets the sector
  gameboy_pin31_wr(base_addr, byte_count - 1); // number of words to write minus one

  while(cur <= buff->last_idx) {
    value = buff->data[cur + 0];
    addr = base_addr + cur;

    // add word to write buffer
    gameboy_pin31_wr(addr, value);

    cur++;
  }
  buff->cur_byte = cur;

  // write program buffer to flash (confirm)
  gameboy_pin31_wr(base_addr, 0x29);

  // TODO: add timeout
  do {
    value = gameboy_rd(addr);
  } while(value != gameboy_rd(addr));

  // TODO: add flash control

  // TODO error check/report
  return SUCCESS;
}

#endif

#ifdef SEGA_CONN
uint8_t genesis_ssf2_write_page_verify(buffer* buff)
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

uint8_t genesis_rom_page_write_verify(buffer* buff)
{
  uint16_t cur = buff->cur_byte; // need 16 bits here so it won't overflow

  uint8_t saved_addr_hi = gen_get_addr_hi();
  uint8_t page_addr_hi = saved_addr_hi + (buff->page_num >> 8);
  uint16_t base_addr = (buff->page_num & 0x00FF) << 8; // byte address for 256 bytes

  gen_set_addr_hi(page_addr_hi);

  uint16_t addr;
  uint16_t value;
  uint16_t read;
  uint8_t retries;

  while(cur <= buff->last_idx) {
    buff->cur_byte = cur;

    value = buff->data[cur + 0] << 8;
    value |= buff->data[cur + 1];
    addr = base_addr + cur;

    retries = 3;

    do {
      // write word
      read = gen_sst_flash_wr(addr, value);
      if(read == value) {
        LED_IP_PU();
        cur += 2;
        break;
      } else {
        LED_OP();
        LED_HI();
      }
    } while(--retries);

    if(read != value) {
      gen_set_addr_hi(saved_addr_hi);
      buff->cur_byte = cur;
      return STOPPED;
    }
  }
  gen_set_addr_hi(saved_addr_hi);
  buff->cur_byte = cur;
  return SUCCESS;
}

uint8_t genesis_ram_page_write(buffer* buff)
{
  uint16_t cur = buff->cur_byte;
  uint16_t temp;
  uint16_t addr;

  addr = ((buff->page_num) << 8);

  while(cur <= buff->last_idx) {
    temp = buff->data[cur];
    gen_ram_wr((addr | cur), temp);
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

      // Latest method used here!
      // leave the host responsible for init & banking
      // we just need to call a page write algo and give it mmc3_prgrom_flash_wr function
      // think of this only as an 8KB ROM
      // ie MMC3 flash writes are always $8000-9FFF, but the host arranges this

      if(buff->mapper == NROM) {
        // used by other 32KB PRG bank discrete mappers like BNROM, CNROM, & color dreams
        nes_write_page_verify((0x80 + addrH), buff, nrom_prgrom_flash_wr);
      }
      if(buff->mapper == MMC1) {
        nes_write_page((0x80 + addrH), buff, mmc1_prgrom_flash_wr);
      }
      if(buff->mapper == UxROM) {
        nes_write_page((0x80 + addrH), buff, unrom_prgrom_flash_wr);
      }
      if(buff->mapper == MMC3) {
        nes_write_page_verify((0x80 + addrH), buff, mmc3_prgrom_flash_wr);
      }
      if(buff->mapper == MMC3S) {
        nes_write_page_verify((0x80 + addrH), buff, mmc3s_prgrom_flash_wr);
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
        nes_write_page_verify((0x80 + addrH), buff, mmc4_prgrom_flash_wr);
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
        nes_write_page_verify((0x80 + addrH), buff, map30_prgrom_flash_wr);
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
        nes_write_page_verify((0x80 + addrH), buff, a53_prgrom_flash_wr);

        // // enter unlock bypass mode
        // nes_m2_high_wr(0x8AAA, 0xAA);
        // nes_m2_high_wr(0x8555, 0x55);
        // nes_m2_high_wr(0x8AAA, 0x20);

        // nes_write_page((0x80 + addrH), buff, a53_tssop_prgrom_flash_wr);

        // // exit unlock bypass mode
        // nes_m2_high_wr(0x8000, 0x90);
        // nes_m2_high_wr(0x8000, 0x00);

        // // reset the flash chip, supposed to exit too
        // nes_m2_high_wr(0x8000, 0xF0);

        //////////////
        // OLD WAY, still used by PLCC flash
        // need to uncomment and reflash firmware to get it to work
        // Long term solution is to have a mapper variant for each
        // or PRG-ROM part number type variable..?
        //////////////
        /*

      //write bank value to bank table
      //page_num shift by 7 bits A15 >> A8(0)
      bank = (buff->page_num)>>7;
      //Setup as CNROM, then scroll through outer banks.
      //cpu_wr(0x5000, 0x80); //reg select mode
      //   xxSSPPMM   SS-size: 0-32KB, PP-prg mode: 0,1 32KB, MM-mirror
      //cpu_wr(0x8000, 0b00000000);   //reg value 256KB inner, 32KB banks
      nes_cpu_wr(0x5000, 0x81); //outer reg select mode
      nes_cpu_wr(0x8000, bank);    //outer bank
      nes_cpu_wr(0x5000, 0x54); //chr reg select act like CNROM & enable flash writes

      //need to use standard CPU writes
      //write_page_old( 0, (0x80 | addrH), buff, nes_cpu_wr, nes_cpu_rd );
      //break;
      //WORKS PLCC Action53:
      //had problems later not all bytes getting programmed..
      write_page_old( bank, (0x80 | addrH), 0xD555, 0xAAAA, buff, nes_cpu_wr, nes_cpu_rd );
      //TSSOP-28 action53:
      //write_page_a53( bank, (0x80 | addrH), buff, nes_m2_high_wr, nes_cpu_rd );
      //nes_write_page_verify( (0x80+addrH), buff, mmc3_prgrom_flash_wr);
      */
      }
      if(buff->mapper == A53_512K) {
        // nes_write_page_verify( (0x80+addrH), buff, a53_512k_prgrom_flash_wr);
        nes_write_page((0x80 + addrH), buff, a53_512k_prgrom_flash_wr);
      }
      if(buff->mapper == EZNSF) {
        /*
      //addrH &= 0b1000 1111 A14-12 must always be low
      addrH &= 0x8F;
      //write bank value to bank table
      //page_num shift by 4 bits A12 >> A8(0)
      bank = (buff->page_num)>>4;
      nes_cpu_wr(0x5000, bank);    //bank @ $8000-8FFF

      write_page_tssop( bank, (0x80 | addrH), buff, nes_cpu_wr, nes_cpu_rd );
      */
        // enter unlock bypass mode
        nes_m2_high_wr(0x9AAA, 0xAA);
        nes_m2_high_wr(0x9555, 0x55);
        nes_m2_high_wr(0x9AAA, 0x20);

        nes_write_page_verify((0x90 + addrH), buff, tssop_prgrom_flash_wr);

        // exit unlock bypass mode
        nes_m2_high_wr(0x9000, 0x90);
        nes_m2_high_wr(0x9000, 0x00);
        // reset the flash chip, supposed to exit too
        nes_m2_high_wr(0x9000, 0xF0);
      }
      if(buff->mapper == GTROM) {
        nes_write_page_verify((0x80 + addrH), buff, gtrom_prgrom_flash_wr);
      }
      if(buff->mapper == RNBW) {
        if(buff->part_num == USE_BUFFER) {
          nes_cpu_write_page_buffer_verify((0x80 + addrH), buff);
        } else if(buff->part_num == USE_UNLOCK_BYPASS) {
          // enter unlock mode bypass
          nes_cpu_wr(0x8AAA, 0xAA);
          nes_cpu_wr(0x8555, 0x55);
          nes_cpu_wr(0x8AAA, 0x20);

          // write data
          nes_write_page_verify((0x80 + addrH), buff, rnbw_prgrom_flash_unlock_wr);

          // exit unlock mode bypass
          nes_cpu_wr(0x8000, 0x90);
          nes_cpu_wr(0x8000, 0x00);

          // reset the flash chip, supposed to exit too
          nes_cpu_wr(0x8000, 0xF0);
        } else {
          nes_write_page_verify((0x80 + addrH), buff, rnbw_prgrom_flash_wr);
        }
      }
      if(buff->mapper == VRC6a || buff->mapper == VRC6b) {
        // nes_write_page_verify((0x60 + addrH), buff, vrc6_prgrom_flash_wr);
        nes_write_page((0x60 + addrH), buff, vrc6_prgrom_flash_wr);
      }
      break;

    case CHRROM: //$0000
      if(buff->mapper == NROM) {
        nes_write_page(addrH, buff, nrom_chrrom_flash_wr);
      }
      if(buff->mapper == MMC1) {
        nes_write_page(addrH, buff, mmc1_chrrom_flash_wr);
      }
      if(buff->mapper == CNROM) {
        nes_write_page(addrH, buff, cnrom_chrrom_flash_wr);
      }
      if(buff->mapper == MMC3) {
        nes_write_page(addrH, buff, mmc3_chrrom_flash_wr);
      }
      if(buff->mapper == MMC4) {
        nes_write_page(addrH, buff, mmc4_chrrom_flash_wr);
      }
      if(buff->mapper == CDREAM) {
        nes_write_page(addrH, buff, cdream_chrrom_flash_wr);
      }
      // if(buff->mapper == DPROM) {
      //   // select bank
      //   // 8KB banks $0000-1FFF
      //   // page_num shift by 5 bits A13 >> A8(0)
      //   bank = (buff->page_num) >> 5;
      //   // write bank to register
      //   nes_ppu_wr(0x3FFF, bank);
      //   addrH &= 0x1F; // only A12-8 are directly addressable
      //   nes_write_page_dualport(0, addrH, buff, nes_dualport_wr, nes_dualport_rd);
      // }
      if(buff->mapper == VRC6a || buff->mapper == VRC6b) {
        // nes_write_page(addrH, buff, vrc6_chrrom_flash_wr);
        nes_write_page(addrH, buff, mmc3_chrrom_flash_wr);
      }
      if(buff->mapper == RNBW) {
        if(buff->part_num == USE_BUFFER) {
          nes_ppu_write_page_buffer_verify(addrH, buff);
        } else if(buff->part_num == USE_UNLOCK_BYPASS) {
          // enter unlock mode bypass
          nes_ppu_wr(0x0AAA, 0xAA);
          nes_ppu_wr(0x0555, 0x55);
          nes_ppu_wr(0x0AAA, 0x20);

          // write data
          nes_write_page_verify(addrH, buff, rnbw_chrrom_flash_unlock_wr);

          // exit unlock mode bypass
          nes_ppu_wr(0x0000, 0x90);
          nes_ppu_wr(0x0000, 0x00);

          // reset the flash chip, supposed to exit too
          nes_ppu_wr(0x0000, 0xF0);
        } else {
          nes_write_page_verify(addrH, buff, rnbw_chrrom_flash_wr);
        }
      }
      break;

    case PRGRAM:
      // if (buff->mapper == MMC5) {
      //  nes_write_page_mmc5( addrH+0x60, buff, nes_cpu_wr);
      // } else {
      nes_write_page(addrH + 0x60, buff, nes_cpu_wr);
      //}
      break;
#endif

#ifdef SNES_CONN
    case SNESROM:
      // if(buff->mapper == LOROM_5VOLT) {
      //   // LOROM banks start at $XX:8000
      //   write_page(addrH + 0x80, buff, snes_5v_flash_wr);
      // }
      // if(buff->mapper == HIROM_5VOLT) {
      //   // HIROM banks start at $XX:0000
      //   write_page(addrH, buff, snes_5v_flash_wr);
      // }
      // if(buff->mapper == LOROM_3VOLT) {
      //   // LOROM banks start at $XX:8000
      //   write_page(addrH + 0x80, buff, snes_3v_flash_wr);
      // }
      // if(buff->mapper == HIROM_3VOLT) {
      //   // HIROM banks start at $XX:0000
      //   write_page(addrH, buff, snes_3v_flash_wr);
      // }
      // if(buff->mapper == LOROM_3V_VERIFY) {
      //   // LOROM banks start at $XX:8000
      //   write_page_verify(addrH + 0x80, buff, snes_3v_verify_wr);
      // }
      // if(buff->mapper == HIROM_3V_VERIFY) {
      //   // HIROM banks start at $XX:0000
      //   write_page_verify(addrH, buff, snes_3v_verify_wr);
      // }
      // if(buff->mapper == LOROM_3V_PAGE) {
      //   // LOROM banks start at $XX:8000
      //   snes_write_page_buffer(addrH + 0x80, buff, snes_3v_buffer_wr);
      // }
      // if(buff->mapper == HIROM_3V_PAGE) {
      //   // HIROM banks start at $XX:0000
      //   snes_write_page_buffer(addrH, buff, snes_3v_buffer_wr);
      // }

      if(buff->mapper == LOROM) {
        addrH |= 0x80; //$8000 LOROM space
        // need to split page_num
        // A14-8 page_num[7-0]
        // A15 high (LOROM)
        // A23-16 page_num[14-8]
        bank = (buff->page_num) >> 7;
        // clear any reset state
        // EXP0_HI();
        HADDR_SET(bank);
        snes_write_page(0, addrH, buff, snes_wr, snes_rd);
      }
      if(buff->mapper == HIROM) {
        // need to split page_num
        // A15-8 page_num[7-0]
        // A21-16 page_num[13-8]
        // A22 high (HIROM)
        // A23 ~page_num[14] (bank CO starts first half, bank 40 starts second)
        bank = ((((buff->page_num) >> 8) | 0x40) & 0x7F);
        HADDR_SET(bank);
        snes_write_page(0, addrH, buff, snes_wr, snes_rd);
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
        result = genesis_rom_page_write_verify(buff);
      }

      if(buff->mapper == SSF2) {
        result = genesis_ssf2_write_page_verify(buff);
      }

      if(buff->mapper == RNBW) {
        result = genesis_ssf2_write_page_verify(buff);
      }

      break;

    case GENESISRAM:
      genesis_ram_page_write(buff);
      break;

#endif

#ifdef GB_CONN
    case GBROM:
      if(buff->mapper == ROMONLY) {
        // write_page(addrH, buff, gameboy_flash_wr);
        gb_write_page_flash(addrH, buff, gameboy_flash_wr);
      }

      if(buff->mapper == MBC1_DISCRETE) {
        // bank 0 address cleanup will be handled in the gameboy_flash_pin31_wr function
        gb_write_page_flash(addrH + 0x40, buff, gameboy_flash_pin31_wr);
      }

      if(buff->mapper == MBC1 || buff->mapper == MBC5) {
        if(buff->part_num == USE_BUFFER) {
          result = gb_write_page_buffer(addrH + 0x40, buff);
        } else if(buff->part_num == USE_UNLOCK_BYPASS) {
          // enter unlock bypass mode
          gameboy_pin31_wr(0x0AAA, 0xAA);
          gameboy_pin31_wr(0x0555, 0x55);
          gameboy_pin31_wr(0x0AAA, 0x20);

          // write data
          gb_write_page_flash(addrH + 0x40, buff, gameboy_unlock_3v_flash_pin31_wr);

          // unlock bypass reset
          gameboy_pin31_wr(0x0000, 0x90);
          gameboy_pin31_wr(0x0000, 0x00);

          // reset/exit
          gameboy_pin31_wr(0x0000, 0xF0);
        } else {
          gb_write_page_flash(addrH + 0x40, buff, gameboy_3v_flash_pin31_wr);
        }
      }

      break;

    case GBRAM:
      // TODO: rename nes_write_page to something generic like write_page as before
      // or create a specific gb_write_page?
      nes_write_page(addrH + 0xA0, buff, gameboy_wr);
      break;
#endif

    default:
      return ERR_BUFF_UNSUP_MEM_TYPE;
  }

  LED_IP_PU();
  return result;
}
