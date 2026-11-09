; entry_beandeck_minimal.asm - Minimal Marvin Entry Point (BeanDeck target)
;
; Minimal boot + trampoline functions (ABI) for Marvin without BBC BASIC.
; USB console output, keyboard or USB input.
;   Reset → keyboard input
;   Shift-Reset → USB input
;
    EXTERN STACK

    EXTERN marvin_coldstart
    EXTERN marvin_warmstart
    EXTERN con_putchar
    EXTERN con_getchar
    EXTERN con_readchar
    EXTERN con_puts
    EXTERN con_putchar_hex
    EXTERN key_readchar
    EXTERN console_select
    EXTERN ra8875_initialise    ; ra8875.asm - display init
    EXTERN ra8875_putchar       ; ra8875.asm - write character to display
    EXTERN ra8875_console_init  ; console.asm (ra8875-z80-repo) - console state init
    EXTERN usb_putchar          ; um245r.asm - USB write character
    EXTERN usb_puts             ; um245r.asm - USB print string
    EXTERN usb_readchar         ; um245r.asm - USB non-blocking read
    EXTERN key_modifiers        ; keymatrix.asm - read modifier keys
    EXTERN ra8875_puts          ; ra8875.asm - RA8875 print string
    EXTERN ra8875_console_putchar ; console.asm - RA8875 console write character
    EXTERN ra8875_console_cursor_x ; console.asm - set cursor column
    EXTERN ra8875_console_cursor_y ; console.asm - set cursor row
    EXTERN ra8875_console_set_cursor_colour ; console.asm - set cursor colour
    EXTERN ra8875_console_set_background_colour ; console.asm - set background colour
    EXTERN ra8875_console_cursor_hide ; console.asm - hide software cursor
    EXTERN ra8875_console_cursor_show ; console.asm - show software cursor
    EXTERN CAPS_LOCK_STATE

    PUBLIC START

    ORG MARVINORG
    ld sp, STACK
    jp _boot

; RST vectors and trampoline functions (ABI) at fixed addresses - must match abi/marvin.inc
ALIGN 0x0008
    jp 0x0000     ; RST 08H
ALIGN 0x0010
    jp 0x0000     ; RST 10H
ALIGN 0x0018
    jp 0x0000     ; RST 18H
ALIGN 0x0020
    jp 0x0000     ; RST 20H
ALIGN 0x0028
    jp 0x0000     ; RST 28H
ALIGN 0x0030
    jp 0x0000     ; RST 30H
ALIGN 0x0038
    jp 0x0000     ; RST 38H / IM 1 vector
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
    jp _stub             ; 0x005B - lcd_init (not available on beandeck)
    jp _stub             ; 0x005E - lcd_putchar (not available on beandeck)
    jp _stub             ; 0x0061 - lcd_puts (not available on beandeck)
    jp key_readchar      ; 0x0064 - read keyboard
    jp key_modifiers     ; 0x0067 - read modifier keys
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
_stub:
    ret
;
; START stub - no BBC BASIC in minimal build
START:
    jp marvin_warmstart
;
;
; ---- Boot Selection ----
;
; BeanDeck: select console input source, then boot to monitor.
;   Shift held at reset → USB console input
;   No key → keyboard input
;
_boot:
    ld bc,0x8000                ; power-up debounce delay (~100ms at 10MHz)
_boot_powerup:
    nop
    dec bc
    ld a,b
    or c
    jr nz,_boot_powerup
    xor a
    ld (CAPS_LOCK_STATE),a      ; ensure caps off at startup
    call ra8875_initialise
    ld bc,0x8000                ; post-init settling delay (~100ms at 10MHz)
_boot_settle:
    nop
    dec bc
    ld a,b
    or c
    jr nz,_boot_settle
    call ra8875_console_init
    call console_select
    jp marvin_coldstart
