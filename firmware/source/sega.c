#include "sega.h"

//only need this file if connector is present on the device
#ifdef SEGA_CONN 

// uint16_t sega_bank = 0;
uint8_t sega_addr_hi = 0;   // A17-A23
uint16_t sega_addr_lo = 0;  //  A1-A16

//=================================================================================================
//
// SEGA operations
// This file includes all the sega functions possible to be called from the sega dictionary.
//
// See description of the commands contained here in shared/shared_dictionaries.h
//
//=================================================================================================

/* Desc:Function takes an opcode which was transmitted via USB
 *  then decodes it to call designated function.
 *  shared_dict_sega.h is used in both host and fw to ensure opcodes/names align
 * Pre: Macros must be defined in firmware pinport.h
 *  opcode must be defined in shared_dict_sega.h
 * Post:function call complete.
 * Rtn: SUCCESS if opcode found and completed, error if opcode not present or other problem.
 */
uint8_t sega_call(uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata)
{

#define RD_LEN 0
#define RD0 1
#define RD1 2

#define BYTE_LEN 1
#define HWORD_LEN 2

  uint16_t temp;

  switch (opcode) {

    case GEN_SET_ADDR_HI:
      gen_set_addr_hi(operand & 0xff);
      break;

    case GEN_SET_ADDR_LO:
      gen_set_addr_lo(operand);
      break;

    case GEN_SET_ADDR:
      sega_addr_hi = miscdata;
      sega_addr_lo = operand;
      gen_refresh_addr();
      break;

    case GEN_ROM_RD:
      rdata[RD_LEN] = HWORD_LEN;
      temp = gen_rom_rd(operand);
      rdata[RD0] = temp;
      rdata[RD1] = temp >> 8;
      break;

    case GEN_ROM_WR:
      gen_rom_wr(sega_addr_lo, operand);
      break;

    case GEN_SET_RAM:
      gen_set_ram(operand & 0xff);
      break;

/*
    case GEN_WR_LO:
      sega_addr = operand;
      gen_wr_lo(operand, miscdata);
      break;
    case GEN_WR_HI:
      sega_addr = operand;
      gen_wr_hi(operand, miscdata);
      break;
*/
    // case GEN_SET_BANK:
    //   sega_bank = operand;
    //   gen_set_bank(sega_bank);
    //   break;

    // case GEN_FLASH_WR_ADDROFF:
    //   sega_addr += miscdata;
    //   gen_rom_wr(sega_addr, operand);
    //   break;

    // case GEN_SST_FLASH_WR_ADDROFF:
    //   sega_addr += miscdata;
    //   gen_sst_flash_wr(sega_addr, operand);
    //   break;

    case GEN_RAM_WR:
      // sega_addr = operand;
      // gen_ram_wr(sega_addr, miscdata);
      gen_ram_wr(operand, miscdata);
      break;

    case GEN_RAM_RD:
      // sega_addr = operand;
      rdata[RD_LEN] = BYTE_LEN;
      // rdata[RD0] = gen_ram_rd(sega_addr);
      rdata[RD0] = gen_ram_rd(operand);
      break;

    case GEN_TIME_WR:
      gen_time_wr(operand, miscdata);
      break;

    case GEN_PAGE_RAM_WR_LFSR:
      gen_page_ram_wr_lfsr(operand, miscdata);
      break;

    default:
       //macro doesn't exist
       return ERR_UNKN_SEGA_OPCODE;
  }
  
  return SUCCESS;

}

void gen_refresh_addr()
{
// #define LOMEM_TIME_MASK 0x84
#define LOMEM_MASK 0x04
#define TIME_MASK 0x80
  //A17-18, 20-23
  //TODO decode #TIME & LO_MEM
  FFADDR_SET(TIME_MASK | (sega_addr_hi & 0x78) | LOMEM_MASK | (sega_addr_hi & 0x03));
#define SEGA_A19_MASK 0x04
  //A19
  if (sega_addr_hi & SEGA_A19_MASK) {
    GEN_A19_HI();
  } else {
    GEN_A19_LO();
  }
  //use of flip-flop corrupts A1-A16, restore it
  ADDR_SET(sega_addr_lo);
}

void gen_set_addr_hi(uint8_t addr_hi)
{
  sega_addr_hi = addr_hi;
  gen_refresh_addr();
}

void gen_set_addr_lo(uint16_t addr_lo)
{
  sega_addr_lo = addr_lo;
  gen_refresh_addr();
}

uint16_t gen_rom_rd(uint16_t addr_lo)
{
  uint16_t rv;
  uint8_t temp;

  //set data bus as input
  DATA16_IP();

  // set address
  gen_set_addr_lo(addr_lo);

  //set #WE/#LDSW
  GEN_LDSW_HI();

  //set #WE/#UDSW B29  CPU D8-15 data strobe
  GEN_UDSW_HI();

  //clear #C_OE
  GEN_C_OE_LO();

  //clear #C_CE
  GEN_C_CE_LO();

  NOP();
  NOP();
  NOP();
  NOP();
  NOP();
  NOP();
  // 6 above were working, trying more
  // NOP();
  // NOP();
  // NOP();
  // // NOP();
  // // NOP();
  // // NOP();

  DATA16L_RD(rv);
  DATA16H_RD(temp);
  rv |= temp << 8;

  NOP();
  NOP();
  NOP();
  NOP();
  NOP();
  NOP();

  //set #C_CE
  GEN_C_CE_HI();

  //set #C_OE
  GEN_C_OE_HI();

  return rv;
}

void gen_rom_wr(uint16_t addr_lo, uint16_t data)
{

  uint8_t temp = data;

  // set address
  gen_set_addr_lo(addr_lo);

  //put data on bus
  //DATA_OP();
  //DATA_SET(temp); //lower byte D0-7
  DATA16_OP();
  DATA16L_SET(data);
  data = data >> 8;
  DATA16H_SET(data); //put 8bits of data on high byte

  //TODO figure out why this is needed...
  //guessing macro expansion or something with setting both bytes separately
  DATA_SET(temp); //lower byte D0-7

  //clear #WE/#LDSW
  GEN_LDSW_LO();

  //clear #WE/#UDSW B29  CPU D8-15 data strobe
  GEN_UDSW_LO();

  //set #C_OE
  GEN_C_OE_HI();

  //clear #C_CE
  GEN_C_CE_LO();

  NOP();
  NOP();
  NOP();
  NOP();
  NOP();
  NOP();
  // adding NOPs
  NOP();
  NOP();
  NOP();
  NOP();
  NOP();
  NOP();

  //set #WE/#LDSW
  GEN_LDSW_HI();

  //set #WE/#UDSW
  //latch data with /WE - #LDSW
  GEN_UDSW_HI();

  //set #C_CE
  //return bus to default
  GEN_C_CE_HI();

  //Free data bus
  //DATA_IP();
  DATA16_IP();
}

void gen_set_ram(uint8_t data)
{
  gen_time_wr(0x0000, data);
  return;

  // #define LOMEM_MASK 0x04
  // #define TIME_MASK 0x80

  // data = data & 0x0001;

  // DATA_OP();
  // DATA_SET(data);
  // FFADDR_SET(LOMEM_MASK);
  // GEN_C_CE_LO(); // controls level shifters #OE
  // NOP();
  // NOP();
  // NOP();
  // NOP();
  // NOP();
  // NOP();
  // FFADDR_SET(LOMEM_MASK | TIME_MASK);
  // NOP();
  // NOP();
  // NOP();
  // NOP();
  // NOP();
  // NOP();
  // GEN_C_CE_HI(); // controls level shifters #OE
  // //Free data bus
  // DATA_IP();
}

uint8_t gen_ram_rd(uint16_t addr_lo)
{
  uint8_t read; //return value

  // SRAM needs to be enabled and address hi bits set
  // before calling this function

  // set address
  gen_set_addr_lo(addr_lo);

  // set data bus as input
  DATA_IP();

  // clear #C_OE
  GEN_C_OE_LO();

  // set #WE/#LDSW
  GEN_LDSW_HI();

  // clear #C_CE
  GEN_C_CE_LO();

  NOP();
  NOP();
  NOP();
  NOP();
  NOP();
  NOP();

  DATA_RD(read);

  // set #WE/#LDSW
  GEN_LDSW_HI();

  // set #C_OE
  GEN_C_OE_HI();

  // set #C_CE
  GEN_C_CE_HI();

  return read;
}

void gen_ram_wr(uint16_t addr_lo, uint8_t data)
{
  // SRAM needs to be enabled and address hi bits set
  // before calling this function

  // set address
  gen_set_addr_lo(addr_lo);

  // put data on bus
  DATA_OP();
  DATA_SET(data); // lower byte D0-7

  // set #C_OE
  GEN_C_OE_HI();

  // clear #WE - #LDSW
  GEN_LDSW_LO();

  // clear #C_CE
  GEN_C_CE_LO();

  NOP();
  NOP();
  NOP();
  NOP();
  NOP();
  NOP();

  // set #WE/#LDSW - latch data
  GEN_LDSW_HI();

  // set #C_CE
  GEN_C_CE_HI();

  // Free data bus
  DATA_IP();
}
















/* Desc:SEGA GENESIS ROM Page Read with optional USB polling
 * /ROMSEL based on romsel arg, EXP0/RESET unaffected
 * if poll is true calls usbdrv.h usbPoll fuction
 * this is needed to keep from timing out when double buffering usb data
 * Pre: snes_init() setup of io pins
 * num_bytes can't exceed 256B page boundary
 * Post:address left on bus
 * data bus left clear
 * data buffer filled starting at first to last
 * Rtn: Index of last byte read
 */
uint8_t genesis_page_rd(uint8_t *data, uint16_t addrH, uint8_t first, uint8_t len)
{
  uint8_t i;

  uint16_t address = first>>1; // shift because there is no A0

  // address = ((addrH<<8) | first)>>1; // shift because there is no A0
  address = (addrH<<7) | address; // shift because there is no A0

  // set address
  // ADDRH(addrH);
  ADDRH(address>>8);

  // set #C_CE
  GEN_C_CE_LO();

  // set #C_OE
  GEN_C_OE_LO();

  first = address;

  // set lower address bits
  ADDRL(first); // doing this prior to entry and right after latching
        // gives longest delay between address out and latching data
  for(i=0; i<=len; i++) {

    // genesis needed some extra NOPS
    // NOP();
    // NOP();
    // NOP();
    // NOP();
    // NOP();
    // NOP();
    // NOP();
    // NOP();
    
    // latch data high byte
    data[i] = HDATA_VAL;

    i++;

    // latch data low byte
    DATA_RD(data[i]);

    // set lower address bits
    // ADDRL(++first); THIS broke things, on stm adapter because macro expands it twice!
    first++;
    ADDRL(first);
  }

  // return bus to default
  GEN_C_OE_HI();
  GEN_C_CE_HI();

  // return index of last byte read
  return i;
}

/* Desc:SEGA GENESIS RAM Page Read with optional USB polling
 *  /ROMSEL based on romsel arg, EXP0/RESET unaffected
 * if poll is true calls usbdrv.h usbPoll fuction
 * this is needed to keep from timing out when double buffering usb data
 * Pre: sega_init() setup of io pins
 * num_bytes can't exceed 256B page boundary
 * Post:address left on bus
 *  data bus left clear
 * data buffer filled starting at first to last
 * Rtn: Index of last byte read
 */
uint8_t genesis_ram_page_rd(uint8_t *data, uint16_t addrH, uint8_t first, uint8_t len)
{
  uint8_t i;

  // SRAM needs to be enabled and address hi bits set
  // before calling this function

  // sega_addr_hi = 0x20 >> 1; //addrh;
  // sega_addr_lo = ( addrH << 8 ) | first;

  // gen_refresh_addr();

  // set address hi
  ADDRH(addrH);

  // set address
  ADDRL(first);

  // set data bus as input
  DATA_IP();

  // clear #C_OE
  GEN_C_OE_LO();

  // set #WE/#LDSW
  GEN_LDSW_HI();

  for(i=0; i<=len; i++) {

    // clear #C_CE
    GEN_C_CE_LO();

    // genesis needed some extra NOPS
    NOP();
    NOP();
    NOP();
    NOP();
    NOP();
    NOP();
    NOP();
    NOP();
    
    // latch data high byte
    // data[i] = HDATA_VAL;

    // i++;

    // latch data low byte
    DATA_RD(data[i]);

    // set #C_CE
    GEN_C_CE_HI();

    // set lower address bits
    // ADDRL(++first); THIS broke things, on stm adapter because macro expands it twice!
    first++;
    ADDRL(first);

    // sega_addr_lo++;
    // gen_refresh_addr();

  }

  // set #WE/#LDSW
  GEN_LDSW_HI();

  // set #C_OE
  GEN_C_OE_HI();

  // set #C_CE
  GEN_C_CE_HI();

  // return index of last byte read
  return i;
}

void gen_sst_flash_wr(uint16_t addr_lo, uint16_t data)
{
  uint16_t rv;

  gen_rom_wr(0x0555, 0x00AA);
  gen_rom_wr(0x02AA, 0x0055);
  gen_rom_wr(0x0555, 0x00A0);
  gen_rom_wr(addr_lo, data);

  do {
    rv = gen_rom_rd(addr_lo);
  } while (rv != gen_rom_rd(addr_lo));

  return;
}

uint16_t gen_time_wr(uint16_t addr_lo, uint8_t data)
{
  uint16_t rv;
  uint8_t temp;

  // set data bus as input
  DATA16_OP();
  DATA16L_SET(data);
  data = data >> 8;
  DATA16H_SET(data); //put 8bits of data on high byte

  // clear address high bits, clear #TIME signal, set #
  // set address low bits
  FFADDR_SET(0x04);
  ADDR_SET(addr_lo);

  // #AS B18  CPU access entire memory map, indicating address bus valid
  GBP_LO();

  // clear #WE/#UDSW B29  CPU D8-15 data strobe
  GEN_UDSW_LO();

  // clear #WE/#LDSW
  GEN_LDSW_LO();

  NOP();
  NOP();
  NOP();
  NOP();
  NOP();
  NOP();
  //6 above were working, trying more
  // NOP();
  // NOP();
  // NOP();
  // NOP();
  // NOP();
  // NOP();

  // set #WE/#LDSW
  GEN_LDSW_HI();

  // set #WE/#UDSW B29  CPU D8-15 data strobe
  GEN_UDSW_HI();

  // #AS B18  CPU access entire memory map, indicating address bus valid
  GBP_HI();

  // set #TIME signal
  //FFADDR_SET(0x84);
  // gen_set_bank(sega_bank);
  gen_refresh_addr();

  //Free data bus
  DATA16_IP();
}

void gen_page_ram_wr_lfsr(uint16_t addr, uint8_t data)
{
  uint16_t i;

  // SRAM needs to be enabled and bank set
  // before calling this function

  for (i = 0; i < 0x8000; i++)
  {
    // gen_ram_wr(addr, data);

    DATA_OP();
    ADDR_SET(addr);

    //put data on bus
    data = lfsr_32();
    DATA_SET(data); //lower byte D0-7

    //set #C_OE
    GEN_C_OE_HI();

    //clear #WE - #LDSW
    GEN_LDSW_LO();

    //clear #C_CE
    GEN_C_CE_LO();

    NOP();
    NOP();
    NOP();
    NOP();
    NOP();
    NOP();
    
    //set #WE/#LDSW - latch data
    GEN_LDSW_HI();

    //set #C_CE
    GEN_C_CE_HI();

    //Free data bus
    DATA_IP();

    // do some things that take time
    //data = lfsr_32();
    addr++;
  }

}

#endif //SEGA_CONN
