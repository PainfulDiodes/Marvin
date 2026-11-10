IFNDEF _MARVIN_INC
DEFINE _MARVIN_INC

; Marvin trampoline functions (ABI) - fixed ROM addresses
; Each entry is a 3-byte JP instruction
; Consumers call these addresses for Marvin I/O services
;
; Sections with limited availability note the supported targets in parentheses.
; Unsupported targets have a stub entry that returns immediately.
;
; Implemented in entry_<target>.asm / entry_<target>_minimal.asm

; ENTRY POINTS - JP to these - they will not RETurn

MARVIN_WARMSTART            EQU 0x0040  ; return to monitor prompt

; FUNCTIONS - CALL  these - they will RETurn

; Console I/O (routes to active console: USB, LCD+kbd, or RA8875+kbd)
MARVIN_PUTCHAR              EQU 0x0043  ; in: A=char           write char
MARVIN_PUTCHAR_HEX          EQU 0x0046  ; in: A=byte           write A as two hex digits
MARVIN_PUTS                 EQU 0x0049  ; in: HL=str(0-term)   write string
MARVIN_GETCHAR              EQU 0x004C  ; out: A=char          blocking read
MARVIN_READCHAR             EQU 0x004F  ; out: A=char (0=none) non-blocking read

; USB I/O  (all targets)
MARVIN_USB_PUTCHAR          EQU 0x0052  ; in: A=char           write char to USB
MARVIN_USB_PUTS             EQU 0x0055  ; in: HL=str(0-term)   write string to USB
MARVIN_USB_READCHAR         EQU 0x0058  ; out: A=char (0=none) non-blocking USB read

; LCD  (beanboard)
MARVIN_LCD_INIT             EQU 0x005B  ;                      initialise LCD
MARVIN_LCD_PUTCHAR          EQU 0x005E  ; in: A=char           write char to LCD
MARVIN_LCD_PUTS             EQU 0x0061  ; in: HL=str(0-term)   write string to LCD

; Keyboard  (beanboard, beandeck)
MARVIN_KEY_READCHAR         EQU 0x0064  ; out: A=char (0=none) non-blocking keyboard read
MARVIN_KEY_MODIFIERS        EQU 0x0067  ; out: A=modifier bits (MOD_KEY_SHIFT, MOD_KEY_CONTROL) read modifier key state

; RA8875 TFT display  (beandeck)
MARVIN_RA8875_INIT          EQU 0x006A  ; out: Z=ok NZ=fail    initialise RA8875
MARVIN_RA8875_PUTCHAR       EQU 0x006D  ; in: A=char           write char to RA8875
MARVIN_RA8875_PUTS          EQU 0x0070  ; in: HL=str(0-term)   write string to RA8875
MARVIN_RA8875_CONSOLE_INIT             EQU 0x0073 ;            initialise console state
MARVIN_RA8875_CONSOLE_PUTCHAR          EQU 0x0076 ; in: A=char  console write (handles LF, scroll)
MARVIN_RA8875_CONSOLE_CURSOR_X         EQU 0x0079 ; in: A=col  set cursor column (0..RA8875_COLS-1)
MARVIN_RA8875_CONSOLE_CURSOR_Y         EQU 0x007C ; in: A=row  set cursor row (0..RA8875_ROWS-1, logical)
MARVIN_RA8875_CONSOLE_SET_CURSOR_COLOUR EQU 0x007F ; in: A=colour  set cursor colour (RA8875_COL_*)
MARVIN_RA8875_CONSOLE_SET_BG_COLOUR    EQU 0x0082 ; in: A=colour  set console background colour
MARVIN_RA8875_CONSOLE_CURSOR_HIDE      EQU 0x0085 ; hide software cursor
MARVIN_RA8875_CONSOLE_CURSOR_SHOW      EQU 0x0088 ; show software cursor

; Flash cartridge  (beandeck)
MARVIN_FLASH_READ         EQU 0x008B  ; in: A=addr[23:16] HL=addr[15:0] DE=dest BC=len  read from flash
MARVIN_FLASH_PAGE_PROGRAM EQU 0x008E  ; in: A=addr[23:16] HL=addr[15:0] DE=src BC=len   Z=ok NZ=timeout  write page
MARVIN_FLASH_SECTOR_ERASE EQU 0x0091  ; in: HL=sector number   Z=ok NZ=timeout  erase 4KB sector
MARVIN_FLASH_SELECT_SLOT  EQU 0x0094  ; in: A=slot (1-6)  caches JEDEC ID to W25Q_ID_MFR/TYPE/CAP
MARVIN_FLASH_READ_JEDEC_ID EQU 0x0097 ; out: A=mfr B=type C=cap           read JEDEC ID from current slot
MARVIN_FLASH_HAS_DEVICE       EQU 0x009A  ; out: Z=device present NZ=no device
MARVIN_FLASH_GET_DEVICE_ID    EQU 0x009D  ; out: A=mfr B=type C=cap         get cached JEDEC ID
MARVIN_FLASH_GET_DEVICE_NAME  EQU 0x00A0  ; out: HL=ptr to name string
MARVIN_FLASH_GET_CAPACITY_MB  EQU 0x00A3  ; out: A=capacity in MB
MARVIN_FLASH_GET_SECTOR_COUNT EQU 0x00A6  ; out: HL=total 4KB sector count
MARVIN_FLASH_BYTES_TO_SECTORS EQU 0x00A9  ; in: HL=byte count  out: A=sector count (ceiling)
MARVIN_FLASH_SECTOR_TO_ADDR   EQU 0x00AC  ; in: HL=sector number  out: A=addr[23:16] HL=addr[15:0]

; BDFS file system  (beandeck)
MARVIN_BDFS_INIT              EQU 0x00AF  ; initialise BDFS RAM state
MARVIN_BDFS_SET_DRIVE         EQU 0x00B2  ; in: A=drive letter ('A'-'F')
MARVIN_BDFS_GET_DRIVE         EQU 0x00B5  ; out: Z=ok A=drive letter; NZ A=BDFS_ERR_NO_DRIVE
MARVIN_BDFS_SELECT_DRIVE      EQU 0x00B8  ; in: A=drive letter  out: Z=ok NZ=BDFS_ERR_NO_DEVICE
MARVIN_BDFS_FORMAT            EQU 0x00BB  ; in: HL=vol name (0=default)  out: Z=ok NZ=BDFS_ERR_*
MARVIN_BDFS_DIR_OPEN          EQU 0x00BE  ; out: Z=ok HL=vol name ptr; NZ=BDFS_ERR_NOT_FORMATTED
MARVIN_BDFS_DIR_NEXT          EQU 0x00C1  ; out: Z=ok HL=entry ptr; NZ=BDFS_ERR_END_OF_DIR C=active count
MARVIN_BDFS_FILE_WRITE        EQU 0x00C4  ; in: HL=filename DE=src BC=len  out: Z=ok NZ=BDFS_ERR_*
MARVIN_BDFS_GET_ERR_MSG       EQU 0x00C7  ; in: A=BDFS_ERR_*  out: HL=message string (0 if unknown)
MARVIN_BDFS_FILE_READ         EQU 0x00CA  ; in: HL=filename DE=dest  out: Z=ok BC=bytes NZ=BDFS_ERR_*  read file into RAM
MARVIN_BDFS_FILE_DELETE       EQU 0x00CD  ; in: HL=filename  out: Z=ok NZ=BDFS_ERR_*  soft-delete file

; String utilities  (all targets)
MARVIN_PUTCHAR_DEC            EQU 0x00D0  ; in: A=value               print byte as decimal (no leading zeros)
MARVIN_HEX_BYTE_VAL           EQU 0x00D3  ; in: HL=hex_str  out: A=byte HL=advanced  parse 2 hex chars to byte

ENDIF ; _MARVIN_INC
