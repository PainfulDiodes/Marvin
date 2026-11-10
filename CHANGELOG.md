# Marvin CHANGELOG

## 1.5

Hardware Support

* BeanBoardSPI Rev B — SPI transport now polls the status register (bit 0 = ~SER_EN) instead of using software delays; `spi_beanboardspi_revb.asm`
* BeanBoardSPI Rev A — SPI transport with NOP delays retained as `spi_beanboardspi_reva.asm`; `beandeck_reva` build target added
* BeanBoard bitbang SPI — `spi_beanboard.asm` placeholder added with GPIO bit-bang framework; MISO sampling not yet implemented, not linked into any build

Drivers

* SPI transport moved from ra8875-z80 submodule into Marvin (`asm/drivers/`); ra8875-z80 `targets/` directory removed and replaced with a stub
* `spi_byte` and `spi_read` are now the shared SPI entry points used by both the RA8875 and W25Q drivers; only one SPI module is linked per build, enforced by duplicate-symbol detection at link time
* `flash_spi_byte` removed from `w25q.asm`; W25Q driver now uses the shared `spi_byte`
* RA8875 transport files renamed to `ra8875_beanboardspi.asm` / `ra8875_beanboard.asm` (driver\_hardwaretarget convention); each is a thin shim providing CS/RESET management and delegating data transfer to `spi_byte`/`spi_read`
* `RA8875_GPIO`, `RA8875_SPI_CTRL`, `RA8875_SPI_DATA` aliases removed from `system.asm`; transport files EXTERN port constants directly
* BeanBoard GPIO pin assignments extracted to `beanboard.inc`; shared between `ra8875_beanboard.asm` and `spi_beanboard.asm`

Build

* `beandeck_reva` build target added (BeanBoardSPI Rev A hardware; uses `spi_beanboardspi_reva` in place of `spi_beanboardspi_revb`)

Source

* Label naming made consistent: jump targets inside a function are now z80asm `@` local labels (e.g. `@loop`), leaving `_` labels for private helpers and data, consistently named so they are unique across the target's module; see `CONVENTIONS.md`. No change to the binaries

## 1.4

Hardware Support

* BeanBoardSPI Rev B - increased software delays (also in ra8875-z80 1.3.1) for serialisation to be compatible with BeanBoardSPI Rev B (with CLK/4) as well as Rev A (with CLK/2).

BeanDeck File System (BDFS) — NOR flash cartridge storage

* W25Q NOR flash driver (`w25q.asm`): JEDEC ID probe, read, sector erase, page program, busy poll, slot selection via `flash_select_slot`. Supports the 6 BeanBoardSPI cartridge slots; supports devices W25Q80–W25Q128 identified by capacity code (although not making full use of the larger devices)
* Layered file system architecture: `w25q.asm`, `bdfs.asm`, `monitor_bdfs.asm` monitor presentation layer
* BDFS filesystem: format, directory iterator (`bdfs_dir_open` / `bdfs_dir_next`), file write, file read, file delete
* CP/M-style drive letters A–F; drive auto-selected on cold start by scanning for first present device
* NOR-correct flags convention: erased state (0xFF) = active; soft-delete programs bit 0 from 1→0 (no sector erase required)
* Write-time guards: file size limit, duplicate filename detection, empty file rejection
* Directory listings include file size alongside filename
* `bdfs_file_read` accepts optional `max_size` in BC (0 = no limit); returns `BDFS_ERR_FILE_TOO_LARGE` if exceeded - used by BBC BASIC LOAD
* New ABI trampoline entries: `flash_read` (0x008B), `flash_page_program` (0x008E), `flash_sector_erase` (0x0091), `flash_select_slot` (0x0094), `bdfs_file_read` (0x00CA), `bdfs_file_delete` (0x00CD)

Monitor commands (BDFS)

* `@A–F` / `@a–f` — select drive; drive letter shown in prompt (`A]`)
* `f [name]` — format current drive (y/n confirmation prompt)
* `d` — directory (active files + deleted count)
* `D` — directory (all entries including deleted)
* `s <n.ext> [<addr> [<len>]]` — save to file (default: RAMSTART, sector size)
* `l <n.ext> [<addr>]` — load from file (default address: RAMSTART)
* `e <n.ext>` — delete file (y/n confirmation prompt)

Monitor improvements

* `?` — help command listing all available commands
* `;` — comment command (line silently ignored)
* Monitor prompt changed from `>` to `]` (to distinguish from BBC BASIC `>` prompt); drive prompt follows suit (`A]`)

BBC BASIC

* `*` commands dispatched to Marvin monitor via `OSCLI` — all monitor commands usable from BASIC (but not all commands the BASIC expects are available)
* `SAVE "name.ext"` writes the current BASIC program to BDFS
* `LOAD "name.ext"` reads a file from BDFS; returns FS errors or BASIC error if file exceeds the load buffer

Build

* `string.asm` consolidates string/decimal/hex helpers (absorbed `hex.asm`)
* Incremental build caching in `build.sh`: BBC BASIC and RA8875 submodule objects skipped when up to date
* `bdfs`, `monitor_bdfs`, `string` modules added to all six build targets (combined + minimal × beanzee, beanboard, beandeck)

## 1.3

BBC BASIC Z80 added as git submodule

* Per-target ENTRY.asm (boot + trampoline functions (ABI) + platform functions) and MOS.asm (Machine Operating System)
* BBC BASIC error handling fixed: MOS RESET changed from RST 0 to RET — errors now print and return to BASIC prompt instead of cold-booting
* BBCZ80 display: shortened BBC BASIC version string to fit 20-character HD44780 LCD on BeanBoard

RA8875 TFT display driver added as git submodule (ra8875-z80)

* Driver split into common core (ra8875.asm) and transport layers: ra8875_spi.asm (BeanBoardSPI hardware SPI), ra8875_gpio.asm (BeanBoard GPIO bit-bang)
* RA8875 wired as beandeck console with hardware vertical scroll and software cursor
* Cursor show/hide via `ra8875_console_cursor_show` / `ra8875_console_cursor_hide` function calls (trampoline function entries 0x0085, 0x0088); SO/SI control characters removed from putchar
* Backspace (0x08 and 0x7F) supported in RA8875 console
* Cursor positioning: ra8875_console_cursor_x / ra8875_console_cursor_y
* Foreground colour support via ra8875_set_foreground_colour
* Console foreground colour set to green on initialisation

Boot

* Power-up debounce delay (~100ms at 10MHz) added at the very start of `_boot` across all six entry files (three regular, three minimal), before any hardware initialisation
* Minimal entry files restructured to use `jp _boot` / `_boot:` after the trampoline functions, matching the regular entry file pattern; fixes latent trampoline function misalignment in `entry_beandeck_minimal.asm`

Keyboard

* Caps lock: lock key toggles `CAPS_LOCK_STATE` (new system RAM byte at 0xF00D); handled in the console layer (beanboard / beandeck)
* Letters a–z uppercased when caps lock is on; non-letter characters (digits, symbols) unaffected
* BeanDeck: cursor colour reflects caps lock state — green (off) / white (on); redrawn immediately on toggle via `ra8875_console_set_cursor_colour` in the ra8875-z80 submodule
* BeanBoard: caps lock state toggled silently; no visual indicator on the LCD

Monitor

* Monitor prompt changed from > to $ (to distinguish it from the BASIC prompt)
* Monitor backspace support in input loop
* `b` launches BBC BASIC cold start, `B` launches warm start — no prompt or extra keypress required; excluded from minimal builds via conditional assembly (IFDEF INCLUDE_BASIC)
* Command buffer backspace fix: spaces in commands now handled in hex parsing rather than skipped on input
* State fix: registers are preserved after monitor commands, but are reinitialised on warmstart

BBC BASIC

* Fixed: quitting BASIC returns to Marvin warm start
* MOS updated to call Marvin functions by labels rather than via trampoline functions

Trampoline functions (ABI)

* Trampoline functions relocated to 0x0040 and extended with RA8875 console entries: `MARVIN_RA8875_CONSOLE_INIT` (0x0073), `MARVIN_RA8875_CONSOLE_PUTCHAR` (0x0076), `MARVIN_RA8875_CONSOLE_CURSOR_X` (0x0079), `MARVIN_RA8875_CONSOLE_CURSOR_Y` (0x007C), `MARVIN_RA8875_CONSOLE_REFRESH_CURSOR` (0x007F), `MARVIN_HEX_BYTE_VAL` (0x0082)

BeanDeck

* Fixed intermittent RA8875 initialisation: increased settle time and tuned boot delays in entry files

Targets

* BeanDeck target added (BeanBoard + BeanBoardSPI; TFT display, hardware keyboard, no LCD)
* BeanBoard: RA8875 GPIO bit-bang driver removed — untested on beanboard hardware; can be added back once validated
* Combined firmware builds for all three targets (beanzee, beanboard, beandeck)
* All targets produce both combined (Marvin + BBC BASIC) and minimal (monitor-only) builds from a single build.sh
* Boot defaults to monitor on all targets; shift-RESET selects USB console on BeanBoard and BeanDeck
* Trampoline functions extended: `MARVIN_KEY_READCHAR` reordered before LCD entries; `MARVIN_RA8875_INIT` (0x0031) and `MARVIN_RA8875_PUTCHAR` (0x0034) added; BeanDeck and BeanBoard entry files realigned to match

Build

* Standalone Marvin build scripts retained for monitor-only ROM images
* system.inc replaced with system.asm compiled module; constants exported as PUBLIC; SPI_CTRL, SPI_DATA, and RA8875 aliases added
* system.asm: system RAM layout cascades from SYSTEM_RAMSTART; RA8875_RAMSTART is an alias; RA8875_RAMSIZE conditionally EXTERNed from ra8875-z80-repo (HAS_RA8875 build flag); beanzee target defines RA8875_RAMSIZE as 0
* burn32k.sh: -m flag for minimal firmware, -8 flag for 8k EEPROM (AT28C64B)
* Repo restructured: hardware drivers in asm/drivers/, BBCZ80/ subdirectories, single root build.sh, boot and ENTRY files separated
* Public labels renamed with module prefix: `getchar`→`con_getchar`, `putchar`→`con_putchar`, `readchar`→`con_readchar`, `puts`→`con_puts`, `putchar_hex`→`con_putchar_hex`, `modifierkeys`→`key_modifiers`
* `modules_for_target()` unified: combined and minimal module lists merged into one function; driver paths inlined
* BBCZ80 interface files (ENTRY.asm, MOS.asm, HOOK.asm) moved from `targets/shared/BBCZ80/` to `asm/BBCZ80/`

## 1.2.1a

* Improve build scripts - build both targets with both assemblers with a single command - heirarchical scripts

## 1.2.1

* Fix LCD scroll/render error - occasionally cursor would land on line 3 and the text would be out of step
* LCD teletype style - always write on line 4 - would simplify the logic
* Added a WARMSTART2 label - dependable entry point across builds - goes to MARVIN prompt without welcome message

## v1.2

* Remove beanboard_proto build target
* Remove keyscan_init so that on reset the last keypress is not repeated on RESET
  * On RESET (and x0) keyscan_init was run which cleared the buffer
  * This meant that any key still held down will register after RESET - meaning an extra keypress is sensed after reset
  * The solution is to simply not clear the buffer - under normal startup a change may be detected, but this will normally be "no keys" and so will have no effect
* Allow for multiple console devices
  * For the BeanZee target, console is fixed to USB
  * For the BeanBoard target, console may be either USB or keyboard/LCD - on RESET we sense for Beanboard shift key to determine which is the active console: shift-RESET=USB, RESET=beanboard
  * This also helps with speeding up loading programs via the USB: LCD echoing seems to significantly slow the USB transfer speed
* Renamed keyscan.asm > keymatrix.asm, keyscan > key_readchar (and associated labels)
* lcd_puts and usb_puts functions
* Build targets were previously kept in sync such that entry point addresses would work across all targets; now build targets (beanzee, beanboard) will not be consistent - beanboard code has been removed from from beanzee target and ALIGN padding between labels has been removed, with the exception of WARMSTART
* Added a WARMSTART label (with ALIGN padding) to fix a consistent warm-start address across all targets
* Revise build scripts to use an output directory (one directory for each supported assembler)
* Fixed Beanboard keyboard debounce delay

## v1.1.0

Add support for BeanBoard  

Tested On: BeanZee v1, BeanBoard prototype, BeanBoard v1  

* Add support for BeanBoard v1  
* Reorganised code: build targets in root, code modules in ASM directory  
* Updated build scripts to simplify multiple build targets and RAM options
  * RAM options are now entirele done with an ORG option on the command line
  * Hardware targets each have their own target asm file
* Source code set convention for 0x and 0b notation rather than $ and %, and prefixing underscores on local labels
* Made labels more specific - e.g. BUFFER => CMD_BUFFER
* Changed labels for escape characters to avoid starting with an underscore
* Changed comment format - avoid comments on same line as code
* Separate builds for BeanZee and BeanBoard, and RAM and ROM variants
* Separate string functions from marvin.asm into strings.asm, and make them safe to call:
  * hex_byte_val
  * hex_val
  * putchar_hex
* Drivers for BeanBoard LCD and keyboard; integrated these into getchar/putchar
* Message length by build target
* Keyboard map for beanboard v1

## v1.0.2

* Changed the handling of CR and LF to be consistent with VT100 terminals / typical defaults for terminal emulators:
  * Expect line termination of input with \r (\n is permitted, but \r\n will be interpreted as an extra empty line)
  * Transmit lines terminated with \r\n
* eXecute without an address will execute from 0x8000 (RAMSTART)
* Build scripts assume z88dk is used by default but sjasmplus is supported

## v1.0.1

Compatibility with z88dk-z80asm and sjasmplus.

## v1.0.0

* Load command
* Case insensitive for hex values
* Tidy memory map

Tested on: BeanZee v1

## v0.9.0

x: eXecute command - enter an address to execute from

Tested on BeanZee v1

## v0.8.0

w: write command - enter an address and string of hex data to memory

Whitespace on commands is now ignored, allowing for human-readable inputs

Tested on BeanZee v1

## v0.7.0

* Completion of "r" command to support passing an address parameter, allow for empty commands, and support Escape key to abandon a command entry
* Passing an address argument to the r command
* Ignore \r in inputs
* Make puts function preserve registers
* Use zero string terminator in buffer rather than \n
* Empty command line is valid - does not generate error
* Escape key support

Tested on BeanZee v1

## v0.6.0

Refactor for Separation Of Concerns - separate out hardware concerns into:

* beanzee.asm - a top level file targetting beanzee/breadboard-computer
* UM245R.asm - console implementation for the UM245R used by beanzee/breadboard-computer

Tested with: Z80 Breadboard Computer v1

## v0.5.0

* Fix to USB status bit tests.  
* Tested with: Z80 Breadboard Computer v1, BeanZee v1

## v0.4.0 Pre-release

## v0.3.0 Pre-release

* Using UM245R, the device isn't immediately ready to write, but we were not checking TXE (D1 at port 0), so added a ready check at the start of the program
* Added a welcome message

## v0.2.0 Pre-release

* The original version was needed to operate entirely within RAM which was first run using an Arduino Mega to provide RAM to the Z80
* This version was altered to run in ROM, separating stack and buffer into RAM
* The original version had an error in that it assumed the stack worked up from a given memory location
* This version understand that the stack works downward though memory and so starts at 0xffff
* Technically this should be 0x0000 as the first PUSH will decrement the SP to 0xffff

## v0.1.0 Pre-release

* This version was needs to operate entirely within RAM  
* It was first run using an Arduino Mega to provide RAM to the Z80  
