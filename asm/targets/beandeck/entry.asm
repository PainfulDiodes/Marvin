; entry_beandeck.asm - Entry Point (BeanDeck target, combined firmware)
;
; CPU reset vector, RST vectors, trampoline functions (ABI), and boot function for the
; combined Marvin + BBC BASIC firmware.
;
; BeanDeck: USB console output, keyboard or USB input.
;   Reset → keyboard input
;   Shift-Reset → USB input
;
; Provides:
;   - CPU boot at 0x0000 (SP init)
;   - RST vectors 0x0008-0x0038, all redirect to 0x0000 (hardware reset)
;   - Marvin trampoline functions (ABI) at 0x0040
;   - Boot selection (init console, then start monitor)
;
    EXTERN marvin_coldstart      ; monitor.asm - cold start
    EXTERN marvin_warmstart     ; monitor.asm - warm start
    EXTERN con_putchar          ; console - write character
    EXTERN con_getchar          ; console - blocking read
    EXTERN con_readchar         ; console - non-blocking read
    EXTERN con_puts             ; console - print string
    EXTERN con_putchar_hex      ; hex.asm - print hex byte
    EXTERN key_readchar         ; keymatrix.asm - keyboard read
    EXTERN console_select       ; console_select.asm - console selection
    EXTERN CONSOLE_STATUS, CONSOLE_STATUS_USB ; system.asm - force USB fallback
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
    EXTERN START                ; MAIN.Z80 - BBC BASIC cold start
;
    EXTERN STACK
    EXTERN CAPS_LOCK_STATE
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
;
;
; ---- Trampoline Functions (ABI) ----
;
; Fixed ROM addresses - must match abi/marvin.inc
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
;
; ---- Boot Selection ----
;
; BeanDeck: select console input source, then boot to monitor.
;   Shift held at reset → USB console input
;   No key → keyboard input
;
_boot:
    ld bc,0x0D00                ; power-up debounce delay (~12ms at 10MHz)
_boot_powerup:
    nop
    dec bc
    ld a,b
    or c
    jr nz,_boot_powerup
    xor a
    ld (CAPS_LOCK_STATE),a      ; ensure caps off at startup
    ld b,3                      ; up to 3 init attempts
_boot_ra8875_init:
    call ra8875_initialise      ; ra8875_initialise preserves BC
    jr z,_boot_ra8875_ok        ; success
    djnz _boot_ra8875_init      ; failed: retry (each attempt re-asserts RESET)
    jr _boot_ra8875_failed      ; all attempts failed: fall back to USB console
_boot_ra8875_ok:
    call ra8875_console_init
    call console_select
    jp marvin_coldstart
_boot_ra8875_failed:
    ; RA8875 initialisation failed (no SPI response or memory-clear timeout).
    ; Fall back to USB console so the monitor is at least reachable.
    ;
    ; LIMITATIONS - this is a minimal fallback, not a proper error path:
    ;
    ; 1. Silent failure: there is no way to tell the user what went wrong.
    ;    The display is blank or shows uninitialised VRAM. The only indication
    ;    that something failed is that the monitor appears on USB instead of
    ;    the TFT — easy to miss if USB is not already connected.
    ;
    ; 2. Requires prior knowledge: the user must know to connect USB and open
    ;    a terminal. There is no beep, LED flash, or other out-of-band signal.
    ;
    ; 3. Future consideration: treat USB as STDERR.
    ;    USB output could be kept always-on as an error/diagnostic channel,
    ;    independent of the selected console. A startup failure message (or any
    ;    runtime error) could then be sent to USB regardless of which console
    ;    is active — analogous to stderr vs stdout. This would make failures
    ;    visible without requiring the user to know something went wrong first.
    ;    That would require the console layer to support a separate diagnostic
    ;    output path (e.g. usb_puts at the hardware level, bypassing CONSOLE_STATUS).
    ld a,CONSOLE_STATUS_USB
    ld (CONSOLE_STATUS),a
    jp marvin_coldstart
;
