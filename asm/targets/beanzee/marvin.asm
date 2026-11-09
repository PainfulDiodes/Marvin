; Marvin - BeanZee
; Monitor only by default; assemble with -DINCLUDE_BASIC to add BBC BASIC

    INCLUDE "asm/targets/beanzee/config.inc"

    INCLUDE "asm/targets/beanzee/entry.asm"
IFDEF INCLUDE_BASIC
    INCLUDE "asm/BBCZ80/ENTRY.asm"
ENDIF
    INCLUDE "asm/core/system.asm"
    INCLUDE "asm/targets/beanzee/console.asm"
    INCLUDE "asm/drivers/um245r.asm"
    INCLUDE "asm/core/monitor.asm"
    INCLUDE "asm/core/hex.asm"
    INCLUDE "asm/core/messages.asm"
