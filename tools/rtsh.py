#!/usr/bin/env python3
"""Run commands on the emulated RT PC over telnet and print what it says.

Beats reading screenshots: the output comes back as text.

    python3 rtsh.py "df" "ls /usr/bin/X11"
    python3 rtsh.py --host 46.0.0.2 --user root --wait 90 "uptime"
"""
import argparse
import re
import socket
import sys
import time

IAC, DONT, DO, WONT, WILL, SB, SE = 255, 254, 253, 252, 251, 250, 240
ECHO, SGA, TTYPE = 1, 3, 24


def negotiate(sock, data, out):
    """Answer telnet option negotiation, return the plain data."""
    i = 0
    while i < len(data):
        b = data[i]
        if b != IAC:
            out.append(b)
            i += 1
            continue
        if i + 1 >= len(data):
            break
        cmd = data[i + 1]
        if cmd in (DO, DONT, WILL, WONT):
            if i + 2 >= len(data):
                break
            opt = data[i + 2]
            if cmd == DO:
                # we only ever claim to do terminal type
                reply = WILL if opt == TTYPE else WONT
                sock.sendall(bytes([IAC, reply, opt]))
            elif cmd == WILL:
                reply = DO if opt in (ECHO, SGA) else DONT
                sock.sendall(bytes([IAC, reply, opt]))
            i += 3
        elif cmd == SB:
            end = data.find(bytes([IAC, SE]), i)
            if end < 0:
                break
            # answer a terminal type request with something harmless
            sock.sendall(bytes([IAC, SB, TTYPE, 0]) + b'DUMB' + bytes([IAC, SE]))
            i = end + 2
        else:
            i += 2
    return out


def read_until(sock, pattern, timeout=60.0):
    """Read until a regex matches or we run dry; return the text seen."""
    rx = re.compile(pattern)
    buf = bytearray()
    deadline = time.time() + timeout
    sock.settimeout(2.0)
    while time.time() < deadline:
        try:
            chunk = sock.recv(4096)
        except socket.timeout:
            if rx.search(bytes(buf).decode('latin1')):
                break
            continue
        if not chunk:
            break
        negotiate(sock, chunk, buf)
        if rx.search(bytes(buf).decode('latin1')):
            break
    return bytes(buf).decode('latin1')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('commands', nargs='*')
    ap.add_argument('--host', default='46.0.0.2')
    ap.add_argument('--user', default='root')
    ap.add_argument('--wait', type=float, default=60.0,
                    help='seconds to keep retrying the connection')
    ap.add_argument('--timeout', type=float, default=120.0,
                    help='seconds to wait for each command')
    ap.add_argument('--prompt', default=r'[a-z]+\([0-9]+\) $|\n# $|\n% $',
                    help='regex that matches the shell prompt')
    ap.add_argument('--file', help='read commands from this file, one per line '
                                   '(avoids the host shell eating quotes)')
    a = ap.parse_args()

    if a.file:
        with open(a.file) as f:
            a.commands = [ln.rstrip('\n') for ln in f
                          if ln.strip() and not ln.lstrip().startswith('##')]

    deadline = time.time() + a.wait
    sock = None
    while time.time() < deadline:
        try:
            sock = socket.create_connection((a.host, 23), timeout=5)
            break
        except OSError as e:
            last = e
            time.sleep(3)
    if sock is None:
        print('could not connect to %s: %s' % (a.host, last), file=sys.stderr)
        return 1

    print(read_until(sock, r'login:', 90), end='')
    sock.sendall(a.user.encode() + b'\r\n')
    banner = read_until(sock, r'[#$%] $|\([0-9]+\) $|Password:', 90)
    print(banner, end='')
    if 'Password:' in banner:
        sock.sendall(b'\r\n')
        banner += read_until(sock, r'[#$%] $|\([0-9]+\) $|TERM = ', 60)
        print(banner[-200:], end='')

    # csh's login script asks the terminal type; accept the default
    if 'TERM = ' in banner:
        sock.sendall(b'\r\n')
        print(read_until(sock, a.prompt, 60), end='')

    for cmd in a.commands:
        print('\n===> %s' % cmd)
        sock.sendall(cmd.encode() + b'\r\n')
        out = read_until(sock, a.prompt + r'|Password:', a.timeout)
        print(out, end='')
        # su and friends ask for a password; these accounts have none
        if out.rstrip().endswith('Password:'):
            sock.sendall(b'\r\n')
            print(read_until(sock, a.prompt, a.timeout), end='')

    sock.sendall(b'exit\r\n')
    time.sleep(1)
    sock.close()
    return 0


if __name__ == '__main__':
    sys.exit(main())
