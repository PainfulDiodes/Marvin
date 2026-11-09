# Marvin 1.3

Firmware for the BeanZee Z80 family: a simple [monitor program](./monitor.md), with submodule extensions.

## Hardware Targets

- [beanzee](https://github.com/PainfulDiodes/BeanZee) is a small Z80 single board computer which is accessible only via a USB interface and a host computer with a console emulator
- [beanboard](https://github.com/PainfulDiodes/BeanBoard) adds a small LCD display and self-contained keyboard to BeanZee, providing direct interaction with the computer in addition to USB; there's also a GPIO to facilitate experimentation
- *beandeck* is a *work-in-progress* and incorporates [BeanBoardSPI](https://github.com/PainfulDiodes/BeanBoardSPI) through which a 7" 800x480 colour TFT and flash storage is added to the beanboard, making a self-contained Z80 computer

## Submodules

The build optionally embeds *RT Russell's [BBCZ80](https://github.com/PainfulDiodes/BBCZ80) BASIC interpreter* in a git submodule.

Marvin provides the glue between BBCZ80 and the hardware - *currently the integration is a work-in-progress - I have not attempted anything beyond the simplest of BASIC test programs*.

A second [ra8875-z80 driver](https://github.com/PainfulDiodes/ra8875-z80) git submodule is added for the beandeck target. This provides low-level interaction with an Adafruit RA8875 TFT controller, configured for an 800x480 TFT display, and a simple console layer for the display supporting a software cursor, wrapping and scrolling.

## Building

Requires [z88dk](https://github.com/z88dk/z88dk) (z88dk-z80asm).

Clone repo with submodules:

```bash
git clone --recurse-submodules https://github.com/PainfulDiodes/marvin.git
```

The build scripts assemble all submodule sources directly — you do not need to build the submodules separately. Run them from the repo root. To build everything:

```bash
./build-all.sh
```

To build one firmware image, name its `.lst` file:

```bash
./build.sh beanzee
./build.sh beanzee_minimal
```

Output binaries are placed in `build/`.

For each target there is a `<target>` output which includes the BASIC interpreter, and in addition a `<target>_minimal` output which contains only the monitor program.

## Memory Map

- 0x0000 - 0x7FFF : 32k ROM (firmware)
- 0x8000 - 0xEFFF : User program area
- 0xF000 - 0xFFFF : System RAM (monitor use + stack)

Stack starts at 0xFFFF (working down).

## Trampoline Functions (ABI)

Fixed ROM entry point addresses for target-independent access from Z80 assembly and C programs: [abi/marvin.inc](./abi/marvin.inc)

Each entry is a `JP` trampoline at a fixed address. Entries not supported on a given target are stubs that return immediately without hanging.

**Usage (z88dk assembly):**

```asm
INCLUDE "marvin.inc"

    LD HL, message
    CALL MARVIN_PUTS    ; write string to active console

message: DEFM "Hello!\n", 0
```

## Monitor Commands

See: [monitor](./monitor.md)

## BBC BASIC

RT Russell's Z80 BASIC interpreter can be launched from the monitor prompt:

- `b` - cold start (clears variables and program)
- `B` - warm start (retains existing program)

From BASIC you can return to the monitor with:

- `*MON`

## Links

- [BeanZee](https://github.com/PainfulDiodes/BeanZee)
- [BeanBoard](https://github.com/PainfulDiodes/BeanBoard)
- [BeanBoardSPI](https://github.com/PainfulDiodes/BeanBoardSPI)
- [BeanZeeBytes example programs](https://github.com/PainfulDiodes/BeanZeeBytes)
- [Blog](https://painfuldiodes.wordpress.com)
- [RT Russell BBCZ80](https://github.com/rtrussell/BBCZ80)
- [BBC BASIC Z80 Manual](https://www.bbcbasic.co.uk/bbcbasic/mancpm)
