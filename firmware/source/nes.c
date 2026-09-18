#include "nes.h"
#include "cic.h"

// only need this file if connector is present on the device
#ifdef NES_CONN

//=================================================================================================
//
// NES operations
// This file includes all the nes functions possible to be called from the nes dictionary.
//
// See description of the commands contained here in shared/shared_dictionaries.h
//
//=================================================================================================

// global variables
uint8_t cur_bank;      // used by some flash algos, must be initialized prior to depending on it
uint16_t bank_table;   // address offset of bank table for mapper writes with bus conflicts
uint8_t num_prg_banks; // used to determine banktable for mappers like colordreams

/* Desc: Dispatch a NES dictionary opcode received over USB
 *       use miscdata and operand as the selected operation arguments
 * Pre:  I/O and mapper state satisfy the selected operation requirements
 *       rdata has room for the response length and up to three data bytes
 * Post: Selected operation performed; bus and mapper state depend on opcode
 *       read/get operations set rdata[0] and the following response bytes
 *       write operations may leave rdata unchanged; flash readbacks are ignored
 * Rtn:  SUCCESS for a recognized opcode, not a guarantee of flash success
 *       ERR_UNKN_NES_OPCODE for an unsupported opcode
 */
uint8_t nes_call(uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t* rdata)
{
  #define RD_LEN 0
  #define RD0 1
  #define RD1 2
  #define RD2 3

  #define BYTE_LEN 1
  #define HWORD_LEN 2

  switch(opcode) {
      // no return value:
    case DISCRETE_EXP0_PRGROM_WR:
      discrete_exp0_prgrom_wr(operand, miscdata);
      break;
    case DISC_PUSH_EXP0_PRGROM_WR:
      disc_push_exp0_prgrom_wr(operand, miscdata);
      break;
    case NES_PPU_WR:
      nes_ppu_wr(operand, miscdata);
      break;
    case NES_CPU_WR:
      nes_cpu_wr(operand, miscdata);
      break;
    case M2_LOW_WR:
      nes_m2_low_wr(operand, miscdata);
      break;
    case M2_HIGH_WR:
      nes_m2_high_wr(operand, miscdata);
      break;
    case NES_DUALPORT_WR:
      nes_dualport_wr(operand, miscdata);
      break;
    // case DISCRETE_EXP0_MAPPER_WR:
    //   discrete_exp0_mapper_wr( operand, miscdata );
    //   break;
    case NES_MMC1_WR:
      mmc1_wr(operand, miscdata, 0);
      break;
    case SET_CUR_BANK:
      cur_bank = operand;
      break;
    case SET_BANK_TABLE:
      bank_table = operand;
      break;
    case SET_NUM_PRG_BANKS:
      num_prg_banks = operand;
      break;
    case NROM_PRG_FLASH_WR:
      nrom_prgrom_flash_wr(operand, miscdata);
      break;
    case NROM_CHR_FLASH_WR:
      nrom_chrrom_flash_wr(operand, miscdata);
      break;
    case MMC1_PRG_FLASH_WR:
      mmc1_prgrom_flash_wr(operand, miscdata);
      break;
    case MMC1_CHR_FLASH_WR:
      mmc1_chrrom_flash_wr(operand, miscdata);
      break;
    case UNROM_PRG_FLASH_WR:
      unrom_prgrom_flash_wr(operand, miscdata);
      break;
    case CNROM_CHR_FLASH_WR:
      cnrom_chrrom_flash_wr(operand, miscdata);
      break;
    case MMC3_PRG_FLASH_WR:
      mmc3_prgrom_flash_wr(operand, miscdata);
      break;
    case MMC3_CHR_FLASH_WR:
      mmc3_chrrom_flash_wr(operand, miscdata);
      break;
    case MMC4_PRG_FLASH_WR:
      mmc4_prgrom_flash_wr(operand, miscdata);
      break;
    case MMC4_CHR_FLASH_WR:
      mmc4_chrrom_flash_wr(operand, miscdata);
      break;
    case CDREAM_CHR_FLASH_WR:
      cdream_chrrom_flash_wr(operand, miscdata);
      break;
    case MAP30_PRG_FLASH_WR:
      map30_prgrom_flash_wr(operand, miscdata);
      break;
    case GTROM_PRG_FLASH_WR:
      gtrom_prgrom_flash_wr(operand, miscdata);
      break;
    case PPU_PAGE_WR_LFSR:
      ppu_page_wr_lfsr(operand, miscdata);
      break;
    case CPU_PAGE_WR_LFSR:
      cpu_page_wr_lfsr(operand, miscdata);
      break;
    case RNBW_PRG_FLASH_WR:
      rnbw_prgrom_flash_wr(operand, miscdata);
      break;
    case RNBW_TSSOP_PRG_FLASH_WR:
      rnbw_prgrom_flash_wr(operand, miscdata);
      break;
    case RNBW_CHR_FLASH_WR:
      rnbw_chrrom_flash_wr(operand, miscdata);
      break;
    case VRC6_PRG_FLASH_WR:
      vrc6_prgrom_flash_wr(operand, miscdata);
      break;
    case VRC6_CHR_FLASH_WR:
      mmc3_chrrom_flash_wr(operand, miscdata);
      break;
    case A53_512K_PRG_FLASH_WR:
      vrc6_prgrom_flash_wr(operand, miscdata);
      break;
    case A53_TSSOP_FLASH_WR:
      a53_tssop_prgrom_flash_wr(operand, miscdata);
      break;

    // 8bit return values:
    case EMULATE_NES_CPU_RD:
      rdata[RD_LEN] = BYTE_LEN;
      rdata[RD0] = emulate_nes_cpu_rd(operand);
      break;
    case NES_CPU_RD:
      rdata[RD_LEN] = BYTE_LEN;
      rdata[RD0] = nes_cpu_rd(operand);
      break;
    case NES_PPU_RD:
      rdata[RD_LEN] = BYTE_LEN;
      rdata[RD0] = nes_ppu_rd(operand);
      break;
    case NES_DUALPORT_RD:
      rdata[RD_LEN] = BYTE_LEN;
      rdata[RD0] = nes_dualport_rd(operand);
      break;
      // case CIRAM_A10_MIRROR:
      //   rdata[RD_LEN] = BYTE_LEN;
      //   rdata[RD0] = ciram_a10_mirroring( );
      //   break;
    case GET_CUR_BANK:
      rdata[RD_LEN] = BYTE_LEN;
      rdata[RD0] = cur_bank;
      break;
    case GET_BANK_TABLE:
      rdata[RD_LEN] = HWORD_LEN;
      rdata[RD0] = bank_table;
      rdata[RD1] = bank_table >> 8;
      break;
    case GET_NUM_PRG_BANKS:
      rdata[RD_LEN] = BYTE_LEN;
      rdata[RD0] = num_prg_banks;
      break;
      // case MMC5_PRG_RAM_WR:
      //   rdata[RD_LEN] = BYTE_LEN;
      //   rdata[RD0] = mmc5_prgram_wr(operand, miscdata);
      //   break;
  #if defined(STM_INL6) || defined(STM_NES)
    case CIC_GET_SIGNATURE:
      rdata[RD_LEN] = 3;
      cic_read_signature(&rdata[RD0]);
      break;
    case CIC_ERASE_PROGRAM:
      rdata[RD_LEN] = BYTE_LEN;
      rdata[RD0] = cic_chip_erase();
      break;
    case CIC_GET_FUSES:
      rdata[RD_LEN] = HWORD_LEN;
      cic_read_fuses(&rdata[RD0]);
      break;
    case CIC_SET_FUSES:
      rdata[RD_LEN] = BYTE_LEN;
      rdata[RD0] = cic_write_fuses(operand, operand >> 8);
      break;
  #endif
    default:
      // macro doesn't exist
      return ERR_UNKN_NES_OPCODE;
  }

  return SUCCESS;
}

/* Desc: Discrete board PRG-ROM only write, does not write to mapper
 *       PRG-ROM /WE <- EXP0 w/PU
 *       PRG-ROM /OE <- /ROMSEL
 *       PRG-ROM /CE <- GND
 *       PRG-ROM write: /WE & /CE low, /OE high
 *       mapper '161 CLK  <- /ROMSEL
 *       mapper '161 /LOAD <- PRG R/W
 *       mapper '161 /LOAD must be low on rising edge of CLK to latch data
 *       This is a /WE controlled write. Address latched on falling edge,
 *       and data latched on rising edge EXP0
 * Note: addrH bit7 has no effect (ends up on PPU /A13)
 *       /ROMSEL, M2, & PRG R/W signals untouched
 * Pre:  nes_init() setup of I/O pins
 * Post: data latched by PRG-ROM, mapper register unaffected
 *       address left on bus
 *       data bus returned to input
 *       EXP0 left pulled up
 * Rtn:  None
 */
void discrete_exp0_prgrom_wr(uint16_t addr, uint8_t data)
{
  ADDR_SET(addr);

  DATA_OP();
  DATA_SET(data);

  EXP0_OP(); // Tas = 0ns, Tah = 30ns
  EXP0_LO();
  EXP0_IP_PU(); // Twp = 40ns, Tds = 40ns, Tdh = 0ns
  // 16Mhz avr clk = 62.5ns period guarantees timing reqts
  DATA_IP();
}

/* Desc: Discrete board PRG-ROM write using a driven EXP0 /WE pulse
 *       unlike discrete_exp0_prgrom_wr, actively drive EXP0 high at the end
 * Pre:  nes_init() setup of I/O pins
 *       board routes EXP0 to PRG-ROM /WE and permits active high drive
 *       /ROMSEL and other control lines set for a flash-only write
 * Post: Address left on bus; data bus returned to input
 *       EXP0 remains an output driven high; M2 and PRG R/W unchanged
 *       /ROMSEL unchanged; no readback verification performed
 * Rtn:  None
 */
void disc_push_exp0_prgrom_wr(uint16_t addr, uint8_t data)
{
  ADDR_SET(addr);

  DATA_OP();
  DATA_SET(data);

  EXP0_OP(); // Tas = 0ns, Tah = 30ns
  EXP0_LO();
  // EXP0_IP_PU(); //Twp = 40ns, Tds = 40ns, Tdh = 0ns
  EXP0_HI(); // Twp = 40ns, Tds = 40ns, Tdh = 0ns
  // 16Mhz avr clk = 62.5ns period guarantees timing reqts
  DATA_IP();
}

/* Desc: Discrete board MAPPER write without bus conflicts
 *       will also write to PRG-ROM, but PRG-ROM shouldn't output
 *       data while writing to mapper.  Thus removing need for bank table.
 *       NOTE: I think it would be possible to write one value to mapper
 *       and another value to PRG-ROM.
 *       PRG-ROM /WE <- EXP0 w/PU
 *       PRG-ROM /OE <- /ROMSEL
 *       PRG-ROM /CE <- GND
 *       PRG-ROM write: /WE & /CE low, /OE high
 *       mapper '161 CLK  <- /ROMSEL
 *       mapper '161 /LOAD <- PRG R/W
 *       mapper '161 /LOAD must be low on rising edge of CLK to latch data
 * Note: addrH bit7 has no effect (ends up on PPU /A13)
 *       M2 signal untouched
 * Pre:  nes_init() setup of I/O pins
 * Post: data latched by MAPPER, will also be written to PRG-ROM afterwards
 *       address left on bus
 *       data left on bus, but pullup only
 *       EXP0 left pulled up
 * Rtn:  None
 */
// void discrete_exp0_mapper_wr( uint16_t addr, uint8_t data )
//{
//  //Float EXP0 as it should be in NES
//  EXP0_IP_FL();
//  //EXP0_OP(); //tas = 0ns, tah = 30ns
//  //EXP0_LO();
//
//  //need for whole function
//  //_DATA_OP();
//
//  //set addrL
//  //ADDR_OUT = addrL;
//  //latch addrH
//  //DATA_OUT = addrH;
//  //_AHL_CLK();
//  ADDR_SET(addr);
//
//  //PRG R/W LO
//  PRGRW_LO();
//
//  //put data on bus
//  DATA_OP();
//  DATA_SET(data);
//
//  //set M2 and /ROMSEL
//  M2_HI();
//  if( addr >= 0x8000 ) { //addressing cart rom space
//    ROMSEL_LO(); //romsel trails M2 during CPU operations
//  }
//
//  //give some time
//  NOP();
//  NOP();
//
//  //latch data to cart memory/mapper
//  M2_LO();
//  ROMSEL_HI();
//
//  //retore PRG R/W to default
//  PRGRW_HI();
//
//  EXP0_IP_PU(); //Twp = 40ns, Tds = 40ns, Tdh = 0ns
//  //Free data bus
//  DATA_IP();
//
//  return;
//
//  /*
//  ADDR_SET(addr);
//
//  DATA_OP();
//  DATA_SET(data);
//
//  //start write to PRG-ROM (latch address)
//  exp0_op(); //tas = 0ns, tah = 30ns
//  exp0_lo();
//
//  //enable write to mapper PRG R/W LO
//  PRGRW_LO();
//  ROMSEL_LO(); //fact that it's low for such a short time might also if PRG-ROM does output data
//
//  NOP();  //AVR didn't need this delay
//  NOP();  //AVR didn't need this delay
//  NOP();  //AVR didn't need this delay
//  NOP();  //AVR didn't need this delay
//  NOP();  //AVR didn't need this delay
//  NOP();  //AVR didn't need this delay
//  //clock mapper register, should not enable PRG-ROM output since /WE low
//  NOP();  //AVR didn't need this delay
//  NOP();  //AVR didn't need this delay
//  ROMSEL_HI(); //data latched on rising edge
//
//  //Could output other data here that would like to be written to PRG-ROM
//  //I'm not certain an actual write gets applied to PRG-ROM as /OE is supposed to be high whole time..
//
//  NOP();  //AVR didn't need this delay
//  //return to default
//  PRGRW_HI();
//
//  EXP0_IP_PU(); //Twp = 40ns, Tds = 40ns, Tdh = 0ns
//  //16Mhz avr clk = 62.5ns period guarantees timing reqts
//  DATA_IP();
//  */
// }

/* Desc: Emulate NES CPU Read as best possible
 *       decode A15 from addr to set /ROMSEL as expected
 *       float EXP0
 *       toggle M2 as NES would
 *       insert some NOP's in to be slow like NES
 * Note: not the fastest read operation
 * Pre:  nes_init() setup of I/O pins
 * Post: address left on bus
 *       data bus remains input
 *       EXP0 left floating
 *       M2 low and /ROMSEL high
 * Rtn:  Byte read from the CPU bus at addr
 */
uint8_t emulate_nes_cpu_rd(uint16_t addr)
{
  uint8_t rv;

  // m2 should be low as it aids in disabling WRAM
  // this is also m2 state at beginging of CPU cycle
  // all these pins should already be in this state, but
  // go ahead and setup just to be sure since we're trying
  // to be as accurate as possible
  EXP0_IP_FL(); // this could have been left pulled up
  M2_LO();      // start of CPU cycle
  ROMSEL_HI();  // trails M2
  PRGRW_HI();   // happens just after M2

  // set address bus
  ADDR_SET(addr);

  // couple NOP's to wait a bit
  NOP();
  NOP();

  // set M2 and /ROMSEL
  if(addr >= 0x8000) { // addressing cart rom space
    M2_HI();
    ROMSEL_LO(); // romsel trails M2 during CPU operations
  } else {
    M2_HI();
  }

  // couple more NOP's waiting for data
  NOP();
  NOP();
  NOP();
  NOP();
  NOP();
  NOP();

  // latch data
  DATA_RD(rv);

  // return bus to default
  M2_LO();
  ROMSEL_HI();

  return rv;
}

/* Desc: NES CPU Read without being so slow
 *       decode A15 from addr to set /ROMSEL as expected
 *       float EXP0
 *       toggle M2 as NES would
 * Pre:  nes_init() setup of I/O pins
 * Post: address left on bus
 *       data bus remains input
 *       EXP0 unchanged
 *       M2 low and /ROMSEL high
 * Rtn:  Byte read from the CPU bus at addr
 */
uint8_t nes_cpu_rd(uint16_t addr)
{
  uint8_t rv;

  // set address bus
  ADDR_SET(addr);

  // set M2 and /ROMSEL
  if(addr >= 0x8000) { // addressing cart rom space
    ROMSEL_LO();       // romsel trails M2 during CPU operations
  }
  M2_HI();

  // couple more NOP's waiting for data
  // zero nop's returned previous databus value
  // wdt_reset();
  NOP(); // one nop got most of the bits right
  NOP(); // two nop got all the bits right
  NOP(); // add third nop for some extra
  NOP(); // one more can't hurt
  // might need to wait longer for some carts...
  // NOP();
  // NOP();
  // NOP();

  // latch data
  DATA_RD(rv);

  // return bus to default
  M2_LO();
  ROMSEL_HI();

  return rv;
}

/* Desc: NES CPU Write
 *       Just as you would expect NES's CPU to perform
 *       A15 decoded to enable /ROMSEL
 *       This ends up as a M2 and/or /ROMSEL controlled write
 * Note: addrH bit7 has no effect (ends up on PPU /A13)
 *       EXP0 floating
 * Pre:  nes_init() setup of I/O pins
 * Post: data latched by anything listening on the bus
 *       address left on bus
 *       data bus returned to input
 *       EXP0 floating; M2 low, /ROMSEL and PRG R/W high
 * Rtn:  None
 */
void nes_cpu_wr(uint16_t addr, uint8_t data)
{
  // Float EXP0 as it should be in NES
  EXP0_IP_FL();

  // need for whole function
  //_DATA_OP();

  // set addrL
  // ADDR_OUT = addrL;
  // latch addrH
  // DATA_OUT = addrH;
  //_AHL_CLK();
  ADDR_SET(addr);

  // PRG R/W LO
  PRGRW_LO();

  // put data on bus
  DATA_OP();
  DATA_SET(data);

  // set M2 and /ROMSEL
  // this was bad for $6000 WRAM decoding!
  // we're creating our own /ROMSEL delay which can cause problems!!!
  if(addr >= 0x8000) { // addressing cart rom space
    ROMSEL_LO();       // romsel trails M2 during CPU operations
  }
  M2_HI();

  // give some time
  NOP();
  NOP();
  NOP(); // Writing to MMC4 SRAM 2 NOPs wasn't enough..
  NOP();
  NOP();
  NOP(); // Writing to RNBW PRG-ROM needs 6 NOPs minimum
  #ifdef AVR_KAZZO
  if(addr >= 0x6000 && addr < 0x8000) {
    NOP();
    // NOP();
    // NOP();
  }
  #endif
  // NOP();
  // NOP();
  // NOP();
  // NOP();
  // NOP();
  // NOP(); // All of this for Rainbow ?! maybe somewhere in the middle could work

  // latch data to cart memory/mapper
  M2_LO();
  ROMSEL_HI();

  // restore PRG R/W to default
  PRGRW_HI();

  // Free data bus
  DATA_IP();
}

/* Desc: NES CPU Write, but M2 remains low
 *       Allows writes to flash, but not memory if M2 must be high for mapper to latch the write
 *       A15 decoded to enable /ROMSEL
 * Note: addrH bit7 has no effect (ends up on PPU /A13)
 *       EXP0 as-is
 * Pre:  nes_init() setup of I/O pins
 * Post: data latched by anything listening on the bus
 *       address left on bus
 *       data bus returned to input
 *       M2 and EXP0 unchanged; /ROMSEL and PRG R/W high
 * Rtn:  None
 */
void nes_m2_low_wr(uint16_t addr, uint8_t data)
{
  // Float EXP0 as it should be in NES
  // EXP0_IP_FL();

  // need for whole function
  //_DATA_OP();

  // set addrL
  // ADDR_OUT = addrL;
  // latch addrH
  // DATA_OUT = addrH;
  //_AHL_CLK();
  ADDR_SET(addr);

  // PRG R/W LO
  PRGRW_LO();

  // put data on bus
  DATA_OP();
  DATA_SET(data);

  // set M2 and /ROMSEL
  //  M2_HI();
  if(addr >= 0x8000) { // addressing cart rom space
    ROMSEL_LO();       // romsel trails M2 during CPU operations
  }

  // give some time
  NOP();
  NOP();

  // latch data to cart memory/mapper
  //  M2_LO();
  ROMSEL_HI();

  // retore PRG R/W to default
  PRGRW_HI();

  // Free data bus
  DATA_IP();
}

/* Desc: NES CPU Write, but M2 remains high
 *       Created for action53 mapper where board's level shifter /OE pin
 *       is driven by inverse of M2.  So for address to be applied to flash,
 *       M2 must be high.
 *       A15 decoded to enable /ROMSEL
 * Note: addrH bit7 has no effect (ends up on PPU /A13)
 *       EXP0 as-is
 * Pre:  nes_init() setup of I/O pins
 * Post: data latched by anything listening on the bus
 *       address left on bus
 *       data bus returned to input
 *       M2 returned low; /ROMSEL and PRG R/W returned high
 * Rtn:  None
 */
void nes_m2_high_wr(uint16_t addr, uint8_t data)
{
  M2_HI();

  // Float EXP0 as it should be in NES
  // EXP0_IP_FL();

  // need for whole function
  //_DATA_OP();

  // set addrL
  // ADDR_OUT = addrL;
  // latch addrH
  // DATA_OUT = addrH;
  //_AHL_CLK();
  ADDR_SET(addr);

  // PRG R/W LO
  PRGRW_LO();

  // put data on bus
  DATA_OP();
  DATA_SET(data);

  // set M2 and /ROMSEL
  //  M2_HI();
  if(addr >= 0x8000) { // addressing cart rom space
    ROMSEL_LO();       // romsel trails M2 during CPU operations
  }

  // give some time
  NOP();
  NOP();

  // latch data to cart memory/mapper
  //  M2_LO();
  ROMSEL_HI();

  // retore PRG R/W to default
  PRGRW_HI();

  // Free data bus
  DATA_IP();

  // return M2 to default state
  M2_LO();
}

/* Desc: NES PPU Read
 *       decode A13 from addr to set /A13 as expected
 * Pre:  nes_init() setup of I/O pins
 * Post: address left on bus
 *       data bus remains input
 *       CHR /RD high; address includes the encoded PPU /A13 signal
 * Rtn:  Byte read from PPU bus at addr
 */
uint8_t nes_ppu_rd(uint16_t addr)
{
  uint8_t rv;

  // addr with PPU /A13
  if(addr < 0x2000) { // below $2000 A13 clear, /A13 set
    addr |= PPU_A13N_WORD;
  } // above PPU $1FFF, A13 set, /A13 clear

  ADDR_SET(addr);

  // set CHR /RD and /WR
  CSRD_LO();

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
  CSRD_HI();

  return rv;
}

/* Desc: NES PPU Write
 *       decode A13 from addr to set /A13 as expected
 *       flash: address clocked falling edge, data rising edge of /WE
 * Pre:  nes_init() setup of I/O pins
 * Post: data written to addr
 *       address left on bus
 *       data bus left clear
 *       CHR /WR high; address includes the encoded PPU /A13 signal
 * Rtn:  None
 */
void nes_ppu_wr(uint16_t addr, uint8_t data)
{
  // addr with PPU /A13
  if(addr < 0x2000) { // below $2000 A13 clear, /A13 set
    addr |= PPU_A13N_WORD;
  } // above PPU $1FFF, A13 set, /A13 clear

  ADDR_SET(addr);

  // put data on bus
  DATA_OP();
  DATA_SET(data);

  // NOP();

  // set CHR /RD and /WR
  CSWR_LO();

  // might need to wait longer for some carts...
  NOP(); // one can't hurt
  NOP();
  NOP();
  NOP();

  // latch data to memory
  CSWR_HI();

  // clear data bus
  DATA_IP();
}

/* Desc: NES dual port Read from the PPU
 *       /A13 ignored
 * Pre:  nes_init() setup of I/O pins
 * Post: address left on bus
 *       data bus remains input
 *       CHR /RD high, M2 low and /ROMSEL high
 * Rtn:  Byte read from PPU bus at addr
 */
uint8_t nes_dualport_rd(uint16_t addr)
{
  uint8_t rv;

  ADDR_SET(addr);

  // enable data path
  M2_HI();     // M2 is kinda like R/W setting direction
  ROMSEL_LO(); // enable data buffers
  // data should now be driven on the bus but invalid

  // set CHR /RD and /WR
  CSRD_LO();

  // couple more NOP's waiting for data
  // zero nop's returned previous databus value
  NOP(); // one nop got most of the bits right
  NOP(); // two nop got all the bits right
  NOP(); // add third nop for some extra

  // latch data
  DATA_RD(rv);

  // return bus to default
  CSRD_HI();
  M2_LO();
  ROMSEL_HI();

  return rv;
}

/* Desc: NES DUALPORT Write
 *       /A13 ignored
 * Pre:  nes_init() setup of I/O pins
 * Post: data written to addr
 *       address left on bus
 *       data bus left clear
 *       CHR /WR high, M2 low and /ROMSEL high
 * Rtn:  None
 */
void nes_dualport_wr(uint16_t addr, uint8_t data)
{
  ADDR_SET(addr);

  // enable data path
  M2_LO();     // M2 is kinda like R/W setting direction
  ROMSEL_LO(); // enable data buffers
  // data should now be driven on the bus but invalid

  // put data on bus
  DATA_OP();
  DATA_SET(data);

  NOP();

  // set CHR /RD and /WR
  CSWR_LO();

  // might need to wait longer for some carts...
  NOP(); // one can't hurt

  // latch data to memory
  CSWR_HI();

  // clear data bus
  DATA_IP();
  ROMSEL_HI();
}

/* Desc: PPU CIRAM A10 NT arrangement sense
 *       Toggle A11 and A10 and read back CIRAM A10
 *       report back if vert/horiz/1scnA/1scnB
 *       reports nesdev defined mirroring
 *       does not report Nintendo's "Name Table Arrangement"
 * Pre:  nes_init() setup of I/O pins
 * Post: address left on bus
 * Rtn:  MIR_VERT, MIR_HORIZ, MIR_1SCNA, MIR_1SCNB
 *       errors not really possible since all combinations
 *       of CIRAM A10 level designate something valid
 */
// uint8_t ciram_a10_mirroring( void )
//{
//  uint16_t readV, readH;
//
//  //set A11, clear A10
//  //ADDRH(A11_BYTE); setting A11 in this manner doesn't work for some reason..
//  ADDR_SET(0x0800);
//  //CIA10_RD(readH);
//  readH = (C11bank->IDR & (1<<C11));
//
//  //set A10, clear A11
//  //ADDRH(A10_BYTE);
//  ADDR_SET(0x0400);
//  //ADDR_SET(0x0400);
//  readV = (C11bank->IDR & (1<<C11));
//  //CIA10_RD(readV);
//
//
//  //if CIRAM A10 was always low -> 1 screen A
//  if ((readV==0) && (readH==0)) return MIR_1SCNA;
//  //if CIRAM A10 was always high -> 1 screen B
//  if ((readV!=0) && (readH!=0)) return MIR_1SCNB;
//  //if CIRAM A10 toggled with A10 -> Vertical mirroring, horizontal arrangement
//  if ((readV!=0) && (readH==0)) return MIR_VERT;
//  //if CIRAM A10 toggled with A11 -> Horizontal mirroring, vertical arrangement
//  if ((readV==0) && (readH!=0)) return MIR_HORZ;
//
//  //shouldn't be here...
//  return GEN_FAIL;
// }

/* Desc: NES CPU page read with optional USB polling
 *       hold M2 high during the page read; decode /ROMSEL from addrH
 *       read len + 1 bytes from page offset first into data[0..len]
 *       call usbPoll for each byte when poll is nonzero
 * Pre:  nes_init() setup of I/O pins
 *       PRG R/W and /ROMSEL initially high
 *       desired bank selected and data has room for len + 1 bytes
 *       len must be below 255: the 8-bit loop counter wraps at 255
 *       first + len must be at most 255 to stay within the page
 * Post: M2 low, /ROMSEL high; EXP0 unchanged
 *       address low byte advanced past the last read (wraps within the page)
 *       data[0..len] filled; data bus remains input
 * Rtn:  Number of bytes read (len + 1)
 */
uint8_t nes_cpu_page_rd_poll(uint8_t* data, uint8_t addrH, uint8_t first, uint8_t len, uint8_t poll)
{
  uint8_t i;

  // set address bus
  ADDRH(addrH);

  // set lower address bits
  ADDRL(first); // doing this prior to entry and right after latching

  // set M2 and /ROMSEL
  if(addrH >= 0x80) { // addressing cart rom space
    ROMSEL_LO();      // romsel trails M2 during CPU operations
  }
  M2_HI();

  // // set lower address bits
  // ADDRL(first); // doing this prior to entry and right after latching
  // extra NOP was needed on stm6 as address hadn't settled in time for the very first read
  NOP();
  // gives longest delay between address out and latching data
  for(i = 0; i <= len; i++) {
    // testing shows that having this if statement doesn't affect overall dumping speed
    if(poll == FALSE) {
      NOP(); // couple more NOP's waiting for data
      NOP(); // one prob good enough considering the if/else
    } else {
      usbPoll(); // Call usbdrv.h usb polling while waiting for data
    }

    // add some delay for 4-8MByte 3v flash
    NOP();
    NOP(); // one more for rainbow?
    NOP(); // one more for rainbow?
    NOP(); // one more for rainbow?
    NOP(); // one more for rainbow?
    NOP(); // one more for rainbow?
    NOP(); // one more for rainbow?
    NOP(); // one more for rainbow?
    NOP(); // one more for rainbow?
    NOP(); // one more for rainbow?
    NOP(); // one more for rainbow?
    NOP(); // one more for rainbow?
    NOP(); // one more for rainbow?
    NOP(); // one more for rainbow?
    NOP(); // one more for rainbow?
    NOP(); // one more for rainbow?
    NOP(); // one more for rainbow?
    NOP(); // one more for rainbow?

    // latch data
    DATA_RD(data[i]);

    NOP();
    NOP();

    // set lower address bits
    // ADDRL(++first); THIS broke things, on stm adapter because macro expands it twice!
    first++;
    ADDRL(first);
  }

  // return bus to default
  M2_LO();
  ROMSEL_HI();

  // return index of last byte read
  return i;
}

/* Desc: NES CPU page read with optional USB polling
 *       toggle M2 and decode /ROMSEL for each byte
 *       read len + 1 bytes from page offset first into data[0..len]
 *       call usbPoll for each byte when poll is nonzero
 * Pre:  nes_init() setup of I/O pins
 *       PRG R/W and /ROMSEL initially high
 *       desired bank selected and data has room for len + 1 bytes
 *       len must be below 255: the 8-bit loop counter wraps at 255
 *       first + len must be at most 255 to stay within the page
 * Post: M2 low, /ROMSEL high; EXP0 unchanged
 *       address low byte advanced past the last read (wraps within the page)
 *       data[0..len] filled; data bus remains input
 * Rtn:  Number of bytes read (len + 1)
 */
uint8_t nes_cpu_page_rd_toggle(uint8_t* data, uint8_t addrH, uint8_t first, uint8_t len, uint8_t poll)
{
  uint8_t i;

  // set address bus
  ADDRH(addrH);

  // set lower address bits
  ADDRL(first); // doing this prior to entry and right after latching

  // // set /ROMSEL
  // if (addrH >= 0x80)
  // {              // addressing cart rom space
  //   ROMSEL_LO(); // romsel trails M2 during CPU operations
  // }

  // set lower address bits
  // ADDRL(first); // doing this prior to entry and right after latching
  // extra NOP was needed on stm6 as address hadn't settled in time for the very first read
  NOP();
  // gives longest delay between address out and latching data
  for(i = 0; i <= len; i++) {
    M2_HI();
    // set /ROMSEL
    if(addrH >= 0x80) { // addressing cart rom space
      ROMSEL_LO();      // romsel trails M2 during CPU operations
    }

    // testing shows that having this if statement doesn't affect overall dumping speed
    if(poll == FALSE) {
      NOP(); // couple more NOP's waiting for data
      NOP(); // one prob good enough considering the if/else
    } else {
      usbPoll(); // Call usbdrv.h usb polling while waiting for data
    }

    // add some delay for 4-8MByte 3v flash
    NOP();
    NOP();
    NOP();
    NOP();
    NOP();
    NOP();
    NOP();
    NOP();
    NOP(); // EKH: Needed one more NOP for MMC3 PRG ROM

    // latch data
    DATA_RD(data[i]);
    M2_LO();
    ROMSEL_HI();
    NOP();
    NOP();
    NOP();
    NOP();
    NOP();
    NOP();
    NOP(); // need these NOPs for Rainbow 256K PRG-RAM for some reason
    // set lower address bits
    // ADDRL(++first); THIS broke things, on stm adapter because macro expands it twice!
    first++;
    ADDRL(first);
  }

  // return bus to default
  M2_LO();
  ROMSEL_HI();

  // return index of last byte read
  return i;
}

/* Desc: NES PPU page read with optional USB polling
 *       hold CHR /RD low during the page read and encode PPU /A13
 *       read len + 1 bytes from page offset first into data[0..len]
 *       call usbPoll for each byte when poll is nonzero
 * Pre:  nes_init() setup of I/O pins
 *       desired bank selected and data has room for len + 1 bytes
 *       len must be below 255: the 8-bit loop counter wraps at 255
 *       first + len must be at most 255 to stay within the page
 * Post: CHR /RD high
 *       address low byte advanced past the last read (wraps within the page)
 *       data[0..len] filled; data bus remains input
 * Rtn:  Number of bytes read (len + 1)
 */
uint8_t nes_ppu_page_rd_poll(uint8_t* data, uint8_t addrH, uint8_t first, uint8_t len, uint8_t poll)
{
  uint8_t i;

  if(addrH < 0x20) { // below $2000 A13 clear, /A13 set
    // ADDRH(addrH | PPU_A13N_BYTE);
    // Don't do weird stuff like above!  logic inside macro expansions can have weird effects!!
    addrH |= PPU_A13N_BYTE;
    ADDRH(addrH);
  } else { // above PPU $1FFF, A13 set, /A13 clear
    ADDRH(addrH);
  }

  // set lower address bits
  ADDRL(first); // doing this prior to entry and right after latching

  // set CHR /RD and /WR
  CSRD_LO();

  // set lower address bits
  // moved this above for compatibility with Rainbow, address needs to be stable before toggling /RD
  // ADDRL(first); // doing this prior to entry and right after latching

  NOP(); // adding extra NOP as it was needed on PRG
         // gives longest delay between address out and latching data
  NOP(); // EKH: Needed another NOP for the first byte of 4k blocks on several MMC3 carts
  NOP();
  NOP();

  for(i = 0; i <= len; i++) {
    // couple more NOP's waiting for data
    if(poll == FALSE) {
      NOP(); // one prob good enough considering the if/else
      NOP();
      NOP(); // EKH: Needed another one for several MMC3 carts
    } else {
      usbPoll();
    }
    // latch data
    DATA_RD(data[i]);

    // set CHR /RD and /WR
    // CSRD_HI();

    // set lower address bits
    first++;
    ADDRL(first);
  }

  // return bus to default
  CSRD_HI();

  // return index of last byte read
  return i;
}

/* Desc: NES PPU page read with optional USB polling
 *       toggle CHR /RD for each byte and encode PPU /A13
 *       read len + 1 bytes from page offset first into data[0..len]
 *       call usbPoll for each byte when poll is nonzero
 * Pre:  nes_init() setup of I/O pins
 *       desired bank selected and data has room for len + 1 bytes
 *       len must be below 255: the 8-bit loop counter wraps at 255
 *       first + len must be at most 255 to stay within the page
 * Post: CHR /RD high
 *       address low byte advanced past the last read (wraps within the page)
 *       data[0..len] filled; data bus remains input
 * Rtn:  Number of bytes read (len + 1)
 */
uint8_t nes_ppu_page_rd_toggle(uint8_t* data, uint8_t addrH, uint8_t first, uint8_t len, uint8_t poll)
{
  uint8_t i;

  if(addrH < 0x20) { // below $2000 A13 clear, /A13 set
    // ADDRH(addrH | PPU_A13N_BYTE);
    // Don't do weird stuff like above!  logic inside macro expansions can have weird effects!!
    addrH |= PPU_A13N_BYTE;
    ADDRH(addrH);
  } else { // above PPU $1FFF, A13 set, /A13 clear
    ADDRH(addrH);
  }

  // set lower address bits
  ADDRL(first); // doing this prior to entry and right after latching

  // dual port assumes address is valid shortly after /RD & /WR are both high
  CSRD_LO();
  CSRD_HI();
  NOP();
  NOP();
  NOP();
  // now it'll go fetch the current address

  for(i = 0; i <= len; i++) {
    // set CHR /RD and /WR
    CSRD_LO();
    // couple more NOP's waiting for data
    NOP();
    NOP();

    if(poll == FALSE) {
      NOP(); // one prob good enough considering the if/else
      NOP();
    } else {
      usbPoll();
    }

    // latch data
    DATA_RD(data[i]);

    // set lower address bits
    first++;
    ADDRL(first);

    // return bus to default
    // also triggers fetch of the current address
    CSRD_HI();
    NOP();
    NOP();
  }

  // return index of last byte read
  return i;
}

/* Desc: Write 256 successive LFSR-generated bytes to the NES PPU bus
 *       start at addr; the supplied data argument is overwritten
 *       nes_ppu_wr encodes PPU /A13 from addr for each write
 *       each byte uses a /WE-controlled write
 * Pre:  nes_init() setup of I/O pins
 *       LFSR state initialized and the 256-byte range valid for writes
 * Post: LFSR advanced 256 times; writes issued without readback verification
 *       last written address left on bus; data bus returned to input
 * Rtn:  None
 */
void ppu_page_wr_lfsr(uint16_t addr, uint8_t data)
// TODO give other data sources
{
  uint16_t i;

  for(i = 0; i < 256; i++) {
    data = lfsr_32();
    nes_ppu_wr(addr, data);
    addr++;
  }

  return;
}

/* Desc: Write 256 successive LFSR-generated bytes to the NES CPU bus
 *       start at addr; the supplied data argument is overwritten
 *       nes_cpu_wr decodes A15 from addr to control /ROMSEL
 *       each byte uses a CPU write cycle with PRG R/W low and M2 toggled
 * Pre:  nes_init() setup of I/O pins
 *       LFSR state initialized and the 256-byte range valid for writes
 * Post: LFSR advanced 256 times; writes issued without readback verification
 *       last written address left on bus; data bus returned to input
 * Rtn:  None
 */
void cpu_page_wr_lfsr(uint16_t addr, uint8_t data)
{
  // TODO give other data sources
  uint16_t i;

  for(i = 0; i < 256; i++) {
    data = lfsr_32();
    nes_cpu_wr(addr, data);
    addr++;
  }
}

/* Desc: Poll a pending PRG-ROM byte program through the NES CPU bus
 *       call usbPoll before each read; perform at most 0xFFFF reads
 * Pre:  nes_init() setup of I/O pins
 *       program command and data already sent; target bank remains selected
 *       addr is the CPU address to poll and data is the expected byte
 * Post: Stops when nes_cpu_rd(addr) equals data or the read limit is reached
 *       no program command, retry or flash reset is issued here
 * Rtn:  Last CPU byte read at addr; a mismatch indicates polling failure
 */
uint8_t prgrom_wr_polling(uint16_t addr, uint8_t data)
{
  uint8_t rv;
  uint16_t timeout = 0xffff;

  do {
    usbPoll(); // orignal kazzo needs this frequently to slurp up incoming data
    rv = nes_cpu_rd(addr);
    if(rv == data) {
      break;
    }
  } while(--timeout);

  return rv;
}

/* Desc: Poll a pending CHR-ROM byte program through the NES PPU bus
 *       call usbPoll before each read; perform at most 0xFFFF reads
 * Pre:  nes_init() setup of I/O pins
 *       program command and data already sent; target bank remains selected
 *       addr is the PPU address to poll and data is the expected byte
 * Post: Stops when nes_ppu_rd(addr) equals data or the read limit is reached
 *       no program command, retry or flash reset is issued here
 * Rtn:  Last PPU byte read at addr; a mismatch indicates polling failure
 */
uint8_t chrrom_wr_polling(uint16_t addr, uint8_t data)
{
  uint8_t rv;
  uint16_t timeout = 0xffff;

  do {
    usbPoll(); // orignal kazzo needs this frequently to slurp up incoming data
    rv = nes_ppu_rd(addr);
    if(rv == data) {
      break;
    }
  } while(--timeout);

  return rv;
}

/* Desc: NES RNBW PRG-ROM FLASH Write
 * Pre:  nes_init() setup of I/O pins
 *       mapper and flash configured for this command sequence and target bank
 * Post: Write attempted; prgrom_wr_polling polls the CPU bus with usbPoll
 *       polling stops on matching data or after at most 0xFFFF reads
 * Rtn:  Last CPU byte read at addr by prgrom_wr_polling
 *       compare with data to detect polling failure
 */
uint8_t rnbw_prgrom_flash_wr(uint16_t addr, uint8_t data)
{
  // write data
  nes_cpu_wr(0x8AAA, 0xAA);
  nes_cpu_wr(0x8555, 0x55);
  nes_cpu_wr(0x8AAA, 0xA0);
  nes_cpu_wr(addr, data);

  return prgrom_wr_polling(addr, data);
}

/* Desc: NES PRG-ROM FLASH Write in unlock bypass mode
 * Pre:  nes_init() setup of I/O pins
 *       mapper and flash configured for this command sequence and target bank
 *       Flash must already be in unlock bypass mode
 * Post: Write attempted; prgrom_wr_polling polls the CPU bus with usbPoll
 *       polling stops on matching data or after at most 0xFFFF reads
 * Rtn:  Last CPU byte read at addr by prgrom_wr_polling
 *       compare with data to detect polling failure
 */
uint8_t prgrom_flash_unlock_wr(uint16_t addr, uint8_t data)
{
  // needs to be in unlock bypass mode
  // write data
  nes_cpu_wr(addr, 0xA0);
  nes_cpu_wr(addr, data);

  return prgrom_wr_polling(addr, data);
}

/* Desc: NES RNBW CHR-ROM FLASH Write
 * Pre:  nes_init() setup of I/O pins
 *       mapper and flash configured for this command sequence and target bank
 * Post: Write attempted; chrrom_wr_polling polls the PPU bus with usbPoll
 *       polling stops on matching data or after at most 0xFFFF reads
 * Rtn:  Last PPU byte read at addr by chrrom_wr_polling
 *       compare with data to detect polling failure
 */
uint8_t rnbw_chrrom_flash_wr(uint16_t addr, uint8_t data)
{
  // send unlock command and write byte
  nes_ppu_wr(0x0AAA, 0xAA);
  nes_ppu_wr(0x0555, 0x55);
  nes_ppu_wr(0x0AAA, 0xA0);
  nes_ppu_wr(addr, data);

  return chrrom_wr_polling(addr, data);
}

/* Desc: NES CHR-ROM FLASH Write in unlock bypass mode
 * Pre:  nes_init() setup of I/O pins
 *       mapper and flash configured for this command sequence and target bank
 *       Flash must already be in unlock bypass mode
 * Post: Write attempted; chrrom_wr_polling polls the PPU bus with usbPoll
 *       polling stops on matching data or after at most 0xFFFF reads
 * Rtn:  Last PPU byte read at addr by chrrom_wr_polling
 *       compare with data to detect polling failure
 */
uint8_t chrrom_flash_unlock_wr(uint16_t addr, uint8_t data)
{
  // needs to be in unlock bypass mode
  // write data
  nes_ppu_wr(addr, 0xA0); // unlock bypass
  nes_ppu_wr(addr, data);

  return chrrom_wr_polling(addr, data);
}

/* Desc: NES VRC6 PRG-ROM FLASH Write
 * Pre:  nes_init() setup of I/O pins
 *       mapper and flash configured for this command sequence and target bank
 * Post: Write attempted; prgrom_wr_polling polls the CPU bus with usbPoll
 *       polling stops on matching data or after at most 0xFFFF reads
 * Rtn:  Last CPU byte read at addr by prgrom_wr_polling
 *       compare with data to detect polling failure
 */
uint8_t vrc6_prgrom_flash_wr(uint16_t addr, uint8_t data)
{
  // unlock the flash
  nes_cpu_wr(0xD555, 0xAA);
  nes_cpu_wr(0xAAAA, 0x55);
  nes_cpu_wr(0xD555, 0xA0);

  // write the data
  nes_cpu_wr(addr, data);

  return prgrom_wr_polling(addr, data);
}

/* Desc: NES DUALPORT PPU page read with optional USB polling
 *       enable the dual-port data path; PPU /A13 is not decoded
 *       read len + 1 bytes from page offset first into data[0..len]
 *       call usbPoll for each byte when poll is nonzero
 * Pre:  nes_init() setup of I/O pins
 *       desired bank selected and data has room for len + 1 bytes
 *       len must be below 255: the 8-bit loop counter wraps at 255
 *       first + len must be at most 255 to stay within the page
 * Post: CHR /RD high, M2 low and /ROMSEL high
 *       address low byte advanced past the last read (wraps within the page)
 *       data[0..len] filled; data bus remains input
 * Rtn:  Number of bytes read (len + 1)
 */
uint8_t nes_dualport_page_rd_poll(uint8_t* data, uint8_t addrH, uint8_t first, uint8_t len, uint8_t poll)
{
  uint8_t i;

  // ignore /A13, board doesn't see it anyway
  ADDRH(addrH);

  // now that data bus is no longer needed,
  // can enable data path out of cart
  M2_HI();
  ROMSEL_LO();

  // set CHR /RD and /WR
  CSRD_LO();

  // set lower address bits
  ADDRL(first); // doing this prior to entry and right after latching
  NOP();        // adding extra NOP as it was needed on PRG
                // gives longest delay between address out and latching data

  for(i = 0; i <= len; i++) {
    // couple more NOP's waiting for data
    if(poll == FALSE) {
      NOP(); // one prob good enough considering the if/else
      NOP();
    } else {
      usbPoll();
    }
    // latch data
    DATA_RD(data[i]);
    // set lower address bits
    first++;
    ADDRL(first);
  }

  // return bus to default
  CSRD_HI();
  M2_LO();
  ROMSEL_HI();

  // return index of last byte read
  return i;
}

/* Desc: NES MMC1 Mapper Register Write
 *       write to entirety of MMC1 register
 *       address selects register that's written to
 *       address must be >= $8000 where registers are located
 * Pre:  nes_init() setup of I/O pins
 *       MMC1 shift register has been reset by writing with D7 set
 *       bit7 must be clear, else the shift register will be reset
 * Post: MMC1 register contains the low five bits of data
 *       address left on bus
 *       data bus returned to input
 * Rtn:  None
 */
void mmc1_wr(uint16_t addr, uint8_t data, uint8_t reset)
{
  uint8_t i;

  // reset shift register if requested
  if(reset) {
    nes_cpu_rd(0x8000);
    nes_cpu_wr(0x8000, 0x80);
  }

  // 5 bits in register D0-4, so 5 total writes through D0
  for(i = 0; i < 5; i++) {
    // MMC1 ignores all but the first write, so perform a read first
    nes_cpu_rd(addr);
    nes_cpu_wr(addr, data);
    data = data >> 1;
  }

  return;
}

/* Desc: NES NROM PRG-ROM FLASH Write
 *       Also used for discrete mappers with 32KB banking (CNROM, BxROM, etc)
 * Pre:  nes_init() setup of I/O pins
 * Post: Write attempted; prgrom_wr_polling polls the CPU bus with usbPoll
 *       polling stops on matching data or after at most 0xFFFF reads
 * Rtn:  Last CPU byte read at addr by prgrom_wr_polling
 *       compare with data to detect polling failure
 */
uint8_t nrom_prgrom_flash_wr(uint16_t addr, uint8_t data)
{
  // unlock and write data
  discrete_exp0_prgrom_wr(0x5555, 0xAA);
  discrete_exp0_prgrom_wr(0x2AAA, 0x55);
  discrete_exp0_prgrom_wr(0x5555, 0xA0);
  discrete_exp0_prgrom_wr(addr, data);

  return prgrom_wr_polling(addr, data);
}

/* Desc: NES NROM CHR-ROM FLASH Write
 * Pre:  nes_init() setup of I/O pins
 * Post: Write attempted; chrrom_wr_polling polls the PPU bus with usbPoll
 *       polling stops on matching data or after at most 0xFFFF reads
 * Rtn:  Last PPU byte read at addr by chrrom_wr_polling
 *       compare with data to detect polling failure
 */
uint8_t nrom_chrrom_flash_wr(uint16_t addr, uint8_t data)
{
  // unlock and write data
  nes_ppu_wr(0x1555, 0xAA);
  nes_ppu_wr(0x0AAA, 0x55);
  nes_ppu_wr(0x1555, 0xA0);
  nes_ppu_wr(addr, data);

  return chrrom_wr_polling(addr, data);
}

/* Desc: NES MMC1 PRG-ROM FLASH Write
 * Pre:  nes_init() setup of I/O pins
 *       mapper and flash configured for this command sequence and target bank
 *       MMC1 must be properly initialized for flashing
 *       32KB mode with current bank selected
 *       addr must be between $8000-FFFF as prescribed by init
 *       cur_bank selects the CHR-register bits used for PRG A18
 * Post: Write attempted; prgrom_wr_polling polls the CPU bus with usbPoll
 *       polling stops on matching data or after at most 0xFFFF reads
 * Rtn:  Last CPU byte read at addr by prgrom_wr_polling
 *       compare with data to detect polling failure
 */
uint8_t mmc1_prgrom_flash_wr(uint16_t addr, uint8_t data)
{
  // make a generic write to mapper reg so the last write will block all subsequent writes
  // mmc1_wr(0xC000, 0x05, 0); //just write to random CHR ROM register

  // set CHR A16 to control PRG-ROM A18 if flashing more than 256K
  if(cur_bank < 8) {
    mmc1_wr(0xA000, 0x00, 0);
    mmc1_wr(0xC000, 0x00, 0);
  } else {
    mmc1_wr(0xA000, 0x10, 0);
    mmc1_wr(0xC000, 0x10, 0);
  }

  // all these writes will be blocked by MMC1 mapper register due to valid write above that ends with a write
  // unlock the flash
  nes_cpu_wr(0xD555, 0xAA);
  nes_cpu_wr(0xAAAA, 0x55);
  nes_cpu_wr(0xD555, 0xA0);

  // write the data
  nes_cpu_wr(addr, data);

  return prgrom_wr_polling(addr, data);
}

/* Desc: NES MMC1 CHR-ROM FLASH Write
 * Pre:  nes_init() setup of I/O pins
 *       mapper and flash configured for this command sequence and target bank
 *       cur_bank global var must be set to desired mapper register value
 *       CHR banking must map the unlock addresses as required by the board
 * Post: Write attempted; chrrom_wr_polling polls the PPU bus with usbPoll
 *       polling stops on matching data or after at most 0xFFFF reads
 *       CHR bank register at 0xA000 left at cur_bank
 * Rtn:  Last PPU byte read at addr by chrrom_wr_polling
 *       compare with data to detect polling failure
 */
uint8_t mmc1_chrrom_flash_wr(uint16_t addr, uint8_t data)
{
  // set banks for unlock commands
  mmc1_wr(0xA000, 0x02, 0);
  // PT1 always set to 0x05 for $5555 command

  // send unlock command
  nes_ppu_wr(0x1555, 0xAA);
  nes_ppu_wr(0x0AAA, 0x55);
  nes_ppu_wr(0x1555, 0xA0);

  // select desired bank for write
  mmc1_wr(0xA000, cur_bank, 0);
  // write the data
  nes_ppu_wr(addr, data);

  return chrrom_wr_polling(addr, data);
}

/* Desc: NES UNROM PRG-ROM FLASH Write
 * Pre:  nes_init() setup of I/O pins
 *       mapper and flash configured for this command sequence and target bank
 *       cur_bank global var must be set to desired mapper register value
 *       bank_table global var must be set to base address of the bank table
 * Post: Write attempted; prgrom_wr_polling polls the CPU bus with usbPoll
 *       polling stops on matching data or after at most 0xFFFF reads
 *       mapper bank register left at cur_bank
 * Rtn:  Last CPU byte read at addr by prgrom_wr_polling
 *       compare with data to detect polling failure
 */
uint8_t unrom_prgrom_flash_wr(uint16_t addr, uint8_t data)
{
  // set A14 low for lower bank so to satisfy unlock commands
  nes_cpu_wr(bank_table, 0x00);

  // unlock the flash
  discrete_exp0_prgrom_wr(0x5555, 0xAA);
  discrete_exp0_prgrom_wr(0x2AAA, 0x55);
  discrete_exp0_prgrom_wr(0x5555, 0xA0);

  // select desired bank and write data
  nes_cpu_wr(bank_table + cur_bank, cur_bank);
  discrete_exp0_prgrom_wr(addr, data);

  return prgrom_wr_polling(addr, data);
}

/* Desc: NES CNROM CHR-ROM FLASH Write
 * Pre:  nes_init() setup of I/O pins
 *       mapper and flash configured for this command sequence and target bank
 *       cur_bank global var must be set to desired mapper register value
 *       bank_table global var must be set to base address of the bank table
 * Post: Write attempted; chrrom_wr_polling polls the PPU bus with usbPoll
 *       polling stops on matching data or after at most 0xFFFF reads
 *       mapper bank register left at cur_bank
 * Rtn:  Last PPU byte read at addr by chrrom_wr_polling
 *       compare with data to detect polling failure
 */
uint8_t cnrom_chrrom_flash_wr(uint16_t addr, uint8_t data)
{
  // unlock the flash
  nes_cpu_wr(bank_table + 2, 0x02);
  nes_ppu_wr(0x1555, 0xAA);

  nes_cpu_wr(bank_table + 1, 0x01);
  nes_ppu_wr(0x0AAA, 0x55);

  nes_cpu_wr(bank_table + 2, 0x02);
  nes_ppu_wr(0x1555, 0xA0);

  // select desired bank for the write
  nes_cpu_wr(bank_table + cur_bank, cur_bank);
  // write the byte
  nes_ppu_wr(addr, data);

  return chrrom_wr_polling(addr, data);
}

/* Desc: NES MMC3 PRG-ROM FLASH Write
 * Pre:  nes_init() setup of I/O pins
 *       mapper and flash configured for this command sequence and target bank
 *       MMC3 must be properly initialized for flashing
 *       addr must be between $8000-9FFF as prescribed by init
 * Post: Write attempted; prgrom_wr_polling polls the CPU bus with usbPoll
 *       polling stops on matching data or after at most 0xFFFF reads
 *       bank select register at 0x8000 left at 0x02
 * Rtn:  Last CPU byte read at addr by prgrom_wr_polling
 *       compare with data to detect polling failure
 */
uint8_t mmc3_prgrom_flash_wr(uint16_t addr, uint8_t data)
{
  // unlock the flash
  nes_cpu_wr(0xD555, 0xAA);
  nes_cpu_wr(0xAAAA, 0x55);
  nes_cpu_wr(0xD555, 0xA0);

  // write the data
  nes_cpu_wr(addr, data);

  // reset $8000 bank select register to a CHR reg
  nes_cpu_wr(0x8000, 0x02); // 0x02 also maintains flash mode for custom

  return prgrom_wr_polling(addr, data);
}

/* Desc: NES MMC3 CHR-ROM FLASH Write
 * Pre:  nes_init() setup of I/O pins
 *       mapper and flash configured for this command sequence and target bank
 *       MMC3 must be properly initialized for flashing
 *       addr must be between $0000-0FFF as prescribed by init
 * Post: Write attempted; chrrom_wr_polling polls the PPU bus with usbPoll
 *       polling stops on matching data or after at most 0xFFFF reads
 * Rtn:  Last PPU byte read at addr by chrrom_wr_polling
 *       compare with data to detect polling failure
 */
uint8_t mmc3_chrrom_flash_wr(uint16_t addr, uint8_t data)
{
  // unlock and write data
  nes_ppu_wr(0x1555, 0xAA);
  nes_ppu_wr(0x1AAA, 0x55);
  nes_ppu_wr(0x1555, 0xA0);
  nes_ppu_wr(addr, data);

  return chrrom_wr_polling(addr, data);
}

/* Desc: NES MMC4 PRG-ROM FLASH Write for standard PLCC SST flash
 * Pre:  nes_init() setup of I/O pins
 *       mapper and flash configured for this command sequence and target bank
 *       MMC4 must be properly initialized for flashing
 *       addr must be between $8000-BFFF as prescribed by init
 *       desired bank must already be selected
 *       cur_bank must be set to desired bank for recovery
 * Post: Write attempted; prgrom_wr_polling polls the CPU bus with usbPoll
 *       polling stops on matching data or after at most 0xFFFF reads
 *       PRG bank register at 0xA000 restored to cur_bank
 * Rtn:  Last CPU byte read at addr by prgrom_wr_polling
 *       compare with data to detect polling failure
 */
uint8_t mmc4_prgrom_flash_wr(uint16_t addr, uint8_t data)
{
  // unlock and write data PLCC flash
  nes_cpu_wr(0xD555, 0xAA);
  nes_cpu_wr(0xEAAA, 0x55);
  nes_cpu_wr(0xD555, 0xA0);
  nes_cpu_wr(addr, data); // corrupts bank register if addr $A000-AFFF

  // recover bank register as data write would have corrupted
  nes_cpu_wr(0xA000, cur_bank);

  return prgrom_wr_polling(addr, data);
}

/* Desc: NES MMC4 CHR-ROM FLASH Write
 * Pre:  nes_init() setup of I/O pins
 *       mapper and flash configured for this command sequence and target bank
 *       cur_bank global var must be set to desired mapper register value
 * Post: Write attempted; chrrom_wr_polling polls the PPU bus with usbPoll
 *       polling stops on matching data or after at most 0xFFFF reads
 *       CHR bank registers at 0xB000 and 0xC000 left at cur_bank
 * Rtn:  Last PPU byte read at addr by chrrom_wr_polling
 *       compare with data to detect polling failure
 */
uint8_t mmc4_chrrom_flash_wr(uint16_t addr, uint8_t data)
{
  //--set bank for unlock command
  // dict.nes("NES_CPU_WR", 0xB000, 0x0A)    --4KB @ PPU $0000 -> $2AAA cmd & writes
  // dict.nes("NES_CPU_WR", 0xC000, 0x0A)    --4KB @ PPU $0000
  //
  //--send unlock command
  // dict.nes("NES_PPU_WR", 0x1555, 0xAA)
  // dict.nes("NES_PPU_WR", 0x0AAA, 0x55)
  // dict.nes("NES_PPU_WR", 0x1555, 0xA0)
  //
  //--select desired bank
  // dict.nes("NES_CPU_WR", 0xB000, bank)    --4KB @ PPU $0000 -> $2AAA cmd & writes
  // dict.nes("NES_CPU_WR", 0xC000, bank)    --4KB @ PPU $0000
  //--write data
  // dict.nes("NES_PPU_WR", addr, value)

  // set banks for unlock commands
  nes_cpu_wr(0xB000, 0x0A);
  nes_cpu_wr(0xC000, 0x0A);

  // PT1 always set to 0x05 for $5555 command

  // send unlock command
  nes_ppu_wr(0x1555, 0xAA);
  nes_ppu_wr(0x0AAA, 0x55);
  nes_ppu_wr(0x1555, 0xA0);

  // select desired bank for write
  nes_cpu_wr(0xB000, cur_bank);
  nes_cpu_wr(0xC000, cur_bank);

  // write the data
  nes_ppu_wr(addr, data);

  return chrrom_wr_polling(addr, data);
}

/* Desc: NES ColorDreams CHR-ROM FLASH Write
 * Pre:  nes_init() setup of I/O pins
 *       mapper and flash configured for this command sequence and target bank
 *       cur_bank global var must be set to desired mapper register value
 *       bank_table global var must be set to base address of the bank table
 *       The first PRG-ROM bank must be selected and bank table present
 *       num_prg_banks must match the bank table layout
 * Post: Write attempted; chrrom_wr_polling polls the PPU bus with usbPoll
 *       polling stops on matching data or after at most 0xFFFF reads
 * Rtn:  Last PPU byte read at addr by chrrom_wr_polling
 *       compare with data to detect polling failure
 */
uint8_t cdream_chrrom_flash_wr(uint16_t addr, uint8_t data)
{
  // uint8_t num_prg_banks = 16; // 4: 128KB, 8: 256KB, 16: 512KB

  // select first bank
  // nes_cpu_wr(0xFF9E, 0);

  // unlock the flash
  // nes_cpu_wr(bank_table+0x20, 0x20); //this assumes a 256Byte bank table!
  // nes_cpu_wr(bank_table+0x08, 0x20); //this assumes a 128KB PRG-ROM banktable!
  //  00 01 02 03 - 10 11 12 13 - 20 21 22 23 - ...
  nes_cpu_wr(bank_table + (num_prg_banks * 2), 0x20); // need the #2 CHR-ROM bank
  nes_ppu_wr(0x1555, 0xAA);

  // nes_cpu_wr(bank_table+0x10, 0x10);
  nes_cpu_wr(bank_table + (num_prg_banks * 1), 0x10);
  nes_ppu_wr(0x0AAA, 0x55);

  // nes_cpu_wr(bank_table+0x20, 0x20);
  nes_cpu_wr(bank_table + (num_prg_banks * 2), 0x20);
  nes_ppu_wr(0x1555, 0xA0);

  // select desired bank for the write
  nes_cpu_wr(bank_table + (num_prg_banks * cur_bank), (cur_bank << 4));
  // write the byte
  nes_ppu_wr(addr, data);

  return chrrom_wr_polling(addr, data);
}

/* Desc: NES MAPPER30 PRG-ROM FLASH Write
 * Pre:  nes_init() setup of I/O pins
 *       mapper and flash configured for this command sequence and target bank
 *       cur_bank global var must be set to desired mapper register value
 * Post: Write attempted; prgrom_wr_polling polls the CPU bus with usbPoll
 *       polling stops on matching data or after at most 0xFFFF reads
 *       mapper bank register left at cur_bank
 * Rtn:  Last CPU byte read at addr by prgrom_wr_polling
 *       compare with data to detect polling failure
 */
uint8_t map30_prgrom_flash_wr(uint16_t addr, uint8_t data)
{
  // unlock the flash
  nes_cpu_wr(0xC000, 0x01);
  nes_cpu_wr(0x9555, 0xAA);
  nes_cpu_wr(0xC000, 0x00);
  nes_cpu_wr(0xAAAA, 0x55);
  nes_cpu_wr(0xC000, 0x01);
  nes_cpu_wr(0x9555, 0xA0);

  // select desired bank and write data
  nes_cpu_wr(0xC000, cur_bank);
  nes_cpu_wr(addr, data);

  return prgrom_wr_polling(addr, data);
}

/* Desc: NES GTROM (mapper 111) PRG-ROM FLASH Write
 * Pre:  nes_init() setup of I/O pins
 *       mapper and flash configured for this command sequence and target bank
 *       cur_bank must contain the desired mapper register value
 * Post: Write attempted; prgrom_wr_polling polls the CPU bus with usbPoll
 *       polling stops on matching data or after at most 0xFFFF reads
 *       mapper bank register left at cur_bank
 * Rtn:  Last CPU byte read at addr by prgrom_wr_polling
 *       compare with data to detect polling failure
 */
uint8_t gtrom_prgrom_flash_wr(uint16_t addr, uint8_t data)
{
  // select bank, don't think needed, but having problems...
  nes_cpu_wr(0x5000, cur_bank);

  // unlock the flash
  nes_cpu_wr(0xD555, 0xAA);
  nes_cpu_wr(0xAAAA, 0x55);
  nes_cpu_wr(0xD555, 0xA0);

  // write the data
  nes_cpu_wr(addr, data);

  // nes_cpu_wr(0x5000, cur_bank);

  return prgrom_wr_polling(addr, data);
}

/* Desc: NES ACTION53 using SST 512K PRG-ROM FLASH Write
 * Pre:  nes_init() setup of I/O pins
 *       mapper and flash configured for this command sequence and target bank
 * Post: Write attempted; prgrom_wr_polling polls the CPU bus with usbPoll
 *       polling stops on matching data or after at most 0xFFFF reads
 *       an extra read at 0x8000 follows a write to 0xFFFC
 * Rtn:  Last CPU byte read at addr by prgrom_wr_polling
 *       compare with data to detect polling failure
 */
uint8_t a53_512k_prgrom_flash_wr(uint16_t addr, uint8_t data)
{
  uint8_t rv;

  // unlock and write data
  nes_m2_high_wr(0xD555, 0xAA);
  nes_m2_high_wr(0xAAAA, 0x55);
  nes_m2_high_wr(0xD555, 0xA0);
  nes_m2_high_wr(addr, data);

  rv = prgrom_wr_polling(addr, data);

  if(addr == 0xFFFC) {
    nes_cpu_rd(0x8000); // prevent resetting mapper config
  }

  return rv;
}

/* Desc: NES ACTION53 TSSOP PRG-ROM FLASH Write
 * Pre:  nes_init() setup of I/O pins
 *       mapper and flash configured for this command sequence and target bank
 *       Flash must already be in unlock bypass mode
 * Post: Write attempted; prgrom_wr_polling polls the CPU bus with usbPoll
 *       polling stops on matching data or after at most 0xFFFF reads
 * Rtn:  Last CPU byte read at addr by prgrom_wr_polling
 *       compare with data to detect polling failure
 */
uint8_t a53_tssop_prgrom_flash_wr(uint16_t addr, uint8_t data)
{
  // chr reg select act like CNROM & enable flash writes
  // nes_cpu_wr(0x5000, 0x54);

  // needs to be in unlock bypass mode
  // write data
  nes_m2_high_wr(addr, 0xA0);
  nes_m2_high_wr(addr, data);

  return prgrom_wr_polling(addr, data);
}

/* Desc: NES ACTION53 TSSOP PRG-ROM FLASH Write
 * Pre:  nes_init() setup of I/O pins
 *       mapper and flash configured for this command sequence and target bank
 * Post: Write attempted; prgrom_wr_polling polls the CPU bus with usbPoll
 *       polling stops on matching data or after at most 0xFFFF reads
 * Rtn:  Last CPU byte read at addr by prgrom_wr_polling
 *       compare with data to detect polling failure
 */
uint8_t a53_prgrom_flash_wr(uint16_t addr, uint8_t data)
{
  // write data
  nes_cpu_wr(0x8AAA, 0xAA);
  nes_cpu_wr(0x8555, 0x55);
  nes_cpu_wr(0x8AAA, 0xA0);
  nes_cpu_wr(addr, data);

  return prgrom_wr_polling(addr, data);
}

/* Desc: NES TSSOP PRG-ROM FLASH Write
 * Pre:  nes_init() setup of I/O pins
 *       mapper and flash configured for this command sequence and target bank
 *       Flash must already be in unlock bypass mode
 * Post: Write attempted; prgrom_wr_polling polls the CPU bus with usbPoll
 *       polling stops on matching data or after at most 0xFFFF reads
 * Rtn:  Last CPU byte read at addr by prgrom_wr_polling
 *       compare with data to detect polling failure
 */
uint8_t tssop_prgrom_flash_wr(uint16_t addr, uint8_t data)
{
  // unlock and write data
  nes_m2_high_wr(addr, 0xA0);
  nes_m2_high_wr(addr, data);

  return prgrom_wr_polling(addr, data);
}

// uint8_t mmc5_prgram_wr(uint16_t addr, uint8_t data)
// {
//   nes_cpu_wr(0x5102, 0x02); // PRG-RAM protect 1
//   nes_cpu_wr(0x5103, 0x01); // PRG-RAM protect 2
//   nes_cpu_wr(0x5102, 0x02); // need an additional M2 cycling, may as well be a write to a prot reg
//   // if there is an interrupt durring this time the write could fail if >11.2usec
//   nes_cpu_wr(addr, data);

// return nes_cpu_rd(addr);
//}

#endif // NES_CONN
