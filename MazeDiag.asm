;*******************************************************************************
;*
;* Diagonal Maze
;*
;*******************************************************************************
;*
;* 10PRINT demo from BASIC converted to Assembly for the Atari
;
; 2021 Ken Jennings                        
;*                                                                             
;*******************************************************************************

; ==========================================================================
; Atari System Includes (MADS assembler versions)

	icl "POKEY.asm"  ; Beep Bop Boop. And RANDOM.
	icl "OS.asm"     ; Interrupt definitions.
	icl "DOS.asm"    ; LOMEM, load file start, and run addresses.

	icl "macros.asm" ; Macros (No code/data declared)
; --------------------------------------------------------------------------

	ORG $80               ; Running in page 0 is evil.

TABLE_MAZE_CHARS          ; Two screen codes for characters (slashes)
	.byte 6,7            

PRG_START

	lda #0
	sta LMARGN             ; Set screen left margin to 0

LOOP
	lda RANDOM             ; Get random value
	and #1                 ; Filter down to 0 or 1
	tax                    ; Use as index.
	lda TABLE_MAZE_CHARS,x ; Get character from list.
	tax                    ; Save in X.
	jsr PutCH              ; write charcter to E:
	jmp LOOP               ; Run while more electricity.


; Use the E: put byte cheat that exists to service BASIC.

PutCH	
	lda ICPTH              ; High byte for Put Char in E:/IOCB Channel 0.
	pha                    ; Push to stack
	lda ICPTL              ; Low byte for Put Char in E:/IOCB Channel 0.
	pha                    ; Push to stack

	txa                    ; Restore A with the character to print.

	rts                    ; Call E: Put character. 

; ==========================================================================
; Inform DOS of the program's Auto-Run address...
; --------------------------------------------------------------------------

	mDiskDPoke DOS_RUN_ADDR,PRG_START
 
	END


; 31 bytes program and data $80 through $9E.
; 43 bytes including load file format structure and autorun information.

; COM block 1
; 0000 : 0000 : FF FF 80 00 9E 00                               | ....          
; 0006 : 0080 : 06 07 A9 00 85 52 AD 0A D2 29 01 AA B5 80 AA 20 | ..)..R-.R).*5.* 
; 0016 : 0090 : 95 00 4C 86 00 AD 47 03 48 AD 46 03 48 8A 60    | ..L..-G.H-F.H.` 

; COM block 2
; 0025 : 0000 : E0 02 E1 02                                     | `.a.            
; 0029 : 02E0 : 82 00                                           | ..              

