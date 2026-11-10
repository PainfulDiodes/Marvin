; entry.asm - Entry Point (BeanDeck target)
;
; CPU reset vector, RST vectors, trampoline functions (ABI), and boot function for the
; firmware, with or without BBC BASIC (INCLUDE_BASIC).
;
; BeanDeck: USB console output, keyboard or USB input.
;   Reset → keyboard input
;   Shift-Reset → USB input
;
; Provides:
;   - CPU boot at 0x0000 (SP init)
;   - RST vectors 0x0008-0x0038, all redirect to 0x0000 (hardware reset)
;   - Marvin trampoline functions (ABI) at 0x0040, from asm/core/trampoline.asm
;   - Boot selection (init console, then start monitor)
;
    EXTERN marvin_coldstart      ; monitor.asm - cold start
    EXTERN marvin_warmstart     ; monitor.asm - warm start
    EXTERN console_select       ; console_select.asm - console selection
    EXTERN CONSOLE_STATUS, CONSOLE_STATUS_USB ; system.asm - force USB fallback
    EXTERN ra8875_initialise    ; ra8875.asm - display init
    EXTERN ra8875_console_init  ; console.asm (ra8875-z80-repo) - console state init
IFDEF INCLUDE_BASIC
    EXTERN START                ; MAIN.Z80 - BBC BASIC cold start
ELSE
    PUBLIC START                ; stub below - no BBC BASIC in this build
ENDIF
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
; BeanDeck: select console input source, then boot to monitor.
;   Shift held at reset → USB console input
;   No key → keyboard input
;
; TODO BASIC and monitor-only boot sequences have diverged - BASIC retries RA8875 init and falls back to USB, monitor-only tries once and has longer delays - decide on one
_boot:
IFDEF INCLUDE_BASIC
    ld bc,0x0D00                ; power-up debounce delay (~12ms at 10MHz)
ELSE
    ld bc,0x8000                ; power-up debounce delay (~100ms at 10MHz)
ENDIF
@powerup:
    nop
    dec bc
    ld a,b
    or c
    jr nz,@powerup
    xor a
    ld (CAPS_LOCK_STATE),a      ; ensure caps off at startup
IFDEF INCLUDE_BASIC
    ld b,3                      ; up to 3 init attempts
@ra8875_init:
    call ra8875_initialise      ; ra8875_initialise preserves BC
    jr z,@ra8875_ok             ; success
    djnz @ra8875_init           ; failed: retry (each attempt re-asserts RESET)
    jr @ra8875_failed           ; all attempts failed: fall back to USB console
@ra8875_ok:
ELSE
    call ra8875_initialise
    ld bc,0x8000                ; post-init settling delay (~100ms at 10MHz)
@settle:
    nop
    dec bc
    ld a,b
    or c
    jr nz,@settle
ENDIF
    call ra8875_console_init
    call console_select
    jp marvin_coldstart
IFDEF INCLUDE_BASIC
@ra8875_failed:
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
ENDIF
;
