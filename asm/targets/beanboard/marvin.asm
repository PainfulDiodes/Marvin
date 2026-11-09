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
    INCLUDE "asm/core/hex.asm"
    INCLUDE "asm/targets/beanboard/messages.asm"
