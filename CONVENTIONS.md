# Conventions

## Coding

"Callable" labels - i.e. addresses of functions which will end in a ret code - are in lowercase

Other labels, including jump addresses and data labels are in uppercase

Private labels - those which should not be referenced outside of their file are prefixed with an underscore

## Build / Structural Conventions

Marvin source files use lowercase names with underscores and live under `asm/`, grouped by role: `asm/core/`, `asm/drivers/`.

The BBC BASIC layer (`ENTRY.asm`, `HOOK.asm`, `MOS.asm`) uses uppercase names matching BBC BASIC conventions and lives in `asm/BBCZ80/`.

Each target has a directory `asm/targets/<target>/` holding `marvin.asm` (includes all of the target's Marvin code as one module), `config.inc` (hardware flags), `entry.asm` (vectors, trampoline table and boot), and as needed `console.asm` and `messages.asm`.

`INCLUDE` paths are written in full from the repo root, e.g. `INCLUDE "asm/core/chars.inc"`. An `.inc` that can be included more than once in a module has an `IFNDEF` guard.

Feature flags are `DEFC` symbols in the target's `config.inc`, tested with `IFDEF`. `HAS_*` flags describe hardware the target has (`HAS_LCD`, `HAS_KEYBOARD`, `HAS_RA8875`). `INCLUDE_BASIC` is the one build choice, set by `basic.lst` for builds with BBC BASIC.

The trampoline table (ABI) is in `asm/core/trampoline.asm`. Addresses must match `abi/marvin.inc`; a hardware-dependent entry is `IFDEF <flag>` / `jp <function>` / `ELSE` / `jp _stub` / `ENDIF`, so every address is the same on every target.

Each build is described by a z80asm project list at the repo root, `<target>.lst` or `<target>_minimal.lst`, listing its separately assembled modules in link order. List files hold sources and other list files only; assembler options stay in `build.sh`, apart from the two `-D` options in `basic.lst`.
