    INCLUDE "asm/drivers/hd44780.inc"

    EXTERN LCD_CTRL, LCD_DATA
    EXTERN LCD_RAMSTART
    INCLUDE "asm/core/chars.inc"

    PUBLIC lcd_init
    PUBLIC lcd_putchar
    PUBLIC lcd_puts
    PUBLIC LCD_RAMSIZE

    ; RAM variables
    LCD_CURSOR_COL  equ LCD_RAMSTART + 0    ; 1 byte: column (0..LCD_LINE_LEN-1)
    LCD_RAMSIZE     equ 1

; initialise LCD
lcd_init:
; preserve registers
    push af
; intitialise device
	ld a,LCD_FUNCTION_SET+LCD_DATA_LEN_8+LCD_DISP_LINES_2+LCD_FONT_8
	call _lcd_putcmd
	ld a,LCD_DISPLAY_ON_OFF_CONTROL+LCD_DISPLAY_ON+LCD_CURSOR_ON+LCD_BLINK_ON
	call _lcd_putcmd
	ld a,LCD_CLEAR_DISPLAY
	call _lcd_putcmd
    ld a,LCD_SET_DDRAM_ADDR+LCD_LINE_3_ADDR
	call _lcd_putcmd
; initialise column tracking
    xor a
    ld (LCD_CURSOR_COL),a

; restore registers
    pop af
    ret

; transmit character in A to the LCD control port
_lcd_putcmd:                     
    push bc
; save the transmit character
    ld b,a
@loop: 
; get the LCD status
    in a,(LCD_CTRL)
; busy ?
    bit 7,a
; yes
    jr nz,@loop
; no, restore the transmit character
    ld a,b
; transmit the character
    out (LCD_CTRL),a
    pop bc
    ret

; get character from LCD data port and return in A
_lcd_getchar:                     
; get the LCD status
    in a,(LCD_CTRL)
; busy ?
    bit 7,a
; yes
    jr nz,_lcd_getchar
; no, get a character
    in a,(LCD_DATA)
    ret

; transmit character in A to the LCD data port
lcd_putchar:
    push af
    push hl
    ; backspace?
    cp CHAR_BS
    jr z,@backspace
    cp CHAR_DEL                         ; DEL (backspace key on most terminals)
    jr z,@backspace
    ; newline char?
    cp CHAR_LF
    jp nz,@printable
    ; newline - fill out the line until EOL
@pad:
    ld a,' '
    call _lcd_putdata
    cp LCD_EOL_3
    jp z,@eol3
    ; loop until EOL
    jr @pad
@printable:
    call _lcd_putdata
    ; track column position (inc (hl) does not affect A)
    ld hl,LCD_CURSOR_COL
    inc (hl)
    ; check for overflow - DDRAM address returned in A
    cp LCD_EOL_3
    jp z,@eol3
    jp @end
@eol3:
    ; line feed
    call _lcd_scroll
    ; carriage return to start of line 3
    ld a,LCD_SET_DDRAM_ADDR+LCD_LINE_3_ADDR
    call _lcd_putcmd
    ; reset column tracking
    xor a
    ld (LCD_CURSOR_COL),a
    jp @end
@backspace:
    ; if at start of line, nothing to do
    ld a,(LCD_CURSOR_COL)
    or a
    jr z,@end
    ; move back one column
    dec a
    ld (LCD_CURSOR_COL),a
    ; position cursor at new column on line 3
    add a,LCD_SET_DDRAM_ADDR+LCD_LINE_3_ADDR
    call _lcd_putcmd
    ; erase character (write space; hardware auto-advances cursor)
    ld a,' '
    call _lcd_putdata
    ; reposition cursor back to erased position
    ld a,(LCD_CURSOR_COL)
    add a,LCD_SET_DDRAM_ADDR+LCD_LINE_3_ADDR
    call _lcd_putcmd
@end:
    pop hl
    pop af
    ret

; transmit character in A to the LCD data port, 
; return in A the DDRAM address where the character was sent
_lcd_putdata:                     
    push bc
    ; save the transmit character
    ld b,a
@loop: 
    ; get the LCD status
    in a,(LCD_CTRL)
    ; busy ?
    bit 7,a
    ; yes
    jr nz,@loop
    ; no, reset the 'busy' bit and preserve the DDRAM address
    and 0b01111111
    ld c,a
    ; restore the transmit character and send it
    ld a,b
    out (LCD_DATA),a
    ; restore the DDRAM address
    ld a,c
    pop bc
    ret

_lcd_scroll:
    push bc
    push de
    ld d,LCD_SET_DDRAM_ADDR+LCD_LINE_1_ADDR
    ld e,LCD_SET_DDRAM_ADDR+LCD_LINE_0_ADDR
    call _lcd_scroll_line
    ld d,LCD_SET_DDRAM_ADDR+LCD_LINE_2_ADDR
    ld e,LCD_SET_DDRAM_ADDR+LCD_LINE_1_ADDR
    call _lcd_scroll_line
    ld d,LCD_SET_DDRAM_ADDR+LCD_LINE_3_ADDR
    ld e,LCD_SET_DDRAM_ADDR+LCD_LINE_2_ADDR
    call _lcd_scroll_line
    ld a,LCD_SET_DDRAM_ADDR+LCD_LINE_3_ADDR
    call _lcd_scroll_clear_line
    pop de
    pop bc
    ret
_lcd_scroll_line:
    ; b = character counter
    ; c = stash char
    ; d = source line to copy from
    ; e = destination line to copy to
    ld b,LCD_LINE_LEN
@loop:
    ; load source
    ld a,d 
    ; character counter is an offset
    add b 
    ; zero based index so -1
    dec a 
    call _lcd_putcmd 
    call _lcd_getchar
    ; stash the value
    ld c,a 
    ; load destination
    ld a,e 
    ; character counter is an offset
    add b 
    ; zero based index so -1
    dec a
    call _lcd_putcmd 
    ; recover the stashed value
    ld a,c 
    call _lcd_putdata
    djnz @loop
    ret
_lcd_scroll_clear_line:
    ; a = destination line to clear
    ; b = character counter
    ld b,LCD_LINE_LEN
    call _lcd_putcmd 
@loop:
    ld a,' '
    call _lcd_putdata
    djnz @loop
    ret

; print a zero-terminated string pointed to by hl to the LCD
lcd_puts:
    push hl
@loop:
    ; get character from string
    ld a,(hl)
    ; is it zero?
    cp 0
    ; yes
    jr z, @end
    ; no: send character
    call lcd_putchar
    ; next character position
    inc hl
    ; loop for next character
    jp @loop
@end:
    pop hl
    ret

