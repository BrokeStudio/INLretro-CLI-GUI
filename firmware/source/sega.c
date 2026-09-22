#include "sega.h"

// only need this file if connector is present on the device
#ifdef SEGA_CONN

  // #define LOMEM_TIME_MASK 0x84
  #define LOMEM_MASK 0x04 // B26 /ASEL
  #define TIME_MASK 0x80  // B31 /TIME
  #define SEGA_A19_MASK 0x04

// uint16_t sega_bank = 0;
uint8_t sega_addr_hi = 0;  // A23-A16
uint16_t sega_addr_lo = 0; // A15-A0

//=================================================================================================
//
// SEGA operations
// This file includes all the sega functions possible to be called from the sega dictionary.
//
// See description of the commands contained here in shared/shared_dictionaries.h
//
//=================================================================================================

/* Desc: Dispatch a Sega dictionary opcode received over USB
 *       shared_dict_sega.h defines opcodes shared by host and firmware
 * Pre:  I/O and address state satisfy the selected operation requirements
 *       rdata has room for the response length and up to two data bytes
 * Post: Read operations set rdata[0] and the response bytes
 *       ROM words returned low byte first; writes leave rdata unchanged
 *       address commands update the cached address and apply it to the bus
 * Rtn:  SUCCESS for a recognized opcode
 *       ERR_UNKN_SEGA_OPCODE for an unsupported opcode
 */
uint8_t sega_call(uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t* rdata)
{
  #define RD_LEN 0
  #define RD0 1
  #define RD1 2

  #define BYTE_LEN 1
  #define HWORD_LEN 2

  uint16_t temp;

  switch(opcode) {
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
      // address must be set before calling GEN_ROM_WR,
      // using GEN_SET_ADDR_HI and GEN_SET_ADDR_LO, or GEN_SET_ADDR
      rdata[RD_LEN] = HWORD_LEN;
      temp = gen_rom_rd(sega_addr_lo);
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

/* Desc: Apply cached 24-bit byte address sega_addr_hi:sega_addr_lo to the bus
 *       shift by one to drive A23-A1; A0 is not a physical address output
 *       assert /TIME for 0xA13000-0xA130FF unless force_set_time is nonzero
 *       force_set_time forces /TIME high, not low
 *       hold /ASEL (LOMEM_MASK) high and drive A19 separately
 * Pre:  sega_init() setup of I/O pins
 *       cached address contains the desired byte address
 * Post: High address latch and A19 updated; A16-A1 restored after latch access
 *       cached address unchanged; /TIME reflects the requested decode
 * Rtn:  None
 */
void gen_refresh_addr(uint8_t force_set_time)
{
  // TODO decode #TIME & #LO_MEM
  uint32_t addr = ((uint32_t)sega_addr_hi << 16) | sega_addr_lo; // A23-A0
  uint8_t addr_hi = (addr >> 17) & 0x7f;                         // A23-A17
  uint16_t addr_lo = (addr >> 1) & 0xffff;                       // A16-A1

  uint8_t time;
  if(force_set_time) {
    time = TIME_MASK;
  } else {
    time = (addr >= 0xA13000 && addr <= 0xA130FF) ? 0 : TIME_MASK;
  }

  // TIME (B31), A23-A20, LOMEM (B26/set), A18-A17
  FFADDR_SET(time | (addr_hi & 0x78) | LOMEM_MASK | (addr_hi & 0x03));

  // A19
  if(addr_hi & SEGA_A19_MASK) {
    GEN_A19_HI();
  } else {
    GEN_A19_LO();
  }
  // use of flip-flop corrupts A16-A1, restore it
  ADDR_SET(addr_lo);
}

/* Desc: Return the cached high byte of the Genesis byte address
 * Pre:  None
 * Post: No hardware access or state change
 * Rtn:  sega_addr_hi, representing A23-A16
 */
uint8_t gen_get_addr_hi(void)
{
  return sega_addr_hi;
}

/* Desc: Set the cached high byte-address part (A23-A16)
 *       apply the full cached address through gen_refresh_addr(0)
 * Pre:  sega_init() setup of I/O pins
 *       the cached low address part already has the desired value
 * Post: Cached hi address updated and full address applied to the bus
 *       /TIME decoded from the full address; /ASEL held high
 * Rtn:  None
 */
void gen_set_addr_hi(uint8_t addr_hi) // A23-A16
{
  sega_addr_hi = addr_hi;
  gen_refresh_addr(0);
}

/* Desc: Set the cached low byte-address part (A15-A0)
 *       apply the full cached address through gen_refresh_addr(0)
 * Pre:  sega_init() setup of I/O pins
 *       the cached high address part already has the desired value
 * Post: Cached lo address updated and full address applied to the bus
 *       /TIME decoded from the full address; /ASEL held high
 * Rtn:  None
 */
void gen_set_addr_lo(uint16_t addr_lo) // A15-A0
{
  sega_addr_lo = addr_lo;
  gen_refresh_addr(0);
}

/* Desc: Read a 16-bit Genesis ROM word using the cached high byte address
 *       addr_lo contains A15-A0; physical address outputs omit A0
 * Pre:  sega_init() setup of I/O pins
 *       sega_addr_hi selected; addr_lo should be even for word accesses
 * Post: sega_addr_lo updated; target address left on bus
 *       16-bit data bus input; /C_OE, /C_CE, /LDSW and /UDSW high
 *       /TIME decoded by gen_set_addr_lo; /AS unchanged
 * Rtn:  16-bit word read at the selected address
 */
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

/* Desc: Write a 16-bit Genesis word using the cached high byte address
 *       drive both byte lanes and pulse /LDSW and /UDSW with /AS low
 *       assert /C_CE outside 0xA13000-0xA130FF; use /TIME inside that range
 * Pre:  sega_init() setup of I/O pins
 *       sega_addr_hi selected; addr_lo should be even for word accesses
 * Post: Write cycle issued without readback verification; sega_addr_lo updated
 *       16-bit data bus input; /AS, /C_CE, /C_OE, /LDSW and /UDSW high
 *       /TIME high after the access; cached high address unchanged
 * Rtn:  None
 */
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

  if(!time) {
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

  if(time) {
    gen_refresh_addr(1);
  }

  // Free data bus
  DATA16_IP();
}

/* Desc: Read Genesis ROM words into data, high byte then low byte
 *       initial physical A16-A1 is (addrH << 7) | (first >> 1)
 *       hold /AS and /C_CE low; toggle /C_OE per word for SSF2/Rainbow
 *       no USB polling is performed
 * Pre:  sega_init() setup of I/O pins
 *       high address outputs A23-A17 already selected
 *       first must be even; len must be odd and below 255
 *       first + len must be at most 255; data has room for len + 1 bytes
 * Post: data[0..len] filled; physical word address advanced after the last read
 *       16-bit data bus input; /AS, /C_CE, /C_OE, /LDSW and /UDSW high
 *       cached sega_addr_hi and sega_addr_lo unchanged
 * Rtn:  Number of bytes read (len + 1) for the required even-sized range
 */
uint8_t gen_rom_page_rd(uint8_t* data, uint16_t addrH, uint8_t first, uint8_t len)
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

  for(i = 0; i <= len; i++) {
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

/* Desc: Read D7-D0 with /TIME asserted and /ASEL high
 *       addr_lo is passed directly to physical A16-A1 without shifting
 *       this address convention differs from gen_time_wr
 * Pre:  sega_init() setup of I/O pins
 *       addr_lo contains the intended physical word address
 *       A19 already set as required; this function does not clear it
 * Post: /C_OE, /C_CE, /AS, /LDSW and /UDSW high
 *       cached address reapplied through gen_refresh_addr(0), including /TIME
 *       16-bit data bus input; cached address values unchanged
 * Rtn:  Byte sampled on D7-D0
 */
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

/* Desc: Write D7-D0 with /TIME asserted and /ASEL high
 *       addr_lo is a byte address shifted right once for physical A16-A1
 *       drive D15-D8 as zero and pulse both /LDSW and /UDSW
 * Pre:  sega_init() setup of I/O pins
 *       A19 and other cartridge controls already set for the intended access
 * Post: Write cycle issued without readback verification
 *       /AS, /LDSW, /UDSW and /TIME high; 16-bit data bus input
 *       final address latch update also changes A16-A1 through FFADDR_SET
 *       cached address unchanged and not reapplied to hardware
 * Rtn:  None
 */
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

/* Desc: Read one Genesis RAM byte on D7-D0
 *       addr_lo is a byte address; gen_set_addr_lo drives physical A16-A1
 * Pre:  sega_init() setup of I/O pins
 *       RAM enabled and sega_addr_hi set for the desired RAM bank
 * Post: sega_addr_lo updated; target address left on bus
 *       low data bus input; /AS, /C_CE, /C_OE, /LDSW and /UDSW high
 * Rtn:  Byte read on D7-D0
 */
uint8_t gen_ram_rd(uint16_t addr_lo)
{
  uint8_t rv;

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

  DATA_RD(rv);

  // set #C_OE
  GEN_C_OE_HI();

  // set #C_CE
  GEN_C_CE_HI();

  // set #AS B18 CPU access entire memory map, indicating address bus valid
  GBP_HI();

  return rv;
}

/* Desc: Write one Genesis RAM byte on D7-D0
 *       pulse /LDSW with /UDSW high; /AS and /C_CE asserted
 *       addr_lo is a byte address; gen_set_addr_lo drives physical A16-A1
 * Pre:  sega_init() setup of I/O pins
 *       RAM enabled and sega_addr_hi set for the desired RAM bank
 * Post: Write cycle issued without readback verification; sega_addr_lo updated
 *       target address left on bus; low data bus input
 *       /AS, /C_CE, /C_OE, /LDSW and /UDSW high
 * Rtn:  None
 */
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

/* Desc: Read len + 1 Genesis RAM bytes on D7-D0 into data[0..len]
 *       addrH and first directly set physical word-address outputs
 *       pulse /C_CE for each read; hold /AS and /C_OE low
 *       no USB polling is performed
 * Pre:  sega_init() setup of I/O pins
 *       RAM enabled and high address outputs selected
 *       data has room for len + 1 bytes; len must be below 255
 *       first + len must be at most 255 to stay within the address page
 * Post: data[0..len] filled; physical word address advanced past the last read
 *       low data bus input; /AS, /C_CE, /C_OE, /LDSW and /UDSW high
 *       cached address unchanged
 * Rtn:  Number of bytes read (len + 1)
 */
uint8_t gen_ram_page_rd(uint8_t* data, uint16_t addrH, uint8_t first, uint8_t len)
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

  for(i = 0; i <= len; i++) {
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

/* Desc: Write size_kb * 1024 LFSR-generated RAM bytes on D7-D0
 *       addr directly drives physical A16-A1 and advances once per byte
 *       pulse /LDSW and /C_CE with /AS low; keep /UDSW and /C_OE high
 * Pre:  sega_init() setup of I/O pins
 *       RAM enabled, high address outputs selected and LFSR initialized
 *       size_kb must be below 64 to avoid wrapping the 16-bit loop counter
 *       requested physical word-address range must fit the selected bank
 * Post: LFSR advanced once per write; no readback verification
 *       low data bus input; /UDSW and /C_OE high
 *       for a nonempty range, last address left on bus and /AS, /C_CE, /LDSW high
 *       cached address unchanged
 * Rtn:  None
 */
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

  for(i = 0; i < size; i++) {
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

/* Desc: Poll a 16-bit Genesis ROM address until it matches the expected word
 *       stop after at most 0xFFFF read attempts
 * Pre:  cartridge I/O initialized and upper address bank selected
 *       addr_lo identifies the word being programmed
 * Post: sega_addr_lo set to addr_lo; data bus returned to input
 *       /C_CE and /C_OE high after the final read
 * Rtn:  Last 16-bit word read; compare with data to detect a timeout
 */
static uint16_t gen_rom_wr_polling(uint16_t addr_lo, uint16_t data)
{
  uint16_t rv;
  uint16_t timeout = 0xFFFF;

  do {
    rv = gen_rom_rd(addr_lo);
    if(rv == data) {
      break;
    }
  } while(--timeout);

  return rv;
}

/* Desc: Program a 16-bit flash word using the short unlock profile
 *       use flash word offsets 0x0555/0x02AA, corresponding to Genesis
 *       byte addresses 0x0AAA/0x0554
 *       poll the target through gen_rom_wr_polling
 *       no USB polling is performed
 * Pre:  sega_init() setup of I/O pins
 *       high byte address and mapper selected for the target and unlock commands
 *       addr_lo even; flash supports the 0x00AA/0x0055/0x00A0 sequence
 * Post: Write attempted; return does not guarantee successful programming
 *       sega_addr_lo left at target; data bus input
 *       /AS, /C_CE, /C_OE, /LDSW and /UDSW high
 * Rtn:  Last 16-bit word read at target; compare with data to detect failure
 */
uint16_t gen_rom_flash_wr_short(uint16_t addr_lo, uint16_t data)
{
  uint16_t rv;

  // write unlock command
  gen_rom_wr(0x0555 << 1, 0x00AA);
  gen_rom_wr(0x02AA << 1, 0x0055);
  gen_rom_wr(0x0555 << 1, 0x00A0);

  // write data
  gen_rom_wr(addr_lo, data);

  rv = gen_rom_wr_polling(addr_lo, data);

  return rv;
}

#endif // SEGA_CONN
