; entry_minimal.asm - Minimal Marvin Entry Point (BeanDeck target)
;
; Minimal boot + trampoline functions (ABI) for Marvin without BBC BASIC.
; USB console output, keyboard or USB input.
;   Reset → keyboard input
;   Shift-Reset → USB input
;
    EXTERN STACK

    EXTERN marvin_coldstart
    EXTERN marvin_warmstart
    EXTERN con_putchar
    EXTERN con_getchar
    EXTERN con_readchar
    EXTERN con_puts
    EXTERN con_putchar_hex
    EXTERN key_readchar
    EXTERN console_select
    EXTERN ra8875_initialise    ; ra8875.asm - display init
    EXTERN ra8875_putchar       ; ra8875.asm - write character to display
    EXTERN ra8875_console_init  ; console.asm (ra8875-z80-repo) - console state init
    EXTERN usb_putchar          ; um245r.asm - USB write character
    EXTERN usb_puts             ; um245r.asm - USB print string
    EXTERN usb_readchar         ; um245r.asm - USB non-blocking read
    EXTERN key_modifiers        ; keymatrix.asm - read modifier keys
    EXTERN ra8875_puts          ; ra8875.asm - RA8875 print string
    EXTERN ra8875_console_putchar ; console.asm - RA8875 console write character
    EXTERN ra8875_console_cursor_x ; console.asm - set cursor column
    EXTERN ra8875_console_cursor_y ; console.asm - set cursor row
    EXTERN ra8875_console_set_cursor_colour ; console.asm - set cursor colour
    EXTERN ra8875_console_set_background_colour ; console.asm - set background colour
    EXTERN ra8875_console_cursor_hide ; console.asm - hide software cursor
    EXTERN ra8875_console_cursor_show ; console.asm - show software cursor
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
    EXTERN con_putchar_dec      ; string.asm - print byte as decimal
    EXTERN hex_byte_val         ; string.asm - parse 2 hex chars to byte value
    EXTERN CAPS_LOCK_STATE

    PUBLIC START

    ORG MARVINORG
    ld sp, STACK
    jp _boot

; RST vectors and trampoline functions (ABI) at fixed addresses - must match abi/marvin.inc
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
    jp _stub             ; 0x005B - lcd_init (not available on beandeck)
    jp _stub             ; 0x005E - lcd_putchar (not available on beandeck)
    jp _stub             ; 0x0061 - lcd_puts (not available on beandeck)
    jp key_readchar      ; 0x0064 - read keyboard
    jp key_modifiers     ; 0x0067 - read modifier keys
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
    jp con_putchar_dec               ; 0x00D0 - print decimal (in: A=value)
    jp hex_byte_val                  ; 0x00D3 - parse hex byte (in: HL=str out: A=byte HL=advanced)
_stub:
    ret
;
; START stub - no BBC BASIC in minimal build
START:
    jp marvin_warmstart
;
;
; ---- Boot Selection ----
;
; BeanDeck: select console input source, then boot to monitor.
;   Shift held at reset → USB console input
;   No key → keyboard input
;
_boot:
    ld bc,0x8000                ; power-up debounce delay (~100ms at 10MHz)
_boot_powerup:
    nop
    dec bc
    ld a,b
    or c
    jr nz,_boot_powerup
    xor a
    ld (CAPS_LOCK_STATE),a      ; ensure caps off at startup
    call ra8875_initialise
    ld bc,0x8000                ; post-init settling delay (~100ms at 10MHz)
_boot_settle:
    nop
    dec bc
    ld a,b
    or c
    jr nz,_boot_settle
    call ra8875_console_init
    call console_select
    jp marvin_coldstart
