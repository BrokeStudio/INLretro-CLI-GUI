#include "sega.h"

// only need this file if connector is present on the device
#ifdef SEGA_CONN

// #define LOMEM_TIME_MASK 0x84
#define LOMEM_MASK 0x04 // B26 /ASEL
#define TIME_MASK 0x80  // B31 /TIME
#define SEGA_A19_MASK 0x04

// uint16_t sega_bank = 0;
uint8_t sega_addr_hi = 0;  // A23-A16
uint16_t sega_addr_lo = 0; //  A15-A0

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

  switch (opcode)
  {

  case GEN_SET_ADDR_LO:
    gen_set_addr_lo(operand);
    break;

  case GEN_SET_ADDR_HI:
    gen_set_addr_hi(operand & 0xff);
    break;

  case GEN_SET_ADDR:
    sega_addr_hi = miscdata;
    sega_addr_lo = operand;
    gen_refresh_addr(0);
    break;

  case GEN_ROM_RD:
    // address high bits must be set before calling GEN_ROM_RD,
    // using GEN_SET_ADDR_HI
    rdata[RD_LEN] = HWORD_LEN;
    temp = gen_rom_rd(operand);
    rdata[RD0] = temp;
    rdata[RD1] = temp >> 8;
    break;

  case GEN_ROM_WR:
    // address must be set before calling GEN_ROM_WR,
    // using GEN_SET_ADDR_HI and GEN_SET_ADDR_LO, or GEN_SET_ADDR
    gen_rom_wr(sega_addr_lo, operand);
    break;

  case GEN_RAM_RD:
    rdata[RD_LEN] = BYTE_LEN;
    rdata[RD0] = gen_ram_rd(operand);
    break;

  case GEN_RAM_WR:
    gen_ram_wr(operand, miscdata);
    break;

  case GEN_PAGE_RAM_WR_LFSR:
    gen_ram_page_wr_lfsr(operand, miscdata);
    break;

  case GEN_TIME_RD:
    rdata[RD_LEN] = BYTE_LEN;
    rdata[RD0] = gen_time_rd(operand);
    break;

  case GEN_TIME_WR:
    gen_time_wr(operand, miscdata);
    break;

  default:
    // opcode doesn't exist
    return ERR_UNKN_SEGA_OPCODE;
  }

  return SUCCESS;
}

void gen_refresh_addr(uint8_t force_set_time)
{
  // TODO decode #TIME & #LO_MEM
  uint32_t addr = ((uint32_t)sega_addr_hi << 16) | sega_addr_lo; // A23-A0
  uint8_t addr_hi = (addr >> 17) & 0x7f;                         // A23-A17
  uint16_t addr_lo = (addr >> 1) & 0xffff;                       // A16-A1

  uint8_t time;
  if (force_set_time)
    time = TIME_MASK;
  else
    time = (addr >= 0xA13000 && addr <= 0xA130FF) ? 0 : TIME_MASK;

  // TIME (B31), A23-A20, LOMEM (B26/set), A18-A17
  FFADDR_SET(time | (addr_hi & 0x78) | LOMEM_MASK | (addr_hi & 0x03));

  // A19
  if (addr_hi & SEGA_A19_MASK)
  {
    GEN_A19_HI();
  }
  else
  {
    GEN_A19_LO();
  }
  // use of flip-flop corrupts A16-A1, restore it
  ADDR_SET(addr_lo);
}

uint8_t gen_get_addr_hi(void)
{
  return sega_addr_hi;
}

void gen_set_addr_hi(uint8_t addr_hi) // A23-A16
{
  sega_addr_hi = addr_hi;
  gen_refresh_addr(0);
}

void gen_set_addr_lo(uint16_t addr_lo) // A15-A0
{
  sega_addr_lo = addr_lo;
  gen_refresh_addr(0);
}

uint16_t gen_rom_rd(uint16_t addr_lo)
{
  uint16_t rv;
  uint8_t temp;

  // set address low bits
  gen_set_addr_lo(addr_lo);

  // set data bus as input
  DATA16_IP();

  // set #WE/#LDSW
  GEN_LDSW_HI();

  // set #WE/#UDSW
  GEN_UDSW_HI();

  // clear #C_CE
  GEN_C_CE_LO();

  // clear #C_OE
  GEN_C_OE_LO();

  NOP();
  NOP();
  NOP(); // 3 NOPs needed

  DATA16L_RD(rv);
  DATA16H_RD(temp);
  rv |= temp << 8;

  // set #C_OE
  GEN_C_OE_HI();

  // set #C_CE
  GEN_C_CE_HI();

  return rv;
}

void gen_rom_wr(uint16_t addr_lo, uint16_t data)
{
  uint8_t temp = data;

  // set address
  gen_set_addr_lo(addr_lo);

  uint32_t addr = ((uint32_t)sega_addr_hi << 16) | sega_addr_lo; // A23-A0
  uint8_t time = (addr >= 0xA13000 && addr <= 0xA130FF) ? TIME_MASK : 0;

  // put data on bus
  DATA16_OP();
  DATA16L_SET(data);
  data = data >> 8;
  DATA16H_SET(data); // put 8bits of data on high byte

  // clear #AS B18 CPU access entire memory map, indicating address bus valid
  GBP_LO();

  if (!time)
  {
    // clear #C_CE
    GEN_C_CE_LO();
  }

  // set #C_OE
  GEN_C_OE_HI();

  // clear #WE/#LDSW B28 CPU D7-D0 data strobe
  GEN_LDSW_LO();

  // clear #WE/#UDSW B29 CPU D15-D8 data strobe
  GEN_UDSW_LO();

  NOP();
  NOP();
  NOP(); // 3 NOPs needed

  // set #WE/#UDSW
  GEN_UDSW_HI();

  // set #WE/#LDSW
  GEN_LDSW_HI();

  // set #C_CE
  GEN_C_CE_HI();

  // set #AS B18 CPU access entire memory map, indicating address bus valid
  GBP_HI();

  if (time)
  {
    gen_refresh_addr(1);
  }

  // Free data bus
  DATA16_IP();
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
uint8_t gen_rom_page_rd(uint8_t *data, uint16_t addrH, uint8_t first, uint8_t len)
{
  uint8_t i;
  uint16_t cur_addr;

  uint16_t address = first >> 1;
  address = (addrH << 7) | address;
  cur_addr = address;

  // set data bus as input
  DATA16_IP();

  // set address
  ADDR_SET(cur_addr);

  // set #WE/#LDSW
  GEN_LDSW_HI();

  // set #WE/#UDSW
  GEN_UDSW_HI();

  // clear #AS B18 CPU access entire memory map, indicating address bus valid
  GBP_LO();

  // clear #C_CE
  GEN_C_CE_LO();

  for (i = 0; i <= len; i++)
  {

    // /OE needs to toggle in the for loop for the ssf2/rainbow mapper

    // clear #C_OE
    GEN_C_OE_LO();

    NOP();
    NOP();
    NOP(); // 3 NOPs needed

    DATA16H_RD(data[i]);
    i++;
    DATA16L_RD(data[i]);

    // set #C_OE
    GEN_C_OE_HI();

    // set lower address bits
    // ADDRL(++cur_addr); THIS broke things, on stm adapter because macro expands it twice!
    cur_addr++;
    ADDRL(cur_addr);
  }

  // set #C_CE
  GEN_C_CE_HI();

  // set #AS B18 CPU access entire memory map, indicating address bus valid
  GBP_HI();

  // return index of last byte read
  return i;
}

uint16_t gen_sst_flash_wr(uint16_t addr_lo, uint16_t data)
{
  uint16_t read;
  uint16_t timeout = 0xFFFF;

  gen_rom_wr(0x0555 << 1, 0x00AA);
  gen_rom_wr(0x02AA << 1, 0x0055);
  gen_rom_wr(0x0555 << 1, 0x00A0);
  gen_rom_wr(addr_lo, data);

  do
  {
    read = gen_rom_rd(addr_lo);
    if (read == data)
    {
      break;
    }
  } while (--timeout);

  return read;
}

uint8_t gen_time_rd(uint16_t addr_lo)
{
  uint16_t rv;
  uint8_t temp;

  // set data bus as input
  DATA16_IP();

  // clear address high bits, clear #TIME signal, set #LOMEM
  // set address low bits
  FFADDR_SET(LOMEM_MASK);
  ADDR_SET(addr_lo);

  // set #WE/#LDSW
  GEN_LDSW_HI();

  // set #WE/#UDSW
  GEN_UDSW_HI();

  // set #C_CE
  GEN_C_CE_HI();

  // clear #AS B18 CPU access entire memory map, indicating address bus valid
  GBP_LO();

  // clear #C_OE
  GEN_C_OE_LO();

  NOP();
  NOP();
  NOP(); // 3 NOPs needed

  DATA16L_RD(rv);
  // DATA16H_RD(temp);
  // rv |= temp << 8;

  // set #C_OE
  GEN_C_OE_HI();

  // set #AS B18 CPU access entire memory map, indicating address bus valid
  GBP_HI();

  gen_refresh_addr(0);

  return rv;
}

void gen_time_wr(uint16_t addr_lo, uint8_t data)
{
  uint8_t temp;

  // set data bus as input
  DATA16_OP();
  DATA16L_SET(data);
  data = data >> 8;
  DATA16H_SET(data); // put 8bits of data on high byte

  // clear address high bits, clear #TIME signal, set #LOMEM
  FFADDR_SET(LOMEM_MASK);

  // set address low bits
  ADDR_SET(addr_lo >> 1);

  // clear #AS B18 CPU access entire memory map, indicating address bus valid
  GBP_LO();

  // clear #WE/#UDSW B29 CPU D15-D8 data strobe
  GEN_UDSW_LO();

  // clear #WE/#LDSW B28 CPU D7-D0 data strobe
  GEN_LDSW_LO();

  NOP();
  NOP();
  NOP(); // 3 NOPs needed

  // set #WE/#LDSW B28 CPU D7-D0 data strobe
  GEN_LDSW_HI();

  // set #WE/#UDSW B29 CPU D15-D8 data strobe
  GEN_UDSW_HI();

  // set #AS B18 CPU access entire memory map, indicating address bus valid
  GBP_HI();

  // clear address high bits, set #TIME signal, set #LOMEM
  FFADDR_SET(TIME_MASK | LOMEM_MASK);

  // Free data bus
  DATA16_IP();
}

uint8_t gen_ram_rd(uint16_t addr_lo)
{
  uint8_t read;

  // SRAM needs to be enabled and address hi bits set
  // before calling this function

  // set data bus as input
  DATA_IP();

  // set address
  gen_set_addr_lo(addr_lo);

  // clear #AS B18 CPU access entire memory map, indicating address bus valid
  GBP_LO();

  // set #WE/#LDSW
  GEN_LDSW_HI();

  // set #WE/#UDSW
  GEN_UDSW_HI();

  // clear #C_CE
  GEN_C_CE_LO();

  // clear #C_OE
  GEN_C_OE_LO();

  NOP();
  NOP();

  DATA_RD(read);

  // set #C_OE
  GEN_C_OE_HI();

  // set #C_CE
  GEN_C_CE_HI();

  // set #AS B18 CPU access entire memory map, indicating address bus valid
  GBP_HI();

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
  DATA_SET(data); // lower byte D7-D0

  // clear #AS B18 CPU access entire memory map, indicating address bus valid
  GBP_LO();

  // set #C_OE
  GEN_C_OE_HI();

  // set #WE/#UDSW
  GEN_UDSW_HI();

  // clear #C_CE
  GEN_C_CE_LO();

  // clear #WE/#LDSW B28 CPU D7-D0 data strobe
  GEN_LDSW_LO();

  NOP();
  NOP();

  // set #WE/#LDSW
  GEN_LDSW_HI();

  // set #C_CE
  GEN_C_CE_HI();

  // set #AS B18 CPU access entire memory map, indicating address bus valid
  GBP_HI();

  // Free data bus
  DATA_IP();
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
uint8_t gen_ram_page_rd(uint8_t *data, uint16_t addrH, uint8_t first, uint8_t len)
{
  uint8_t i;
  uint16_t cur_addr = first;

  // SRAM needs to be enabled and address hi bits set
  // before calling this function

  // set data bus as input
  DATA_IP();

  // set address high bits
  ADDRH(addrH);

  // set address low bits
  ADDRL(cur_addr);

  // clear #AS B18 CPU access entire memory map, indicating address bus valid
  GBP_LO();

  // set #WE/#LDSW
  GEN_LDSW_HI();

  // set #WE/#UDSW
  GEN_UDSW_HI();

  // clear #C_OE
  GEN_C_OE_LO();

  for (i = 0; i <= len; i++)
  {

    // clear #C_CE
    GEN_C_CE_LO();

    NOP();
    NOP();

    // latch data low byte
    DATA_RD(data[i]);

    // set #C_CE
    GEN_C_CE_HI();

    // set lower address bits
    // ADDRL(++cur_addr); THIS broke things, on stm adapter because macro expands it twice!
    cur_addr++;
    ADDRL(cur_addr);
  }

  // set #C_OE
  GEN_C_OE_HI();

  // set #AS B18 CPU access entire memory map, indicating address bus valid
  GBP_HI();

  // return index of last byte read
  return i;
}

void gen_ram_page_wr_lfsr(uint16_t addr, uint8_t size_kb)
{
  uint8_t data;
  uint16_t i;
  uint32_t size = size_kb * 1024;

  // SRAM needs to be enabled and bank set
  // before calling this function

  // set data bus as output
  DATA_OP();

  // set #WE/#UDSW
  GEN_UDSW_HI();

  // set #C_OE
  GEN_C_OE_HI();

  for (i = 0; i < size; i++)
  {
    ADDR_SET(addr);

    // clear #AS B18 CPU access entire memory map, indicating address bus valid
    GBP_LO();

    // put data on bus
    data = lfsr_32();
    DATA_SET(data); // lower byte D7-D0

    // clear #WE/#LDSW B28 CPU D7-D0 data strobe
    GEN_LDSW_LO();

    // clear #C_CE
    GEN_C_CE_LO();

    NOP();
    NOP();

    // set #C_CE
    GEN_C_CE_HI();

    // set #WE/#LDSW
    GEN_LDSW_HI();

    // set #AS B18 CPU access entire memory map, indicating address bus valid
    GBP_HI();

    // do some things that take time
    // data = lfsr_32();
    addr++;
  }

  // Free data bus
  DATA_IP();
}

#endif // SEGA_CONN
