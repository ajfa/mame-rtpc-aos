# Installing AOS 4.3 on the emulated RT PC

Reconstructed from the AOS sources, then checked against IBM's own manual,
*Installing and Operating Academic Operating System 4.3*, December 1988.

The short version: the RT PC installer is a network installer. It boots a miniroot
from floppy, and pulls the distribution over `rsh` from a "master" machine. There is
no way around the network part, because the AOS tapes are `dump(8)` streams and the
miniroot has no tape drive it can reach in MAME.

## 1. The media

The distribution is four pieces:

| piece | what it is |
| --- | --- |
| `miniroot.img` | 1.2 MB floppy, the installation kernel and its tiny root |
| `sautil.img` | 360 KB floppy, the standalone utilities (format, minidisk) |
| `dump.root` | `dump(8)` stream of the root filesystem |
| `dump.usr` | `dump(8)` stream of `/usr` |

`tools/dumpls.py` lists a dump stream and `tools/dumpget.py` pulls files out of it.
They are useful before you install anything: the whole kernel source tree is in
there, and reading `sys/caio/hd.c` is how the disk fix got found.

```
python3 tools/dumpls.py dump.root | head
python3 tools/dumpget.py dump.root out sys/ca/loutil.s sys/caio/hd.c
```

## 2. The partitions are minidisks, not a disklabel

This is the first thing that goes wrong. The RT PC does not use a BSD disklabel. It
keeps a **minidisk directory** on the disk, and the kernel reads that to find
partitions. Without it every partition comes out bogus, `restore` fills the disk
instantly and you get `/mnt: file system full`.

From the standalone utilities:

```
format          # low level format, answer for the drive you attached
minidisk        # then: standard root
```

`standard root` writes the conventional layout: `hd0a` root, `hd0b` swap, `hd0g`
for `/usr`. Use a disk geometry with room to spare; `hd114e` (114 MB) leaves `/usr`
comfortable, a smaller one does not.

## 3. The network side

The miniroot expects a machine called `master` at 46.0.0.1 to serve the dumps over
`rsh`. `/etc/hosts` in the miniroot already maps `master` and `slave`, and you must
use those names: the 4.3BSD resolver of that era does not accept numeric addresses,
so `rsh 46.0.0.1` answers `unknown host`.

Run MAME with `-networkprovider taptun` and give the host side a tap interface at
46.0.0.1, then run `tools/fake_rshd.py` on it.

### The rshd handshake, which is where people get stuck

`rcmd()` in 4.3BSD, and therefore the AOS client, blocks until the server calls
back. The order is not negotiable:

1. server accepts the connection
2. client sends the **stderr port number**, NUL terminated
3. server **connects back to that port immediately, from a source port below 1024**
4. only then does the client send locuser, remuser and the command
5. server sends one NUL byte to say it is happy
6. data flows

Read all four strings before calling back and the install deadlocks with no error on
either side. `tools/fake_rshd.py` does it in the right order; `tools/rcmd_probe.py`
is a fake client that lets you test the server without starting the emulator.

## 4. The restore itself

The miniroot's own installer aborts, because it runs `fsck` and the miniroot kernel
is built `NOFPA`: it dies with `Memory fault` on the line that prints a percentage.
Do the restore by hand instead.

The miniroot's root is mounted read only (`options ROROOT=0x0300`), so `restore`
cannot create its temporary files. Mount the swap partition somewhere writable
first:

```
/etc/mount /dev/hd0b /tmp
```

Then, for each filesystem, `newfs` it, mount it, and pipe the dump in from the
network:

```
cd /mnt
rsh master cat dump.root | restore rf -
```

## 5. After the first boot

The installed system defaults to `hostname=master`, from this line in
`/etc/rc.local`:

```
hostname="${hostname-master}"
```

If your host is also using 46.0.0.1 as `master`, the guest routes that address to
`lo0` and the network appears to break right after a successful install. Set the
name before you reboot:

```
echo hostname=slave > /etc/rc.config
```

## 6. Working on it afterwards

4.3BSD does not let root log in over the network, and the console is slow to drive.
The practical answer is to leave yourself a setuid shell in the root directory
during the install:

```
cp /bin/sh /rsh0
chmod 4755 /rsh0
```

and then run root commands from an ordinary telnet session as `/rsh0 -c "..."`.
Remove it when you are finished if it bothers you. `tools/rtsh.py` is a telnet
client that answers the `TERM = (dumb)` prompt and runs a file of commands, which
beats reading screenshots.
