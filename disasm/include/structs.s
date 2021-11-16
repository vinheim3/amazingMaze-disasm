.struct Player
; Bit 7 - set if can move
; Bit 6 - during DrawPlayer, if clear, clears bit 7 (stops movement) and 5 (can redraw)
; Bit 5 - set if player is being drawn
; Bit 4 - set if player Y < $60, ie in area before midframe interrupt
    DirInputs db
    PixelX db
    PixelY db
    TileDataSrc dw
; Player is drawn upwards
    StartingVramLoc dw
    TileDataWithoutPlayer ds 2
.endst