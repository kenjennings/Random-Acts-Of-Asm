; --------------------------------------------------------------------
; 6502 assembly on Atari.
; Built with eclipse/wudsn/atasm.
;
; Atari-specific extension of the idea for scrolling text through bitmaps.
; In the font_left_scroll demos the images are shifted through a 
; soft character set which is treating a display line (40 characters)
; as a graphics bitmap.  However, this is non-linear memory.
;
; The Atari's display system is highly flexible and a line of "text"
; can also be represented as a set of bitmap graphics lines. 
; This allows the flexibility to scroll text and graphics in 
; while reducing the complexity of the code, and cutting down the 
; memory use to only what is needed for display rather than 
; committing the entire space for a soft character set.
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
; Some Page 0 shenanigans to make life easier later on.

	*=$80

; Point to next character in the scrolling message.
NewMessagePtr .word newmessage 

; Save the original display list for the OS.  On exit this will be 
; restored, so DOS looks right.
SAVE_OS_DL .word $0000
;
;; When copying the character image to the scrolling line...
Z_CHAR_IMAGE_SOURCE .word $0000

; --------------------------------------------------------------------
; LOMEM_DOS_DUP = $3308 ; First usable memory after DOS and DUP 

	*=LOMEM_DOS_DUP ; Start "program" after DOS and DUP 

	; go to next aligned page, so everything will fits easily without 
	; needing to think about ANTIC address boundary limits.

	mAlign $1000  

SCROLL_MEM ; 40 bytes (+1 for buffer) times 8 lines.
SCROLL_MEM1 .ds 41
SCROLL_MEM2 .ds 41
SCROLL_MEM3 .ds 41
SCROLL_MEM4 .ds 41
SCROLL_MEM5 .ds 41
SCROLL_MEM6 .ds 41
SCROLL_MEM7 .ds 41
SCROLL_MEM8 .ds 41

	mAlign $100 ; Go to next aligned page. 

 	; We are creating a Display list that mimics the OS default screen.  
	; The differences:
	; - The first 8 lines are mode F graphics with LMS pointing to memory for 
	;   bitmapped graphics. This is the scrolling "text"
	; - The 9th instruction has  LMS added to point to the
	;   memory used for the second line on the default OS display.

DISPLAY_LIST
	.byte DL_BLANK_8, DL_BLANK_8, DL_BLANK_8 ; 3 * 8 = 24 blank scan lines
	; Line 1, 2, ... 8
	entry .= SCROLL_MEM
	.rept 8
		.byte DL_MAP_F|DL_LMS
		.word entry
		entry .= entry+41 ; sizeof line plus buffer
	.endr
	; Line 9 (text line 2) 
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

; --------------------------------------------------------------------

CODE_START

; ***********************************************************************************
; Step 1 Perfect mimicing the OS screen.  
; Set the pointer for the second text line in our display list to point to the 
; screen memeory of the second text line on the OS's default display. 
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

	ldx #40   ; clear the scrolling screen ram
zero_screenram
	sta SCROLL_MEM1,x
	sta SCROLL_MEM2,x
	sta SCROLL_MEM3,x
	sta SCROLL_MEM4,x
	sta SCROLL_MEM5,x
	sta SCROLL_MEM6,x
	sta SCROLL_MEM7,x
	sta SCROLL_MEM8,x
	dex
	bpl zero_screenram

	lda SDLSTL         ; Save the original OS DL, so it can be restored on exit.
	sta SAVE_OS_DL
	lda SDLSTH
	sta SAVE_OS_DL+1

	lda #<DISPLAY_LIST ; set new display list.
	sta SDLSTL
	lda #>DISPLAY_LIST
	sta SDLSTH
	
	jsr long_pause ; wait 4 sec to give time to manage video capture.
	
	lda #[ENABLE_DL_DMA|PLAYFIELD_WIDTH_NORMAL]
	sta SDMCTL ; screen on

; ***********************************************************************************
; Step 4 - MAIN PROGRAM LOOP - start the shifting 
; ***********************************************************************************

	; framework  code will run the same on Atari
	; However, blank space is 0 value on Atari, so a different end of string
	; flag is needed.  Here, this is CHR$(155) which is the Atascii EOL.
	              
keepgoing

	jsr grab_next_char ; get the next character for the scroll
	
	cmp #155 ; Is is ATASCII EOL?
	beq done ; Yes.  The scroll is done. 

	jsr show_next_char  ; put this character bitmap into the graphics lines.
	
	jsr shift_bitmap           
	jsr shift_bitmap           
	jsr shift_bitmap           
	jsr shift_bitmap                               
	jsr shift_bitmap           
	jsr shift_bitmap           
	jsr shift_bitmap           
	jsr shift_bitmap
	
	jmp keepgoing  
	
done               

	lda #$00   ; turn off display and pause to allow for managing the screen capture.
	sta SDMCTL
	
	jsr long_pause ; wait 4 sec to give time to manage video capture.
	
	lda #[ENABLE_DL_DMA|PLAYFIELD_WIDTH_NORMAL]
	sta SDMCTL ; screen on

	rts


; ***********************************************************************************
; Subroutines Grab next char
; ***********************************************************************************
	; Get the next character from the NewMessage Pointer.

grab_next_char

	ldy #0
	lda (NewMessagePtr),Y   ; Get characcter from current pointer.
	inc NewMessagePtr       ; point to next character
	bne exit_grab_next_char ; Did not roll over to 0, so, exit.
	inc NewMessagePtr+1     ; increment high byte.

exit_grab_next_char
	
	rts
	
	

; ***********************************************************************************
; Subroutines Show next char
; ***********************************************************************************
	; Rephrased for the Atari - Given a character in the Accumulator copy 
	; the 8 bytes for the character image to the 40th soft character set.
	;
	; The target location is fixed/known, so this should not need a 
	; reference through page 0 for the target location.
	;
	; The other caveat is that "inverse" video is done by ANTIC and is not in 
	; the font bitmap.  Therefore, to scroll an inverse character a different 
	; copy routine is needed to invert the data (EOR #$FF) to make it appear
	; as if it were inverse video.
	
show_next_char
	pha ; Save screen character code for later.
	; First, figure out the character set address of the character.
	; Start by multiplying the character id by 8.
	and #$7F ; remove high bit from character (for inverse)
	sta Z_CHAR_IMAGE_SOURCE
	lda #$00
	sta Z_CHAR_IMAGE_SOURCE+1
	; multiply by 8 to get the character's bitmap start address
	clc
	rol Z_CHAR_IMAGE_SOURCE   ; * 2
	rol Z_CHAR_IMAGE_SOURCE+1 ; carry should be 0 from the high byte
	rol Z_CHAR_IMAGE_SOURCE   ; * 4
	rol Z_CHAR_IMAGE_SOURCE+1 ; carry should be 0 from the high byte
	rol Z_CHAR_IMAGE_SOURCE   ; * 8
	rol Z_CHAR_IMAGE_SOURCE+1 ; carry should be 0 from the high byte
	; Add the character offset to the character set address
	clc
	lda Z_CHAR_IMAGE_SOURCE+1
	; The page address could be turned into a variable/argument, so any of multiple
	; soft character sets could be used in the scrolling.
	adc #$E0  ; $E0 is ROM. Or this could be the high byte for a custom charset address.
	sta Z_CHAR_IMAGE_SOURCE+1
	
	; Copy the character image.
	ldy #$FF ; (will roll over to 0 in the next INY)
	
	pla ; restore original character
	bmi copy_inverse_char ; if high bit is set then this is an inverse video char

; To avoid doing math on the target address into screen memory this is 
; 8 explicit fetch and stores, one for each byte/each line of the grapics:

copy_regular_char
	entry .= [SCROLL_MEM1+40]
	.rept 8
		iny
		lda (Z_CHAR_IMAGE_SOURCE),y
		sta entry 
		entry .= [entry+41]
	.endr
	
	rts

; Same as the code above, but this inverts the bits in the image to 
; immitate inverse video.   I should probably add some inverse 
; video to the scroll to prove this works.

copy_inverse_char
	entry .= [SCROLL_MEM1+40]
	.rept 8
		iny
		lda (Z_CHAR_IMAGE_SOURCE),y
		eor #$FF
		sta entry
		entry .= [entry+41]
	.endr

	rts


; ***********************************************************************************
; Subroutine  Shift bitmap
; ***********************************************************************************

shift_bitmap    
	jsr Smooth_Scroll ; Wait until scan line is after the text being scrolled. Then 
					  ; turn on the visual indicators to show processing.
 
 ; a macro for each line of graphics, 1 to 8......

	entry .= SCROLL_MEM1
	
	.rept 8
		ldx #39           ; start at the last character on the line
		rol entry+40
	
; could not figure out how to coerce the macro to use a local "loop_shift_bitmap" 
; target address.   Probably something I stupidly overlooked in macro expansion...
; I'm sure I recall successfully doing this in Mac/65. what's up?
; So, I had to count out the branch below and figure out how many instructions/bytes 
; it must branch backwards.  

;loop_shift_bitmap ; -- bpl target 
		rol entry,x
		dex
		bpl *-4 ; loop_shift_bitmap 
		entry .= entry+41
	.endr

	; A shift is done! turn off the processing indicators.  
	; Restore the original screen colors from the OS shadow registers
	; the hardware registers.

	lda COLOR1 
	sta COLPF1	
	lda COLOR2 
	sta COLPF2
	lda COLOR4 
	sta COLBK
	
	rts
	

; ***********************************************************************************
; Subroutine  Smooth_Scroll
; ***********************************************************************************

Smooth_Scroll                                      ; Wait for Raster to be off screen 

	; wait for the scan line AFTER the scrolling line, so that the bitmap 
	; ROL'ing is not applied while the video is fetching the bitmap for display. 

smooth_scroll_loop
	lda VCOUNT
	cmp #20 ; video offset 8, + 24 blank lines, + 8 for scroll line = 40.  / by 2 = 20.
	bne smooth_scroll_loop
	
	; Change border and playfield color to identify when we're processing. 

	lda #[COLOR_GREEN+$08]   ; It's not easy being green...
	sta COLPF2
	sta COLBK
	
	lda #COLOR_BLACK
	sta COLPF1 ; make text black.
	
	rts

; ***********************************************************************************
; Extra stuff.  Little bit-o-docs.  Explain the run-time markers on screen.
; ***********************************************************************************

Write_doc_msg
	ldx #0  ; index into Doc_msg text.
	ldy #80 ; index into screen RAM. Start on 3rd line. 
			; This leaves 175 characters for direct index.

write_more                  ; Poke chars to screen until we hit EOL.
	lda Doc_msg,x           ; get a character from the string .
	cmp #155                ; Is it ATASCII EOL?  
	beq Exit_write_doc_msg  ; Yes.  Stop here.
	sta (SAVMSC),Y          ; Poke it to screen memory. 
	inx
	iny 
	bne write_more  ; Stop when we exceed max index range.  
	
Exit_write_doc_msg
	rts
	
Doc_msg
	.sbyte "The green color is the time spent       "
	.sbyte "running the ROL code in the bitmap.     "
	.sbyte "Some loops unrolled. "
	.byte 155

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
; Scrolling data . . .
; ***********************************************************************************    

; Note Atari uses 0 for blank spaces in screen memory.  
; Therefore 0 cannot be used to flag the end of the sstring. 
; Here we use 155, the ATASCII end of line. 
; The alternaticve is just count the characters.

newmessage 
	.sbyte "Hello, this is a test scroll on the Atar"
	.sbyte "i.  The 'text' at the top of the screen "
	.sbyte "is actually 8 high resolution graphics l"
	.sbyte "ines (ANTIC Map mode F).  The scrolling "
	.sbyte "is done by rolling the bits through the "
	.sbyte "40 bytes in each line.  Because the Atar"
	.sbyte "i has linear memory for graphics this sh"
	.sbyte "ifting can be more efficient than the wo"
	.sbyte "rk needed to shift bits through a soft c"
	.sbyte "haracter set in the other scrolling demo"
	.sbyte "s (font left scroll 1 and 2).  The loopi"
	.sbyte "ng code here is faster than the looping "
	.sbyte "code in demo font left scroll 1 and only"
	.sbyte " a bit slower than the unrolled loops in"
	.sbyte " font left scroll 2.  This has some adva"
	.sbyte "ntages - any kind of custom character or"
	.sbyte " graphics can be introduced to the scrol"
	.sbyte "ling line, and no space needs to be dedi"
	.sbyte "cated to a custom character set.  The on"
	.sbyte "ly memory needed is for the 8 lines of h"
	.sbyte "igh-res graphics.                       "
	.sbyte +$80,"This is the End."                    ; Prints in  inverse video.
	.sbyte "                                        " ; 40 blanks to make sure text is gone.
	.byte  155 ; ATASCII EOL, to mark end of text


; --------------------------------------------------------------------
; Store the program start location in the Atari DOS RUN Address.
; When DOS is done loading the executable file into memory it will 
; automatically jump to the address placed here in DOS_RUN_ADDR.

; DOS_RUN_ADDR =  $02e0 ; Execute at address stored here when file loading completes.

	mDiskDPoke DOS_RUN_ADDR, CODE_START

; --------------------------------------------------------------------
	.end ; finito
