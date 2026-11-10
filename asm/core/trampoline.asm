; trampoline.asm - Marvin trampoline functions (ABI)
;
; A table of jp instructions at fixed ROM addresses from 0x0040, one 3-byte entry per
; service. Addresses must match abi/marvin.inc. Included by each target's entry.asm,
; after the RST vectors.
;
; Each entry jumps to the real function when the target's config.inc declares the
; hardware, and to _stub (returns immediately) when it doesn't:
;   HAS_LCD      - HD44780 LCD
;   HAS_KEYBOARD - matrix keyboard
;   HAS_RA8875   - RA8875 TFT display
;
    EXTERN marvin_warmstart     ; monitor.asm - warm start
    EXTERN con_putchar          ; console - write character
    EXTERN con_putchar_hex      ; hex.asm - print hex byte
    EXTERN con_puts             ; console - print string
    EXTERN con_getchar          ; console - blocking read
    EXTERN con_readchar         ; console - non-blocking read
    EXTERN usb_putchar          ; um245r.asm - USB write character
    EXTERN usb_puts             ; um245r.asm - USB print string
    EXTERN usb_readchar         ; um245r.asm - USB non-blocking read
IFDEF HAS_LCD
    EXTERN lcd_init             ; hd44780.asm - LCD initialisation
    EXTERN lcd_putchar          ; hd44780.asm - LCD character output
    EXTERN lcd_puts             ; hd44780.asm - LCD print string
ENDIF
IFDEF HAS_KEYBOARD
    EXTERN key_readchar         ; keymatrix.asm - keyboard read
    EXTERN key_modifiers        ; keymatrix.asm - read modifier keys
ENDIF
IFDEF HAS_RA8875
    EXTERN ra8875_initialise    ; ra8875.asm - display init
    EXTERN ra8875_putchar       ; ra8875.asm - write character to display
    EXTERN ra8875_puts          ; ra8875.asm - RA8875 print string
    EXTERN ra8875_console_init  ; console.asm (ra8875-z80-repo) - console state init
    EXTERN ra8875_console_putchar ; console.asm - RA8875 console write character
    EXTERN ra8875_console_cursor_x ; console.asm - set cursor column
    EXTERN ra8875_console_cursor_y ; console.asm - set cursor row
    EXTERN ra8875_console_set_cursor_colour ; console.asm - set cursor colour
    EXTERN ra8875_console_set_background_colour ; console.asm - set background colour
    EXTERN ra8875_console_cursor_hide ; console.asm - hide software cursor
    EXTERN ra8875_console_cursor_show ; console.asm - show software cursor
ENDIF
;
ALIGN 0x0040
    jp marvin_warmstart  ; 0x0040 - warm start (monitor prompt)
    jp con_putchar       ; 0x0043 - write character (A = char)
    jp con_putchar_hex   ; 0x0046 - print A as two hex digits
    jp con_puts          ; 0x0049 - print string (HL = address, zero-terminated)
    jp con_getchar       ; 0x004C - wait for character (returns A)
    jp con_readchar      ; 0x004F - non-blocking read (returns A, 0 = none)
    jp usb_putchar       ; 0x0052 - USB write character (A = char)
    jp usb_puts          ; 0x0055 - USB print string (HL = address, zero-terminated)
    jp usb_readchar      ; 0x0058 - USB non-blocking read (returns A, 0 = none)
IFDEF HAS_LCD
    jp lcd_init          ; 0x005B - initialise LCD
    jp lcd_putchar       ; 0x005E - write character to LCD
    jp lcd_puts          ; 0x0061 - LCD print string (HL = address, zero-terminated)
ELSE
    jp _stub             ; 0x005B - lcd_init
    jp _stub             ; 0x005E - lcd_putchar
    jp _stub             ; 0x0061 - lcd_puts
ENDIF
IFDEF HAS_KEYBOARD
    jp key_readchar      ; 0x0064 - read keyboard
    jp key_modifiers     ; 0x0067 - read modifier keys
ELSE
    jp _stub             ; 0x0064 - key_readchar
    jp _stub             ; 0x0067 - key_modifiers
ENDIF
IFDEF HAS_RA8875
    jp ra8875_initialise ; 0x006A - ra8875 init
    jp ra8875_putchar    ; 0x006D - ra8875 putchar
    jp ra8875_puts       ; 0x0070 - ra8875 print string
    jp ra8875_console_init          ; 0x0073 - ra8875 console state init
    jp ra8875_console_putchar        ; 0x0076 - ra8875 console write character
    jp ra8875_console_cursor_x      ; 0x0079 - set cursor column (A = col)
    jp ra8875_console_cursor_y      ; 0x007C - set cursor row (A = row, logical)
    jp ra8875_console_set_cursor_colour ; 0x007F - set cursor colour (RA8875_COL_* in A)
    jp ra8875_console_set_background_colour ; 0x0082 - set console background colour (A = colour)
    jp ra8875_console_cursor_hide    ; 0x0085 - hide software cursor
    jp ra8875_console_cursor_show    ; 0x0088 - show software cursor
ELSE
    jp _stub             ; 0x006A - ra8875_init
    jp _stub             ; 0x006D - ra8875_putchar
    jp _stub             ; 0x0070 - ra8875_puts
    jp _stub             ; 0x0073 - ra8875_console_init
    jp _stub             ; 0x0076 - ra8875_console_putchar
    jp _stub             ; 0x0079 - ra8875_console_cursor_x
    jp _stub             ; 0x007C - ra8875_console_cursor_y
    jp _stub             ; 0x007F - ra8875_console_set_cursor_colour
    jp _stub             ; 0x0082 - ra8875_console_set_background_colour
    jp _stub             ; 0x0085 - ra8875_console_cursor_hide
    jp _stub             ; 0x0088 - ra8875_console_cursor_show
ENDIF
_stub:
    ret
