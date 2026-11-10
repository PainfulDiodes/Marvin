    PUBLIC con_getchar

    EXTERN CONSOLE_STATUS, CONSOLE_STATUS_USB, CONSOLE_STATUS_BEANBOARD
    PUBLIC con_readchar
    PUBLIC con_putchar
    PUBLIC con_puts

    EXTERN usb_readchar
    EXTERN usb_putchar
    EXTERN key_readchar
    EXTERN lcd_putchar
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
    xor a               ; return 0 (consume keypress)
    jr @end
@usb:
    call usb_readchar
@end:
    pop hl
    ret

; sent character in A to the console
con_putchar:
    push bc
    push hl
    ld b,a
    ld hl,CONSOLE_STATUS
    ld a,CONSOLE_STATUS_BEANBOARD
    and (hl)
    jr nz,@keyboard
    ld a,CONSOLE_STATUS_USB
    and (hl)
    jr nz,@usb
    jr @done
@keyboard:
    ld a,b
    call lcd_putchar
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
    ; get character from string
    ld a,(hl)
    ; is it zero?
    cp 0
    ; yes
    jr z, @end
    ; no: send character
    call con_putchar
    ; next character position
    inc hl
    ; loop for next character
    jp @loop
@end:
    pop hl
    ret
