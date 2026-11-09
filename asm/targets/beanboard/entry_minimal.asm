; entry_beanboard_minimal.asm - Minimal Marvin Entry Point (BeanBoard target)
;
; Minimal boot + trampoline functions (ABI) for Marvin without BBC BASIC.
; Initialises LCD and console, then boots to the monitor prompt.
;
    EXTERN STACK
    EXTERN CAPS_LOCK_STATE

    EXTERN marvin_coldstart
    EXTERN marvin_warmstart
    EXTERN con_putchar
    EXTERN con_getchar
    EXTERN con_readchar
    EXTERN con_puts
    EXTERN con_putchar_hex
    EXTERN lcd_init
    EXTERN lcd_putchar
    EXTERN key_readchar
    EXTERN console_select
    EXTERN usb_putchar          ; um245r.asm - USB write character
    EXTERN usb_puts             ; um245r.asm - USB print string
    EXTERN usb_readchar         ; um245r.asm - USB non-blocking read
    EXTERN key_modifiers        ; keymatrix.asm - read modifier keys
    EXTERN lcd_puts             ; hd44780.asm - LCD print string

    PUBLIC START                ; START stub - no BBC BASIC in minimal build
;
;
;
; ---- Boot Code ----
;
    ORG 0x0000
    ld sp, STACK
    jp _boot
;
;
; ---- RST Vectors ----
;
; All RST instructions redirect to 0x0000 (hardware reset)
;
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
    jp lcd_init          ; 0x005B - initialise LCD
    jp lcd_putchar       ; 0x005E - write character to LCD
    jp lcd_puts          ; 0x0061 - LCD print string (HL = address, zero-terminated)
    jp key_readchar      ; 0x0064 - read keyboard
    jp key_modifiers     ; 0x0067 - read modifier keys
    jp _stub             ; 0x006A - ra8875_init (not available on beanboard)
    jp _stub             ; 0x006D - ra8875_putchar (not available on beanboard)
    jp _stub             ; 0x0070 - ra8875_puts (not available on beanboard)
    jp _stub             ; 0x0073 - ra8875_console_init (not available on beanboard)
    jp _stub             ; 0x0076 - ra8875_console_putchar (not available on beanboard)
    jp _stub             ; 0x0079 - ra8875_console_cursor_x (not available on beanboard)
    jp _stub             ; 0x007C - ra8875_console_cursor_y (not available on beanboard)
    jp _stub             ; 0x007F - ra8875_console_set_cursor_colour (not available on beanboard)
    jp _stub             ; 0x0082 - ra8875_console_set_background_colour (not available on beanboard)
    jp _stub             ; 0x0085 - ra8875_console_cursor_hide (not available on beanboard)
    jp _stub             ; 0x0088 - ra8875_console_cursor_show (not available on beanboard)
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
; BeanBoard: init LCD and select console, then boot to monitor.
;   Shift held at reset → USB console
;   No key → beanboard console: LCD + keyboard
;
_boot:
    ld bc,0x8000                ; power-up debounce delay (~100ms at 10MHz)
_boot_powerup:
    nop
    dec bc
    ld a,b
    or c
    jr nz,_boot_powerup
    call lcd_init
    ld bc,0x8000                ; post-lcd_init delay (~100ms at 10MHz)
_boot_lcd_init_delay:
    nop
    dec bc
    ld a,b
    or c
    jr nz,_boot_lcd_init_delay
    call console_select
    xor a
    ld (CAPS_LOCK_STATE),a      ; ensure caps off at startup
    jp marvin_coldstart
