; string.asm - string and display utility functions

    PUBLIC con_putchar_dec
    PUBLIC hex_byte_val
    PUBLIC con_putchar_hex

    EXTERN con_putchar

; con_putchar_dec: print byte A as decimal digits (0-255), no leading zeros
; in:  A = value
; out: —
; destroys: AF, BC
con_putchar_dec:
    push af
    push bc
    ld b, 0                     ; hundreds digit
    ld c, 0                     ; tens digit
@hundreds:
    cp 100
    jr c, @tens
    sub 100
    inc b
    jr @hundreds
@tens:
    cp 10
    jr c, @units
    sub 10
    inc c
    jr @tens
@units:
    push af                     ; save units digit
    ld a, b
    or a
    jr z, @no_hundreds
    add a, '0'
    call con_putchar            ; hundreds
    ld a, c
    add a, '0'
    call con_putchar            ; tens (always printed if hundreds printed)
    jr @print_units
@no_hundreds:
    ld a, c
    or a
    jr z, @print_units
    add a, '0'
    call con_putchar            ; tens
@print_units:
    pop af
    add a, '0'
    call con_putchar            ; units
    pop bc
    pop af
    ret

; hex_byte_val: read 2 ASCII hex chars from memory at HL, return converted value in A and advance HL
; in:  HL = pointer to hex string
; out: A = byte value, HL advanced past the 2 chars (or unchanged on empty string)
; destroys: AF, HL
hex_byte_val:
    push bc
@skip_space:
    ld a, (hl)
    cp ' '
    jr nz, @read
    inc hl
    jr @skip_space
@read:
    cp 0
    jr z, @zero
    inc hl
    call _hex_val
    sla a
    sla a
    sla a
    sla a
    ld b, a
    ld a, (hl)
    cp 0
    jr z, @zero
    inc hl
    call _hex_val
    add a, b
    pop bc
    ret
@zero:
    ld a, 0
    pop bc
    ret

; _hex_val: convert ASCII hex char in A to a 4-bit nibble value
; in:  A = ASCII hex character ('0'-'9', 'a'-'f', 'A'-'F')
; out: A = nibble value (0-15)
; destroys: AF
_hex_val:
    cp 'a'
    jr c, @upper_or_digit
    sub 'a'-0x0a
    ret
@upper_or_digit:
    cp 'A'
    jr c, @digit
    sub 'A'-0x0a
    ret
@digit:
    sub '0'
    ret

; con_putchar_hex: print byte A as two lowercase hex digits
; in:  A = value
; out: —
; destroys: AF, BC
con_putchar_hex:
    push af
    push bc
    ld b, a
    srl a
    srl a
    srl a
    srl a
    call _putchar_hex_digit
    ld a, b
    and 0x0F
    call _putchar_hex_digit
    pop bc
    pop af
    ret

_putchar_hex_digit:
    cp 0x0a
    jr c, @numeric
    add a, 'a'-0x0a
    call con_putchar
    ret
@numeric:
    add a, '0'
    call con_putchar
    ret
