#!/usr/bin/env python3
"""Extract one or more files from a 4.3BSD dump(8) stream.

Usage: dumpget.py <dumpfile> <outdir> <substring> [<substring> ...]
"""
import os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'dumpls.py')).read()
src = src.replace("if __name__ == '__main__':", "if False:")
g = {}
exec(src, g)

dumpfile, outdir = sys.argv[1], sys.argv[2]
wanted = sys.argv[3:]

inodes = g['Reader'](dumpfile).read()
entries = g['walk'](inodes)
os.makedirs(outdir, exist_ok=True)
for path, size, ino in entries:
    if path.endswith('/'):
        continue
    if not any(w in path for w in wanted):
        continue
    node = inodes.get(ino)
    if not node:
        print('missing inode', path)
        continue
    data = bytes(node['data'])[:size]
    dest = os.path.join(outdir, path.lstrip('/').replace('/', '_'))
    with open(dest, 'wb') as f:
        f.write(data)
    print('%8d  %s -> %s' % (len(data), path, os.path.basename(dest)))
