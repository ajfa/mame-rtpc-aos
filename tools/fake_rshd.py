#!/usr/bin/env python3
"""Minimal rshd that feeds AOS 4.3's network install.

restore.net on the RT runs, on the source host:
    rsh <host> -n -l operator hostname
    rsh <host> -n -l operator /etc/dump 0fs - 20000 <mountpoint>
where <mountpoint> comes from whichdev: "/" for root, "/usr" for user and
"/usr/src" for source. Instead of running dump, this server streams the
matching pre-made dump(8) file.

Protocol order matters: BSD rcmd() sends the stderr port, then WAITS for the
server to connect back to it, and only then sends the user names and the
command. So the callback has to happen before reading anything else, and it
has to come from a privileged port or the client rejects it.

Needs port 514, so run as root:
    sudo python3 fake_rshd.py --dir ~/rtpc/media --bind 46.0.0.1
"""
import argparse, os, socket, socketserver, sys

MAP = {
    '/':         'dump.root',
    '/usr':      'dump.usr',
    '/usr/src':  'srctape.dd',
    '/minroot':  'dump.root',
}


def pick(command, directory):
    """Map a command to a file: the dump mountpoints, or `cat <name>` for
    anything sitting in the served directory (so new files need no restart)."""
    words = command.strip().split()
    if not words:
        return None
    word = words[-1]
    name = MAP.get(word)
    if name is None and words[0].endswith('cat'):
        # serve any plain file by name, without letting the path escape
        name = os.path.basename(word)
    if not name:
        return None
    path = os.path.join(directory, name)
    return path if os.path.exists(path) else None


def connect_from_privileged(host, port, timeout=10):
    """The client checks that the stderr connection comes from a reserved port."""
    last = None
    for src in range(1023, 511, -1):
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            s.bind(('', src))
            s.settimeout(timeout)
            s.connect((host, port))
            return s, src
        except OSError as e:
            last = e
            s.close()
    # not root: fall back to any port so the server can be tested unprivileged
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(timeout)
    s.connect((host, port))
    return s, s.getsockname()[1]


class Handler(socketserver.BaseRequestHandler):
    directory = '.'

    def readz(self):
        buf = bytearray()
        while True:
            c = self.request.recv(1)
            if not c or c == b'\0':
                return bytes(buf).decode('latin1')
            buf += c

    def handle(self):
        peer = self.client_address
        stderr_port = self.readz()
        print(f'[rshd] {peer[0]}:{peer[1]} pide canal de error en {stderr_port!r}', flush=True)

        err = None
        if stderr_port and stderr_port != '0':
            try:
                err, src = connect_from_privileged(peer[0], int(stderr_port))
                print(f'[rshd] canal de error abierto {src} -> {peer[0]}:{stderr_port}', flush=True)
            except Exception as e:
                print(f'[rshd] could not call back: {e}', flush=True)

        locuser = self.readz()
        remuser = self.readz()
        command = self.readz()
        print(f'[rshd] {locuser}/{remuser}: {command!r}', flush=True)

        self.request.sendall(b'\0')          # zero byte: command started

        try:
            if 'hostname' in command:
                self.request.sendall(b'master\n')
                print('[rshd] respondido: master', flush=True)
                return

            path = pick(command, self.directory)
            if not path:
                msg = f'no file for {command!r}\n'
                print('[rshd] ' + msg, flush=True)
                if err:
                    err.sendall(msg.encode())
                return

            size = os.path.getsize(path)
            print(f'[rshd] enviando {path} ({size} bytes)', flush=True)
            sent = 0
            mark = 0
            with open(path, 'rb') as f:
                while True:
                    b = f.read(1 << 16)
                    if not b:
                        break
                    self.request.sendall(b)
                    sent += len(b)
                    if sent - mark >= (1 << 22):
                        mark = sent
                        print(f'[rshd]   {sent >> 20} MB de {size >> 20}', flush=True)
            print(f'[rshd] terminado, {sent} bytes', flush=True)
        except Exception as e:
            print(f'[rshd] error enviando: {e}', flush=True)
        finally:
            if err:
                try:
                    err.close()
                except Exception:
                    pass


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--dir', default='.')
    ap.add_argument('--bind', default='0.0.0.0')
    ap.add_argument('--port', type=int, default=514)
    a = ap.parse_args()
    Handler.directory = os.path.expanduser(a.dir)
    print(f'[rshd] escuchando en {a.bind}:{a.port}, sirviendo {Handler.directory}', flush=True)
    for k, v in MAP.items():
        p = os.path.join(Handler.directory, v)
        print(f'[rshd]   {k:10s} -> {v} {"(ok)" if os.path.exists(p) else "(FALTA)"}', flush=True)
    Server((a.bind, a.port), Handler).serve_forever()
