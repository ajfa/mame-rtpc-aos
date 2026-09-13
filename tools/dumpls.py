#!/usr/bin/env python3
"""Minimal reader for 4.3BSD dump(8) streams (big-endian, TP_BSIZE=1024).

Usage: dumpls.py <dumpfile> [--extract DIR]
Lists the archived tree; optionally extracts regular files.
"""
import os, struct, sys, stat

TP_BSIZE = 1024
NFS_MAGIC = 60012
TS_TAPE, TS_INODE, TS_BITS, TS_ADDR, TS_END, TS_CLRI = 1, 2, 3, 4, 5, 6


def records(path):
    with open(path, 'rb') as f:
        while True:
            b = f.read(TP_BSIZE)
            if len(b) < TP_BSIZE:
                return
            yield b


class Reader:
    def __init__(self, path):
        self.it = records(path)
        self.inodes = {}        # ino -> (dinode fields, [data blocks])

    def parse_header(self, b):
        c_type, c_date, c_ddate, c_vol, c_tapea, c_ino, magic, cks = struct.unpack('>8i', b[:32])
        if magic != NFS_MAGIC:
            return None
        di = b[32:160]
        mode, nlink, uid, gid = struct.unpack('>Hhhh', di[:8])
        size = struct.unpack('>Q', di[8:16])[0]
        count = struct.unpack('>i', b[160:164])[0]
        addr = b[164:164 + 512]
        return dict(type=c_type, ino=c_ino & 0xffffffff, mode=mode, nlink=nlink,
                    uid=uid, gid=gid, size=size, count=count, addr=addr)

    def read(self):
        hdr = None
        for b in self.it:
            h = self.parse_header(b)
            if h is None:
                continue                     # data block handled below
            if h['type'] == TS_END:
                break
            if h['type'] in (TS_INODE, TS_ADDR):
                if h['type'] == TS_INODE:
                    hdr = h
                    self.inodes.setdefault(h['ino'], dict(meta=h, data=bytearray()))
                cur = self.inodes.get(hdr['ino']) if hdr else None
                for i in range(h['count']):
                    blk = next(self.it, None)
                    if blk is None:
                        return
                    if h['addr'][i]:
                        if cur is not None:
                            cur['data'] += blk
        return self.inodes


def dirents(data):
    off = 0
    while off + 8 <= len(data):
        ino, reclen, namlen = struct.unpack('>IHH', data[off:off + 8])
        if reclen < 8 or off + reclen > len(data):
            break
        name = data[off + 8:off + 8 + namlen].split(b'\0')[0].decode('latin1')
        if ino:
            yield ino, name
        off += reclen


def walk(inodes, ino=2, path='', seen=None, out=None):
    seen = seen or set()
    out = out if out is not None else []
    if ino in seen:
        return out
    seen.add(ino)
    node = inodes.get(ino)
    if not node:
        return out
    for cino, name in dirents(bytes(node['data'])):
        if name in ('.', '..'):
            continue
        child = inodes.get(cino)
        p = path + '/' + name
        if child and stat.S_ISDIR(child['meta']['mode']):
            out.append((p + '/', child['meta']['size'], cino))
            walk(inodes, cino, p, seen, out)
        else:
            sz = child['meta']['size'] if child else -1
            out.append((p, sz, cino))
    return out


if __name__ == '__main__':
    inodes = Reader(sys.argv[1]).read()
    entries = walk(inodes)
    print('inodes in stream: %d, entries reachable from root: %d' % (len(inodes), len(entries)))
    for p, sz, ino in entries[:int(os.getenv('LIMIT', '60'))]:
        print('%10d  %6d  %s' % (sz, ino, p))
