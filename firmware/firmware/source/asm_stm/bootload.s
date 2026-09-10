

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


			
.globl   jump2addr
.p2align 2
.type    jump2addr,%function
	//;r0 - r3 contain function args (excess on stack)
	//;jump2addr( data_pb, spddir_len, swim_base, swim_mask);
	//;spddir_len = (SWIM_RD_LS<<16) | len;
//;	stream		.req	a1	this arg is moved to variable reg after stack push
	addr		.req	a1
//;	rv		.req	r0
//;	len		.req	a2
//;	swim_base	.req	a3
//;	swim_mask	.req	a4
jump2addr:	//;Function entry point.
.fnstart

	//;bkpt
	blx	r0
.fnend
