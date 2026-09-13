# X11 and the mouse on the emulated RT PC

## The APA8 is a dead end, and knowing that saves days

MAME's RT PC emulates the `amgda` display adapter, which its own source calls
"All-Points-Addressable-8, or APA8". The X server IBM shipped with AOS 4.3 has ddx
drivers for **8514, aed, apa16, ega, vga and mpel**, and none for the APA8. Checked
by string search across all three servers that exist for this machine: the one on the
4.3 tape, the `Xibm.apa16` patch, and the later X11R5 port. Zero occurrences of
`apa8` in any of them.

Of the adapters the server does support, MAME emulates the EGA. So that is the way
in:

```
mame rtpc025 ... -isa3 ega
```

The text console is legible on the EGA, which it is not on the APA8.

## Device nodes

`MAKEDEV` does not create them for you. The major and minor numbers below are the
ones from the `MAKEDEV` script on the distribution itself, not guesses:

```
/etc/mknod /dev/ega    c 0 77
/etc/mknod /dev/ttyega c 0 5
/etc/mknod /dev/msega  c 15 5
/etc/mknod /dev/bus    c 13 0
chmod 666 /dev/ega /dev/ttyega /dev/msega /dev/bus
```

`/dev/bus` is easy to miss: the server opens it and dies with
`open of /dev/bus failed!` without it.

The mouse node name is chosen by the ddx of whichever adapter you are on: EGA looks
for `/dev/msega` (see `egaScrInfo.c`), the AED for `/dev/msaed`, and so on. If it
cannot be opened the server exits with `Error in open of (/dev/msega)`.

## The font index is missing

The tape ships 124 `.snf` fonts and neither `fonts.dir` nor `mkfontdir`. Without the
index the server opens no font at all and clients hang with no error. Build it on
the machine:

```
cd /usr/lib/X11/fonts
ls *.snf > /tmp/l
wc -l < /tmp/l > fonts.dir
sed 's/\(.*\)\.snf/& \1/' /tmp/l >> fonts.dir
```

## Starting the desktop: order matters

**As soon as `Xibm` starts it owns the console keyboard.** Anything typed after that
goes to X as key events, not to the shell that started the server. A script driving
the console therefore has to put the whole desktop on one line, before the server,
and detach it:

```
PATH=/usr/bin/X11:/bin:/usr/bin:/etc; DISPLAY=:0; export PATH DISPLAY
cp /usr/lib/X11/default.uwmrc $HOME/.uwmrc
(Xibm :0 -ega /dev/console > /tmp/xlog 2>&1 & sleep 50;
 xterm -geometry 62x20+8+8 & sleep 25;
 xclock -geometry 120x120+500+8 & sleep 15; uwm &) &
```

The symptom of getting this wrong is X on screen with no clients at all, and the
commands visible on the console underneath.

The server also listens on TCP 6000, so you can drive it from outside the emulator.

## uwm has no menu without a uwmrc

`uwm` starts, shows up in `ps` and responds, but pressing the middle button on the
background does nothing: its compiled in bindings name the `WindowOps` menu and do
not define it. The sample file X11 ships does define it, so copy it before starting
the window manager, as above. Measured with and without: without it, screenshots
taken with the buttons down and up are identical; with it, the menu covers a
measurable part of the screen.

## The mouse has two buttons

MAME emulates the IBM #8426 pointing device (`rtpc_mouse.cpp`) on the locator port of
the keyboard, locator and speaker adapter. It is a **two button** mouse. The kernel
emulates the third with a chord of both, through the `PLANMS_DISC3` line discipline
that the X server itself selects in `rtmouse.c`. So the middle button, which is the
one `uwm` puts its menus on, is **both buttons at once**.

Driving it from MAME's Lua, the ports are `:kls:locc:mouse:X`, `:Y` and `:BTN`, with
masks 0x20 for button 1 and 0x80 for button 2. The axes are relative: the device
reports the difference since the last report, so set the analog value to a running
total and move in small steps.

## Watching the screen from outside

`screen:pixel()` from MAME's Lua is not usable here. It does not fail; it returns
opaque black for every pixel whatever is on screen, and `screen.height` reports 1.
`screen:snapshot()` on the other hand writes a real PNG even with `-video none`, so
the way to know what is on the screen is to count light pixels in that PNG from the
outside. `tools/count-light.py` does it with nothing but `zlib`.

Sampling a grid with **odd** steps, so as not to alias with the dither patterns, the
states come out far apart:

| what is on screen | light points |
| --- | --- |
| AOS text console | about 4 per cent |
| X11 root weave | about 24 per cent |
| a white window on it | about 61 per cent |
| a menu open on top | 328 points more, out of 5576 sampled |

The same trick answers the harder question of when the machine is ready. There is no
fixed time for a 1980s Unix to finish `/etc/rc`: here it ranged from 300 to over 420
emulated seconds depending on the host, and typing early drops the characters into
the tty buffer and ends in `Login incorrect`. MAME produces a byte identical PNG when
the screen has not changed, so **three identical snapshots eighteen seconds apart**
mean the console has stopped printing, which is where the login prompt is waiting.
Two are not enough: `/etc/rc` has quiet stretches longer than that.
