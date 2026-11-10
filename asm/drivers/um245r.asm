    INCLUDE "asm/core/chars.inc"

    EXTERN UM245R_CTRL, UM245R_DATA

    PUBLIC usb_readchar
    PUBLIC usb_putchar
    PUBLIC usb_puts

; It is assumed that UM245R status signals are gated to the data bus as an IO port where:
; /TXE = bit 0
; /RXF = bit 1 
; As per:
; https://github.com/PainfulDiodes/z80-breadboard-computer
; 
; line endings are translated:
; incoming line endings from the terminal are expected to be \r 
; and are tranlslated to \n
; (\r\n would count as 2 line endings)
; and outgoing line endings are sent as \r\n
; externally this is consistent with VT100/ANSI terminal behaviour
; and internally line endings are always \n

; get character and return in A
usb_readchar:
    ; get the USB status
    in a,(UM245R_CTRL)
    ; data to read? (active low)
    bit 1,a
    ; no, the buffer is empty
    jr nz,@no_char
    ; yes, read the received char
    in a,(UM245R_DATA)
    ; is CR?
    cp CHAR_CR
    ; no:
    ret nz
    ; yes: convert CR to LF
    ld a, CHAR_LF
    ret 
@no_char:
    ld a,0
    ret

usb_putchar:
    ; newline?
    cp CHAR_LF
    ; no: just send the char
    jr nz,@put
    ld a, CHAR_CR
    call _usb_put
    ld a, CHAR_LF
@put:
    call _usb_put
    ret

; transmit character in A
_usb_put:
    push bc
    ; stash the transmit character
    ld b,a
@loop: 
    ; get the USB status
    in a,(UM245R_CTRL)
    ; ready to transmit? (active low)
    bit 0,a
    ; no: bit is high
    jr nz,@loop
    ; yes: restore the stashed transmit character
    ld a,b
    ; transmit the character
    out (UM245R_DATA),a
    pop bc
    ret

; print a zero-terminated string pointed to by hl to the USB
usb_puts:
    push hl
@loop:
    ; get character from string
    ld a,(hl)
    ; is it zero?
    cp 0
    ; yes
    jr z, @end
    ; no: send character
    call usb_putchar
    ; next character position
    inc hl
    ; loop for next character
    jp @loop
@end:
    pop hl
    ret

