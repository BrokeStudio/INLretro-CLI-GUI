#include "usbstm.h"
#include "usb_descriptors.h"


//debug use only, should probably move this variable to usb buffer ram if enabling again
//since usb drivers don't use any .data nor .bss space
//static int log = 0;

USBDRIVER void usb_reset_recovery(){

//	USB->CNTR |= USB_CNTR_FRES;
//	USB->CNTR &= ~USB_CNTR_FRES;
	
	//Endpoint-specific registers
	//The number of these registers varies according to the number of endpoints that the USB peripheral is designed to handle. 
	//The USB peripheral supports up to 8 bidirectional endpoints. Each USB device must support a control endpoint whose 
	//address (EA bits) must be set to 0. The USB peripheral behaves in an undefined way if multiple endpoints 
	//are enabled having the same endpoint number value. For each endpoint, an USB_EPnR register is available to store 
	//the endpoint specific information.
	
	//Enable the USB device and set address to zero
	//USB device address (USB_DADDR)
	//bit7 must be set to enable USB functionality, bits 6:0 are the address, must be 0 prior to enumeration
	USB->DADDR = (uint16_t) USB_DADDR_EF;

	//They are also reset when an USB reset is received from the USB bus or forced through bit FRES in the CTLR register, 
	//except the CTR_RX and CTR_TX bits, which are kept unchanged to avoid missing a correct packet notification 
	//immediately followed by an USB reset event. Each endpoint has its USB_EPnR register where n is the endpoint identifier.
	//Read-modify-write cycles on these registers should be avoided because between the read and the write operations 
	//some bits could be set by the hardware and the next write would modify them before the CPU has the time to detect the change. 
	//For this purpose, all bits affected by this problem have an "invariant" value that must be used whenever their 
	//modification is not required. It is recommended to modify these registers with a load instruction where all the bits, 
	//which can be modified only by the hardware, are written with their "invariant" value.
	//
	//USB endpoint n register (USB_EPnR), n=[0..7]
	//Address offset: 0x00 to 0x1C
	//Reset value: 0x0000
	//
	//Bit 15 CTR_RX: Correct Transfer for reception
	//	Hardware sets on successful completetion of OUT/SETUP transaction
	//	a failed transaction won't set this bit
	//	Software can only clear this bit
	//	SETUP bit11 signifies if OUT/SETUP was received
	// USE: read this bit after interrupt to determine/verify interrupt was due to success
	//	service OUT/SETUP packet then clear the bit so subsequent interrupt can be detected properly
	// write 0 to clear, write 1 to leave as-is
	//
	//Bit 14 DTOG_RX: Data Toggle, for reception transfers
	//	For non-isosync xfrs this bit contains Data0/1 expectation of next data packet
	//	Hardware toggles this bit after ACK'ing the host from successful PID match
	//	For control EPs HW clears this bit after receiving SETUP PID
	//	For double buffered, or isosync EPs this bit has other meanings
	//	Software can toggle this value by writting a 1, writting 0 has no effect. 
	//	-This is manditory for non-control EPs!
	// USE: For control endpoints: Seems this bit can be used to determine if upcoming xfr is DATA0/1
	// 	Shouldn't have to do/care much with this bit for control endpoints
	// write 1 to toggle, write 0 to leave as-is
	//
	//
	//Bits 13:12 STAT_RX [1:0]: Status bits, for reception transfers
	//	00: Disabled, all reception requests to this EP are ignored (default post-reset)
	//	01: Stall, EP is stalled and all reception requests will get STALL handshake
	//	10: NAK, all reception requests will get NAK handshake
	//	11: Valid, this endpoint is enabled for reception
	//	Hardware sets these bits to NAK after successful OUT/SETUP xfr
	//	Software can toggle these bits by writting a 1, writting 0 has no effect
	// USE: to enable the endpoint toggle these bits to set.  HW will clear bit12 when xfr is recieved.
	// 	That way subsequent xfrs will get NAK'd until software processes EP and ready's it for another.
	// 	Once processed toggle back to VALID so next xfr can occur
	// write 1 to toggle, write 0 to leave as-is
	//
	//
	//Bit 11 SETUP: Setup transaction completed
	//	This bit is read-only and indicates if last completed transaction was a SETUP.
	//	This bit only gets set for control endpoints.  It remains set while CTR_RX is set.
	// USE: For control EPs read this bit to determine if received xfr is SETUP or OUT.
	// writes have no effect, read only
	//
	//Bits 10:9 EP_TYPE[1:0]: Endpoint type
	//	00: BULK
	//	01: CONTROL
	//	10: ISO
	//	11: INTERRUPT
	//	EP0 must always be CONTROL and always available (set by address==0)
	// USE: set these bits to desired endpoint type.  Hardware uses these bits to dictate it's behavior.
	// bits are read/write, RMW to leave as is
	//
	//Bit 8 EP_KIND: Endpoint kind
	//	BULK: DBL_BUF, this bit is set by software to indicate double buffered EP
	//	CONTROL: STATUS_OUT, this bit is set by software to indicate that STATUS_OUT is expected.
	//		This will cause all OUT transactions with more than zero data bytes to be STALL'd instead of ACK.
	//		When clear, OUT transactions of any data length will be allowed.
	//	ISO/INT: unused
	// USE: set for BULK EPs if want to double buffer the endpoint
	// 	set for CONTROL EPs for robustness, when a STATUS_OUT is expected and want non-zero data to be STALL'd
	// 	Think we can get by ignoring this bit for now
	// bit is read/write, RMW to leave as-is
	// 	
	//Bit 7 CTR_TX: Correct Transfer for transmission
	//	Similar to CTR_RX, but for transmissions.  Hardware sets this bit on successful transmission completion.
	//	This won't get set if transfer failed.  Software can only write this bit to 0.
	// USE: read this bit after interrupt to determine if source of interrupt was due to successful transmission.
	// 	process what's needed for upcoming transmission if needed, and clear this bit to subsequent interrupts 
	// 	will be properly detected.
	// write 0 to clear, write 1 to leave as-is
	//
	//
	//Bit 6 DTOG_TX: Data Toggle, for transmission transfers
	//	Similar to DTOG_RX, but for transmissions.  Hardware toggles this bit after an ACK of data transmit.
	//	For control EPs HW sets this bit at reception of SETUP PID
	//	For double buffered, and iso EPs this bit has different functions
	//	Software can toggle this bit by writting a 1, writting 0 is ignored.  Required for non-control EPs
	// USE: should be able to ignore for control EPs.  
	// To leave as-is write a 0.
	//
	//Bits 5:4 STAT_TX [1:0]: Status bits, for transmission transfers
	//	00: Disabled, all transmission requests to this EP are ignored (default post-reset)
	//	01: Stall, EP is stalled and all transmission requests will get STALL handshake
	//	10: NAK, all transmission requests will get NAK handshake
	//	11: Valid, this endpoint is enabled for transmission
	//	Hardware changes these bits from Valid to NAK after successful transmission.
	//	That way subsequent transmit requests will be NAK'd until software can prepare the next one.
	//	These bits will toggle when wrote to with a 1, writting a 0 doesn't affect them.
	// USE: Toggle the bits to Valid when data has been loaded into buffer and ready for transmission.
	// write 1 to toggle, write 0 to leave as-is
	//
	//Bits 3:0 EA[3:0]: Endpoint address
	//	Software must write the address to these bits to enable the endpoint.
	// USE: set these bits to the "endpoint number" ie 0 for EP0, 1 for EP1, etc.
	// 	These default to 0, so post reset all USB_EPnR are set to be EP0.
	// 	But because nothing is initialized they'll all ignore anything going on.
	// bits are read/write, RMW to leave as is
	
	//Reset done, now setup as if USB reset has occured
	//USB reset (RESET interrupt)
	//When this event occurs, the USB peripheral is put in the same conditions it is left by the system 
	//reset after the initialization described in the previous paragraph: communication is disabled in all 
	//endpoint registers (the USB peripheral will not respond to any packet). 
	//As a response to the USB reset event, the USB function must be enabled, having as USB address 0, 
	//implementing only the default control endpoint (endpoint address is 0 too). 
	//This is accomplished by setting the Enable Function (EF) bit of the USB_DADDR register and 
	//initializing the EP0R register and its related packet buffers accordingly. 
	//
	//During USB enumeration process, the host assigns a unique address to this device, 
	//which must be written in the ADD[6:0] bits of the USB_DADDR register, and configures any other necessary endpoint.
	//When a RESET interrupt is received, the application software is responsible to enable again 
	//the default endpoint of USB function 0 within 10 ms from the end of reset sequence which triggered the interrupt.
	
	//clear any pending interrupts
	USB->ISTR = 0;
	
	//initialize EP specific register for EP0 as CONTROL and ready for RX of any OUT
	//assuming reset condition with all bits clear, except CTR_RX/TX holding prior to reset value
	USB->EP0R = (uint16_t) (USB_EP_RX_VALID | USB_EP_CONTROL | USB_EP_TX_NAK);
	//clears CTR_RX/TX bits, ready to recieve, transmit disabled, sets to control type, expect any out, set addr to EP0
	//
	


}


//Create pointer to 16bit array with 512 entries (1024Bytes)
//can only be accessed in byte or half words, not full 32bit words!
//uint16_t volatile (* const usb_buff)[512] = (void*)USB_PMAADDR; 
//this was suggestion by: http://a3f.at/articles/register-syntax-sugar
//which errors on compilation due to assigning of type array
uint16_t volatile (* const usb_buff) = (void*)USB_PMAADDR;


//static uint16_t num_bytes_req;
#define num_bytes_req  		usb_buff[NUM_BYTES_REQ]		//place this variable in USB RAM

//static uint16_t num_bytes_sending;
#define num_bytes_sending  	usb_buff[NUM_BYTES_SENDING]	//place this variable in USB RAM

//static uint16_t num_bytes_expecting;		//this was never used, so it was cut
//#define num_bytes_expecting  	usb_buff[NUM_BYTES_EXPECTING]	//place this variable in USB RAM

//static uint16_t num_bytes_xfrd;
#define num_bytes_xfrd  	usb_buff[NUM_BYTES_XFRD]	//place this variable in USB RAM



//flag and value, since can't change address until after STATUS stage, must use this value
//to denote that the USB device address needs updated after the status stage.
//static uint8_t new_address = 0;	placed in upper byte of newaddr_reqtype
//place this variable in the upper byte of reqtype, 
//but it's prob important to ensure it's cleared & init

//these variables are used together, so let's place them in the same usb_buff index
//static uint8_t reqtype = 0;
//static uint8_t reqdir = 0;
//they're actual bit masks of the same bmRequestType byte, so really don't need separate bytes
#define newaddr_reqtype  usb_buff[NEWADDR_REQTYPE]	//place this variable in USB RAM


//static uint8_t	req_dir;
#define req_dir  usb_buff[VAR_REQ_DIR]	//place this variable in USB RAM

//move this into USB buffer ram, definition kept in usbstm.h so application code can import it
//usbMsgPtr_t usbMsgPtr;
//#define usbMsgPtr_L  usb_buff[USBMSGPTR_L]	//place this variable in USB RAM
//#define usbMsgPtr_H  usb_buff[USBMSGPTR_H]	//place this variable in USB RAM


//#define TSSOP20	//defined when using TSSOP-20 part to get PA11/12 alternate mapping to the pins

//prereq: USB block's clock must be initialized prior to calling
USBDRIVER void init_usb()
{

	//initialize the clock
	//init_usb_clock();
	//couldn't get this to work for some reason.. 
	//leaving it up to the main to turn on the USB clock

	//clear variables stored in USB ram since can't rely on .bss clearning them anymore
	//Don't think most of these actually need to be cleared.. newaddr_reqtype might be only one..
	num_bytes_req = 0;
	num_bytes_sending = 0; 	
	//num_bytes_expecting = 0; 	
	num_bytes_xfrd = 0;
	newaddr_reqtype = 0;	//two single byte variables stored in single 16bit half word
	req_dir = 0;	
	//usbMsgPtr_H/L shouldn't need pre-initialized

	//initialize i/o
	// TSSOP-20: On STM32F070x6 devices, pin pair PA11/12 can be remapped instead of pin pair PA9/10 using SYSCFG_CFGR1 register.
#ifdef TSSOP20
	//by default PA9/10 are configured to pins 17/18, have to set bits to map PA11/12 which contain USB PHY
	SYSCFG->CFGR1 |= PA11_PA12_RMP;
#endif
	//
	// ensure GPIO bank A is enabled after the discussion below, I'm not even sure this is needed..
//	RCC->AHBENR |= (uint32_t) (1<<IOPAEN);
	// set GPIO alternate function to USB
	// Can't find the USB alternate function mapping on the datasheets!
	// Not sure how this is supposed to work..
	// Considering the USB PHY are terminated, they don't lend themselves well to the basic GPIO structure
	// which can be taken over by common alternate functions.  Wondering if the PHY are hardwired to the pins.
	// If that were the case, then really just need to make sure the USB GPIO are left floating inputs at reset/default.
	// Can't find anything in the datasheet that explains this so I'm left to assume there's nothing to do
	// As the only other thing I can do is take wild stabs in the dark as to what alternate function mapping is needed..
	// Considering the USB PHY has it's own power and clock supply, this logic seems reasonable enough
	

	//reset USB device and release, don't think this is needed, but I'm at a loss of what's wrong...
//	RCC->APB1RSTR |= RCC_APB1RSTR_USBRST;	//reset
//	RCC->APB1RSTR &= ~RCC_APB1RSTR_USBRST;	//release reset


	//Sections copied from reference manual
	//As a first step application software needs to activate register macrocell clock and de-assert 
	//macrocell specific reset signal using related control bits provided by device clock management logic.
	//
	//clock was already done in init_usb_clk function.
	//de-assert translates to set reset high I believe, but I'm still not sure I understand.
	//The next section talks about removing the reset condition with FRES/CNTR reg, but that can't be done yet.
	//So I think it's just covering bases to say the RCC_APB1RSTR register can't be set "in reset condition"
	//Actually I think this section of the datasheet is referring to how the first thing a host does once
	//a device is detected is send it a reset condition (lack of SOF packets) and as this code is being ran that
	//has yet to occur.  So we need to set things up to expect the first "USB command" to be recieved via the cable
	//as reset which equates to enabling the reset interrupt and having it call reset recovery routine.
	
	//After that, the analog part of the device related to the USB transceiver must be 
	//switched on using the PDWN bit in CNTR register, which requires a special handling. 
	USB->CNTR &= ~USB_CNTR_PDWN; //default is set, clear to power up USB

	//This bit is intended to switch on the internal voltage references that supply the port transceiver. 
	//This circuit has a defined startup time (tSTARTUP specified in the datasheet) tSTARTUP = 1usec
	//during which the behavior of the USB transceiver is not defined. 
	int delay = 0;
	for( delay = 0; delay < 48; delay++ ){
		//16Mhz = 62.5nsec clock, 1usec = 1Mhz
		//need 16 clocks to delay 1usec this loop will take a few instruction cycles at least
		//Perhaps this code will be ran while the core is running at 48Mhz
		//So future proof by waiting 3 times as long
	}

	//It is thus necessary to wait this time, after setting the PDWN bit in the CNTR register, 
	//before removing the reset condition on the USB part (by clearing the FRES bit in the CNTR register). 
	USB->CNTR &= ~USB_CNTR_FRES; //default set, clear to remove reset
	
	//Clearing the ISTR register then removes any spurious pending interrupt before any other macrocell operation is enabled.
	//Entire register is read, or clear by writing 0.
	USB->ISTR = 0;

	//At system reset, the microcontroller must initialize all required registers and the packet buffer description table, 
	//to make the USB peripheral able to properly generate interrupts and data transfers. 
	//
	//Structure and usage of packet buffers
	//Each bidirectional endpoint may receive or transmit data from/to the host. The received data 
	//is stored in a dedicated memory buffer reserved for that endpoint, while another memory
	//buffer contains the data to be transmitted by the endpoint. Access to this memory is
	//performed by the packet buffer interface block, which delivers a memory access request
	//and waits for its acknowledgment. Since the packet buffer memory has to be accessed by
	//the microcontroller also, an arbitration logic takes care of the access conflicts, using half
	//APB cycle for microcontroller access and the remaining half for the USB peripheral access.
	//In this way, both the agents can operate as if the packet memory is a dual-port SRAM,
	//without being aware of any conflict even when the microcontroller is performing back-to-
	//back accesses. The USB peripheral logic uses a dedicated clock. The frequency of this
	//dedicated clock is fixed by the requirements of the USB standard at 48 MHz, and this can be 
	//different from the clock used for the interface to the APB bus. Different clock configurations 
	//are possible where the APB clock frequency can be higher or lower than the USB peripheral
	//one.
	//
	//Note: Due to USB data rate and packet memory interface requirements, the APB clock must have a minimum 
	//frequency of 10 MHz to avoid data overrun/underrun problems.
	//
	//Each endpoint is associated with two packet buffers (usually one for transmission and the
	//other one for reception). Buffers can be placed anywhere inside the packet memory
	//because their location and size is specified in a buffer description table, which is also
	//located in the packet memory at the address indicated by the USB_BTABLE register. 
	//
	//Each table entry is associated to an endpoint register and it is composed of four 16-bit half-words
	//so that table start address must always be aligned to an 8-byte boundary (the lowest three
	//bits of USB_BTABLE register are always "000"). Buffer descriptor table entries are
	//described in the Section30.6.2: Buffer descriptor table. If an endpoint is unidirectional and it
	//is neither an Isochronous nor a double-buffered bulk, only one packet buffer is required 
	//(the one related to the supported transfer direction). Other table locations related to unsupported 
	//transfer directions or unused endpoints, are available to the user. Isochronous and double-
	//buffered bulk endpoints have special handling of packet buffers (Refer to Section 30.5.4:
	//Isochronous transfers and Section 30.5.3: Double-buffered endpoints respectively). The
	//relationship between buffer description table entries and packet buffer areas is depicted in Figure323.
	//
	//Each packet buffer is used either during reception or transmission starting from the bottom.
	//The USB peripheral will never change the contents of memory locations adjacent to the
	//allocated memory buffers; if a packet bigger than the allocated buffer length is received
	//(buffer overrun condition) the data will be copied to the memory only up to the last available
	//location.
	//
	//Buffer descriptor table
	//Although the buffer descriptor table is located inside the packet buffer memory, its entries
	//can be considered as additional registers used to configure the location and size of the
	//packet buffers used to exchange data between the USB macro cell and the device.
	//The first packet memory location is located at 0x40006000. The buffer descriptor table
	//entry associated with the USB_EPnR registers is described below. The packet memory
	//should be accessed only by byte (8-bit) or half-word (16-bit) accesses. Word (32-bit) accesses are not allowed.
	//
	//Buffer table address (USB_BTABLE) this is the address of the buffer table which is contained in the 1KB of RAM itself
	//By default this value is set to zero, that's what I would have choosen anyway, so doesn't need initialized
	//But let's go ahead and do it so it's easy to move later if needed and gives us defines to use for addressing
	USB->BTABLE = USB_BTABLE_ADDR;

	
	//Endpoint initialization
	//The first step to initialize an endpoint is to write appropriate values to the ADDRn_TX/ADDRn_RX registers 
	//so that the USB peripheral finds the data to be transmitted already available and the data to be received can be buffered. 
	//The EP_TYPE bits in the USB_EPnR register must be set according to the endpoint type, eventually using 
	//the EP_KIND bit to enable any special required feature. 
	//On the transmit side, the endpoint must be enabled using the STAT_TX bits in the USB_EPnR register 
	//and COUNTn_TX must be initialized. 
	//For reception, STAT_RX bits must be set to enable reception and COUNTn_RX must be written with 
	//the allocated buffer size using the BL_SIZE and NUM_BLOCK fields.
	
	//only setup endpoint zero buffers for now that's all that's required to satisfy USB and get started
	usb_buff[USB_ADDR0_TX] = EP0_TX_ADDR;
	//TX count is set to the number of bytes to xfr in next packet
	//usb_buff[USB_COUNT0_TX] = EP0_SIZE;
	usb_buff[USB_ADDR0_RX] = EP0_RX_ADDR;
	//RX count is made up of 3 parts
	//the MSB is block size 0->2Bytes, 1->32Bytes
	//bit 14:10 is number of blocks
	//end point size = block size * num blocks
	//bits 9:0 are set by USB block based on actual count received
	//usb_buff[USB_COUNT0_RX] = (uint16_t) ((BL_SIZE2) | ((EP0_SIZE/2)<<NUM_BLOCKS)) ;	//set EP0 to 8 bytes
	//usb_buff[USB_COUNT0_RX] = USB_RX_8BYTES; //set EP0 to 8 bytes
	usb_buff[USB_COUNT0_RX] = USB_RX_2TO62_MUL2B(EP0_SIZE); //set EP0 to 8 bytes or whatever it's defined as


	//Clear buffers for debug purposes
//	usb_buff[EP0_TX_BASE] = (uint16_t) 0x1111;
//	usb_buff[EP0_TX_BASE+1] = (uint16_t) 0x2222;
//	usb_buff[EP0_TX_BASE+2] = (uint16_t) 0x3333;
//	usb_buff[EP0_TX_BASE+3] = (uint16_t) 0x4444;
//
//	usb_buff[EP0_RX_BASE] = (uint16_t) 0x5555;
//	usb_buff[EP0_RX_BASE+1] = (uint16_t) 0x6666;
//	usb_buff[EP0_RX_BASE+2] = (uint16_t) 0x7777;
//	usb_buff[EP0_RX_BASE+3] = (uint16_t) 0x8888;


	//All registers not specific to any endpoint must be initialized according to the needs of application software 
	//(choice of enabled interrupts, chosen address of packet buffers, etc.). 
	//Then the process continues as for the USB reset case (see further paragraph).
	
	
	//initialize all registers not specific to any endpoint
	//
	//LPM control and status register (USB_LPMCSR)
	//Link power management, this is disabled by default, lets leave it that way.
	

	
	//now all the registers and buffers are setup so endpoint specific registers can be set
	usb_reset_recovery();

	NVIC_EnableIRQ( USB_IRQn );

	//enable interrupts
	//USB control register (USB_CNTR)
	//only enable interrupts for correct transfers for now
//	USB->CNTR |= (USB_CNTR_CTRM | USB_CNTR_PMAOVRM | USB_CNTR_ERRM | USB_CNTR_WKUPM |
//			USB_CNTR_SUSPM | USB_CNTR_RESETM | USB_CNTR_SOFM | USB_CNTR_ESOFM | USB_CNTR_L1REQM ); 	
	USB->CNTR |= ( USB_CNTR_RESETM );
	//USB control register (USB_ISTR) will indicate what endpoint and direction created the interrupt
	//Apparently you don't even need to set the CTRM interrupt as it's not of much use
	//The EP0R register creates it's own interrupt which is always enabled upon completion of transfer
	//The ITSR is still useful for determining which EP and dir of transfer that occured.
	//Having the reset interrupt is vital as apparently the first thing that occurs over the USB bus is a reset.
	//Not sure if that's caused by the host intentionally, or just the nature of hot plugging where some
	//SOF's are missed during the mating of the connectors or what.  Banged my head for awhile till actually
	//serviced the reset interrupt as needed
	
	//Battery charging detector (USB_BCDR)
	//Bit 15 DPPU: DP pull-up control
	//This bit is set by software to enable the embedded pull-up on the DP line. Clearing it to Î÷Îõ0ÎéÎ÷
	//can be used to signalize disconnect to the host when needed by the user software.
	//all other bits have to do with battery charging which is off by default
	//
	//Enable the data plus pull up resistor to signal to host that USB device is connected
	USB->BCDR = USB_BCDR_DPPU;
}



//function gets called after reception of setup packet for IN transfer,
//and each time an interrupt for successful data tx from control EP
//So it's as if this function gets called *AFTER* each transmission
//Therefore it's task is to prep the next transmission should there be one needed
//If we don't need another transmission, prepare to receive status from host
//currently hardcoded for EP0 only
//num_bytes_sending, num_bytes_xfrd, and *usbMsgPtr must be initialized prior to entry

USBDRIVER static void control_xfr_in(){
	//determine if have data remaining to be sent
	
// We should never get to this point, if we did there was an error and should prob send STALL
//	if ( num_bytes_xfrd == num_bytes_sending ) {
//		//no more data to send
//		//wrap up transfer and prep endpoint for next setup packet
//		//
//		//While enabling the last data stage, the opposite direction should be set to NAK, so that, if
//		//the host reverses the transfer direction (to perform the status stage) immediately, it is kept
//		//waiting for the completion of the control operation. If the control operation completes
//		//successfully, the software will change NAK to VALID, otherwise to STALL. At the same time,
//		//if the status stage will be an OUT, the STATUS_OUT (EP_KIND in the USB_EPnR register)
//		//bit should be set, so that an error is generated if a status transaction is performed with not-
//		//zero data. When the status transaction is serviced, the application clears the STATUS_OUT
//		//bit and sets STAT_RX to VALID (to accept a new command) and STAT_TX to NAK (to delay
//		//a possible status stage immediately following the next setup).
//
//		return;
//	}

	//need a usbMsgPtr but want it to be a variable from the stack
	usbMsgPtr_t usbMsgPtr_temp;
	//copy the actual pointer from usb_buffer ram
	//the usb_buffer ram can only be accessed in halfwords (16bits)
	//so this assigment respects this and then casts it to the necessary pointer type
	usbMsgPtr_temp = (uint16_t *) ((usbMsgPtr_H<<16) | usbMsgPtr_L);
	
	//copy over 8bytes from transmit data to EP0 buffer
	//copy data into EP0 buffer table ram
	//usb buffer ram is only accessible in halfwords/bytes (16/8bits)
	usb_buff[EP0_TX_BASE] 	= usbMsgPtr_temp[num_bytes_xfrd/2];
	num_bytes_xfrd += 2;
	usb_buff[EP0_TX_BASE+1] = usbMsgPtr_temp[num_bytes_xfrd/2];
	num_bytes_xfrd += 2;
	usb_buff[EP0_TX_BASE+2] = usbMsgPtr_temp[num_bytes_xfrd/2];
	num_bytes_xfrd += 2;
	usb_buff[EP0_TX_BASE+3] = usbMsgPtr_temp[num_bytes_xfrd/2];
	num_bytes_xfrd += 2;

	//if there aren't 8bytes of data to send, junk will be copied into end of EP0 TX buffer
	//to correct for this, simply set tx count to amount of good data
	if ( num_bytes_xfrd > num_bytes_sending ) {
		//set tx count to number of bytes we actually want to send
		usb_buff[USB_COUNT0_TX] = EP0_SIZE - (num_bytes_xfrd - num_bytes_sending);
		//stop lying about how many bytes will be sent
		num_bytes_xfrd = num_bytes_sending;
	} else if ( num_bytes_req < num_bytes_xfrd ) {
		//set tx count to number bytes requested since host didn't want everything
		usb_buff[USB_COUNT0_TX] = EP0_SIZE - (num_bytes_xfrd - num_bytes_req);
		num_bytes_xfrd = num_bytes_req;
	} else {
		//update tx count
		usb_buff[USB_COUNT0_TX] = EP0_SIZE;
	}

//	if (num_bytes_xfrd == num_bytes_sending ) {
//		//expect next token to be OUT STATUS zero data length from host to end transaction
//		//setting EP_KIND to STATUS_OUT:
//		//STATUS_OUT: This bit is set by the software to indicate that a status out transaction is
//		//expected: in this case all OUT transactions containing more than zero data bytes are
//		//answered "STALL" instead of "ACK". This bit may be used to improve the robustness of the
//		//application to protocol errors during control transfers and its usage is intended for control
//		//endpoints only. When STATUS_OUT is reset, OUT transactions can have any number of
//		//bytes, as required.
//
//		//Don't really feel like doing this on only the last packet, and really should be fine without it.
//		//The host doesn't always take all the data it asks for in the setup packet, sometimes it simply
//		//sends an OUT in the midst of large IN xfr asking the device to end current transfer
//		//This seems like something we should just do during init of SETUP with IN xfr to follow.
//	}


	//setup EP0R for transmit
	USB_EP0R_TX_VALID();

	return;
}

	//Need to decode the setup packet to determine what type of standard request was made
	//Beyondlogic.com's USB in a nutshell is the best resource for this stuff:
	//http://www.beyondlogic.org/usbnutshell/usb6.shtml
	//
	//
	//STANDARD DEVICE REQUESTS
	//bmRequestType bRequest (1Byte)		wValue (2Bytes)		wIndex (2Bytes)		wLength (2Bytes)	Data(based on SETUP)
	//1000 0000b 	GET_STATUS (0x00) 		Zero 			Zero 			Two 			Device Status
#define STD_REQ_GET_STATUS	0x00
	//0000 0000b 	CLEAR_FEATURE (0x01) 		Feature Selector 	Zero 			Zero 			None
#define STD_REQ_CLEAR_FEATURE	0x01
	//0000 0000b 	SET_FEATURE (0x03) 		Feature Selector 	Zero 			Zero 			None
#define STD_REQ_SET_FEATURE	0x03
	//0000 0000b 	SET_ADDRESS (0x05) 		Device Address 		Zero 			Zero 			None
#define STD_REQ_SET_ADDRESS	0x05
	//1000 0000b 	GET_DESCRIPTOR (0x06) 		Descriptor Type & Index Zero or Language ID 	Descriptor Length 	Descriptor
#define STD_REQ_GET_DESCRIPTOR	0x06
	//0000 0000b 	SET_DESCRIPTOR (0x07) 		Descriptor Type & Index Zero or Language ID 	Descriptor Length 	Descriptor
#define STD_REQ_SET_DESCRIPTOR	0x07
	//1000 0000b 	GET_CONFIGURATION (0x08) 	Zero 			Zero 			1 			Configuration Value
#define STD_REQ_GET_CONFIGURATION	0x08
	//0000 0000b 	SET_CONFIGURATION (0x09) 	Configuration Value 	Zero 			Zero 			None
#define STD_REQ_SET_CONFIGURATION	0x09
	//
	//
	//	The Get Status request directed at the device will return two bytes during the data stage with the following format,
	//        D15 - D2 	D1 		D0
	//        Reserved 	Remote Wakeup 	Self Powered
	//	If D0 is set, then this indicates the device is self powered. If clear, the device is bus powered. If D1 is set, 
	//	the device has remote wakeup enabled and can wake the host up during suspend. The remote wakeup bit can be by the 
	//	SetFeature and ClearFeature requests with a feature selector of DEVICE_REMOTE_WAKEUP (0x01)
	//
	//	Clear Feature and Set Feature requests can be used to set boolean features. When the designated recipient is the device, 
	//	the only two feature selectors available are DEVICE_REMOTE_WAKEUP and TEST_MODE. Test mode allows the device to exhibit 
	//	various conditions. These are further documented in the USB Specification Revision 2.0.
	//
	//
	//	Set Descriptor/Get Descriptor is used to return the specified descriptor in wValue. A request for the configuration 
	//	descriptor will return the device descriptor and all interface and endpoint descriptors in the one request.
	//		Endpoint Descriptors cannot be accessed directly by a GetDescriptor/SetDescriptor Request.
	//		Interface Descriptors cannot be accessed directly by a GetDescriptor/SetDescriptor Request.
	//		String Descriptors include a Language ID in wIndex to allow for multiple language support.
	//
	//	Get Configuration/Set Configuration is used to request or set the current device configuration. In the case of a 
	//	Get Configuration request, a byte will be returned during the data stage indicating the devices status. A zero value 
	//	means the device is not configured and a non-zero value indicates the device is configured. 
	//	Set Configuration is used to enable a device. It should contain the value of bConfigurationValue of the desired 
	//	configuration descriptor in the lower byte of wValue to select which configuration to enable.
	//

//void control_xfr_out(uint16_t len){
//
//	usbFunctionWrite(
//
//}


//return number of bytes expected
USBDRIVER static uint16_t standard_req_out( usbRequest_t *spacket ){

	switch ( spacket->bRequest ) {

	//STANDARD DEVICE REQUESTS
	//bmRequestType bRequest (1Byte)		wValue (2Bytes)		wIndex (2Bytes)		wLength (2Bytes)	Data(based on SETUP)
	//0000 0000b 	CLEAR_FEATURE (0x01) 		Feature Selector 	Zero 			Zero 			None
		case STD_REQ_CLEAR_FEATURE:
			break;

	//0000 0000b 	SET_FEATURE (0x03) 		Feature Selector 	Zero 			Zero 			None
		case STD_REQ_SET_FEATURE:
			break;

	//0000 0000b 	SET_ADDRESS (0x05) 		Device Address 		Zero 			Zero 			None
	//	Set Address is used during enumeration to assign a unique address to the USB device. The address is specified in wValue 
	//	and can only be a maximum of 127. This request is unique in that the device does not set its address until after the 
	//	completion of the status stage. (See Control Transfers.) All other requests must complete before the status stage.
		case STD_REQ_SET_ADDRESS:
			//new_address = spacket->wValue;
			//store in upper byte of usb ram variable
			newaddr_reqtype = (newaddr_reqtype & 0x00FF) | ((spacket->wValue)<<8);
			//debug logging usb_buff[LOG0] = new_address;
			return 0;
			break;

	//0000 0000b 	SET_DESCRIPTOR (0x07) 		Descriptor Type & Index Zero or Language ID 	Descriptor Length 	Descriptor
		case STD_REQ_GET_CONFIGURATION:
			break;

	//0000 0000b 	SET_CONFIGURATION (0x09) 	Configuration Value 	Zero 			Zero 			None
		case STD_REQ_SET_CONFIGURATION:
			break;

		default:
			//ERROR send STALL?
			break;

	}



}

USBDRIVER static uint16_t standard_req_in( usbRequest_t *spacket ){

	switch ( spacket->bRequest ) {

	//STANDARD DEVICE REQUESTS
	//bmRequestType bRequest (1Byte)		wValue (2Bytes)		wIndex (2Bytes)		wLength (2Bytes)	Data(based on SETUP)
	//1000 0000b 	GET_STATUS (0x00) 		Zero 			Zero 			Two 			Device Status
		case STD_REQ_GET_STATUS:
			break;

	//1000 0000b 	GET_DESCRIPTOR (0x06) 		Descriptor Type & Index Zero or Language ID 	Descriptor Length 	Descriptor
		case STD_REQ_GET_DESCRIPTOR:
			switch ( (spacket->wValue & DESC_TYPE_MASK)>>8) {	//must mask out upper byte and shift to get desc type
				case DESC_TYPE_DEVICE:
					//usbMsgPtr = (uint16_t *)device_desc;
					//set the usb_buff[] message ptr instead..
					//this works, but requires assingment above
					//usbMsgPtr_L = (uint32_t)usbMsgPtr;
					//usbMsgPtr_H = ((uint32_t)usbMsgPtr)>>16;

					//do the same but without the use of an actual usbMsgPtr
					//first the const array (which is actually a pointer), is cast to a 
					//16bit pointer.  Then that pointer is cast to an int and assinged
					//to the usb_buff ram/index.
					//the upper 16bits needs to get shifted prior to assignment
					usbMsgPtr_L = (uint32_t)(uint16_t *)device_desc;
					usbMsgPtr_H = ((uint32_t)(uint16_t *)device_desc)>>16;

					return device_desc[bLength];

				case DESC_TYPE_CONFIG:	//Must return all config, interface, and endpoint descriptors in one shot
					//usbMsgPtr = (uint16_t *)config_desc;
					usbMsgPtr_L = (uint32_t)(uint16_t *)config_desc;
					usbMsgPtr_H = ((uint32_t)(uint16_t *)config_desc)>>16;
					return config_desc[wTotalLength];

				case DESC_TYPE_STRING:
					//determine which string index
					switch ( spacket->wValue & DESC_IDX_MASK ) { //Must mask out index from lower byte
						case 0: //usbMsgPtr = (uint16_t *)string0_desc;
							usbMsgPtr_L = (uint32_t)(uint16_t *)string0_desc;
							usbMsgPtr_H = ((uint32_t)(uint16_t *)string0_desc)>>16;
							return string0_desc[bLength];
						case 1: //usbMsgPtr = (uint16_t *)string1_desc;
							usbMsgPtr_L = (uint32_t)(uint16_t *)string1_desc;
							usbMsgPtr_H = ((uint32_t)(uint16_t *)string1_desc)>>16;
							return string1_desc[bLength];
						case 2: //usbMsgPtr = (uint16_t *)string2_desc;
							usbMsgPtr_L = (uint32_t)(uint16_t *)string2_desc;
							usbMsgPtr_H = ((uint32_t)(uint16_t *)string2_desc)>>16;
							return string2_desc[bLength];
						default: //error send stall
							return 0;
					}
			// interface and endpoint descriptors can't be accessed directly, get them via config desc
			//	case DESC_TYPE_INTERFACE:
			//		usbMsgPtr = (uint16_t *)interface_desc;
			//		return interface_desc[bLength];
			//	case DESC_TYPE_ENDPOINT:
			//		usbMsgPtr = (uint16_t *)endpoint_desc;
			//		return endpoint_desc[bLength];
				default:
					//TODO error send stall
					return 0;
			}

	//1000 0000b 	GET_CONFIGURATION (0x08) 	Zero 			Zero 			1 			Configuration Value
		case STD_REQ_GET_CONFIGURATION:
			break;

	}

	//just return device descriptor for now


}

//USB IRQ handler calls this function after recieving a control setup packet
//function is responsible for preparing follow on data/status transfers to complete control xfr
//must set everything up for control_xfr_in/out functions to be called during data packets
USBDRIVER static void control_xfr_init( usbRequest_t *spacket ) {

	//determine number of requested data payload bytes
	num_bytes_req = spacket->wLength;
	num_bytes_xfrd = 0;

	//Vusb calls usbFunctionSetup which sets usbMsgPtr to point to IN data array
	//and returns length of data to be returned.
	//Vusb needs nothing else for IN transfers as it already has the data
	//Vusb calls usbFunctionWrite for OUT xfr on subsequent of data packet arrival (8bytes max)

	//if data is IN (tx) need to aquire pointer to data that we'd like to transmit
	//don't think we'll get a zero data length IN as that would mean the host sends all packets
	//I suppose this is possible for poorly written host application..?
	//Vusb had option to provide function that would be called for each IN data packet
	//I found that to be slow and best avoided, so not going to bother supporting that for now..
	//Also need to get amount of data that the device would like to return, possible the
	//device has less data to send back than requested in wLength.
	
	
/*USB_PUBLIC usbMsgLen_t usbFunctionSetup(uchar data[8]);
 * If the SETUP indicates a control-in transfer, you should provide the
 * requested data to the driver. There are two ways to transfer this data:
 * (1) Set the global pointer 'usbMsgPtr' to the base of the static RAM data
 * block and return the length of the data in 'usbFunctionSetup()'. The driver
 * will handle the rest. Or (2) return USB_NO_MSG in 'usbFunctionSetup()'. The
 * driver will then call 'usbFunctionRead()' when data is needed. See the
 * documentation for usbFunctionRead() for details.
 *
 * If the SETUP indicates a control-out transfer, the only way to receive the
 * data from the host is through the 'usbFunctionWrite()' call. If you
 * implement this function, you must return USB_NO_MSG in 'usbFunctionSetup()'
 * to indicate that 'usbFunctionWrite()' should be used. See the documentation
 * of this function for more information. If you just want to ignore the data
 * sent by the host, return 0 in 'usbFunctionSetup()'.
 */
	//set request type so it can be keyed from for subsequent IN/OUT data transfers
	//reqtype = (spacket->bmRequestType & REQ_TYPE_MASK);
	//reqdir =  (spacket->bmRequestType & REQ_DIR_MASK);
	//don't need separate bytes to store 2 bits of data coming from the same byte..
	//reqtype = spacket->bmRequestType;
	//store in lower byte
	newaddr_reqtype = (newaddr_reqtype & 0xFF00) | spacket->bmRequestType;

	//setup packets not handled by standard requests sent to usbFunctionSetup (just like Vusb)
	if ((spacket->bmRequestType & REQ_TYPE_MASK) != REQ_TYPE_STD) {
		//function must set usbMsgPtr to point to return data for IN transfers
		//num_bytes_sending = usbFunctionSetup( (uint8_t*) spacket );

		//the above worked great for a long time..
		//but now I want to separate application code from usb code for firmware updates
		//to do this the usb code can't directly call application code (usbFunction Setup/Write)
		//need the application code to tell the usb code where the functions are using variables


		//call the usbFunctionSetup function with some function pointer magic
		typedef uint16_t (*pFunction)(uint8_t data[8]);
		pFunction JumpToApplication;


		//but this is where we need to snoop on the setup packet to determine 
		//if it's a firmware update packet
		//
		//this isn't needed anymore though.  because the application code
		//jumps to the fwupdate main which effectively exits the main application
		//then updates our usb function pointers for us.
		//
		//
//		if (spacket->bRequest == DICT_FWUPDATE ) {
//			//send this packet to the firmware updater
//			//do this by changing the usbfuncsetup pointer
//			usbfuncsetup = (uint32_t) &usb_fwupdate_setup;	//should only assign lower 16bits
//			//now all setup packets will go to the fwupdater instead of application code
//			//we're basically stuck in this condition until a reset which is what we want
//			//accidentally jumping to the application code that's not existent would brick us
//			//hmmm could have the application code do this for us though instead of slowing down
//			//all setup packets..
//			//I think I like this idea, use BOOTLOADER dictionary to get it done once
//			//rest of update stuff is working
//			//other thing that should be protected from is write transfers
//
//			//The above was DONE
//
//
//			//other thing we need to do is keep the USB ISR from returning to 
//			//the main function
//			//I think this function is inlined with the USB ISR which means the current
//			//value in the link register is where the ISR will return to
//			asm(
//				//	"ldr     r0, sramconst\n"
//				//	"mov 	r13, r0\n"
//				//	"ldr     r0, sramconst+4\n"
//      					"bkpt\n"
//      					//"bx r0\n"
//					//"mov pc, r0\n"
//					//".p2align 2\n"
//					//"sramconst:\n"
//					////".word        0xDEADBEEF"
//					//".word        0x20001278\n"	//MSP for bootloader
//					////".word        0x1FFFC519"	//AN2606 note for jumping to bootloader C6
//					//".word        0x1FFFCAC5\n"	//C6 reset vector
//			   );
//		}

		JumpToApplication = (uint16_t (*)(uint8_t data[8])) ((0x08000000));  //base of flash
		//application main makes the following assignment at powerup
		//usbfuncsetup = (uint32_t) &usbFunctionSetup;	//should only assign lower 16bits
		JumpToApplication += usbfuncsetup;

		//perform the actual jump/call
		num_bytes_sending = JumpToApplication( (uint8_t*) spacket );

	}
	
	
	if ( (spacket->bmRequestType & REQ_DIR_MASK) == REQ_DIR_IN ) {
	//IN transfer Host wants us to send data (tx)
		switch ( spacket->bmRequestType & REQ_TYPE_MASK ) {
			case REQ_TYPE_STD:
				num_bytes_sending = standard_req_in( spacket );
				break;
		//	case REQ_TYPE_CLASS:
		//		num_bytes_sending = 0;//class_req_in( spacket );
		//		break;
		//	case REQ_TYPE_VEND:
		//		num_bytes_sending = 0;//vendor_req_in( spacket );
		//		break;
		//	case REQ_TYPE_RES:
		//	default:
		//		num_bytes_sending = 0;
		//		break;
		}
		//A USB device can determine the number and
		//direction of data stages by interpreting the data transferred in the SETUP stage, and is
		//required to STALL the transaction in the case of errors. To do so, at all data stages before
		//the last, the unused direction should be set to STALL, so that, if the host reverses the
		//transfer direction too soon, it gets a STALL as a status stage.
		//
		//WRONG!!!  This ended up being a shot in the foot.  The VERY first request from the host is a 
		//SETUP device descriptor request for 16KBytes worth of data!!  
		//HOWEVER, the host tells us the device to shut it's mouth after the first data stage as if 
		//it doesn't want any more info by sending a STATUS state (OUT xfr expecting zero data)
		//So we need to be ready for this condition and be prepared to recieve a STATUS OUT zero data "shutup" command
		//Maybe this is only an issue for standard type requests during enumeration..?
		//
		//Need to set RX to stall it should be NAK right now
		
		//TODO decide if want to set EP_KIND to STATUS_OUT during this time.  I don't think there is much benefit 
		//currently and will cause more hassle than it's worth currently, since have to ensure it's clear for other OUT xfrs
		USB_EP0R_RX_VALID_STATUS_OUT();

		//TODO decide if want to set EP0_RX_COUNT to 0 so we can only receive STATUS OUT with zero data, however that
		//is effectively what EP_KIND= STATUS_OUT is intended for.. I don't think RX count matters since it can't overflow

		//Now we've got the pointer to return data initialized
		//and number of bytes the firmware would like to return
		control_xfr_in();
		
	} else { 
	//OUT transfer Host is sending us data (rx)
		//if data is OUT (rx) need a function pointer of what to call when data is received
		//or if there is no data stage, we just need to send status packet

		//num_byte_req contains number of bytes expected to be transferred in upcoming OUT xfrs

		switch ( spacket->bmRequestType & REQ_TYPE_MASK ) {
			case REQ_TYPE_STD:
				//num_bytes_expecting was never used, so cut it to save ram
				//the compiler was cutting it anyway, no need to put in usb_buff[]..
				//BUT!  When I cut it, USB device descriptor fails..  
				//IDK why, so just let's just keep it anyway..
				//num_bytes_expecting = standard_req_out( spacket );
				//The reason was because that function actually does something required even
				//if the return value is ignored you bozo!
				standard_req_out( spacket );
				break;
		//	case REQ_TYPE_CLASS:
		//		//num_bytes_sending = 0;//class_req_in( spacket );
		//		//break;
		//	case REQ_TYPE_VEND:
		//		//num_bytes_sending = 0;//vendor_req_in( spacket );
		//		//num_bytes_sending = usbFunctionSetup( spacket );
		//		break;
		//	case REQ_TYPE_RES:
		//	default:
		//		//num_bytes_sending = 0;
		//		break;
		}

		//Clear EP_KIND so OUT transfers of any length are accepted
		USB_EP0R_EP_KIND_ANY();

		//TODO if there is no DATA stage, then we expect the next token to be IN
		//in which case device need to be prepared to send IN transfer of zero data length

		//prepare IN STATUS packet of zero length
		usb_buff[USB_COUNT0_TX] = 0;
		//enable any packet
		USB_EP0R_RXTX_VALID();



		//control_xfr_out();
	}


}




//This is the ISR that gets called for USB interrupts
	//At the end of the transaction, an endpoint-specific interrupt is generated, reading status registers 
	//and/or using different interrupt response routines. The microcontroller can determine:
	// -which endpoint has to be served,
	// -which type of transaction took place, if errors occurred (bit stuffing, format, CRC,
	//	protocol, missing ACK, over/underrun, etc.).
	
	//USB interrupt status register (USB_ISTR)
	//This register contains the status of all the interrupt sources allowing application 
	//software to determine, which events caused an interrupt request.
USBDRIVER void USB_IRQHandler(void)
{

	//communications between application code & USB to prevent direct calls
	//USB interrupts should probably be disabled when getting things done in this manner..
	if (usbflag) {
		//IDK if checking for it to be clear before switching will result in faster code or not..
		switch (usbflag) {
			case INITUSB:
				init_usb(); break;
		}
		//clear the flag so don't come back for same request
		//TODO think this trough to make sure other IRQ triggers aren't going to mess this up..
		//perhaps we need to disable irq's while performing these flaging operations..
		usbflag = 0x0000;
	}

	//all interrupts enabled by USB_CNTR, plus any successful rx/tx to an endpoint triggers this ISR
	
	//should be our goal to get out of this ISR asap, signal the transaction to the main thread
	//and let the main thread process the data.
	//That isn't really how V-usb is setup which we're looking to replace and be compatible with for starters.
	//So for now this isn't going to be setup ideally, but if USB is our top priority then maybe it's not so bad..

	//Plan is to determine source of interrupt
	//Service what's needed for the interrupt
	//Clear the pending/active interrupts which have been serviced
	//If there are other interrupts occuring simulateously we don't have to catch em all
	//	they'll trigger this ISR again
	//Return from interrupt
	
	//First check for successful transfer of USB packets
	//High level we can determine this by USB_ISTR:
	//	CTR:set if correct transfer occured (read only, cleared via the EP)
	//	DIR: 0-TX, 1-RX
	//	EP_ID[3:0]: endpoint that triggered the interrupt with following priority:
	//		-isosync & double-buffered bulk are considered first getting hi pri
	//		-then EPnR register number ie EP0R gets priority over EP2R
	//		NOTE: you can put whatever endpoint number in whichever register you choose
	//		endpoint0 doesn't have to go in EP0R register, the endpoint number is programmable!
	//		would probably make more sense if they used letters to define EPnR registers..
	//Low level we don't have to use EP_ID's priority assignments we could just check EPnR CTR_RX/TX bits
	//Kinda like EP_ID though as it allows us to focus on a single EP for the given ISR call
	
	//CAUTION!!!  usb_buff data can only be accessed in half words, or bytes.  No 32bit accesses!!!
	
	usbRequest_t *setup_packet;
	uint8_t	endpoint_num;
	

	//only have EP0 for now
	
	//check for OUT/SETUP
	if ( USB->EP0R & USB_EP_CTR_RX ) {


		//clear RX interrupt leave everything else unaffected, reference manual says this should be the first thing
		//we do, but with control endpoints, any subsequent SETUP will stomp over the prior one if CTR_RX is clear
		//It'll stomp it even if STAT is set to STALL/NAK, setting to DISABLE is only way to prevent it..
		//If last setup data is vital to maintain it should be stored more permanently somewhere besides buffer ram.
		EP0R_CLR_CTR_RX();
		//Note: clearing CTR_RX on a control EP, is enough for another setup packet to be accepted
		//this is true even if STAT_RX is STALL/NAK, so if the data needs retained it must be copied
		//elsewhere, or set STAT_RX to DISABLED to keep it from being stomped by the next setup

		if ( USB->EP0R & USB_EP_SETUP ) { //SETUP packet
		//log ++;	//inc log for each setup packet used for debugging purposes to trigger logic analyzer at desired packet
#define LOG_COUNT	3
//		if ( log >= LOG_COUNT) { DEBUG_HI(); DEBUG_LO(); }
//usb_buff[LOG0] = USB->EP0R;
			//set pointer to usb buffer, type ensures 8/16bit accesses to usb_buff
			setup_packet = (void*) &usb_buff[EP0_RX_BASE];
			req_dir = (setup_packet->bmRequestType & REQ_DIR_MASK);	//set to REQ_DIR_IN/OUT for data stage dir
			control_xfr_init( setup_packet );
			
		} else { //OUT packet
			//if ((reqtype == REQ_TYPE_VEND) & (reqdir == REQ_DIR_OUT)) { 
			//the two variables (bits) were combined to single byte
			if (((newaddr_reqtype & REQ_TYPE_MASK) == REQ_TYPE_VEND) && ((newaddr_reqtype & REQ_DIR_MASK) == REQ_DIR_OUT)) { 
				//have to key off of reqdir so OUT status packets don't call usbFunctionWrite
//			if ( log >= LOG_COUNT) { DEBUG_HI(); DEBUG_LO(); }
		//number of bytes received is denoted in USB_COUNTn_RX buffer table
			//control_xfr_out();
			//usbFunctionWrite((uint8_t*) &usb_buff[EP0_RX_BASE], (usb_buff[USB_COUNT0_RX] & RX_COUNT_MSK));

			//usb code doesn't know where usbFunctionWrite is at build time
			//must use usb_buff variables as function pointers, but they're only 16bit

			//function pointer magic
			typedef uint8_t (*pFunction)(uint8_t *data, uint8_t len);
			pFunction JumpToApplication;
			JumpToApplication = (uint8_t (*)(uint8_t *data, uint8_t len)) ((0x08000000));  //Base of flash
			//application main makes the following assignment at powerup
			//usbfuncwrite = (uint32_t) &usbFunctionWrite;	//should only assign lower 16bits
			JumpToApplication += usbfuncwrite;	//must be within first 64KByte of flash
			JumpToApplication((uint8_t*) &usb_buff[EP0_RX_BASE], (usb_buff[USB_COUNT0_RX] & RX_COUNT_MSK));

			USB_EP0R_RX_VALID();
			}
		}
	

	} else if ( USB->EP0R & USB_EP_CTR_TX ) { //IN packet
//		if ( log >= LOG_COUNT) { DEBUG_HI(); DEBUG_LO(); }
//DEBUG_HI(); DEBUG_LO();
	//	log ++;
			//LED_ON();
	//	if (log >= 2) {
	//		LED_ON();
	//	}
		//Servicing of the CTR_TX event starts clearing the interrupt bit; 

//usb_buff[LOG4] = USB->EP0R;
		//clear TX interrupt
		EP0R_CLR_CTR_TX();
		//USB->EP0R = (((USB->EP0R | USB_EP_CTR_RX) 	//set rx field to keep from accidentally clearing
		//		& USB_EPREG_MASK ) 	//mask out toggle feilds making them zero
		//		& ~USB_EP_CTR_TX );		//clear tx bit removing active interrupt

//		LED_ON();
//usb_buff[LOG8] = USB->EP0R;

		//the application software then prepares another buffer full of data to be sent, 
		//updates the COUNTn_TX table location with the number of byte to be transmitted during the next transfer, 
		//and finally sets STAT_TX to 11 (VALID) to re-enable transmissions. 
		//this is only done if the IN transfer had data, if there was no data, it was a status stage
		//if ( (usb_buff[USB_COUNT0_RX] & RX_COUNT_MSK)  != 0 ) {
		if ( req_dir == REQ_DIR_IN ) {
			control_xfr_in();
		} else {
			//OUT request, IN denotes STATUS stage

			//check if USB device address needs set must be after completion of STATUS stage
			//if (new_address) {
			//stored in upper byte of newaddr_reqtype
			if (newaddr_reqtype & 0xFF00) {
				//USB->DADDR = (new_address | USB_DADDR_EF);	//update address and keep USB function enabled	
				USB->DADDR = ((newaddr_reqtype>>8) | USB_DADDR_EF);	//update address and keep USB function enabled	
				//new_address = 0;	//clear flag value so don't come back here again
				newaddr_reqtype &= 0x00FF;

				//LED_ON();
			}
		}

//usb_buff[LOGC] = USB->EP0R;
//usb_buff[LOG10] = log;
		//While the STAT_TX bits are equal to 10 (NAK), any IN request addressed to that endpoint is NAKed, 
		//indicating a flow control condition: the USB host will retry the transaction until it succeeds. 
		//It is mandatory to execute the sequence of operations in the above mentioned order to avoid losing the 
		//notification of a second IN transaction addressed to the same endpoint immediately following the one 
		//which triggered the CTR interrupt. 

		//I wasn't doing things in this order thinking that explains why I can't get a second transfer out

	}

	if ( USB->ISTR & USB_ISTR_RESET ) {	//USB reset event occured
		//Anytime a reset condition occurs, the EPnR registers are cleared
		//Must re-enable the USB function and setup EP0 after any reset condition within 10msec
		usb_reset_recovery();
		//handled in reset recovery: USB->ISTR &= ~USB_ISTR_RESET;
	}
	
}

