#!/usr/bin/env python3

import png
from util import getRom

data = getRom()

# start = bankConv(sys.argv[1])
# numBytes = conv(sys.argv[2])
start = 0x170
numBytes = 0x172
data = data[start:start+numBytes]

tiles_wide = 1
# 1bpp, 8 pixels per row = 8 bits = 1 byte
tiles_high = len(data) // 1 // tiles_wide

palette = [(0, 0, 0), (0xff, 0xff, 0xff)]

all_data = []
for i in range(tiles_high):
    # array in every row
    all_data.append([0]*(tiles_wide*8))

for i in range(tiles_high):
    for j in range(tiles_wide):
        data_offset = (i*tiles_wide)+j
        data_byte = data[data_offset]

        for l in range(8):
            all_data[i][j*8+l] = ((data_byte>>l)&1)

w = png.Writer(len(all_data[0]), len(all_data), palette=palette, bitdepth=1)

with open('gfx_new.png', 'wb') as f:
    w.write(f, all_data)
