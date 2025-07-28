

//;Ensure that your assembly code complies with the Procedure Call Standard for the ARM Architecture (AAPCS).
//;
//;The AAPCS describes a contract between caller functions and callee functions. For example, for integer or pointer types, it specifies that:
//;
//;    Registers R0-R3 pass argument values to the callee function, with subsequent arguments passed on the stack.
//;    Register R0 passes the result value back to the caller function.
//;    Caller functions must preserve R0-R3 and R12, because these registers are allowed to be corrupted by the callee function.
//;    Callee functions must preserve R4-R11 and LR, because these registers are not allowed to be corrupted by the callee function.
//;
//;For more information, see the Procedure Call Standard for the ARM Architecture (AAPCS).

//;WARNING!!!   logic instructions all affect flags despite the 's' postfix arm_none_eabi_gcc doesn't like 's' instructions
//;		but the 's' affect flag instructions are the only ones the M0 supports
//;		because of this, issue the following code isn't compatible with other cores.


.equ	BSSR,	0x18
.equ	BRR,	0x28
.equ	OTYPER,	0x04
.equ	IDR,	0x10
.equ	NO_RESP,	0xFF
.equ	ACK,	0x01
.equ	NAK,	0x00
.equ	HERR,	0x0E
.equ	PERR,	0x09

.macro	swim_lo
	strh	swim_mask, [swim_base, #BRR]
.endm
.macro	swim_hi
	strh	swim_mask, [swim_base, #BSSR]
.endm
.macro	swim_pp
	strh	pushpull, [swim_base, #OTYPER]
.endm
.macro	swim_od
	strh	opendrain, [swim_base, #OTYPER]
.endm

.equ	SWIM_RD,	0x01
.equ	SWIM_WR,	0x02
.equ	SWIM_HS_BIT,	4
.equ	SWIM_HS_MSK,	0x10
.equ	HS_DELAY,	4
.equ	LS_DELAY,	22
			
.globl   swim_xfr
.p2align 2
.type    swim_xfr,%function
	//;r0 - r3 contain function args (excess on stack)
	//;swim_xfr( data_pb, spddir_len, swim_base, swim_mask);
	//;spddir_len = (SWIM_RD_LS<<16) | len;
//;	stream		.req	a1	this arg is moved to variable reg after stack push
	stream_arg	.req	a1
	rv		.req	r0
	len		.req	a2
	swim_base	.req	a3
	swim_mask	.req	a4
swim_xfr:	//;Function entry point.
.fnstart

	//;need a few extra variable registers, but they need to be preserved
	pushpull	.req	v1
	opendrain	.req	v2
	stream		.req	v3
	speed		.req	v4
	//;high registers r8-r12 are very limited following instructions can utilize them
	//; ADD, CMP, LDR PC-rel, BX, BLX, MSR, MSR
	//; Docs list that MOV can only use R0-7, but testing and compilation proves otherwise
	//; Additionally, arm_none_eabi_gcc uses MOV R8, R8 as it's NOP!!
	rdwr	.req	v5
	push	{pushpull, opendrain, stream, speed, lr}
	mov	speed,	rdwr //;preserve r8 high register can't pop/push
	push	{speed}

	//; move stream arg out of r0, and into variable register so r0 is free
	mov	stream,	stream_arg

	//; len contains speed and direction data, must trim off and move
	//; into variable registers
	//;spddir_len = (SWIM_RD/WR_LS/HS<<16) | len;
	mov	r0, len
	lsr	r0, #16
	cmp	r0, #SWIM_HS_MSK
	bpl	high_speed
	mov	speed, #LS_DELAY
	b	speed_dir
high_speed:
	mov	speed, #HS_DELAY
speed_dir:
	//;mask out speed bit and store in rdwr
	//;shift speed bit left past carry
	lsl	r0, #(16-SWIM_HS_BIT + 16)	//;16-BIT shifts bit to b16, 16 shifts to carry = 28
	lsr	r0, #(16-SWIM_HS_BIT + 16)	//;carry doesn't shift in
	mov	rdwr, r0

	//; mask out upper bits of len
	mov	r0, #0xFF
	and	len, r0


	//; ~83nsec per unit of delay change
	//;mov	speed, #22	//;22 = 2.75usec bit time delay variable
	//;mov	speed, #4	//;4  = 1.25usec bit time delay variable
	//;mov	speed, #22

//;TODO should probably disable interrupts while transferring data via SWIM as it's timing sensitive
//;	haven't touched this code in awhile and can't get myself to make this update right now..
//;	may want something similar when entering swim activation

	//; set pushpull and opendrain to values we can write to otyper register
	//; to quickly change direction of the SWIM pin only
	ldr	pushpull, [swim_base, #OTYPER]
	mov	opendrain, pushpull
	//; variables hold current OTYPER register value
	//; set bit for opendrain, clear for pushpull
	orr	opendrain, swim_mask
	bic	pushpull, swim_mask

	//; now these registers can be written directly to otyper GPIO reg 
	//; to quickly change SWIM pin direction and not affect other pins

	//;set flags so first bit is header '0' "from host"
	//;the stream comes in as 16bit value with stream bit 7 in bit position 15
	//;shift the stream left so the current transfer bit is in bit position 31
	//;15 -> 30 is 15bit shifts, this leaves header zero in bit position 31
	//;store stream in r4
	lsl	stream, #15


bit_start:

	//;always start going low
	swim_lo

	//;current bit is stored in bit31 and Negative flag is set if 
	//;current bit is '1'
	bpl	cur_bit_zero

	//;delay to extend low time for '1'
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	//;go high since current bit is '1' 
	swim_pp
	swim_hi
	swim_od
	b	det_next_bit

cur_bit_zero:
	//;must delay same amount of time as instructions above since branch
	//;add delay here to make '0' longer until equal to '1'
	mov	r0, #1	
	bl	delay_r0
	
det_next_bit:
	//;determine if this is the last bit
	sub	len, #1

	//;if last bit, go to stream end to prepare for ACK/NAK latch
	bmi	out_end

	//;delay until 'go high' time for '0'
	//;add delay here to make all bit transfers longer
	//;20-> 2.56usec bit time
	//;21-> 2.65usec
	//;22-> 2.73usec
	mov	r0, speed	;//4-HS 22-LS
	bl	delay_r0
	nop	//;22+nop = 2.75usec = low speed timing perfect!

	//; high speed bit time has same 0-high, 1-lo time
	//; only difference is bit time is 1.25usec

	//;Negative flag is now set for '1', and clear for '0'
	//;always go high for '0' (no effect if already high for '1')
	swim_pp
	swim_hi
	swim_od

	//;delay to extend high time of '0'
	nop
	nop

	//;determine next bit value
	lsl	stream,	#1
	
	//;go to bit start
	b	bit_start

out_end:
	//;delay until 'go high' time for '0'
	mov	r0, speed
	sub	r0, #1		;//this decrement keeps both HS and LS perfectly aligned
	bl	delay_r0

	//;always go high for '0' (no effect if already high for '1')
	swim_pp
	swim_hi
	swim_od

	//;delay until time to latch ACK/NAK from device
	mov	r0, #4	//;1-2:NR 3: usually RESP, not always/5-varies RESP/NO RESP
	//; sometime the device takes longer...
	//; 3 was failing for some, inc to 5
	//; 5 works, '1' NAK has low pulse width of 500-600nsec, trying 4
	//; 4 seems stable.  low pulse time is 400-550nsec
	bl	delay_r0

	//;first need to ensure device is actually responding
	//;sample when output should be low for a 1 or 0
	//;appears the device inserts a little delay ~220nsec between final host bit
	//;and ACK/NAK
	//;total time between host high (parity bit = '0')
	//;and device ACK/NAK low is ~450nsec

	//;debug toggle pushpull below
	//;measurements showed pulse ~100nsec after device took SWIM low with 3 above
	//;swim_pp
	//;swim_od

	//;latch SWIM pin value from GPIO IDR
	ldrh	rv, [swim_base, #IDR]
	and	rv, swim_mask
	
	
	//;if it wasn't low, then the device didn't respond, so return error designating that
	//;__asm volatile ("bne no_response\n\t");
	beq	wait_ack_nak

	//;return 0xFF
	mov	rv, #NO_RESP
	b	exit_swim

wait_ack_nak:
	//;don't have a strong enough pull-up resistor on SWIM pin
	//;to compensate for this we can cheat by quickly toggling
	//;to push-pull after device should have gone high for ACK = '0'
	//;this does create bus contension for breif period but don't have much choice here..
	//;only other alternative is to install pullup on board/programmer
	//;swim_pp	no delay_r0 outputs pulse ~240nsec after device goes low with 3 above
	//;swim_od

	//; 3 above, and 2 here equates to pulse high 640nsec after device goes low
	//; 3 above, and 1 here equates to pulse high 460nsec after device goes low
	//; 3 above wasn't stable, incremented to 4 and works, give 400-550nsec pulse low
//;	mov	r0, #1 		
//;	bl	delay_r0	
	;//r0=1: for ACK, artf pullup enabled 150-300nsec after device stops driving low
	;//this is okay timing allowance as being early would cause misread
	;//could possibly tighten with nops instead..
	nop
	nop
	nop
	nop	//;4 nops = 250-350nsec low pulse width for ACK '1'
	nop
	nop	//;5 nops = 300-450nsec low pulse width
	swim_pp
	swim_od

	//;now we can sample for NAK/ACK as artifical pullup has been inserted above
	//;if device output ACK, the artificial pullup doesn't cause contension
	//;but if device output NAK "0" device should still be driving low

	//;latch SWIM pin value from GPIO IDR
	ldrh	rv, [swim_base, #IDR]
	and	rv, swim_mask

	//; NAK: rv=0, ACK: rv=swim_mask
	beq	return_nak

	mov	rv, #ACK
	//; device sent ACK, if this is a read operation
	//; need to capture data sent by the device
	mov	stream, #SWIM_WR
	cmp	rdwr, stream
	beq	exit_swim

	//; Sent the last byte of the command successfully
	//; Now read in data from device
	//; A bit of a challenge because of lacking legit pullup

	//; setup for read transfer
	mov	len,	#9	//;read 9bits total, then output ACK

	//; poll until device takes SWIM low for header bit
	//; perhaps setting an interrupt and waiting for it would be better
	//; due to less jitter from polling..
poll_header:
	ldrh	stream, [swim_base, #IDR]
	and	stream, swim_mask
	bne	poll_header

	//;device took SWIM low
	//;pulse for artifical pullup
	mov	r0, #1 		//;1: 350-450nsec equates to 100-200nsec delay ~okay
	bl	delay_r0	

	//;nop
	//;nop
	//;nop	//; 3xnop = 250-300nsec low pulse for '1' header from device
	//;nop	//; 4xnop = 250-350nsec
	//;nop	//; 5xnop = 250-300	never seems to change!!!!

	//; the device seems to stall for a little bit due to the delayed pull-up
	//; the bit time for the header seems to extend to ~3usec
	//; but perhaps we can take advantage of this to better align with the device
	//; add delay between here and read_next_bit to lengthen header bit

	//; seemed to be a little early at times..
	swim_pp
	nop
	swim_od

	//; adding delay to extend header bit which always seems 250nsec longer than it should be
	nop	//; 1x NOP fails pretty hard header errors @ slow speed
	//; moved second NOP between pp->od to try and reduce header errors @ low speed
//;	nop	//; 2x NOP seems pretty good, sometimes fails in slow speed, but pretty good @ high speed
	//; can usually get 1 out of 12 low speed to fail, and sometimes HS will fail hard
//;	nop	//; 3x NOP seems more likely to fail @ low speed than 3x
	//; hard to say if 3x NOP is actually better, it might succeed more on reads, but switching to HS seems to fail more often
	b read_next_bit
	
.p2align 4
read_next_bit:
	swim_pp
	swim_od
	//; header bit '1' is now high

	//; give a little delay between push pulse and reading
	//; this instruction can be performed out of order
	//; this didn't end up being a real problem, but it can't hurt
	lsl	stream, #1

	//; read bit, should be '1' for header on first read
	//; sample and place value in carry, then rotate in
	ldrh	r0, [swim_base, #IDR]
	and	r0, swim_mask
	//; Z flag contains inverse of bit
	mrs	r0, APSR
	//; bit 30 of r0 contains inverse of bit
	//; shift left to mask away any upper bits
	lsl	r0, #1
	//; shift right to mask away lower bits
	lsr	r0, #31
	//; shift stream and or in r0 (stream does have mask bit set from poll loop)
	//; moved up to provide delay between push and read
	//;lsl	stream, #1
	orr	stream, r0
	//; now stream holds the inverse stream (plus mask junk on upper half)

	
	//; wait bit time, enable artifical pullup, and sample
	mov	r0, speed
	sub	r0, #2		//; need to save some delay for after pushing '0' high
	bl	delay_r0	

	//;	push high for logic '0'
	//;swim_pp
	//;swim_od
	//;mov	r0, #2
	//;bl	delay_r0	

	//; above isn't always getting SWIM pin high for '0'
	//; can only assume that it's too early
	swim_pp
	swim_od
	mov	r0, #2
	bl	delay_r0	

	//; seems to drop out at times..
	//; adding a check here to verify that SWIM is high looks like it would 
	//; catch when the device drops out

	//; check if last bit in read
	sub	len, #1
	//;if last bit, go to stream end to prepare for ACK/NAK latch
	bpl read_next_bit

	//; last bit calc and send parity, or just always send ACK
	//; could send back to poll header but not sure it's worth retrying..
	//; not sure a failure would even allow us to properly send a NAK

always_send_ack:
	//; ACK is a '1' from host, so need a short pulse low
	//; this is actually a little late, but seems the device sends it a little late as well
	//; so this happens to align pretty well with the device's timing
	swim_lo
	swim_pp
	mov	r0, #1
	bl	delay_r0	
	swim_hi
	swim_od

	//; check that SWIM is actually high
	//; if device failed it's possible pairity still passed
	//; but device sensed reset condition due to lack of legit pullup
	//; in which case it would likely be outputing low now for 16usec

	//; organize return data
	//; MSB NAK/NORESP from last write
	//; if ACK, then return read result
	//; TIMEOUT, HEADER error, PAIRITY error
	//; ACK entire transfer good!
	//; LSB data read back

	//; stream data sturcture
	//; upper bits may contain swim_mask value
	//; all values inverted:
	//; b9 header '1' -> '0'
	//; b8-1 data inverted 1's compliment
	//; b0 pairity inverted

	//; write corrupted data for testing
	//; inverted 1 header bit - F0 data - 0 pairitybit
	//;          0		    0F        1
//;	mov	stream, #0x1F	;// good data should report 0xF0 - ACK
//;	mov	stream, #0x1E	;// toggle pairity data should report PAIRITY ERROR

;// bad header data
//;	mov	stream, #0x80	
//;	mov	rv, #2
//;	lsl	stream, rv
//;	mov	rv, #1		;// set correct pairity
//;	orr	stream, rv

	//; store result as-is
	mov	rv, stream

	//; check that header was read as '1' (from device) and stored as '0'
	mov	len, #0x80	;// bad header data would have bit 9 set ('1' device header is inverted)
	mov	swim_mask, #2		
	lsl	len, swim_mask 	;// shift bit 7 into bit 9
	and	stream, len
	//; should be zero if header stored as '0'
	bne	header_error
	
	//; calc pairity
	//; must add to registers to add with carry
	//; swim_mask no longer needed
	mov	swim_mask, #0
	//; store stream temporarily in len reg while shifting pairity bit to carry
	lsr	len, rv, #1	

	//; stream should be zero on entry
	//; add inverted pairity bit
	adc	stream, swim_mask
	lsr	len, #1
	//; add bit0-3
	adc	stream, swim_mask
	lsr	len, #1
	adc	stream, swim_mask
	lsr	len, #1
	adc	stream, swim_mask
	lsr	len, #1
	adc	stream, swim_mask
	lsr	len, #1
	//; add bit4-7
	adc	stream, swim_mask
	lsr	len, #1
	adc	stream, swim_mask
	lsr	len, #1
	adc	stream, swim_mask
	lsr	len, #1
	adc	stream, swim_mask

	//; individual sumation of all bits should be even when pairity included
	//; but for inverted data, the sum should be odd
	//; shift sum lsbit into carry and verify it's set (equates to odd)
	lsr	stream, #1
	bcc	pairity_error

	//; all is good, just return the inverted data!
	lsr	rv, #1
	//; mask out data alone
	mov	len, #0xFF
	and	rv, len
	//; invert data to true data
	eor	rv, len
	
	//; shift to upper byte
	lsl	rv, #8
	//; add in the ACK to lower byte
	add	rv, #ACK
	//; since things are little endian
	//; the output is a 16bit int
	//; so the value we output will be byte swapped
	//; when interpreted as 16bit int
	
	b	exit_swim
	
header_error:
	//; header wasn't '1' as expected when reading from device
	mov	rv, #HERR
	b	exit_swim

pairity_error:
	mov	rv, #PERR
	b	exit_swim

return_nak:
	mov	rv, #NAK

exit_swim:
	//;r0 contains return value on exit (already done prior to this point)
	//;r4-r11 & lr must be preserved to entry values
	pop	{speed}
	mov	rdwr,	speed	//;restore r8 high register can't pop/push
	pop	{pushpull, opendrain, stream, speed, pc}

//;	bx	lr	//;Return by branching to the address in the link register.
.fnend


//;.globl   delay_r0
//; ~83nsec per unit of delay change
.p2align 2
.type    delay_r0,%function
	count		.req	a1
delay_r0:	//;Function entry point.
	.fnstart
	sub	count, #1
	bne	delay_r0
	bx	lr
	.fnend
