; entry.asm - Entry points (all targets)
;
; Every fixed-address entry point into the ROM, shared by all targets, with or without
; BBC BASIC (INCLUDE_BASIC). Included first by each target's marvin.asm, followed by
; the target's boot.asm, which provides _boot.
;
;   0x0000          CPU reset: set SP, then the target's _boot
;   0x0008-0x0038   RST vectors, all redirect to 0x0000 (hardware reset)
;   0x0040-         Marvin trampoline functions (ABI)
;
; The ABI is a table of jp instructions at fixed ROM addresses from 0x0040, one 3-byte
; entry per service. Addresses must match abi/marvin.inc.
;
; Each entry jumps to the real function when the target's config.inc declares the
; hardware, and to _stub (returns immediately) when it doesn't:
;   HAS_LCD      - HD44780 LCD
;   HAS_KEYBOARD - matrix keyboard
;   HAS_RA8875   - RA8875 TFT display
;   HAS_FLASH    - W25Q flash cartridges, with BDFS
;
    EXTERN STACK
    EXTERN marvin_warmstart     ; monitor.asm - warm start
IFDEF INCLUDE_BASIC
    EXTERN START                ; MAIN.Z80 - BBC BASIC cold start
ELSE
    PUBLIC START                ; stub below - no BBC BASIC in this build
ENDIF
    EXTERN con_putchar          ; console - write character
    EXTERN con_putchar_hex      ; string.asm - print hex byte
    EXTERN con_puts             ; console - print string
    EXTERN con_getchar          ; console - blocking read
    EXTERN con_readchar         ; console - non-blocking read
    EXTERN usb_putchar          ; um245r.asm - USB write character
    EXTERN usb_puts             ; um245r.asm - USB print string
    EXTERN usb_readchar         ; um245r.asm - USB non-blocking read
    EXTERN con_putchar_dec      ; string.asm - print byte as decimal
    EXTERN hex_byte_val         ; string.asm - parse 2 hex chars to byte value
IFDEF HAS_LCD
    EXTERN lcd_init             ; hd44780.asm - LCD initialisation
    EXTERN lcd_putchar          ; hd44780.asm - LCD character output
    EXTERN lcd_puts             ; hd44780.asm - LCD print string
ENDIF
IFDEF HAS_KEYBOARD
    EXTERN key_readchar         ; keymatrix.asm - keyboard read
    EXTERN key_modifiers        ; keymatrix.asm - read modifier keys
ENDIF
IFDEF HAS_RA8875
    EXTERN ra8875_initialise    ; ra8875.asm - display init
    EXTERN ra8875_putchar       ; ra8875.asm - write character to display
    EXTERN ra8875_puts          ; ra8875.asm - RA8875 print string
    EXTERN ra8875_console_init  ; console.asm (ra8875-z80-repo) - console state init
    EXTERN ra8875_console_putchar ; console.asm - RA8875 console write character
    EXTERN ra8875_console_cursor_x ; console.asm - set cursor column
    EXTERN ra8875_console_cursor_y ; console.asm - set cursor row
    EXTERN ra8875_console_set_cursor_colour ; console.asm - set cursor colour
    EXTERN ra8875_console_set_background_colour ; console.asm - set background colour
    EXTERN ra8875_console_cursor_hide ; console.asm - hide software cursor
    EXTERN ra8875_console_cursor_show ; console.asm - show software cursor
ENDIF
IFDEF HAS_FLASH
    EXTERN flash_read           ; w25q.asm - read bytes from flash into RAM
    EXTERN flash_page_program   ; w25q.asm - write page to flash
    EXTERN flash_sector_erase   ; w25q.asm - erase 4KB sector
    EXTERN flash_select_slot    ; w25q.asm - select active cartridge slot
    EXTERN flash_read_jedec_id  ; w25q.asm - read JEDEC ID from current slot
    EXTERN flash_has_device     ; w25q.asm - check device present
    EXTERN flash_get_device_id  ; w25q.asm - get cached JEDEC ID
    EXTERN flash_get_device_name ; w25q.asm - get device name string
    EXTERN flash_get_capacity_mb ; w25q.asm - get capacity in MB
    EXTERN flash_get_sector_count ; w25q.asm - get total sector count
    EXTERN flash_bytes_to_sectors ; w25q.asm - byte count to sector count
    EXTERN flash_sector_to_addr ; w25q.asm - sector number to 24-bit address
    EXTERN bdfs_init            ; bdfs.asm - initialise BDFS RAM state
    EXTERN bdfs_set_drive       ; bdfs.asm - set active drive letter
    EXTERN bdfs_get_drive       ; bdfs.asm - get active drive letter
    EXTERN bdfs_select_drive    ; bdfs.asm - select drive slot and verify device
    EXTERN bdfs_format          ; bdfs.asm - erase and write directory header
    EXTERN bdfs_dir_open        ; bdfs.asm - prepare directory iterator
    EXTERN bdfs_dir_next        ; bdfs.asm - read next directory entry
    EXTERN bdfs_file_write      ; bdfs.asm - write file to current drive
    EXTERN bdfs_get_err_msg     ; bdfs.asm - error code to message string
    EXTERN bdfs_file_read       ; bdfs.asm - read file from current drive into RAM
    EXTERN bdfs_file_delete     ; bdfs.asm - soft-delete file on current drive
ENDIF
;
;
; ---- CPU Reset ----
;
    ORG 0x0000
    ld sp, STACK
    jp _boot                    ; target's boot.asm
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
ALIGN 0x0040
    jp marvin_warmstart  ; 0x0040 - warm start (monitor prompt)
    jp con_putchar       ; 0x0043 - write character (A = char)
    jp con_putchar_hex   ; 0x0046 - print A as two hex digits
    jp con_puts          ; 0x0049 - print string (HL = address, zero-terminated)
    jp con_getchar       ; 0x004C - wait for character (returns A)
    jp con_readchar      ; 0x004F - non-blocking read (returns A, 0 = none)
    jp usb_putchar       ; 0x0052 - USB write character (A = char)
    jp usb_puts          ; 0x0055 - USB print string (HL = address, zero-terminated)
    jp usb_readchar      ; 0x0058 - USB non-blocking read (returns A, 0 = none)
IFDEF HAS_LCD
    jp lcd_init          ; 0x005B - initialise LCD
    jp lcd_putchar       ; 0x005E - write character to LCD
    jp lcd_puts          ; 0x0061 - LCD print string (HL = address, zero-terminated)
ELSE
    jp _stub             ; 0x005B - lcd_init
    jp _stub             ; 0x005E - lcd_putchar
    jp _stub             ; 0x0061 - lcd_puts
ENDIF
IFDEF HAS_KEYBOARD
    jp key_readchar      ; 0x0064 - read keyboard
    jp key_modifiers     ; 0x0067 - read modifier keys
ELSE
    jp _stub             ; 0x0064 - key_readchar
    jp _stub             ; 0x0067 - key_modifiers
ENDIF
IFDEF HAS_RA8875
    jp ra8875_initialise ; 0x006A - ra8875 init
    jp ra8875_putchar    ; 0x006D - ra8875 putchar
    jp ra8875_puts       ; 0x0070 - ra8875 print string
    jp ra8875_console_init          ; 0x0073 - ra8875 console state init
    jp ra8875_console_putchar        ; 0x0076 - ra8875 console write character
    jp ra8875_console_cursor_x      ; 0x0079 - set cursor column (A = col)
    jp ra8875_console_cursor_y      ; 0x007C - set cursor row (A = row, logical)
    jp ra8875_console_set_cursor_colour ; 0x007F - set cursor colour (RA8875_COL_* in A)
    jp ra8875_console_set_background_colour ; 0x0082 - set console background colour (A = colour)
    jp ra8875_console_cursor_hide    ; 0x0085 - hide software cursor
    jp ra8875_console_cursor_show    ; 0x0088 - show software cursor
ELSE
    jp _stub             ; 0x006A - ra8875_init
    jp _stub             ; 0x006D - ra8875_putchar
    jp _stub             ; 0x0070 - ra8875_puts
    jp _stub             ; 0x0073 - ra8875_console_init
    jp _stub             ; 0x0076 - ra8875_console_putchar
    jp _stub             ; 0x0079 - ra8875_console_cursor_x
    jp _stub             ; 0x007C - ra8875_console_cursor_y
    jp _stub             ; 0x007F - ra8875_console_set_cursor_colour
    jp _stub             ; 0x0082 - ra8875_console_set_background_colour
    jp _stub             ; 0x0085 - ra8875_console_cursor_hide
    jp _stub             ; 0x0088 - ra8875_console_cursor_show
ENDIF
IFDEF HAS_FLASH
    jp flash_read                    ; 0x008B - flash read (A=addr[23:16], HL=addr[15:0], DE=dest, BC=len)
    jp flash_page_program            ; 0x008E - flash page program (HL=addr, DE=src, BC=len)
    jp flash_sector_erase            ; 0x0091 - flash sector erase (HL=sector number)
    jp flash_select_slot             ; 0x0094 - select flash slot (A=slot 1-6)
    jp flash_read_jedec_id           ; 0x0097 - read JEDEC ID (out: A=mfr B=type C=cap)
    jp flash_has_device              ; 0x009A - check device present (out: Z=present NZ=none)
    jp flash_get_device_id           ; 0x009D - get cached JEDEC ID (out: A=mfr B=type C=cap)
    jp flash_get_device_name         ; 0x00A0 - get device name string (out: HL=ptr)
    jp flash_get_capacity_mb         ; 0x00A3 - get capacity in MB (out: A=MB)
    jp flash_get_sector_count        ; 0x00A6 - get total sector count (out: HL=count)
    jp flash_bytes_to_sectors        ; 0x00A9 - bytes to sectors ceiling (in: HL=bytes out: A=sectors)
    jp flash_sector_to_addr          ; 0x00AC - sector to 24-bit addr (in: HL=sector out: A=addr[23:16] HL=addr[15:0])
    jp bdfs_init                     ; 0x00AF - initialise BDFS RAM state
    jp bdfs_set_drive                ; 0x00B2 - set active drive (in: A=drive letter)
    jp bdfs_get_drive                ; 0x00B5 - get active drive (out: Z=ok A=drive; NZ A=err)
    jp bdfs_select_drive             ; 0x00B8 - select drive slot and verify (in: A=drive letter out: Z=ok NZ=err)
    jp bdfs_format                   ; 0x00BB - format drive (in: HL=vol name out: Z=ok NZ=err)
    jp bdfs_dir_open                 ; 0x00BE - open directory iterator (out: Z=ok HL=vol name; NZ=err)
    jp bdfs_dir_next                 ; 0x00C1 - next directory entry (out: Z=ok HL=entry; NZ=err C=active count)
    jp bdfs_file_write               ; 0x00C4 - write file (in: HL=filename DE=src BC=len out: Z=ok NZ=err)
    jp bdfs_get_err_msg              ; 0x00C7 - error code to message string (in: A=BDFS_ERR_* out: HL=str)
    jp bdfs_file_read                ; 0x00CA - read file (in: HL=filename DE=dest out: Z=ok BC=bytes NZ=err)
    jp bdfs_file_delete              ; 0x00CD - delete file (in: HL=filename out: Z=ok NZ=err)
ELSE
    jp _stub             ; 0x008B - flash_read
    jp _stub             ; 0x008E - flash_page_program
    jp _stub             ; 0x0091 - flash_sector_erase
    jp _stub             ; 0x0094 - flash_select_slot
    jp _stub             ; 0x0097 - flash_read_jedec_id
    jp _stub             ; 0x009A - flash_has_device
    jp _stub             ; 0x009D - flash_get_device_id
    jp _stub             ; 0x00A0 - flash_get_device_name
    jp _stub             ; 0x00A3 - flash_get_capacity_mb
    jp _stub             ; 0x00A6 - flash_get_sector_count
    jp _stub             ; 0x00A9 - flash_bytes_to_sectors
    jp _stub             ; 0x00AC - flash_sector_to_addr
    jp _stub             ; 0x00AF - bdfs_init
    jp _stub             ; 0x00B2 - bdfs_set_drive
    jp _stub             ; 0x00B5 - bdfs_get_drive
    jp _stub             ; 0x00B8 - bdfs_select_drive
    jp _stub             ; 0x00BB - bdfs_format
    jp _stub             ; 0x00BE - bdfs_dir_open
    jp _stub             ; 0x00C1 - bdfs_dir_next
    jp _stub             ; 0x00C4 - bdfs_file_write
    jp _stub             ; 0x00C7 - bdfs_get_err_msg
    jp _stub             ; 0x00CA - bdfs_file_read
    jp _stub             ; 0x00CD - bdfs_file_delete
ENDIF
    jp con_putchar_dec   ; 0x00D0 - print decimal (in: A=value)
    jp hex_byte_val      ; 0x00D3 - parse hex byte (in: HL=str out: A=byte HL=advanced)
_stub:
    ret
;
; The monitor's b command jumps to START: BBC BASIC when it is in the build, otherwise
; back to the monitor
IFNDEF INCLUDE_BASIC
START:
    jp marvin_warmstart
ENDIF
