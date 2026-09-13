#!/usr/bin/env python3
"""Fake rcmd() client, to gate fake_rshd.py the way AOS's libc talks to it."""
import socket, sys, time

host = sys.argv[1] if len(sys.argv) > 1 else '127.0.0.1'
port = int(sys.argv[2]) if len(sys.argv) > 2 else 5140
cmd = sys.argv[3] if len(sys.argv) > 3 else 'hostname'

# stderr listener, like rresvport + listen(s2, 1)
lst = socket.socket()
lst.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
lst.bind(('', 0))
lport = lst.getsockname()[1]
lst.listen(1)

s = socket.create_connection((host, port), timeout=10)
s.sendall(str(lport).encode() + b'\0')
lst.settimeout(15)
try:
    err, peer = lst.accept()
    print('callback received from', peer)
except socket.timeout:
    print('FAILED: the server did not call back')
    sys.exit(1)

s.sendall(b'operator\0operator\0' + cmd.encode() + b'\0')
c = s.recv(1)
print('start byte:', c)
if c != b'\0':
    print('FAILED: it did not send the NUL')
    sys.exit(1)

total = 0
t0 = time.time()
while True:
    b = s.recv(1 << 16)
    if not b:
        break
    total += len(b)
    if total > (2 << 20):
        break
print('received %d bytes in %.1f s' % (total, time.time() - t0))
