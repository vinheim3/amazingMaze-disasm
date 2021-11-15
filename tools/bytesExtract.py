#!/usr/bin/env python3

import sys
import clipboard
from util import conv, bankConv, groupBytes, stringB, stringW, getRom, stringBits, stringRevBits

args = 4

if len(sys.argv) < args:
    print('Usage: ' + sys.argv[0] + ' startAddress endAddress groups')
    sys.exit()

data = getRom()

start, end, groups, *extra = sys.argv[1:]

start = bankConv(start)

if ':' in end:
    end = bankConv(end)
    bytes = data[start:end+1]
else:
    end = conv(end)
    bytes = data[start:start+end]

if groups == 't':
    chars = []
    for byte in bytes:
        if byte < 0x30:
            break
        if byte <= 0x39:
            chars.append(chr(byte))
        elif byte < 0x40:
            raise Exception(byte)
        elif byte == 0x40:
            chars.append(' ')
        elif byte > 0x5a:
            raise Exception(byte)
        else:
            #special case for jqx
            letter = chr(byte)
            mapp = {
                'J': '!',
                'Q': 'v',
                'X': ':',
            }
            letter = mapp.get(letter, letter)
            chars.append(letter)
    final_str = '\t.asc "' + "".join(chars) + '"'
    clipboard.copy(final_str)
    print(final_str)
    exit(0)

comps = []
groups = int(groups)
if groups == -1:
    bgs = groupBytes(bytes, 1 if not extra else int(extra[0]))
    comps = [stringBits(comp) for comp in bgs]
    print(len(comps))
elif groups == -2:
    bgs = groupBytes(bytes, 1 if not extra else int(extra[0]))
    comps = [stringRevBits(comp) for comp in bgs]
    print(len(comps))
elif groups != 0:
    comps = groupBytes(bytes, groups)
    comps = [stringB(comp) for comp in comps]
    print(len(comps))
else:
    curr_comp = []
    for i, byte in enumerate(bytes):
        if i != 0 and i%2 == 0:
            full_str = stringW([(curr_comp[1]<<8)+curr_comp[0]])
            comps.append(full_str)
            curr_comp = []
        curr_comp.append(byte)
    if curr_comp:
        if len(curr_comp) == 2:
            full_str = stringW([(curr_comp[1]<<8)+curr_comp[0]])
        else:
            full_str = stringB([curr_comp[0]])
        comps.append(full_str)

final_str = "\n".join(comps)
clipboard.copy(final_str)
print(final_str)
