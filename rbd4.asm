; --------------------------------------------------------------------
; 6502 assembly on Atari.
; Built with eclipse/wudsn/atasm.
;
; The World's Smallest Raster Bar Demo (with vertical positioning, smaller color bars and two different vertical movements.)
;
; Wait for specific screen position.
; Load value of jiffy counter.
; Use value for color.
; double increment color value for smaller color bars.
; Repeat 64 times.
;
; Do the same again in reverse for the next 64 times.
;
; Do it again until there is no more electricity.
;
; https://github.com/kenjennings/Random-Acts-Of-Asm
; --------------------------------------------------------------------
 
;===============================================================================
;   ATARI SYSTEM INCLUDES
;===============================================================================
; Various Include files that provide equates defining 
; registers and the values used for the registers.
;
; For these include files refer to 
; https://github.com/kenjennings/Atari-Atasm-Includes
;
	.include "ANTIC.asm" 
	.include "GTIA.asm"
	.include "POKEY.asm"
	.include "PIA.asm"
	.include "OS.asm"
	.include "DOS.asm" 

	.include "macros.asm"

; --------------------------------------------------------------------

	mDiskPoke SDMCTL, 0  ; turn off screen DMA
	
; --------------------------------------------------------------------
; LOMEM_DOS_DUP = $3308 ; First usable memory after DOS and DUP 

	*=LOMEM_DOS_DUP ; Start "program" after DOS and DUP 

PRG_START

WaitForTop
	lda VCOUNT     ; Get scan line counter
	cmp #32        ; Is it 32?
	bne WaitForTop ; Go back and wait if this is not scanline 32
	
	ldy RTCLOK60   ; Start with jiffy (1/60th sec) clock
	ldx #64        ; Do this first part 64 times.
	
TopColorLoop
	sty WSYNC        ; sync to end of current scan line.
	sty COLBK        ; Save Y in color register.
	iny              ; Y = Y + 1
	iny              ; Y = Y + 1 (so, next color is now +2)
	dex              ; X = X - 1 (number of lines)  
	bpl TopColorLoop ; If 64 lines are not counted then do it again.
	
	ldx #64             ; Do this next part 64 times.
	
BottomColorLoop
	sty WSYNC           ; sync to end of current scan line.
	sty COLBK           ; Save Y in color register.
	dey                 ; Y = Y - 1
	dey                 ; Y = Y - 1 (so, next color is now -2)
	dex                 ; X = X - 1 (number of lines)
	bpl BottomColorLoop ; If 64 lines are not counted then do it again.
	
	lda #0         ;  Clean and tidy.  Use black/color 0.
	sta WSYNC      ;  sync to end of current scan line.
	sta COLBK      ; Save black/0 in color register.

	jmp PRG_START  ; Do While More Electricity
	
; --------------------------------------------------------------------
; Store the program start location in the Atari DOS RUN Address.
; When DOS is done loading the executable file into memory it will 
; automatically jump to the address placed here in DOS_RUN_ADDR.

; DOS_RUN_ADDR =  $02e0 ; Execute at address stored here when file loading completes.

	mDiskDPoke DOS_RUN_ADDR, PRG_START

; --------------------------------------------------------------------
	.end ; finito

