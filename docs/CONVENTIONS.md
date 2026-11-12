# Conventions

## Coding

Labels come in three kinds:

- **Public** — no prefix, declared `PUBLIC`. Functions (addresses that end in a `ret`) are lowercase, e.g. `con_puts`; data labels and constants are uppercase, e.g. `WELCOME_MSG`
- **Private** — `_` prefix, never `PUBLIC`: private helper functions (lowercase) and private data (uppercase), e.g. `_parse_filename`, `_MSG_NO_DRIVE`. A target's Marvin files assemble as one module, so a `_` label must be unique across the whole module: name it for its subsystem or parent function, e.g. `_file_write_scan_dir`, `_key_rowscan`
- **Local** — `@` prefix: jump targets inside a function, scoped by z80asm to the previous ordinary label, e.g. `@loop`, `@exit`. They only need to be unique within their function, so they are short. The BBC BASIC layer uses them in uppercase, e.g. `@LOOP`

Labels use full words, not abbreviations.

## Build / Structural Conventions

Marvin source files use lowercase names with underscores and live under `asm/`, grouped by role: `asm/core/`, `asm/drivers/`, `asm/bdfs/`.

The BBC BASIC layer (`ENTRY.asm`, `HOOK.asm`, `MOS.asm`) uses uppercase names matching BBC BASIC conventions and lives in `asm/BBCZ80/`.

Each target has a directory `asm/targets/<target>/` holding `marvin.asm` (includes all of the target's Marvin code as one module), `config.inc` (hardware flags), `boot.asm` (the boot sequence; the vectors and trampoline table are shared in `asm/core/entry.asm`), and as needed `console.asm`, `messages.asm` and the `mos.asm` wrapper.

`INCLUDE` paths are written in full from the repo root, e.g. `INCLUDE "asm/core/chars.inc"`. An `.inc` that can be included more than once in a module has an `IFNDEF` guard.

Feature flags are `DEFC` symbols in the target's `config.inc`, tested with `IFDEF`. `HAS_*` flags describe hardware the target has (`HAS_LCD`, `HAS_KEYBOARD`, `HAS_RA8875`, `HAS_FLASH`). `INCLUDE_BASIC` is the one build choice, set by `basic.lst` for builds with BBC BASIC.

The trampoline table (ABI) is in `asm/core/entry.asm`, after the reset and RST vectors. Addresses must match `abi/marvin.inc`; a hardware-dependent entry is `IFDEF <flag>` / `jp <function>` / `ELSE` / `jp _stub` / `ENDIF`, so every address is the same on every target.

Each build is described by a manifest in `manifests/`, `<target>.lst` or `<target>_minimal.lst`: a z80asm project list, listing its separately assembled modules in link order. List files hold sources and other list files only; assembler options stay in `build.sh`, apart from the two `-D` options in `basic.lst`.
