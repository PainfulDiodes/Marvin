; boot.asm - Boot sequence (BeanDeck target)
;
; _boot is entered from the reset vector in asm/core/entry.asm, with SP set.
;
; BeanDeck: init RA8875 and select console input source, then boot to monitor.
;   Shift held at reset → USB console input
;   No key → keyboard input
;   RA8875 init fails → USB console
;
    EXTERN CAPS_LOCK_STATE
    EXTERN marvin_coldstart     ; monitor.asm - cold start
    EXTERN console_select       ; console_select.asm - console selection
    EXTERN CONSOLE_STATUS, CONSOLE_STATUS_USB ; console_select - force USB fallback
    EXTERN ra8875_initialise    ; ra8875.asm - display init
    EXTERN ra8875_console_init  ; console.asm (ra8875-z80-repo) - console state init
;
_boot:
    ld bc,0x0D00                ; power-up debounce delay (~12ms at 10MHz)
@powerup:
    nop
    dec bc
    ld a,b
    or c
    jr nz,@powerup
    xor a
    ld (CAPS_LOCK_STATE),a      ; ensure caps off at startup
    ld b,3                      ; up to 3 init attempts
@ra8875_init:
    call ra8875_initialise      ; ra8875_initialise preserves BC
    jr z,@ra8875_ok             ; success
    djnz @ra8875_init           ; failed: retry (each attempt re-asserts RESET)
    jr @ra8875_failed           ; all attempts failed: fall back to USB console
@ra8875_ok:
    call ra8875_console_init
    call console_select
    jp marvin_coldstart
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
