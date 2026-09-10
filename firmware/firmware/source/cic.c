#include "cic.h"
#include "io.h"
#include "pinport.h"

#ifdef STM_INL6

  // | ATTiny (pin - desc) | NES (pin - desc) | STM (pin - desc) |
  // | ------------------- | ---------------- | ---------------- |
  // | 1 - PB5(/ RESET)    | 55 - EXP5        | 58 - PB6         |
  // | 2 - PB3(CLKI)       | 71 - CIC_4MHZ    | 8 - PC0          |
  // | 3 - PB4             | not connected    |                  |
  // | 5 - PB0(MOSI)       | 35 - CIC_S1      | 54 - PD2         |
  // | 6 - PB1(MISO)       | 34 - CIC_S0      | 23 - PA7         |
  // | 7 - PB2(SCK)        | 70 - CIC_S2      | 26 - PB0         |

  // INL6 routing:
  // ATtiny pin 1 / PB5 / RESET -> NES EXP5    -> STM PB6 / C22
  // ATtiny pin 2 / PB3 / CLKI  -> NES CIC_4MHZ -> STM PC0 / ADDR bit 0
  // ATtiny pin 5 / PB0 / MOSI  -> NES CIC_S1  -> STM PD2 / C20
  // ATtiny pin 6 / PB1 / MISO  -> NES CIC_S0  -> STM PA7 / C16
  // ATtiny pin 7 / PB2 / SCK   -> NES CIC_S2  -> STM PB0 / C19
  #define CIC_CLKI_BANK GPIOC
  #define CIC_CLKI_PIN (0U)

  #define CIC_RESET_BANK EXP5bank
  #define CIC_RESET_PIN EXP5

  #define CIC_MOSI_BANK COUTbank
  #define CIC_MOSI_PIN COUT

  #define CIC_MISO_BANK GBPbank
  #define CIC_MISO_PIN GBP

  #define CIC_SCK_BANK AFLbank
  #define CIC_SCK_PIN AFL

  // ATtiny13A flash page is 16 words = 32 bytes. A 256 byte INL buffer
  // therefore contains eight ATtiny flash pages.
  #define CIC_FLASH_BYTES 1024U
  #define CIC_PAGE_BYTES 32U
  #define CIC_PAGE_WORD_MASK 0xFFF0U

  // Timing knobs validated on INL6 with ATtiny13A CIC ISP.
  #define CIC_CLKI_DELAY_LOOPS 20U
  #define CIC_CLKI_CYCLES_PER_SCK_PHASE 2U
  #define CIC_WRITE_SETTLE_CLKI_CYCLES 64U
  #define CIC_ERASE_SETTLE_CLKI_CYCLES 128U
  #define CIC_READY_POLL_LIMIT 60000U
  #define CIC_ENTER_ISP_TRIES 3U
  #define CIC_VERIFY_AFTER_WRITE 0U

static void cic_delay(void)
{
  uint8_t n = CIC_CLKI_DELAY_LOOPS;

  while(n) {
    NOP();
    n--;
  }
}

static void cic_pin_lo(GPIO_TypeDef* bank, uint8_t pin)
{
  bank->BRR = 1U << pin;
}

static void cic_pin_hi(GPIO_TypeDef* bank, uint8_t pin)
{
  bank->BSRR = 1U << pin;
}

static void cic_pin_op(GPIO_TypeDef* bank, uint8_t pin)
{
  bank->MODER &= ~(0x3U << (pin * 2U));
  bank->MODER |= (0x1U << (pin * 2U));
  bank->OTYPER &= ~(1U << pin);
}

static void cic_pin_ip(GPIO_TypeDef* bank, uint8_t pin)
{
  bank->MODER &= ~(0x3U << (pin * 2U));
}

static void cic_clki_cycle(void)
{
  cic_pin_hi(CIC_CLKI_BANK, CIC_CLKI_PIN);
  cic_delay();
  cic_pin_lo(CIC_CLKI_BANK, CIC_CLKI_PIN);
  cic_delay();
}

static void cic_clki_cycles(uint16_t cycles)
{
  while(cycles) {
    cic_clki_cycle();
    cycles--;
  }
}

static void cic_io_begin(void)
{
  io_reset();

  RCC->AHBENR |= RCC_AHBENR_GPIOAEN | RCC_AHBENR_GPIOBEN | RCC_AHBENR_GPIOCEN | RCC_AHBENR_GPIODEN;

  cic_pin_lo(CIC_CLKI_BANK, CIC_CLKI_PIN);
  cic_pin_lo(CIC_SCK_BANK, CIC_SCK_PIN);
  cic_pin_lo(CIC_MOSI_BANK, CIC_MOSI_PIN);
  cic_pin_hi(CIC_RESET_BANK, CIC_RESET_PIN);

  cic_pin_op(CIC_CLKI_BANK, CIC_CLKI_PIN);
  cic_pin_op(CIC_SCK_BANK, CIC_SCK_PIN);
  cic_pin_op(CIC_MOSI_BANK, CIC_MOSI_PIN);
  cic_pin_op(CIC_RESET_BANK, CIC_RESET_PIN);
  cic_pin_ip(CIC_MISO_BANK, CIC_MISO_PIN);
}

static void cic_io_end(void)
{
  cic_pin_hi(CIC_RESET_BANK, CIC_RESET_PIN);
  cic_pin_lo(CIC_CLKI_BANK, CIC_CLKI_PIN);
  cic_pin_lo(CIC_SCK_BANK, CIC_SCK_PIN);
  cic_pin_lo(CIC_MOSI_BANK, CIC_MOSI_PIN);

  io_reset();
}

static uint8_t cic_isp_xfer(uint8_t out)
{
  uint8_t in = 0;
  uint8_t mask = 0x80;

  while(mask) {
    if(out & mask) {
      cic_pin_hi(CIC_MOSI_BANK, CIC_MOSI_PIN);
    } else {
      cic_pin_lo(CIC_MOSI_BANK, CIC_MOSI_PIN);
    }

    cic_clki_cycles(CIC_CLKI_CYCLES_PER_SCK_PHASE);
    cic_pin_hi(CIC_SCK_BANK, CIC_SCK_PIN);
    cic_clki_cycles(CIC_CLKI_CYCLES_PER_SCK_PHASE);

    if(CIC_MISO_BANK->IDR & (1U << CIC_MISO_PIN)) {
      in |= mask;
    }

    cic_pin_lo(CIC_SCK_BANK, CIC_SCK_PIN);
    cic_clki_cycles(CIC_CLKI_CYCLES_PER_SCK_PHASE);
    mask >>= 1;
  }

  return in;
}

static uint8_t cic_isp_cmd(uint8_t b0, uint8_t b1, uint8_t b2, uint8_t b3)
{
  cic_isp_xfer(b0);
  cic_isp_xfer(b1);
  cic_isp_xfer(b2);
  return cic_isp_xfer(b3);
}

static uint8_t cic_wait_ready(void)
{
  uint16_t polls = CIC_READY_POLL_LIMIT;

  while(polls) {
    if((cic_isp_cmd(0xF0, 0x00, 0x00, 0x00) & 0x01) == 0) {
      return SUCCESS;
    }
    polls--;
  }

  return GEN_FAIL;
}

static uint8_t cic_enter_isp(void)
{
  uint8_t echo;

  cic_pin_lo(CIC_SCK_BANK, CIC_SCK_PIN);
  cic_pin_lo(CIC_MOSI_BANK, CIC_MOSI_PIN);

  // Start CLKI before asserting reset so the part has a valid external clock.
  cic_clki_cycles(64);
  cic_pin_lo(CIC_RESET_BANK, CIC_RESET_PIN);
  cic_clki_cycles(256);

  cic_isp_xfer(0xAC);
  cic_isp_xfer(0x53);
  echo = cic_isp_xfer(0x00);
  cic_isp_xfer(0x00);

  return (echo == 0x53) ? SUCCESS : GEN_FAIL;
}

static uint8_t cic_begin_isp(void)
{
  uint8_t tries = CIC_ENTER_ISP_TRIES;
  uint8_t result;

  while(tries) {
    cic_io_begin();
    result = cic_enter_isp();
    if(result == SUCCESS) {
      return SUCCESS;
    }

    cic_io_end();
    cic_clki_cycles(256);
    tries--;
  }

  return GEN_FAIL;
}

static void cic_load_flash_word(uint16_t word_addr, uint16_t word)
{
  uint8_t addr = word_addr;

  cic_isp_cmd(0x40, 0x00, addr, word & 0xFF);
  cic_isp_cmd(0x48, 0x00, addr, word >> 8);
}

static uint8_t cic_write_flash_page(uint16_t page_word_addr)
{
  page_word_addr &= CIC_PAGE_WORD_MASK;
  cic_isp_cmd(0x4C, page_word_addr >> 8, page_word_addr & 0xFF, 0x00);
  cic_clki_cycles(CIC_WRITE_SETTLE_CLKI_CYCLES);
  return cic_wait_ready();
}

uint8_t cic_chip_erase(void)
{
  uint8_t result = SUCCESS;

  result = cic_begin_isp();
  if(result != SUCCESS) {
    return result;
  }

  // erase
  cic_isp_cmd(0xAC, 0x80, 0x00, 0x00);
  cic_clki_cycles(CIC_ERASE_SETTLE_CLKI_CYCLES);
  result = cic_wait_ready();

  wdt_reset();

  cic_io_end();
  return result;
}

static uint16_t cic_read_flash_word(uint16_t word_addr)
{
  uint8_t lo;
  uint8_t hi;

  lo = cic_isp_cmd(0x20, word_addr >> 8, word_addr & 0xFF, 0x00);
  hi = cic_isp_cmd(0x28, word_addr >> 8, word_addr & 0xFF, 0x00);

  return ((uint16_t)hi << 8) | lo;
}

static uint16_t cic_buffer_flash_word(buffer* buff, uint16_t cur)
{
  uint16_t word = buff->data[cur];

  if((cur + 1) <= buff->last_idx) {
    word |= ((uint16_t)buff->data[cur + 1]) << 8;
  } else {
    word |= 0xFF00;
  }

  return word;
}

uint8_t cic_read_signature(uint8_t* rdata)
{
  uint8_t result;
  uint8_t i;

  result = cic_begin_isp();
  if(result != SUCCESS) {
    return result;
  }

  for(i = 0; i < 3; i++) {
    rdata[i] = cic_isp_cmd(0x30, 0x00, i, 0x00);
  }

  wdt_reset();

  cic_io_end();
  return SUCCESS;
}

uint8_t cic_read_fuses(uint8_t* rdata)
{
  uint8_t result;

  result = cic_begin_isp();
  if(result != SUCCESS) {
    return result;
  }

  rdata[0] = cic_isp_cmd(0x50, 0x00, 0x00, 0x00);
  rdata[1] = cic_isp_cmd(0x58, 0x08, 0x00, 0x00);

  wdt_reset();
  cic_io_end();
  return SUCCESS;
}

uint8_t cic_write_fuses(uint8_t low_fuse, uint8_t high_fuse)
{
  uint8_t fuses[2];
  uint8_t result;

  result = cic_begin_isp();
  if(result != SUCCESS) {
    return result;
  }

  result = cic_wait_ready();
  if(result != SUCCESS) {
    cic_io_end();
    return result;
  }

  cic_isp_cmd(0xAC, 0xA0, 0x00, low_fuse);
  result = cic_wait_ready();
  if(result != SUCCESS) {
    cic_io_end();
    return result;
  }

  cic_isp_cmd(0xAC, 0xA8, 0x00, high_fuse);
  result = cic_wait_ready();
  if(result != SUCCESS) {
    cic_io_end();
    return result;
  }

  fuses[0] = cic_isp_cmd(0x50, 0x00, 0x00, 0x00);
  fuses[1] = cic_isp_cmd(0x58, 0x08, 0x00, 0x00);

  wdt_reset();
  cic_io_end();

  return ((fuses[0] == low_fuse) && (fuses[1] == high_fuse)) ? SUCCESS : GEN_FAIL;
}

uint8_t cic_read_buffer(buffer* buff)
{
  uint16_t byte_addr = (((uint16_t)buff->page_num) << 8) | buff->id;
  uint16_t cur = buff->cur_byte;
  uint16_t last_word_addr = 0xFFFF;
  uint16_t word_addr;
  uint16_t word = 0xFFFF;
  uint8_t result;

  if((byte_addr + buff->last_idx) >= CIC_FLASH_BYTES) {
    return buff->cur_byte;
  }

  result = cic_begin_isp();
  if(result != SUCCESS) {
    return buff->cur_byte;
  }

  cic_clki_cycles(512);
  (void)cic_read_flash_word(0);

  while(cur <= buff->last_idx) {
    word_addr = (byte_addr + cur) >> 1;
    if(word_addr != last_word_addr) {
      word = cic_read_flash_word(word_addr);
      last_word_addr = word_addr;
    }

    if(((byte_addr + cur) & 1U) == 0) {
      buff->data[cur] = word & 0xFF;
    } else {
      buff->data[cur] = word >> 8;
    }

    cur++;
  }

  wdt_reset();
  cic_io_end();

  // Return the next byte index, matching page read helpers like
  // nes_cpu_page_rd_poll().
  return cur;
}

uint8_t cic_write_buffer(buffer* buff)
{
  uint16_t byte_addr = ((uint16_t)buff->page_num) << 8;
  uint16_t cur = buff->cur_byte;
  uint16_t page_start;
  uint16_t page_end;
  uint16_t word_addr;
  uint16_t word;
  uint8_t result = SUCCESS;

  if((byte_addr + buff->last_idx) >= CIC_FLASH_BYTES) {
    return GEN_FAIL;
  }

  result = cic_begin_isp();
  if(result != SUCCESS) {
    return result;
  }

  // After a standalone chip erase, the first programming session may enter ISP
  // before flash writes are accepted.
  result = cic_wait_ready();
  if(result != SUCCESS) {
    cic_io_end();
    return result;
  }

  while(cur <= buff->last_idx) {
    page_start = cur;
    page_end = page_start + CIC_PAGE_BYTES - 1;
    if(page_end > buff->last_idx) {
      page_end = buff->last_idx;
    }

    while(cur <= page_end) {
      word_addr = (byte_addr + cur) >> 1;
      word = cic_buffer_flash_word(buff, cur);

      cic_load_flash_word(word_addr, word);
      cur += 2;
    }

    result = cic_write_flash_page((byte_addr + page_start) >> 1);
    if(result != SUCCESS) {
      goto done;
    }
    wdt_reset();

  #if CIC_VERIFY_AFTER_WRITE
    cur = page_start;
    while(cur <= page_end) {
      word_addr = (byte_addr + cur) >> 1;
      word = cic_buffer_flash_word(buff, cur);

      if(cic_read_flash_word(word_addr) != word) {
        result = GEN_FAIL;
        goto done;
      }
      cur += 2;
    }
  #else
    cur = page_end + 1;
  #endif

    buff->cur_byte = cur;
    wdt_reset();
  }

done:
  cic_io_end();
  return result;
}

#else

uint8_t cic_read_signature(uint8_t* rdata)
{
  (void)rdata;
  return GEN_FAIL;
}

uint8_t cic_read_fuses(uint8_t* rdata)
{
  (void)rdata;
  return GEN_FAIL;
}

uint8_t cic_write_fuses(uint8_t low_fuse, uint8_t high_fuse)
{
  (void)low_fuse;
  (void)high_fuse;
  return GEN_FAIL;
}

uint8_t cic_read_buffer(buffer* buff)
{
  (void)buff;
  return GEN_FAIL;
}

uint8_t cic_chip_erase(void)
{
  return GEN_FAIL;
}

uint8_t cic_write_buffer(buffer* buff)
{
  (void)buff;
  return GEN_FAIL;
}

#endif
