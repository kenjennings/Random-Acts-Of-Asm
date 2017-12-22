; --------------------------------------------------------------------
; 6502 assembly on Atari.
; Built with eclipse/wudsn/atasm.
;
; port horizontal scrolling by ROL the character bitmap.
;
; originally from:
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
; https://github.com/kenjennings/Atari-Atasm-Includes
;
	.include "ANTIC.asm" 
	.include "GTIA.asm"
	.include "POKEY.asm"
	.include "PIA.asm"
	.include "OS.asm"
	.include "DOS.asm" ; This provides the LOMEM, start, and run addresses.

	.include "macros.asm"

; --------------------------------------------------------------------
; LOMEM_DOS_DUP = $3308 ; First usable memory after DOS and DUP 

	*=LOMEM_DOS_DUP ; Start "program" after DOS and DUP 

	mAlign 1024 ; Align to the next 1K boundary for the soft font.

SOFT_CSET ; the scrolling character set

	malign 1024 ; skip over the character set

; When copying the character image to the scrolling line...
Z_ROM_SOURCE = $FB
SCROLL_DEST  = SOFT_CSET+$340 ; Or cset start of char 104 which is 64 + 40

; When shifting bits...
Z_CH_FIRST = $FB
Z_CH_NEXT  = $FD

CODE_START

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
	; So, the scrolling chars will start at character 64. 
	; 40 characters need to be cleared, or $140 bytes.
	
	; y is already 0 from the code above
	
	lda #0
loop_clear_cs1	; Clear the first $100 bytes of $140 bytes.
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
	txa
	sta (SAVMSC),Y  ;  SAVMSC = $58 ; word. Address of first byte of screen memory.
	inx
	iny
	cpy #40
	bne loop_populate_screen

; ***********************************************************************************
; Step 4 - MAIN PROGRAM LOOP - start the shifting 
; ***********************************************************************************
	; framework  work similar on Atari
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
	; are being used for scrolling.  Using the ROM cset for source (or any other
	; soft cset) then the entire "font" is available for the scroll.
	;
	; The other caveat is that "inverse" video is done by ANTIC and is not in 
	; the font bitmap.  Therefore, to scroll an inverse character a different 
	; copy routine is needed to invert the data (EOR #$FF) to make it appear
	; as if it were inverse video.
	
grab_next_char
	pha : Save screen character code for later.
	; First, set up ROM as source
	and #$7F ; remove high bit from character (for inverse)
	sta Z_ROM_SOURCE
	lda #$00
	sta Z_ROM_SOURCE+1
	; multiply by 8 to get the character's bitmap start address
	clc
	rol Z_ROM_SOURCE
	rol Z_ROM_SOURCE+1 ; carry should be 0 from this
	rol Z_ROM_SOURCE
	rol Z_ROM_SOURCE+1 ; carry should be 0 from this
	rol Z_ROM_SOURCE
	rol Z_ROM_SOURCE+1 ; carry should be 0 from this
	; Add to the ROM address
	lda Z_ROM_SOURCE+1
	adc #$E0
	sta Z_ROM_SOURCE+1
	
	pla ; restore original character
	bmi copy_inverse_char ; if high bit is set then this is an inverse video char
copy_regular_char
	ldy #7
	lda (Z_ROM_SOURCE),y
	sta SCROLL_DEST,y
	dey
	bpl copy_regular_char
	rts

copy_inverse_char
	ldy #7
	lda (Z_ROM_SOURCE),y
	eor #$FF
	sta SCROLL_DEST,y
	dey
	bpl copy_regular_char
	rts






; ***********************************************************************************
; Subroutine  Shift char
; ***********************************************************************************
Z_CH_FIRST = $FB
Z_CH_NEXT  = $FD

shiftchar     
                    jsr Smooth_Scroll      
                    ldx                 #00                
@loop
                    txa
                    tay                    
                    lda                 charhi,y
                    sta                 Z_CH_FIRST+1                 
                    lda                 charlow,y            
                    sta                 Z_CH_FIRST                 
                    iny
                    lda                 charhi,y
                    sta                 Z_CH_NEXT+1                 
                    lda                 charlow,y            
                    sta                 Z_CH_NEXT                 
                    ldy                 #7                                    
@loopab                    
                    lda                 (Z_CH_NEXT),y             
                    and                 #%10000000          
                    bne                 @sec                    
@clc                clc
                    jmp @cont              
@sec                sec
@cont               lda                 (Z_CH_FIRST),y                  
                    rol
                    sta                 (Z_CH_FIRST),y            
                    dey
                    cpy #$ff
                    bne                 @loopab             
                    inx
                    bne @keepgoing
@keepgoing          cpx                 #41
                    bne @loop
                    rts

; ***********************************************************************************
; Subroutine  Smooth_Scroll
; ***********************************************************************************

Smooth_Scroll
;@w1                 bit $d011                       ; Wait for Raster to be off screen 
;                    bpl @w1 
;@w2                 bit $d011 
;                    bmi                 @w2                 

@loop
                    lda                 $D012               
                    cmp #100
                    bcc                 @loop
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
	.sbyte "horizontal scrolling by rolling the character set bitmap images. "
	.sbyte "This is the message.  Will it repeat? "
	.sbyte "             It might!                           "                    
	.byte  155

; Here is one reason why atasm rocks
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
