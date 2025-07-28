#include <avr/interrupt.h>
#include <avr/wdt.h>
#include <util/delay.h>

#include "usbdrv.h"
#include "io.h"
#include "pinport.h"
#include "buffer.h"

int main(void)
{

	//set watch dog timer with 1 second timer
	wdt_enable(WDTO_1S);
	/* Even if you don't use the watchdog, turn it off here. On newer devices,
	 * the status of the watchdog (on/off, period) is PRESERVED OVER RESET!
	 */
	/* RESET status: all port bits are inputs without pull-up.
	 * That's the way we need D+ and D-. Therefore we don't need any
	 * additional hardware initialization.
	 */

	//odDebugInit();	//intialize debuging printing via serial port
	//DBG1(0x00, 0, 0);	//debug serial op: main starts

	//initialize V-usb driver before interupts enabled and entering main loop
	usbInit();
	//disconnect from host enforce re-enumeration, interupts must be disabled during this.
	usbDeviceDisconnect();

	//fake USB disconnect for over 250ms
	uint8_t index = 0;
	while(--index){		//loop 256 times
		wdt_reset();	//keep wdt happy during this time
		_delay_ms(1);	//delay 256msec
	}

	//reconnect to host
	usbDeviceConnect();

	//intialize i/o and LED to pullup state
	io_reset();

	//enable interrupts
	sei();

	//=================
	//MAIN LOOP
	//=================
	while (1) {

		//pet the watch doggie to keep him happy
		wdt_reset();	

		//must call at regular intervals no longer than 50msec
		//checks for setup packets from what I understand
		usbPoll();	

		//check buffer status' and instruct them to 
		//flash/dump as needed to keep data moving
		//currently assuming this operation doesn't take longer
		//than 50msec to meet usbPoll's req't
		//considering using a timer counter interupt to call
		//usbPoll more often but going to see how speed is 
		//impacted first..
		//256Bytes * 20usec Tbp = 5.12msec programming time 
		//+ cpu operations that can't be hid behind flash wait time
		//another thought would be to call usbPoll mid programming
		//a few times to prevent incoming data from being delayed too long
		update_buffers();
	}
}
