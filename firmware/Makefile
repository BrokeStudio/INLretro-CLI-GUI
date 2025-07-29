#Single Makefile for all devices

all:
	make -f Make_stm_nes clean all
	mkdir -p build_stmn
	cp -r build_stm/* build_stmn
	make -f Make_stm_inl6 clean all
	mkdir -p build_stm6
	cp -r build_stm/* build_stm6
	make -f Make_avr clean hex

avr:
	make -f Make_avr clean all
	# program
stm6:
	make -f Make_stm_inl6 all
	# program
stm6clean:
	make -f Make_stm_inl6 clean all
	cp -r build_stm/* build_stm6
stm6p:
	make -f Make_stm_inl6p clean all
	# program
stmad:
	make -f Make_stm_adapter clean all
	# program
stmn:
	make -f Make_stm_nes clean all
	# program
