; spi_beanboard.asm - SPI byte transfer for BeanBoard via bit-bang GPIO
;
; NOTE: not currently linked into any Marvin build target. Wire up alongside
; ra8875_beanboard.asm when adding RA8875 support for the beanboard target.
;
; TODO: spi_byte is not correctly full-duplex. MOSI is driven correctly for
; each bit but MISO (GPIO_IN bit 0) is not sampled on the rising SCK edge,
; so the received byte returned in A is always 0. The bit loop needs to read
; GPIO_IN after clocking high and accumulate the received byte. Fix before
; linking this module into a build.
;
; TODO: the active SPI channel selection mechanism (how CS/RESET state
; constants are embedded in the bit patterns below) needs to be reconsidered
; when supporting multiple SPI devices on the beanboard GPIO port.
;
; Interface (PUBLIC):
;   spi_read - receive one byte (transmits 0x00); returns byte in A (unreliable - see TODO)
;   spi_byte - transmit A, receive one byte; returns byte in A (unreliable - see TODO)

    PUBLIC spi_byte
    PUBLIC spi_read

    EXTERN GPIO_OUT             ; system.asm - GPIO output port

    INCLUDE "asm/drivers/beanboard.inc"

; spi_read: receive one byte, transmitting 0x00
; out: A = byte received (unreliable - see TODO above)
; destroys: AF, B, D
spi_read:
    xor a                       ; A = 0x00 (dummy transmit byte)
                                ; fall through to spi_byte

; spi_byte: transmit A MSB first over 8 clock cycles
; TODO: MISO is not sampled - returned byte is always 0. See file header.
; in:  A = byte to transmit
; out: A = 0 (received byte - unreliable until TODO is fixed)
; destroys: AF, B, D
spi_byte:
    ld b, 8
@loop:
    rlca
    ld d, a
    ld a, GPO_LOW_STATE
    jr nc, @bit
    ld a, GPO_HIGH_STATE
@bit:
    out (GPIO_OUT), a           ; set MOSI
    or 1 << GPO_BIT_SCK
    out (GPIO_OUT), a           ; clock high - TODO: sample GPIO_IN here for MISO
    and ~(1 << GPO_BIT_SCK)
    out (GPIO_OUT), a           ; clock low
    ld a, d
    djnz @loop
    xor a                       ; TODO: replace with accumulated received byte
    ret
