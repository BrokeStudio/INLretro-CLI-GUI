#include "snes.h"

//only need this file if connector is present on the device
#ifdef SNES_CONN

//=================================================================================================
//
//	SNES operations
//	This file includes all the snes functions possible to be called from the snes dictionary.
//
//	See description of the commands contained here in shared/shared_dictionaries.h
//
//=================================================================================================

/* Desc: Dispatch a SNES dictionary opcode received over USB
 *       shared_dict_snes.h defines the opcodes shared by host and firmware
 * Pre:  I/O and mapper state satisfy the selected operation requirements
 *       rdata has room for the response length and one data byte
 * Post: Selected operation performed; SNES_SET_BANK updates the high address
 *       SNES_ROM_RD sets rdata[0] to 1 and rdata[1] to the byte read
 *       write operations leave rdata unchanged; SNES_FLASH_WR ignores readback
 * Rtn:  SUCCESS for a recognized opcode, not a guarantee of flash success
 *       ERR_UNKN_SNES_OPCODE for an unsupported opcode
 */
uint8_t snes_call(uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t* rdata)
{
  #define RD_LEN	0
  #define RD0	1
  #define RD1	2

  #define BYTE_LEN 1
  #define HWORD_LEN 2

  switch(opcode) {
    //no return value:
    case SNES_SET_BANK:
      HADDR_SET(operand);
      break;

    case SNES_ROM_WR:
      snes_wr(operand, miscdata, 0); //last arg is romsel state
      break;

      // case SNES_SYS_WR:
      //   snes_wr(operand, miscdata, 1); //last arg is romsel state
      //   break;

    case SNES_FLASH_WR:
      snes_flash_wr(operand, miscdata); //last arg is romsel state
      break;

    //8bit return values:
    case SNES_ROM_RD:
      rdata[RD_LEN] = BYTE_LEN;
      rdata[RD0] = snes_rd(operand, 0); //last arg is romsel state
      break;

      // case SNES_SYS_RD:
      //   rdata[RD_LEN] = BYTE_LEN;
      //   rdata[RD0] = snes_rd(operand, 1); //last arg is romsel state
      //   break;

    default:
      //macro doesn't exist
      return ERR_UNKN_SNES_OPCODE;
  }

  return SUCCESS;
}

/* Desc: Read a SNES byte using snes_rd with romsel fixed to 0
 *       adapter for read_funcptr; assert /ROMSEL during the read
 * Pre:  snes_init() setup of I/O pins and desired bank selected
 * Post: Address left on bus; high bank and EXP0/RESET unchanged
 *       data bus left in input mode; /RD and /ROMSEL high
 * Rtn:  Byte read at addr in the selected bank
 */
uint8_t snes_rd_romsel_0(uint16_t addr)
{
  return snes_rd(addr, 0);
}

/* Desc: SNES ROM Read without changing high bank
 *       assert /ROMSEL if romsel is 0, otherwise leave it as-is during access
 *       EXP0/RESET not affected
 * NOTE: /ROMSEL is controlled explicitly, not decoded from the console memory map
 * Pre:  snes_init() setup of I/O pins and desired bank selected
 * Post: address left on bus
 *       data bus left in input mode
 *       /RD and /ROMSEL high; high bank and EXP0/RESET unchanged
 * Rtn:  Byte read at addr in the selected bank
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

/* Desc: Write a SNES byte using snes_wr with romsel fixed to 0
 *       adapter for write_funcptr; assert /ROMSEL during the write
 * Pre:  snes_init() setup of I/O pins and desired bank selected
 * Post: Write cycle issued without readback verification
 *       address left on bus; high bank and EXP0/RESET unchanged
 *       data bus returned to input (AVR pull-ups enabled on bits written as 1)
 *       /WR and /ROMSEL high
 * Rtn:  None
 */
void snes_wr_romsel_0(uint16_t addr, uint8_t data)
{
  snes_wr(addr, data, 0);
}

/* Desc: SNES ROM Write
 *       assert /ROMSEL if romsel is 0, otherwise leave it as-is during access
 *       EXP0/RESET unaffected
 *       lower /WR before /ROMSEL to set the v3.0 level-shifter direction
 *       write value to currently selected bank
 * NOTE: /ROMSEL is controlled explicitly, not decoded from the console memory map
 * Pre:  snes_init() setup of I/O pins and desired bank selected
 * Post: Write cycle issued without readback verification
 *       address left on bus
 *       data bus returned to input (AVR pull-ups enabled on bits written as 1)
 *       /WR and /ROMSEL high; high bank and EXP0/RESET unchanged
 * Rtn:  None
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

/* Desc: SNES ROM Write to current address
 *       assert /ROMSEL if romsel is 0, otherwise leave it as-is during access
 *       EXP0/RESET unaffected
 *       lower /WR before /ROMSEL to set the v3.0 level-shifter direction
 *       write value to currently selected bank, and current address
 *       Mostly used when address is don't care
 * Pre:  snes_init() setup of I/O pins and desired bank selected
 *       desired address already on the bus, or address is irrelevant
 * Post: Write cycle issued without readback verification
 *       address unchanged
 *       data bus returned to input (AVR pull-ups enabled on bits written as 1)
 *       /WR and /ROMSEL high; high bank and EXP0/RESET unchanged
 * Rtn:  None
 */
void snes_wr_cur_addr(uint8_t data, uint8_t romsel)
{
  //	ADDR_SET(addr);

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
  //NOP();	//6x total NOPs passed all bytes

  //latch data to cart memory/mapper
  CSWR_HI();
  ROMSEL_HI();

  //Free data bus
  DATA_IP();
}

/* Desc: SNES ROM page read with optional USB polling
 *       read len + 1 bytes from page offset first into data[0..len]
 *       hold /RD low; assert /ROMSEL if romsel is 0, otherwise leave it as-is
 *       high bank and EXP0/RESET unaffected
 *       call usbPoll for each byte when poll is nonzero
 * Pre:  snes_init() setup of I/O pins and desired bank selected
 *       data has room for len + 1 bytes
 *       first + len must be at most 255 to stay within the page
 *       len must be below 255: the 8-bit loop counter wraps at 255
 * Post: Address low byte advanced past the last read (wraps within the page)
 *       data[0..len] filled; data bus left in input mode
 *       /RD and /ROMSEL high; high bank and EXP0/RESET unchanged
 * Rtn:  Number of bytes read (len + 1)
 */
uint8_t snes_page_rd_poll(uint8_t* data, uint8_t addrH, uint8_t romsel, uint8_t first, uint8_t len, uint8_t poll)
{
  uint8_t i;

  //set address bus
  ADDRH(addrH);

  //set /ROMSEL and /RD
  CSRD_LO();

  if(romsel == 0) {
    ROMSEL_LO();
  }

  //set lower address bits
  ADDRL(first); //doing this prior to entry and right after latching
                //gives longest delay between address out and latching data
  for(i = 0; i <= len; i++) {
    //testing shows that having this if statement doesn't affect overall dumping speed
    if(poll == FALSE) {
      NOP(); //couple more NOP's waiting for data
      NOP(); //one prob good enough considering the if/else
      NOP();
      NOP();
    } else {
      usbPoll(); //Call usbdrv.h usb polling while waiting for data
      NOP();
      NOP();
      NOP();
    }

    //latch data
    DATA_RD(data[i]);

    //set lower address bits
    //ADDRL(++first);	THIS broke things, on stm adapter because macro expands it twice!
    first++;
    ADDRL(first);
  }

  //return bus to default
  CSRD_HI();
  ROMSEL_HI();

  //return index of last byte read
  return i;
}

/* Desc: SNES ROM flash byte write using the 0xAA/0x55/0xA0 command sequence
 *       assert /ROMSEL for each write and read; EXP0/RESET unaffected
 *       poll until the byte matches data or the 0xFFFF-attempt limit is reached
 *       call usbPoll on each polling iteration
 * Pre:  snes_init() setup of I/O pins and desired bank selected
 *       flash and board must support unlock addresses 0x8AAA and 0x8555
 * Post: Write attempted; return does not guarantee successful programming
 *       address left on bus; high bank and EXP0/RESET unchanged
 *       data bus left in input mode; /RD, /WR and /ROMSEL high
 * Rtn:  Last byte read at addr; compare with data to detect failure
 */
uint8_t snes_flash_wr(uint16_t addr, uint8_t data)
{
  uint8_t rv;
  uint8_t romsel = 0;
  uint16_t timeout = 0xFFFF;

  //unlock and write data
  snes_wr(0x8AAA, 0xAA, romsel);
  snes_wr(0x8555, 0x55, romsel);
  snes_wr(0x8AAA, 0xA0, romsel);
  snes_wr(addr, data, romsel);

  do {
    rv = snes_rd(addr, romsel);
    usbPoll();
    if(rv == data) {
      break;
    }
  } while(--timeout);

  return rv;
}

/* Desc: SNES ROM flash byte write using unlock bypass mode
 *       assert /ROMSEL for each write and read; EXP0/RESET unaffected
 *       poll until the byte matches data or the 0xFFFF-attempt limit is reached
 *       call usbPoll on each polling iteration
 * Pre:  snes_init() setup of I/O pins and desired bank selected
 *       flash must already be in unlock bypass mode; this function does not exit it
 * Post: Write attempted; return does not guarantee successful programming
 *       address left on bus; high bank and EXP0/RESET unchanged
 *       data bus left in input mode; /RD, /WR and /ROMSEL high
 * Rtn:  Last byte read at addr; compare with data to detect failure
 */
uint8_t snes_flash_unlock_wr(uint16_t addr, uint8_t data)
{
  uint8_t rv;
  uint8_t romsel = 0;
  uint16_t timeout = 0xFFFF;

  snes_wr(addr, 0xA0, romsel); // unlock bypass command
  snes_wr(addr, data, romsel);

  do {
    rv = snes_rd(addr, romsel);
    usbPoll();
    if(rv == data) {
      break;
    }
  } while(--timeout);

  return rv;
}

#endif //SNES_CONN
