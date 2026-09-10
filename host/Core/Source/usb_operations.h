#pragma once
#ifndef USB_OPRATIONS_H
#define USB_OPRATIONS_H

// #include <stdio.h>
// #include <string.h>
// #include <stdlib.h>
// #include <assert.h>
// #include <errno.h>
#if defined(_WIN32) || defined(__APPLE__)
#include "libusb.h"
#else
#include <libusb-1.0/libusb.h>
#endif
#include "lua.hpp"

// list of included dictionaries for defining request, wValue, and wIndex fields
#include "shared_dictionaries.h"

// uncomment to DEBUG this file alone
// #define DEBUG
//"make debug" to get DEBUG msgs on entire program
#include "dbg.h"

// control transfer request types
// uint8_t libusb_control_setup::bmRequestType
// Request type.
//	Bits 0:4 determine recipient, see libusb_request_recipient. Bits 5:6 determine type, see libusb_request_type. Bit 7 determines data transfer direction, see libusb_endpoint_direction.
//
// libusb_request_types:
// LIBUSB_REQUEST_TYPE_STANDARD	Standard handled by driver during setup/etc
// LIBUSB_REQUEST_TYPE_CLASS 	Class for use with specific device classes like HID.
// LIBUSB_REQUEST_TYPE_VENDOR	Vendor application specific as we choose which is what we'll be utilizing for all transfers
// LIBUSB_REQUEST_TYPE_RESERVED	Reserved.
//
// libusb_request_recipients:
// LIBUSB_RECIPIENT_DEVICE	Device.
// LIBUSB_RECIPIENT_INTERFACE	Interface.
// LIBUSB_RECIPIENT_ENDPOINT	Endpoint.
// LIBUSB_RECIPIENT_OTHER	Other.
//
// LIBUSB_ENDPOINT_IN	0x80	In: device-to-host.
// LIBUSB_ENDPOINT_OUT	0x00	Out: host-to-device.
#define USB_IN LIBUSB_ENDPOINT_IN
#define USB_OUT LIBUSB_ENDPOINT_OUT

// USB timeout
#define TIMEOUT_1_SEC 1000
#define TIMEOUT_5_SEC 5000

// Max transfer length
#define MAX_VUSB 254           // Max VUSB transfers without long transfers enabled
#define USB_NO_MSG 255         // designates transfer with no message
#define MAX_VUSB_LONGXFR 16384 // 16KByte biggest value 16bit wLength can hold

// typedef struct USBtransfer {
// This is the primary USB request struct used by host app used for all application USB communications.
// handle is retrieved from open_usb_device gives us a means to point to the opened USB device.
// The remaining elements are all directly fed to the outgoing USB setup & data packets to/from the device.
//	Every USB transfer starts with host sending one of these setup packets to the device.
//	the setup packets are unidirectinal always coming from the bus master (host).
//	The data packet(s) for the transfer then follow and are bidirectional.
//	The drivers handle final NACK/ACK/STALL packet for the most part..
//	Note V-USB mcu driver doesn't have time to check CRC so it sends ACK assuming no corruption.
// endpoint basically this is the direction of the data packet to follow.
//	the usb device has a OUT and IN endpoint buffer and this defines which is being accessed.
//	OUT "out of host" is for writting data to the usb device.
//	IN  "in to host" is for reading data from the usb device.
//	endpoint is the only portion of setup packet's requestType field that isn't hardcoded.
//       Vendor request types used exclusively as they meet the our intent and 'hard coded' into this struct.
//	The recipient of this setup packet is also 'hard coded' to the usb device.
// request is more like request type in this scope and designates the 'dictionary' containing the command.
//	pinport is the first dictionary of commands, more to come as things develop.
//	these requests/dictionaries define how the wValue and wIndex fields are utilized.
//	anything can be placed in the 4 bytes of wValue/wIndex as defined by the dictionary.
// wValueMSB:wValueLSB
//	This is where the app places the 'command' being given to the retro programmer.
//	LSB is big enough for now and contains the actual opcode.
//	MSB is used as an overflow for operands/data if wIndex is not large enough.
//	future dicts with more than 256 opcodes could define some/all of MSB to contain the opcode as well.
// wIndexMSB:wIndexLSB
//	This typically contains the operand/data for the opcode but could be used for anything
//	as defined by the opcode.  Raw buffer data could even be placed here to cheat the 254 Byte transfer
//	limit of V-USB (w/o long xfrs), the two bytes of wIndex bring to full page of 256 Bytes.
//	Planning for this to contain the page index (aka memory addr) of the transmitted data buffer.
// wLength must be set to the size of the data transfer to follow this setup packet in Bytes.
//	if wLength is >8, drivers split data into 8byte packets and final packet of < 8Bytes if needed.
//	with 16bit wLength 16KB transfers are largest possible, requires using long xfrs on device driver.
//	The max length without long xfrs is 254Bytes, value 255 is reserved for USB_NO_MSG.
//	This means wLength's MSByte is under utilized but prob shouldn't concern ourselves with that.
// data is a pointer to the data buffer being sent for writes (OUT transfers).
//	read (IN transfers) utilize data pointer to pass location of where to dump read data.

typedef struct USBtransfer
{
  libusb_device_handle *handle;
  uint8_t endpoint;
  uint8_t request;
  uint16_t wValue;
  uint16_t wIndex;
  uint16_t wLength;
  unsigned char *data;
} USBtransfer;

bool is_device_flasher(libusb_device *device, char retroprog_id);
bool find_device(char retroprog_id);
libusb_device_handle *usb_open(char retroprog_id);
// void usb_close(libusb_device_handle *handle);
uint8_t get_device_hardware_type(char retroprog_id);
uint8_t get_device_version(char retroprog_id);
libusb_device_handle *open_usb_device(int log_level, const char *retroprog_id, Log *log);

void close_usb(libusb_device_handle *handle);

// int libusb_control_transfer (libusb_device_handle *dev_handle, uint8_t bmRequestType, uint8_t bRequest, uint16_t wValue, uint16_t wIndex, unsigned char *data, uint16_t wLength, unsigned int timeout)
//
// SETUP PACKET FIELDS:
// bmRequestType: ORing of req type (STD/VENDOR), recipient (think we only care about DEVICE), endpoint direction IN-dev->host OUT-host->dev
// bRequest: single byte that can signify any 'command' or 'request' we setup.
// The wValue and wIndex fields allow parameters to be passed with the request.  Think we can do whatever we want with these
// wLength is used the specify the number of bytes to be transferred should there be a data phase.
// wLength the length field for the setup packet. The data buffer should be at least this size.
//	USB 1.1 low speed standard limits to 8 bytes
//	V-USB seems to break this limit with max of 254 bytes (255 designates "USB_NO_MSG"
//	V-USB allows "LONG TRANSFERS" utilizing full 16bit wLength for upto 16384 bytes = exactly 16KBytes
//	although considering sram on AVR doesn't explode with long transfers and read/write functions are in 8byte chunks,
//		I think it really is limited to 8bytes
//	One idea to squeeze more data is have a request type defined that utilizes wValue and wIndex to gain 4bytes + 8buffer = 12bytes 50% gain
//		Not sure how to gain access to wValue/wIndex with vusb drivers...
//		answer: usbFunctionSetup will get called for every setup packet and pass all 8 bytes of setup packet
//	Can ultimately answer this question by counting how many startup packets are recieved by usbFunciton setup for transfers >8 bytes
//	If when sending >8 byte control transfers, a setup packet only comes once, then there is nothing to abuse
//		however if the same setup packet gets sent for every 8 bytes, it would be better to only perform 8byte transfers and stuff
//		4 more bytes in wValue and wIndex fields to increase throughput by ~50%!!!
//	Testing shows that usbFunctionSetup only gets called once for transfers of 254 bytes
//		So there is only one setup packet for multiple data packets of 8bytes each
//
// Still not sure increasing transfer length doesn't simply break up into bunch of small 8byte transfers although it doesn't sound like it.
// 245byte limit is kind of a pain..  but wValue/wIndex fields could be abused to send 256 bytes
// Long transfers apparently max out speed @ 24KBps with 300 bytes: https://forums.obdev.at/viewtopic.php?t=3059
//
// PAYLOAD:
// data: a suitably-sized data buffer for either input or output (depending on direction bits within bmRequestType)
//
// TIMEOUT:
// timeout: (in millseconds) that this function should wait before giving up due to no response being received.
//	For an unlimited timeout, use value 0
//	USB nutshell: A compliant host requires control transfer response within 5sec
//
// RETURN:
//	Returns on success, the number of bytes actually transferred
//	LIBUSB_ERROR_TIMEOUT if the transfer timed out
//	LIBUSB_ERROR_PIPE if the control request was not supported by the device
//	LIBUSB_ERROR_NO_DEVICE if the device has been disconnected
//	another LIBUSB_ERROR code on other failures
int usb_vendor_transfer(USBtransfer *transfer, Log *log);
// int lua_usb_vend_xfr(lua_State *L);

#endif
