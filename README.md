# Random-Acts-Of-Asm
Random bits and bytes of Atari 6502 assembly.

Also refer to HelloWhirled repository at https://github.com/kenjennings/HelloWhirled which includes several conventional and weird ways to output text to the Atari's screen.

**GTIA256.asm**

Sets up a simple GTIA mode 9 display (16 grey scales) and uses DLIs to change the base color 16 times to display all 256 GTIA colors.

[![GTIA256](https://github.com/kenjennings/Random-Acts-Of-Asm/blob/master/GTIA256.png)](#GTIA256)


**font_left_scroll1.asm**

This is originally from:
https://github.com/graydefender/RandomStuff/blob/master/leftshift.asm
This is an Atari port of a C64 example performing horizontal text scrolling using ROL on the character bitmaps.  The shifting parts function identically on the Atari as the C64, since both use the same bitmap organization for the character set. 

This version uses smaller looping code, but takes longer to execute.  Almost the entire frame.

The program include a little extra code to provide visual feedback of the amount of time per frame used for the shifting, plus some on-screen labeling to explain the visual indicator. 

[![font_left_scroll1](https://github.com/kenjennings/Random-Acts-Of-Asm/blob/master/font_left_scroll1.png)](#font_left_scroll1)


**font_left_scroll2.asm**

This is originally from:
https://github.com/graydefender/RandomStuff/blob/master/leftshift2.asm
This is an Atari port of a C64 example performing horizontal text scrolling using ROL on the character bitmaps.  The shifting parts function identically on the Atari as the C64, since both use the same bitmap organization for the character set. 

This version uses unrolled direct code to ROL 320 bytes of font bitmap data.  The code is much larger, but executes faster.  It completes in just about 32 scan lines.

The program include a little extra code to provide visual feedback of the amount of time per frame used for the shifting, plus some on-screen labeling to explain the visual indicator. 

[![font_left_scroll2](https://github.com/kenjennings/Random-Acts-Of-Asm/blob/master/font_left_scroll2.png)](#font_left_scroll2)


