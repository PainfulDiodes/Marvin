; spi_beanboardspi_revb.asm - SPI byte transfer for BeanBoardSPI Rev B
;
; Rev B has a status register: reading SPI_CTRL returns bit 0 = ~SER_EN,
; high when serialisation is complete. Polling replaces fixed NOP delays.
;
; Interface (PUBLIC):
;   spi_read - receive one byte (transmits 0x00); returns byte in A
;   spi_byte - transmit A, receive one byte (full-duplex); returns byte in A

    PUBLIC spi_byte
    PUBLIC spi_read

    EXTERN SPI_CTRL             ; system.asm - SPI control/status port
    EXTERN SPI_DATA             ; system.asm - SPI data port

; spi_read: receive one byte, transmitting 0x00
; out: A = byte received
; destroys: AF
spi_read:
    xor a                       ; A = 0x00 (dummy transmit byte)
                                ; fall through to spi_byte

; spi_byte: full-duplex SPI byte transfer
; in:  A = byte to transmit
; out: A = byte received
; destroys: AF
spi_byte:
    out (SPI_DATA), a
@wait:
    in a, (SPI_CTRL)
    bit 0, a
    jr z, @wait                 ; bit 0 low = serialising
    in a, (SPI_DATA)
    ret
