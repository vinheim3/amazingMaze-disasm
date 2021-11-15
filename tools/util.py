def conv(hexstr):
    return int(f"0x{hexstr}", 16)


def bankAddr(bank, addr):
    return bank * 0x2000 + (addr % 0x2000)


def bankConv(hexstr):
    if ':' not in hexstr:
        return conv(hexstr)

    bank, addr = hexstr.split(':')
    return bankAddr(conv(bank), conv(addr))


def groupBytes(bs, groups):
    n = len(bs[::groups])
    return [
        bs[i*groups:(i+1)*groups] for i in range(n)
    ]


def stringB(bs):
    return f"\t.db " + ", ".join(f"${byte:02x}" for byte in bs)


def stringBits(bs):
    return f"\t.db " + ", ".join(f"%{byte:08b}" for byte in bs)


def stringRevBits(bs):
    return f"\tdbrev " + ", ".join("%"+ "".join(reversed(f"{byte:08b}")) for byte in bs)


def stringW(ws):
    return f"\t.dw " + ", ".join(f"${word:04x}" for word in ws)


def wordIn(data, offset):
    return (data[offset+1]<<8)|data[offset]


def toWords(bs):
    ws = []
    for i in range(len(bs)//2):
        word = bs[i*2]+(bs[i*2+1]<<8)
        ws.append(word)
    return ws


def getRom():
    with open('tools/prgRom.bin', 'rb') as f:
        data = f.read()
    return data
