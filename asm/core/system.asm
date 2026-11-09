; Marvin system constants.
; All labels are PUBLIC so they can be referenced via EXTERN from other modules.

    PUBLIC RAMSTART
    PUBLIC CONSOLE_STATUS, LCD_RAMSTART, KEY_MATRIX_BUFFER, CAPS_LOCK_STATE, CMD_BUFFER, STACK
    PUBLIC UM245R_CTRL, UM245R_DATA
    PUBLIC KEYSCAN_OUT, KEYSCAN_IN
    PUBLIC LCD_CTRL, LCD_DATA
    PUBLIC GPIO_OUT, GPIO_IN
    PUBLIC SPI_CTRL, SPI_DATA
    PUBLIC RA8875_GPIO, RA8875_SPI_CTRL, RA8875_SPI_DATA, RA8875_RAMSTART
    PUBLIC SYSTEM_RAMSTART
    PUBLIC CONSOLE_STATUS_USB, CONSOLE_STATUS_BEANBOARD

IFDEF HAS_RA8875
    EXTERN RA8875_RAMSIZE
ELSE
RA8875_RAMSIZE      equ 0
ENDIF

IFDEF HAS_LCD
    EXTERN LCD_RAMSIZE
ELSE
LCD_RAMSIZE         equ 0
ENDIF

; start of user RAM
RAMSTART            equ 0x8000

; system RAM
SYSTEM_RAMSTART     equ 0xf000
RA8875_RAMSTART     equ SYSTEM_RAMSTART                     ; RA8875 console variables (RA8875_RAMSIZE bytes)
CONSOLE_STATUS      equ RA8875_RAMSTART + RA8875_RAMSIZE    ; 1 byte: active console
LCD_RAMSTART        equ CONSOLE_STATUS + 1                  ; LCD console variables (LCD_RAMSIZE bytes)
KEY_MATRIX_BUFFER   equ LCD_RAMSTART + LCD_RAMSIZE          ; 8 bytes: keyscan buffer
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

; RA8875 driver labels (aliases used by ra8875-z80-repo transport modules)
RA8875_GPIO         equ GPIO_OUT    ; GPIO port for RA8875 bit-bang SPI
RA8875_SPI_CTRL     equ SPI_CTRL    ; hardware SPI control port
RA8875_SPI_DATA     equ SPI_DATA    ; hardware SPI data port

; console selection
CONSOLE_STATUS_USB       equ 1
CONSOLE_STATUS_BEANBOARD equ 2
