==============================================================================
  Headless harness for AOS 4.3 on the emulated IBM RT PC
==============================================================================

These scripts drive the machine without anyone sitting in front of it: they
boot AOS, log in on the console, bring up X11 on the EGA, work the mouse, and
halt the system in order. They are what the check in check.sh runs, and they
are also a usable way to start the machine day to day.

No ROMs, no disk image and no MAME binary are included. You supply those.


  WHAT HAS TO BE NEXT TO THESE SCRIPTS
------------------------------------------------------------------------------

    mame/rtpc                  MAME built with the patches in ../patch
    roms/                      the ROMs MAME asks for under rtpc025, plus ega
    disk/aos43-installed.chd   your own installed AOS 4.3 disk
    template/rtpc025.cfg       comes with this harness
    keys.lua  rig.lua          come with this harness
    lib/                       optional: shared libraries to run MAME with

The tools directory of the repository has to stay one level up, because
common.sh calls ../tools/count-light.py to read the screenshots.

python3 has to be installed. The scripts use it to look at the snapshots MAME
writes and work out how far the boot has got.

The directory name cannot contain spaces.


  THE SCRIPTS
------------------------------------------------------------------------------

start-aos.sh    Boots in a window and leaves a root shell on the console.

start-x11.sh    Boots, logs in, and brings up X11 on the EGA with uwm, an
                xterm and a clock. From then on the real mouse drives the
                RT PC one.

check.sh        No window. Boots, verifies X11 is on screen, moves the mouse,
                opens the menu with both buttons, halts in order, and says
                GREEN or RED. Evidence goes to shots/.

stop.sh         Halts AOS in order (sync, sync, /etc/halt) and then closes the
                emulator. This is the right way to finish.

reset.sh        Throws the working disk away and goes back to the installed
                original.

The disk actually used is a copy (disk/work.chd) made on the first run. The
original is never touched.


  HOW TO SHUT DOWN
------------------------------------------------------------------------------

Run stop.sh and wait for it to say "Down". It types this on the AOS console:

    sync
    sync
    /etc/halt

and only then closes the emulator. In the window you will see

    syncing disks... done
    halting (via wait)

Killing the emulator with the filesystem mounted leaves it dirty and the next
boot spends a while repairing it with fsck. It does not corrupt the disk, but
it wastes time.

If something wedges and stop.sh does not answer, the way out is

    pkill -f "mame[/]rtpc"

and then let the next boot repair.


  THE TWO MAME WARNING SCREENS
------------------------------------------------------------------------------

The two scripts that open a window show TWO warning screens before the machine
runs: the system information one and the red "known problems" one. Press a key
on each. The red one appears because the RT PC driver is marked as not working
in MAME, and there is no option to suppress it. check.sh never shows them
because it runs with no video at all.


  USING THE MACHINE
------------------------------------------------------------------------------

Users: root and guest, neither with a password, on a disk installed the way
../docs/INSTALL.md describes.

The keyboard in the window is the RT PC one. Two keys to watch:
  erase is Ctrl-H, not backspace
  interrupt is Ctrl-C

To release the mouse from MAME's window, press Insert.

The RT PC mouse has TWO buttons. The middle one, which is where uwm keeps its
menus, is both at once:

  left button    on a window with Alt   moves it
  both buttons   on the background      brings up the WindowOps menu
  right button   on the background      raises the window underneath

"New Window" in that menu starts another xterm: uwm then asks where to put it,
so move the mouse and press the left button to drop it there.
