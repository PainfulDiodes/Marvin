# Marvin 1.5

Firmware for the BeanZee Z80 family: a simple [monitor program](./monitor.md), with submodule extensions.

## Hardware Targets

- [beanzee](https://github.com/PainfulDiodes/BeanZee) is a small Z80 single board computer which is accessible only via a USB interface and a host computer with a console emulator
- [beanboard](https://github.com/PainfulDiodes/BeanBoard) adds a small LCD display and self-contained keyboard to BeanZee, providing direct interaction with the computer in addition to USB; there's also a GPIO to facilitate experimentation
- *beandeck* is a *work-in-progress* and incorporates [BeanBoardSPI](https://github.com/PainfulDiodes/BeanBoardSPI) through which a 7" 800x480 colour TFT and flash storage is added to the beanboard, making a self-contained Z80 computer (BeanBoard LCD display is removed to install this board)
- *beandeck_reva* incorporates [BeanBoardSPI Rev A](https://github.com/PainfulDiodes/BeanBoardSPI/tree/v1-rev-a) - the original revision of the board which should NOT be used, and is provided for interest only - this first revision requires software delays while hardware serialisation occurs, whereas subsequent revisions poll a status register

## Submodules

The build optionally embeds *RT Russell's [BBCZ80](https://github.com/PainfulDiodes/BBCZ80) BASIC interpreter* in a git submodule.

Marvin provides the glue between BBCZ80 and the hardware. Marvin console I/O and BFDS filesystem are connected:`SAVE` and `LOAD` read and write BDFS files and `*` commands are dispatched to the Marvin monitor (e.g. file directory)

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

Each build produces `build/<name>.bin`, plus `.hex` hex dump and `.ihx` (Intel HEX). z80asm's working files (`.o`, `.lis`, `.map`) go in `build/tmp/`. `./clean.sh` removes `build/`.

For each target there is a main output which includes the BASIC interpreter, and in addition a `minimal` output which contains only the monitor program.

To program an EEPROM with a [minipro](https://gitlab.com/DavidGriffith/minipro) programmer, pass the binary to the script for the device:

```bash
./burn-AT28C256.sh build/beanzee.bin
./burn-AT28C64B.sh build/beanzee_minimal.bin
```

### How a build is put together

- `<name>.lst` (repo root) — a z80asm project list: the separately assembled modules for one build, in link order. `build.sh` passes it to z80asm as `@<name>.lst`
- `basic.lst` — the BBC BASIC modules, shared by every BASIC build. Including it also sets `-DINCLUDE_BASIC`, which is what makes a build a BASIC build
- `asm/targets/<target>/marvin.asm` — all of Marvin's own code for a target, as one module: it `INCLUDE`s the target's `config.inc` and every Marvin source file the target uses, in order
- `asm/targets/<target>/config.inc` — the hardware the target has, as `DEFC` flags: `HAS_LCD`, `HAS_KEYBOARD`, `HAS_RA8875`, `HAS_FLASH`
- `asm/targets/<target>/entry.asm` — reset and RST vectors, the trampoline table (from `asm/core/trampoline.asm`) and the boot sequence
- `asm/targets/<target>/mos.asm` — wrapper that assembles the shared `asm/BBCZ80/MOS.asm` with the target's flags (BASIC builds only)

For example, `beandeck.lst`:

```text
; BeanDeck (BeanBoardSPI Rev B) with BBC BASIC
asm/targets/beandeck/marvin.asm
ra8875-z80-repo/asm/ra8875.asm
ra8875-z80-repo/asm/console.asm
BBCZ80-repo/src/MAIN.asm
@basic.lst
asm/targets/beandeck/mos.asm
```

Source layout:

- `asm/core/` — monitor, console selection, strings, system RAM, messages and the trampoline table
- `asm/drivers/` — hardware drivers (USB, LCD, keyboard, SPI, RA8875 transport, W25Q flash)
- `asm/bdfs/` — the BeanDeck File System and its monitor commands
- `asm/BBCZ80/` — the layer connecting BBC BASIC to Marvin (`ENTRY`, `HOOK`, `MOS`)
- `asm/targets/<target>/` — the target files described above

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

From BASIC you can access BDFS with `SAVE "name.ext"` and `LOAD "name.ext"`. If the filename extension is missed, ".BBC" is assumed. You may also use `*` to run any monitor command.

Return to the monitor with:

- QUIT

## Links

- [BeanZee](https://github.com/PainfulDiodes/BeanZee)
- [BeanBoard](https://github.com/PainfulDiodes/BeanBoard)
- [BeanBoardSPI](https://github.com/PainfulDiodes/BeanBoardSPI)
- [BeanZeeBytes example programs](https://github.com/PainfulDiodes/BeanZeeBytes)
- [Blog](https://painfuldiodes.wordpress.com)
- [RT Russell BBCZ80](https://github.com/rtrussell/BBCZ80)
- [BBC BASIC Z80 Manual](https://www.bbcbasic.co.uk/bbcbasic/mancpm)
