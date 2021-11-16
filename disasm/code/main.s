.include "includes.s"
        
.bank $000 slot 0
.org $0


Boot:
	nop                                                             ; $0000
	nop                                                             ; $0001
	lxi sp, wStackTop                                               ; $0002
	jmp Begin                                                       ; $0005


MidFrameInterruptHandler:
	push psw                                                        ; $0008
	push b                                                          ; $0009
	push d                                                          ; $000a
	push h                                                          ; $000b
	jmp _MidFrameInterruptHandler                                   ; $000c


VBlankInterruptHandler:
	nop                                                             ; $000f
	push psw                                                        ; $0010
	push b                                                          ; $0011
	push d                                                          ; $0012
	push h                                                          ; $0013
	jmp _VBlankInterruptHandler                                     ; $0014


Begin:
; Jump if INPUTF_SERVICE not set
	in MISC_INPUTS                                                  ; $0017
	ral                                                             ; $0019
	jnc BeginRegularGame                                            ; $001a

; Else begin service mode
	mvi b, $01                                                      ; $001d
	lxi d, $0000                                                    ; $001f

ServiceBitB:
; B = byte to set against all ram
	lxi h, wWram                                                    ; $0022

@nextRamAddr:
	out WATCHDOG_RESET                                              ; $0025

; Set ram, jumping if it reads back the same
	mov m, b                                                        ; $0027
	mov a, m                                                        ; $0028
	xra b                                                           ; $0029
	jz @toNextRamAddr                                               ; $002a

; C, then A after ani = the differing bits. Jump if odd wram
	mov c, a                                                        ; $002d
	mov a, l                                                        ; $002e
	ani $01                                                         ; $002f
	mov a, c                                                        ; $0031
	jnz @brokenOddRam                                               ; $0032

; Even ram, or differing bits in D
	ora d                                                           ; $0035
	mov d, a                                                        ; $0036
	jmp @toNextRamAddr                                              ; $0037

@brokenOddRam:
; Or differing bits in E
	ora e                                                           ; $003a
	mov e, a                                                        ; $003b

@toNextRamAddr:
	inx h                                                           ; $003c
	mov a, h                                                        ; $003d
	cpi >wRamEnd                                                    ; $003e
	jnz @nextRamAddr                                                ; $0040

; B = current byte to set in all ram
; D = dysfunctional bits in even ram
; E = dysfunctional bits in odd ram
; HL = $4000
AfterSettingAllRamToB:
@nextRamAddr:
; Dec ram addr, jumping if we finished all
	out WATCHDOG_RESET                                              ; $0043
	dcx h                                                           ; $0045
	mov a, h                                                        ; $0046
	cpi >(wWram-1)                                                  ; $0047
	jz AfterSettingAllRamToComplimentedB                            ; $0049

; Jump if ram addr we set last time to B, still reads B
	mov a, m                                                        ; $004c
	xra b                                                           ; $004d
	jz @setRamToComplimentedB                                       ; $004e

; C, then A after ani = the differing bits. Jump if odd wram
	mov c, a                                                        ; $0051
	mov a, l                                                        ; $0052
	ani $01                                                         ; $0053
	mov a, c                                                        ; $0055
	jnz @brokenOddRam1                                              ; $0056

; Even ram, or differing bits in D
	ora d                                                           ; $0059
	mov d, a                                                        ; $005a
	jmp @setRamToComplimentedB                                      ; $005b

@brokenOddRam1:
; Or differing bits in E
	ora e                                                           ; $005e
	mov e, a                                                        ; $005f

@setRamToComplimentedB:
; Write complimented byte into ram, jumping if it reads the same
	mov a, b                                                        ; $0060
	cma                                                             ; $0061
	mov m, a                                                        ; $0062
	xra m                                                           ; $0063
	jz @nextRamAddr                                                 ; $0064

; C, then A after ani = the differing bits. Jump if odd wram
	mov c, a                                                        ; $0067
	mov a, l                                                        ; $0068
	ani $01                                                         ; $0069
	mov a, c                                                        ; $006b
	jnz @brokenOddRam2                                              ; $006c

; Even ram, or differing bits in D
	ora d                                                           ; $006f
	mov d, a                                                        ; $0070
	jmp +                                                           ; $0071

@brokenOddRam2:
; Or differing bits in E
	ora e                                                           ; $0074
	mov e, a                                                        ; $0075

+	jmp @nextRamAddr                                                ; $0076

; B = current byte to set in all ram
; D = dysfunctional bits in even ram
; E = dysfunctional bits in odd ram
; HL = $1fff
AfterSettingAllRamToComplimentedB:
@nextRamAddr:
; Inc HL, starting service with next bit once we reach ram end
	out WATCHDOG_RESET                                              ; $0079
	inx h                                                           ; $007b
	mov a, h                                                        ; $007c
	cpi >wRamEnd                                                    ; $007d
	jz @serviceNextBit                                              ; $007f

; Jump if B == ~(HL) from last loop
	mov a, b                                                        ; $0082
	cma                                                             ; $0083
	xra m                                                           ; $0084
	jz @toNextRamAddr                                               ; $0085

; C, then A after ani = the differing bits. Jump if odd wram
	mov c, a                                                        ; $0088
	mov a, l                                                        ; $0089
	ani $01                                                         ; $008a
	mov a, c                                                        ; $008c
	jnz @brokenOddRam                                               ; $008d

; Even ram, or differing bits in D
	ora d                                                           ; $0090
	mov d, a                                                        ; $0091
	jmp @toNextRamAddr                                              ; $0092

@brokenOddRam:
; Or differing bits in E
	ora e                                                           ; $0095
	mov e, a                                                        ; $0096

@toNextRamAddr:
; Clear ram address for next servicing
	xra a                                                           ; $0097
	mov m, a                                                        ; $0098
	jmp @nextRamAddr                                                ; $0099

@serviceNextBit:
; Once bit 7 done, continue onwards
	mov a, b                                                        ; $009c
	rlc                                                             ; $009d
	mov b, a                                                        ; $009e
	jnc ServiceBitB                                                 ; $009f

; --
; -- After service
; --

; If D & E == 0 (healthy), process checksums
	mov a, d                                                        ; $00a2
	ora e                                                           ; $00a3
	jz ProcessRomChecksums                                          ; $00a4

; Else set SP to the differing bits DE
; Loop to set ram for $2000 bytes (all ram)
	xchg                                                            ; $00a7
	sphl                                                            ; $00a8
	lxi d, wWram                                                    ; $00a9
	mvi b, $00                                                      ; $00ac

@nextRamRow:
; HL = differing bits, loop to process all bits of orig DE
	lxi h, $0000                                                    ; $00ae
	dad sp                                                          ; $00b1

	mvi c, NEXT_PIXEL_ROW/2                                         ; $00b2

@next16pixels:
; Shift differing bits left, setting A to $ff if no carry (good data)
	xra a                                                           ; $00b4
	dad h                                                           ; $00b5
	jc +                                                            ; $00b6
	cma                                                             ; $00b9

; Store in wram
+	stax d                                                          ; $00ba
	inx d                                                           ; $00bb

; Clear next wram, ie we make it visible which bits differed with 16 cleared pixels, as opposed to alternating
; This would display across the screen, also highlighting specific ram byte areas with issues, per row
	xra a                                                           ; $00bc
	stax d                                                          ; $00bd
	inx d                                                           ; $00be

	dcr c                                                           ; $00bf
	jnz @next16pixels                                               ; $00c0

	dcr b                                                           ; $00c3
	jnz @nextRamRow                                                 ; $00c4

-	out WATCHDOG_RESET                                              ; $00c7
	jmp -                                                           ; $00c9


ProcessRomChecksums:
; Set SP as we do push/pops, HL = rom addr, DE = block idx, C = block end
	lxi sp, wStackTop                                               ; $00cc
	lxi h, $0000                                                    ; $00cf
	lxi d, $0000                                                    ; $00d2
	mvi c, >$400                                                    ; $00d5

@next400hBlock:
; A = block checksum
	xra a                                                           ; $00d7

@nextByteToTotal:
; Add byte from rom into A, retain total in B
	out WATCHDOG_RESET                                              ; $00d8
	add m                                                           ; $00da
	inx h                                                           ; $00db
	mov b, a                                                        ; $00dc

; Exit loop when HL == end of $400 block, else loop with total back in A
	mov a, c                                                        ; $00dd
	cmp h                                                           ; $00de
	mov a, b                                                        ; $00df
	jnz @nextByteToTotal                                            ; $00e0

; HL points to checksum table entry for block
	push h                                                          ; $00e3
	lxi h, ValidChecksumValues                                      ; $00e4
	dad d                                                           ; $00e7

; If valid, use a space char
	cmp m                                                           ; $00e8
	mvi a, CHAR_SPACE                                               ; $00e9
	jz @afterCharToUseForBlockChecksum                              ; $00eb

; Else use its entry from the invalid letters table
	lxi h, InvalidChecksumLetters                                   ; $00ee
	dad d                                                           ; $00f1
	mov a, m                                                        ; $00f2

@afterCharToUseForBlockChecksum:
; Load in char chosen, pop start address of next block
	lxi h, wServiceModeChecksumChars                                ; $00f3
	dad d                                                           ; $00f6
	mov m, a                                                        ; $00f7
	pop h                                                           ; $00f8

; Inc idx into checksum tables, and have C point to high byte of next $400 block
	inx d                                                           ; $00f9
	inr c                                                           ; $00fa
	inr c                                                           ; $00fb
	inr c                                                           ; $00fc
	inr c                                                           ; $00fd

; Return if just done up to $1000 (rom size)
	mvi a, 5*4                                                      ; $00fe
	cmp c                                                           ; $0100
	jnz @next400hBlock                                              ; $0101

; A = last checksum letter, or with the other 3 chars
	lxi h, wServiceModeChecksumCharsEnd-1                           ; $0104
	mov a, m                                                        ; $0107
	dcx h                                                           ; $0108

	ora m                                                           ; $0109
	dcx h                                                           ; $010a

	ora m                                                           ; $010b
	dcx h                                                           ; $010c

	ora m                                                           ; $010d

; Reset if all bits 0, ignoring bit 6 (space char just has bit 6 set),
; So we proceed only if checksum incorrect
	ani $bf                                                         ; $010e
	jz Boot                                                         ; $0110

; Draw text with invalid blocks not spaced out, and stay in an infinite loop
	lxi d, wVram+NEXT_PIXEL_ROW*96+8                                ; $0113
	mvi a, $04                                                      ; $0116
	call PrintText                                                  ; $0118

-	out WATCHDOG_RESET                                              ; $011b
	jmp -                                                           ; $011d


ValidChecksumValues:
	.db $00, $a1, $c1, $ee


Unused_0124:
	.db CHAR_COLON


InvalidChecksumLetters:
	.asc "HHGG"

; A - num chars
; DE - dest addr
; HL - src addr
PrintText:
@nextChar:
	push psw                                                        ; $0129

@getCharOrPos:
; Get byte, jumping if ascii (> CHAR_0), else it's position-related
	mov a, m                                                        ; $012a
	inx h                                                           ; $012b
	sui $30                                                         ; $012c
	jp @isChar                                                      ; $012e

; With B being inc'd per loop, loop ($30-orig val) times
	mov b, a                                                        ; $0131

@nextCol:
; Inc DE to next col, jumping if it loops around
	inx d                                                           ; $0132
	mov a, e                                                        ; $0133
	ani $1f                                                         ; $0134
	jnz +                                                           ; $0136

; If it looped, go 16 pixels down (+$200)
	inr d                                                           ; $0139
	inr d                                                           ; $013a

+	inr b                                                           ; $013b
	jnz @nextCol                                                    ; $013c

	jmp @getCharOrPos                                               ; $013f

@isChar:
	push h                                                          ; $0142
	push d                                                          ; $0143

; Char val++. If >= $0b ('9' now $0a), -6 to have 'A' 2 spots after '9'
	inr a                                                           ; $0144
	cpi $0b                                                         ; $0145
	jm +                                                            ; $0147
	sui $06                                                         ; $014a

; Every char takes up 10 bytes, loop to have HL point to char's tiles
+	lxi h, TileData_Ascii-CHAR_HEIGHT                               ; $014c
	lxi b, CHAR_HEIGHT                                              ; $014f
-	dad b                                                           ; $0152
	dcr a                                                           ; $0153
	jnz -                                                           ; $0154

; DE = src addr, HL = dest addr
	xchg                                                            ; $0157
	lxi b, NEXT_PIXEL_ROW                                           ; $0158
	mvi a, CHAR_HEIGHT                                              ; $015b

@nextCharLine:
	push psw                                                        ; $015d

; Copy from src to dest, point dest at next row each line
	ldax d                                                          ; $015e
	inx d                                                           ; $015f
	mov m, a                                                        ; $0160
	dad b                                                           ; $0161

; To next line for the char
	pop psw                                                         ; $0162
	dcr a                                                           ; $0163
	jnz @nextCharLine                                               ; $0164

; Get prev dest and inc it. Get src already inc'd
	pop d                                                           ; $0167
	pop h                                                           ; $0168
	inx d                                                           ; $0169

; To next char
	pop psw                                                         ; $016a
	dcr a                                                           ; $016b
	jnz @nextChar                                                   ; $016c

	ret                                                             ; $016f


TileData_Ascii:
	dbrev %00111100
	dbrev %01111110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01111110
	dbrev %00111100

	dbrev %00011000
	dbrev %00111000
	dbrev %00011000
	dbrev %00011000
	dbrev %00011000
	dbrev %00011000
	dbrev %00011000
	dbrev %00011000
	dbrev %00111100
	dbrev %00111100

	dbrev %00111100
	dbrev %01111110
	dbrev %01100110
	dbrev %00000110
	dbrev %00111110
	dbrev %01111100
	dbrev %01100000
	dbrev %01100000
	dbrev %01111110
	dbrev %01111110

	dbrev %00111100
	dbrev %01111110
	dbrev %01100110
	dbrev %00000110
	dbrev %00011100
	dbrev %00011110
	dbrev %00000110
	dbrev %01100110
	dbrev %01111110
	dbrev %00111100

	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01111110
	dbrev %01111110
	dbrev %00000110
	dbrev %00000110
	dbrev %00000110
	dbrev %00000110

	dbrev %01111100
	dbrev %01111100
	dbrev %01100000
	dbrev %01100000
	dbrev %01111100
	dbrev %01111110
	dbrev %00000110
	dbrev %01100110
	dbrev %01111110
	dbrev %00111100

	dbrev %00111100
	dbrev %01111100
	dbrev %01100000
	dbrev %01100000
	dbrev %01111100
	dbrev %01111110
	dbrev %01100110
	dbrev %01100110
	dbrev %01111110
	dbrev %00111100

	dbrev %01111110
	dbrev %01111110
	dbrev %00000110
	dbrev %00001110
	dbrev %00001100
	dbrev %00011100
	dbrev %00011000
	dbrev %00111000
	dbrev %00110000
	dbrev %00110000

	dbrev %00111100
	dbrev %01111110
	dbrev %01100110
	dbrev %01100110
	dbrev %00111100
	dbrev %01111110
	dbrev %01100110
	dbrev %01100110
	dbrev %01111110
	dbrev %00111100

	dbrev %00111100
	dbrev %01111110
	dbrev %01100110
	dbrev %01100110
	dbrev %01111110
	dbrev %00111110
	dbrev %00000110
	dbrev %00000110
	dbrev %00111110
	dbrev %00111100

TileData_Space:
	dbrev %00000000
	dbrev %00000000
	dbrev %00000000
	dbrev %00000000
	dbrev %00000000
	dbrev %00000000
	dbrev %00000000
	dbrev %00000000
	dbrev %00000000
	dbrev %00000000

	dbrev %00011000
	dbrev %00111100
	dbrev %01111110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01111110
	dbrev %01111110
	dbrev %01100110
	dbrev %01100110

	dbrev %01111100
	dbrev %01111110
	dbrev %01100110
	dbrev %01100110
	dbrev %01111100
	dbrev %01111110
	dbrev %01100110
	dbrev %01100110
	dbrev %01111110
	dbrev %01111100

	dbrev %00111100
	dbrev %01111110
	dbrev %01100110
	dbrev %01100000
	dbrev %01100000
	dbrev %01100000
	dbrev %01100000
	dbrev %01100110
	dbrev %01111110
	dbrev %00111100

	dbrev %01111100
	dbrev %01111110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01111110
	dbrev %01111100

	dbrev %01111110
	dbrev %01111110
	dbrev %01100000
	dbrev %01100000
	dbrev %01111100
	dbrev %01111100
	dbrev %01100000
	dbrev %01100000
	dbrev %01111110
	dbrev %01111110

	dbrev %01111110
	dbrev %01111110
	dbrev %01100000
	dbrev %01100000
	dbrev %01111100
	dbrev %01111100
	dbrev %01100000
	dbrev %01100000
	dbrev %01100000
	dbrev %01100000

	dbrev %00111100
	dbrev %01111110
	dbrev %01100110
	dbrev %01100000
	dbrev %01100000
	dbrev %01101110
	dbrev %01101110
	dbrev %01100110
	dbrev %01111110
	dbrev %00111100

	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01111110
	dbrev %01111110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110

	dbrev %00111100
	dbrev %00111100
	dbrev %00011000
	dbrev %00011000
	dbrev %00011000
	dbrev %00011000
	dbrev %00011000
	dbrev %00011000
	dbrev %00111100
	dbrev %00111100

	dbrev %00000011
	dbrev %00000011
	dbrev %00000011
	dbrev %00000011
	dbrev %00000011
	dbrev %00000011
	dbrev %00000000
	dbrev %00000000
	dbrev %00000011
	dbrev %00000011

	dbrev %01100110
	dbrev %01100110
	dbrev %01101110
	dbrev %01111100
	dbrev %01111000
	dbrev %01111000
	dbrev %01111100
	dbrev %01101110
	dbrev %01100110
	dbrev %01100110

	dbrev %01100000
	dbrev %01100000
	dbrev %01100000
	dbrev %01100000
	dbrev %01100000
	dbrev %01100000
	dbrev %01100000
	dbrev %01100000
	dbrev %01111110
	dbrev %01111110

	dbrev %11000011
	dbrev %11000011
	dbrev %11100111
	dbrev %11100111
	dbrev %11111111
	dbrev %11111111
	dbrev %11011011
	dbrev %11000011
	dbrev %11000011
	dbrev %11000011

	dbrev %01100110
	dbrev %01100110
	dbrev %01110110
	dbrev %01110110
	dbrev %01111110
	dbrev %01111110
	dbrev %01101110
	dbrev %01101110
	dbrev %01100110
	dbrev %01100110

	dbrev %00111100
	dbrev %01111110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01111110
	dbrev %00111100

	dbrev %01111100
	dbrev %01111110
	dbrev %01100110
	dbrev %01100110
	dbrev %01111110
	dbrev %01111100
	dbrev %01100000
	dbrev %01100000
	dbrev %01100000
	dbrev %01100000

	dbrev %00000000
	dbrev %00000000
	dbrev %00010000
	dbrev %00010000
	dbrev %00010000
	dbrev %10010010
	dbrev %11010110
	dbrev %01111100
	dbrev %00111000
	dbrev %00010000

	dbrev %01111100
	dbrev %01111110
	dbrev %01100110
	dbrev %01100110
	dbrev %01111110
	dbrev %01111100
	dbrev %01101110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110

	dbrev %00111100
	dbrev %01111110
	dbrev %01100110
	dbrev %01100000
	dbrev %01111100
	dbrev %00111110
	dbrev %00000110
	dbrev %01100110
	dbrev %01111110
	dbrev %00111100

	dbrev %01111110
	dbrev %01111110
	dbrev %00011000
	dbrev %00011000
	dbrev %00011000
	dbrev %00011000
	dbrev %00011000
	dbrev %00011000
	dbrev %00011000
	dbrev %00011000

	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01111110
	dbrev %00111100

	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01100110
	dbrev %01111110
	dbrev %00111100
	dbrev %00111100
	dbrev %00011000
	dbrev %00011000

	dbrev %11000011
	dbrev %11000011
	dbrev %11000011
	dbrev %11011011
	dbrev %11111111
	dbrev %11111111
	dbrev %11100111
	dbrev %11100111
	dbrev %11000011
	dbrev %11000011

	dbrev %00000000
	dbrev %00011000
	dbrev %00011000
	dbrev %00000000
	dbrev %00000000
	dbrev %00000000
	dbrev %00000000
	dbrev %00011000
	dbrev %00011000
	dbrev %00000000

	dbrev %01100110
	dbrev %01100110
	dbrev %01111110
	dbrev %00111100
	dbrev %00011000
	dbrev %00011000
	dbrev %00011000
	dbrev %00011000
	dbrev %00011000
	dbrev %00011000

	dbrev %01111110
	dbrev %01111110
	dbrev %00000110
	dbrev %00001110
	dbrev %00011100
	dbrev %00111000
	dbrev %01110000
	dbrev %01100000
	dbrev %01111110
	dbrev %01111110


_VBlankInterruptHandler:
; Don't proceed if the int to ignore is $00, else proceed and set it to $00
	xra a                                                           ; $02e2
	call CheckIfShouldIgnoreInterrupt                               ; $02e3
	mov m, a                                                        ; $02e6

; Move players, dec timers setting those just done, and check player 1's inputs
	call UpdatePlayersDisplayOnScreen                               ; $02e7
	call DecTimersCheckThoseJustDone                                ; $02ea

	lxi h, wPlayer1.DirInputs                                       ; $02ed
	call UpdatePlayerFromInputsHeld                                 ; $02f0

; Process timers, directions players have held, and if any players have won
	call ProcessTimersJustDoneHandlers                              ; $02f3
	call ProcessDirInputs                                           ; $02f6
	call CheckIfAnyPlayerWon                                        ; $02f9

InterruptHandlerEnd:
	pop h                                                           ; $02fc
	pop d                                                           ; $02fd
	pop b                                                           ; $02fe
	pop psw                                                         ; $02ff
	ei                                                              ; $0300
	ret                                                             ; $0301


; A - $00 to ignore vblank funcs, $10 to ignore mid-frame funcs
CheckIfShouldIgnoreInterrupt:
; If interrupt to ignore matches A...
	lxi h, wInterruptHandlerToIgnore                                ; $0302
	cmp m                                                           ; $0305
	rnz                                                             ; $0306

; Pop return addr further into handler, and end interrupt
	pop h                                                           ; $0307
	jmp InterruptHandlerEnd                                         ; $0308


_MidFrameInterruptHandler:
; Don't proceed if the int to ignore is $10, else proceed and set it to $10
	mvi a, $10                                                      ; $030b
	call CheckIfShouldIgnoreInterrupt                               ; $030d
	mov m, a                                                        ; $0310

; Update players and process misc inputs
	call UpdatePlayersDisplayOnScreen                               ; $0311
	call ProcessCoinage                                             ; $0314
	call ProcessStartInputs                                         ; $0317

; Jump if 2 players
	lda wNumPlayers                                                 ; $031a
	dcr a                                                           ; $031d
	jnz @updatePlayer2FromInputs                                    ; $031e

; If 1 player, we're done if still in study time
	lda wStudyTimeIsDone                                            ; $0321
	ana a                                                           ; $0324
	jz InterruptHandlerEnd                                          ; $0325

; If 1 player, with game started...
	lxi h, wAIMovementFrameCounter                                  ; $0328
	inr m                                                           ; $032b

; Return if AI needs more frames to move, else clear frame counter, and move AI
	lda wAIMovementDelay                                            ; $032c
	cmp m                                                           ; $032f
	jnz InterruptHandlerEnd                                         ; $0330

	mvi m, $00                                                      ; $0333
	call MoveAI                                                     ; $0335

@updatePlayer2FromInputs:
	lxi h, wPlayer2.DirInputs                                       ; $0338
	call UpdatePlayerFromInputsHeld                                 ; $033b
	jmp InterruptHandlerEnd                                         ; $033e


DecTimersCheckThoseJustDone:
; Return if timers to process not 0, else clear b (timers just done) and proceed
	lxi h, wTimersJustDoneBitField                                  ; $0341
	mov a, m                                                        ; $0344
	ana a                                                           ; $0345
	rnz                                                             ; $0346

	mov b, a                                                        ; $0347

; Every second, process wTimerUntilScriptChange
	lxi h, wTimesToShuffleRNG                                       ; $0348
	dcr m                                                           ; $034b
	jnz @afterScriptChangeTimer                                     ; $034c

	mvi m, 60                                                       ; $034f
	lxi h, wTimerUntilScriptChange                                  ; $0351
	call ShiftInBitSetIfTimerJustDone                               ; $0354

@afterScriptChangeTimer:
; Now do wait timer
	lxi h, wScriptWaitTimer                                         ; $0357
	call ShiftInBitSetIfTimerJustDone                               ; $035a

; Then do wSecondsPassedTimer
	inx h                                                           ; $035d
	call ShiftInBitSetIfTimerJustDone                               ; $035e

; Then do wTimerUntilNextStudyTimeTick
	inx h                                                           ; $0361
	call ShiftInBitSetIfTimerJustDone                               ; $0362
	sta wTimersJustDoneBitField                                     ; $0365
	ret                                                             ; $0368


; HL - timer
ShiftInBitSetIfTimerJustDone:
; If timer == 0, it could be idle, don't shift in bit
	mov a, m                                                        ; $0369
	ana a                                                           ; $036a
	jz @end                                                         ; $036b

; Dec timer, and set carry if timer now 0
	dcr m                                                           ; $036e
	jnz @end                                                        ; $036f

	stc                                                             ; $0372

@end:
; B << 1, bringing in carry if set
	mov a, b                                                        ; $0373
	ral                                                             ; $0374
	mov b, a                                                        ; $0375
	ret                                                             ; $0376


BeginRegularGame:
; Clear all ram
	mvi a, (wRamEnd-wWram)/$200                                     ; $0377
	call MemClear200hAFromRamEnd                                    ; $0379

; Start with game over screen
	lxi h, Script_GameOver                                          ; $037c
	shld wScriptToStart                                             ; $037f

; Set random vars to all $ff
	lxi h, $ffff                                                    ; $0382
	shld wRNGVars                                                   ; $0385
	shld wRNGVars+2                                                 ; $0388

; After executing a command after, return here
-	ei                                                              ; $038b
	lxi h, -                                                        ; $038c
	push h                                                          ; $038f

	out WATCHDOG_RESET                                              ; $0390

; If no new script to start, jump
	lhld wScriptToStart                                             ; $0392
	mov a, h                                                        ; $0395
	ora l                                                           ; $0396
	jz @processCurrScript                                           ; $0397

; Reset these control script timers
	xra a                                                           ; $039a
	sta wTimerUntilScriptChange                                     ; $039b
	sta wScriptWaitTimer                                            ; $039e

; Set curr script to process, and clear script to start
	shld wScriptPointer                                             ; $03a1
	lxi h, $0000                                                    ; $03a4
	shld wScriptToStart                                             ; $03a7

@processCurrScript:
; A = curr script byte, jump if 0
	lhld wScriptPointer                                             ; $03aa
	mov a, m                                                        ; $03ad
	ana a                                                           ; $03ae
	jz @scriptCommand0_Wait                                         ; $03af

; Save address of next script byte, then save that next addr in DE
	inx h                                                           ; $03b2
	shld wScriptPointer                                             ; $03b3
	xchg                                                            ; $03b6

; Table is for other non-0 script commands. If invalid, reset
	lxi h, Non0ScriptCommands                                       ; $03b7
	dcr a                                                           ; $03ba
	cpi _sizeof_Non0ScriptCommands/2                                ; $03bb
	jnc BeginRegularGame                                            ; $03bd

; BC = double idx, add onto HL
	add a                                                           ; $03c0
	mov c, a                                                        ; $03c1
	mvi b, $00                                                      ; $03c2
	dad b                                                           ; $03c4

; Get HL from table entry, then jump to it
	mov a, m                                                        ; $03c5
	inx h                                                           ; $03c6
	mov h, m                                                        ; $03c7
	mov l, a                                                        ; $03c8
	pchl                                                            ; $03c9

@scriptCommand0_Wait:
; Set new game grid if not yet loaded, while waiting
	lda wGameGridLoaded                                             ; $03ca
	ana a                                                           ; $03cd
	cz GenNewGameGrid                                               ; $03ce
	ret                                                             ; $03d1


.org $3d4

GenNewGameGrid:
@setNewGameGrid:
; Clear low decision bits, and clear happy path counter
	call RetainOnlyUpperBitsOfGameGridData                          ; $03d4
	xra a                                                           ; $03d7
	sta wNumTimesSettingWallsForHappyPath                           ; $03d8

; Set RNG for grid, and gen left exit point (sets BC to that points coords)
	call ShuffleRNG                                                 ; $03db
	call SetGameGridLeftExitPoint                                   ; $03de

@setMoreWalls:
; Check neighbors, jumping if all already previously explored (can't move)
	call EisNumNeighborsWithBit0Clear                               ; $03e1
	out WATCHDOG_RESET                                              ; $03e4
	mov a, e                                                        ; $03e6
	ana a                                                           ; $03e7
	jz @noMoreMoves                                                 ; $03e8

; If we can move, continue setting walls from new loc
	call SetSomeGridWallsAroundCurrLoc                              ; $03eb
	jmp @setMoreWalls                                               ; $03ee

@noMoreMoves:
; If we're still in happy path, we can't find the exit, so set new grid
	lda wCurrGameGridByteIsNotInSolution                            ; $03f1
	ana a                                                           ; $03f4
	jz @setNewGameGrid                                              ; $03f5

; If any game grid cell bit 0's set (previously explored), try to set more walls from it
	call RetZIfReachedEndOfGridWithNoNewWallsSet                    ; $03f8
	jc @setMoreWalls                                                ; $03fb

; Else set that game grid is now loaded
	inr a                                                           ; $03fe
	sta wGameGridLoaded                                             ; $03ff
	ret                                                             ; $0402


RetainOnlyUpperBitsOfGameGridData:
; Loop through all grid columns
	lxi d, wGameGrid                                                ; $0403
	mvi b, GRID_TILE_WIDTH                                          ; $0406

@nextCol:
; Loop through all rows in col
	mvi c, GRID_TILE_HEIGHT                                         ; $0408

@nextRow:
; Retain only the upper bits
	ldax d                                                          ; $040a
	ani $f0                                                         ; $040b
	stax d                                                          ; $040d

; To next grid byte and row
	inx d                                                           ; $040e
	dcr c                                                           ; $040f
	jnz @nextRow                                                    ; $0410

	dcr b                                                           ; $0413
	jnz @nextCol                                                    ; $0414

	ret                                                             ; $0417


Unused_0418:
	ret                                                             ; $0418


ScriptCommand06_InitInGameVars:
; Called after a game is done, set game grid upper nybs which game logic checks against
	call ShiftGameGridLowNybsIntoUpperNybs                          ; $0419

; Clear in-game state
	xra a                                                           ; $041c
	lxi h, wInGameVarsToReset                                       ; $041d
	mvi b, wInGameVarsToResetEnd-wInGameVarsToReset                 ; $0420

-	mov m, a                                                        ; $0422
	inx h                                                           ; $0423
	dcr b                                                           ; $0424
	jnz -                                                           ; $0425

; Copy from this var to wLeftArrowTileY
	lxi h, wInitTileYtoSetForLeftArrow                              ; $0428
	mov a, m                                                        ; $042b
	inx h                                                           ; $042c
	mov m, a                                                        ; $042d
	inx h                                                           ; $042e

; Copy from wInitTileYtoSetForRightArrow to wRightArrowTileY
	mov a, m                                                        ; $042f
	inx h                                                           ; $0430
	mov m, a                                                        ; $0431

; Get C, then B from init row and wInitColToSetForAI
	lxi h, wInitRowToSetForAI                                       ; $0432
	mov c, m                                                        ; $0435
	inx h                                                           ; $0436
	mov b, m                                                        ; $0437
	inx h                                                           ; $0438

; Store in wAIGameGridRow, wAIGameGridCol
	mov m, c                                                        ; $0439
	inx h                                                           ; $043a
	mov m, b                                                        ; $043b
	ret                                                             ; $043c


ShiftGameGridLowNybsIntoUpperNybs:
; Loop through game grid bytes. B = 1 extra due to how loop below works
	lxi d, wGameGrid                                                ; $043d
	lxi b, _sizeof_wGameGrid+$100                                   ; $0440

@nextByte:
; Get game grid byte, and shift its low nybble into the upper nybble
	ldax d                                                          ; $0443
	add a                                                           ; $0444
	add a                                                           ; $0445
	add a                                                           ; $0446
	add a                                                           ; $0447

; Set byte, then point DE to the next
	stax d                                                          ; $0448
	inx d                                                           ; $0449

; To next byte
	dcr c                                                           ; $044a
	jnz @nextByte                                                   ; $044b

	dcr b                                                           ; $044e
	jnz @nextByte                                                   ; $044f

	ret                                                             ; $0452


CheckIfAnyPlayerWon:
; Return if we already finished the game based on checks below
	lda wProcessedGameDone                                          ; $0453
	ana a                                                           ; $0456
	rnz                                                             ; $0457

; B = player that just won
	mvi b, $01                                                      ; $0458
	lxi h, wPlayer2.PixelX                                          ; $045a
	lxi d, wPlayer1.PixelX                                          ; $045d

; Jump if player 1's X == $10
	ldax d                                                          ; $0460
	sui $10                                                         ; $0461
	jz @gameDone                                                    ; $0463

; Check if player 2 has won, returning if the X is not $e6
	inr b                                                           ; $0466
	mov a, m                                                        ; $0467
	sui $e6                                                         ; $0468
	rnz                                                             ; $046a

@gameDone:
; A = 0, clear p2 pixel X
	mov m, a                                                        ; $046b
	dcx h                                                           ; $046c

; Clear wPlayer2.DirInputs
	mov m, a                                                        ; $046d
	xchg                                                            ; $046e

; Repeat for p1 pixel X and wPlayer1.DirInputs
	mov m, a                                                        ; $046f
	dcx h                                                           ; $0470
	mov m, a                                                        ; $0471

; Clear seconds passed, set wait timer to get script progressing
	sta wSecondsPassedTimer                                         ; $0472
	mov a, b                                                        ; $0475
	sta wScriptWaitTimer                                            ; $0476
	sta wProcessedGameDone                                          ; $0479

; Jump if player 1 just won
	lxi h, wP1MazesWon                                              ; $047c
	lxi d, wP1JustWon                                               ; $047f
	dcr a                                                           ; $0482
	jz +                                                            ; $0483

; Else operate on wP2MazesWon and wP2JustWon
	inx d                                                           ; $0486
	inx h                                                           ; $0487

; Inc mazes won, and store in 'just won' var to keep it non-0
+	mov a, m                                                        ; $0488
	inr a                                                           ; $0489
	daa                                                             ; $048a
	mov m, a                                                        ; $048b
	stax d                                                          ; $048c

; -1 from mazes left to play, then draw grid circles to show solution
	lxi h, wMazesLeftToPlay                                         ; $048d
	mov a, m                                                        ; $0490
	adi $99                                                         ; $0491
	daa                                                             ; $0493
	jm ScriptCommand0a_DrawGridCircles                              ; $0494

	mov m, a                                                        ; $0497
	jmp ScriptCommand0a_DrawGridCircles                             ; $0498


ProcessDirInputs:
; Bounce check
	in JOY_INPUTS                                                   ; $049b
	mov b, a                                                        ; $049d
	in JOY_INPUTS                                                   ; $049e
	cmp b                                                           ; $04a0
	rnz                                                             ; $04a1

; Set inputs for player 1
	lxi d, wPlayer1.DirInputs                                       ; $04a2
	call UpdateAPlayersDirInputs                                    ; $04a5

; Return if num players == 1
	lda wNumPlayers                                                 ; $04a8
	dcr a                                                           ; $04ab
	rz                                                              ; $04ac

; A = player 2's inputs in low nybble, then set inputs for player 2
	mov a, b                                                        ; $04ad
	rrc                                                             ; $04ae
	rrc                                                             ; $04af
	rrc                                                             ; $04b0
	rrc                                                             ; $04b1
	lxi d, wPlayer2.DirInputs                                       ; $04b2

; A - btns held in low nybble
; DE - addr of player's btns held
UpdateAPlayersDirInputs:
; C = player's buttons held
	ani $0f                                                         ; $04b5
	mov c, a                                                        ; $04b7

; Retain upper bits set, and set new input
	ldax d                                                          ; $04b8
	ani $f0                                                         ; $04b9
	ora c                                                           ; $04bb
	stax d                                                          ; $04bc

@done:
	ret                                                             ; $04bd


ProcessTimersJustDoneHandlers:
; Return if no timers just done, else proceed and clear flag as we are now processing them
	lxi h, wTimersJustDoneBitField                                  ; $04be
	mov a, m                                                        ; $04c1
	ana a                                                           ; $04c2
	rz                                                              ; $04c3

	mvi m, $00                                                      ; $04c4

; For wTimerUntilNextStudyTimeTick, process study timer
	rar                                                             ; $04c6
	push psw                                                        ; $04c7
	cc ProcessStudyTimer                                            ; $04c8
	pop psw                                                         ; $04cb

; For wSecondsPassedTimer, handle things that happen every second
	rar                                                             ; $04cc
	push psw                                                        ; $04cd
	cc ProcessGenericTimer                                          ; $04ce
	pop psw                                                         ; $04d1

; For wScriptWaitTimer, get past script timer we're stuck at
	rar                                                             ; $04d2
	cc IncScriptPointer                                             ; $04d3

; For wTimerUntilScriptChange, set new script addr
	rar                                                             ; $04d6
	cc SwitchToScriptToChangeToAfterTime                            ; $04d7
	ret                                                             ; $04da


ProcessStudyTimer:
; Jump if study time still ticking
	lxi h, wStudyTimeLeft                                           ; $04db
	dcr m                                                           ; $04de
	jnz @studyTimeLeft                                              ; $04df

; As these 2 happen per second, align their occurrence
	mvi a, $01                                                      ; $04e2
	sta wSecondsPassedTimer                                         ; $04e4
	sta wStudyTimeIsDone                                            ; $04e7

; Clear 'STUDY TIME'
	lxi h, Text_Spaces                                              ; $04ea
	lxi d, wVram+NEXT_PIXEL_ROW*213+0                               ; $04ed
	mvi a, $0a                                                      ; $04f0
	call PrintText                                                  ; $04f2

; Print 'TIME'
	lxi h, Text_Time                                                ; $04f5
	lxi d, wVram+NEXT_PIXEL_ROW*213+3                               ; $04f8
	mvi a, _sizeof_Text_Time                                        ; $04fb
	jmp PrintText                                                   ; $04fd

@studyTimeLeft:
; Tick in another second
	mvi a, 60                                                       ; $0500
	sta wTimerUntilNextStudyTimeTick                                ; $0502

; A = char digit, set in HL to print
	mov a, m                                                        ; $0505
	ori CHAR_0                                                      ; $0506
	lxi h, wCharDigitsToProcess                                     ; $0508
	mov m, a                                                        ; $050b

; Print study time left
	mvi a, $01                                                      ; $050c
	lxi d, wVram+NEXT_PIXEL_ROW*213+11                              ; $050e
	jmp PrintText                                                   ; $0511


ProcessGenericTimer:
; This should occur every second
	mvi a, 60                                                       ; $0514
	sta wSecondsPassedTimer                                         ; $0516

; Jump if 2-player time was 4 minutes
	lda w2PlayerGameTimeIs6Mins                                     ; $0519
	ana a                                                           ; $051c
	jz @after2PlayerGameTimeChecks                                  ; $051d

; Sub 1 from seconds, jumping if still positive
	lxi h, wNum2PlayerGameTimeMins+1                                ; $0520
	mov a, m                                                        ; $0523
	adi $99                                                         ; $0524
	daa                                                             ; $0526
	mov m, a                                                        ; $0527
	jp @afterGameOverCheck                                          ; $0528

; If dec'ing from 0 seconds, set to 59, then dec minutes, jumping if still positive
	mvi m, $59                                                      ; $052b
	dcx h                                                           ; $052d
	dcr m                                                           ; $052e
	jp @afterGameOverCheck                                          ; $052f

; Set game over script
	lxi h, Script_GameOver                                          ; $0532
	shld wScriptToStart                                             ; $0535

; Clear all timers
	lxi h, wTimers                                                  ; $0538
	mvi b, wTimersEnd-wTimers                                       ; $053b
	xra a                                                           ; $053d
-	mov m, a                                                        ; $053e
	inx h                                                           ; $053f
	dcr b                                                           ; $0540
	jnz -                                                           ; $0541

; Clear player inputs
	sta wPlayer2.DirInputs                                          ; $0544
	sta wPlayer1.DirInputs                                          ; $0547
	ret                                                             ; $054a

@afterGameOverCheck:
; Print 2-player game time
	lxi h, wVram+NEXT_PIXEL_ROW*213+24                              ; $054b
	lxi d, wNum2PlayerGameTimeMins                                  ; $054e
	call PrintATime                                                 ; $0551

@after2PlayerGameTimeChecks:
; Inc seconds passed, printing if not 60
	lxi h, wInGameTimePassed+1                                      ; $0554
	mov a, m                                                        ; $0557
	inr a                                                           ; $0558
	daa                                                             ; $0559
	mov m, a                                                        ; $055a
	cpi $60                                                         ; $055b
	jnz @printTimePassed                                            ; $055d

; Else clear seconds, inc minutes passed, and then print
	mvi m, $00                                                      ; $0560
	dcx h                                                           ; $0562
	mov a, m                                                        ; $0563
	inr a                                                           ; $0564
	daa                                                             ; $0565
	mov m, a                                                        ; $0566

@printTimePassed:
	lxi h, wVram+NEXT_PIXEL_ROW*213+8                               ; $0567
	lxi d, wInGameTimePassed                                        ; $056a

; DE - src of 2-byte digits
; HL - dest addr
PrintATime:
; Store 1st DE byte's digits in BC
	lxi b, wCharDigitsToProcess                                     ; $056d
	call StoreDEsCharDigitsIntoBC                                   ; $0570

; Follow it up with a colon
	mvi a, CHAR_COLON                                               ; $0573
	stax b                                                          ; $0575
	inx b                                                           ; $0576

; Store 2nd DE byte's digits in BC
	call StoreDEsCharDigitsIntoBC                                   ; $0577

; DE = dest addr, HL points to 1st of 4 char digits. Push for later drawing
	xchg                                                            ; $057a
	lxi h, wCharDigitsToProcess                                     ; $057b
	push h                                                          ; $057e

; Clear either of the 1st 2 digits (bug: 2nd digit could be empty with 1st displaying)
	call ChangeCharToSpaceIf0                                       ; $057f
	inx h                                                           ; $0582
	call ChangeCharToSpaceIf0                                       ; $0583

; Draw the 4 digits with colon in between
	pop h                                                           ; $0586
	mvi a, $05                                                      ; $0587
	jmp PrintText                                                   ; $0589


; HL - pointer to a char digit
ChangeCharToSpaceIf0:
	mov a, m                                                        ; $058c
	cpi CHAR_0                                                      ; $058d
	rnz                                                             ; $058f

	mvi m, CHAR_SPACE                                               ; $0590
	ret                                                             ; $0592


IncScriptPointer:
	lhld wScriptPointer                                             ; $0593
	inx h                                                           ; $0596
	shld wScriptPointer                                             ; $0597
	ret                                                             ; $059a


SwitchToScriptToChangeToAfterTime:
	lhld wScriptToChangeToAfterTime                                 ; $059b
	shld wScriptToStart                                             ; $059e
	ret                                                             ; $05a1


ProcessCoinage:
; C = misc input, B = coin input
	lxi h, wLastInputfCoinValue                                     ; $05a2
	in MISC_INPUTS                                                  ; $05a5
	mov c, a                                                        ; $05a7
	ani INPUTF_COIN                                                 ; $05a8
	mov b, a                                                        ; $05aa

; Return if coin input is the same as it was last frame
	xra m                                                           ; $05ab
	rz                                                              ; $05ac

; Set new last input coin value, return if it was 0
	mov m, b                                                        ; $05ad
	mov a, b                                                        ; $05ae
	ana a                                                           ; $05af
	rz                                                              ; $05b0

; Inc num coins
	out COIN_COUNTER                                                ; $05b1
	lxi h, wNumCoins                                                ; $05b3
	inr m                                                           ; $05b6

; The ani == 1 if INPUTF_2C_1C/INPUTF_2C_3C
	mov a, c                                                        ; $05b7
	rar                                                             ; $05b8
	rar                                                             ; $05b9
	rar                                                             ; $05ba
	rar                                                             ; $05bb
	ani $01                                                         ; $05bc

; Return if coinage option >= num coins, else clear num coins
	cmp m                                                           ; $05be
	rp                                                              ; $05bf

	mvi m, $00                                                      ; $05c0

; Inc num credits, as all opts are at least _1C
	lxi h, wNumCredits                                              ; $05c2
	inr m                                                           ; $05c5

; Jump if INPUTF_1C_1C/INPUTF_2C_1C
	mov a, c                                                        ; $05c6
	ani $20                                                         ; $05c7
	jz @afterNumCredits                                             ; $05c9

	inr m                                                           ; $05cc

; With m = 1, jump if INPUTF_1C_2C
	mov a, c                                                        ; $05cd
	ani $10                                                         ; $05ce
	jz @afterNumCredits                                             ; $05d0

; Else it's INPUTF_2C_3C, continue with m = 2
	inr m                                                           ; $05d3

@afterNumCredits:
; Use up a credit if we just game-overed
	lda wIsNotGameOvered                                            ; $05d4
	ana a                                                           ; $05d7
	rnz                                                             ; $05d8

ScriptCommand11_CreditUsedUp:
; Return if 0 credits, else dec it
	lxi h, wNumCredits                                              ; $05d9
	xra a                                                           ; $05dc
	cmp m                                                           ; $05dd
	rz                                                              ; $05de

	dcr m                                                           ; $05df

; Reset mazes left, and set that we've not game-overed
	mvi a, $03                                                      ; $05e0
	sta wMazesLeftToPlay                                            ; $05e2
	sta wIsNotGameOvered                                            ; $05e5

; Set new script, and print wait text as the script will load a new game
	lxi h, Script_PressToStart1or2Player                            ; $05e8
	shld wScriptToStart                                             ; $05eb

PrintWaitText:
	lxi h, Text_Wait                                                ; $05ee
	lxi d, wVram+NEXT_PIXEL_ROW*213+3                               ; $05f1
	mvi a, _sizeof_Text_Wait                                        ; $05f4
	jmp PrintText                                                   ; $05f6


ProcessStartInputs:
; Return if not ready to accept start btns
	lxi d, wReadyToAcceptStartBtns                                  ; $05f9
	ldax d                                                          ; $05fc
	ana a                                                           ; $05fd
	rz                                                              ; $05fe

; B = misc inputs
	in MISC_INPUTS                                                  ; $05ff
	mov b, a                                                        ; $0601

; If start 1 pressed, jump with this script, and A=1
	lxi h, Script_1Player3MazesOrPlayAsLong                         ; $0602
	ani INPUTF_START1                                               ; $0605
	mvi a, $01                                                      ; $0607
	jnz @afterScriptChosen                                          ; $0609

; Else if start 2 pressed, continue with this script, and A=2
	lxi h, Script_2Player3Mazes                                     ; $060c
	mov a, b                                                        ; $060f
	ani INPUTF_START2                                               ; $0610
	mvi a, $02                                                      ; $0612
	rz                                                              ; $0614

@afterScriptChosen:
; Set num players and script to start executing
	sta wNumPlayers                                                 ; $0615
	shld wScriptToStart                                             ; $0618

; Clear wReadyToAcceptStartBtns
	xra a                                                           ; $061b
	stax d                                                          ; $061c
	ret                                                             ; $061d


; Called mid-frame and in vblank
UpdatePlayersDisplayOnScreen:
; Undraw both players
	lxi h, wPlayer2.DirInputs                                       ; $061e
	push h                                                          ; $0621
	call UndrawPlayer                                               ; $0622
	lxi h, wPlayer1.DirInputs                                       ; $0625
	push h                                                          ; $0628
	call UndrawPlayer                                               ; $0629

; Re-draw players
	pop h                                                           ; $062c
	call DrawPlayer                                                 ; $062d
	pop h                                                           ; $0630
	jmp DrawPlayer                                                  ; $0631


; BC - upper, then lower nybble of DE
StoreDEsCharDigitsIntoBC:
; Convert high nybble into digit char
	ldax d                                                          ; $0634
	rar                                                             ; $0635
	rar                                                             ; $0636
	rar                                                             ; $0637
	rar                                                             ; $0638
	ani $0f                                                         ; $0639
	adi CHAR_0                                                      ; $063b

; Store in BC
	stax b                                                          ; $063d
	inx b                                                           ; $063e

; Repeat with low nybble
	ldax d                                                          ; $063f
	inx d                                                           ; $0640
	ani $0f                                                         ; $0641
	adi CHAR_0                                                      ; $0643

; Store and inc BC
	stax b                                                          ; $0645
	inx b                                                           ; $0646
	ret                                                             ; $0647


; HL - pointer to a player's dir inputs
DrawPlayer:
; Only process on the same interrupt each frame
	lda wInterruptHandlerToIgnore                                   ; $0648
	xra m                                                           ; $064b
	ani $10                                                         ; $064c
	rnz                                                             ; $064e

; Return if player input bit 7 clear (player can't move)
	mov a, m                                                        ; $064f
	ana a                                                           ; $0650
	rp                                                              ; $0651

; B = player input with bit 5 set (player is being drawn)
	ori $20                                                         ; $0652
	mov b, a                                                        ; $0654

; If player input bit 6 clear, clear the above. Update player's dir inputs
	ani $40                                                         ; $0655
	jnz +                                                           ; $0657
	mvi b, $00                                                      ; $065a
+	mov m, b                                                        ; $065c
	inx h                                                           ; $065d

; E = player x, D = player y
	mov e, m                                                        ; $065e
	inx h                                                           ; $065f
	mov d, m                                                        ; $0660
	inx h                                                           ; $0661

; Low 3 bits of E is the pixel shift, higher bits of DE = vram address of it
	mov a, e                                                        ; $0662
	ani $07                                                         ; $0663
	sta wPlayerPixelShift                                           ; $0665
	call DEequByteOffsetIntoScreen                                  ; $0668

; BC = eg wPlayer1.TileDataSrc
	mov c, m                                                        ; $066b
	inx h                                                           ; $066c
	mov b, m                                                        ; $066d
	inx h                                                           ; $066e

; Store vram address in eg wPlayer1.StartingVramLoc
	mov m, e                                                        ; $066f
	inx h                                                           ; $0670
	mov m, d                                                        ; $0671
	inx h                                                           ; $0672

; DE = eg wPlayer1.TileDataWithoutPlayer, HL = vram address of player
	xchg                                                            ; $0673

; Draw 5 lines for the player
	mvi a, _sizeof_TileData_SquareWithDot                           ; $0674

@nextLine:
	push psw                                                        ; $0676

; Store curr tile data in eg wPlayer1.TileDataWithoutPlayer
	mov a, m                                                        ; $0677
	stax d                                                          ; $0678
	inx d                                                           ; $0679

; A = tile data byte, tile data src += 1
	ldax b                                                          ; $067a
	inx b                                                           ; $067b

; Draw in left part of player tile data
	call DrawShiftedInPlayerTileData                                ; $067c
	ora m                                                           ; $067f
	mov m, a                                                        ; $0680

; HL points to next col, store curr tile data in eg wPlayer1.TileDataWithoutPlayer+1
	inx h                                                           ; $0681
	mov a, m                                                        ; $0682
	stax d                                                          ; $0683
	inx d                                                           ; $0684

; Shift in 0, to draw right part of player tile data
	xra a                                                           ; $0685
	call DrawShiftedInPlayerTileData                                ; $0686
	ora m                                                           ; $0689
	mov m, a                                                        ; $068a

; Player vram address up a pixel row
	push d                                                          ; $068b
	lxi d, NEXT_PIXEL_ROW-1                                         ; $068c
	dad d                                                           ; $068f
	pop d                                                           ; $0690

; To next tile data line
	pop psw                                                         ; $0691
	dcr a                                                           ; $0692
	jnz @nextLine                                                   ; $0693

	ret                                                             ; $0696


; A - player tile data
DrawShiftedInPlayerTileData:
	push h                                                          ; $0697

; Get prev tile data in L, then new tile data in H
	lhld wPrevPlayerTileDataBytes                                   ; $0698
	mov l, h                                                        ; $069b
	mov h, a                                                        ; $069c
	shld wPrevPlayerTileDataBytes                                   ; $069d

; HL << shift val. Because bits are drawn left to right, low bit to high bit,
; This moves the player right as X grows
	lda wPlayerPixelShift                                           ; $06a0
	ana a                                                           ; $06a3
	jz @end                                                         ; $06a4

-	dad h                                                           ; $06a7
	dcr a                                                           ; $06a8
	jnz -                                                           ; $06a9

@end:
; Return tile data in A
	mov a, h                                                        ; $06ac
	pop h                                                           ; $06ad
	ret                                                             ; $06ae


; HL - pointer to a player's dir inputs
UndrawPlayer:
; Only process on the same interrupt each frame
	lda wInterruptHandlerToIgnore                                   ; $06af
	xra m                                                           ; $06b2
	ani $10                                                         ; $06b3
	rnz                                                             ; $06b5

; Return if player input bit 5 clear (player is not being drawn)
	mov a, m                                                        ; $06b6
	ani $20                                                         ; $06b7
	rz                                                              ; $06b9

; HL points to player's vram loc, DE = that loc
	lxi b, wPlayer1.StartingVramLoc-wPlayer1.DirInputs              ; $06ba
	dad b                                                           ; $06bd

	mov e, m                                                        ; $06be
	inx h                                                           ; $06bf
	mov d, m                                                        ; $06c0
	inx h                                                           ; $06c1

; DE = eg wPlayer1.TileDataWithoutPlayer, HL = player's vram loc
	xchg                                                            ; $06c2

; Draw 5 lines for the player
	mvi c, _sizeof_TileData_SquareWithDot                           ; $06c3

@nextLine:
; Replace tile data with tile data without player
	ldax d                                                          ; $06c5
	inx d                                                           ; $06c6
	mov m, a                                                        ; $06c7
	inx h                                                           ; $06c8

	ldax d                                                          ; $06c9
	inx d                                                           ; $06ca
	mov m, a                                                        ; $06cb

; Player vram address up a pixel row
	mov a, c                                                        ; $06cc
	mvi c, NEXT_PIXEL_ROW-1                                         ; $06cd
	dad b                                                           ; $06cf
	mov c, a                                                        ; $06d0

	dcr c                                                           ; $06d1
	jnz @nextLine                                                   ; $06d2

	ret                                                             ; $06d5


; DE = pixel location of tile, left->right, top->bottom
DEequByteOffsetIntoScreen:
; DE >> 3, ie DE /= 8
	mvi b, $03                                                      ; $06d6

@nextHalf:
	xra a                                                           ; $06d8

	mov a, d                                                        ; $06d9
	rar                                                             ; $06da
	mov d, a                                                        ; $06db

	mov a, e                                                        ; $06dc
	rar                                                             ; $06dd
	mov e, a                                                        ; $06de

	dcr b                                                           ; $06df
	jnz @nextHalf                                                   ; $06e0

; DE = offset into vram
	mov a, d                                                        ; $06e3
	adi >wVram                                                      ; $06e4
	mov d, a                                                        ; $06e6
	ret                                                             ; $06e7


ShuffleRNG:
; Loop this many times
	lda wTimesToShuffleRNG                                          ; $06e8

@loop:
	push psw                                                        ; $06eb
	call AequRandomNumber                                           ; $06ec
	pop psw                                                         ; $06ef

	dcr a                                                           ; $06f0
	jnz @loop                                                       ; $06f1

	ret                                                             ; $06f4


; Returns B = starting col
; Returns C = starting row
SetGameGridLeftExitPoint:
; Get a random val and set some vars and C to that tile Y
	mvi e, GRID_TILE_HEIGHT                                         ; $06f5
	call AequETimesRandomNumDiv100h                                 ; $06f7
	sta wInitTileYtoSetForRightArrow                                ; $06fa
	sta wInitRowToSetForAI                                          ; $06fd
	mov c, a                                                        ; $0700

; Clear col and B
	xra a                                                           ; $0701
	sta wInitColToSetForAI                                          ; $0702
	mov b, a                                                        ; $0705

; For that left exit point, set bits 0 (to be processed as part of setting up game grid),
; and 3 (part of the solution)
	call HLpointsToGameGridColBRowC                                 ; $0706
	mov a, m                                                        ; $0709
	ori $09                                                         ; $070a
	mov m, a                                                        ; $070c
	ret                                                             ; $070d


; B - game grid col from left
; C - game grid row from bottom
; Returns bits 0-3 set in D for neighbors with bit 0 clear
EisNumNeighborsWithBit0Clear:
; D to have return value described above
	mvi d, $00                                                      ; $070e

; Skip below if we're at the leftmost col
	mov a, b                                                        ; $0710
	cpi $00                                                         ; $0711
	jz @checkRightNeighbor                                          ; $0713

; HL = game grid to the left
	dcr b                                                           ; $0716
	call HLpointsToGameGridColBRowC                                 ; $0717
	inr b                                                           ; $071a

; If bit 0 clear on neighbor, set bit 0 on D
	mov a, m                                                        ; $071b
	rrc                                                             ; $071c
	jc @checkRightNeighbor                                          ; $071d

	mov a, d                                                        ; $0720
	ori $01                                                         ; $0721
	mov d, a                                                        ; $0723

@checkRightNeighbor:
; Jump if we're not at the rightmost col
	mvi a, GRID_TILE_WIDTH-1                                        ; $0724
	cmp b                                                           ; $0726
	jnz @isNotRightmost                                             ; $0727

; If genning happy path still...
	lda wCurrGameGridByteIsNotInSolution                            ; $072a
	ora a                                                           ; $072d
	jnz @checkBottomNeighbor                                        ; $072e

; And we've set walls 70+ times, consider that the right neighbor is done
; Coerces wall setting to try and move right
	lda wNumTimesSettingWallsForHappyPath                           ; $0731
	cpi $46                                                         ; $0734
	jc @checkBottomNeighbor                                         ; $0736

	jmp @setBit1                                                    ; $0739

@isNotRightmost:
; HL = game grid to the right
	inr b                                                           ; $073c
	call HLpointsToGameGridColBRowC                                 ; $073d
	dcr b                                                           ; $0740

; If bit 0 clear on neighbor, set bit 1 on D
	mov a, m                                                        ; $0741
	rrc                                                             ; $0742
	jc @checkBottomNeighbor                                         ; $0743

@setBit1:
	mov a, d                                                        ; $0746
	ori $02                                                         ; $0747
	mov d, a                                                        ; $0749

@checkBottomNeighbor:
; Skip below if we're at the bottommost row
	mov a, c                                                        ; $074a
	cpi $00                                                         ; $074b
	jz @checkTopNeighbor                                            ; $074d

; HL = game grid below
	dcr c                                                           ; $0750
	call HLpointsToGameGridColBRowC                                 ; $0751
	inr c                                                           ; $0754

; If bit 0 clear on neighbor, set bit 2 on D
	mov a, m                                                        ; $0755
	rrc                                                             ; $0756
	jc @checkTopNeighbor                                            ; $0757

	mov a, d                                                        ; $075a
	ori $04                                                         ; $075b
	mov d, a                                                        ; $075d

@checkTopNeighbor:
; Skip below if we're at the topmost row
	mvi a, GRID_TILE_HEIGHT-1                                       ; $075e
	cmp c                                                           ; $0760
	jz @returnNeighbors                                             ; $0761

; HL = game grid above
	inr c                                                           ; $0764
	call HLpointsToGameGridColBRowC                                 ; $0765
	dcr c                                                           ; $0768

; If bit 0 clear on neighbor, set bit 3 on D
	mov a, m                                                        ; $0769
	rrc                                                             ; $076a
	jc @returnNeighbors                                             ; $076b

	mov a, d                                                        ; $076e
	ori $08                                                         ; $076f
	mov d, a                                                        ; $0771

@returnNeighbors:
; Count neighbors in E with bit 0 clear
	mvi e, $00                                                      ; $0772
	mov a, d                                                        ; $0774
	ora a                                                           ; $0775

@nextNeighborBit:
; For every bit set (neighbour found with bit 0 clear in direction), E += 1
	rar                                                             ; $0776
	jnc +                                                           ; $0777
	inr e                                                           ; $077a
+	ora a                                                           ; $077b
	jnz @nextNeighborBit                                            ; $077c

	ret                                                             ; $077f


; B - game grid col from left
; C - game grid row from bottom
; D - bits 0-3 set for neighbors bit 0 clear (0-left, 1-right, 2-down, 3-up)
; E - num neighbors with bit 0 clear
; How this works:
;   From D, we understand which grid cells we can move to (haven't tried to expand to it yet)
;   From E, we have a count
;   A value is picked from 0 to E-1, which tells us which of D we want to move to
;   Below checks then have player clear curr cell bit 0 (not pending, we can move into it),
;     move to an adjacent cell, and set its bit 0 (pending),
;     creating some walls around curr cell and next cell in the process
;   In the diagrams, x is curr cell, y is new cell
SetSomeGridWallsAroundCurrLoc:
; If still genning happy path, inc num times var below
	lda wCurrGameGridByteIsNotInSolution                            ; $0780
	ana a                                                           ; $0783
	jnz +                                                           ; $0784

	lxi h, wNumTimesSettingWallsForHappyPath                        ; $0787
	inr m                                                           ; $078a

; Set that we've just set some walls as part of this func
+	mvi a, $01                                                      ; $078b
	sta wJustSetSomeWalls                                           ; $078d

; E = a random val up to num neighbors done-1, A = bits set for neighbors done
	call AequETimesRandomNumDiv100h                                 ; $0790
	mov e, a                                                        ; $0793
	mov a, d                                                        ; $0794

; Jump if left neighbor still pending
; Else if E = 0,
; _
; yx
; Else E -= 1 (not the attempt we want to make)
	inr e                                                           ; $0795
	dcr e                                                           ; $0796
	rrc                                                             ; $0797
	jnc @leftNeighborNotDone                                        ; $0798

	jz @moveLeftSetNorthWall                                        ; $079b

	dcr e                                                           ; $079e

@leftNeighborNotDone:
; Jump if right neighbor still pending
; Else if E = 0,
; __
; xy|
; Else E -= 1 (not the attempt we want to make)
	rrc                                                             ; $079f
	jnc @rightNeighborNotDone                                       ; $07a0

	jz @setNorthWallHereMoveRightSetBothWalls                       ; $07a3

	dcr e                                                           ; $07a6

@rightNeighborNotDone:
; If bottom neighbor still pending, or E is non-0 (the attempt we want to make),
; _
; y|
; x|
; Else if E = 0, (bottom is the attempt we want to make)
; x
; y|
	rrc                                                             ; $07a7
	jnc @setEastWallHereMoveUpSetBothWalls                          ; $07a8

	jz @moveDownSetEastWall                                         ; $07ab

	jmp @setEastWallHereMoveUpSetBothWalls                          ; $07ae

@moveLeftSetNorthWall:
; Bit 0 set (neighbor pending)
	dcr b                                                           ; $07b1
	call HLpointsToGameGridColBRowC                                 ; $07b2
	mvi d, $05                                                      ; $07b5
	jmp SetPendingGameGridByte                                      ; $07b7

@setNorthWallHereMoveRightSetBothWalls:
; Set north wall at this cell, bit 0 clear (this cell done)
	call HLpointsToGameGridColBRowC                                 ; $07ba
	mvi d, $04                                                      ; $07bd
	call SetPendingGameGridByte                                     ; $07bf

; Jump if eastmost grid col
	mvi a, GRID_TILE_WIDTH-1                                        ; $07c2
	cmp b                                                           ; $07c4
	jz @isEastMostGridCol                                           ; $07c5

; Move right, set both walls to cell to the right, bit 0 set (neighbor pending)
	inr b                                                           ; $07c8
	call HLpointsToGameGridColBRowC                                 ; $07c9
	mvi d, $01                                                      ; $07cc
	jmp SetPendingGameGridByte                                      ; $07ce

@isEastMostGridCol:
; If we're still genning the happy path...
	lda wCurrGameGridByteIsNotInSolution                            ; $07d1
	ana a                                                           ; $07d4
	jnz @end                                                        ; $07d5

; Set that everything else is unhappy...
	mvi a, $08                                                      ; $07d8
	sta wCurrGameGridByteIsNotInSolution                            ; $07da

; Current Y is where we draw the left arro
	mov a, c                                                        ; $07dd
	sta wInitTileYtoSetForLeftArrow                                 ; $07de

@end:
; Return position as being by the left arrow
	mvi b, GRID_TILE_WIDTH-1                                        ; $07e1
	lda wInitTileYtoSetForLeftArrow                                 ; $07e3
	mov c, a                                                        ; $07e6
	ret                                                             ; $07e7

@moveDownSetEastWall:
; Bit 0 set (neighbor pending)
	dcr c                                                           ; $07e8
	call HLpointsToGameGridColBRowC                                 ; $07e9
	mvi d, $03                                                      ; $07ec
	jmp SetPendingGameGridByte                                      ; $07ee


.org $7f3

@setEastWallHereMoveUpSetBothWalls:
; Set east wall at this cell, bit 0 clear (this cell done)
	call HLpointsToGameGridColBRowC                                 ; $07f3
	mvi d, $02                                                      ; $07f6
	call SetPendingGameGridByte                                     ; $07f8

; Set east+north walls on cell above, bit 0 set (neighbor pending)
	inr c                                                           ; $07fb
	call HLpointsToGameGridColBRowC                                 ; $07fc
	mvi d, $01                                                      ; $07ff
	jmp SetPendingGameGridByte                                      ; $0801


; D - game grid bits 0-2
; HL - points to a game grid cell
SetPendingGameGridByte:
; If 0, it's part of the path solution
	lda wCurrGameGridByteIsNotInSolution                            ; $0804
	xri $08                                                         ; $0807

; Set other low nybble bits
	ora m                                                           ; $0809
	ora d                                                           ; $080a
	mov m, a                                                        ; $080b
	ret                                                             ; $080c


; B - game grid col from left
; C - game grid row from bottom
; Returns with carry set if any bit 0s set
; If above set, returns with B & C set to pending position
RetZIfReachedEndOfGridWithNoNewWallsSet:
@nextRow:
; Inc row, jumping if we're past the last
	inr c                                                           ; $080d
	mvi a, GRID_TILE_HEIGHT                                         ; $080e
	cmp c                                                           ; $0810
	jz @endOfCol                                                    ; $0811

@nextGameGridByte:
; Get game grid byte, return with carry set if bit 0 set (pending)
	call HLpointsToGameGridColBRowC                                 ; $0814
	mov a, m                                                        ; $0817
	rrc                                                             ; $0818
	jnc @nextRow                                                    ; $0819

	ret                                                             ; $081c

@endOfCol:
; Inc col, and reset row
	mvi c, $00                                                      ; $081d
	inr b                                                           ; $081f

; Jump if not the last col
	mvi a, GRID_TILE_WIDTH                                          ; $0820
	cmp b                                                           ; $0822
	jnz @nextGameGridByte                                           ; $0823

; We're done, set col back to 0, return if flag reset below, else...
	mvi b, $00                                                      ; $0826
	lda wJustSetSomeWalls                                           ; $0828
	ora a                                                           ; $082b
	rz                                                              ; $082c

; Re-process game grid bytes to catch those before our current grid cell
	mvi a, $00                                                      ; $082d
	sta wJustSetSomeWalls                                           ; $082f
	jmp @nextGameGridByte                                           ; $0832


ScriptCommand03_DrawGameGridAndArrows:
; HL points to bottom of the left grid line
	lxi h, wVram+NEXT_PIXEL_ROW*208+2                               ; $0835
	mvi d, $00                                                      ; $0838

@nextLeftLine:
; Default load an east line, jumping if we are not at the right arrow's Y
	lda wRightArrowTileY                                            ; $083a
	lxi b, TileData_EastLine                                        ; $083d
	cmp d                                                           ; $0840
	jnz +                                                           ; $0841

; Once we are at its Y, draw a right arrow, and prevent drawing an east line
	call DrawRightArrow                                             ; $0844
	lxi b, TileData_Space                                           ; $0847

+	call DrawGridTileUpwards                                        ; $084a

; +$100 to go to next tile row, stop once all walls done
	inr d                                                           ; $084d
	mvi a, GRID_TILE_HEIGHT                                         ; $084e
	cmp d                                                           ; $0850
	jnz @nextLeftLine                                               ; $0851

; HL points to pixel row under bottom-left of game grid
	lxi h, wVram+NEXT_PIXEL_ROW*209+3                               ; $0854
	lxi d, wGameGrid                                                ; $0857
	mvi b, GRID_TILE_WIDTH                                          ; $085a

@nextColumn:
; Loop through entire grid height
	mvi c, GRID_TILE_HEIGHT                                         ; $085c
	push h                                                          ; $085e

; Start off with a south line, then go up a pixel row
	push b                                                          ; $085f
	mvi m, $ff                                                      ; $0860
	lxi b, -NEXT_PIXEL_ROW                                          ; $0862
	dad b                                                           ; $0865
	pop b                                                           ; $0866

@nextRow:
	push b                                                          ; $0867

; Get byte from ram, if bit 6 clear, draw an east line
	ldax d                                                          ; $0868
	lxi b, TileData_EastLine                                        ; $0869
	ani $40                                                         ; $086c
	jz +                                                            ; $086e
	lxi b, TileData_Space                                           ; $0871
+	push h                                                          ; $0874
	call DrawGridTileUpwards                                        ; $0875
	pop h                                                           ; $0878

; Get same byte from ram, if bit 5 clear, draw a north line
	ldax d                                                          ; $0879
	inx d                                                           ; $087a
	lxi b, TileData_SouthLine                                       ; $087b
	ani $20                                                         ; $087e
	jz +                                                            ; $0880
	lxi b, TileData_Space                                           ; $0883
+	call DrawGridTileUpwards                                        ; $0886

; To next row
	pop b                                                           ; $0889
	dcr c                                                           ; $088a
	jnz @nextRow                                                    ; $088b

; HL += 1 to do next column
	pop h                                                           ; $088e
	inx h                                                           ; $088f
	dcr b                                                           ; $0890
	jnz @nextColumn                                                 ; $0891

; With HL pointing to bottom right, -$100 to go to prev tile row, until at tile Y
	lda wLeftArrowTileY                                             ; $0894
	inr h                                                           ; $0897

-	dcr h                                                           ; $0898
	dcr a                                                           ; $0899
	jp -                                                            ; $089a

; Finally draw the left arrow
	lxi b, TileData_LeftArrow                                       ; $089d
	jmp DrawGridTileUpwards                                         ; $08a0


; HL - dest addr of bottom of arrow
DrawRightArrow:
	push h                                                          ; $08a3
	lxi b, TileData_RightArrow                                      ; $08a4
	call DrawGridTileUpwards                                        ; $08a7
	pop h                                                           ; $08aa
	ret                                                             ; $08ab


ScriptCommand0a_DrawGridCircles:
; HL points to bottom-left of game grid, loop through all cols
	lxi h, wVram+NEXT_PIXEL_ROW*208+3                               ; $08ac
	lxi d, wGameGrid                                                ; $08af
	mvi b, GRID_TILE_WIDTH                                          ; $08b2

@nextCol:
; Loop through all tile rows in col
	mvi c, GRID_TILE_HEIGHT                                         ; $08b4
	push h                                                          ; $08b6

@nextRow:
	push b                                                          ; $08b7

; If bit 7 set on game grid byte (AI traversed it), draw a small circle
	ldax d                                                          ; $08b8
	inx d                                                           ; $08b9
	lxi b, TileData_SmallCircle                                     ; $08ba
	ani $80                                                         ; $08bd
	jnz +                                                           ; $08bf
	lxi b, TileData_Space                                           ; $08c2
+	call DrawGridTileUpwards                                        ; $08c5

; To next row
	pop b                                                           ; $08c8
	dcr c                                                           ; $08c9
	jnz @nextRow                                                    ; $08ca

; HL += 1 to get to next col
	pop h                                                           ; $08cd
	inx h                                                           ; $08ce
	dcr b                                                           ; $08cf
	jnz @nextCol                                                    ; $08d0

; Print wait text if new game grid not loaded yet
	lda wGameGridLoaded                                             ; $08d3
	ana a                                                           ; $08d6
	jz PrintWaitText                                                ; $08d7

	ret                                                             ; $08da


; BC - src addr of bottom of 8-byte tile
; HL - dest addr of bottom of grid tile
DrawGridTileUpwards:
	push d                                                          ; $08db

; Loop through 8 rows
	mvi e, $08                                                      ; $08dc

@nextPixelRow:
; Draw byte in src BC, onto dest HL
	ldax b                                                          ; $08de
	inx b                                                           ; $08df
	ora m                                                           ; $08e0
	mov m, a                                                        ; $08e1

;Ppoint dest to pixel row above
	push d                                                          ; $08e2
	lxi d, -NEXT_PIXEL_ROW                                          ; $08e3
	dad d                                                           ; $08e6
	pop d                                                           ; $08e7

; To next row
	dcr e                                                           ; $08e8
	jnz @nextPixelRow                                               ; $08e9

	pop d                                                           ; $08ec
	ret                                                             ; $08ed


MemClear200hAFromRamEnd:
; Preserve return addr
	di                                                              ; $08ee
	pop h                                                           ; $08ef

; Push 2 0's in BC, A*$100 times
	lxi b, $0000                                                    ; $08f0
	lxi d, $0000                                                    ; $08f3
	lxi sp, wRamEnd                                                 ; $08f6

@nextBytePair:
	push b                                                          ; $08f9
	inx d                                                           ; $08fa
	cmp d                                                           ; $08fb
	jnz @nextBytePair                                               ; $08fc

; Assume we're at the top of stack before this, and jump to return addr
	lxi sp, wStackTop                                               ; $08ff
	pchl                                                            ; $0902


; ie A is [0, E-1]
AequETimesRandomNumDiv100h:
; A = random num
	push b                                                          ; $0903
	call AequRandomNumber                                           ; $0904

; Loop E-1 times, below loop does A+A*(E-1)
	mov c, a                                                        ; $0907
	mvi b, $00                                                      ; $0908

@nextAdd:
	dcr e                                                           ; $090a
	jz @end                                                         ; $090b

; Add BC
	add c                                                           ; $090e
	jnc @nextAdd                                                    ; $090f

	inr b                                                           ; $0912
	jmp @nextAdd                                                    ; $0913

@end:
; Return high byte in A
	mov a, b                                                        ; $0916
	pop b                                                           ; $0917
	ret                                                             ; $0918


AequRandomNumber:
	push h                                                          ; $0919
	push b                                                          ; $091a

; Loop 8 times, get 1st random byte
	lxi h, wRNGVars                                                 ; $091b
	mvi b, $08                                                      ; $091e
	mov a, m                                                        ; $0920

@loopB:
; Swap low 3 bits and upper 5 bits
	rlc                                                             ; $0921
	rlc                                                             ; $0922
	rlc                                                             ; $0923

; Flip against itself, and rotate left twice
	xra m                                                           ; $0924
	ral                                                             ; $0925
	ral                                                             ; $0926

; Rotate the 4 rng vars left
	lxi h, wRNGVars                                                 ; $0927
	mov a, m                                                        ; $092a
	ral                                                             ; $092b
	mov m, a                                                        ; $092c
	inx h                                                           ; $092d

	mov a, m                                                        ; $092e
	ral                                                             ; $092f
	mov m, a                                                        ; $0930
	inx h                                                           ; $0931

	mov a, m                                                        ; $0932
	ral                                                             ; $0933
	mov m, a                                                        ; $0934
	inx h                                                           ; $0935

	mov a, m                                                        ; $0936
	ral                                                             ; $0937
	mov m, a                                                        ; $0938

; Loop again, returning the 4th byte in A once done
	dcr b                                                           ; $0939
	jnz @loopB                                                      ; $093a

	pop b                                                           ; $093d
	pop h                                                           ; $093e
	ret                                                             ; $093f


; B - col idx from left
; C - row idx from bottom
HLpointsToGameGridColBRowC:
	push d                                                          ; $0940
	mvi e, <GRID_TILE_HEIGHT                                        ; $0941
	mvi d, $00                                                      ; $0943
	lxi h, $0000                                                    ; $0945

; A = col idx
	mov a, b                                                        ; $0948
	push b                                                          ; $0949

; Loop 8 times (all bits of A). The loop does A*DE
	mvi b, $09                                                      ; $094a

@multLoop:
	dcr b                                                           ; $094c
	jz @end                                                         ; $094d

; Shift HL left, rotate any carries into A. If carry on A...
	dad h                                                           ; $0950
	ral                                                             ; $0951
	jnc @multLoop                                                   ; $0952

; Add DE
	dad d                                                           ; $0955
	jmp @multLoop                                                   ; $0956

@end:
	pop b                                                           ; $0959

; HL += C (row idx)
	mov e, c                                                        ; $095a
	dad d                                                           ; $095b

; HL to point to game grid byte to set
	lxi d, wGameGrid                                                ; $095c
	dad d                                                           ; $095f
	pop d                                                           ; $0960
	ret                                                             ; $0961


; HL - pointer to player's inputs
UpdatePlayerFromInputsHeld:
; Return if player input bit 7 clear (can't move)
	mov a, m                                                        ; $0962
	ana a                                                           ; $0963
	rp                                                              ; $0964

; E = wPlayer1.PixelX, D = wPlayer1.PixelY
	push h                                                          ; $0965
	inx h                                                           ; $0966
	mov e, m                                                        ; $0967
	inx h                                                           ; $0968
	mov d, m                                                        ; $0969

; Call handlers based on buttons held
	rrc                                                             ; $096a
	push psw                                                        ; $096b
	cc HandlePlayersLeftHeld                                        ; $096c
	pop psw                                                         ; $096f

	rrc                                                             ; $0970
	push psw                                                        ; $0971
	cc HandlePlayersRightHeld                                       ; $0972
	pop psw                                                         ; $0975

	rrc                                                             ; $0976
	push psw                                                        ; $0977
	cc HandlePlayersDownHeld                                        ; $0978
	pop psw                                                         ; $097b

	rrc                                                             ; $097c
	cc HandlePlayersUpHeld                                          ; $097d

; Return if reached the exit
	pop h                                                           ; $0980
	mov a, e                                                        ; $0981
	cpi $0f                                                         ; $0982
	rz                                                              ; $0984

; D = pixel y, B has bit 4 set if before midframe interrupt Y
	mov a, d                                                        ; $0985
	ldbc $00, $ff-$10                                               ; $0986
	cpi $60                                                         ; $0989
	jnc +                                                           ; $098b
	mvi b, $10                                                      ; $098e

; HL = player controls, set bit 4 if pixel Y < $60
+	mov a, m                                                        ; $0990
	ana c                                                           ; $0991
	ora b                                                           ; $0992
	mov m, a                                                        ; $0993

; Save eg to wPlayer1.PixelX and wPlayer1.PixelY
	inx h                                                           ; $0994
	mov m, e                                                        ; $0995
	inx h                                                           ; $0996
	mov m, d                                                        ; $0997
	ret                                                             ; $0998


; D - player pixel Y
; E - player pixel X
HandlePlayersLeftHeld:
; This func can have us exit this func. Jump if we can't also move vertically
	call ChecksForPlayerMovingHoriz                                 ; $0999
	jnz @moveLeft                                                   ; $099c

; -1 to check west wall. If on the leftmost column...
	call ConvertPlayerPixelPosIntoGameGridCoords                    ; $099f
	dcr b                                                           ; $09a2
	jp @checkWall                                                   ; $09a3

; If we have the same Y as the right arrow, allow movement, else return
	lda wRightArrowTileY                                            ; $09a6
	cmp c                                                           ; $09a9
	rnz                                                             ; $09aa

	jmp @moveLeft                                                   ; $09ab

@checkWall:
; If bit 6 of game grid clear (there is an east wall), return
	call HLpointsToGameGridColBRowC                                 ; $09ae
	mov a, m                                                        ; $09b1
	ani $40                                                         ; $09b2
	rz                                                              ; $09b4

@moveLeft:
	dcr e                                                           ; $09b5
	ret                                                             ; $09b6


; D - player pixel Y
; E - player pixel X
HandlePlayersRightHeld:
; This func can have us exit this func. Jump if we can't also move vertically
	call ChecksForPlayerMovingHoriz                                 ; $09b7
	jnz @moveRight                                                  ; $09ba

; Convert coords to check east wall
	call ConvertPlayerPixelPosIntoGameGridCoords                    ; $09bd

; If bit 6 of game grid clear (there is an east wall), return
	call HLpointsToGameGridColBRowC                                 ; $09c0
	mov a, m                                                        ; $09c3
	ani $40                                                         ; $09c4
	rz                                                              ; $09c6

@moveRight:
	inr e                                                           ; $09c7
	ret                                                             ; $09c8


; D - player pixel Y
; E - player pixel X
HandlePlayersUpHeld:
; This func can have us exit this func. Jump if we can't also move horizontally
	call ChecksForPlayerMovingVertically                            ; $09c9
	jnz @moveUp                                                     ; $09cc

; Convert coords to check north wall
	call ConvertPlayerPixelPosIntoGameGridCoords                    ; $09cf

; If bit 5 of game grid clear (there is a north wall), return
	call HLpointsToGameGridColBRowC                                 ; $09d2
	mov a, m                                                        ; $09d5
	ani $20                                                         ; $09d6
	rz                                                              ; $09d8

@moveUp:
	dcr d                                                           ; $09d9
	ret                                                             ; $09da


; D - player pixel Y
; E - player pixel X
HandlePlayersDownHeld:
; This func can have us exit this func. Jump if we can't also move horizontally
	call ChecksForPlayerMovingVertically                            ; $09db
	jnz @moveDown                                                   ; $09de

; Convert coords to check north wall from below,
; Returning if we were on the bottom-most row of the grid
	call ConvertPlayerPixelPosIntoGameGridCoords                    ; $09e1
	dcr c                                                           ; $09e4
	rm                                                              ; $09e5

; If bit 5 of game grid clear (there is a north wall), return
	call HLpointsToGameGridColBRowC                                 ; $09e6
	mov a, m                                                        ; $09e9
	ani $20                                                         ; $09ea
	rz                                                              ; $09ec

@moveDown:
	inr d                                                           ; $09ed
	ret                                                             ; $09ee


; D - player pixel Y
; E - player pixel X
; Returns z flag set if we can also move vertically
ChecksForPlayerMovingHoriz:
; Only allow horiz movement if our Y pixel within 8x8 tile is 3
	mov a, d                                                        ; $09ef
	ani $07                                                         ; $09f0
	cpi $03                                                         ; $09f2

; Else don't process the rest of the dir handling func
	pop b                                                           ; $09f4
	rnz                                                             ; $09f5

; Restore stack, and stop study time
	push b                                                          ; $09f6
	call StopStudyTime                                              ; $09f7

; Check if our X is aligned such that we can also move vertically
	mov a, e                                                        ; $09fa
	ani $07                                                         ; $09fb
	cpi $07                                                         ; $09fd
	ret                                                             ; $09ff


; D - player pixel Y
; E - player pixel X
; Returns z flag set if we can also move horizontally
ChecksForPlayerMovingVertically:
; Only allow vertical movement if our X pixel within 8x8 tile is 7
	mov a, e                                                        ; $0a00
	ani $07                                                         ; $0a01
	cpi $07                                                         ; $0a03

; Else don't process the rest of the dir handling func
	pop b                                                           ; $0a05
	rnz                                                             ; $0a06

; Restore stack, and stop study time
	push b                                                          ; $0a07
	call StopStudyTime                                              ; $0a08

; Check if our Y is aligned such that we can also move horizontally
	mov a, d                                                        ; $0a0b
	ani $07                                                         ; $0a0c
	cpi $03                                                         ; $0a0e
	ret                                                             ; $0a10


StopStudyTime:
; If study time was not done...
	lxi b, wStudyTimeIsDone                                         ; $0a11
	ldax b                                                          ; $0a14
	ana a                                                           ; $0a15
	rnz                                                             ; $0a16

; Set study time left to just 1, and set that study time is done
	inr a                                                           ; $0a17
	stax b                                                          ; $0a18
	sta wStudyTimeLeft                                              ; $0a19
	ret                                                             ; $0a1c


; D - player pixel Y
; E - player pixel X
; Returns player's position as col B/row C in game grid
ConvertPlayerPixelPosIntoGameGridCoords:
; A = tile X
	mov a, e                                                        ; $0a1d
	rar                                                             ; $0a1e
	rar                                                             ; $0a1f
	rar                                                             ; $0a20
	ani $1f                                                         ; $0a21

; B = tile X-2
	sui $02                                                         ; $0a23
	mov b, a                                                        ; $0a25

; A = tile Y
	mov a, d                                                        ; $0a26
	rar                                                             ; $0a27
	rar                                                             ; $0a28
	rar                                                             ; $0a29
	ani $1f                                                         ; $0a2a

; C = $19-tile Y
	mov c, a                                                        ; $0a2c
	mvi a, $19                                                      ; $0a2d
	sub c                                                           ; $0a2f
	mov c, a                                                        ; $0a30
	ret                                                             ; $0a31


MoveAI:
; Return if not aligned so it can move horizontally
	lxi h, wPlayer2.PixelY                                          ; $0a32
	mov a, m                                                        ; $0a35
	ani $07                                                         ; $0a36
	cpi $03                                                         ; $0a38
	rnz                                                             ; $0a3a

; Check wPlayer2.PixelX, returning if not aligned to move vertically
	dcx h                                                           ; $0a3b
	mov a, m                                                        ; $0a3c
	ani $07                                                         ; $0a3d
	cpi $07                                                         ; $0a3f
	rnz                                                             ; $0a41

; A = wPlayer2.DirInputs
	dcx h                                                           ; $0a42
	mov a, m                                                        ; $0a43

; B = wAIGameGridCol, C = wAIGameGridRow
	dcx h                                                           ; $0a44
	mov b, m                                                        ; $0a45
	dcx h                                                           ; $0a46
	mov c, m                                                        ; $0a47

; Jump based on direction bit set
	rar                                                             ; $0a48
	jc @moveLeft                                                    ; $0a49

	rar                                                             ; $0a4c
	jc @moveRight                                                   ; $0a4d

	rar                                                             ; $0a50
	jc @moveDown                                                    ; $0a51

	rar                                                             ; $0a54
	jc @moveUp                                                      ; $0a55

	ret                                                             ; $0a58

@moveLeft:
; Try going down, left, or up in order
; Incs and decs are to move check back to curr AI position
	call CheckIfAICanMoveSouth                                      ; $0a59
	jc @updatePosition                                              ; $0a5c
	inr c                                                           ; $0a5f

	call CheckIfAICanMoveWest                                       ; $0a60
	jc @updatePosition                                              ; $0a63
	inr b                                                           ; $0a66

	call CheckIfAICanMoveNorth                                      ; $0a67
	jc @updatePosition                                              ; $0a6a
	dcr c                                                           ; $0a6d

	ret                                                             ; $0a6e

@moveDown:
; Try going right, down, or left in order
; Incs and decs are to move check back to curr AI position
	call CheckIfAICanMoveEast                                       ; $0a6f
	jc @updatePosition                                              ; $0a72
	dcr b                                                           ; $0a75

	call CheckIfAICanMoveSouth                                      ; $0a76
	jc @updatePosition                                              ; $0a79
	inr c                                                           ; $0a7c

	call CheckIfAICanMoveWest                                       ; $0a7d
	jc @updatePosition                                              ; $0a80
	inr b                                                           ; $0a83

	ret                                                             ; $0a84

@moveRight:
; Try going down, up, or right in order
; Incs and decs are to move check back to curr AI position
	call CheckIfAICanMoveSouth                                      ; $0a85
	jc @updatePosition                                              ; $0a88
	inr c                                                           ; $0a8b

	call CheckIfAICanMoveNorth                                      ; $0a8c
	jc @updatePosition                                              ; $0a8f
	dcr c                                                           ; $0a92

	call CheckIfAICanMoveEast                                       ; $0a93
	jc @updatePosition                                              ; $0a96
	dcr b                                                           ; $0a99

	ret                                                             ; $0a9a

@moveUp:
; Try going right, up, or left in order
; Incs and decs are to move check back to curr AI position
	call CheckIfAICanMoveEast                                       ; $0a9b
	jc @updatePosition                                              ; $0a9e
	dcr b                                                           ; $0aa1

	call CheckIfAICanMoveNorth                                      ; $0aa2
	jc @updatePosition                                              ; $0aa5
	dcr c                                                           ; $0aa8

	call CheckIfAICanMoveWest                                       ; $0aa9
	jc @updatePosition                                              ; $0aac
	inr b                                                           ; $0aaf

	ret                                                             ; $0ab0

@updatePosition:
; Update row
	lxi h, wAIGameGridRow                                           ; $0ab1
	mov m, c                                                        ; $0ab4
	inx h                                                           ; $0ab5

; Update wAIGameGridCol
	mov m, b                                                        ; $0ab6
	inx h                                                           ; $0ab7

; Update wPlayer2.DirInputs
	mov a, m                                                        ; $0ab8
	ani $f0                                                         ; $0ab9
	ora d                                                           ; $0abb
	mov m, a                                                        ; $0abc
	ret                                                             ; $0abd


; B - game grid col from left
; C - game grid row from bottom
; Returns carry if we can move in.
; Returns with wPlayer2.DirInputs bits set in D
CheckIfAICanMoveSouth:
; Move to grid cell below, returning if at bottommost
	xra a                                                           ; $0abe
	dcr c                                                           ; $0abf
	rm                                                              ; $0ac0

; Return if there is a north wall from tile below
	call HLpointsToGameGridColBRowC                                 ; $0ac1
	mov a, m                                                        ; $0ac4
	ani $20                                                         ; $0ac5
	rz                                                              ; $0ac7

; Return if bit 7 clear on cell below (not part of the solution)
	mov a, m                                                        ; $0ac8
	ral                                                             ; $0ac9
	rnc                                                             ; $0aca

; Can move, can be redrawn, INPUTF_DOWN2
	mvi d, $c0|INPUTF_DOWN1                                         ; $0acb
	ret                                                             ; $0acd


; B - game grid col from left
; C - game grid row from bottom
; Returns carry if we can move in.
; Returns with wPlayer2.DirInputs bits set in D
CheckIfAICanMoveWest:
	dcr b                                                           ; $0ace
	rm                                                              ; $0acf

; Return if there is an east wall from the left
	call HLpointsToGameGridColBRowC                                 ; $0ad0
	mov a, m                                                        ; $0ad3
	ani $40                                                         ; $0ad4
	rz                                                              ; $0ad6

; Return if bit 7 clear on left cell (not part of the solution)
	mov a, m                                                        ; $0ad7
	ral                                                             ; $0ad8
	rnc                                                             ; $0ad9

; Can move, can be redrawn, INPUTF_LEFT2
	mvi d, $c0|INPUTF_LEFT1                                         ; $0ada
	ret                                                             ; $0adc


; B - game grid col from left
; C - game grid row from bottom
; Returns carry if we can move in.
; Returns with wPlayer2.DirInputs bits set in D
CheckIfAICanMoveNorth:
; Return if there is a north wall from here, C = cell above
	call HLpointsToGameGridColBRowC                                 ; $0add
	inr c                                                           ; $0ae0
	mov a, m                                                        ; $0ae1
	ani $20                                                         ; $0ae2
	rz                                                              ; $0ae4

; Return if we are at the topmost row
	mvi a, GRID_TILE_HEIGHT                                         ; $0ae5
	cmp c                                                           ; $0ae7
	rz                                                              ; $0ae8

; Return if bit 7 clear on cell above (not part of the solution)
	inx h                                                           ; $0ae9
	mov a, m                                                        ; $0aea
	ral                                                             ; $0aeb
	rnc                                                             ; $0aec

; Can move, can be redrawn, INPUTF_UP2
	mvi d, $c0|INPUTF_UP1                                           ; $0aed
	ret                                                             ; $0aef


; B - game grid col from left
; C - game grid row from bottom
; Returns carry if we can move in.
; Returns with wPlayer2.DirInputs bits set in D
CheckIfAICanMoveEast:
; Return if there is an east wall from here, B = right cell
	call HLpointsToGameGridColBRowC                                 ; $0af0
	inr b                                                           ; $0af3
	mov a, m                                                        ; $0af4
	ani $40                                                         ; $0af5
	rz                                                              ; $0af7

; Jump if we were at the rightmost col
	mvi a, GRID_TILE_WIDTH                                          ; $0af8
	cmp b                                                           ; $0afa
	jz @rightmostCol                                                ; $0afb

; HL points to right cell in game grid
	lxi d, GRID_TILE_HEIGHT                                         ; $0afe
	dad d                                                           ; $0b01

; Return if bit 7 clear on right cell (not part of the solution)
	mov a, m                                                        ; $0b02
	ral                                                             ; $0b03
	rnc                                                             ; $0b04

@canMoveRight:
; Can move, can be redrawn, INPUTF_RIGHT2
	mvi d, $c0|INPUTF_RIGHT1                                        ; $0b05
	stc                                                             ; $0b07
	ret                                                             ; $0b08

@rightmostCol:
; Move right if we're aligned to AI's goal, else clear that we can move there
	lda wLeftArrowTileY                                             ; $0b09
	cmp c                                                           ; $0b0c
	jz @canMoveRight                                                ; $0b0d

	xra a                                                           ; $0b10
	ret                                                             ; $0b11


ScriptCommand02_ClearVram:
	mvi a, _sizeof_wVram/$200                                       ; $0b12
	jmp MemClear200hAFromRamEnd                                     ; $0b14


; DE - pointer to script bytes
ScriptCommand04_SetUpPlayer:
	di                                                              ; $0b17

; From script, get DE (eg high byte of player's tile data src),
; Then BC (eg some symbol's tile data)
	xchg                                                            ; $0b18
	mov e, m                                                        ; $0b19
	inx h                                                           ; $0b1a
	mov d, m                                                        ; $0b1b
	inx h                                                           ; $0b1c
	mov c, m                                                        ; $0b1d
	inx h                                                           ; $0b1e
	mov b, m                                                        ; $0b1f
	inx h                                                           ; $0b20

; Store BC in DE/DE-1 (set player's tile data src)
	xchg                                                            ; $0b21
	mov m, b                                                        ; $0b22
	dcx h                                                           ; $0b23
	mov m, c                                                        ; $0b24
	dcx h                                                           ; $0b25

; From script, get another BC (eg tile Y of relevant arrow exit)
	xchg                                                            ; $0b26
	mov c, m                                                        ; $0b27
	inx h                                                           ; $0b28
	mov b, m                                                        ; $0b29
	inx h                                                           ; $0b2a

; Neg byte in bc, add $1a, ie $1a-(BC)
	ldax b                                                          ; $0b2b
	cma                                                             ; $0b2c
	adi $1a                                                         ; $0b2d

; Times 8, then +3 to get starting pixel Y
	rlc                                                             ; $0b2f
	rlc                                                             ; $0b30
	rlc                                                             ; $0b31
	adi $03                                                         ; $0b32

; Store it-1 in eg wPlayer1.PixelY
	stax d                                                          ; $0b34
	dcx d                                                           ; $0b35

; If val < $60 (midframe interrupt Y), c = $10, else $00
	mvi c, $00                                                      ; $0b36
	cpi $60                                                         ; $0b38
	jnc +                                                           ; $0b3a
	mvi c, $10                                                      ; $0b3d

; Store next byte from script into eg wPlayer1.PixelX
+	mov a, m                                                        ; $0b3f
	inx h                                                           ; $0b40
	stax d                                                          ; $0b41
	dcx d                                                           ; $0b42

; A = last script byte, update script pointer
	mov a, m                                                        ; $0b43
	inx h                                                           ; $0b44
	shld wScriptPointer                                             ; $0b45

; Update wPlayer1.DirInputs from last script byte, and bit 4 from checking pixel Y
	ora c                                                           ; $0b48
	stax d                                                          ; $0b49
	ret                                                             ; $0b4a


ScriptCommand05_Check2PlayerGameTime:
; If input is $00, it's 6 mins, if $40, it's 4 minutes
	lxi h, $0006                                                    ; $0b4b
	in MISC_INPUTS                                                  ; $0b4e
	ani INPUTF_2PLAYER_GAME_TIME                                    ; $0b50
	jz +                                                            ; $0b52
	mvi l, $04                                                      ; $0b55
+	shld wNum2PlayerGameTimeMins                                    ; $0b57

; Set if it's 6 mins
	cma                                                             ; $0b5a
	sta w2PlayerGameTimeIs6Mins                                     ; $0b5b
	ret                                                             ; $0b5e


; DE - pointer to script bytes
ScriptCommand08_SetWaitTimer:
; From script, get A
	xchg                                                            ; $0b5f
	mov a, m                                                        ; $0b60

; Update script pointer, then set wait timer
	inx h                                                           ; $0b61
	shld wScriptPointer                                             ; $0b62

	sta wScriptWaitTimer                                            ; $0b65
	ret                                                             ; $0b68


; DE - pointer to script bytes
ScriptCommand09_SetTimerUntilScriptChange:
; From script, get A and store in timer til script change
	xchg                                                            ; $0b69
	mov a, m                                                        ; $0b6a
	sta wTimerUntilScriptChange                                     ; $0b6b
	inx h                                                           ; $0b6e

; Then get DE after
	mov e, m                                                        ; $0b6f
	inx h                                                           ; $0b70
	mov d, m                                                        ; $0b71
	inx h                                                           ; $0b72

; Update script pointer, and store DE as script to change to when timer 0
	shld wScriptPointer                                             ; $0b73
	xchg                                                            ; $0b76
	shld wScriptToChangeToAfterTime                                 ; $0b77
	ret                                                             ; $0b7a


; DE - pointer to script bytes
ScriptCommand0b_Jump:
; From script, get DE
	xchg                                                            ; $0b7b
	mov e, m                                                        ; $0b7c
	inx h                                                           ; $0b7d
	mov d, m                                                        ; $0b7e

; Set script pointer to it
	xchg                                                            ; $0b7f
	shld wScriptPointer                                             ; $0b80
	ret                                                             ; $0b83


; DE - pointer to script bytes
ScriptCommand0c_MemSet:
; From script, get A, then DE
	xchg                                                            ; $0b84
	mov a, m                                                        ; $0b85
	inx h                                                           ; $0b86
	mov e, m                                                        ; $0b87
	inx h                                                           ; $0b88
	mov d, m                                                        ; $0b89
	inx h                                                           ; $0b8a

; Update script pointer, then set A in DE
	shld wScriptPointer                                             ; $0b8b
	stax d                                                          ; $0b8e
	ret                                                             ; $0b8f


; DE - pointer to script bytes
ScriptCommand07_PrintText:
; From script, get A, then DE (later HL)
	xchg                                                            ; $0b90
	mov a, m                                                        ; $0b91
	inx h                                                           ; $0b92
	mov e, m                                                        ; $0b93
	inx h                                                           ; $0b94
	mov d, m                                                        ; $0b95
	inx h                                                           ; $0b96

; Push DE, then get DE from script
	push d                                                          ; $0b97
	mov e, m                                                        ; $0b98
	inx h                                                           ; $0b99
	mov d, m                                                        ; $0b9a
	inx h                                                           ; $0b9b

; Update script pointer, pop 1st word (text src), then print text
	shld wScriptPointer                                             ; $0b9c
	pop h                                                           ; $0b9f
	jmp PrintText                                                   ; $0ba0


ScriptCommand0d_DecAIMovementDelay:
; Dec delay
	lxi d, wAIMovementDelay                                         ; $0ba3
	ldax d                                                          ; $0ba6
	dcr a                                                           ; $0ba7

; Stop updating it if it == 2
	cpi $01                                                         ; $0ba8
	rz                                                              ; $0baa

	stax d                                                          ; $0bab
	ret                                                             ; $0bac


; DE - pointer to script bytes
; Returns HL pointing to after the 2nd word
AndByteInScriptWord_DEequNextWord:
; From script, get BC, then DE
	xchg                                                            ; $0bad
	mov c, m                                                        ; $0bae
	inx h                                                           ; $0baf
	mov b, m                                                        ; $0bb0
	inx h                                                           ; $0bb1
	mov e, m                                                        ; $0bb2
	inx h                                                           ; $0bb3
	mov d, m                                                        ; $0bb4
	inx h                                                           ; $0bb5

; And byte in BC to set/reset z flag
	ldax b                                                          ; $0bb6
	ana a                                                           ; $0bb7
	ret                                                             ; $0bb8


; DE - pointer to script bytes
ScriptCommand0e_JumpIf0:
; Script pointer is jump address if xchg hit, else its after jump addr DE
	call AndByteInScriptWord_DEequNextWord                          ; $0bb9
	jnz +                                                           ; $0bbc
	xchg                                                            ; $0bbf
+	shld wScriptPointer                                             ; $0bc0
	ret                                                             ; $0bc3


ScriptCommand0f_JumpIfNon0:
; Script pointer is jump address if xchg hit, else its after jump addr DE
	call AndByteInScriptWord_DEequNextWord                          ; $0bc4
	jz +                                                            ; $0bc7
	xchg                                                            ; $0bca
+	shld wScriptPointer                                             ; $0bcb
	ret                                                             ; $0bce


; DE - pointer to script bytes
ScriptCommand10_Print2Digits:
; From script, get DE
	xchg                                                            ; $0bcf
	mov e, m                                                        ; $0bd0
	inx h                                                           ; $0bd1
	mov d, m                                                        ; $0bd2
	inx h                                                           ; $0bd3

; Store DE's char digits
	lxi b, wCharDigitsToProcess                                     ; $0bd4
	call StoreDEsCharDigitsIntoBC                                   ; $0bd7

; Get another DE, then update script pointer after it
	mov e, m                                                        ; $0bda
	inx h                                                           ; $0bdb
	mov d, m                                                        ; $0bdc

	inx h                                                           ; $0bdd
	shld wScriptPointer                                             ; $0bde

; Print the digits from the 1st DE to dest in 2nd DE
	lxi h, wCharDigitsToProcess                                     ; $0be1
	call ChangeCharToSpaceIf0                                       ; $0be4
	mvi a, _sizeof_wCharDigitsToProcess                             ; $0be7
	jmp PrintText                                                   ; $0be9


.org $0bee

Non0ScriptCommands:
	.dw UpdateAPlayersDirInputs@done ; Stub command
	.dw ScriptCommand02_ClearVram
	.dw ScriptCommand03_DrawGameGridAndArrows
	.dw ScriptCommand04_SetUpPlayer
	.dw ScriptCommand05_Check2PlayerGameTime
	.dw ScriptCommand06_InitInGameVars
	.dw ScriptCommand07_PrintText
	.dw ScriptCommand08_SetWaitTimer
	.dw ScriptCommand09_SetTimerUntilScriptChange
	.dw ScriptCommand0a_DrawGridCircles
	.dw ScriptCommand0b_Jump
	.dw ScriptCommand0c_MemSet
	.dw ScriptCommand0d_DecAIMovementDelay
	.dw ScriptCommand0e_JumpIf0
	.dw ScriptCommand0f_JumpIfNon0
	.dw ScriptCommand10_Print2Digits
	.dw ScriptCommand11_CreditUsedUp


Text_Spaces:
; 17 spaces
	.asc "                 "


Text_The:
	.asc "THE"
	
Text_Amazing:
	.asc " AMAZING"
Text_TheAmazingEnd:

Text_Maze:
	.asc "MAZE"


Unused_0c30:
	.db CHAR_SPACE


Text_MazesWon:
	.asc "MAZES WON"


Text_Select:
	.asc "SELECT"
	.db $19

Text_SinglePlayer:
	.asc "SINGLE PLAYER"

Text_SinglePlayerToOr:
	.db $18

Text_Or:
	.asc "OR"

Text_OrToTwoPlayer:
	.db $16

Text_TwoPlayer:
	.asc "TWO PLAYER"
Text_SingleOrTwoPlayerEnd:
Text_SelectSinglePlayerOrTwoPlayerEnd:


Unused_0c5c:
	.db $18


Text_3Mazes:
	.asc "3 MAZES"
	
Text_PerGame:
	.asc " PER GAME"
Text_3MazesPerGameEnd:

Text_InsertCoin:
	.asc "INSERT COIN "

Text_DownArrow:
	.asc "v"
Text_InsertCoinDownArrowEnd:


Text_GetReady:
	.asc "GET READY"


Text_PlayAsLongAsYouWin:
	.asc "PLAY AS LONG AS"
	.db $1b
	.asc "YOU WIN"


Text_MazesToPlay:
	.asc "MAZES TO PLAY"


Text_Study:
	.asc "STUDY "
	
Text_Time:
	.asc "TIME"
Text_StudyTimeEnd:


Text_PlayerVertical:
	.asc "P"
	.db $11
	.asc "L"
	.db $11
	.asc "A"
	.db $11
	.asc "Y"
	.db $11
	.asc "E"
	.db $11
	.asc "R"
	
	
Text_OneVertical:
	.asc "O"
	.db $11
	.asc "N"
	.db $11
	.asc "E"


Text_TwoVertical:
	.asc "T"
	.db $11
	.asc "W"
	.db $11
	.asc "O"


Unused_0cc6:
	.db $11
	
	
Text_WinnerVertical:
	.asc "W"
	.db $11
	.asc "I"
	.db $11
	.asc "N"
	.db $11
	.asc "N"
	.db $11
	.asc "E"
	.db $11
	.asc "R"


Text_SpacesVertical:
	.asc " "
	.db $11
	.asc " "
	.db $11
	.asc " "
	.db $11
	.asc " "
	.db $11
	.asc " "
	.db $11
	.asc " "
	.db $11
	.asc " "
	.db $11
	.asc " "
	.db $11
	.asc " "
	.db $11
	.asc " "
	
	
Text_KeepPlaying:
	.asc "KEEP PLAYING"


Text_Wait:
	.asc "WAIT"


Text_PlayerWins:
	.asc "PLAYER WINS"


Text_PlayerLoses:
	.asc "PLAYER LOSES"


Text_PressButtonToStart:
	.asc "PRESS BUTTON TO"
	.db $1c
	.asc "START "

Text_Game:
	.asc "GAME"
Text_PressButtonToStartGameEnd:

Text_Over:
	.asc " OVER"
Text_GameOverEnd:


Text_Overall:
	.asc "OVERALL"


TileData_SmallDiamond:
	dbrev %00001000
	dbrev %00011100
	dbrev %00110110
	dbrev %00011100
	dbrev %00001000


TileData_SquareWithDot:
	dbrev %00111110
	dbrev %00100010
	dbrev %00101010
	dbrev %00100010
	dbrev %00111110


TileData_SmallCircle:
	dbrev %00000000
	dbrev %00000000
	dbrev %00001000
	dbrev %00010100
	dbrev %00001000
	dbrev %00000000
	dbrev %00000000
	dbrev %00000000


TileData_EastLine:
	dbrev %00000001
	dbrev %00000001
	dbrev %00000001
	dbrev %00000001
	dbrev %00000001
	dbrev %00000001
	dbrev %00000001
	dbrev %00000001


TileData_SouthLine:
	dbrev %00000000
	dbrev %00000000
	dbrev %00000000
	dbrev %00000000
	dbrev %00000000
	dbrev %00000000
	dbrev %00000000
	dbrev %11111111


TileData_RightArrow:
	dbrev %00011000
	dbrev %00001100
	dbrev %00000110
	dbrev %01111111
	dbrev %00000110
	dbrev %00001100
	dbrev %00011000
	dbrev %00000000


TileData_LeftArrow:
	dbrev %00000000
	dbrev %00011000
	dbrev %00110000
	dbrev %01100000
	dbrev %11111110
	dbrev %01100000
	dbrev %00110000
	dbrev %00011000


; Called when game is loaded
; Called when time left == 0
Script_GameOver:
; Clear some starting game vars, and use up a credit
; (can be directed to Script_PressToStart1or2Player, eg if not start of he game)
	S_MEMSET $00, w2PlayerGameTimeIs6Mins
	S_MEMSET $00, wP1MazesWon
	S_MEMSET $00, wP2MazesWon
	S_MEMSET $00, wIsNotGameOvered
	S_CREDITUSEDUP

; Flash game over every 0.5 seconds, changing script after 10 seconds
	S_SETTIMERUNTILSCRIPTCHANGE 10, Script_TheAmazingMazeGameInsertCoin
	S_PRINTTEXT $10, Text_Spaces, wVram+NEXT_PIXEL_ROW*0+8

-	S_PRINTTEXT Text_GameOverEnd-Text_Game, Text_Game, wVram+NEXT_PIXEL_ROW*0+11
	S_SETWAITTIMER 30
	S_WAIT
	S_PRINTTEXT Text_GameOverEnd-Text_Game, Text_Spaces, wVram+NEXT_PIXEL_ROW*0+11
	S_SETWAITTIMER 30
	S_WAIT
	S_JUMP -


Script_TheAmazingMazeGameInsertCoin:
; This is the true starting screen, clear vram, and have script change after 10 seconds
	S_CLEARVRAM
	S_SETTIMERUNTILSCRIPTCHANGE 10, Script_InsertCoin1or2Players3Mazes

; Flash some title screen words
-	S_PRINTTEXT _sizeof_Text_The, Text_The, wVram+NEXT_PIXEL_ROW*64+10
	S_SETWAITTIMER 15
	S_WAIT
	S_PRINTTEXT Text_TheAmazingEnd-Text_The, Text_The, wVram+NEXT_PIXEL_ROW*64+10
	S_SETWAITTIMER 15
	S_WAIT
	S_PRINTTEXT _sizeof_Text_Maze, Text_Maze, wVram+NEXT_PIXEL_ROW*112+11
	S_SETWAITTIMER 15
	S_WAIT
	S_PRINTTEXT _sizeof_Text_Game, Text_Game, wVram+NEXT_PIXEL_ROW*112+16
	S_SETWAITTIMER 60
	S_WAIT
	S_PRINTTEXT Text_TheAmazingEnd-Text_The, Text_Spaces, wVram+NEXT_PIXEL_ROW*64+10
	S_PRINTTEXT _sizeof_Text_Maze+_sizeof_Text_Game+1, Text_Spaces, wVram+NEXT_PIXEL_ROW*112+11
	S_PRINTTEXT Text_InsertCoinDownArrowEnd-Text_InsertCoin, Text_InsertCoin, wVram+NEXT_PIXEL_ROW*176+9
	S_SETWAITTIMER 15
	S_WAIT
	S_JUMP -


Script_InsertCoin1or2Players3Mazes:
; The screen when player hasn't inserted a coin yet, clear vram, and display initial text
	S_CLEARVRAM
	S_PRINTTEXT Text_InsertCoinDownArrowEnd-Text_InsertCoin, Text_InsertCoin, wVram+NEXT_PIXEL_ROW*176+9
	S_PRINTTEXT Text_SingleOrTwoPlayerEnd-Text_SinglePlayer-2, Text_SinglePlayer, wVram+NEXT_PIXEL_ROW*48+10

; Flash '3', going to next prompt after 8 seconds
	S_SETTIMERUNTILSCRIPTCHANGE 8, Script_1or2PlayerInsertCoin
-	S_PRINTTEXT Text_3MazesPerGameEnd-Text_3Mazes, Text_3Mazes, wVram+NEXT_PIXEL_ROW*144+8
	S_SETWAITTIMER 30
	S_WAIT
	S_PRINTTEXT $01, Text_Spaces, wVram+NEXT_PIXEL_ROW*144+8
	S_SETWAITTIMER 30
	S_WAIT
	S_JUMP -


Script_1or2PlayerInsertCoin:
; Next prompt screen, display 1 or 2 players
	S_CLEARVRAM
	S_PRINTTEXT Text_SelectSinglePlayerOrTwoPlayerEnd-Text_Select-3, Text_Select, wVram+NEXT_PIXEL_ROW*48+12

; Flash down arrow, going to in-game attract mode after 8 seconds
	S_SETTIMERUNTILSCRIPTCHANGE 8, Script_AttractModeMaze
-	S_PRINTTEXT Text_InsertCoinDownArrowEnd-Text_InsertCoin, Text_InsertCoin, wVram+NEXT_PIXEL_ROW*176+9
	S_SETWAITTIMER 20
	S_WAIT
	S_PRINTTEXT $01, Text_Spaces, wVram+NEXT_PIXEL_ROW*176+21
	S_SETWAITTIMER 20
	S_WAIT
	S_JUMP -


Script_AttractModeMaze:
; Init game, drawing it
	S_CLEARVRAM
	S_INITINGAMEVARS
	S_DRAWGAMEGRIDANDARROWS

; While waiting, a solution is genned. After waiting, draw the solution
	S_SETWAITTIMER 240
	S_WAIT
	S_DRAWGRIDCIRCLES

; Loop up to prompts again after 4 seconds
	S_SETTIMERUNTILSCRIPTCHANGE 4, Script_TheAmazingMazeGameInsertCoin
	S_WAIT


; Called when credits available
Script_PressToStart1or2Player:
; Clear screen, prompting for 1 or 2 players. Set that Start btns are handled
	S_CLEARVRAM
	S_PRINTTEXT Text_PressButtonToStartGameEnd-Text_PressButtonToStart-1, Text_PressButtonToStart, wVram+NEXT_PIXEL_ROW*32+8
	S_PRINTTEXT _sizeof_Text_SinglePlayer, Text_SinglePlayer, wVram+NEXT_PIXEL_ROW*128+9
	S_PRINTTEXT _sizeof_Text_TwoPlayer, Text_TwoPlayer, wVram+NEXT_PIXEL_ROW*160+11
	S_MEMSET $01, wReadyToAcceptStartBtns

; Flash down arrows
-	S_PRINTTEXT _sizeof_Text_DownArrow, Text_Spaces, wVram+NEXT_PIXEL_ROW*128+23
	S_PRINTTEXT _sizeof_Text_DownArrow, Text_DownArrow, wVram+NEXT_PIXEL_ROW*160+9
	S_SETWAITTIMER 30
	S_WAIT
	S_PRINTTEXT _sizeof_Text_DownArrow, Text_DownArrow, wVram+NEXT_PIXEL_ROW*128+23
	S_PRINTTEXT _sizeof_Text_DownArrow, Text_Spaces, wVram+NEXT_PIXEL_ROW*160+9
	S_SETWAITTIMER 30
	S_WAIT
	S_JUMP -


; Called when Start prompted, and 1 player selected
Script_1Player3MazesOrPlayAsLong:
; Clear screen, and set AI to move as slow as possible
	S_CLEARVRAM
	S_MEMSET $04, wAIMovementDelay

; Display that we can do 3 mazes, or as long as we can win
	S_PRINTTEXT _sizeof_Text_SinglePlayer, Text_SinglePlayer, wVram+NEXT_PIXEL_ROW*64+9
	S_PRINTTEXT _sizeof_Text_3Mazes, Text_3Mazes, wVram+NEXT_PIXEL_ROW*96+12
	S_PRINTTEXT _sizeof_Text_Or, Text_Or, wVram+NEXT_PIXEL_ROW*112+15
	S_PRINTTEXT _sizeof_Text_PlayAsLongAsYouWin-1, Text_PlayAsLongAsYouWin, wVram+NEXT_PIXEL_ROW*128+8

; Wait and go to study time
	S_SETWAITTIMER 240
	S_WAIT
	S_JUMP Script_StudyTimeKeepPlaying


Script_GameOverGetReady1:
; Go to game over if 0 mazes left, and P2 has won mazes
	S_JUMPIFNON0 wMazesLeftToPlay, +
	S_JUMPIFNON0 wP2MazesWon, Script_GameOver

; Clear screen, go to study time after 2 seconds
+	S_CLEARVRAM
	S_SETTIMERUNTILSCRIPTCHANGE 2, Script_StudyTimeKeepPlaying

; Before study time, flash 'Get ready'
-	S_PRINTTEXT _sizeof_Text_GetReady, Text_GetReady, wVram+NEXT_PIXEL_ROW*112+11
	S_SETWAITTIMER 30
	S_WAIT
	S_PRINTTEXT _sizeof_Text_GetReady, Text_Spaces, wVram+NEXT_PIXEL_ROW*112+11
	S_SETWAITTIMER 15
	S_WAIT
	S_JUMP -
	
	
Script_StudyTimeKeepPlaying:
; Clear screen, init and display game
	S_CLEARVRAM
	S_INITINGAMEVARS
	S_DRAWGAMEGRIDANDARROWS

; Jump if more mazes left
	S_PRINTTEXT Text_StudyTimeEnd-Text_Study, Text_Study, wVram+NEXT_PIXEL_ROW*213+0
	S_JUMPIFNON0 wMazesLeftToPlay, @moreMazesToPlay

; Else display 'Keep playing', adding 1 to mazes left (play as long as you win)
	S_PRINTTEXT _sizeof_Text_KeepPlaying, Text_KeepPlaying, wVram+NEXT_PIXEL_ROW*0+8
	S_MEMSET $01, wMazesLeftToPlay
	S_JUMP +

@moreMazesToPlay:
; Display mazes left
	S_PRINTTEXT _sizeof_Text_MazesToPlay, Text_MazesToPlay, wVram+NEXT_PIXEL_ROW*0+8
	S_PRINT2DIGITS wMazesLeftToPlay, wVram+NEXT_PIXEL_ROW*0+22

; Display mazes won
+	S_PRINTTEXT _sizeof_Text_MazesWon, Text_MazesWon, wVram+NEXT_PIXEL_ROW*213+17
	S_PRINT2DIGITS wP1MazesWon, wVram+NEXT_PIXEL_ROW*213+27

; Set character sprites, and timers, then wait until game done
	S_SETUPPLAYER wPlayer2.TileDataSrc+1, TileData_SmallDiamond, wRightArrowTileY, $17, $c0|INPUTF_RIGHT1
	S_SETUPPLAYER wPlayer1.TileDataSrc+1, TileData_SquareWithDot, wLeftArrowTileY, $e0, $c0

	S_MEMSET 6, wTimerUntilNextStudyTimeTick
	S_MEMSET 6, wStudyTimeLeft
	S_WAIT

; 4 seconds after game done, get ready (can move). Hide 'mazes to play', and display mazes won
	S_SETTIMERUNTILSCRIPTCHANGE 4, Script_GameOverGetReady1
	S_PRINTTEXT $10, Text_Spaces, wVram+NEXT_PIXEL_ROW*0+8
	S_PRINT2DIGITS wP1MazesWon, wVram+NEXT_PIXEL_ROW*213+27

; Jump if AI won
	S_JUMPIF0 wP1JustWon, @aiJustWon

; If player won, make AI faster, and flash 'Player wins'
	S_DECAIMOVEMENTDELAY
-	S_PRINTTEXT _sizeof_Text_PlayerWins, Text_PlayerWins, wVram+NEXT_PIXEL_ROW*0+8
	S_SETWAITTIMER 30
	S_WAIT
	S_PRINTTEXT _sizeof_Text_PlayerWins, Text_Spaces, wVram+NEXT_PIXEL_ROW*0+8
	S_SETWAITTIMER 30
	S_WAIT
	S_JUMP -

@aiJustWon:
; Flash 'Player loses'
-	S_PRINTTEXT _sizeof_Text_PlayerLoses, Text_PlayerLoses, wVram+NEXT_PIXEL_ROW*0+8
	S_SETWAITTIMER 30
	S_WAIT
	S_PRINTTEXT _sizeof_Text_PlayerLoses, Text_Spaces, wVram+NEXT_PIXEL_ROW*0+8
	S_SETWAITTIMER 30
	S_WAIT
	S_JUMP -


; Called when Start prompted, and 2 player selected
Script_2Player3Mazes:
; Clear screen, and set vars based on 2-player game time
	S_CLEARVRAM
	S_CHECK2PLAYERGAMETIME

; Display text, wait, then go to vertical text script
	S_PRINTTEXT _sizeof_Text_TwoPlayer, Text_TwoPlayer, wVram+NEXT_PIXEL_ROW*64+11
	S_PRINTTEXT _sizeof_Text_3Mazes, Text_3Mazes, wVram+NEXT_PIXEL_ROW*96+12
	S_SETWAITTIMER 180
	S_WAIT
	S_JUMP Script_VerticalText


Script_GameOverGetReady2:
; If 0 mazes left, go to game over, else clear screen
	S_JUMPIF0 wMazesLeftToPlay, Script_GameOver
	S_CLEARVRAM

; Flash 'Get ready', then go to vertical text
	S_SETTIMERUNTILSCRIPTCHANGE 2, Script_VerticalText
-	S_PRINTTEXT _sizeof_Text_GetReady, Text_GetReady, wVram+NEXT_PIXEL_ROW*112+11
	S_SETWAITTIMER 30
	S_WAIT
	S_PRINTTEXT _sizeof_Text_GetReady, Text_Spaces, wVram+NEXT_PIXEL_ROW*112+11
	S_SETWAITTIMER 30
	S_WAIT
	S_JUMP -


Script_VerticalText:
; Clear screen, init in-game, and draw grid
	S_CLEARVRAM
	S_INITINGAMEVARS
	S_DRAWGAMEGRIDANDARROWS

; Print vertical text
	S_PRINTTEXT _sizeof_Text_PlayerVertical-5, Text_PlayerVertical, wVram+NEXT_PIXEL_ROW*16+1
	S_PRINTTEXT _sizeof_Text_TwoVertical-2, Text_TwoVertical, wVram+NEXT_PIXEL_ROW*135+1
	S_PRINT2DIGITS wP2MazesWon, wVram+NEXT_PIXEL_ROW*192+0
	S_PRINTTEXT _sizeof_Text_PlayerVertical-5, Text_PlayerVertical, wVram+NEXT_PIXEL_ROW*16+30
	S_PRINTTEXT _sizeof_Text_OneVertical-2, Text_OneVertical, wVram+NEXT_PIXEL_ROW*135+30
	S_PRINT2DIGITS wP1MazesWon, wVram+NEXT_PIXEL_ROW*192+29
	S_PRINTTEXT _sizeof_Text_MazesToPlay, Text_MazesToPlay, wVram+NEXT_PIXEL_ROW*0+8
	S_PRINT2DIGITS wMazesLeftToPlay, wVram+NEXT_PIXEL_ROW*0+22
	S_PRINTTEXT _sizeof_Text_Time, Text_Time, wVram+NEXT_PIXEL_ROW*213+3
	S_PRINTTEXT _sizeof_Text_Overall, Text_Overall, wVram+NEXT_PIXEL_ROW*213+17
	S_SETUPPLAYER wPlayer2.TileDataSrc+1, TileData_SquareWithDot, wRightArrowTileY, $17, $c0
	S_SETUPPLAYER wPlayer1.TileDataSrc+1, TileData_SmallDiamond, wLeftArrowTileY, $e0, $c0

; Start counting seconds, and don't do 1-player's study time. Wait until game done
	S_MEMSET 1, wSecondsPassedTimer
	S_MEMSET $01, wStudyTimeIsDone
	S_WAIT

; Display mazes left, and after 4 seconds, go to Game over/Get ready screen for 2-player
	S_PRINT2DIGITS wMazesLeftToPlay, wVram+NEXT_PIXEL_ROW*0+22
	S_SETTIMERUNTILSCRIPTCHANGE $04, Script_GameOverGetReady2

; Jump if player 1 just won
	S_JUMPIF0 wP2JustWon, @player1JustWon

; Print num mazes player 2 just won, and flash Winner on the left
	S_PRINT2DIGITS wP2MazesWon, wVram+NEXT_PIXEL_ROW*192+0
-	S_PRINTTEXT _sizeof_Text_SpacesVertical-9, Text_SpacesVertical, wVram+NEXT_PIXEL_ROW*16+1
	S_SETWAITTIMER 30
	S_WAIT
	S_PRINTTEXT _sizeof_Text_WinnerVertical-5, Text_WinnerVertical, wVram+NEXT_PIXEL_ROW*16+1
	S_SETWAITTIMER 30
	S_WAIT
	S_JUMP -

@player1JustWon:
; Print num mazes player 1 just won, and flash Winner on the right
	S_PRINT2DIGITS wP1MazesWon, wVram+NEXT_PIXEL_ROW*192+29
-	S_PRINTTEXT _sizeof_Text_SpacesVertical-9, Text_SpacesVertical, wVram+NEXT_PIXEL_ROW*16+30
	S_SETWAITTIMER 30
	S_WAIT
	S_PRINTTEXT _sizeof_Text_WinnerVertical-5, Text_WinnerVertical, wVram+NEXT_PIXEL_ROW*16+30
	S_SETWAITTIMER 30
	S_WAIT
	S_JUMP -
