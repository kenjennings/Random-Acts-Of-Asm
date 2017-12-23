# Random-Acts-Of-Asm
Random bits and bytes of Atari 6502 assembly.

Also refer to **HelloWhirled** repository at https://github.com/kenjennings/HelloWhirled which includes several conventional and some bizzare and weird ways to make text appear on the Atari's screen.

**GTIA256.asm**

Sets up a simple GTIA mode 9 display (16 grey scales) and uses DLIs to change the base color 16 times to display all 256 GTIA colors.

It's not a real GTIA mode 9 display.  There is only one line of screen memory defined that shows pixels from color 0 to 15 across the width of the screen:

```asm
; Each Block on screen is 5 GTIA pixels wide.
; Blocks range from value 0 to 15.

SCREEN_MEM
	.byte $00,$00,$01,$11,$11
	.byte $22,$22,$23,$33,$33
	.byte $44,$44,$45,$55,$55
	.byte $66,$66,$67,$77,$77
	.byte $88,$88,$89,$99,$99
	.byte $aa,$aa,$ab,$bb,$bb
	.byte $cc,$cc,$cd,$dd,$dd
	.byte $ee,$ee,$ef,$ff,$ff
```

The display list for the screen uses LMS with all the ANTIC instructions, and so displays the same screen data for every line on the screen.

[![GTIA256](https://github.com/kenjennings/Random-Acts-Of-Asm/blob/master/GTIA256.png)](#GTIA256)


**font_left_scroll1.asm**

This is originally from:
https://github.com/graydefender/RandomStuff/blob/master/leftshift.asm
This is an Atari port of a C64 example performing horizontal text scrolling using ROL on the character bitmaps.  The shifting parts function identically on the Atari as the C64, since both use the same bitmap organization for the character set. 

This version uses smaller looping code, but takes much longer to execute.  It runs for almost the entire frame.  There is a little code near the start of the program that can be uncommented to experiment with the display list.  This extra code replaces most of the display list's Text Mode 2 instructions with Blank Line instructions which do not require DMA for screen memeory or the character set.  When the display is mostly blank lines the ROL routine finishes in about 2/3 of the frame.

The program includes a few extra bells and whistles to provide visual feedback of the amount of time per frame used for the shifting, plus additional on-screen text to explain the visual indicator. 

[![font_left_scroll1](https://github.com/kenjennings/Random-Acts-Of-Asm/blob/master/font_left_scroll1.png)](#font_left_scroll1)


**font_left_scroll2.asm**

This is originally from:
https://github.com/graydefender/RandomStuff/blob/master/leftshift2.asm
This is an Atari port of a C64 example performing horizontal text scrolling using ROL on the character bitmaps.  The shifting parts function identically on the Atari as the C64, since both use the same bitmap organization for the character set. 

This version uses unrolled direct code to ROL 320 bytes of font bitmap data.  The code is much larger, but executes faster.  The ROL routine completes in just about 32 scan lines.

The program includes a few extra bells and whistles to provide visual feedback of the amount of time per frame used for the shifting, plus additional on-screen text to explain the visual indicator. 

[![font_left_scroll2](https://github.com/kenjennings/Random-Acts-Of-Asm/blob/master/font_left_scroll2.png)](#font_left_scroll2)


