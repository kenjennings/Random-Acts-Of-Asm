# Random-Acts-Of-Asm
Random bits and bytes of Atari 6502 assembly.

Also refer to HelloWhirled repository at https://github.com/kenjennings/HelloWhirled which includes several conventional and weird ways to output text to the screen.

**GTIA256.asm**

Sets up a simple GTIA mode 9 display (16 grey scales) and uses a DLI to display all 256 GTIA colors.

**font_left_scroll1.asm**

originally from:
https://github.com/graydefender/RandomStuff/blob/master/leftshift.asm
This is an Atari port of a C64 example perfomring horizontal text scrolling using ROL on the character bitmaps.  Functionally, the shifting parts work identically on the Atari as the C64, since both use the same bitmap organization for the character set. This version uses shorter looping code, but takes longer to execute.

