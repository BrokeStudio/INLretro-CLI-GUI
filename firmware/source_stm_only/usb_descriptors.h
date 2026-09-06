#ifndef _usb_descriptors_h
#define _usb_descriptors_h

#define USBDESC __attribute__ ((section (".usb_desc")))

/*	Contains all the device, configuration, interface, endpoint, and string descriptor definitions
 *	The excellent breakdown of the USB standard and field comments have been copy pasted from the
 *	almighty documentation "USB in a Nutshell" article by BeyondLogic:
 *	http://www.beyondlogic.org/usbnutshell/usb5.shtml#DeviceDescriptors
 */
#define EP0_SIZE	0x08		//8Bytes same as usb 1.1 for now

#define bLength			0		//offset of bLength in descriptor array
#define bDescriptorType		1	//offset of bDescriptorType in descriptor array
#define DESC_TYPE_MASK		0xFF00	//Descriptor type is upper byte of wValue
#define DESC_IDX_MASK		0x00FF	//Descriptor index is lower byte of wValue
#define DESC_TYPE_DEVICE 	0x01
#define DESC_TYPE_CONFIG 	0x02
#define DESC_TYPE_STRING 	0x03
#define DESC_TYPE_INTERFACE 	0x04
#define DESC_TYPE_ENDPOINT 	0x05

#define DEVICE_DESC_LEN	18
USBDESC const uint8_t device_desc[DEVICE_DESC_LEN] = {
  // 0 	bLength 		1 	Number 		Size of the Descriptor in Bytes (18 bytes)
  DEVICE_DESC_LEN,
  // 1 	bDescriptorType 	1 	Constant 	Device Descriptor (0x01)
  DESC_TYPE_DEVICE,
  // 2 	bcdUSB 			2 	BCD 		USB Specification Number which device complies too.
  0x00,
  0x02,
  // 4 	bDeviceClass 		1 	Class 		Class Code (Assigned by USB Org)
  0xFF,
  // 							If equal to Zero, each interface specifies it����s own class code
  // 							If equal to 0xFF, the class code is vendor specified.
  // 							Otherwise field is valid Class Code.
  // 5 	bDeviceSubClass 	1 	SubClass 	Subclass Code (Assigned by USB Org)
  0x00,
  // 6 	bDeviceProtocol 	1 	Protocol 	Protocol Code (Assigned by USB Org)
  0x00,
  // 7 	bMaxPacketSize 		1 	Number 		Maximum Packet Size for Zero Endpoint. Valid Sizes are 8, 16, 32, 64 (for usb 2.0)
  EP0_SIZE,
  // 8 	idVendor 		2 	ID 		Vendor ID (Assigned by USB Org)
  0xC0,
  0x16,
  // 10 	idProduct 		2 	ID 		Product ID (Assigned by Manufacturer)
  0xDC,
  0x05,
  // 12 	bcdDevice 		2 	BCD 		Device Release Number
  //0x00, 0x02,	early development version
  //0x01, 0x02,	//first public release 7SEP2018
  //0x02, 0x02,	//second public release 16NOV2018
  // 0x03, 0x02,	//third public release 30NOV2018
  0x04,
  0x02, //fourth public release XXYYY2025 (Broke Studio)
  //v2.3 is first to contain switchless USB firmware updates
  //application version numbers also included in this release
  //application version are meant to tack onto end of usb version
  //application version 0 is being released with this build
  //so we'll be at v2.3.0 application versions is expected to
  //increment while maintaining usb/fwupater v2.3

  // 14 	iManufacturer 		1 	Index 		Index of Manufacturer String Descriptor
  0x01,
  // 15 	iProduct 		1 	Index 		Index of Product String Descriptor
  0x02,
  // 16 	iSerialNumber 		1 	Index 		Index of Serial Number String Descriptor
  0x00,
  // 17 	bNumConfigurations 	1 	Integer 	Number of Possible Configurations
  0x01
};

//	The bcdUSB field reports the highest version of USB the device supports. The value is in binary coded decimal
//	with a format of 0xJJMN where JJ is the major version number, M is the minor version number and N is the sub minor
//	version number. e.g. USB 2.0 is reported as 0x0200, USB 1.1 as 0x0110 and USB 1.0 as 0x0100.
//
//	The bDeviceClass, bDeviceSubClass and bDeviceProtocol are used by the operating system to find a class driver
//	for your device. Typically only the bDeviceClass is set at the device level. Most class specifications choose to
//	identify itself at the interface level and as a result set the bDeviceClass as 0x00. This allows for the one
//	device to support multiple classes.
//
//	The bMaxPacketSize field reports the maximum packet size for endpoint zero. All devices must support endpoint zero.
//
//	The idVendor and idProduct are used by the operating system to find a driver for your device. The Vendor ID is assigned by the USB-IF.
//
//	The bcdDevice has the same format than the bcdUSB and is used to provide a device version number. This value is assigned by the developer.
//
//	Three string descriptors exist to provide details of the manufacturer, product and serial number. There is no
//	requirement to have string descriptors. If no string descriptor is present, a index of zero should be used.
//
//	bNumConfigurations defines the number of configurations the device supports at its current speed.

//Configuration Descriptors
//
//    A USB device can have several different configurations although the majority of devices are simple and only have one.
//    The configuration descriptor specifies how the device is powered, what the maximum power consumption is, the number of
//    interfaces it has. Therefore it is possible to have two configurations, one for when the device is bus powered and another
//    when it is mains powered. As this is a "header" to the Interface descriptors, its also feasible to have one configuration
//    using a different transfer mode to that of another configuration.
//
//    Once all the configurations have been examined by the host, the host will send a SetConfiguration command with a non zero
//    value which matches the bConfigurationValue of one of the configurations. This is used to select the desired configuration.
//
#define CONFIG_DESC_LEN		9
#define INTERFACE_DESC_LEN 	9
#define ENDPOINT_DESC_LEN	0	//only describe EP's other than EP0
//NOTE: current table broken if total is greater 255 bytes!!!
#define CONFIG_TOTAL_LEN	(CONFIG_DESC_LEN + INTERFACE_DESC_LEN + ENDPOINT_DESC_LEN)
#define wTotalLength	2	//offset of wTotalLength in descriptor array
USBDESC const uint8_t config_desc[CONFIG_TOTAL_LEN] = {
  // Off 	Field 			Size 	Value 		Description
  // 0 	bLength 		1 	Number		Size of Descriptor in Bytes
  CONFIG_DESC_LEN,
  // 1 	bDescriptorType 	1 	Constant 	Configuration Descriptor (0x02)
  DESC_TYPE_CONFIG,
  // 2 	wTotalLength 		2 	Number		Total length in bytes of data returned
  CONFIG_TOTAL_LEN,
  0x00,
  // 4 	bNumInterfaces 		1 	Number		Number of Interfaces
  0x01,
  // 5 	bConfigurationValue 	1 	Number		Value to use as an argument to select this configuration
  0x01,
  // 6 	iConfiguration 		1 	Index		Index of String Descriptor describing this configuration
  0x00,
  // 7 	bmAttributes 		1 	Bitmap		D7 Reserved, set to 1. (USB 1.0 Bus Powered)
  //							D6 Self Powered
  //							D5 Remote Wakeup
  //							D4..0 Reserved, set to 0.
  0x80,
  // 8 	bMaxPower 		1 	mA		Maximum Power Consumption in 2mA units
  // 							bus powered devices should request more than 100mA
  100 / 2,
  //
  //	When the configuration descriptor is read, it returns the entire configuration hierarchy which includes all related
  //	interface and endpoint descriptors. The wTotalLength field reflects the number of bytes in the hierarchy.
  //
  //	bNumInterfaces specifies the number of interfaces present for this configuration.
  //
  //	bConfigurationValue is used by the SetConfiguration request to select this configuration.
  //
  //	iConfiguration is a index to a string descriptor describing the configuration in human readable form.
  //
  //	bmAttributes specify power parameters for the configuration. If a device is self powered, it sets D6. Bit D7 was used in
  //	USB 1.0 to indicate a bus powered device, but this is now done by bMaxPower. If a device uses any power from the bus,
  //	whether it be as a bus powered device or as a self powered device, it must report its power consumption in bMaxPower.
  //	Devices can also support remote wakeup which allows the device to wake up the host when the host is in suspend.
  //
  //	bMaxPower defines the maximum power the device will drain from the bus. This is in 2mA units, thus a maximum of
  //	approximately 500mA can be specified. The specification allows a high powered bus powered device to drain no more than
  //	500mA from Vbus. If a device loses external power, then it must not drain more than indicated in bMaxPower. It should
  //	fail any operation it cannot perform without external power.
  //
  //
  //
  //
  //Interface Descriptors
  //
  // The interface descriptor could be seen as a header or grouping of the endpoints into a functional group performing a
  // single feature of the device. The interface descriptor conforms to the following format,
  //
  // Off 	Field 			Size 	Value 		Description
  // 0 	bLength 		1 	Number		Size of Descriptor in Bytes (9 Bytes)
  INTERFACE_DESC_LEN,
  // 1 	bDescriptorType 	1 	Constant	Interface Descriptor (0x04)
  DESC_TYPE_INTERFACE,
  // 2 	bInterfaceNumber 	1 	Number		Number of Interface
  0x00,
  // 3 	bAlternateSetting 	1 	Number		Value used to select alternative setting
  0x00,
  // 4 	bNumEndpoints 		1 	Number		Number of Endpoints used for this interface
  0x00,
  // 5 	bInterfaceClass 	1 	Class		Class Code (Assigned by USB Org)
  0x00,
  // 6 	bInterfaceSubClass 	1 	SubClass	Subclass Code (Assigned by USB Org)
  0x00,
  // 7 	bInterfaceProtocol 	1 	Protocol	Protocol Code (Assigned by USB Org)
  0x00,
  // 8 	iInterface 		1 	Index		Index of String Descriptor Describing this interface
  0x00
};
//
//	bInterfaceNumber indicates the index of the interface descriptor. This should be zero based, and incremented once
//	for each new interface descriptor.
//
//	bAlternativeSetting can be used to specify alternative interfaces. These alternative interfaces can be selected
//	with the Set Interface request.
//
//	bNumEndpoints indicates the number of endpoints used by the interface. This value should exclude endpoint zero
//	and is used to indicate the number of endpoint descriptors to follow.
//
//	bInterfaceClass, bInterfaceSubClass and bInterfaceProtocol can be used to specify supported classes
//	(e.g. HID, communications, mass storage etc.) This allows many devices to use class drivers preventing the
//	need to write specific drivers for your device.
//
//	iInterface allows for a string description of the interface.
//
//Endpoint Descriptors
//
//    Endpoint descriptors are used to describe endpoints other than endpoint zero. Endpoint zero is always assumed to be a
//    control endpoint and is configured before any descriptors are even requested. The host will use the information returned
//    from these descriptors to determine the bandwidth requirements of the bus.
//
// Off 	Field 			Size 	Value 		Description
// 0 	bLength 		1 	Number		Size of Descriptor in Bytes (7 bytes)
// 1 	bDescriptorType 	1 	Constant	Endpoint Descriptor (0x05)
// 2 	bEndpointAddress 	1 	Endpoint 	Endpoint Address
//							  Bits 0..3b Endpoint Number.
//							  Bits 4..6b Reserved. Set to Zero
//							  Bits 7 Direction 0 = Out, 1 = In (Ignored for Control Endpoints)
// 3 	bmAttributes 		1 	Bitmap 		Bits 0..1 Transfer Type
//							  00 = Control 01 = Isochronous 10 = Bulk 11 = Interrupt
//							Bits 2..7 are reserved. If Isochronous endpoint,
//							Bits 3..2 = Synchronisation Type (Iso Mode)
//							  00 = No Synchonisation 01 = Asynchronous 10 = Adaptive 11 = Synchronous
//							Bits 5..4 = Usage Type (Iso Mode)
//							  00 = Data Endpoint 01 = Feedback Endpoint
//							  10 = Explicit Feedback Data Endpoint 11 = Reserved
// 4 	wMaxPacketSize 		2 	Number		Maximum Packet Size this endpoint is capable of sending or receiving
// 6 	bInterval 		1 	Number		Interval for polling endpoint data transfers. Value in frame counts.
// 							Ignored for Bulk & Control Endpoints. Isochronous must equal 1 and field may
// 							range from 1 to 255 for interrupt endpoints.
//
//	bEndpointAddress indicates what endpoint this descriptor is describing.
//
//	bmAttributes specifies the transfer type. This can either be Control, Interrupt, Isochronous or Bulk Transfers.
//	If an Isochronous endpoint is specified, additional attributes can be selected such as the Synchronisation and usage types.
//
//      wMaxPacketSize indicates the maximum payload size for this endpoint.
//
//      bInterval is used to specify the polling interval of certain transfers. The units are expressed in frames,
//      thus this equates to either 1ms for low/full speed devices and 125us for high speed devices.
//
//String Descriptors
//
//	String descriptors provide human readable information and are optional. If they are not used, any
//	string index fields of descriptors must be set to zero indicating there is no string descriptor available.
//
//	The strings are encoded in the Unicode format and products can be made to support multiple languages.
//	String Index 0 should return a list of supported languages. A list of USB Language IDs can be found in
//	Universal Serial Bus Language Identifiers (LANGIDs) version 1.0
//
#define STRING0_DESC_LEN	4
USBDESC const uint8_t string0_desc[STRING0_DESC_LEN] = {
  // Off 	Field 			Size 	Value 		Description
  // 0 	bLength 		1 	Number		Size of Descriptor in Bytes
  STRING0_DESC_LEN,
  // 1 	bDescriptorType 	1 	Constant	String Descriptor (0x03)
  DESC_TYPE_STRING,
  // 2 	wLANGID[0] 		2 	number		Supported Language Code Zero
  //							(e.g. 0x0409 English - United States)
  0x09,
  0x04
};
// 4 	wLANGID[1] 		2 	number		Supported Language Code One
//							(e.g. 0x0c09 English - Australian)
// n 	wLANGID[x] 		2 	number		Supported Language Code x
//							(e.g. 0x0407 German - Standard)
//
//	The above String Descriptor shows the format of String Descriptor Zero. The host should read this descriptor to
//	determine what languages are available. If a language is supported, it can then be referenced by sending the
//	language ID in the wIndex field of a Get Descriptor(String) request.
//
//	All subsequent strings take on the format below,
//
// Off 	Field 			Size 	Value 		Description
// 0 	bLength 		1 	Number		Size of Descriptor in Bytes
// 1 	bDescriptorType 	1 	Constant	String Descriptor (0x03)
// 2 	bString 		n 	Unicode		Unicode Encoded String
//
//
//

//Defining string arrays as uint16_t effectively makes the strings UTF-16 as required
#define BYTES_PER_HWORD		2
#define STRING1_DESC_LEN	(21*BYTES_PER_HWORD)	//characters plus 1 for bLength & bDescriptorType
USBDESC const uint16_t string1_desc[STRING1_DESC_LEN] = {
  // 0 	bLength 		1 	Number		Size of Descriptor in Bytes
  // 1 	bDescriptorType 	1 	Constant	String Descriptor (0x03)
  ((uint16_t)DESC_TYPE_STRING << 8 | STRING1_DESC_LEN),
  // 2 	bString 		n 	Unicode		Unicode Encoded String
  'I',
  'n',
  'f',
  'i',
  'n',
  'i',
  't',
  'e',
  'N',
  'e',
  's',
  'L',
  'i',
  'v',
  'e',
  's',
  '.',
  'c',
  'o',
  'm'
};

#define STRING2_DESC_LEN	(15*BYTES_PER_HWORD)	//characters plus 1 for bLength & bDescriptorType
USBDESC const uint16_t string2_desc[STRING2_DESC_LEN] = {
  // 0 	bLength 		1 	Number		Size of Descriptor in Bytes
  // 1 	bDescriptorType 	1 	Constant	String Descriptor (0x03)
  ((uint16_t)DESC_TYPE_STRING << 8 | STRING2_DESC_LEN),
  // 2 	bString 		n 	Unicode		Unicode Encoded String
  'I',
  'N',
  'L',
  ' ',
  'R',
  'e',
  't',
  'r',
  'o',
  '-',
  'P',
  'r',
  'o',
  'g'
}; //normal
//'I','N','L',' ','R','e','t','r','o','-','P','r','o','2'};	//numbered devices to use multiple retroprog at once

#endif
