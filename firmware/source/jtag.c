#include "jtag.h"

//=================================================================================================
//
//	JTAG operations
//	This file includes all the jtag functions possible to be called from the jtag dictionary.
//
//	See description of the commands contained here in shared/shared_dictionaries.h
//
//=================================================================================================

//JTAG pin globals initialized by io.c when setting up JTAG port
//Having these as variables allows pins to be easily relocated to any pin
GPIO_TypeDef  	*tdo_base;
uint8_t 	tdo_pin;
GPIO_TypeDef  	*tdi_base;
uint8_t 	tdi_pin;
GPIO_TypeDef  	*tms_base;
uint8_t 	tms_pin;
GPIO_TypeDef  	*tck_base;
uint8_t 	tck_pin;

//Paul's Basic JTAG Engine globals
uint8_t	pbje_status;	//only engine can write, read only by host
uint8_t	pbje_command;	//only host can write, read only by engine
uint8_t	pbje_numclk; 	//numclk is a sticky value, don't modify!
//TODO I don't think there's much value in having the data array this big
//We can scan in/out smaller portions of a longer bit streams using the HOLD commands
//Thinking that 8Bytes may be better max length, which is also max lua int (64bit)
//But honestly could get by pretty well with 2-4Bytes
//need to size this down and retest, but works for now
#define	PBJE_DATA_ARRAY_SIZE 32
uint8_t	pbje_data[PBJE_DATA_ARRAY_SIZE];
uint8_t	pbje_cmd_update_flag;


/* Desc:Function takes an opcode which was transmitted via USB
 * 	then decodes it to call designated function.
 * 	shared_dict_jtag.h is used in both host and fw to ensure opcodes/names align
 * Pre: Macros must be defined in firmware pinport.h & jtag.h
 * 	opcode must be defined in shared_dict_jtag.h
 * Post:function call complete.
 * Rtn: SUCCESS if opcode found, error if opcode not present or other problem.
 */
uint8_t jtag_call( uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata )
{
#define	RD_LEN	0
#define	RD0	1
#define	RD1	2
#define	RD2	3
#define	RD3	4
#define	RD4	5
#define	RD5	6
//	uint16_t *ret_hword = (uint16_t*) &rdata[1];

#define	BYTE_LEN 1
#define	HWORD_LEN 2
	uint8_t temp;

	switch (opcode) { 
		//case PBJE_INIT:		jtag_init_pbje();		break;
		//NOTE!  INITIALIZE PBJE with IO dictionary!!!

		case GET_CMD:		rdata[RD0] = pbje_command;
					rdata[RD_LEN] = BYTE_LEN;	break;

		case GET_STATUS:	rdata[RD0] = pbje_status;
					rdata[RD_LEN] = BYTE_LEN;	break;

		case SET_CMD:		pbje_command = operand;		
					//need to immediately update status to overwrite PBJE_DONE from previous command
					//signal to main thread that command was updated
					//this status is what triggers engine to process current command
					pbje_status = PBJE_CMD_RX;	
									break;
		case SET_CMD_WAIT:	pbje_command = operand;		
					pbje_status = PBJE_CMD_RX;	
					//perform command before returning
					jtag_run_pbje();
					//return current status
					rdata[RD0] = pbje_status;
					rdata[RD_LEN] = BYTE_LEN;
									break;

		case SET_NUMCLK:	pbje_numclk = operand;		break;

		//GET & SET ARRAY DATA, miscdata defines first byte index
		case SET_2B_DATA:	pbje_data[miscdata] = operand;
					pbje_data[miscdata+1] = operand>>8;
									break;
		case GET_8B_DATA:	//copy over 8B of data starting at miscdata index
					for (temp=RD0; temp<(RD0+8); temp++) {
						rdata[temp] = pbje_data[temp-RD0+miscdata];
					}	

					rdata[RD_LEN] = 8;
									break;
		case GET_32B_DATA:	
					//copy over 32B of data
					for (temp=RD0; temp<(RD0+32); temp++) {
						rdata[temp] = pbje_data[temp-RD0];
					}	

					rdata[RD_LEN] = 32;
									break;

		
		
		default:
			 //opcode doesn't exist
			 return ERR_UNKN_JTAG_OPCODE;
	}
	
	return SUCCESS;

}

//NOTE!  MUST INITIALIZE JTAG in io.c before calling!!!!
void jtag_init_pbje()
{
	uint8_t i;


	//set outputs to default level
#ifdef STM_INL6
	//while these are supposed to be default high, I'm going with low
	//these signals aren't 5v tolerant which could be problem with original kazzo boards
	TMS_LO();
	TDI_LO();
	//makes sense for TCK default state to be low as posedge is begining of cycle
	TCK_LO();

	//enable ouput drivers
	TCK_OP();
	TCK_PP();
	TMS_OP();
	TMS_PP();
	TDI_OP();
	TDI_PP();
#else
	exp_byte = 0;
	EXP_SET(exp_byte);
#endif

	
	//enable TDO as input
	TDO_IP_PU();


	//set NUM_CLK to max this engine can clock based on DATA_ARRAY bit size
	pbje_numclk = 0;	//byte variable, 0 -> 256

	//clear DATA_ARRAY
	for( i=0; i<PBJE_DATA_ARRAY_SIZE; i++) {
		pbje_data[i] = 0;
	}

	//SET STATE LAST to signal complete
	//PBJE initialization
	//set status & command to INIT
	pbje_status = PBJE_INIT;
	//only the host writes to command
	//pbje_command = PBJE_INIT;

}

//actual JTAG engine
//called periodically from main thread when jtag engine is on
//this is where the actual JTAG communications are generated
//main thread will call this routine so long as pbje_status != PBJE_OFF
void jtag_run_pbje()
{
	//status needs to be CMD_RX to start processing of new command
	if (pbje_status == PBJE_CMD_RX) {
		//host has issued a command
		//process the command and update status accordingly
		switch (pbje_command) {
			case PBJE_INIT:		
				jtag_init_pbje();
				//status set in function
				break;
			case PBJE_SHUTDOWN:		
				pbje_status = PBJE_OFF;
				break;

			case PBJE_STATE_CHG:  //data array holds TMS values to clock values bit packed, TDI undefined
				pbje_status = PBJE_PROC;
				pbje_state_change( DATA0 );
				pbje_status = PBJE_DONE;
				break;

			case PBJE_TDI_SCAN:   //ignore TDO, end scan with exit   256max
				pbje_status = PBJE_PROC;
				pbje_scan( DATA0, 0, 1 );
				pbje_status = PBJE_DONE;
				break;

			case PBJE_TDI_SCAN_HOLD:   //ignore TDO, don't exit    256max
				pbje_status = PBJE_PROC;
				pbje_scan( DATA0, 0, 0 );
				pbje_status = PBJE_DONE;
				break;

			case PBJE_TDO_SCAN0:  //TDI = 0, TMS=0 (last TMS=1)      256max
				pbje_status = PBJE_PROC;
				pbje_scan( FORCE0, DATA0, 1 );
				pbje_status = PBJE_DONE;
				break;

			case PBJE_TDO_SCAN1:  //TDI = 1, TMS=0 (last TMS=1)      256max
				pbje_status = PBJE_PROC;
				pbje_scan( FORCE1, DATA0, 1 );
				pbje_status = PBJE_DONE;
				break;

			case PBJE_TDO_SCAN0_HOLD:  //TDI = 0, TMS=0      256max
				pbje_status = PBJE_PROC;
				pbje_scan( FORCE0, DATA0, 0 );
				pbje_status = PBJE_DONE;
				break;

			case PBJE_TDO_SCAN1_HOLD:  //TDI = 1, TMS=0      256max
				pbje_status = PBJE_PROC;
				pbje_scan( FORCE1, DATA0, 0 );
				pbje_status = PBJE_DONE;
				break;

			//case PBJE_HALF_SCAN:  //TDI = first half of data array, TDO = second, TMS=0  128max
			//	pbje_status = PBJE_PROC;
			//	pbje_scan( DATA0, DATA1, 1 );
			//	pbje_status = PBJE_DONE;
			//	break;

			case PBJE_FULL_SCAN:  //TDI = entire data array, TDO dumped into array stomping TDI, TMS=0   256max
				pbje_status = PBJE_PROC;
				pbje_scan( DATA0, DATA0, 1 );
				pbje_status = PBJE_DONE;
				break;

			case PBJE_FULL_SCAN_HOLD:  //TDI = entire data array, TDO dumped into array stomping TDI, TMS=0   256max
				pbje_status = PBJE_PROC;
				pbje_scan( DATA0, DATA0, 0 );
				pbje_status = PBJE_DONE;
				break;

			case PBJE_CLOCK0:     //data not used, clock TMS=0 for NUMCLK
				pbje_status = PBJE_PROC;
				pbje_state_change( FORCE0 );
				pbje_status = PBJE_DONE;
				break;

			case PBJE_CLOCK1:     //data not used, clock TMS=1 for NUMCLK
				pbje_status = PBJE_PROC;
				pbje_state_change( FORCE1 );
				pbje_status = PBJE_DONE;
				break;

			//TODO
			//case PBJE_FREE_CLOCK0:        //data not used, clock TMS=0 indefinely
			//	pbje_status = PBJE_PROCESSED;
			//	break;
			//case PBJE_FREE_CLOCK1:        //data not used, clock TMS=1 indefinely
			//	pbje_status = PBJE_PROCESSED;
			//	break;
			//case PBJE_LONG_CLOCK0:        //data contains 32bit uint for number of clocks, TMS=0, numclk not used
			//	pbje_status = PBJE_PROCESSED;
			//	break;
			//case PBJE_LONG_CLOCK1:        //data contains 32bit uint for number of clocks, TMS=1, numclk not used
			//	pbje_status = PBJE_PROCESSED;
			//	break;

			default: //unknown command
				pbje_status = PBJE_UNKN_CMD;
				break;
		}

	}

}


//change the state of JTAG state machine
//tms data bit packed in data array unless forced 0/1
//numclk contains number of tck clocks to perform
//PRE/POST: TCK is low, all signals low (limit 5v non-tolerance with original kazzos)
void pbje_state_change( uint8_t tms_data )
{
	//numclk is a sticky value, don't modify!
	uint8_t	clk_count = pbje_numclk;
	uint8_t	cur_byte = 0;
	uint8_t	cur_bit = 0;


#ifndef STM_INL6
	exp_byte = 0;
#endif

	//force TMS if not using data array
	if( tms_data == FORCE0 ) {
#ifdef STM_INL6
		TMS_LO();
#endif
	} else if ( tms_data == FORCE1 ) {
#ifdef STM_INL6
		TMS_HI();
#else
		exp_byte = TMS_MASK;
#endif
	} 

#ifndef STM_INL6
	EXP_SET(exp_byte);
#endif

	do{
		//if TMS isn't forced, should be in data array
		if( tms_data == DATA0 ) {
			if( pbje_data[cur_byte] & (1<<cur_bit) ) {
#ifdef STM_INL6
				TMS_HI();
#else
				exp_byte = TMS_MASK;
#endif
			} else {
#ifdef STM_INL6
				TMS_LO();
#else
				exp_byte = 0;
#endif
			}

#ifndef STM_INL6
			EXP_SET(exp_byte);
#endif

			cur_bit++;
			if( cur_bit == 8) {
				cur_bit = 0;
				cur_byte++;
			}
		}
		
		//clock in TMS value with rising edge of TCK
#ifdef STM_INL6
		TCK_HI();
#else
		exp_byte_temp = exp_byte | TCK_MASK;
		//need to send macro a single byte variable
		EXP_SET(exp_byte_temp);
#endif

		//may need to slow between edges.. depending on max TCK frequency...
		clk_count--;

		//end cycle
#ifdef STM_INL6
		TCK_LO();
#else
		EXP_SET(exp_byte);
#endif

	} while( clk_count != 0x00 ) ;

	//restore TMS low
#ifdef STM_INL6
	TMS_LO();
#else
	EXP_SET(0);
#endif

}

//scan data in & out of JTAG shift register
//tms forced 0 as should be in SHIFT_DR/IR already, leave it there when done
//tdi/tdo data in data array, ingored, or forced 0/1
//numclk contains number of tck clocks to perform
//PRE/POST: TCK is low, all signals low (limit 5v non-tolerance with original kazzos)
void pbje_scan( uint8_t tdi_data, uint8_t tdo_data, uint8_t exit )
{

	//numclk is a sticky value, don't modify!
	uint8_t	clk_count = pbje_numclk;
	uint8_t	cur_byte = 0;
	uint8_t	cur_bit = 0;

	//TDO data may stomp over the top of TDI data
	//need to temporily save tdi byte before it gets stomped
	uint8_t	temp_byte = pbje_data[cur_byte];
	GPIO_PinMask tdo_read;

	//force TMS low to remain in SHIFT-DR/IR state
#ifdef STM_INL6
	TMS_LO();
#else
	exp_byte = 0;
#endif

	//force TDI if not using data array
	if( tdi_data == FORCE0 ) {
#ifdef STM_INL6
		TDI_LO();
#else
		//TDI clear by default
#endif
	} else if ( tdi_data == FORCE1 ) {
#ifdef STM_INL6
		TDI_HI();
#else
		exp_byte |= TDI_MASK;
#endif
	}

#ifndef STM_INL6
	//output to EXP Flopflop for first time
	EXP_SET(exp_byte);
#endif
	do {
		
		//if TDI isn't forced, should be in data array
		if( tdi_data == DATA0 ) {
			if( temp_byte & (1<<cur_bit) ) {
#ifdef STM_INL6
				TDI_HI();
#else
				exp_byte |= TDI_MASK;
#endif
			} else {
#ifdef STM_INL6
				TDI_LO();
#else
				exp_byte &= ~TDI_MASK;
#endif
			}
#ifndef STM_INL6
		EXP_SET(exp_byte);
#endif
		}

		//The first TDO bit should already be shifted out by now
		//it actually spit out on falling TCK edge of entering SHIFT-DR/IR
		//so it's effectively like we read TDO before TCK rising edge as
		//it was shifted out last cycle
		
		//if TDO isn't ignored, need to store in data array
		if( tdo_data == DATA0 ) {

			//if bit0, clear byte so we only have to set bits
			if( cur_bit==0 ) {
				pbje_data[cur_byte] = 0;	
			}

			//TDO value should now be shifted out
			TDO_RD( tdo_read );	//will be 0 if low, non-zero if high

			if( tdo_read ) {
				//TDO was set, store it in data array
				pbje_data[cur_byte] |= 1<<cur_bit;
			}
		}

		clk_count--;

		//clock in TMS & TDI value with rising edge of TCK
		//on the last shift, if exiting, exit SHIFT-DR/IR so TMS must go high
		//This will put statemachine in EXIT1-IR/DR state at the same time the last bit is shifted in
		if( exit && (clk_count == 0)) {
#ifdef STM_INL6
			TMS_HI();
#else
			exp_byte |= TMS_MASK;
			EXP_SET(exp_byte);
#endif
		}


		//clock TCK latching both TMS & TDI
#ifdef STM_INL6
		TCK_HI();
#else
		exp_byte_temp = exp_byte | TCK_MASK;
		//need to send macro a single byte variable
		EXP_SET(exp_byte_temp);
#endif


		//end cycle TDO shifted out on falling edge of TCK
#ifdef STM_INL6
		TCK_LO();
#else
		EXP_SET(exp_byte);
#endif

		//increment bit counter
		cur_bit++;
		if( cur_bit == 8) {
			cur_bit = 0;
			cur_byte++;
			temp_byte = pbje_data[cur_byte];
		}

	} while( clk_count != 0x00 ) ;

	//leave default condition low (better for lack of 5v tolerance)
#ifdef STM_INL6
	TDI_LO();
	TMS_LO();
#else
	EXP_SET(0);
#endif

}

