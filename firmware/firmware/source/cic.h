#ifndef _cic_h
#define _cic_h

#include "pinport.h"
#include "types.h"

// Mapper variant for ATtiny13A CIC ISP over the NES CIC
uint8_t cic_read_signature(uint8_t* rdata);
uint8_t cic_read_fuses(uint8_t* rdata);
uint8_t cic_write_fuses(uint8_t low_fuse, uint8_t high_fuse);
uint8_t cic_read_buffer(buffer* buff);
uint8_t cic_chip_erase(void);
uint8_t cic_write_buffer(buffer* buff);

#endif
