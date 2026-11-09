    PUBLIC con_getchar
    PUBLIC con_readchar
    PUBLIC con_putchar
    PUBLIC con_puts

    EXTERN usb_readchar
    EXTERN usb_putchar

; wait for a character and return in A
con_getchar:
    call con_readchar
    cp 0
    ret nz
    jr con_getchar

; read a character from the console and return in A - return 0 if there is no character
con_readchar:
    call usb_readchar
    ret

; sent character in A to the console
con_putchar:
    push bc
    ld b,a
    call usb_putchar
    ld a,b
    pop bc
    ret

; print a zero-terminated string pointed to by hl to the console
con_puts:
    push hl
_puts_loop:
    ; get character from string
    ld a,(hl)
    ; is it zero?
    cp 0
    ; yes
    jr z, _puts_end
    ; no: send character
    call con_putchar
    ; next character position
    inc hl
    ; loop for next character
    jp _puts_loop
_puts_end:
    pop hl
    ret
