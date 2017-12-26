; --------------------------------------------------------------------
; 6502 assembly on Atari.
; Built with eclipse/wudsn/atasm.
;
; Atari-specifc version of horizontally scrolling text. 
;
; This scrolling demo uses the hardware scrolling feature of
; ANTIC that provides nearly free fine scrolling with negligible 
; CPU cost.
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
; LOMEM_DOS_DUP = $3308 ; First usable memory after DOS and DUP 

	*=LOMEM_DOS_DUP ; Start "program" after DOS and DUP 

	; go to an aligned page, so everything will fits without crossing an ANTIC limit.

	mAlign $1000  

	; We are creating a Display list that mimics the OS default screen.  
	; The differences:
	; - The first instruction with LMS points to our scrolling memory.
	; - The second instruction will have an LMS added to point to the
	;   memory used for the second line on the default OS display.

DISPLAY_LIST
	.byte DL_BLANK_8, DL_BLANK_8, DL_BLANK_8 ; 3 * 8 = 24 blank scan lines
	; Line 1
	.byte DL_TEXT_2|DL_LMS|DL_HSCROLL
DISPLAY_SCROLL   ; DL Low Byte of pointer to scrolling memory
	.word SCROLL_MEM
	; Line 2
	.byte DL_TEXT_2|DL_LMS
DISPLAY_OS       ; DL Low Byte of pointer to OS default screen memory
	.word $0000  ; will be replaced by pointer into default OS screen memory
	; Text Lines 3...24
	.rept 21
		.byte DL_TEXT_2
	.endr
	; End display, vertical blank.
	.byte DL_JUMP_VB
	.word DISPLAY_LIST

; Save the original display list for the OS.  On exit this will be 
; restored, so DOS looks right.
SAVE_OS_DL .word 0

	mAlign $100 ; Go to next aligned page. 
 
SCROLL_MEM ; 440 bytes of memory (of 484 total)  to scroll through.
	.sbyte "                                        " ; 40 blanks to make sure text starts at the right side.
	.sbyte "Hello, this is a test scroll on the Atari using AN"
	.sbyte "TIC's hardware horizontal fine scrolling. For 15 f"
	.sbyte "rames the only thing updated is the fine scroll re"
	.sbyte "gister. On the 16th frame the fine scroll is reset"
	.sbyte ", and the LMS pointer is updated to coarse scroll "
	.sbyte "the line of text. Most other computers must rewrit"
	.sbyte "e the entire line of text in screen memory to do c"
	.sbyte "oarse scrolling.      Have you played Atari today?"
END_SCROLL_MEM 
	.sbyte "                                            " ; 44 extra blanks to make sure text is gone.
	; 44, not 40 is needed due to the fine scroll buffer.

CODE_START


; ***********************************************************************************
; Step 1 Perfect mimicing the OS screen.  
; Set the pointer for the second line in the display list to point to the 
; second line of the OS screen memory. 
; ***********************************************************************************

	clc
	lda SAVMSC ; OS pointer to screen memory low byte
	adc #40    ; point second line of our DL to the second line of the OS display.
	sta DISPLAY_OS
	
	lda SAVMSC+1 ; and the high byte
	adc #0
	sta DISPLAY_OS+1
	
; ***********************************************************************************
; Step 2 Add some documentation to the screen.
; ***********************************************************************************

	jsr	Write_doc_msg

; ***********************************************************************************
; Step 3 - Init the new display values 
; ***********************************************************************************

	lda #0
	sta SDMCTL ; screen off.

	lda SDLSTL         ; Save the original OS DL, so it can be restored on exit.
	sta SAVE_OS_DL
	lda SDLSTH
	sta SAVE_OS_DL+1

	lda #<DISPLAY_LIST ; set new display list.
	sta SDLSTL
	lda #>DISPLAY_LIST
	sta SDLSTH
	
	ldx #15 ; init scrolling position
	stx HSCROL
	
	jsr long_pause ; wait 4 sec to give time to manage video capture.
	
	lda #[ENABLE_DL_DMA|PLAYFIELD_WIDTH_NORMAL]
	sta SDMCTL ; screen on

; ***********************************************************************************
; Step 3 - This is the way we scroll.
; Fine scroll distance is 0 to 15 color clocks which is the same as four, 
; Text Mode 2 characters.
; Thus coarse scrolling is done in 4 character steps, and the coarse scroll is 
; done by just changing the display list's pointer into the screen memory.
; Most computers that support fine scrolling can only move the distance of one
; character before needing to coarse scroll, and coarse scrolling requires 
; moving all the characters through screen memory.
; ***********************************************************************************

scroll_o_matic

	; Turn off the processing indicators.  
	; Restore the original screen colors from the OS shadow 
	; registers to the hardware registers.

	lda COLOR1
	sta COLPF1	
	lda COLOR2
	sta COLPF2
	lda COLOR4
	sta COLBK
	
	; Since the scrolling increment is by color clock the scrolling speed at 
    ; 60 fps is so fast that the text is not readable.  So, the movement needs
	; to be slowed down by waiting an extra frame.

	jsr Smooth_Scroll ; Wait for scan line at specific position...
	jsr Smooth_Scroll ; Wait again for the next frame...

	; Change border and playfield color to identify when we're processing. 

	lda #[COLOR_GREEN+$08]   ; It's not easy being green...
	sta COLPF2
	sta COLBK
	
	lda #COLOR_BLACK
	sta COLPF1 ; make text black.

	; Now that the diagnostic gymnastics are done, let's do something real.

	; THE SCROLLING...

	; In most real-world situations this would probably be put into a vertical blank interrupt.

	dex                ; moving the fine scroll -1 color clock moves display to left.
	bmi coarse_scroll  ; scroll went from 0 to negative.  time to coarse scroll.

	stx HSCROL         ; Set next fine scroll
	jmp scroll_o_matic ; go wait for the next frame.
	
coarse_scroll
	; Did we reach the end?  Compare pointer to end of scrolling area.
	lda DISPLAY_SCROLL ; 
	cmp #<END_SCROLL_MEM ; Low byte matches end position?
	bne reset_scroll     ; Nope.  Continue with coarse scroll.
	
	lda DISPLAY_SCROLL+1 
	cmp #>END_SCROLL_MEM ; high byte matches end position?
	beq end_scroll       ; yes.  We're done.
	
reset_scroll 
	ldx #15              ; Reset the fine scroll
	stx HSCROL
	
	clc                  ; Add 4 to the screen pointer to "move" the display.
	lda DISPLAY_SCROLL
	adc #4
	sta DISPLAY_SCROLL
	
	lda DISPLAY_SCROLL+1
	adc #0
	sta DISPLAY_SCROLL+1
	
	jmp scroll_o_matic

end_scroll

; ***********************************************************************************
; THE END
; ***********************************************************************************
	; Restore the OS default display.

	lda #0
	sta SDMCTL ; screen off.

	lda SAVE_OS_DL
	sta SDLSTL         
	lda SAVE_OS_DL+1
	sta SDLSTH
	
	jsr long_pause ; wait 4 sec to give time to manage video capture.
	
	lda #[ENABLE_DL_DMA|PLAYFIELD_WIDTH_NORMAL]
	sta SDMCTL ; screen on

	rts                 

; ***********************************************************************************
; Subroutine  Smooth_Scroll
; ***********************************************************************************

Smooth_Scroll                                      ; Wait for Raster to be off screen 

	; Wait for the scan line AFTER the scrolling line, so that the bitmap 
	; ROL'ing is not applied while the video is fetching the bitmap for display. 

	lda VCOUNT
	cmp #20 ; video offset 8, + 24 blank lines, + 8 for scroll line = 40.  / by 2 = 20.
	bne Smooth_Scroll
	
	; If this is called again very soon, make sure we're not on the 
	; same scan line.

	sta WSYNC
	sta WSYNC
	
	rts

; ***********************************************************************************
; Long Pause
; Provide a short wait to get the bleeping video capture sorted.
; ***********************************************************************************

long_pause
	lda #0
	sta RTCLOK60   ; increments every jiffy
	sta RTCLOK+1   ; increments every 4.27 sec.
	
pausing
	cmp RTCLOK+1
	beq pausing   ; This should take 4.27 sec to change.
	
	rts

; ***********************************************************************************
; Little bit-o-docs.  Explain the run-time markers on screen.
; Printing begins at the third line of the screen.
; We're actually writing to the OS default display. 
; ***********************************************************************************

Write_doc_msg
	ldx #0  ; index into Doc_msg text.
	ldy #80 ; index into screen RAM. Start on 3rd line. 
			; This leaves 175 characters for direct index.

write_more                  ; Poke chars to screen until we hit EOL.
	lda Doc_msg,x           ; get a character from the string .
	cmp #155                ; Is it ATASCII EOL?  
	beq Exit_write_doc_msg  ; Yes.  Stop here.
	sta (SAVMSC),Y          ;  Poke it to screen memory. 
	inx
	iny 
	bne write_more  ; Stop when we exceed max index range.  
	
Exit_write_doc_msg
	rts

	; Since this demo is not altering the character set 
	; we can use upper and lower case for this...
	
Doc_msg
	.sbyte "The green line is the time spent on the "
	.sbyte "scrolling code.  Usually, less than one "
	.sbyte "scan line of time is used. The scroll is"
	.sbyte "so fast it must pause a frame between   "
	.sbyte "steps."
	.byte 155

; --------------------------------------------------------------------
; Store the program start location in the Atari DOS RUN Address.
; When DOS is done loading the executable file into memory it will 
; automatically jump to the address placed here in DOS_RUN_ADDR.

; DOS_RUN_ADDR =  $02e0 ; Execute at address stored here when file loading completes.

	mDiskDPoke DOS_RUN_ADDR, CODE_START

; --------------------------------------------------------------------
	.end ; finito

