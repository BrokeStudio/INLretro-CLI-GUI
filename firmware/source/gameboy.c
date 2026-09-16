#include "gameboy.h"

// only need this file if connector is present on the device
#ifdef GB_CONN

//=================================================================================================
//
// GAMEBOY operations
// This file includes all the gameboy functions possible to be called from the gameboy dictionary.
//
// See description of the commands contained here in shared/shared_dictionaries.h
//
//=================================================================================================

// global variables
uint8_t cur_bank; // used by some flash algos, must be initialized prior to depending on it

/* Desc: Dispatch a Game Boy dictionary opcode received over USB
 *       shared_dict_gameboy.h defines opcodes shared by host and firmware
 * Pre:  I/O and mapper state satisfy the selected operation requirements
 *       rdata has room for the response length and one data byte
 * Post: GAMEBOY_RD sets rdata[0] to 1 and rdata[1] to the byte read
 *       GAMEBOY_SET_CUR_BANK updates cur_bank, not the hardware bank register
 *       write operations leave rdata unchanged; flash readbacks are ignored
 * Rtn:  SUCCESS for a recognized opcode, not a guarantee of flash success
 *       ERR_UNKN_GAMEBOY_OPCODE for an unsupported opcode
 */
uint8_t gameboy_call(uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t* rdata)
{
  #define RD_LEN 0
  #define RD0 1
  #define RD1 2

  #define BYTE_LEN 1
  #define HWORD_LEN 2

  switch(opcode) {
      // no return value:
    case GAMEBOY_WR:
      gameboy_wr(operand, miscdata);
      break;

    case GAMEBOY_FLASH_WR:
      gameboy_flash_wr(operand, miscdata);
      break;

    case GAMEBOY_PIN31_WR:
      gameboy_pin31_wr(operand, miscdata);
      break;

    case GAMEBOY_FLASH_PIN31_WR:
      gameboy_flash_pin31_wr(operand, miscdata);
      break;

    case GAMEBOY_UNLOCK_3V_FLASH_PIN31_WR:
      gameboy_unlock_3v_flash_pin31_wr(operand, miscdata);
      break;

    case GAMEBOY_3V_FLASH_PIN31_WR:
      gameboy_3v_flash_pin31_wr(operand, miscdata);
      break;

    case GAMEBOY_PAGE_WR_LFSR:
      gameboy_page_wr_lfsr(operand, miscdata);
      break;

    // 8bit return values:
    case GAMEBOY_RD:
      rdata[RD_LEN] = BYTE_LEN;
      rdata[RD0] = gameboy_rd(operand);
      break;

    case GAMEBOY_SET_CUR_BANK:
      cur_bank = operand;
      break;

    default:
      // macro doesn't exist
      return ERR_UNKN_GAMEBOY_OPCODE;
  }

  return SUCCESS;
}

/* Desc: Read a byte from the Game Boy cartridge
 *       assert SRAM /CS for addresses 0xA000-0xBFFF; clock pin is not toggled
 *       timing reference:
 *       https://dhole.github.io/media/gameboy_stm32f4/cpu_manual_timing_small.png
 * Pre:  gameboy_init() setup of I/O pins and desired bank selected
 *       RAM enabled by the mapper when reading cartridge RAM
 * Post: Address left on bus; data bus left in input mode
 *       /RD and SRAM /CS high
 * Rtn:  Byte read from the cartridge at addr
 */
uint8_t gameboy_rd(uint16_t addr)
{
  uint8_t rv;

  // cycle would start with clock rise

  // set address bus
  ADDR_SET(addr);

  // enable /RD pin
  GB_RD_LO();

  // set SRAM /CS
  // low for $A000-BFFF
  if((addr >= 0xA000) && (addr < 0xC000)) { // addressing cart RAM space
    GB_RAM_CS_LO();
  }

  // half cycle with clock fall
  // and /WR low for writes

  // couple more NOP's waiting for data
  // zero nop's returned previous databus value
  NOP(); // one nop got most of the bits right
  NOP(); // two nop got all the bits right
  NOP(); // add third nop for some extra
  NOP(); // one more can't hurt
  // might need to wait longer for some carts...

  // latch data
  DATA_RD(rv);

  // return bus to default
  GB_RAM_CS_HI();
  GB_RD_HI();

  // next cycle clock rise

  return rv;
}

/* Desc: Write a byte to the Game Boy cartridge using /WR
 *       assert SRAM /CS for addresses 0xA000-0xBFFF; clock pin is not toggled
 * Pre:  gameboy_init() setup of I/O pins and desired bank selected
 *       RAM enabled by the mapper when writing cartridge RAM
 * Post: Write cycle issued without readback verification; address left on bus
 *       /WR and SRAM /CS high
 *       data bus returned to input (AVR pull-ups enabled on bits written as 1)
 * Rtn:  None
 */
void gameboy_wr(uint16_t addr, uint8_t data)
{
  // cycle would start with clock rise

  // set address bus
  ADDR_SET(addr);

  // set SRAM /CS
  // low for $A000-BFFF
  if((addr >= 0xA000) && (addr < 0xC000)) { // addressing cart RAM space
    GB_RAM_CS_LO();
  }

  // put data on bus
  DATA_OP();
  DATA_SET(data);

  // half cycle with clock fall
  // and /WR low for writes
  GB_WR_LO();

  // give some time
  NOP();
  NOP();
  NOP();

  // latch data to cart memory/mapper
  GB_WR_HI();
  GB_RAM_CS_HI();

  // Free data bus
  DATA_IP();
}

/* Desc: Program one Game Boy flash byte using normal /WR
 *       send 0xAA/0x55/0xA0 at 0x5555/0x2AAA/0x5555
 *       call usbPoll while waiting for readback to match data
 * Pre:  gameboy_init() setup of I/O pins and desired bank selected
 *       board and flash support this command sequence
 * Post: Write attempted; polling stops on matching data or timeout
 *       data bus left in input mode; /RD, /WR and SRAM /CS high
 * Rtn:  Last byte read at the effective target address; compare with data for success
 */
uint8_t gameboy_flash_wr(uint16_t addr, uint8_t data)
{
  uint8_t rv;
  uint16_t timeout = 0xffff;

  gameboy_wr(0x5555, 0xAA);
  gameboy_wr(0x2AAA, 0x55);
  gameboy_wr(0x5555, 0xA0);
  gameboy_wr(addr, data);

  do {
    usbPoll(); // orignal kazzo needs this frequently to slurp up incoming data
    rv = gameboy_rd(addr);
    if(rv == data) {
      break;
    }
  } while(--timeout);

  return rv;
}

/* Desc: Write a byte using cartridge pin 31 (AUDIO IN) as flash /WE
 *       keep normal /WR high; assert SRAM /CS for addresses 0xA000-0xBFFF
 *       clock pin is not toggled
 * Pre:  gameboy_init() setup of I/O pins and desired bank selected
 *       board must route pin 31 to flash /WE and permit active high drive
 * Post: Write pulse issued without readback verification; address left on bus
 *       pin 31 driven high then returned to floating input
 *       normal /WR and SRAM /CS high
 *       data bus returned to input (AVR pull-ups enabled on bits written as 1)
 * Rtn:  None
 */
void gameboy_pin31_wr(uint16_t addr, uint8_t data)
{
  // cycle would start with clock rise

  // set address bus
  ADDR_SET(addr);

  // set SRAM /CS
  // low for $A000-BFFF
  if((addr >= 0xA000) && (addr < 0xC000)) { // addressing cart RAM space
    GB_RAM_CS_LO();
  }

  // put data on bus
  DATA_OP();
  DATA_SET(data);

  // half cycle with clock fall
  // and /WR low for writes
  // GB_WR_LO();
  GB_WR_HI();
  // use pin 31 (AUDIO in) as Flash /WR instead of normal /WR pin
  CTL_OP(AUDRbank, AUDR);
  CTL_SET_LO(AUDRbank, AUDR);

  // give some time
  NOP();
  NOP();
  NOP();

  // latch data to cart memory/mapper
  // GB_WR_HI();
  //  use pin 31 (AUDIO in) as Flash /WR instead of normal /WR pin
  CTL_SET_HI(AUDRbank, AUDR);
  CTL_IP_FL(AUDRbank, AUDR);
  GB_RAM_CS_HI();

  // Free data bus
  DATA_IP();
}

/* Desc: Program one Game Boy flash byte using pin 31 as /WE
 *       send 0xAA/0x55/0xA0 at 0x5555/0x2AAA/0x5555
 *       mask addr to 0x0000-0x3FFF when cur_bank is zero
 *       call usbPoll while waiting for readback to match data
 * Pre:  gameboy_init() setup of I/O pins and desired bank selected
 *       board routes pin 31 to flash /WE; cur_bank identifies the target bank
 *       mapper must provide the expected mapping for the unlock sequence
 * Post: Write attempted; polling stops on matching data or timeout
 *       0x2000 bank register written with 0, then cur_bank if nonzero
 *       data bus left in input mode; /RD, /WR and SRAM /CS high
 * Rtn:  Last byte read at the effective target address; compare with data for success
 */
uint8_t gameboy_flash_pin31_wr(uint16_t addr, uint8_t data)
{
  uint8_t rv;
  uint16_t timeout = 0xffff;

  // clean up address if we're flashing bank 0
  if(cur_bank == 0x00) {
    addr = addr & 0x3fff;
  }

  // program byte sequence
  gameboy_wr(0x2000, 0x00); // TODO: should be 0x01 instead since MBC1 can't map bank 0?
  gameboy_pin31_wr(0x5555, 0xAA);
  gameboy_pin31_wr(0x2AAA, 0x55);
  gameboy_pin31_wr(0x5555, 0xA0);

  // set bank if needed
  if(cur_bank != 0x00) {
    gameboy_wr(0x2000, cur_bank);
  }

  // write the actual data
  gameboy_pin31_wr(addr, data);

  do {
    usbPoll(); // orignal kazzo needs this frequently to slurp up incoming data
    rv = gameboy_rd(addr);
    if(rv == data) {
      break;
    }
  } while(--timeout);

  return rv;
}

/* Desc: Program one 3V Game Boy flash byte in unlock bypass mode via pin 31
 *       mask addr to 0x0000-0x3FFF when cur_bank is zero
 *       call usbPoll while waiting for readback to match data
 * Pre:  gameboy_init() setup of I/O pins and desired bank selected
 *       board routes pin 31 to flash /WE; flash already in unlock bypass mode
 *       cur_bank must agree with the selected hardware bank
 * Post: Write attempted; polling stops on matching data or timeout
 *       unlock bypass mode remains active; bank registers unchanged
 *       data bus left in input mode; /RD, /WR and SRAM /CS high
 * Rtn:  Last byte read at the effective target address; compare with data for success
 */
uint8_t gameboy_unlock_3v_flash_pin31_wr(uint16_t addr, uint8_t data)
{
  uint8_t rv;
  uint16_t timeout = 0xffff;

  if(cur_bank == 0x00) {
    addr = addr & 0x3fff;
  }

  gameboy_pin31_wr(addr, 0xA0); // unlock bypass command
  gameboy_pin31_wr(addr, data);

  do {
    usbPoll(); // orignal kazzo needs this frequently to slurp up incoming data
    rv = gameboy_rd(addr);
    if(rv == data) {
      break;
    }
  } while(--timeout);

  return rv;
}

/* Desc: Program one 3V Game Boy flash byte using pin 31 as /WE
 *       send 0xAA/0x55/0xA0 at 0x0AAA/0x0555/0x0AAA
 *       mask addr to 0x0000-0x3FFF when cur_bank is zero
 *       call usbPoll while waiting for readback to match data
 * Pre:  gameboy_init() setup of I/O pins and desired bank selected
 *       board routes pin 31 to flash /WE and supports this command sequence
 *       cur_bank must agree with the selected hardware bank
 * Post: Write attempted; polling stops on matching data or timeout
 *       bank registers unchanged
 *       data bus left in input mode; /RD, /WR and SRAM /CS high
 * Rtn:  Last byte read at the effective target address; compare with data for success
 */
uint8_t gameboy_3v_flash_pin31_wr(uint16_t addr, uint8_t data)
{
  uint8_t rv;
  uint16_t timeout = 0xffff;

  if(cur_bank == 0x00) {
    addr = addr & 0x3fff;
  }

  gameboy_pin31_wr(0x0AAA, 0xAA);
  gameboy_pin31_wr(0x0555, 0x55);
  gameboy_pin31_wr(0x0AAA, 0xA0);
  // if(addr >= 0x4000) gameboy_wr(0x2000, cur_bank);

  gameboy_pin31_wr(addr, data);

  do {
    usbPoll(); // orignal kazzo needs this frequently to slurp up incoming data
    rv = gameboy_rd(addr);
    if(rv == data) {
      break;
    }
  } while(--timeout);

  return rv;
}

/* Desc: Write 256 successive LFSR-generated bytes starting at addr
 *       the supplied data argument is overwritten
 *       gameboy_wr pulses /WR and asserts SRAM /CS for 0xA000-0xBFFF
 * Pre:  gameboy_init() setup of I/O pins and desired bank selected
 *       LFSR initialized; target range writable and RAM enabled when needed
 * Post: LFSR advanced 256 times; writes issued without readback verification
 *       last written address left on bus; /WR and SRAM /CS high
 *       data bus returned to input (AVR pull-ups enabled on bits written as 1)
 * Rtn:  None
 */
void gameboy_page_wr_lfsr(uint16_t addr, uint8_t data)
{
  // TODO give other data sources
  uint16_t i;

  for(i = 0; i < 256; i++) {
    data = lfsr_32();
    gameboy_wr(addr, data);
    addr++;
  }
}

/* Desc: Read len + 1 Game Boy bytes from page offset first into data[0..len]
 *       hold /RD low; toggle SRAM /CS for each RAM read for FRAM compatibility
 *       RAM range is 0xA000-0xBFFF; clock pin is not toggled
 *       poll argument is currently unused: USB polling is commented out
 * Pre:  gameboy_init() setup of I/O pins and desired bank selected
 *       RAM enabled when reading cartridge RAM; data has room for len + 1 bytes
 *       len must be below 255 or the 8-bit counter loops indefinitely
 *       first + len must be at most 255 to stay within the page
 * Post: data[0..len] filled; address low byte advanced past the last read
 *       address wraps within the page; /RD and SRAM /CS high
 *       data bus left in input mode
 * Rtn:  Number of bytes read (len + 1)
 */
uint8_t gameboy_page_rd_poll(uint8_t* data, uint8_t addrH, uint8_t first, uint8_t len, uint8_t poll)
{
  uint8_t i;

  // set address bus
  ADDRH(addrH);

  // set lower address bits
  ADDRL(first); // doing this prior to entry and right after latching

  // enable /RD pin
  GB_RD_LO();

  // extra NOP was needed on stm6 as address hadn't settled in time for the very first read
  NOP();

  // gives longest delay between address out and latching data
  for(i = 0; i <= len; i++) {
    // set SRAM /CS
    // low for $A000-BFFF
    if((addrH >= 0xA0) && (addrH < 0xC0)) {
      GB_RAM_CS_LO();
    }

    // // testing shows that having this if statement doesn't affect overall dumping speed
    // if (poll)
    // {
    //   usbPoll(); // Call usbdrv.h usb polling while waiting for data
    // }
    // else
    // {
    //   NOP(); // couple more NOP's waiting for data
    //   NOP(); // one prob good enough considering the if/else
    // }

    // gameboy needed some extra NOPS
    // NOP();
    // NOP();
    // NOP();
    // NOP();
    // NOP();
    // NOP();
    NOP(); // original
    NOP(); // original

    // latch data
    DATA_RD(data[i]);

    // set lower address bits
    // ADDRL(++first); THIS broke things, on stm adapter because macro expands it twice!
    first++;
    ADDRL(first);

    // because some carts use FRAM, we need to toggle RAM /CS between each reads
    // clear SRAM /CS
    // high for $A000-BFFF
    if((addrH >= 0xA0) && (addrH < 0xC0)) {
      GB_RAM_CS_HI();
      NOP();
      NOP();
    }
  }

  // return bus to default
  GB_RD_HI();
  GB_RAM_CS_HI();

  // return index of last byte read
  return i;
}

#endif // GB_CONN
