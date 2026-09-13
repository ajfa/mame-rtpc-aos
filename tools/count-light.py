#!/usr/bin/env python3
"""Count the light pixels of a MAME snapshot, on a grid.

The console of AOS is black with a little red text; the root window of X11 is
a dense black and white weave, and a menu on top of it is a solid white box.
Counting light pixels tells the three of them apart without any image library.
"""
import sys
import zlib

def load(path):
    data = open(path, 'rb').read()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('not a PNG')
    pos, idat, plte = 8, [], None
    w = h = depth = ctype = 0
    while pos < len(data):
        ln = int.from_bytes(data[pos:pos + 4], 'big')
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + ln]
        if kind == b'IHDR':
            w = int.from_bytes(body[0:4], 'big')
            h = int.from_bytes(body[4:8], 'big')
            depth, ctype = body[8], body[9]
        elif kind == b'PLTE':
            plte = body
        elif kind == b'IDAT':
            idat.append(body)
        elif kind == b'IEND':
            break
        pos += 12 + ln
    if depth != 8:
        raise ValueError('only 8 bits per sample supported, got %d' % depth)
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    raw = zlib.decompress(b''.join(idat))
    stride = w * channels
    out = bytearray(h * stride)
    prev = bytearray(stride)
    p = 0
    for y in range(h):
        f = raw[p]; p += 1
        line = bytearray(raw[p:p + stride]); p += stride
        if f == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xff
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xff
        elif f == 3:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xff
        elif f == 4:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                c = prev[i - channels] if i >= channels else 0
                b = prev[i]
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xff
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return w, h, channels, ctype, plte, out

def main():
    w, h, ch, ctype, plte, px = load(sys.argv[1])
    stride = w * ch
    light = total = 0
    y = 20
    while y < min(h, 360):
        x = 60
        while x < min(w, 630):
            i = y * stride + x * ch
            if ctype == 3:
                k = px[i] * 3
                r, g, b = plte[k], plte[k + 1], plte[k + 2]
            elif ch >= 3:
                r, g, b = px[i], px[i + 1], px[i + 2]
            else:
                r = g = b = px[i]
            total += 1
            if r + g + b > 300:
                light += 1
            x += 7
        y += 5
    print('%d %d' % (light, total))

main()
