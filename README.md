# Random-Acts-Of-Asm
Random bits and bytes of Atari 6502 assembly.

| Topic | Program | Summary | 
| ----- | ------- | ------- |
| Color, Color, Color | [GTIA256.asm](https://github.com/kenjennings/Random-Acts-Of-Asm/blob/master/GTIA256.asm "GTIA256.asm") | Display all 256 colors on one screen. |
| "Writing" Text | [ATARI_ATASM_CIO_PUTBYTES.asm](https://github.com/kenjennings/HelloWhirled/blob/master/ATARI_ATASM_CIO_PUTBYTES.asm "ATARI_ATASM_CIO_PUTBYTES.asm") | Use the official, legally sanctioned call through the OS Central I/O to write the string to the screen (E: device.) |
| | [ATARI_ATASM_CIO_PUTCHEAT.asm](https://github.com/kenjennings/HelloWhirled/blob/master/ATARI_ATASM_CIO_PUTCHEAT.asm "ATARI_ATASM_CIO_PUTCHEAT.asm") | Uses the OS Central I/O in a slightly less than sanctioned way to write the characters to the screen (E: device.)  It reduces the IOCB set up by calling Atari BASIC's PUT CHAR vector in the IOCB channel. |
| | [ATARI_ATASM_DIRECTWRITE.asm](https://github.com/kenjennings/HelloWhirled/blob/master/ATARI_ATASM_DIRECTWRITE.asm "ATARI_ATASM_DIRECTWRITE.asm") | Uses the OS's Page 0 pointer to the current display to write (or, POKE) directly into screen memory. |
| | [ATARI_ATASM_DISPLAYLIST.asm](https://github.com/kenjennings/HelloWhirled/blob/master/ATARI_ATASM_DISPLAYLIST.asm "ATARI_ATASM_DISPLAYLIST.asm") | Display text without executing any code. Uses the Atari's executable load file to replace the OS's default display list LMS address operand's value with the address of the desired text string in memory. |
| | [ATARI_ATASM_DISPLAYLIST_EXTRA.asm](https://github.com/kenjennings/HelloWhirled/blob/master/ATARI_ATASM_DISPLAYLIST_EXTRA.asm "ATARI_ATASM_DISPLAYLIST_EXTRA.asm") |  Display text without executing any code. Uses the Atari's executable load file to load a minimal display list showing the text, and directly updates the OS's ANTIC shadow registers to install the display list. |
| | [ATARI_ATASM_SCREENRAM.asm](https://github.com/kenjennings/HelloWhirled/blob/master/ATARI_ATASM_SCREENRAM.asm "ATARI_ATASM_SCREENRAM.asm") | Display text without executing any code. Uses the Atari's executable load file to load the text directly into the screen RAM for the OS's default text display. |
| Horizontal Scrolling | [font_left_scroll1.asm](https://github.com/kenjennings/Random-Acts-Of-Asm/blob/master/font_left_scroll1.asm "font_left_scroll1.asm") | Scroll text by shifting character bitmaps through a sequential line of characters in a soft character set. |
| | [font_left_scroll2.asm](https://github.com/kenjennings/Random-Acts-Of-Asm/blob/master/font_left_scroll2.asm "font_left_scroll2.asm") | Same program as font_left_scroll1 with loops unrolled to dramatically improve execution time. |
| | [left_scroll3.asm](https://github.com/kenjennings/Random-Acts-Of-Asm/blob/master/left_scroll3.asm "left_scroll3.asm") | Scroll text by shifting character bitmaps through lines of bitmapped graphics. Faster than font_left_scroll1.asm above, and smaller code than font_left_scroll2. |
| | [left_scroll4.asm](https://github.com/kenjennings/Random-Acts-Of-Asm/blob/master/left_scroll4.asm "left_scroll4.asm") | For sake of comparison this is how it looks done in real hardware scrolling.  Magically fast and small code. |

---

**GTIA256.asm**

[![GTIA256](https://github.com/kenjennings/Random-Acts-Of-Asm/blob/master/GTIA256.png)](#GTIA256)

Sets up a simple GTIA mode 9 display (16 grey scales) and uses Display List Interupts to change the base color at 16 places on screen to show all 256 GTIA colors on a single display.

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

All the ANTIC mode instructions in the Display List include LMS pointing to the same screen memory, so the entire display is populated with the same line of graphics. 

---

**font_left_scroll1.asm**

YouTube video: https://youtu.be/oMa2MsVkeGk

[![font_left_scroll1](https://github.com/kenjennings/Random-Acts-Of-Asm/blob/master/font_left_scroll1.png)](#font_left_scroll1)

This is originally from:
https://github.com/graydefender/RandomStuff/blob/master/leftshift.asm
This is an Atari port of a C64 example performing horizontal text scrolling using ROL on the character bitmaps.  The shifting parts function identically on the Atari as the C64, since both use the same bitmap organization for the character set. 

This version uses smaller looping code, but takes much longer to execute.  It runs for almost the entire frame.  There is a little code near the start of the program that can be uncommented to experiment with the display list.  This extra code replaces most of the display list's Text Mode 2 instructions with Blank Line instructions which do not require DMA for screen memeory or the character set.  When the display is mostly blank lines the ROL routine finishes in about 2/3 of the frame.

The program includes a few extra bells and whistles to provide visual feedback of the amount of time per frame used for the shifting, plus additional on-screen text to explain the visual indicator. 

So, why would someone want to do scrolling through a bitmap when hardware scrolling on the Atari is nearly magical?  This method allows one to mix multiple fonts and graphics in the scrolling content.  Also, the scan lines could be scrolled at different speeds allowing different kinds of animation that would be harder to do with the hardware scrolling.

---

**font_left_scroll2.asm**

YouTube video: https://youtu.be/aFscbCip2bQ

[![font_left_scroll2](https://github.com/kenjennings/Random-Acts-Of-Asm/blob/master/font_left_scroll2.png)](#font_left_scroll2)

This is originally from:
https://github.com/graydefender/RandomStuff/blob/master/leftshift2.asm
This is an Atari port of a C64 example performing horizontal text scrolling using ROL on the character bitmaps.  The shifting parts function identically on the Atari as the C64, since both use the same bitmap organization for the character set. 

This version uses unrolled direct code to ROL 320 bytes of font bitmap data.  The code is much larger, but executes faster.  The ROL routine completes in just about 32 scan lines.

The program includes a few extra bells and whistles to provide visual feedback of the amount of time per frame used for the shifting, plus additional on-screen text to explain the visual indicator. 

---

**left_scroll3.asm**

YouTube video: https://youtu.be/L2wj6jGeq8M

[![left_scroll3](https://github.com/kenjennings/Random-Acts-Of-Asm/blob/master/left_scroll3.png)](#left_scroll3)

The Atari always has more than one way to solve a problem.  Here is another way to horizontally scroll text without using the hardware scrolling features.  This version uses bit-mapped graphics memory instead of the soft character set used in font_left_scroll1.asm, and font_left_scroll2.asm above.  

Since Atari graphics use linear memory rather than a character set-like arrangement this provides a few advantages.  The shifting is going through sequential bytes of memory, so looping code can be used that does not require extra address manipulation in each pass.  This results in much faster code than the original font_left_scroll1 demo, and while this program retains loops for shifting the bitmaps it is only a little slower than the large code resulting from the unrolled loops in font_left_scroll2.

---

**left_scroll4.asm**

YouTube video: https://youtu.be/BfNkqKnDSgg

[![left_scroll4](https://github.com/kenjennings/Random-Acts-Of-Asm/blob/master/left_scroll4.png)](#left_scroll4)

For comparison purposes with the other three scrolling demos above, this is what the code for Atari's hardware fine scrolling looks like.  

The hardware feature is so stupidly fast the green block showing the CPU time used for scrolling in the other scrolling demos is now reduced to a fraction of a single scan line.

Since the fine scrolling feature is based on color clocks, the scrolling is so fast the text is not readable.  To scale it down to the speed of the other scrolling demos this program skips an entire frame between updates to make the animation occur at 30fps rather than 60fps.

This is so fast and efficient, because "moving" the characters is never moving anything.  Fine scrolling "moves" the displayed text the distance of four characters (16 color clocks)  by writing one value to a hardware register each frame.  Coarse scrolling to reset the scrolling and continue the motion also does not move any characters at all.  The only thing that happens for coarse scrolling is incrementing a two-byte pointer to the new starting address of the display line.  Most other computers would have to do coarse scrolling by updating all 40 characters in the row.  

The only computer I'm aware of that can do scrolling similarly is the Amiga (while only bit-mapped based, the screen display is still controlled by fiddling with a couple pointers in registers rather than actually moving data through screen RAM.)

We've done the advatages of the hardware features, so, now here's the disadvantage:  Since the screen data for the other three scrolling demos is in bit-mapped screen memory, ANY character or graphics image can be introduced to the scrolling line without limit.  In this hardware scrolling example everything that appears on the line must be represented in the same character font.  Within the width of the screen that text line cannot mix another font or graphics unless those images are part of the same character set.  Switching fonts would switch the images of all the text currently displayed on the line.  Therefore, there must be some overlap or identical characters in two different fonts.  The alternative is that the text line must be cleared before changing fonts.  

