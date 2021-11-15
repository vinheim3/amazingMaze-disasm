#!/usr/bin/env python3

import sys
import clipboard
from util import getRom, bankConv

data = getRom()
addr = bankConv(sys.argv[1])

cmds = {
    0x00: ['S_WAIT', ""],
    0x02: ['S_CLEARVRAM', ""],
    0x03: ['S_DRAWGAMEGRIDANDARROWS', ""],
    0x04: ['S_SETUPPLAYER', "wwwbb"],
    0x05: ['S_CHECK2PLAYERGAMETIME', ""],
    0x06: ['S_INITINGAMEVARS', ""],
    0x07: ['S_PRINTTEXT', "bww"],
    0x08: ['S_SETWAITTIMER', "b"],
    0x09: ['S_SETTIMERUNTILSCRIPTCHANGE', "bw"],
    0x0a: ['S_DRAWGRIDCIRCLES', ""],
    0x0b: ['S_JUMP', "w"],
    0x0c: ['S_MEMSET', "bw"],
    0x0d: ['S_DECAIMOVEMENTDELAY', ""],
    0x0e: ['S_JUMPIF0', "ww"],
    0x0f: ['S_JUMPIFNON0', "ww"],
    0x10: ['S_PRINT2DIGITS', "ww"],
    0x11: ['S_CREDITUSEDUP', ""],
}

limit = 10000
comps = []
addr_comps = []
while True:
    # Prevent infinite loops
    limit -= 1
    if limit == 0:
        break

    # Get op, raise if not catered to
    op = data[addr]
    orig_addr = addr
    addr += 1
    if op not in cmds:
        print(Exception(f"Command: ${op:02x}"))
        break

    # Build param part of macro
    cmd, params = cmds[op]
    param_comps = []
    for param in params:
        if param == 'b':
            b = data[addr]
            addr += 1
            param_comps.append(f"${b:02x}")
        elif param == 'w':
            w = data[addr]+data[addr+1]*0x100
            addr += 2
            param_comps.append(f"${w:04x}")
    
    # Add macro + params if it has it
    ins_str = f"\t{cmd}"
    comment = f"; ${orig_addr:04x}"
    if param_comps:
        comps.append(f"{ins_str} {', '.join(param_comps)}")
        addr_comps.append(f"{ins_str} {', '.join(param_comps)} {comment}")
    else:
        comps.append(ins_str)
        addr_comps.append(f"{ins_str} {comment}")

    if op in [0x0b]:
        break

# Output to cli and clipboard
final_str = "\n".join(comps)
clipboard.copy(final_str)
print("\n".join(addr_comps))
print(f"Next: ${addr:04x}")
