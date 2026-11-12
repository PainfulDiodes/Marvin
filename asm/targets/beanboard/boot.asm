; boot.asm - Boot sequence (BeanBoard target)
;
; _boot is entered from the reset vector in asm/core/entry.asm, with SP set.
;
; BeanBoard: init LCD and select console, then boot to monitor.
;   Shift held at reset → USB console
;   No key → beanboard console: LCD + keyboard
;
    EXTERN CAPS_LOCK_STATE
    EXTERN marvin_coldstart     ; monitor.asm - cold start
    EXTERN lcd_init             ; hd44780.asm - LCD initialisation
    EXTERN console_select       ; console_select.asm - console selection
;
_boot:
    ld bc,0x8000                ; power-up debounce delay (~100ms at 10MHz)
@powerup:
    nop
    dec bc
    ld a,b
    or c
    jr nz,@powerup
    call lcd_init
    ld bc,0x8000                ; post-lcd_init delay (~100ms at 10MHz)
@lcd_init_delay:
    nop
    dec bc
    ld a,b
    or c
    jr nz,@lcd_init_delay
    call console_select
    xor a
    ld (CAPS_LOCK_STATE),a      ; ensure caps off at startup
    jp marvin_coldstart
