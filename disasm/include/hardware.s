; in
.define JOY_INPUTS = $00
.define INPUTF_LEFT1 = $01
.define INPUTF_RIGHT1 = $02
.define INPUTF_DOWN1 = $04
.define INPUTF_UP1 = $08
.define INPUTF_LEFT2 = $10
.define INPUTF_RIGHT2 = $20
.define INPUTF_DOWN2 = $40
.define INPUTF_UP2 = $80

.define MISC_INPUTS = $01
.define INPUTF_START1 = $01
.define INPUTF_START2 = $02
.define INPUTF_COIN = $08
; Bit 4/5 are for Coin/Credit
.define INPUTF_1C_1C = $00
.define INPUTF_2C_1C = $10
.define INPUTF_1C_2C = $20
.define INPUTF_2C_3C = $30
; $40 if 4 minutes, $00 if 6 minutes
.define INPUTF_2PLAYER_GAME_TIME = $40
.define INPUTF_SERVICE = $80

; out
.define COIN_COUNTER = $01
.define WATCHDOG_RESET = $02