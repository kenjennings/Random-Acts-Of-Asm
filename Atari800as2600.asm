; --------------------------------------------------------------------
; Atari 800 as 2600
; 6502 assembly on Atari.
; Built with eclipse/wudsn/mads
;
; Abuse background color register as many times as possible on a 
; scan line.  (Like you have to do on the Atari 2600 when
; racing the beam).
;
; Turn off ANTIC DMA to maximize  number of times this can be done.
;
; --------------------------------------------------------------------

SDMCTL        = $022F ; DMACTL

VCOUNT        = $D40B ; (Read) Vertical Scan Line Counter
WSYNC         = $D40A ; Wait for Horizontal Sync

COLBK         = $D01A ; Playfield Background color

LOMEM_DOS_DUP = $3308 ; First usable memory after DOS and DUP 
DOS_RUN_ADDR  = $02e0 ; Execute here when file loading completes.


; --------------------------------------------------------------------

	ORG LOMEM_DOS_DUP ; Start "program" after DOS and DUP 


; --------------------------------------------------------------------

PRG_START

	lda #0     ; Turn off the screen DMA -- not really the same as turning off display.
	sta SDMCTL ; SDMCTL = $022F ; OS Shadow register for ANTIC's DMACTL (Display DMA Control)
	
LoopFrame
	lda VCOUNT
	cmp #20
	bne LoopFrame

	ldx #160  ; Repeat for an enjoyable number of scan lines

LoopColors
	sta WSYNC ; Baseline to start cycling at the end of this line.

	lda #$0E  
	sta COLBK ; Color  1
	
	lda #$36 
	nop       ; Wait a bit for the horizontal blank to progress,
	nop       ; otherwise multiple color register changes
	nop       ; occur when they are not even visible on screen.
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	sta COLBK ; Color  2

	lda #$0c 
	sta COLBK ; Color  3
	lda #$56
	sta COLBK ; Color  4
	lda #$0a
	sta COLBK ; Color  5
	lda #$76
	sta COLBK ; Color  6
	lda #$08
	sta COLBK ; Color  7
	lda #$96
	sta COLBK ; Color  8
	lda #$06
	sta COLBK ; Color  9
	lda #$b6
	sta COLBK ; Color  10
	lda #$04
	sta COLBK ; Color  11
	lda #$d6
	sta COLBK ; Color  12

	dex
	bne LoopColors
	
	lda #0
	sta COLBK
	
	jmp LoopFrame
	
; --------------------------------------------------------------------

	ORG	DOS_RUN_ADDR  ; Tell DOS where to start running this
	.word PRG_START

; --------------------------------------------------------------------
	END ; finito
