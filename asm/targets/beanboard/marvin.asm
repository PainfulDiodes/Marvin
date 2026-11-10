; Marvin - BeanBoard
; Monitor only by default; assemble with -DINCLUDE_BASIC to add BBC BASIC

    INCLUDE "asm/targets/beanboard/config.inc"

    INCLUDE "asm/targets/beanboard/entry.asm"
IFDEF INCLUDE_BASIC
    INCLUDE "asm/BBCZ80/ENTRY.asm"
ENDIF
    INCLUDE "asm/core/system.asm"
    INCLUDE "asm/targets/beanboard/console.asm"
    INCLUDE "asm/core/console_select.asm"
    INCLUDE "asm/drivers/um245r.asm"
    INCLUDE "asm/drivers/hd44780.asm"
    INCLUDE "asm/drivers/keymatrix.asm"
    INCLUDE "asm/core/monitor.asm"
    INCLUDE "asm/core/string.asm"
    INCLUDE "asm/targets/beanboard/messages.asm"

; System RAM - allocated by the linker from SYSTEM_RAMSTART, in the order listed.
; Must stay at the end of the module: z80asm cannot switch back to the code section.
    SECTION marvin_ram
    ORG SYSTEM_RAMSTART
    INCLUDE "asm/core/console_select_ram.asm"
    INCLUDE "asm/drivers/hd44780_ram.asm"
    INCLUDE "asm/drivers/keymatrix_ram.asm"
    INCLUDE "asm/core/monitor_ram.asm"      ; last: the command buffer grows toward the stack
