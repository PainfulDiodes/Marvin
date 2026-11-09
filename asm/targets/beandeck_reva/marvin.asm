; Marvin - BeanDeck (BeanBoardSPI Rev A)
; Monitor only by default; assemble with -DINCLUDE_BASIC to add BBC BASIC

    INCLUDE "asm/targets/beandeck_reva/config.inc"

    INCLUDE "asm/targets/beandeck/entry.asm"
IFDEF INCLUDE_BASIC
    INCLUDE "asm/BBCZ80/ENTRY.asm"
ENDIF
    INCLUDE "asm/core/system.asm"
    INCLUDE "asm/targets/beandeck/console.asm"
    INCLUDE "asm/core/console_select.asm"
    INCLUDE "asm/drivers/um245r.asm"
    INCLUDE "asm/drivers/keymatrix.asm"
    INCLUDE "asm/drivers/spi_beanboardspi_reva.asm"
    INCLUDE "asm/drivers/ra8875_beanboardspi.asm"
    INCLUDE "asm/drivers/w25q.asm"
    INCLUDE "asm/bdfs/bdfs.asm"
    INCLUDE "asm/bdfs/monitor_bdfs.asm"
    INCLUDE "asm/core/string.asm"
    INCLUDE "asm/core/monitor.asm"
    INCLUDE "asm/core/messages.asm"
