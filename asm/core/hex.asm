    PUBLIC hex_byte_val
    PUBLIC con_putchar_hex

    EXTERN con_putchar

; string subroutines

; read 2 ASCII hex chars from memory by HL pointer, return converted value in A and advance HL pointer
hex_byte_val:
    ; preserve BC
    push bc
_hex_byte_val_skip_space:
    ; load 1st character from memory
    ld a,(hl)
    ; skip spaces
    cp ' '
    jr nz,_hex_byte_val_read
    inc hl
    jr _hex_byte_val_skip_space
_hex_byte_val_read:
    ; end of string?
    cp 0
    ; yes: no value - return zero
    jr z,_hex_byte_val_zero
    ; no:
    ; advance the buffer pointer
    inc hl
    ; convert first hex digit
    call hex_val
    ; shift left 4 bits to put value into top nibble
    sla a
    sla a
    sla a
    sla a
    ; cache the result
    ld b,a
    ; load 2nd character from memory
    ld a,(hl)
    ; end of string?
    cp 0
    ; yes: incomplete byte - return zero 
    jr z,_hex_byte_val_zero
    ; advance the buffer pointer
    inc hl
    ; and convert 2nd hex digit
    call hex_val         
    ; add first and second digits
    add a,b
    ; restore BC
    pop bc
    ret
_hex_byte_val_zero:
    ; zero return value
    ld a,0
    ; restore BC
    pop bc
    ret

; convert an ASCII hex char in A to a number value (lower 4 bits)
hex_val:
    ; is it lowercase alphabetic?
    cp 'a'                  
    ; no: uppercase/numeric
    jr c,_hex_val_u_n
    ; yes: alphabetic
    sub 'a'-0x0a
    ret
_hex_val_u_n:
    ; is it uppercase alphabetic?
    cp 'A'
    ; no: numeric
    jr c,_hex_val_n       
    ; y:
    sub 'A'-0x0a
    ret
_hex_val_n:
    ; numeric
    sub '0'
    ret

; convert value in A into an ASCII pair and send to console
con_putchar_hex:
    push af
    push bc
    ; stash in B
    ld b,a
    ; shift A right x4 e.g. transform 10110010 to 00001011
    srl a
    srl a
    srl a
    srl a
    ; most significant digit
    call _putchar_hex_dgt
    ; recover from stash
    ld a,b
    ; clear the top 4 bits
    and 0b00001111
    ; least significant digit
    call _putchar_hex_dgt
    pop bc
    pop af
    ret
_putchar_hex_dgt:
    ; is it an alpha or numeric?
    cp 0x0a
    ; numeric
    jr c,_putchar_hex_n
    ; alpha
    ; for alpha add the base ascii for 'a' but then sub 10 / 0x0a as hex 'a' = 10d
    add a,'a'-0x0a
    call con_putchar
    ret
_putchar_hex_n:
    ; for numeric add the base ascii for '0'
    add a,'0'
    call con_putchar
    ret
