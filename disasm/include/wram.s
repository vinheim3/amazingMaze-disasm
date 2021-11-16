.include "includes.s"

.ramsection "WRAM 0" bank 0 slot 1

wWram: ; $2000
    .db

wScriptPointer: ; $2000
    dw

wScriptToStart: ; $2002
    dw

wRNGVars: ; $2004
    ds 4

wScriptToChangeToAfterTime: ; $2008
    dw

wTimesToShuffleRNG: ; $200a
    db

wTimers: ; $200b
    .db
; The only timer that ticks per second, rather than per frame
wTimerUntilScriptChange: ; $200b
    db
wScriptWaitTimer: ; $200c
    db
wSecondsPassedTimer: ; $200d
    db
wTimerUntilNextStudyTimeTick: ; $200e
    db
wUnusedTimer_200f: ; $200f
    db
wTimersEnd:
    .db

w2010:
    ds 3-0

wAIMovementDelay: ; $2013
    db

wNumCoins: ; $2014
    db

wInGameVarsToReset: ; $2015
    .db
wPlayerPixelShift: ; $2015
    db
wPrevPlayerTileDataBytes: ; $2016
    ds 2
wInGameTimePassed: ; $2018
    ds 2
wP1JustWon: ; $201a
    db
wP2JustWon: ; $201b
    db
wNumTimesSettingWallsForHappyPath: ; $201c
    db
; When genning grid, the happy path has this at 0
; When we reach the right part of the screen,
;   this is set to 8 to set everything else as unhappy
wCurrGameGridByteIsNotInSolution: ; $201d
    db
wProcessedGameDone: ; $201e
    db
wGameGridLoaded: ; $201f
    db
wStudyTimeIsDone: ; $2020
    db
wUnusedInGameVar_2021: ; $2021
    db
wInGameVarsToResetEnd: ; $2022
    .db

wJustSetSomeWalls: ; $2022
    db

; Both from bottom-right
wInitTileYtoSetForLeftArrow: ; $2023
    db
wLeftArrowTileY: ; $2024
    db

; Both from bottom-left
wInitTileYtoSetForRightArrow: ; $2025
    db
wRightArrowTileY: ; $2026
    db

wNumCredits: ; $2027
    db

wLastInputfCoinValue: ; $2028
    db

wStudyTimeLeft: ; $2029
    db

wNum2PlayerGameTimeMins: ; $202a
    dw

w2PlayerGameTimeIs6Mins: ; $202c
    db

wIsNotGameOvered: ; $202d
    db

wMazesLeftToPlay: ; $202e
    db

; $00 for vblank, $10 for mid-frame
; Ensures interrupts are always done in the right order, if 1 takes too long
wInterruptHandlerToIgnore: ; $202f
    db

wNumPlayers: ; $2030
    db

wP1MazesWon: ; $2031
    db
wP2MazesWon: ; $2032
    db

wAIMovementFrameCounter: ; $2033
    db

wReadyToAcceptStartBtns: ; $2034
    db

wTimersJustDoneBitField: ; $2035
    db

.union

wCharDigitsToProcess: ; $2036
    ds 2

.nextu

wServiceModeChecksumChars: ; $2036
    ds 4
wServiceModeChecksumCharsEnd: ; $203a
    .db

.endu

w203a:
    ds $40-$3a

wInitRowToSetForAI: ; $2040
    db
wInitColToSetForAI: ; $2041
    db
wAIGameGridRow: ; $2042
    db
wAIGameGridCol: ; $2043
    db

wPlayer2: ; $2044
    instanceof Player

w204d:
    ds $55-$4d

wPlayer1: ; $2055
    instanceof Player

w205e:
    ds $66-$5e

; Bit 7 - if set, its part of the solution (draw small circles when game done)
; Bit 6 - if clear, there is an east wall
; Bit 5 - if clear, there is a north wall
; Bit 0 - if clear, cell considered able to move to as part of drawing process
;       - if set, cell is considered processed
;           (we can still move to other cells as part of final check)
; Bits 3-0 - shifted to upper bits from script command 6
; Starts from bottom-left of grid. As we move through the struct,
;   move up vertically first, then to the bottom of the col to the right
wGameGrid: ; $2066
    ds GRID_TILE_HEIGHT*GRID_TILE_WIDTH

w22d6:
    ds $400-$2d6

wStackTop: ; $2400
    .db

wVram: ; $2400
    ds $4000-$2400

wRamEnd: ; $4000
    .db

.ends
