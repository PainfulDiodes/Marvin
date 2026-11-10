; entry.asm - Entry Point (BeanBoard target)
;
; CPU reset vector, RST vectors, trampoline functions (ABI), and boot function for the
; firmware, with or without BBC BASIC (INCLUDE_BASIC).
;
; Provides:
;   - CPU boot at 0x0000 (SP init)
;   - RST vectors 0x0008-0x0038, all redirect to 0x0000 (hardware reset)
;   - Marvin trampoline functions (ABI) at 0x0040, from asm/core/trampoline.asm
;   - Boot selection (init LCD and console, then start monitor)
;
    EXTERN STACK
    EXTERN CAPS_LOCK_STATE

    EXTERN marvin_coldstart      ; monitor.asm - cold start
    EXTERN marvin_warmstart     ; monitor.asm - warm start
    EXTERN lcd_init             ; hd44780.asm - LCD initialisation
    EXTERN console_select       ; console_select.asm - console selection

IFDEF INCLUDE_BASIC
    EXTERN START                ; MAIN.Z80 - BBC BASIC cold start
ELSE
    PUBLIC START                ; stub below - no BBC BASIC in this build
ENDIF
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
;
;
; ---- Trampoline Functions (ABI) ----
;
    INCLUDE "asm/core/trampoline.asm"
;
IFNDEF INCLUDE_BASIC
; START stub - no BBC BASIC in this build
START:
    jp marvin_warmstart
ENDIF
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
