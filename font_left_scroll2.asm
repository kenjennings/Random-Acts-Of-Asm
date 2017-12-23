; --------------------------------------------------------------------
; 6502 assembly on Atari.
; Built with eclipse/wudsn/atasm.
;
; Atari port of C64 program to horizontally scroll text 
; via character bitmap ROL.
;
; Originally from:
; https://github.com/graydefender/RandomStuff/blob/master/leftshift2.asm
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
SCROLL_DEST  = SOFT_CSET+$340 ; aka the cset start of char 104 which is 64 + 40

; When shifting bits...
Z_CH_FIRST = $FB
Z_CH_NEXT  = $FD


; ***********************************************************************************
; Macro: Rotateline  
;        Shift an entire row 40 characters over one bit
;        starting from the right then advancing left
; ***********************************************************************************
defm                RotateLine
  
                    rol                 /1+320           
                    rol                 /1+312           
                    rol                 /1+304           
                    rol                 /1+296      
                    rol                 /1+288                               
                    rol                 /1+280              
                    rol                 /1+272              
                    rol                 /1+264                               
                    rol                 /1+256              
                    rol                 /1+248          
                    rol                 /1+240                               
                    rol                 /1+232           
                    rol                 /1+224              
                    rol                 /1+216                             
                    rol                 /1+208          
                    rol                 /1+200              
                    rol                 /1+192                              
                    rol                 /1+184         
                    rol                 /1+176          
                    rol                 /1+168          
                    rol                 /1+160          
                    rol                 /1+152           
                    rol                 /1+144           
                    rol                 /1+136         
                    rol                 /1+128          
                    rol                 /1+120          
                    rol                 /1+112           
                    rol                 /1+104           
                    rol                 /1+96           
                    rol                 /1+88           
                    rol                 /1+80           
                    rol                 /1+72           
                    rol                 /1+64           
                    rol                 /1+56           
                    rol                 /1+48           
                    rol                 /1+40           
                    rol                 /1+32           
                    rol                 /1+24           
	rol                 /1+16           
	rol                 /1+8
	rol                 /1
		    
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

	; A little Atari extra to label the running code markers on the screen.
	jsr	Write_doc_msg
	
	lda #>SOFT_CSET ; Have to tell ANTIC to display the soft font or nothing moves.
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
	adc #$E0  ; Or this could be the chbas for a custom character.
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

shiftchar     
	jsr Smooth_Scroll     ; Wait until scan line is after the text beine scrolled. 
	
	ldx #00           ; start at the first character on the line
	
loop_shift_char
	txa
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
	and	#~10000000    ; Check if it has high bit set
	bne set_c         ; Yes.  

clr_c                 ; No.  Clear Carry
	clc
	jmp continue_sc
	
set_c                 ; Yes. Set Carry
	sec
	
continue_sc
	lda (Z_CH_FIRST),y ; Get byte of the first/left-most character
	rol A              ; Shift and roll in the carry from the next character     
	sta (Z_CH_FIRST),y ; update it in the first character
	
	dey                ; go to next byte in bitmap
	bpl loop_a_to_b    ; counting down 7...to...0.  $FF is negative
	
	; I'm kind wondering here about the 41-ness below.
	; 40 displayed characters means the characters are numbered 0 to 39.
	; Therefore the buffer character being rolled into the 39th is the 40th.
	; Therefore the maximum values for FIRST is 39, and NEXT is 40.
	; Then this loop appears to run up to FIRST = 40, and NEXT = 41 and 
	; the 41st should not be visible, even partly on the screen. ?
	inx                 ; next character position
	cpx #41             ; have we reached the end?
	bne loop_shift_char ; No.  do the next character.
	
	rts

; ***********************************************************************************
; Subroutine  Smooth_Scroll
; ***********************************************************************************

Smooth_Scroll
;;@w1                 bit $d011                       ; Wait for Raster to be off screen 
;;                    bpl @w1 
;;@w2                 bit $d011 
;;                    bmi                 @w2                 

; for the Atari we're going to have an on screen visual indicator of where the 
; processing stops and starts.  So on entry assume we're not in the correct position, 
; and reassert the correct screen colors from the OS shadow registers.

	lda COLOR1
	sta COLPF1
	lda COLOR2
	sta COLPF2
	lda COLOR4
	sta COLBK
	
smooth_scroll_loop
;                    lda                 $D012               
;                    cmp #100
;                    bcc                 @loop
;                    rts

	; I think the idea here is to wait for a scan line AFTER the scrolling line, so that
	; the font bitmap ROL'ing is not applied while the text line is being displayed. 

	lda VCOUNT
	cmp #29 ; 24 blank lines, plus 8 * four lines of text (32), = 56, divided by 2 = 28. Start at +1
	bne smooth_scroll_loop
	
	; We're at the correct position. Change border and playfield color to 
	; identify when we're processing. 
	
	lda #$C6   ; It's not easy being green. 
	sta COLPF1
	sta COLPF2
	sta COLBK
	
	rts


; ***********************************************************************************
; Extra Atari stuff.  Little bit-o-docs.  Explain the run-time markers on screen.
; ***********************************************************************************

Write_doc_msg
	ldx #0  ; index into Doc_msg text.
	ldy #80 ; index into screen RAM. Start on 3rd line. 
			; This leaves 176 characters for direct index.
write_more
	lda Doc_msg,x   ; get a character from the string .
	cmp #155        ; Is it ATASCII EOL?  Stop here.
	beq Exit_write_doc_msg
	sta (SAVMSC),Y  ;  Poke it to screen memory. 
	inx
	iny 
	bne write_more  ; Do until we hit EOL.
	
Exit_write_doc_msg
	rts
	
Doc_msg
	.sbyte "THE GREEN COLOR IS THE TIME SPENT       "
	.sbyte "RUNNING THE ROL CODE."
	.byte 155


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










*=$0801

        BYTE    $0E,$08,$0A,$00,$9E,$20,$28,$32,$30,$36,$34,$29,$00,$00,$00

; [CODE START] ----------------------------------------------------------------

*=$0810
Const_StartLine     = $400
CS                  = $3000
                    
Const_Char1      = CS+$200
Const_Char2      = CS+$201
Const_Char3      = CS+$202
Const_Char4      = CS+$203
Const_Char5      = CS+$204
Const_Char6      = CS+$205
Const_Char7      = CS+$206
Const_Char8      = CS+$207                    

;http://dustlayer.com/vic-ii/2013/4/23/vic-ii-for-beginners-part-2-to-have-or-to-not-have-character

; ***********************************************************************************
; Step 1 Redefine char set    
; ***********************************************************************************

Character_Set        
                    lda                 #$93                
                    jsr                 $ffd2               
                  
                    sei                                     ; disable interrupts while we copy
                    ldx                 #$08                ; we loop 8 times (8x255 = 2Kb)
                    lda                 #$33                ; make the CPU see the Character Generator ROM...
                    sta                 $01                 ; ...at $D000 by storing %00110011 into location $01
                    lda                 #$d0                ; load high byte of $D000
                    sta                 $fc                 ; store it in a free location we use as vector
                    LDA                 #>CS                ;
                    STA                 $fe                 ;
                    LDA                 #0                  ;
                    STA                 $fd
                    ldy                 #$00                ; init counter with 0
                    sty                 $fb                 ; store it as low byte in the $FB/$FC vector
loop                lda                 ($fb),y             ; read byte from vector stored in $fb/$fc
                    sta                 ($fd),y             ; write to the RAM under ROM at same position
                    iny                                     ; do this 255 times...
                    bne                 loop                ; ..for low byte $00 to $FF
                    inc                 $fc                 ; when we passed $FF increase high byte...
                    inc                 $fe
                    dex                                     ; ... and decrease X by one before restart
                    bne                 loop                ; We repeat this until X becomes Zero
                    lda                 #$37                ; switch in I/O mapped registers again...
                    sta                 $01                 ; ... with %00110111 so CPU can see them
                    cli                                    ; turn off interrupt disable flag
                    LDA                 #28    
                    STA                 $d018               ;

; ***********************************************************************************
; Step 2 Initialize the redefined characters in charset used for scrolling, they
;        -start at index charset index 64 which equate to 64*8 = $200 + $3000=$3200 
; ***********************************************************************************

                    
                    ldy                 #$00                  
@inner              lda #0
                    sta                 CS+$200,y                                 
                    iny
                    cpy                 #255                  
                    bne                 @inner
                    ldy                 #00                
@inner2             sta                 $32ff,y             
                    iny
                    cpy #66
                    bne                 @inner2    
                   
; ***********************************************************************************
; Step 3 - Display the redefined characters on screen
;        - In this case in one lines across the entire screen
; ***********************************************************************************

                    ldy                 #0                  
                    ldx                 #64    ; character set offset            
@loop1              txa
                    sta                 Const_StartLine,y              
                    iny
                    inx
                    cpy                 #40             
                    bne                 @loop1              
                    
; ***********************************************************************************
; Step 4 - start shifting the redefined characters
; ***********************************************************************************

                    ldx                 #0                  
@keepgoing                             
                    lda                 newmessage,x
                    beq                 @done               
                    jsr                 grab_next_char                      
                    jsr                 shift_all_chars                    
                    inx
                    jmp                 @keepgoing          
@done               rts
                   
; ***********************************************************************************
; Subroutines Grab next char
; ***********************************************************************************
grab_next_char                  
                    tay
                    lda                 charhi,y            
                    sec
                    sbc                 #2                  
                    sta                 $fc                 
                    lda                 charlow,y            
                    sta                 $fb        
         
                    ldy                 #40            ; # chars index into charset                                
                    lda                 charhi,y            
                    sta                 $fe                 
                    lda                 charlow,y           
                    sta                 $fd                 
                    
                    ldy                 #0                                      
@inner              lda                 ($fb),y       ; Source character set
                    sta                 ($fd),y       ; Dest in redefined area
                    iny
                    cpy                 #8                                      
                    bne                 @inner                
@end_loop           rts
                    
; ***********************************************************************************
; Subroutine  Shift char
; ***********************************************************************************
                   
shift_all_chars                         
                    jsr                 Shift_Once          
                    jsr                 Shift_Once          
                    jsr                 Shift_Once          
                    jsr                 Shift_Once          
                    jsr                 Shift_Once          
                    jsr                 Shift_Once          
                    jsr                 Shift_Once          
                    jsr                 Shift_Once          
                    rts
Shift_Once          
                    jsr Smooth_Scroll 
                    ;jsr delay                                   
                    RotateLine          Const_Char8
                    RotateLine          Const_Char7
                    RotateLine          Const_Char6
                    RotateLine          Const_Char5
                    RotateLine          Const_Char4
                    RotateLine          Const_Char3          
                    RotateLine          Const_Char2          
                    RotateLine          Const_Char1          
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
                    cmp #200
                    bcc                 @loop
                    rts

delay
                    txa
                    pha
                    ldy #5
@loop2              ldx                 #0
@loop               dex
                    bne                 @loop               
                    dey
                    bne                 @loop2              
                    pla
                    tax
                    rts


;                    rol                 /1
;                    rol                 /1+8
;                    rol                 /1+16           
;                    rol                 /1+24           
;                    rol                 /1+32           
;                    rol                 /1+40           
;                    rol                 /1+48           
;                    rol                 /1+56           
;                    rol                 /1+64           
;                    rol                 /1+72           
;                    rol                 /1+80           
;                    rol                 /1+88           
;                    rol                 /1+96           
;                    rol                 /1+104           
;                    rol                 /1+112           
;                    rol                 /1+120          
;                    rol                 /1+128          
;                    rol                 /1+136         
;                    rol                 /1+144           
;                    rol                 /1+152           
;                    rol                 /1+160          
;                    rol                 /1+168          
;                    rol                 /1+176          
;                    rol                 /1+184         
;                    rol                 /1+192          
;                    rol                 /1+200           
;                    rol                 /1+208          
;                    rol                 /1+216         
;                    rol                 /1+224          
;                    rol                 /1+232           
;                    rol                 /1+240           
;                    rol                 /1+248          
;                    rol                 /1+256           
;                    rol                 /1+264           
;                    rol                 /1+272      
;                    rol                 /1+280          
;                    rol                 /1+288                               
;                    rol                 /1+296      
;                    rol                 /1+304           
;                    rol                 /1+312           
;                    rol                 /1+320           

                    endm
                 
newmessage          null 'hello this is a message from gray defender this is my message will it repeat            it might!                           '                    
charlow             byte $00,$08,$10,$18,$20,$28,$30,$38,$40,$48,$50,$58,$60,$68,$70,$78,$80,$88,$90,$98,$a0,$a8,$b0,$b8,$c0,$c8,$d0,$d8,$e0,$e8,$f0,$f8,$00,$08,$10,$18,$20,$28,$30,$38,$40,$48
charhi              byte >CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+2,>CS+3,>CS+3,>CS+3,>CS+3,>CS+3,>CS+3,>CS+3,>CS+3,>CS+3,>CS+3


