#ifndef _pinport_h
#define _pinport_h

#include "pinport_al.h"
#include "shared_errors.h"
#include "shared_dict_pinport.h"

uint8_t pinport_call( uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata );


// used for a very short delay
#define NOP() do { __asm__ __volatile__ ("nop"); } while (0)


////////////////////////////////
// CONTROL (CTL) PORT PINS
////////////////////////////////

//     PC0  "M2"
#define	M2_IP_PU()	CTL_IP_PU(M2bank, M2)
#define	M2_IP_FL()	CTL_IP_FL(M2bank, M2)
#define	M2_OP()		CTL_OP(M2bank, M2)
#define M2_LO()		CTL_SET_LO(M2bank, M2)
#define M2_HI()		CTL_SET_HI(M2bank, M2)
#define M2_RD(val)	CTL_RD(M2bank, M2, val)

//     PC1  "ROMSEL"
#define	ROMSEL_IP_PU()	CTL_IP_PU(ROMSELbank, ROMSEL)
#define	ROMSEL_IP_FL()	CTL_IP_FL(ROMSELbank, ROMSEL)
#define	ROMSEL_OP()	CTL_OP(ROMSELbank, ROMSEL)
#define ROMSEL_LO()	CTL_SET_LO(ROMSELbank, ROMSEL)
#define ROMSEL_HI()	CTL_SET_HI(ROMSELbank, ROMSEL)
#define ROMSEL_RD(val)	CTL_RD(ROMSELbank, ROMSEL, val)
// same pin: N64 ALE_L
#define	ALE_L_OP()	CTL_OP(ROMSELbank, ROMSEL)
#define	ALE_L_IP_PU()	CTL_IP_PU(ROMSELbank, ROMSEL)
#define ALE_L_LO()	CTL_SET_LO(ROMSELbank, ROMSEL)
#define ALE_L_HI()	CTL_SET_HI(ROMSELbank, ROMSEL)

//     PC2  "PRGRW"
#define	PRGRW_IP_PU()	CTL_IP_PU(PRGRWbank, PRGRW)
#define	PRGRW_IP_FL()	CTL_IP_FL(PRGRWbank, PRGRW)
#define	PRGRW_OP()	CTL_OP(PRGRWbank, PRGRW)
#define PRGRW_LO()	CTL_SET_LO(PRGRWbank, PRGRW)
#define PRGRW_HI()	CTL_SET_HI(PRGRWbank, PRGRW)
#define PRGRW_RD(val)	CTL_RD(PRGRWbank, PRGRW, val)
// same pin: N64 ALE_H
#define	ALE_H_IP_PU()	CTL_IP_PU(PRGRWbank, PRGRW)
#define	ALE_H_OP()	CTL_OP(PRGRWbank, PRGRW)
#define ALE_H_LO()	CTL_SET_LO(PRGRWbank, PRGRW)
#define ALE_H_HI()	CTL_SET_HI(PRGRWbank, PRGRW)

//     PC3  "FREE"
#ifndef C3nodef
#define	FREE_IP_PU()	CTL_IP_PU(FREEbank, FREE)
#define	FREE_IP_FL()	CTL_IP_FL(FREEbank, FREE)
#define	FREE_OP()	CTL_OP(FREEbank, FREE)
#define FREE_LO()	CTL_SET_LO(FREEbank, FREE)
#define FREE_HI()	CTL_SET_HI(FREEbank, FREE)
#define FREE_RD(val)	CTL_RD(FREEbank, FREE, val)
#endif

//     PC4  "CSRD"
#define	CSRD_IP_PU()	CTL_IP_PU(CSRDbank, CSRD)
#define	CSRD_IP_FL()	CTL_IP_FL(CSRDbank, CSRD)
#define	CSRD_OP()	CTL_OP(CSRDbank, CSRD)
#define CSRD_LO()	CTL_SET_LO(CSRDbank, CSRD)
#define CSRD_HI()	CTL_SET_HI(CSRDbank, CSRD)
#define CSRD_RD(val)	CTL_RD(CSRDbank, CSRD, val)

//     PC5  "CSWR"
#define	CSWR_IP_PU()	CTL_IP_PU(CSWRbank, CSWR)
#define	CSWR_IP_FL()	CTL_IP_FL(CSWRbank, CSWR)
#define	CSWR_OP()	CTL_OP(CSWRbank, CSWR)
#define CSWR_LO()	CTL_SET_LO(CSWRbank, CSWR)
#define CSWR_HI()	CTL_SET_HI(CSWRbank, CSWR)
#define CSWR_RD(val)	CTL_RD(CSWRbank, CSWR, val)

//     PC6  "CICE" 
#define	CICE_IP_PU()	CTL_IP_PU(CICEbank, CICE)
#define	CICE_IP_FL()	CTL_IP_FL(CICEbank, CICE)
#define	CICE_OP()	CTL_OP(CICEbank, CICE)
#define CICE_LO()	CTL_SET_LO(CICEbank, CICE)
#define CICE_HI()	CTL_SET_HI(CICEbank, CICE)
#define CICE_RD(val)	CTL_RD(CICEbank, CICE, val)

//     PC7  "AHL"
#ifndef	C7nodef
#define	AHL_IP_PU()	CTL_IP_PU(AHLbank, AHL)
#define	AHL_IP_FL()	CTL_IP_FL(AHLbank, AHL)
#define	AHL_OP()	CTL_OP(AHLbank, AHL)
#define AHL_LO()	CTL_SET_LO(AHLbank, AHL)
#define AHL_HI()	CTL_SET_HI(AHLbank, AHL)
#define AHL_RD(val)	CTL_RD(AHLbank, AHL, val)
#endif

//     PC8  "EXP0" 
#define	EXP0_IP_PU()	CTL_IP_PU(EXP0bank, EXP0)
#define	EXP0_IP_FL()	CTL_IP_FL(EXP0bank, EXP0)
#define	EXP0_OP()	CTL_OP(EXP0bank, EXP0)
#define EXP0_LO()	CTL_SET_LO(EXP0bank, EXP0)
#define EXP0_HI()	CTL_SET_HI(EXP0bank, EXP0)
#define EXP0_RD(val)	CTL_RD(EXP0bank, EXP0, val)

//     PC22  "EXP5" 
#define	EXP5_IP_PU()	CTL_IP_PU(EXP5bank, EXP5)
#define	EXP5_IP_FL()	CTL_IP_FL(EXP5bank, EXP5)
#define	EXP5_OP()	CTL_OP(EXP5bank, EXP5)
#define EXP5_LO()	CTL_SET_LO(EXP5bank, EXP5)
#define EXP5_HI()	CTL_SET_HI(EXP5bank, EXP5)
#define EXP5_RD(val)	CTL_RD(EXP5bank, EXP5, val)

#ifdef STM_CORE
	#define	EXP0_OD()	CTL_OD(EXP0bank, EXP0)
	#define	EXP0_PP()	CTL_PP(EXP0bank, EXP0)
#endif

//     PC9  "LED" 
#define	LED_IP_PU()	CTL_IP_PU(LEDbank, LED)
#define	LED_IP_FL()	CTL_IP_FL(LEDbank, LED)
#define	LED_OP()	CTL_OP(LEDbank, LED)
#define LED_LO()	CTL_SET_LO(LEDbank, LED)
#define LED_HI()	CTL_SET_HI(LEDbank, LED)
#define LED_RD(val)	CTL_RD(LEDbank, LED, val)

//     PC10 "IRQ"
#define	IRQ_IP_PU()	CTL_IP_PU(IRQbank, IRQ)
#define	IRQ_IP_FL()	CTL_IP_FL(IRQbank, IRQ)
#define	IRQ_OP()	CTL_OP(IRQbank, IRQ)
#define IRQ_LO()	CTL_SET_LO(IRQbank, IRQ)
#define IRQ_HI()	CTL_SET_HI(IRQbank, IRQ)
#define IRQ_RD(val)	CTL_RD(IRQbank, IRQ, val)

//     PC11 "CIA10" 
#define	CIA10_IP_PU()	CTL_IP_PU(CIA10bank, CIA10)
#define	CIA10_IP_FL()	CTL_IP_FL(CIA10bank, CIA10)
#define	CIA10_OP()	CTL_OP(CIA10bank, CIA10)
#define CIA10_LO()	CTL_SET_LO(CIA10bank, CIA10)
#define CIA10_HI()	CTL_SET_HI(CIA10bank, CIA10)
#define CIA10_RD(val)	CTL_RD(CIA10bank, CIA10, val)

//     PC12 "BL" 

//     PC13 "AXL"
#ifndef	C13nodef

#ifdef	PURPLE_KAZZO	//tie two pins together via software
#define	AXL_IP_PU()	CTL_IP_PU(AXLbank, AXL)		CTL_IP_PU(FREEbank, FREE)
#define	AXL_IP_FL()	CTL_IP_FL(AXLbank, AXL)         CTL_IP_FL(FREEbank, FREE)
#define	AXL_OP()	CTL_OP(AXLbank, AXL)            CTL_OP(FREEbank, FREE)
#define AXL_LO()	CTL_SET_LO(AXLbank, AXL)        CTL_SET_LO(FREEbank, FREE)
#define AXL_HI()	CTL_SET_HI(AXLbank, AXL)        CTL_SET_HI(FREEbank, FREE)
#define AXL_RD(val)	CTL_RD(AXLbank, AXL, val)
#else	//not PURPLE_KAZZO
#define	AXL_IP_PU()	CTL_IP_PU(AXLbank, AXL)
#define	AXL_IP_FL()	CTL_IP_FL(AXLbank, AXL)
#define	AXL_OP()	CTL_OP(AXLbank, AXL)
#define AXL_LO()	CTL_SET_LO(AXLbank, AXL)
#define AXL_HI()	CTL_SET_HI(AXLbank, AXL)
#define AXL_RD(val)	CTL_RD(AXLbank, AXL, val)
#endif

#endif

//     PC14 "AUDL"

//     PC15 "AUDR"

//     PC16 "GBP" 
#ifndef	C16nodef
#define	GBP_IP_PU()	CTL_IP_PU(GBPbank, GBP)
#define	GBP_IP_FL()	CTL_IP_FL(GBPbank, GBP)
#define	GBP_OP()	CTL_OP(GBPbank, GBP)
#define GBP_LO()	CTL_SET_LO(GBPbank, GBP)
#define GBP_HI()	CTL_SET_HI(GBPbank, GBP)
#define GBP_3V()	GBP_HI()
#define GBP_5V()	GBP_LO()
#define GBP_RD(val)	CTL_RD(GBPbank, GBP, val)
#endif

//     PC17 "SWD" 

//     PC18 "SWC" 

//     PC19 "AFL" 
#ifndef	C19nodef
#define	AFL_IP_PU()	CTL_IP_PU(AFLbank, AFL)
#define	AFL_IP_FL()	CTL_IP_FL(AFLbank, AFL)
#define	AFL_OP()	CTL_OP(AFLbank, AFL)
#define AFL_LO()	CTL_SET_LO(AFLbank, AFL)
#define AFL_HI()	CTL_SET_HI(AFLbank, AFL)
#define AFL_RD(val)	CTL_RD(AFLbank, AFL, val)
#endif

//     PC20 "COUT" 

//     PC21 "FCAPU" 

// BROKE STUDIO
//     PC22 "EXP5" 
// BROKE STUDIO

////////////////////////////////
// EXTRA (EXT) PORT PINS
////////////////////////////////

//     PE0 "A0"
#define	A0_IP_PU()	EXT_IP_PU(A0bank, A0)
#define	A0_IP_FL()	EXT_IP_FL(A0bank, A0)
#define	A0_OP()		EXT_OP(A0bank, A0)
#define A0_LO()		EXT_SET_LO(A0bank, A0)
#define A0_HI()		EXT_SET_HI(A0bank, A0)
#define A0_RD(val)	EXT_RD(A0bank, A0, val)

#ifdef STM_CORE
	#define	A0_OD()	EXT_OD(A0bank, A0)
	#define	A0_PP()	EXT_PP(A0bank, A0)
#endif

//     PE1 "D0"
#define	D0_IP_PU()	EXT_IP_PU(D0bank, D0)
#define	D0_IP_FL()	EXT_IP_FL(D0bank, D0)
#define	D0_OP()		EXT_OP(D0bank, D0)
#define D0_LO()		EXT_SET_LO(D0bank, D0)
#define D0_HI()		EXT_SET_HI(D0bank, D0)
#define D0_RD(val)	EXT_RD(D0bank, D0, val)

#ifdef STM_CORE
	#define	D0_OD()	EXT_OD(D0bank, D0)
	#define	D0_PP()	EXT_PP(D0bank, D0)
#endif

#endif	//end of file
