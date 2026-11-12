; Marvin - BeanDeck (BeanBoardSPI Rev A)
; Monitor only by default; assemble with -DINCLUDE_BASIC to add BBC BASIC

    INCLUDE "asm/targets/beandeck_reva/config.inc"

    INCLUDE "asm/core/entry.asm"
    INCLUDE "asm/targets/beandeck/boot.asm"
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

; System RAM - allocated by the linker from SYSTEM_RAMSTART, in the order listed.
; Must stay at the end of the module: z80asm cannot switch back to the code section.
    SECTION marvin_ram
    ORG SYSTEM_RAMSTART
    INCLUDE "asm/drivers/ra8875_ram.asm"
    INCLUDE "asm/core/console_select_ram.asm"
    INCLUDE "asm/drivers/w25q_ram.asm"
    INCLUDE "asm/bdfs/bdfs_ram.asm"
    INCLUDE "asm/drivers/keymatrix_ram.asm"
    INCLUDE "asm/core/monitor_ram.asm"      ; last: the command buffer grows toward the stack
