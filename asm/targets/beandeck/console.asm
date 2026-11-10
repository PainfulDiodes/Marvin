    PUBLIC con_getchar

    EXTERN CONSOLE_STATUS, CONSOLE_STATUS_USB, CONSOLE_STATUS_BEANBOARD
    PUBLIC con_readchar
    PUBLIC con_putchar
    PUBLIC con_puts

    INCLUDE "asm/ra8875.inc"

    EXTERN usb_readchar
    EXTERN usb_putchar
    EXTERN key_readchar
    EXTERN ra8875_console_putchar
    EXTERN ra8875_console_puts
    EXTERN ra8875_console_set_cursor_colour
    EXTERN CAPS_LOCK_STATE, QWERTY_CAPS

; wait for a character and return in A
con_getchar:
    call con_readchar
    cp 0
    ret nz
    jr con_getchar

; read a character from the console and return in A - return 0 if there is no character
con_readchar:
    push hl
    ld hl,CONSOLE_STATUS
    ld a,CONSOLE_STATUS_BEANBOARD
    and (hl)
    jr nz,@keyboard
    ld a,CONSOLE_STATUS_USB
    and (hl)
    jr nz,@usb
    jr @end
@keyboard:
    call key_readchar
    cp QWERTY_CAPS
    jr nz,@end
    ; toggle caps lock state
    ld a,(CAPS_LOCK_STATE)
    xor 0x01
    ld (CAPS_LOCK_STATE),a
    ; set cursor colour to reflect new caps lock state
    or a                                ; test new value (flags survive the ld above)
    ld a,RA8875_COL_WHITE
    jr nz,@caps_colour                  ; caps on: use white
    ld a,RA8875_COL_GREEN               ; caps off: use green
@caps_colour:
    call ra8875_console_set_cursor_colour
    xor a               ; return 0 (consume keypress)
    jr @end
@usb:
    call usb_readchar
@end:
    pop hl
    ret

; send character in A to console
con_putchar:
    push bc
    push hl
    ld b,a
    ld hl,CONSOLE_STATUS
    ld a,CONSOLE_STATUS_BEANBOARD
    and (hl)
    jr nz,@ra8875
    ld a,CONSOLE_STATUS_USB
    and (hl)
    jr nz,@usb
    jr @done
@ra8875:
    ld a,b
    call ra8875_console_putchar
    jr @done
@usb:
    ld a,b
    call usb_putchar
@done:
    ld a,b
    pop hl
    pop bc
    ret

; print a zero-terminated string pointed to by hl to the console
con_puts:
    push hl
@loop:
    ld a,(hl)
    cp 0
    jr z,@end
    call con_putchar
    inc hl
    jp @loop
@end:
    pop hl
    ret
