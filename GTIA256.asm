; --------------------------------------------------------------------
; 6502 assembly on Atari.
; Built with eclipse/wudsn/atasm.
;
; 256 colors on GTIA mode 9.
;
; --------------------------------------------------------------------
 
;===============================================================================
;   ATARI SYSTEM INCLUDES
;===============================================================================
; Various Include files that provide equates defining 
; registers and the values used for the registers:
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

	mDiskDPoke DOS_RUN_ADDR, PRG_START

; --------------------------------------------------------------------
	.end ; finito
