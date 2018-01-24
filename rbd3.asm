; --------------------------------------------------------------------
; 6502 assembly on Atari.
; Built with eclipse/wudsn/atasm.
;
; The World's Smallest Raster Bar Demo (with smaller color bars and vertical movement)
;
; Load value of scan line counter.
; Multiply by 2. (which shrinks the size of the color bars.)
; Add that value to the current jiffy (1/60 sec) timer value.
; Write that value to the background color.
; do it again until there is no more electricity.
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
	lda VCOUNT    ; Load VCOUNT scan line counter
	asl a         ; Multiply by 2 to shrink bar height
	clc
	adc RTCLOK60  ; Add the jiffy timer.
	sta COLBK     ; COLOR!
	jmp PRG_START
	
; --------------------------------------------------------------------
; Store the program start location in the Atari DOS RUN Address.
; When DOS is done loading the executable file into memory it will 
; automatically jump to the address placed here in DOS_RUN_ADDR.

; DOS_RUN_ADDR =  $02e0 ; Execute at address stored here when file loading completes.

	mDiskDPoke DOS_RUN_ADDR, PRG_START

; --------------------------------------------------------------------
	.end ; finito

