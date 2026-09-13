# Status

What the emulated RT PC does and does not do with the patches in `patch/`, as of
MAME `dab76193`.

## Working

| | |
| --- | --- |
| Boot from hard disk | multiuser, `login:`, root and ordinary users |
| Userland | the whole 4.3BSD tree, `cc`, `as`, `ld`, `make`, `vi`, the kernel sources |
| Console | text is legible on the EGA |
| Keyboard | through the matrix; MAME's natural keyboard drops shifted characters on this machine, so hold shift around the key instead |
| Ethernet | `un0`, with MAME's `taptun` provider: telnet, rsh, NFS daemons |
| Display | X11 on the EGA |
| Mouse | motion, both buttons, and the chord that makes the middle one |

## Not working

### Floating point

`df` and `fsck` die with `Memory fault` in the routine that formats a percentage.
Under the miniroot kernel, which is compiled `NOFPA`, `fsck` dies the same way; under
the installed `GENERIC` kernel the same binary prints the percentage fine. So the
gap is in the software floating point path of the ROMP core. Everything that does
not touch floating point behaves.

This is why the AOS installer aborts and the restore has to be done by hand.

### The floppy probe

The `fddda` adapter and its uPD765 work. What fails is the probe AOS runs at boot:
it arms the FDC interrupt through the digital output register and expects the edge
that follows. The 8259 in this machine is programmed edge triggered (`ICW1 = 0x12`,
LTIM clear) and MAME's model does not produce the transition the driver waits for,
so the drive is never attached. A Lua shim can park the probe, which is what the
harness does; there is no upstream fix here.

### The APA8 display

Not an emulation problem. The X server that came with AOS 4.3 has no ddx for the
APA8. See `X11-AND-MOUSE.md`.

### Shared interrupt levels and adapter ID registers

Several adapters share a CPU interrupt level, and the adapter identification
registers are not all modelled. Nothing observed depends on them yet, but they are
the obvious next place to look if a new adapter misbehaves.

## Notes on the emulation that cost time

* Save states are unavailable: the driver has no `MACHINE_SUPPORTS_SAVE`, and a
  state written anyway is 2.5 KB and kills MAME on reload.
* Lua memory taps are garbage collected if you do not keep them in a live table, and
  then quietly count zero. Tap ranges must be word aligned.
* `manager.machine.time.as_double()` does not exist; use `.seconds`.
* MAME rewrites its own `cfg` file on exit, and the memory size of this machine lives
  in there as `:mmu:MCR` config ports. Keep a pristine copy and put it back, or the
  machine silently drops to 4 MB.
