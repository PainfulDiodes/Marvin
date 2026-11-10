; console_select_ram.asm - RAM for console selection
; Included in the target's RAM section at the end of its marvin.asm

    PUBLIC CONSOLE_STATUS

CONSOLE_STATUS:     DEFS 1                  ; active console (CONSOLE_STATUS_USB / CONSOLE_STATUS_BEANBOARD)
_CONSOLE_MAGIC:     DEFS 2                  ; magic number: CONSOLE_STATUS was set by an earlier boot (console_select.asm)
