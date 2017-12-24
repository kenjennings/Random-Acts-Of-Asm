; --------------------------------------------------------------------
; 6502 assembly on Atari.
; Built with eclipse/wudsn/atasm.
;
; Atari port of C64 program to horizontally scroll text via 
; character bitmap ROL.
;
; Originally from:
; https://github.com/graydefender/RandomStuff/blob/master/leftshift.asm
;
; 40 chars * 8 shifts == 320 shifts per frame.
;
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

	mAlign 1024 ; Align to the next 1K boundary for the soft font.

SOFT_CSET ; the scrolling character set
	.ds $400 ; reserve this 1K  The progam will copy the ROM set here later.


; When copying the character image to the scrolling line...
Z_ROM_SOURCE = $FB
SCROLL_DEST  = SOFT_CSET+$340 ; This is offset to the 41st character 
; in the scrolling characters.  The scrolling characters are offset
; from  the 64th character in the character set. Therefore, 
; 64 + 40 - 1  = character 103, the last visible character in the line.  
; 103 + 1 is the buffer character, 104.   
; 104 * 8 = 832 or byte offset $340 byte.

; When shifting bits...
Z_CH_FIRST = $FB
Z_CH_NEXT  = $FD

CODE_START

; --------------------------------------------------------------------
; Turn off screen for a moment and pause to provide time to 
; manage the screen capture.
; --------------------------------------------------------------------

	lda #$00
	sta SDMCTL ; screen off.
	
	jsr long_pause ; wait 4 sec to give time to manage video capture.
	
	lda #[ENABLE_DL_DMA|PLAYFIELD_WIDTH_NORMAL]
	sta SDMCTL ; screen on

;; --------------------------------------------------------------------
;; A little Atari experiment.  Replace most of the text lines with 
;; blank lines to see how it impacts the completion time.
;; 
;; When ANTIC is doing DMA for a full text screen it takes almost the
;; entire frame for the ROL routine to complete.
;;
;; When most of the display is blank lines the ROL routine finishes in 
;; 2/3 of a frame.
;; --------------------------------------------------------------------
;
;	lda SDLSTL ; Display list, low byte
;	sta $F8
;	lda SDLSTH ; Display list, high byte
;	sta $F9
	
;	ldy #10 ; 3 blank lines, 3 for line with lms, and 4 more lines following with text.
;dl_substitute
;	lda #DL_BLANK_8
;	sta ($F8),Y
;	iny
;	cpy #29 ; up to the last (24th) line in the display list 
;	bne dl_substitute
	
	

; ***********************************************************************************
; Step 1 Redefine char set    
; ***********************************************************************************
	; Copy the four pages of the ROM character set to RAM.
	; Technically, only needed if the screen will display any of the regular
	; characters not used for the scrolling.  (Though, in that case, it would 
	; really make more sense to use a DLI to flip back to the ROM font after
	; the scrolling text line.) 
	
	ldy #$00
loop_cset
	lda $E000,Y     ; Cset Page E0
	sta SOFT_CSET,Y 
	lda $E100,Y     ; Cset Page E1
	sta SOFT_CSET+$100,Y 
	lda $E200,Y     ; Cset Page E2
	sta SOFT_CSET+$200,Y 
	lda $E300,Y     ; Cset Page E3
	sta SOFT_CSET+$300,Y 
	iny
	bne loop_cset

; ***********************************************************************************
; Step 2 - Initialize the redefined characters in charset used for scrolling, they
;          start at index charset index 64 which equate to 64*8 = $200 + $3000=$3200 
; ***********************************************************************************
	; For the Atari, this is similar.
	; The numbers, most punctuation, and upper case are in the first 64 characters.
	; We want to keep those.
	; So, the scrolling chars will start at character 64. (64 * 8 = 512 or $200)
	; 40 characters need to be cleared, or $140 bytes.
	
;	lda #0  ; Y is already 0 from the code above
loop_clear_cs1	; Clear the first $100 bytes of the $140 bytes. full page
	sta SOFT_CSET+$200,Y
	iny
	bne loop_clear_cs1
	
	ldy #$3F 
loop_clear_cs2	; Clear the next $40 bytes
	sta SOFT_CSET+$300,Y
	dey
	bpl loop_clear_cs2

; ***********************************************************************************
; Step 3 - put redefined characters on a row on the screen
; ***********************************************************************************
	; For the Atari, essentially similar.
	; The OS provides a pointer to screen mem, so we can use that to set 
	; the first line of screen memory with the redefined characters.
	
	ldy #$00
	ldx #64 ; 40 chars starting at 64...65..., etc.
loop_populate_screen
	txa             ; transfer character number to A
	sta (SAVMSC),Y  ; SAVMSC = $58 ; word. Address of first byte of screen memory.
	inx
	iny
	cpy #40
	bne loop_populate_screen

	; A little Atari extra to label the running code markers on the screen.
	jsr	Write_doc_msg
	
	lda #>SOFT_CSET ; Tell ANTIC to display the soft font or nothing will move.
	sta CHBAS

; ***********************************************************************************
; Step 4 - MAIN PROGRAM LOOP - start the shifting 
; ***********************************************************************************
	; framework  code will run the same on Atari
	; However, blank space is 0 value on Atari, so a different end of string
	; flag is needed.  Here, this is CHR$(155) which is the Atascii EOL.
	
	ldx #0                  
keepgoing
	lda newmessage,X
	cmp #155 ; ATASCII EOL
	beq done               

	jsr grab_next_char 
	
	stx xsave
	jsr shiftchar           
	jsr shiftchar           
	jsr shiftchar           
	jsr shiftchar                               
	jsr shiftchar           
	jsr shiftchar           
	jsr shiftchar           
	jsr shiftchar
	ldx xsave
	inx
	jmp keepgoing  
	
done               

; turn off display and pause to allow for managing the screen capture.

	lda #$00
	sta SDMCTL
	
	jsr long_pause ; wait 4 sec to give time to manage video capture.
	
	lda #[ENABLE_DL_DMA|PLAYFIELD_WIDTH_NORMAL]
	sta SDMCTL ; screen on

	rts


; ***********************************************************************************
; Subroutines Grab next char
; ***********************************************************************************
	; Rephrased for the Atari - Given a character in the Accumulator copy 
	; the 8 bytes for the character image to the 40th soft character set.
	;
	; The target location is fixed/known, so this should not need a 
	; reference through page 0 for the target location.
	;
	; Also, the source should not be the soft charset since 40 of the characters
	; are being used for scrolling.  Using the ROM charset for source or any 
	; other soft charset not participating in the scrolling then makes that 
	; entire "font" available for the scroll.
	;
	; The other caveat is that "inverse" video is done by ANTIC and is not in 
	; the font bitmap.  Therefore, to scroll an inverse character a different 
	; copy routine is needed to invert the data (EOR #$FF) to make it appear
	; as if it were inverse video.
	
grab_next_char
	pha ; Save screen character code for later.
	; First, set up ROM as source
	and #$7F ; remove high bit from character (for inverse)
	sta Z_ROM_SOURCE
	lda #$00
	sta Z_ROM_SOURCE+1
	; cheat multiply by 8 to get the character's bitmap start address
	clc
	rol Z_ROM_SOURCE   ; * 2
	rol Z_ROM_SOURCE+1 ; carry should be 0 from the high byte
	rol Z_ROM_SOURCE   ; * 4
	rol Z_ROM_SOURCE+1 ; carry should be 0 from the high byte
	rol Z_ROM_SOURCE   ; * 8
	rol Z_ROM_SOURCE+1 ; carry should be 0 from the high byte
	; Add to the ROM address
	clc
	lda Z_ROM_SOURCE+1
	adc #$E0  ; $E0 is ROM. Or this could be the high byte for a custom charset address.
	sta Z_ROM_SOURCE+1
	
	; Copy the character image.
	ldy #7
	
	pla ; restore original character
	bmi copy_inverse_char ; if high bit is set then this is an inverse video char

copy_regular_char
	lda (Z_ROM_SOURCE),y
	sta SCROLL_DEST,y
	dey
	bpl copy_regular_char
	rts

copy_inverse_char
	lda (Z_ROM_SOURCE),y
	eor #$FF
	sta SCROLL_DEST,y
	dey
	bpl copy_inverse_char
	rts


; ***********************************************************************************
; Subroutine  Shift char
; ***********************************************************************************

shiftchar     
	jsr Smooth_Scroll ; Wait until scan line is after the text being scrolled. Then 
					  ; turn on the visual indicators to show processing.
 
	ldx #00           ; start at the first character on the line
	
loop_shift_char
	txa               ; Transfer X to Y for the copying below and to preserve X for loop.
	tay                    
	lda charhi,y      ; Z_CH_FIRST = charlookup[Y]
	sta Z_CH_FIRST+1
	lda charlow,y
	sta Z_CH_FIRST
	
	iny              ; Y = Y + 1
	
	lda charhi,y     ; Z_CH_NEXT = charlookup[Y]
	sta Z_CH_NEXT+1
	lda charlow,y
	sta Z_CH_NEXT
	
	ldy #7
	
loop_a_to_b
	lda (Z_CH_NEXT),y ; Get from the last/next/right-most char...
	bmi set_c         ; Check if it has high bit set

clr_c                 ; No. Clear Carry
	clc
	bcc continue_sc
	
set_c                 ; Yes. Set Carry
	sec
	
continue_sc
	lda (Z_CH_FIRST),y ; Get byte of the first/left-most character
	rol A              ; Shift and roll in the carry from the next character     
	sta (Z_CH_FIRST),y ; update it in the first character
	
	dey                ; go to next byte in bitmap
	bpl loop_a_to_b    ; counting down 7...to...0.  $FF is negative
	
	inx                 ; next character position
	cpx #41             ; have we reached the end?
	bne loop_shift_char ; No.  do the next character.
	
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
; Extra Atari stuff.  Little bit-o-docs.  Explain the run-time markers on screen.
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
	
Doc_msg
	.sbyte "THE GREEN COLOR IS THE TIME SPENT       "
	.sbyte "RUNNING THE ROL CODE.  YES, IT'S THE    "
	.sbyte "WHOLE FRAME.  LOOPING IS SLOW."
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
; Other Variables and Data
; ***********************************************************************************

xsave	.byte $00      

; Note Atari uses 0 for blank spaces in screen memory.  
; Therefore a different value is needed for the end of the string.
; (Or the code would just need to count characters.)

newmessage 
	.sbyte "Hello, this is a test scroll on the Atari version of gray defender's C64 "
	.sbyte "horizontal scrolling by ROL'ing the character set bitmap images. "
	.sbyte "This is the message.  Will it repeat? "
	.sbyte "                    It might! "
	.sbyte "                                        " ; 40 blanks to make sure text is gone.
	.byte  155 ; ATASCII EOL, to mark end of text

; Here is one reason why atasm rocks:
;
; This mass of typing:
; charlow byte $00,$08,$10,$18,$20,$28,$30,$38
;         byte $40,$48,$50,$58,$60,$68,$70,$78
;         byte $80,$88,$90,$98,$a0,$a8,$b0,$b8
;         byte $c0,$c8,$d0,$d8,$e0,$e8,$f0,$f8
;         byte $00,$08,$10,$18,$20,$28,$30,$38
;         byte $40,$48 ; why 42 entries?
; becomes this:
charlow
	entry .=[SOFT_CSET+$200]
	.rept 42 
	.byte <entry ; low byte
	entry .= entry+8 ; Start of next character bitmap 
	.endr
	
; and this:
; charhi byte $32,$32,$32,$32,$32,$32,$32,$32
;        byte $32,$32,$32,$32,$32,$32,$32,$32
;        byte $32,$32,$32,$32,$32,$32,$32,$32
;        byte $32,$32,$32,$32,$32,$32,$32,$32
;        byte $33,$33,$33,$33,$33,$33,$33,$33
;        byte $33,$33
; becomes this:
charhi
	entry .=[SOFT_CSET+$200]
	.rept 42 
	.byte >entry ; high byte
	entry .= entry+8 ; Start of next character bitmap 
	.endr

; --------------------------------------------------------------------
; Store the program start location in the Atari DOS RUN Address.
; When DOS is done loading the executable file into memory it will 
; automatically jump to the address placed here in DOS_RUN_ADDR.

; DOS_RUN_ADDR =  $02e0 ; Execute at address stored here when file loading completes.

	mDiskDPoke DOS_RUN_ADDR, CODE_START

; --------------------------------------------------------------------
	.end ; finito
