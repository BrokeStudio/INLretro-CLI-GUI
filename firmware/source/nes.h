#ifndef _nes_h
#define _nes_h

#include "pinport.h"
#include "buffer.h" //TODO remove this junk when get rid of FALSE
#include "shared_dictionaries.h"
#include "shared_errors.h"
#include "stuff.h"

uint8_t nes_call(uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t* rdata);

void discrete_exp0_prgrom_wr(uint16_t addr, uint8_t data);
void disc_push_exp0_prgrom_wr(uint16_t addr, uint8_t data);
// void	discrete_exp0_mapper_wr( uint16_t addr, uint8_t data );
uint8_t emulate_nes_cpu_rd(uint16_t addr);
uint8_t nes_cpu_rd(uint16_t addr);
void nes_cpu_wr(uint16_t addr, uint8_t data);
void nes_m2_low_wr(uint16_t addr, uint8_t data);
// TODO combine m2_low & m2_high into one function with an arg
void nes_m2_high_wr(uint16_t addr, uint8_t data);
uint8_t nes_ppu_rd(uint16_t addr);
void nes_ppu_wr(uint16_t addr, uint8_t data);
uint8_t nes_dualport_rd(uint16_t addr);
void nes_dualport_wr(uint16_t addr, uint8_t data);
// uint8_t	ciram_a10_mirroring( void );
uint8_t nes_cpu_page_rd_poll(uint8_t* data, uint8_t addrH, uint8_t first, uint8_t last, uint8_t poll);
uint8_t nes_cpu_page_rd_toggle(uint8_t* data, uint8_t addrH, uint8_t first, uint8_t last, uint8_t poll);
uint8_t nes_ppu_page_rd_poll(uint8_t* data, uint8_t addrH, uint8_t first, uint8_t last, uint8_t poll);
uint8_t nes_ppu_page_rd_toggle(uint8_t* data, uint8_t addrH, uint8_t first, uint8_t len, uint8_t poll);
uint8_t nes_dualport_page_rd_poll(uint8_t* data, uint8_t addrH, uint8_t first, uint8_t len, uint8_t poll);

void mmc1_wr(uint16_t addr, uint8_t data, uint8_t reset);

uint8_t nrom_prgrom_flash_wr(uint16_t addr, uint8_t data);
uint8_t nrom_chrrom_flash_wr(uint16_t addr, uint8_t data);
uint8_t mmc1_prgrom_flash_wr(uint16_t addr, uint8_t data);
uint8_t mmc1_chrrom_flash_wr(uint16_t addr, uint8_t data);
uint8_t unrom_prgrom_flash_wr(uint16_t addr, uint8_t data);
uint8_t cnrom_chrrom_flash_wr(uint16_t addr, uint8_t data);
uint8_t mmc3_prgrom_flash_wr(uint16_t addr, uint8_t data);
// uint8_t mmc3s_prgrom_flash_wr(uint16_t addr, uint8_t data);
uint8_t mmc3_chrrom_flash_wr(uint16_t addr, uint8_t data);
uint8_t mmc4_prgrom_sop_flash_wr(uint16_t addr, uint8_t data);
uint8_t mmc4_prgrom_flash_wr(uint16_t addr, uint8_t data);
uint8_t mmc2_prgrom_flash_wr(uint16_t addr, uint8_t data);
uint8_t mmc4_chrrom_flash_wr(uint16_t addr, uint8_t data);
uint8_t cdream_chrrom_flash_wr(uint16_t addr, uint8_t data);
uint8_t map30_prgrom_flash_wr(uint16_t addr, uint8_t data);
uint8_t gtrom_prgrom_flash_wr(uint16_t addr, uint8_t data);
void ppu_page_wr_lfsr(uint16_t addr, uint8_t data);
void cpu_page_wr_lfsr(uint16_t addr, uint8_t data);
uint8_t nes_prgrom_flash_wr_m2_high(uint16_t addr, uint8_t data);
uint8_t nes_prgrom_flash_wr_unlock_m2_high(uint16_t addr, uint8_t data);
// uint8_t mmc5_prgram_wr(uint16_t addr, uint8_t data);
uint8_t nes_prgrom_flash_wr_short(uint16_t addr, uint8_t data);
uint8_t rnbw_chrrom_flash_wr(uint16_t addr, uint8_t data);
uint8_t nes_prgrom_flash_wr_unlock(uint16_t addr, uint8_t data);
uint8_t nes_chrrom_flash_wr_unlock(uint16_t addr, uint8_t data);
uint8_t nes_prgrom_flash_wr_long(uint16_t addr, uint8_t data);

#define A10_BYTE 0x04
#define A11_BYTE 0x08
#define PPU_A13N_WORD 0x8000
#define PPU_A13N_BYTE 0x80

#endif
