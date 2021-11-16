.macro ldbc
    lxi b, (\1<<8)+\2
.endm

.macro S_WAIT
	.db $00
.endm

.macro S_CLEARVRAM
    .db $02
.endm

.macro S_DRAWGAMEGRIDANDARROWS
	.db $03
.endm

.macro S_SETUPPLAYER
    .db $04
; player's tile data src, tile data src to set, pointer to tile Y to place player
    .dw \1, \2, \3
	.db \4, \5 ; player's X, bits to set on eg wPlayer1.DirInputs
.endm

.macro S_CHECK2PLAYERGAMETIME
	.db $05
.endm

.macro S_INITINGAMEVARS
	.db $06
.endm

.macro S_PRINTTEXT
	.db $07, \1 ; num chars
	.dw \2, \3 ; src dest
.endm

.macro S_SETWAITTIMER
	.db $08, \1 ; num frames
.endm

.macro S_SETTIMERUNTILSCRIPTCHANGE
    .db $09, \1 ; num seconds
    .dw \2 ; script to change to
.endm

.macro S_DRAWGRIDCIRCLES
	.db $0a
.endm

.macro S_JUMP
    .db $0b
    .dw \1 ; jump address
.endm

.macro S_MEMSET
    .db $0c, \1 ; byte to set
    .dw \2 ; address to set
.endm

.macro S_DECAIMOVEMENTDELAY
	.db $0d
.endm

.macro S_JUMPIF0
	.db $0e
	.dw \1, \2 ; addr to check, jump address
.endm

.macro S_JUMPIFNON0
	.db $0f
	.dw \1, \2 ; addr to check, jump address
.endm

.macro S_PRINT2DIGITS
    .db $10
    .dw \1, \2 ; pointer to BCD byte, vram dest
.endm

.macro S_CREDITUSEDUP
	.db $11
.endm

.macro revb
	.redefine tmp \1
	.rept 4 index tmpi
		.redefine tmp1 tmp&(1<<tmpi)
		.redefine tmp2 tmp&($80>>tmpi)
		.redefine tmp tmp&(($1<<tmpi)~$ff)
		.redefine tmp tmp&(($80>>tmpi)~$ff)
		.redefine tmp tmp | (tmp1<<(7-tmpi*2)) | (tmp2>>(7-tmpi*2))
	.endr
	.redefine _out tmp

	.undefine tmp
	.undefine tmp1
	.undefine tmp2
.endm

; Define a byte, reversing the bits
.macro dbrev
	.rept NARGS
		.dbm revb \1
		.shift
	.endr
.endm