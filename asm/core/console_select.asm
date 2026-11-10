    PUBLIC console_select

    EXTERN CONSOLE_STATUS_USB, CONSOLE_STATUS_BEANBOARD

    ; RAM variables: console_select_ram.asm

    EXTERN key_modifiers
    EXTERN MOD_KEY_SHIFT

; determine which console should be active - Reset=beanboard, shift-Reset=USB
console_select:
    ; check for modifier keys being held down
    call key_modifiers
    ; shift key down?
    and MOD_KEY_SHIFT
    ; yes shift
    jp nz,@usb
    ; no shift
    ld a,CONSOLE_STATUS_BEANBOARD
    ld hl,CONSOLE_STATUS
    ld (hl),a
    ret
@usb:
    ld a,CONSOLE_STATUS_USB
    ld hl,CONSOLE_STATUS
    ld (hl),a
    ret
