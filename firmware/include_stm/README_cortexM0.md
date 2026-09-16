Paul's super awesome bare cortex M0 bare metal project.

Got tired sifting through existing bare metal template projects and not liking how everything was setup.
Also feel silly starting such a simple project with some sort of licensing to bother with.
Stumbled upon the example projects included with arm-none-eabi-gcc compiler and decided that was as good as starting point as any.
So that's where the files originated from.

I cut out files not used by cortex M0 or the minimum example.
Then reorganized the directory into how I like things by default.
Combined everything into one single Makefile and added creation of hex/binary file output and size reporting.

This could easily be migrated to different core M0plus etc, just by including the proper startup file and modifying Makefile.

When using as template first thing to do is modify linker file for memory sizes of target chip.
Don't forget to update CPU frequency as needed for any time functions.
Then bring in some library/header files for registers included with target chip.
Finally do something useful in init and main.

There is option to use nano new lib or not in Makefile for things like printf and malloc which doesn't sound very bare metal to me..
But whatev it's there and ready to turn on if needed.

Current size:
   text    data     bss     dec     hex filename
    148       0       0     148      94 build/baremetal.elf

Pertenent sections of readme from samples dir:

ldscripts/mem.ld defines address ranges for flash and RAM. Modify them to
reflect start address and length of flash/RAM banks in your board, by
following the embedded comments.

Recommend to make clean after modifying mem.ld.

** minimum - A minimum skeleton to start a C program with limited features.
This case has a empty main. Code size built from it is only about 150 bytes,
since it has almost no "fat" for a Cortex-M C program. Be noticed that this
case doesn't support semihosting or C++ global constructor/destructor.

