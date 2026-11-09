; Marvin system constants.
; All labels are PUBLIC so they can be referenced via EXTERN from other modules.

    PUBLIC RAMSTART
    PUBLIC CONSOLE_STATUS, LCD_RAMSTART, KEY_MATRIX_BUFFER, CAPS_LOCK_STATE, CMD_BUFFER, STACK
    PUBLIC UM245R_CTRL, UM245R_DATA
    PUBLIC KEYSCAN_OUT, KEYSCAN_IN
    PUBLIC LCD_CTRL, LCD_DATA
    PUBLIC GPIO_OUT, GPIO_IN
    PUBLIC SPI_CTRL, SPI_DATA
    PUBLIC SPI_CS_IDLE, SPI_CS_RESET, SPI_CS_SLOT0, SPI_CS_SLOT1, SPI_CS_SLOT2, SPI_CS_SLOT3, SPI_CS_SLOT4, SPI_CS_SLOT5, SPI_CS_SLOT6
    PUBLIC RA8875_GPIO, RA8875_SPI_CTRL, RA8875_SPI_DATA, RA8875_RAMSTART
    PUBLIC SYSTEM_RAMSTART
    PUBLIC CONSOLE_STATUS_USB, CONSOLE_STATUS_BEANBOARD
    PUBLIC W25Q_RAMSTART
    PUBLIC BDFS_RAMSTART

IFDEF HAS_RA8875
    EXTERN RA8875_RAMSIZE
ELSE
RA8875_RAMSIZE      equ 0
ENDIF

; TODO we need to reconsider the RAM allocation here - its getting messy and there's a mix of conditional / unconditional allocations

; TODO this conditional is unneccessary - LCD is not a submodule
IFDEF HAS_LCD
    EXTERN LCD_RAMSIZE
ELSE
LCD_RAMSIZE         equ 0
ENDIF

IFDEF INCLUDE_BDFS
    EXTERN W25Q_RAMSIZE
    EXTERN BDFS_RAMSIZE
ELSE
W25Q_RAMSIZE        equ 0
BDFS_RAMSIZE        equ 0
ENDIF

; start of user RAM
RAMSTART            equ 0x8000

; system RAM
SYSTEM_RAMSTART     equ 0xf000
RA8875_RAMSTART     equ SYSTEM_RAMSTART                     ; RA8875 console variables (RA8875_RAMSIZE bytes)
CONSOLE_STATUS      equ RA8875_RAMSTART + RA8875_RAMSIZE    ; 1 byte: active console
LCD_RAMSTART        equ CONSOLE_STATUS + 1                  ; LCD console variables (LCD_RAMSIZE bytes)
W25Q_RAMSTART       equ LCD_RAMSTART + LCD_RAMSIZE          ; W25Q driver variables (W25Q_RAMSIZE bytes, layout in w25q.asm)
BDFS_RAMSTART       equ W25Q_RAMSTART + W25Q_RAMSIZE        ; BDFS variables (BDFS_RAMSIZE bytes, layout in bdfs.asm)
KEY_MATRIX_BUFFER   equ BDFS_RAMSTART + BDFS_RAMSIZE        ; 8 bytes: keyscan buffer
CAPS_LOCK_STATE     equ KEY_MATRIX_BUFFER + 8               ; 1 byte: caps lock state (0=off, 1=on)
CMD_BUFFER          equ CAPS_LOCK_STATE + 1                 ; command buffer (grows toward stack)

; stack starts at top of RAM (CPU decrements SP before PUSH)
STACK               equ 0xffff

; USB serial (UM245R)
UM245R_CTRL         equ 0
UM245R_DATA         equ 1

; keyboard scan
KEYSCAN_OUT         equ 2       ; either 2 or 3 will work
KEYSCAN_IN          equ 3       ; either 2 or 3 will work

; LCD display (HD44780)
LCD_CTRL            equ 4
LCD_DATA            equ 5

; GPIO (bit-bang SPI for BeanBoard RA8875)
GPIO_OUT            equ 6       ; either 6 or 7 will work
GPIO_IN             equ 7       ; either 6 or 7 will work

; hardware SPI (BeanDeck BeanBoardSPI)
SPI_CTRL            equ 8       ; SPI control register (74HCT373 latch)
SPI_DATA            equ 10      ; SPI data register (74HCT299 shift register)

; SPI control register bit assignments
; Bit 0: RESET active low, Bits 1-7: SPI slot 0-6 CS active low
SPI_CS_IDLE         equ 0xFF    ; all CS deasserted, RESET released
SPI_CS_RESET        equ 0xFE    ; bit 0 low: RESET asserted
SPI_CS_SLOT0        equ 0xFD    ; bit 1 low: slot 0
SPI_CS_SLOT1        equ 0xFB    ; bit 2 low: slot 1
SPI_CS_SLOT2        equ 0xF7    ; bit 3 low: slot 2
SPI_CS_SLOT3        equ 0xEF    ; bit 4 low: slot 3
SPI_CS_SLOT4        equ 0xDF    ; bit 5 low: slot 4
SPI_CS_SLOT5        equ 0xBF    ; bit 6 low: slot 5
SPI_CS_SLOT6        equ 0x7F    ; bit 7 low: slot 6

; RA8875 submodule aliases — ra8875-z80-repo EXTERNs these labels
; Keep them even if unused in marvin
RA8875_GPIO         equ GPIO_OUT    ; GPIO port for RA8875 bit-bang SPI
RA8875_SPI_CTRL     equ SPI_CTRL    ; hardware SPI control port
RA8875_SPI_DATA     equ SPI_DATA    ; hardware SPI data port

; console selection
CONSOLE_STATUS_USB       equ 1
CONSOLE_STATUS_BEANBOARD equ 2

; TODO consider making the SPI / GPIO entries conditionally added at build time