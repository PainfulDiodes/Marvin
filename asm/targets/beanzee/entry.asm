; entry_beanzee.asm - Entry Point (BeanZee target, combined firmware)
;
; CPU reset vector, RST vectors, trampoline functions (ABI), and boot function for the
; combined Marvin + BBC BASIC firmware.
;
; Provides:
;   - CPU boot at 0x0000 (SP init)
;   - RST vectors 0x0008-0x0038, all redirect to 0x0000 (hardware reset)
;   - Marvin trampoline functions (ABI) at 0x0040
;   - Boot selection (BeanZee: always monitor)
;
    EXTERN marvin_coldstart      ; monitor.asm - cold start
    EXTERN marvin_warmstart     ; monitor.asm - warm start
    EXTERN con_putchar          ; console - write character
    EXTERN con_getchar          ; console - blocking read
    EXTERN con_readchar         ; console - non-blocking read
    EXTERN con_puts             ; console - print string
    EXTERN con_putchar_hex      ; hex.asm - print hex byte
    EXTERN usb_putchar          ; um245r.asm - USB write character
    EXTERN usb_puts             ; um245r.asm - USB print string
    EXTERN usb_readchar         ; um245r.asm - USB non-blocking read
    EXTERN START                ; MAIN.Z80 - BBC BASIC cold start
;
    EXTERN STACK
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
    jp _stub             ; 0x005B - lcd_init (not available on beanzee)
    jp _stub             ; 0x005E - lcd_putchar (not available on beanzee)
    jp _stub             ; 0x0061 - lcd_puts (not available on beanzee)
    jp _stub             ; 0x0064 - key_readchar (not available on beanzee)
    jp _stub             ; 0x0067 - key_modifiers (not available on beanzee)
    jp _stub             ; 0x006A - ra8875_init (not available on beanzee)
    jp _stub             ; 0x006D - ra8875_putchar (not available on beanzee)
    jp _stub             ; 0x0070 - ra8875_puts (not available on beanzee)
    jp _stub             ; 0x0073 - ra8875_console_init (not available on beanzee)
    jp _stub             ; 0x0076 - ra8875_console_putchar (not available on beanzee)
    jp _stub             ; 0x0079 - ra8875_console_cursor_x (not available on beanzee)
    jp _stub             ; 0x007C - ra8875_console_cursor_y (not available on beanzee)
    jp _stub             ; 0x007F - ra8875_console_set_cursor_colour (not available on beanzee)
    jp _stub             ; 0x0082 - ra8875_console_set_background_colour (not available on beanzee)
    jp _stub             ; 0x0085 - ra8875_console_cursor_hide (not available on beanzee)
    jp _stub             ; 0x0088 - ra8875_console_cursor_show (not available on beanzee)
_stub:
    ret
;
;
; ---- Boot Selection ----
;
; BeanZee (USB only): boot to Marvin monitor
;
_boot:
    ld bc,0x8000                ; power-up debounce delay (~100ms at 10MHz)
_boot_powerup:
    nop
    dec bc
    ld a,b
    or c
    jr nz,_boot_powerup
    jp marvin_coldstart
;
