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
                xterm and a clock. Does NOT hand the mouse to the machine.

start-x11-mouse.sh
                The same, but with the mouse. While the pointer is over the
                window MAME keeps it: see below.

check.sh        No window. Boots, verifies X11 is on screen, moves the mouse,
                opens the menu with both buttons, halts in order, and says
                GREEN or RED. Evidence goes to shots/.

stop.sh         Halts AOS in order (sync, sync, /etc/fasthalt) and then closes
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
    /etc/fasthalt

and only then closes the emulator. In the window you will see

    syncing disks... done
    halting (via wait)

fasthalt rather than halt leaves a /fastboot file on the disk, and with that
there the next boot skips the filesystem check entirely: /etc/rc says "Fast
boot ... skipping disk checks" instead of "Automatic reboot in progress" and
the fsck that follows it. So if you always stop this way, you never wait for
a check again.

Killing the emulator with the filesystem mounted leaves it dirty, leaves no
/fastboot, and the next boot spends a while repairing with fsck. It does not
corrupt the disk, but it wastes time.

If something wedges and stop.sh does not answer, the way out is

    pkill -f "mame[/]rtpc"

and then let the next boot repair.


  NO WARNING SCREENS, AND THE POINTER
------------------------------------------------------------------------------

MAME shows a warning screen and waits for a keypress for any system carrying
warning flags, and the red one cannot be turned off from the command line:
skip_warnings in ui.ini only suppresses repeats, for a few days. Since this
harness has to start on its own, build MAME with patch/03, which clears the
flags on the RT PC drivers. Then there is nothing to press.

The pointer is the other thing to know about. With start-x11-mouse.sh, MAME
keeps the pointer while it is over the window, and no single key gives it
back: in MAME's own code (sdl_osd_interface::should_hide_mouse) the pointer
is released when the emulation is paused or when the pointer is outside the
window. So: Insert, then P to pause, move the pointer away, P again to carry
on. From a terminal ./stop.sh always works.


------------------------------------------------------------------------------
  USING THE MACHINE
------------------------------------------------------------------------------

Users: root and guest, neither with a password, on a disk installed the way
../docs/INSTALL.md describes.

The keyboard in the window is the RT PC one. Two keys to watch:
  erase is Ctrl-H, not backspace
  interrupt is Ctrl-C

To get the pointer back from MAME's window, see the section above.

The RT PC mouse has TWO buttons. The middle one, which is where uwm keeps its
menus, is both at once:

  left button    on a window with Alt   moves it
  both buttons   on the background      brings up the WindowOps menu
  right button   on the background      raises the window underneath

"New Window" in that menu starts another xterm: uwm then asks where to put it,
so move the mouse and press the left button to drop it there.
