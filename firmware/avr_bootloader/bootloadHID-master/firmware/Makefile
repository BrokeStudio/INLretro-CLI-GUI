# Name: Makefile
# Project: bootloadHID
# Author: Christian Starkjohann
# Creation Date: 2007-03-19
# Tabsize: 4
# Copyright: (c) 2007 by OBJECTIVE DEVELOPMENT Software GmbH
# License: GNU GPL v2 (see License.txt)
# This Revision: $Id: Makefile 788 2010-05-30 20:54:41Z cs $
#
# Edited for INL Retro-Prog "kazzo" project
# Uses Atmega164p

###############################################################################
# Configure the following variables according to your AVR. The example below
# is for an ATMega8. Program the device with
#     make fuse    # to set the clock generator, boot section size etc.
#     make flash   # to load the boot loader into flash
#     make lock    # to protect the boot loader from overwriting

DEVICE = atmega164a
#BOOTLOADER_ADDRESS = datasheet: 0x1C00 * 2words/address = 0x3800
BOOTLOADER_ADDRESS = 3800
F_CPU = 16000000

###############################################################################
#			ATMEGA-164A FUSE TABLE
#	see datasheet for further explaination of each fuse
###############################################################################
#
# Lock bit byte:
# Default: all set 0xFF
#         +------------------- unused/reserved (def prgm = 1)
#         |  +---------------- BLB12 read BL section  1=allowed
#         |  | +-------------- BLB11 write BL section 0=allowed
#         |  | |   +---------- BLB02 read app section   1=allowed
#         |  | |   | +-------- BLB01 write app section  1=not allowed
#        / \ v v   v v /-v---- LB[2:1] lock chip 11=unlocked
# 0xEF = 1 1 1 0   1 1 1 1
LOCK  = 0xEF
#
#
# Extended fuse byte:
# Default: all set 0xFF
#             +--------------- unused/reserved (def prgm = 1)
#             |        +------ BODLEVEL[2:0]
#        /----+----\ /-+-\     111=BOD disbl 110=BOD 1.8V
# 0xFD = 1 1 1 1   1 1 0 1     101=BOD 2.7V  100=BOD 4.3V
EFUSE = 0xFD
#
#
# Fuse high byte:
# Default: 0x99
#        +-------------------- OCDEN  1=On-Chip-Debugger disabled
#        | +------------------ JTAGEN 1=JTAG disabled (enabled caused problems!)
#        | | +---------------- SPIEN  0=SPI prgm/dwnld enabled
#        | | | +-------------- WDTON  1=WDT not always on
#        | | | |
#        | | | |   +---------- EESAVE 1=eeprom not preserved w/chip erase
#        | | | |   |  +------- BOOTSZ[1:0] bootloader size
#        v v v v   v / \       00=1Kwords App end= 0x1BFF BL start=0x1C00
# 0xD8 = 1 1 0 1   1 0 0 0 <-- BOOTRST 0=reset vector-> BL section
FUSEH = 0xD8
#
#
# Fuse low byte: 0xDF
# Default: 0x62
#        +-------------------- CKDIV8 1=Clock not divided by 8
#        | +------------------ CKOUT  1=Don't allow CLK O/P on PORTB1
#        | |  +--------------- SUT[1:0]  01=xtal BOD enabled
#        | |  |       +------- CKSEL[3:0] 1111=low pwr xtal 8-16Mhz 
#        v v / \   /--^--\          [3:1] 111=low power 8-16Mhz
# 0xDF = 1 1 0 1   1 1 1 1            [0] 1= xtal
FUSEL = 0xDF
#
###############################################################################

AVRDUDE = avrdude -c stk500v2 -P avrdoper -p $(DEVICE)

LDFLAGS += -Wl,--relax,--gc-sections -Wl,--section-start=.text=$(BOOTLOADER_ADDRESS)

# Omit -fno-* options when using gcc 3, it does not support them.
COMPILE = avr-gcc -Wall -Os -fno-move-loop-invariants -fno-tree-scev-cprop -fno-inline-small-functions -Iusbdrv -I. -mmcu=$(DEVICE) -DF_CPU=$(F_CPU) -DDEBUG_LEVEL=0 # -DTEST_MODE
# NEVER compile the final product with debugging! Any debug output will
# distort timing so that the specs can't be met.

OBJECTS =  usbdrv/usbdrvasm.o usbdrv/oddebug.o main.o


# symbolic targets:
all:	main.hex

.c.o:
	$(COMPILE) -c $< -o $@

.S.o:
	$(COMPILE) -x assembler-with-cpp -c $< -o $@
# "-x assembler-with-cpp" should not be necessary since this is the default
# file type for the .S (with capital S) extension. However, upper case
# characters are not always preserved on Windows. To ensure WinAVR
# compatibility define the file type manually.

.c.s:
	$(COMPILE) -S $< -o $@

flash:	all
	$(AVRDUDE) -U flash:w:main.hex:i

readflash:
	$(AVRDUDE) -U flash:r:read.hex:i

fuse:
	$(AVRDUDE) -U hfuse:w:$(FUSEH):m -U lfuse:w:$(FUSEL):m -U efuse:w:$(EFUSE)

lock:
	$(AVRDUDE) -U lock:w:$(LOCK):m

read_fuses:
	$(UISP) --rd_fuses

clean:
	rm -f main.hex main.bin *.o usbdrv/*.o main.s usbdrv/oddebug.s usbdrv/usbdrv.s

# file targets:
main.bin:	$(OBJECTS)
	$(COMPILE) -o main.bin $(OBJECTS) $(LDFLAGS)

main.hex:	main.bin
	rm -f main.hex main.eep.hex
	avr-objcopy -j .text -j .data -O ihex main.bin main.hex
	avr-size main.hex

disasm:	main.bin
	avr-objdump -d main.bin

cpp:
	$(COMPILE) -E main.c

size: ${TARGET}
	@echo
	@avr-size -C --mcu=${MCU} ${TARGET}
