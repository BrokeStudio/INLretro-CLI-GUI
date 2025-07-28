#ifndef _jtag_h
#define _jtag_h

#include "pinport.h"
#include "shared_dictionaries.h"
#include "shared_errors.h"

extern GPIO_TypeDef  	*tdo_base;
extern uint8_t 	tdo_pin;
extern GPIO_TypeDef  	*tdi_base;
extern uint8_t 	tdi_pin;
extern GPIO_TypeDef  	*tms_base;
extern uint8_t 	tms_pin;
extern GPIO_TypeDef  	*tck_base;
extern uint8_t 	tck_pin;

//main thread needs access to status to know when engine is running
extern uint8_t	pbje_status;

//macros for JTAG signals on pins mcu has direct access to, for now only INL6
#ifdef STM_INL6

//TCK JTAG clock signal
//TMS & TDI latched on rising edges, TDO updated on falling
#define	TCK_HI()	tck_base->BSRR = 1<<tck_pin
#define	TCK_LO()	tck_base->BRR = 1<<tck_pin
#define	TCK_OP()	tck_base->MODER |= (MODER_OP<<(tck_pin*2))
#define	TCK_PP()	tck_base->OTYPER &= ~(OTYPER_OD<<tck_pin)

//TMS JTAG mode input
#define	TMS_HI()	tms_base->BSRR = 1<< tms_pin
#define	TMS_LO()	tms_base->BRR = 1<< tms_pin
#define	TMS_OP()	tms_base->MODER |=  (MODER_OP<<(tms_pin*2))
#define	TMS_PP()	tms_base->OTYPER &= ~(OTYPER_OD<< tms_pin)

//TDI JTAG data input
#define	TDI_HI()	tdi_base->BSRR = 1<< tdi_pin
#define	TDI_LO()	tdi_base->BRR = 1<< tdi_pin
#define	TDI_OP()	tdi_base->MODER |=  (MODER_OP<<(tdi_pin*2))
#define	TDI_PP()	tdi_base->OTYPER &= ~(OTYPER_OD<< tdi_pin)

//TDI JTAG data output
#define	TDO_IP_PU()	tdo_base->MODER &= ~(MODER_OP<<(tdo_pin*2)); tdo_base->PUPDR |=  (PUPDR_PU<<(tdo_pin*2))
#define TDO_RD(val)	val = (tdo_base->IDR & (1<<tdo_pin))

#else	//everything else (AVR_KAZZO & STM_ADAPTER)


//EXPANSION PORT SUPPORT
//write only byte wide port
//TDO EXP0 not part of EXP PORT definition (because it's read/write and not behind flipflop)
#define	TDO_IP_PU()	EXP0_IP_PU()
#define TDO_RD(val)	EXP0_RD(val)
//TDI EXP1 (bit 0)
#define	TDI_MASK	0x01
//TMS EXP2 (bit 1)
#define	TMS_MASK	0x02
//TCK EXP3 (bit 2)
#define	TCK_MASK	0x04

//global byte used for byte wide right only EXPANSION port to support devices with EXP flipflops
uint8_t exp_byte;
uint8_t exp_byte_temp;

//signal macros for EXP PORT
#define EXP_ALL_LO()		exp_byte = 0x00; EXP_SET(0x00)
#define EXP_ONLY_TMS_HI()	exp_byte = TMS_MASK; EXP_SET(TMS_MASK)


#endif	//end AVR_KAZZO & STM_ADAPTER

uint8_t jtag_call( uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata );

void jtag_init_pbje(); 
void jtag_run_pbje();


// false = 0 = ignore
#define	FORCE0	0x10	//0x1x -> force
#define	FORCE1	0x11
#define	DATA0	0x20	//0x2x -> data array
//#define	DATA1	0x21
void pbje_state_change( uint8_t tms_data ); 
void pbje_scan( uint8_t tdi_data, uint8_t tdo_data, uint8_t exit );

#endif
