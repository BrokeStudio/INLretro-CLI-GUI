#include "snes.h"

//only need this file if connector is present on the device
#ifdef SNES_CONN

//=================================================================================================
//
//  SNES operations
//  This file includes all the snes functions possible to be called from the snes dictionary.
//
//  See description of the commands contained here in shared/shared_dictionaries.h
//
//=================================================================================================

/* Desc: Dispatch a SNES dictionary opcode received over USB
 *       miscdata is interpreted as a data byte or /ROMSEL state according to opcode
 * Pre:  SNES I/O initialized and the selected bank and bus state are valid
 *       rdata has room for two bytes when opcode is SNES_RD
 * Post: SNES_SET_BANK updates the high address; SNES_RD stores BYTE_LEN in rdata[0]
 *       and the byte read in rdata[1]; write operations leave rdata unchanged
 * Ret:  SUCCESS for a recognized opcode; ERR_UNKN_SNES_OPCODE otherwise
 *       SUCCESS does not guarantee that flash programming completed successfully
 */
uint8_t snes_call(uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t* rdata)
{
  #define RD_LEN  0
  #define RD0  1
  #define RD1  2

  #define BYTE_LEN 1
  #define HWORD_LEN 2

  switch(opcode) {
    //no return value:
    case SNES_SET_BANK:
      HADDR_SET(operand);
      break;

    case SNES_RD:
      rdata[RD_LEN] = BYTE_LEN;
      rdata[RD0] = snes_rd(operand, miscdata); // last arg is romsel state
      break;

    case SNES_WR_LO:
      snes_wr(operand, miscdata, 0); // last arg is romsel state
      break;

    case SNES_WR_HI:
      snes_wr(operand, miscdata, 1); // last arg is romsel state
      break;

    case SNES_FLASH_WR:
      snes_flash_wr(operand, miscdata);
      break;

      // case SNES_SYS_WR:
      //   snes_wr(operand, miscdata, 1); //last arg is romsel state
      //   break;

      // case SNES_SYS_RD:
      //   rdata[RD_LEN] = BYTE_LEN;
      //   rdata[RD0] = snes_rd(operand, 1); //last arg is romsel state
      //   break;

    case SNES_PAGE_WR_LFSR:
      snes_page_wr_lfsr(operand, miscdata); // miscdata = romsel state
      break;

    default:
      //macro doesn't exist
      return ERR_UNKN_SNES_OPCODE;
  }

  return SUCCESS;
}

/* Desc: Read a SNES byte with /ROMSEL asserted using the read_funcptr signature
 * Pre:  snes_init() has configured the I/O pins and the desired bank is selected
 * Post: Address left on bus; high bank and EXP0/RESET unchanged
 *       data bus left in input mode; /RD and /ROMSEL high
 * Ret:  Byte read at addr in the selected bank
 */
uint8_t snes_rd_romsel_lo(uint16_t addr)
{
  return snes_rd(addr, 0);
}

/* Desc: Read one byte from the SNES bus without changing the selected bank
 *       assert /ROMSEL during the access only when romsel is 0
 * NOTE: /ROMSEL is controlled explicitly, not decoded from the console memory map
 * Pre:  snes_init() has configured the I/O pins and the desired bank is selected
 * Post: Address left on bus; high bank and EXP0/RESET unchanged
 *       data bus left in input mode; /RD and /ROMSEL high
 * Ret:  Byte read at addr in the selected bank
 */
uint8_t snes_rd(uint16_t addr, uint8_t romsel)
{
  uint8_t rv;

  //set address bus
  ADDR_SET(addr);

  if(romsel == 0) {
    ROMSEL_LO();
  }

  CSRD_LO();

  //couple more NOP's waiting for data
  //zero nop's returned previous databus value
  NOP(); //one nop got most of the bits right
  NOP(); //two nop got all the bits right
  NOP(); //add third nop for some extra
  NOP(); //one more can't hurt
  //might need to wait longer for some carts...
  //this was long enough for AVR

  //SNES v2.0p needed 6 more NOPs compared to v3.x & v1.x
  //seems like a crazy long time...
  NOP(); //v2.0p gets prod & density ID correct with addition of this NOP
  //not sure why manf ID and sector ID are so much slower on v2 board
  NOP();
  NOP(); //v2.0p gets most bits right after 3 NOPs
  NOP();
  NOP(); //more after 5 extra...
  NOP(); //all after 6 extra..
  //sounds like 1 AVR NOP needs to equal 2STM32
  //AVR running at 16Mhz, STM32 running at 48Mhz (3x as fast)
  NOP(); //4MB proto needed this to get manfID, sector still bad
  NOP(); //all good on 4MB proto
  NOP(); //swapped for OR gate and takes a little longer now..?

  //latch data
  DATA_RD(rv);

  //return bus to default
  CSRD_HI();
  ROMSEL_HI();

  return rv;
}

/* Desc: Write a SNES byte with /ROMSEL asserted using the write_funcptr signature
 * Pre:  snes_init() has configured the I/O pins and the desired bank is selected
 * Post: Write cycle issued without readback verification
 *       address left on bus; high bank and EXP0/RESET unchanged
 *       data bus returned to input (AVR pull-ups enabled on bits written as 1)
 *       /WR and /ROMSEL high
 * Ret:  None
 */
void snes_wr_romsel_lo(uint16_t addr, uint8_t data)
{
  snes_wr(addr, data, 0);
}

/* Desc: Write one byte to the SNES bus without changing the selected bank
 *       assert /ROMSEL during the access only when romsel is 0
 *       lower /WR before /ROMSEL to set the v3.0 level-shifter direction
 * NOTE: /ROMSEL is controlled explicitly, not decoded from the console memory map
 * Pre:  snes_init() has configured the I/O pins and the desired bank is selected
 * Post: Write cycle issued without readback verification
 *       address left on bus; high bank and EXP0/RESET unchanged
 *       data bus returned to input (AVR pull-ups enabled on bits written as 1)
 *       /WR and /ROMSEL high
 * Ret:  None
 */
void snes_wr(uint16_t addr, uint8_t data, uint8_t romsel)
{
  ADDR_SET(addr);

  //put data on bus
  DATA_OP();
  DATA_SET(data);

  //set /WR low first as this sets direction of
  //level shifter on v3.0 boards
  CSWR_LO();
  //Then set romsel as this enables output of level shifter
  if(romsel == 0) {
    ROMSEL_LO();
  }
  //Doing the other order creates bus conflict between ROMSEL low -> WR low

  //give some time
  NOP();
  NOP();
  NOP(); //3x total NOPs fails ~2Bytes per 2MByte on v3.0 proto and inl6
  //swaping /WR /ROMSEL order above helped greatly
  //but still had 2 byte fails adding NOPS
  NOP(); //4x total NOPs passed all bytes v3.0 SNES and inl6
  NOP();
  NOP(); //6x total NOPs passed all bytes
  NOP();
  NOP();

  //latch data to cart memory/mapper
  CSWR_HI();
  ROMSEL_HI();

  //Free data bus
  DATA_IP();
}

/* Desc: Write one byte to the current SNES bus address
 *       assert /ROMSEL during the access only when romsel is 0
 *       lower /WR before /ROMSEL to set the v3.0 level-shifter direction
 * Pre:  snes_init() has configured the I/O pins and the desired bank is selected
 *       desired address is already on the bus, or the address is irrelevant
 * Post: Write cycle issued without readback verification
 *       address unchanged; high bank and EXP0/RESET unchanged
 *       data bus returned to input (AVR pull-ups enabled on bits written as 1)
 *       /WR and /ROMSEL high
 * Ret:  None
 */
void snes_wr_cur_addr(uint8_t data, uint8_t romsel)
{
  // ADDR_SET(addr);

  //put data on bus
  DATA_OP();
  DATA_SET(data);

  //set /WR low first as this sets direction of
  //level shifter on v3.0 boards
  CSWR_LO();
  //Then set romsel as this enables output of level shifter
  if(romsel == 0) {
    ROMSEL_LO();
  }
  //Doing the other order creates bus conflict between ROMSEL low -> WR low

  //give some time
  NOP();
  NOP();
  NOP(); //3x total NOPs fails ~2Bytes per 2MByte on v3.0 proto and inl6
  //swaping /WR /ROMSEL order above helped greatly
  //but still had 2 byte fails adding NOPS
  NOP(); //4x total NOPs passed all bytes v3.0 SNES and inl6
  //NOP();
  //NOP();  //6x total NOPs passed all bytes

  //latch data to cart memory/mapper
  CSWR_HI();
  ROMSEL_HI();

  //Free data bus
  DATA_IP();
}

/* Desc: Read len + 1 consecutive bytes from a SNES page into data[0..len]
 *       hold /RD low, poll USB for every byte, and assert /ROMSEL only when romsel is 0
 * Pre:  snes_init() has configured the I/O pins and the desired bank is selected
 *       data has room for len + 1 bytes
 *       first + len must be at most 255 to stay within the page
 *       len must be below 255: the 8-bit loop counter wraps at 255
 * Post: Address low byte advanced past the last read (wraps within the page)
 *       data[0..len] filled; data bus left in input mode
 *       /RD and /ROMSEL high; high bank and EXP0/RESET unchanged
 * Ret:  Number of bytes read (len + 1)
 */
uint8_t snes_page_rd(uint8_t* data, uint8_t addrH, uint8_t romsel, uint8_t first, uint8_t len)
{
  uint8_t i;

  //set address bus
  ADDRH(addrH);

  //set lower address bits
  ADDRL(first); //doing this prior to entry and right after latching
                //gives longest delay between address out and latching data

  //set /ROMSEL and /RD
  CSRD_LO();

  if(romsel == 0) {
    ROMSEL_LO();
  }

  for(i = 0; i <= len; i++) {
    usbPoll(); //Call usbdrv.h usb polling while waiting for data
    NOP();
    NOP();
    NOP();

    //latch data
    DATA_RD(data[i]);

    //set lower address bits
    //ADDRL(++first);  THIS broke things, on stm adapter because macro expands it twice!
    first++;
    ADDRL(first);
  }

  //return bus to default
  CSRD_HI();
  ROMSEL_HI();

  //return index of last byte read
  return i;
}

/* Desc: Poll a pending SNES ROM byte program until the expected byte is read
 *       use the supplied /ROMSEL state and call usbPoll before each read
 *       perform at most 0xFFFF reads
 * Pre:  snes_init() has configured the I/O pins and the desired bank is selected
 *       program command and data already sent; addr is the target address
 * Post: Stops when snes_rd(addr, romsel) equals data or the read limit is reached
 *       no program command, retry or flash reset is issued here
 *       address left on bus; data bus left in input mode; /RD and /ROMSEL high
 *       high bank and EXP0/RESET unchanged
 * Ret:  Last byte read at addr; a mismatch with data indicates polling failure
 */
static uint8_t rom_wr_polling(uint16_t addr, uint8_t data, uint8_t romsel)
{
  uint8_t rv;
  uint16_t timeout = 0xffff;

  do {
    usbPoll(); // orignal kazzo needs this frequently to slurp up incoming data
    rv = snes_rd(addr, romsel);
    if(rv == data) {
      break;
    }
  } while(--timeout);

  return rv;
}

/* Desc: SNES ROM flash byte write using the short 0xAA/0x55/0xA0 command sequence
 *       derive the unlock base from addr bits A15-A12 so commands remain in the
 *       same visible LoROM or HiROM window as the byte being programmed
 *       issue unlock commands at base | 0x0AAA and base | 0x0555
 *       program data at addr, then delegate completion polling to rom_wr_polling
 *       assert /ROMSEL for each write and polling read; EXP0/RESET unaffected
 * Pre:  snes_init() has configured the I/O pins and the desired bank is selected
 *       flash must support the short unlock-address sequence
 * Post: Write attempted and polled; no retry or flash reset is issued here
 *       address left on bus; high bank and EXP0/RESET unchanged
 *       data bus left in input mode; /RD, /WR and /ROMSEL high
 * Ret:  Last byte read at addr; compare with data to detect failure
 */
uint8_t snes_flash_wr(uint16_t addr, uint8_t data)
{
  uint8_t romsel = 0;
  uint16_t unlock_base = addr & 0xF000;

  //unlock and write data
  snes_wr(unlock_base | 0x0AAA, 0xAA, romsel);
  snes_wr(unlock_base | 0x0555, 0x55, romsel);
  snes_wr(unlock_base | 0x0AAA, 0xA0, romsel);
  snes_wr(addr, data, romsel);

  return rom_wr_polling(addr, data, romsel);
}

/* Desc: SNES ROM flash byte write using unlock bypass mode
 *       issue the 0xA0 program command and data at addr, then delegate
 *       completion polling to rom_wr_polling
 *       assert /ROMSEL for each write and polling read; EXP0/RESET unaffected
 * Pre:  snes_init() has configured the I/O pins and the desired bank is selected
 *       flash must already be in unlock bypass mode; this function does not exit it
 * Post: Write attempted and polled; unlock bypass mode remains active
 *       no retry or flash reset is issued here
 *       address left on bus; high bank and EXP0/RESET unchanged
 *       data bus left in input mode; /RD, /WR and /ROMSEL high
 * Ret:  Last byte read at addr; compare with data to detect failure
 */
uint8_t snes_flash_wr_unlock(uint16_t addr, uint8_t data)
{
  uint8_t romsel = 0;

  snes_wr(addr, 0xA0, romsel); // unlock bypass command
  snes_wr(addr, data, romsel);

  return rom_wr_polling(addr, data, romsel);
}

/* Desc: Write 256 successive LFSR-generated bytes to the SNES bus
 *       start at addr and use the supplied /ROMSEL state for every write
 * Pre:  snes_init() has configured the I/O pins and the desired bank is selected
 *       LFSR state initialized and the 256-byte range valid for writes
 * Post: LFSR advanced 256 times; writes issued without readback verification
 *       address addr + 255 left on bus; data bus returned to input
 *       /WR and /ROMSEL high; high bank and EXP0/RESET unchanged
 * Ret:  None
 */
void snes_page_wr_lfsr(uint16_t addr, uint8_t romsel)
{
  // TODO give other data sources
  uint16_t i;
  uint8_t data;

  for(i = 0; i < 256; i++) {
    data = lfsr_32();
    snes_wr(addr, data, romsel);
    addr++;
  }
}

#endif //SNES_CONN
