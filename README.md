# Random-Acts-Of-Asm
Random bits and bytes of Atari 6502 assembly.

Also refer to HelloWhirled repository at https://github.com/kenjennings/HelloWhirled which includes several conventional and weird ways to output text to the screen.

**GTIA256.asm**

Sets up a simple GTIA mode 9 display (16 grey scales) and uses a DLI to display all 256 GTIA colors.

**font_left_scroll1.asm**

originally from:
https://github.com/graydefender/RandomStuff/blob/master/leftshift.asm
Atari port of horizontal text scrolling using ROL on the character bitmaps.
This version uses shorter looping code, but takes longer to execute.
