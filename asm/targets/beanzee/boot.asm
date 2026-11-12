; boot.asm - Boot sequence (BeanZee target)
;
; _boot is entered from the reset vector in asm/core/entry.asm, with SP set.
;
; BeanZee (USB only): boot to Marvin monitor
;
    EXTERN marvin_coldstart     ; monitor.asm - cold start
;
_boot:
    ld bc,0x8000                ; power-up debounce delay (~100ms at 10MHz)
@powerup:
    nop
    dec bc
    ld a,b
    or c
    jr nz,@powerup
    jp marvin_coldstart
