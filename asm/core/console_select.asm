    PUBLIC console_select

    EXTERN CONSOLE_STATUS_USB, CONSOLE_STATUS_BEANBOARD

    ; RAM variables: console_select_ram.asm

    EXTERN key_modifiers
    EXTERN MOD_KEY_SHIFT, MOD_KEY_CONTROL

; marks CONSOLE_STATUS as set by an earlier boot - SRAM keeps it through a reset, not a power cycle
_CONSOLE_MAGIC_VALUE equ 0x4D56     ; "VM" in memory

; determine which console should be active:
;   Shift-Reset → USB
;   Ctrl-Reset  → beanboard (local keyboard and display)
;   Reset       → the previous console, if the magic number shows CONSOLE_STATUS was set
;                 by an earlier boot; otherwise (power-up) beanboard
console_select:
    ; check for modifier keys being held down
    call key_modifiers
    ld b,a
    ; shift key down?
    and MOD_KEY_SHIFT
    ld a,CONSOLE_STATUS_USB
    jr nz,@set
    ; control key down?
    ld a,b
    and MOD_KEY_CONTROL
    jr nz,@beanboard
    ; no modifier - was the console set by an earlier boot?
    ld hl,(_CONSOLE_MAGIC)
    ld de,_CONSOLE_MAGIC_VALUE
    ; clear the carry flag so sbc works as needed
    or a        
    sbc hl,de
    jr nz,@beanboard
    ; yes - keep it, if it is a valid console
    ld a,(CONSOLE_STATUS)
    cp CONSOLE_STATUS_USB
    jr z,@set
    cp CONSOLE_STATUS_BEANBOARD
    jr z,@set
@beanboard:
    ld a,CONSOLE_STATUS_BEANBOARD
@set:
    ld (CONSOLE_STATUS),a
    ld hl,_CONSOLE_MAGIC_VALUE
    ld (_CONSOLE_MAGIC),hl
    ret
