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

Z_ROM_SOURCE = $FB
SCROLL_DEST  = SOFT_CSET+$340 ; Or cset start of char 104 which is 64 + 40

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
	; framework should work identically on Atari
	
	ldx #0                  
keepgoing          
	lda newmessage,X        
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
                   
shiftchar     
                    jsr Smooth_Scroll      
                    ldx                 #00                
@loop
                    txa
                    tay                    
                    lda                 charhi,y
                    sta                 $fc                 
                    lda                 charlow,y            
                    sta                 $fb                 
                    iny
                    lda                 charhi,y
                    sta                 $fe                 
                    lda                 charlow,y            
                    sta                 $fd                 
                    ldy                 #7                                    
@loopab                    
                    lda                 ($fd),y             
                    and                 #%10000000          
                    bne                 @sec                    
@clc                clc
                    jmp @cont              
@sec                sec
@cont               lda                 ($fb),y                  
                    rol
                    sta                 ($fb),y            
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

xsave               byte 00                   
newmessage          null 'hello this is a message from gray defender this is my message will it repeat            it might!                           '                    

; Here is one reason why atasm rocks
;
; This mass of typing:
; charlow byte $00,$08,$10,$18,$20,$28,$30,$38
;         byte $40,$48,$50,$58,$60,$68,$70,$78
;         byte $80,$88,$90,$98,$a0,$a8,$b0,$b8
;         byte $c0,$c8,$d0,$d8,$e0,$e8,$f0,$f8
;         byte $00,$08,$10,$18,$20,$28,$30,$38
;         byte $40,$48
; becomes this:
CR

charhi              byte $32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$32,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33


; --------------------------------------------------------------------
; Store the program start location in the Atari DOS RUN Address.
; When DOS is done loading the executable file into memory it will 
; automatically jump to the address placed here in DOS_RUN_ADDR.

; DOS_RUN_ADDR =  $02e0 ; Execute at address stored here when file loading completes.

	mDiskDPoke DOS_RUN_ADDR, CODE_START

; --------------------------------------------------------------------
	.end ; finito
	






; ***************** DISPLAY LIST *****************

; Forcing start to a boundary guarantees there is no problem 
; with graphics or display list alignment.
; Even the most convoluted display list will not exceed 1K.

	mAlign 1024

DISPLAY_LIST

; Overscan 0 - 23
	.byte DL_BLANK_8
	.byte DL_BLANK_8

	; 16 * 12 lines is 192 scan lines.
	.rept 16
		mDL_LMS DL_MAP_F, SCREEN_MEM ; 1
		mDL_LMS DL_MAP_F, SCREEN_MEM ; 2
		mDL_LMS DL_MAP_F, SCREEN_MEM ; 3
		mDL_LMS DL_MAP_F, SCREEN_MEM ; 4
		mDL_LMS DL_MAP_F, SCREEN_MEM ; 5
		mDL_LMS DL_MAP_F, SCREEN_MEM ; 6
		mDL_LMS DL_MAP_F, SCREEN_MEM ; 7
		mDL_LMS DL_MAP_F, SCREEN_MEM ; 8
		mDL_LMS DL_MAP_F, SCREEN_MEM ; 9
		mDL_LMS DL_MAP_F, SCREEN_MEM ; 10
		mDL_LMS DL_MAP_F, SCREEN_MEM ; 11
		mDL_LMS DL_MAP_F|DL_DLI, SCREEN_MEM ; 12th with DLI
	.endr
	
; Superfluous blank before JVB.
	.byte DL_BLANK_8

; Display List End
	.byte DL_JUMP_VB
	.word DISPLAY_LIST

	
; ***************** SCREEN DATA *****************

	mAlign 256

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


; --------------------------------------------------------------------

; DLI

	BACK_COLOR .byte $00

DLI
	pha
	lda BACK_COLOR
	sta WSYNC
	sta COLBK
	cld
	clc
	adc #$10
	sta BACK_COLOR
	pla
	rti


; --------------------------------------------------------------------
; Vertical Blank Interrupt

VBI

; Force clean start to DLI
	lda #$00
	sta COLOR4
	sta COLBK
	lda #$10
	sta BACK_COLOR
	
; Finito.
	jmp XITVBV


; --------------------------------------------------------------------

PRG_START
; Start the display.  (Note this is a hacky, not especially safe way to startup.)

; Set new Display List address
; SDLSTL = $0230 ; OS Shadow register for ANTIC's DLISTL (Display List Address)
	mLoadIntP SDLSTL, DISPLAY_LIST

; Set DLI staring address.
	mLoadIntP VDSLST, DLI
	
	lda #ENABLE_DL_DMA|PLAYFIELD_WIDTH_NORMAL ; Set DMA control. 
	sta SDMCTL ; SDMCTL = $022F ; OS Shadow register for ANTIC's DMACTL (Display DMA Control)

    ; Set the VBI
	ldy #<VBI ; LSB for routine
	ldx #>VBI ; MSB for routine
	lda #7 ; Set Interrupt Vector 7 for Deferred VBI
	jsr SETVBV  ; and away we go.

	lda #[NMI_DLI|NMI_VBI] ; Set DLI and VBI Interrupt flags ON
	sta NMIEN

	lda #GTIA_MODE_16_SHADE ; Engage GTIA 16 grey scale mode
 	sta GPRIOR
     
Do_While_More_Electricity         ; Infinite loop, otherwise the
	jmp Do_While_More_Electricity ; program returns to DOS immediately.

; --------------------------------------------------------------------
; Store the program start location in the Atari DOS RUN Address.
; When DOS is done loading the executable file into memory it will 
; automatically jump to the address placed here in DOS_RUN_ADDR.

; DOS_RUN_ADDR =  $02e0 ; Execute at address stored here when file loading completes.

	mDiskDPoke DOS_RUN_ADDR, CODE_START

; --------------------------------------------------------------------
	.end ; finito
	
