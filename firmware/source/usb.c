#include "usb.h"

//used to store success/error code of last transfer for debugging
//static uint8_t usbWrite_status;

//USB_PUBLIC usbMsgLen_t usbFunctionSetup(uchar data[8]);
/* This function is called when the driver receives a SETUP transaction from
 * the host which is not answered by the driver itself (in practice: class and
 * vendor requests). All control transfers start with a SETUP transaction where
 * the host communicates the parameters of the following (optional) data
 * transfer. The SETUP data is available in the 'data' parameter which can
 * (and should) be casted to 'usbRequest_t *' for a more user-friendly access
 * to parameters.
 *
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
 *
 * Note that calls to the functions usbFunctionRead() and usbFunctionWrite()
 * are only done if enabled by the configuration in usbconfig.h.
 */

//typedef struct usbRequest{
//	uchar       bmRequestType;
//	uchar       bRequest;
//	usbWord_t   wValue;
//	usbWord_t   wIndex;
//	usbWord_t   wLength;
//}usbRequest_t;

#ifdef AVR_CORE
USB_PUBLIC usbMsgLen_t usbFunctionSetup(uchar data[8])
{
#endif
#ifdef STM_CORE
  #define USBSETUP	__attribute__ ((section (".usbFuncSetup"), noinline, noclone))
  //noinline should keep these functions at beinging of flash (.text)
  //they need to be in the first 64KByte which is non issue with C6, but could prob with RB
  USBSETUP uint16_t usbFunctionSetup(uint8_t data[8])
  {
#endif

    //defined and controled by buffer.c
    //	extern buffer *cur_usb_load_buff;

    //cast incoming data into the the usb setup packet it is
    setup_packet* spacket = (void*)data;

    //default 8 Byte buffer to be used for returning error code and return values
    //must be static so USB driver can still access after function return
    //static uint8_t rv[RETURN_BUFF_SIZE];
    //need to make sure this return array is aligned on arm core to prevent unaligned access
    //best way I can think to do this is instantiate it as a 16bit array,
    //then point to it with an 8bit pointer and now it can be accessed as 8bit array.
    //without this stm32 was hardfaulting I'm not certain, but I think this is why
#ifdef STM_CORE
    static uint16_t rv16[RETURN_BUFF_SIZE / 2];
    uint8_t* rv = (uint8_t*)rv16;

    //create a usbMsgPtr variable from the stack which we can use convienently
    //but then at end of the function we'll need to copy the value over to usb_buff usbMsgPtr_H/L
    usbMsgPtr_t usbMsgPtr;
#else
static uint8_t rv[RETURN_BUFF_SIZE];
#endif
    //perhaps a better solution for stm32 is just provide a pointer to usb buffer ram
    //but that doesn't expand past 8bytes easily, and starts to necessitate special cases
    //diverging from V-usb norms..
    rv[RETURN_ERR_IDX] = GEN_FAIL; //default to error till opcode updates.
    rv[RETURN_LEN_IDX] = 0;        //reset to zero, number of bytes in return data (excluding ERR & LEN)
    //now it's the opcode's responsiblity to update these values
    //rv[RETURN_DATA] start of return data

    /* (1) Set the global pointer 'usbMsgPtr' to the base of the static RAM data
     * block and return the length of the data in 'usbFunctionSetup()'. The driver
     * will handle the rest. Or (2) return USB_NO_MSG in 'usbFunctionSetup()'. The
     * driver will then call 'usbFunctionRead()' when data is needed. See the
     */
    //by default want to return some portion of the 8 byte rv "return value"
    //buffer. If no return data requested from host rlen = 0, so this wouldn't matter
    //Some dictionaries/opcodes that want to return larger buffers though
    //this function will set usbMsgPtr to point to that larger buffer when supported
    usbMsgPtr = (usbMsgPtr_t)rv;

#if USB_CFG_LONG_TRANSFERS
    //number of bytes to return to host
    //16bit meets max possible 16KBytes with V-USB long transfers enabled
    uint16_t rlen = spacket->wLength; //the speed loss doesn't make long transfers worth it for now
#else
//8bit is enough for 254 bit non-long xfrs
//also gives ~0.7KBps speed up compared to 16bit rlen on V-USB
uint8_t rlen = (uint8_t)spacket->wLength;
#endif

    switch(spacket->bRequest) {
      case DICT_PINPORT:
        rv[RETURN_ERR_IDX] =
          pinport_call(spacket->opcode, spacket->miscdata, spacket->operand, &rv[RETURN_LEN_IDX]);
        break;

      case DICT_IO:
        rv[RETURN_ERR_IDX] =
          io_call(spacket->opcode, spacket->miscdata, spacket->operand, &rv[RETURN_LEN_IDX]);
        break;

#ifdef NES_CONN
      case DICT_NES:
        rv[RETURN_ERR_IDX] =
          nes_call(spacket->opcode, spacket->miscdata, spacket->operand, &rv[RETURN_LEN_IDX]);
        break;
#endif

#ifdef SNES_CONN
      case DICT_SNES:
        rv[RETURN_ERR_IDX] =
          snes_call(spacket->opcode, spacket->miscdata, spacket->operand, &rv[RETURN_LEN_IDX]);
        break;
#endif

#ifdef GB_CONN
      case DICT_GB:
        rv[RETURN_ERR_IDX] =
          gb_call(spacket->opcode, spacket->miscdata, spacket->operand, &rv[RETURN_LEN_IDX]);
        break;

      case DICT_GBA:
        rv[RETURN_ERR_IDX] =
          gba_call(spacket->opcode, spacket->miscdata, spacket->operand, &rv[RETURN_LEN_IDX]);
        break;
#endif

#ifdef GEN_CONN
      case DICT_GEN:
        rv[RETURN_ERR_IDX] =
          gen_call(spacket->opcode, spacket->miscdata, spacket->operand, &rv[RETURN_LEN_IDX]);
        break;
#endif

#ifdef N64_CONN
      case DICT_N64:
        rv[RETURN_ERR_IDX] =
          n64_call(spacket->opcode, spacket->miscdata, spacket->operand, &rv[RETURN_LEN_IDX]);
        break;
#endif

#ifdef STM_CORE
      case DICT_SWIM:
        rv[RETURN_ERR_IDX] =
          swim_call(spacket->opcode, spacket->miscdata, spacket->operand, &rv[RETURN_LEN_IDX]);
        break;
#endif

      case DICT_JTAG:
        rv[RETURN_ERR_IDX] =
          jtag_call(spacket->opcode, spacket->miscdata, spacket->operand, &rv[RETURN_LEN_IDX]);
        break;

      case DICT_BOOTLOAD:
        rv[RETURN_ERR_IDX] =
          bootload_call(spacket->opcode, spacket->miscdata, spacket->operand, &rv[RETURN_LEN_IDX]);
        break;

      case DICT_CICCOM:
        rv[RETURN_ERR_IDX] =
          ciccom_call(spacket->opcode, spacket->miscdata, spacket->operand, &rv[RETURN_LEN_IDX]);
        break;
      case DICT_STUFF:
        rv[RETURN_ERR_IDX] =
          stuff_call(spacket->opcode, spacket->miscdata, spacket->operand, &rv[RETURN_LEN_IDX]);
        break;

      case DICT_BUFFER:
        //just give buffer.c the setup packet and let it figure things out for itself
        usbMsgPtr = (usbMsgPtr_t)buffer_usb_call(spacket, rv, &rlen);
        break; //end of BUFFER

        /*
    case DICT_USB:
      //currently just a simple way to read back usbFunctionWrite status SUCCESS/ERROR
      //if there are future status' to read back may have to create some functions
      rv[RV_ERR_IDX] = SUCCESS;
      rv[RV_DATA0_IDX] = usbWrite_status;
      rv[RV_DATA0_IDX+1] = cur_usb_load_buff->last_idx;
      rlen = 3;
      break; //end of USB
      */

      case DICT_OPER:
        //just give operation.c the setup packet and let it figure things out for itself
        usbMsgPtr = (usbMsgPtr_t)operation_usb_call(spacket, rv, &rlen);
        break; //end of OPER

      default:
        //request (aka dictionary) is unknown
        rv[RETURN_ERR_IDX] = ERR_UNKN_DICTIONARY;
    }

#ifdef STM_CORE
    //now we need to copy usbMsgPtr over to usb_buff so the usb drivers actually get the pointer value
    usbMsgPtr_L = (uint32_t)usbMsgPtr;
    usbMsgPtr_H = ((uint32_t)usbMsgPtr) >> 16;
    //this is a hack for stm32 devices only.  It allows usb firmware to be mostly separated
    //from application code.  Usb code doesn't use any .data nor .bss, only the stack and usb_buff
#endif

    return rlen;

    //need to return USB_NO_MSG for OUT transfers to make usbFunctionWrite called
  }

  //USB_PUBLIC uchar usbFunctionRead(uchar *data, uchar len);
  /* This function is called by the driver to ask the application for a control
   * transfer's payload data (control-in). It is called in chunks of up to 8
   * bytes each. You should copy the data to the location given by 'data' and
   * return the actual number of bytes copied. If you return less than requested,
   * the control-in transfer is terminated. If you return 0xff, the driver aborts
   * the transfer with a STALL token.
   * In order to get usbFunctionRead() called, define USB_CFG_IMPLEMENT_FN_READ
   * to 1 in usbconfig.h and return 0xff in usbFunctionSetup()..
   */
  //USB_PUBLIC uchar usbFunctionRead(uchar *data, uchar len) {
  //	//this function should only get called if usbFunctionSetup returns USB_NO_MSG
  //	return len;
  //}

  // V-USB description of this function:
  //USB_PUBLIC uchar usbFunctionWrite(uchar *data, uchar len);
  /* This function is called by the driver to provide a control transfer's
   * payload data (control-out). It is called in chunks of up to 8 bytes. The
   * total count provided in the current control transfer can be obtained from
   * the 'length' property in the setup data. If an error occurred during
   * processing, return 0xff (== -1). The driver will answer the entire transfer
   * with a STALL token in this case. If you have received the entire payload
   * successfully, return 1. If you expect more data, return 0. If you don't
   * know whether the host will send more data (you should know, the total is
   * provided in the usbFunctionSetup() call!), return 1.
   * NOTE: If you return 0xff for STALL, 'usbFunctionWrite()' may still be called
   * for the remaining data. You must continue to return 0xff for STALL in these
   * calls.
   * In order to get usbFunctionWrite() called, define USB_CFG_IMPLEMENT_FN_WRITE
   * to 1 in usbconfig.h and return 0xff in usbFunctionSetup()..
   */

  /* Desc: USB Write routine for OUT transfers
   *       the V-USB drivers call this function on OUT tokens
   *       and provide upto 8 byte data packet's payload
   *       for payloads longer than 8Bytes this gets called multiple times
   *       until all bytes have been transferred.  Real thing to understand
   *       is that this function gets called once per data packet (max 8bytes)
   *       based on USB 1.1 low speed standard.
   *       buffer.c is the govnerning module for what buffer gets filled
   * Pre:  buffer.c must have set current usb loading buffer with global var
   *       the current buffer must have enough room for incoming data
   *       possible to use mutliple buffers for a single transfer, but
   *       buffer.c must orchestrate the swap to new buffer object.
   *       buffer.c sets global incoming bytes remain so it can keep
   *       track of this function's progress
   *       buffer object must be initialized, allocated, and status USB_LOADING
   * Post: usbWrite_status updated with SUCCESS/ERROR number
   *       incoming data packet copied to cur_usb_load_buff
   *       global incoming_bytes_remain updated
   *       cur_usb_load_buff cur_byte updated based on data length
   *       cur_usb_load_buff status updated when it's full
   * Rtn:  message to V-USB driver so it can respond to host
   */

  //removing checks from this function speeds up transfers by ~1KBps
  //this data is based on doing nothing with data once it arrives
  //long transfers disabled, and using 254 byte transfers with 2 bytes stuffed in setup packet
  // with checks: 512KByte = 18.7sec = 27.4KBps
  // w/o  checks: 512KByte = 17.9sec = 28.5KBps
  // w/o  checks: using 8bit rlen = 17.5sec = 29.2KBps
  // with checks: using 8bit rlen = 18sec   = 28.3KBps
  //#define MAKECHECKS

#ifdef AVR_CORE
  USB_PUBLIC uchar usbFunctionWrite(uchar * data, uchar len)
  {
#endif

#ifdef STM_CORE
  #define USBWRITE	__attribute__ ((section (".usbFuncWrite"), noinline, noclone))
    //noinline should keep these functions at beinging of flash (.text)
    //they need to be in the first 64KByte which is non issue with C6, but could prob with RB
    USBWRITE uint8_t usbFunctionWrite(uint8_t* data, uint8_t len)
    {
#endif

      //defined and controled by buffer.c
      extern buffer* cur_usb_load_buff;
      extern uint8_t incoming_bytes_remain;

      uint8_t data_cur = 0;                          //current incoming byte to copy
      uint8_t buf_cur = cur_usb_load_buff->cur_byte; //current buffer byte
      uint8_t* buf_data = cur_usb_load_buff->data;   //current buffer data array

#ifdef MAKECHECKS
      //check that current buffer's status is USB_LOADING
      if(cur_usb_load_buff->status != USB_LOADING) {
        usbWrite_status = ERR_OUT_CURLDBUF_STATUS;
        return STALL;
      }
      //check that current buffer's has enough room
      if(((cur_usb_load_buff->last_idx) + 1 - buf_cur) < len) {
        usbWrite_status = ERR_OUT_CURLDBUF_TO_SMALL;
        return STALL;
      }
#endif

      //copy 1-8bytes of payload into buffer
      while(data_cur < len) {
        buf_data[buf_cur] = data[data_cur];
        buf_cur++;
        data_cur++;
      }

#ifdef MAKECHECKS
      //need to account for the fact that cur_byte will roll over being 8bit value
      if(cur_usb_load_buff->last_idx == (cur_usb_load_buff->cur_byte + len - 1)) {
        //this signals to buffer.c so it can update cur_usb_load_buf
        //and start tasking this buffer to programming
        cur_usb_load_buff->status = USB_FULL;
      }
#endif

      //update counters and status
      cur_usb_load_buff->cur_byte += len;
      incoming_bytes_remain -= len;
      //usbWrite_status = SUCCESS;

      //want this function to be as fast as possible, so buffer.c checks if
      //the buffer is full 'behind the scenes' outside of this function.

      if(incoming_bytes_remain == 0) { //done with OUT transfer
        //alternate to MAKECHECKS should be faster but require transfer sizes to match buffer size
        cur_usb_load_buff->status = USB_FULL;
        return PAYLD_DONE;
      } else { //more data packets remain to complete OUT transfer
        return NOT_DONE;
      }
    }
