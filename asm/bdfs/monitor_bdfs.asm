; monitor_bdfs.asm - BDFS monitor layer
; Wraps bdfs.asm functions with console output for the monitor.

    INCLUDE "asm/core/chars.inc"
    INCLUDE "asm/bdfs/bdfs.inc"

    PUBLIC monitor_bdfs_format
    PUBLIC monitor_bdfs_dir
    PUBLIC monitor_bdfs_dir_all
    PUBLIC monitor_bdfs_drive
    PUBLIC monitor_bdfs_save
    PUBLIC monitor_bdfs_load
    PUBLIC monitor_bdfs_delete

    EXTERN con_puts
    EXTERN con_putchar
    EXTERN con_getchar
    EXTERN con_putchar_hex
    EXTERN con_putchar_dec
    EXTERN bdfs_select_drive
    EXTERN bdfs_format
    EXTERN bdfs_dir_open
    EXTERN bdfs_dir_next
    EXTERN bdfs_get_drive
    EXTERN bdfs_set_drive
    EXTERN bdfs_file_write
    EXTERN bdfs_file_read
    EXTERN bdfs_file_delete
    EXTERN hex_byte_val
    EXTERN BDFS_DRIVE
    EXTERN BDFS_HDR_BUF
    EXTERN BDFS_ENT_BUF
    EXTERN flash_get_device_id
    EXTERN flash_get_device_name
    EXTERN flash_get_capacity_mb
    EXTERN bdfs_get_err_msg
    EXTERN RAMSTART
    EXTERN BDFS_SECTOR_SIZE

; monitor_bdfs_format: 'f' command — confirm and format the current drive
; in:  HL = pointer into CMD_BUFFER past 'f' (optional volume name arg follows)
; out: — (all output already printed)
; destroys: AF, BC, DE, HL
monitor_bdfs_format:
    ld a, (hl)
    cp ' '
    jr nz, @get_drive
    inc hl
    jr monitor_bdfs_format
@get_drive:
    push hl                          ; save name pointer
    call bdfs_get_drive
    jr z, @confirm
    pop hl                           ; discard name ptr
    call _bdfs_cmd_error             ; A = BDFS_ERR_NO_DRIVE from bdfs_get_drive
    ret
@confirm:
    ld b, a                          ; save drive letter
    ld hl, _MSG_FORMAT_CONF_PRE
    call con_puts                    ; "Format "
    ld a, b
    call con_putchar                 ; drive letter
    ld hl, _MSG_FORMAT_CONF_POST
    call con_puts                    ; "? y/n "
    call con_getchar
    ld b, a                          ; save response before echo clobbers A
    call con_putchar                 ; echo
    ld a, CHAR_LF
    call con_putchar
    ld a, b
    cp 'y'
    jr z, @confirmed
    pop hl                           ; discard name ptr: user declined
    cp a                             ; Z = success (user declined, not an error)
    ret
@confirmed:
    pop hl                           ; restore name pointer
    ld a, (hl)
    or a
    jr nz, @execute
    ld hl, 0                         ; no name arg: use default
@execute:
    push hl                          ; save vol name ptr
    call bdfs_get_drive              ; A = drive letter (already confirmed valid above)
    call bdfs_select_drive
    jr z, @has_device
    pop hl                           ; discard vol name ptr
    call _bdfs_cmd_error             ; A = BDFS_ERR_NO_DEVICE from bdfs_select_drive
    ret
@has_device:
    ld hl, _MSG_FORMAT_PRE
    call con_puts                    ; "Formatting drive "
    ld a, (BDFS_DRIVE)
    call con_putchar
    ld a, CHAR_LF
    call con_putchar
    call _print_device_info          ; preserves HL
    pop hl                           ; restore vol name ptr
    call bdfs_format
    jr z, @completed
    call _bdfs_cmd_error
    ret
@completed:
    ld hl, _MSG_FORMAT_OK
    call con_puts
    ld hl, BDFS_HDR_BUF + BDFS_HDR_VOL_NAME_OFFSET
    call con_puts
    ld a, CHAR_LF
    call con_putchar
    cp a                             ; Z = success
    ret

; monitor_bdfs_dir: 'd' command — list active directory entries; deleted count at end
; in:  —
; out: — (all output already printed)
; destroys: AF, BC, DE, HL
monitor_bdfs_dir:
    call _dir_common_open
    ret nz
    ld e, 0                        ; E = deleted entry count
@scan:
    call bdfs_dir_next             ; preserves DE; NZ = end, C = active count
    jr nz, @done
    ld a, (BDFS_ENT_BUF + BDFS_ENT_FLAGS_OFFSET)
    bit BDFS_FLAG_DELETED_BIT, a
    jr z, @count_deleted           ; bit 0 = 0: deleted
    push de
    ld hl, _MSG_INDENT
    call con_puts
    call _print_entry_name_fixed
    call _print_entry_size
    ld a, CHAR_LF
    call con_putchar
    pop de
    jr @scan
@count_deleted:
    inc e
    jr @scan
@done:
    push de                        ; save E across print calls
    ld a, c
    call con_putchar_dec           ; active count
    ld hl, _MSG_FILES
    call con_puts                  ; " file(s)\n"
    pop de
    ld a, e
    or a
    ret z                          ; no deleted entries
    call con_putchar_dec
    ld hl, _MSG_DELETED_COUNT
    call con_puts                  ; " deleted\n"
    cp a                             ; Z = success
    ret

; monitor_bdfs_dir_all: 'D' command — list all directory entries including deleted
; in:  —
; out: — (all output already printed)
; destroys: AF, BC, DE, HL
monitor_bdfs_dir_all:
    call _dir_common_open
    ret nz
@scan:
    call bdfs_dir_next
    jr nz, @done
    ld a, (BDFS_ENT_BUF + BDFS_ENT_FLAGS_OFFSET)
    bit BDFS_FLAG_DELETED_BIT, a
    jr z, @item_deleted            ; bit 0 = 0: deleted
    ld hl, _MSG_INDENT
    call con_puts
    call _print_entry_name_fixed
    call _print_entry_size
    ld a, CHAR_LF
    call con_putchar
    jr @scan
@item_deleted:
    ld hl, _MSG_INDENT
    call con_puts
    call _print_entry_name_fixed
    call _print_entry_size
    ld hl, _MSG_DELETED
    call con_puts                  ; " (deleted)"
    ld a, CHAR_LF
    call con_putchar
    jr @scan
@done:
    ld a, c
    call con_putchar_dec           ; C = active entry count
    ld hl, _MSG_FILES
    call con_puts                  ; " file(s)\n"
    cp a                             ; Z = success
    ret

; _dir_common_open: shared setup for d/D — selects drive, opens directory,
; prints device info and volume name
; out: Z=ok; NZ=error, A=BDFS_ERR_* (already printed)
; destroys: AF, BC, HL
_dir_common_open:
    call bdfs_get_drive
    jr z, @has_drive
    call _bdfs_cmd_error
    ret
@has_drive:
    call bdfs_select_drive
    jr z, @selected
    call _bdfs_cmd_error
    ret
@selected:
    call bdfs_dir_open
    jr z, @opened
    call _bdfs_cmd_error
    ret
@opened:
    call _print_device_info        ; HL = vol name from bdfs_dir_open; preserves HL
    call con_puts                  ; print volume name
    ld a, CHAR_LF
    call con_putchar
    xor a                          ; Z=ok
    ret

; monitor_bdfs_drive: '@' command — select drive A-F
; in:  HL = pointer to drive letter char in CMD_BUFFER
; out: — (error message printed on invalid input)
; destroys: AF
monitor_bdfs_drive:
    ld a, (hl)
    call bdfs_set_drive
    ret z
    call _bdfs_cmd_error            ; A = BDFS_ERR_BAD_DRIVE from bdfs_set_drive
    ret

; monitor_bdfs_save: 's' command — save a region of RAM to the current drive as a named file
; in:  HL = pointer to CMD_BUFFER
; Syntax:  s <name.ext> [<hex-address> [<hex-length>]]
; Example: s HELLO.BAS 8000 0400
; Defaults: address=RAMSTART (8000), length=BDFS_SECTOR_SIZE (1000)
; out: — (all output already printed)
; destroys: AF, BC, DE, HL, IX
monitor_bdfs_save:
    ld a, (hl)
    or a
    jp z, @bad_usage                ; null before any filename
    cp ' '
    jr nz, @got_filename
    inc hl
    jr monitor_bdfs_save
@got_filename:
    push hl                         ; save filename ptr
@scan_name:
    ld a, (hl)
    or a
    jr z, @default_addr           ; null with no space: filename only, use defaults
    cp ' '
    jr z, @name_end
    inc hl
    jr @scan_name
@name_end:
    ld (hl), 0                      ; null-terminate filename in CMD_BUFFER
    inc hl
@find_addr_arg:
    ld a, (hl)
    or a
    jr z, @default_addr             ; no address — use RAMSTART
    cp ' '
    jr nz, @parse_addr_arg
    inc hl
    jr @find_addr_arg
@default_addr:
    ld de, RAMSTART
    ld bc, BDFS_SECTOR_SIZE
    jr @get_drive
@parse_addr_arg:
    call hex_byte_val               ; A = addr high byte; HL advances 2
    ld d, a
    call hex_byte_val               ; A = addr low byte; HL advances 2
    ld e, a                         ; DE = source address
@find_len_arg:
    ld a, (hl)
    or a
    jr z, @default_len              ; no length — use sector size
    cp ' '
    jr nz, @parse_len_arg
    inc hl
    jr @find_len_arg
@default_len:
    ld bc, BDFS_SECTOR_SIZE
    jr @get_drive
@parse_len_arg:
    call hex_byte_val               ; A = len high byte; HL advances 2
    ld b, a
    call hex_byte_val               ; A = len low byte; HL advances 2
    ld c, a                         ; BC = length; DE = source; stack: [FN]
@get_drive:
    call bdfs_get_drive
    jr z, @select_drive
    pop hl                          ; discard filename ptr
    call _bdfs_cmd_error            ; A = BDFS_ERR_NO_DRIVE from bdfs_get_drive
    ret
@select_drive:
    call bdfs_select_drive
    jr z, @execute
    pop hl                          ; discard filename ptr
    call _bdfs_cmd_error            ; A = BDFS_ERR_NO_DEVICE from bdfs_select_drive
    ret
@execute:
    pop hl                          ; HL = filename ptr
    call bdfs_file_write            ; HL=filename, DE=source, BC=length; Z=ok NZ=error; preserves BC, DE
    jr z, @done
    call _bdfs_cmd_error
    ret
@done:
    ld hl, _MSG_SAVED
    call con_puts                   ; "Saved "
    call _print_entry_name          ; print filename from BDFS_ENT_BUF
    ld a, ' '
    call con_putchar
    ld a, d
    call con_putchar_hex            ; source addr high byte
    ld a, e
    call con_putchar_hex            ; source addr low byte
    ld a, ' '
    call con_putchar
    ld a, b
    call con_putchar_hex            ; length high byte
    ld a, c
    call con_putchar_hex            ; length low byte
    ld a, CHAR_LF
    call con_putchar
    cp a                             ; Z = success
    ret
@bad_usage:
    ld hl, _MSG_SAVE_USAGE
    call con_puts
    or 0FFh                          ; NZ = error
    ret

; monitor_bdfs_load: 'l' command — load a named file from the current drive into RAM
; in:  HL = pointer into CMD_BUFFER past 'l'
; Syntax:  l <name.ext> [<hex-address>]
; Example: l HELLO.BAS 8000
; Default: address = RAMSTART
; out: — (all output already printed)
; destroys: AF, BC, DE, HL, IX
monitor_bdfs_load:
    ld a, (hl)
    or a
    jp z, @bad_usage                ; null before any filename
    cp ' '
    jr nz, @got_filename
    inc hl
    jr monitor_bdfs_load
@got_filename:
    push hl                         ; save filename ptr
@scan_name:
    ld a, (hl)
    or a
    jr z, @default_addr             ; null with no space: filename only, use default
    cp ' '
    jr z, @name_end
    inc hl
    jr @scan_name
@name_end:
    ld (hl), 0                      ; null-terminate filename in CMD_BUFFER
    inc hl
@find_addr_arg:
    ld a, (hl)
    or a
    jr z, @default_addr             ; no address — use RAMSTART
    cp ' '
    jr nz, @parse_addr_arg
    inc hl
    jr @find_addr_arg
@default_addr:
    ld de, RAMSTART
    jr @get_drive
@parse_addr_arg:
    call hex_byte_val               ; A = addr high byte; HL advances 2
    ld d, a
    call hex_byte_val               ; A = addr low byte; HL advances 2
    ld e, a                         ; DE = destination address
@get_drive:
    call bdfs_get_drive
    jr z, @select_drive
    pop hl                          ; discard filename ptr
    call _bdfs_cmd_error
    ret
@select_drive:
    call bdfs_select_drive
    jr z, @execute
    pop hl                          ; discard filename ptr
    call _bdfs_cmd_error
    ret
@execute:
    pop hl                          ; HL = filename ptr
    push de                         ; save original dest addr; flash_read advances DE
    ld bc, 0                        ; no size limit
    call bdfs_file_read             ; HL=filename, DE=dest, BC=max_size; Z=ok BC=bytes, NZ=error A=BDFS_ERR_*
    jr z, @done
    pop de                          ; balance stack
    call _bdfs_cmd_error
    ret
@done:
    pop de                          ; restore original dest addr for confirmation message
    ld hl, _MSG_LOADED
    call con_puts                   ; "Loaded "
    call _print_entry_name          ; print filename from BDFS_ENT_BUF
    ld a, ' '
    call con_putchar
    ld a, d
    call con_putchar_hex            ; dest addr high byte
    ld a, e
    call con_putchar_hex            ; dest addr low byte
    ld a, ' '
    call con_putchar
    ld a, b
    call con_putchar_hex            ; length high byte
    ld a, c
    call con_putchar_hex            ; length low byte
    ld a, CHAR_LF
    call con_putchar
    cp a                             ; Z = success
    ret
@bad_usage:
    ld hl, _MSG_LOAD_USAGE
    call con_puts
    or 0FFh                          ; NZ = error
    ret

; monitor_bdfs_delete: 'e' erase command — soft-delete a named file from the current drive
; in:  HL = pointer into CMD_BUFFER past 'e'
; Syntax:  e <name.ext>
; Example: e HELLO.BIN
; out: — (all output already printed)
; destroys: AF, BC, DE, HL, IX
monitor_bdfs_delete:
    ld a, (hl)
    or a
    jp z, @bad_usage                  ; found null
    cp ' '
    jr nz, @got_filename              ; found a non-space (and non-null) character - we have a name
    inc hl
    jr monitor_bdfs_delete
@got_filename:
    push hl                           ; save filename ptr
@scan_name:
    ld a, (hl)
    or a
    jr z, @get_drive                  ; null: end of name
    cp ' '
    jr z, @name_end                   ; trim trailing space
    inc hl
    jr @scan_name
@name_end:
    ld (hl), 0                        ; null-terminate filename in CMD_BUFFER (trim trailing space)
@get_drive:
    call bdfs_get_drive
    jr z, @select_drive
    pop hl                            ; discard filename ptr
    call _bdfs_cmd_error
    ret
@select_drive:
    call bdfs_select_drive
    jr z, @execute
    pop hl                            ; discard filename ptr
    call _bdfs_cmd_error
    ret
@execute:
    ld hl, _MSG_DELETE_CONF_PRE
    call con_puts                     ; "Delete "
    pop hl                            ; HL = filename ptr
    push hl                           ; save for bdfs_file_delete
    call con_puts                     ; filename (null-terminated in CMD_BUFFER)
    ld hl, _MSG_FORMAT_CONF_POST
    call con_puts                     ; "? y/n "
    call con_getchar
    ld b, a
    call con_putchar                  ; echo
    ld a, CHAR_LF
    call con_putchar
    ld a, b
    cp 'y'
    pop hl                            ; filename ptr
    jr nz, @cancelled
    call bdfs_file_delete             ; HL=filename; Z=ok, NZ=error A=BDFS_ERR_*
    jr z, @done
    call _bdfs_cmd_error
    ret
@cancelled:
    cp a                             ; Z = success (user declined, not an error)
    ret
@done:
    ld hl, _MSG_DEL_OK
    call con_puts                     ; "Deleted "
    call _print_entry_name            ; name from BDFS_ENT_BUF (populated by bdfs_file_delete scan)
    ld a, CHAR_LF
    call con_putchar
    cp a                             ; Z = success
    ret
@bad_usage:
    ld hl, _MSG_DELETE_USAGE
    call con_puts
    or 0FFh                          ; NZ = error
    ret

; helpers

; _print_entry_name: print 8.3 filename from BDFS_ENT_BUF, trimmed (e.g. "HELLO.TXT")
; destroys: AF, BC, HL
_print_entry_name:
    push af
    push bc
    push hl
    ld hl, BDFS_ENT_BUF + BDFS_ENT_NAME_OFFSET
    ld b, BDFS_NAME_LEN
    call _print_entry_name_part
    ld a, (BDFS_ENT_BUF + BDFS_ENT_EXT_OFFSET)
    cp ' '                          ; leading space means no extension
    jr z, @done
    ld a, '.'
    call con_putchar
    ld hl, BDFS_ENT_BUF + BDFS_ENT_EXT_OFFSET
    ld b, BDFS_EXT_LEN
    call _print_entry_name_part
@done:
    pop hl
    pop bc
    pop af
    ret

; _print_entry_name_fixed: print 8.3 filename from BDFS_ENT_BUF, fixed width (always 12 chars)
; Format: "NAME     EXT" — name space-padded to 8, space separator, ext space-padded to 3
; destroys: AF, BC, HL
_print_entry_name_fixed:
    push af
    push bc
    push hl
    ld hl, BDFS_ENT_BUF + BDFS_ENT_NAME_OFFSET
    ld b, BDFS_NAME_LEN
@name:
    ld a, (hl)
    call con_putchar
    inc hl
    dec b
    jr nz, @name
    ld a, ' '
    call con_putchar
    ld hl, BDFS_ENT_BUF + BDFS_ENT_EXT_OFFSET
    ld b, BDFS_EXT_LEN
@ext:
    ld a, (hl)
    call con_putchar
    inc hl
    dec b
    jr nz, @ext
    pop hl
    pop bc
    pop af
    ret

; _print_entry_name_part: print up to B chars from (HL), stopping at first space (trims padding)
; in:  HL = source, B = max chars
; destroys: AF, BC, HL
_print_entry_name_part:
    push af
    push hl
    push bc
@loop:
    ld a, b
    or a
    jr z, @done
    ld a, (hl)
    cp ' '
    jr z, @done
    call con_putchar
    inc hl
    dec b
    jr @loop
@done:
    pop bc
    pop hl
    pop af
    ret

; _print_entry_size: print file size from BDFS_ENT_BUF as " XXXX" (space + 4 hex digits)
; destroys: AF, BC
_print_entry_size:
    ld a, ' '
    call con_putchar
    ld a, (BDFS_ENT_BUF + BDFS_ENT_LENGTH_OFFSET + 1)  ; high byte
    call con_putchar_hex
    ld a, (BDFS_ENT_BUF + BDFS_ENT_LENGTH_OFFSET)      ; low byte
    call con_putchar_hex
    ret

; _print_device_info: print label, capacity, and JEDEC ID e.g. "W25Q16 2MB [ef4015]\n"
; destroys: -
_print_device_info:
    push af
    push bc
    push de
    push hl
    call flash_get_device_name      ; HL = name string
    call con_puts
    ld a, ' '
    call con_putchar
    call flash_get_capacity_mb      ; A = MB
    call con_putchar_dec
    ld hl, _MSG_MB
    call con_puts
    call flash_get_device_id        ; A=mfr, B=type, C=cap
    call con_putchar_hex            ; print mfr
    ld a, b
    call con_putchar_hex            ; print type
    ld a, c
    call con_putchar_hex            ; print cap
    ld hl, _MSG_ID_CLOSE
    call con_puts
    pop hl
    pop de
    pop bc
    pop af
    ret

; _bdfs_cmd_error: print error message for any BDFS_ERR_* code
; in:  A = BDFS_ERR_* code
; out: A = original error code, NZ set (all BDFS error codes are non-zero)
; destroys: HL
_bdfs_cmd_error:
    push af
    call bdfs_get_err_msg
    ld a, h
    or l
    jr z, @exit                    ; no message for this code
    call con_puts
@exit:
    pop af
    or a                           ; restore error code; NZ guaranteed
    ret

; strings
_MSG_FORMAT_CONF_PRE:   db "Format ", 0
_MSG_FORMAT_CONF_POST:  db "? y/n ", 0
_MSG_FORMAT_PRE:        db "Formatting drive ", 0
_MSG_FORMAT_OK:         db "Format ok - ", 0
_MSG_INDENT:            db "  ", 0
_MSG_DELETED:           db " (deleted)", 0
_MSG_FILES:             db " file(s)", CHAR_LF, 0
_MSG_DELETED_COUNT:     db " deleted", CHAR_LF, 0
_MSG_MB:                db "MB [", 0
_MSG_ID_CLOSE:          db "]", CHAR_LF, 0
_MSG_SAVED:             db "Saved ", 0
_MSG_SAVE_USAGE:        db "s <name.ext> [<addr> [<len>]]", CHAR_LF, 0
_MSG_LOADED:            db "Loaded ", 0
_MSG_LOAD_USAGE:        db "l <name.ext> [<addr>]", CHAR_LF, 0
_MSG_DELETE_CONF_PRE:   db "Delete ", 0
_MSG_DEL_OK:            db "Deleted ", 0
_MSG_DELETE_USAGE:      db "k <name.ext>", CHAR_LF, 0
