; ra8875_ram.asm - RAM for the RA8875 console (ra8875 submodule)
; Included in the target's RAM section at the end of its marvin.asm
; The submodule lays out its variables from RA8875_RAMSTART. RA8875_RAMSIZE comes from its
; ra8875.inc, already included in this module by the target's console.asm (the file has no include guard)

    PUBLIC RA8875_RAMSTART

RA8875_RAMSTART:    DEFS RA8875_RAMSIZE     ; RA8875 console variables (layout in ra8875-z80-repo/asm/console.asm)
