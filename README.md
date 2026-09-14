# IBM AOS 4.3 on the emulated IBM RT PC

Two MAME fixes that let IBM's **Academic Operating System 4.3** install onto, and
boot from, the hard disk of an emulated **IBM RT PC 6150 model 025**, together with
the tools used to get there: a reader for 4.3BSD `dump(8)` tapes, a minimal `rshd`
that speaks the 1980s BSD handshake, and a headless harness that drives the machine
and reads what is on its screen.

AOS 4.3 is IBM's port of 4.3BSD to the ROMP processor, product number 5799-WZQ. The
kernel on a finished install identifies itself as

```
4.3 BSD UNIX (GENERIC) #0: Sun Dec 18 19:34:42 PST 1988
5799-WZQ (C) Copyright IBM Corporation 1986,1987
```

The `rtpc` driver in MAME is marked `MACHINE_NOT_WORKING`. With the two patches here
it reaches multiuser, runs X11 on an EGA card, and takes mouse input.

**No ROMs and no IBM software are redistributed here.** You need your own copy of the
AOS 4.3 distribution tapes and of the RT PC firmware.

## The two fixes

Both are against MAME at `dab76193` (0.289 development). `patch/rtpc-aos.patch` has
them together; `patch/01-*` and `patch/02-*` have them separately. There is a third
patch, `patch/03-pack-only-no-warning-screens.patch`, which is not a fix and is not
meant for upstream: it clears the warning flags on the RT PC drivers so MAME stops
showing its warning screen and waiting for a keypress, which a harness that has to
start on its own cannot answer. There is no command line option for that screen;
`skip_warnings` in ui.ini only suppresses repeats, and only for a few days.

### 1. `fddda`: the hard disk error register came back on the wrong byte lane

`isa16_fddda_device::hdc_data_r` maps offsets 0 and 1 as a single 16 bit data
register and hand dispatches the error register by mask, but returned it unshifted:

```c
else if (mem_mask == 0xff00U)
        return u16(hdc_error_r()) << 8;   // was: return hdc_error_r();
```

AOS reads the diagnostic result through the high half of the word. Before the fix it
read zero, declared the drive bad, and the kernel died during autoconfiguration:

```
hdc0: diagnose=0x0 ERROR
panic: swap blocks <= 0
```

After it:

```
hdc0 adapter f00001f0 IRQ 14 CPU level 4
hd0 at hdc0 slave 0
```

This is the one that makes the difference between "no disk at all" and a system that
installs and boots.

### 2. `rtpc`: the channel reset register had inverted polarity

`crra_w` reset an adapter slot on the 0 to 1 transition of its bit. AOS resets slots
by writing a **zero** to 0xf0008c40, which is what `sys/ca/loutil.s` in IBM's own
kernel source does, so the reset is active low:

```c
if (!BIT(data, i) && BIT(m_crra, i) && m_slot[i].found())
```

The same applies to the SCC line in `crrb_w`. This one is backed by the AOS source
rather than by an isolated symptom of its own.

## What works

* Boots AOS 4.3 from the emulated hard disk to multiuser and to `login:`.
* Root and ordinary logins, the full 4.3BSD userland, `cc`, the kernel sources.
* Networking through MAME's `taptun` provider, including `telnet`, `rsh` and NFS
  daemons.
* X11 (the MIT R2 tree that IBM shipped) on an EGA card, with `uwm`, `xterm` and
  `xclock`.
* The IBM #8426 mouse: pointer motion, buttons, and the `uwm` menus. Two things
  about it are the host's doing rather than the emulation's. MAME keeps the host
  pointer while it is over the window and no single key gives it back:
  `sdl_osd_interface::should_hide_mouse` releases it only when the emulation is
  paused or the pointer is outside the window, so the way out is Insert then P.
  And if the pointer does not move at all inside AOS, look at the host first: in
  a VirtualBox guest, mouse integration makes the pointer absolute and MAME never
  sees the relative motion this mouse is built on. Turn it off with Host+I.
  `pack/mouse-probe.sh` tells the two cases apart in twenty five seconds.

## What does not work

* **Floating point.** `df` and `fsck` die with `Memory fault` in the routine that
  prints a percentage. Everything that avoids floating point is fine.
* **Floppy, beyond being detected.** The drive is found and attached at boot
  (`fdc0 adapter f00003f2 IRQ 6 CPU level 4`, `fd0: 1.2M drive`, `fd0 at fdc0 slave
  0`), which it was not before the channel reset fix. Actually reading a diskette
  image through it has not been tested.
* **The APA8 display.** Not a MAME problem: the X server IBM shipped with AOS 4.3 has
  drivers for 8514, aed, apa16, ega, vga and mpel, and none for the APA8 that MAME
  emulates. EGA is the only way in. See `docs/X11-AND-MOUSE.md`.

## Getting there yourself

`docs/INSTALL.md` has the whole procedure: formatting the disk, writing the minidisk
directory, and restoring the distribution tapes over the network, all reconstructed
from the AOS sources and then checked against IBM's own manual, *Installing and
Operating Academic Operating System 4.3* (December 1988).

`docs/X11-AND-MOUSE.md` covers the device nodes, the missing font index, the window
manager and the two button mouse.

`docs/STATUS.md` lists what is still open.

## Layout

```
patch/   the two MAME fixes, separately and together
tools/   dump(8) reader and extractor, minimal rshd, telnet driver, screen reader
pack/    headless harness: a Lua driver for the machine and the shell around it
docs/    install procedure, X11 and mouse, status
```

## Requirements

* MAME built from `dab76193` with the patches, or any later revision they still apply
  to. A driver only build is enough:
  `make SUBTARGET=rtpc SOURCES=src/mame/ibm/rtpc.cpp`. Budget 2.5 GB of RAM per
  compile job.
* The ROMs MAME asks for under `rtpc025`, plus `ega` if you want X11.
* The AOS 4.3 distribution tapes.
* Python 3 for the tools.

## License

BSD 3 Clause, the same as MAME. See `LICENSE`.
