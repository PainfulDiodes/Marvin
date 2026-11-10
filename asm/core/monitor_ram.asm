; monitor_ram.asm - RAM for the monitor
; Included last in the target's RAM section at the end of its marvin.asm:
; the command buffer has no fixed size and grows toward the stack

    PUBLIC CMD_BUFFER

CMD_BUFFER:                                 ; command buffer
