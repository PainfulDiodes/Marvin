; bdfs.asm - BeanDeck File System
;
; Deletion and free-space fragmentation:
;   Deleting a file marks its directory entry as deleted but does not erase its sectors.
;   New files are written after the last *active* file's end sector, so deleted sectors
;   at the tail of used space are silently reclaimed; deleted sectors surrounded by active
;   files are stranded until a full reclaim (e.g. copy all active files to a second drive,
;   format this drive, copy back - or some other reclaim / defrag process).
;
; Flash medium assumptions (coupled to underlying device geometry):
;   Sector size : 4096 bytes — erase unit; directory sector holds exactly 255 entries
;                 (16-byte header + 255 × 16-byte entries = 4096)
;   Page size   : 256 bytes  — write unit; file data written in 256-byte pages
;   Address width: 24 bits   — passed as A:HL (A = addr[23:16], HL = addr[15:0])
;   Directory   : sector 0; file data starts at sector 1 (BDFS_DATA_START_SECTOR)

    INCLUDE "asm/bdfs/bdfs.inc"
    INCLUDE "asm/core/chars.inc"

; Magic bytes - used on the directory sector to indicate a formatted drive
BDFS_MAGIC_0            EQU 0xBD
BDFS_MAGIC_1            EQU 0x01

; volume layout
BDFS_DIR_SECTOR         EQU 0x0000
BDFS_DATA_START_SECTOR  EQU 0x0001

; Entry state
BDFS_ENT_EMPTY        EQU 0xFF    ; name[0] = FF means no more entries; 0xFF is the erased state, names can't include 0xFF

; Format field sizes
; BDFS_HDR_SIZE and BDFS_ENT_SIZE are both multiples of W25Q_PAGE_SIZE (256) and
; exact divisors of W25Q_SECTOR_SIZE (4096), so reads and writes never cross page
; or sector boundaries. As a result the directory sector holds exactly 4096/16 - 1 = 255 entries.
BDFS_VOL_NAME_LEN     EQU 12
BDFS_HDR_SIZE         EQU 16   ; 2 (magic) + 12 (vol name) + 2 (reserved)
BDFS_ENT_SIZE         EQU 16   ; 8 (name) + 3 (ext) + 2 (sector) + 2 (length) + 1 (flags)

; Directory header offsets
BDFS_HDR_MAGIC_OFFSET        EQU 0       ; 2 bytes
BDFS_HDR_RESERVED_OFFSET     EQU 14      ; 2 bytes


    PUBLIC bdfs_get_err_msg
    PUBLIC bdfs_init
    PUBLIC bdfs_select_drive
    PUBLIC bdfs_format
    PUBLIC bdfs_dir_open
    PUBLIC bdfs_dir_next
    PUBLIC bdfs_file_write
    PUBLIC bdfs_file_read
    PUBLIC bdfs_file_delete
    PUBLIC bdfs_set_drive
    PUBLIC bdfs_get_drive
    PUBLIC BDFS_SECTOR_SIZE

    EXTERN flash_select_slot
    EXTERN flash_has_device
    EXTERN flash_sector_erase
    EXTERN flash_page_program
    EXTERN flash_get_sector_count
    EXTERN flash_bytes_to_sectors
    EXTERN flash_sector_to_addr
    EXTERN flash_read
    EXTERN W25Q_SECTOR_SIZE     ; hardware geometry — erase unit
    EXTERN W25Q_PAGE_SIZE       ; hardware geometry — write unit

; Aliases coupling BDFS to W25Q geometry (hardware dependency made explicit)
BDFS_SECTOR_SIZE EQU W25Q_SECTOR_SIZE
_PAGE_SIZE      EQU W25Q_PAGE_SIZE
_MAX_ENTRIES    EQU (BDFS_SECTOR_SIZE / BDFS_ENT_SIZE) - 1  ; -1 : header occupies one slot

; ---- RAM variables: bdfs_ram.asm ----

; bdfs_init: called once at cold start
; Sets BDFS_DRIVE to the lowest drive letter ('A'-'F') with a device present,
; or 0 if no device is found.
; in:  —
; out: —
; destroys: AF
bdfs_init:
    push bc
    ld b, BDFS_FIRST_DRIVE
@loop:
    ld a, b
    call bdfs_select_drive          ; Z=ok (device present), NZ=no device; preserves BC
    jr z, @found
    inc b
    ld a, b
    cp BDFS_LAST_DRIVE + 1
    jr c, @loop
    xor a                           ; no device found: drive = 0 (none)
    ld (BDFS_DRIVE), a
    jr @exit
@found:
    ld a, b
    ld (BDFS_DRIVE), a
@exit:
    pop bc
    ret

; bdfs_set_drive: validate and record the active drive letter
; in:  A = drive letter ('A'-'F', upper or lower case)
; out: Z=ok; NZ=error, A=BDFS_ERR_BAD_DRIVE
; destroys: AF
bdfs_set_drive:
    and 0dfh                        ; fold lowercase to uppercase
    cp BDFS_FIRST_DRIVE
    jr c, @bad
    cp BDFS_LAST_DRIVE + 1
    jr nc, @bad
    ld (BDFS_DRIVE), a
    cp a                            ; Z=ok
    ret
@bad:
    ld a, BDFS_ERR_BAD_DRIVE
    or a                            ; NZ
    ret

; bdfs_get_drive: return the current drive letter
; in:  —
; out: Z=ok, A = drive letter ('A'-'F')
;      NZ=no drive, A=BDFS_ERR_NO_DRIVE
; destroys: AF
bdfs_get_drive:
    ld a, (BDFS_DRIVE)
    or a
    jr z, @no_drive
    cp a                            ; Z set, A = drive letter unchanged
    ret
@no_drive:
    ld a, BDFS_ERR_NO_DRIVE
    or a
    ret

; bdfs_select_drive: select the slot for a drive letter and verify a device is present
; must be performed before read/write activities, as the SPI transport may be used for 
; other things and therefore may disrupt the active slot.
; in:  A = drive letter ('A'-'F')
; out: Z=ok, NZ=error A=BDFS_ERR_NO_DEVICE
; destroys: AF
bdfs_select_drive:
    push bc
    push de
    push hl
    sub BDFS_FIRST_DRIVE - 1        ; A = slot number (1-6)
    call flash_select_slot
    call flash_has_device
    jr nz, @no_device
    xor a
    jr @exit
@no_device:
    ld a, BDFS_ERR_NO_DEVICE
@exit:
    pop hl
    pop de
    pop bc
    or a
    ret

; bdfs_format: erase sector 0 of the current drive and write a BDFS directory header
; assumes bdfs_select_drive has been called
; in:  HL = volume name string (null-terminated, max BDFS_VOL_NAME_LEN-1 chars), or 0 for default
; out: Z=ok (format succeeded)
;      NZ=error, A=BDFS_ERR_* code
; destroys: AF
bdfs_format:
    push bc
    push de
    push hl                         ; name ptr
    ld hl, BDFS_DIR_SECTOR          ; sector 0 = directory sector
    call flash_sector_erase         ; Z=ok NZ=fail
    jr z, @erase_ok
    ld a, BDFS_ERR_ERASE_FAIL
    jp @exit
@erase_ok:
    ; build 16-byte header in BDFS_HDR_BUF: magic + vol_name + reserved
    ld hl, BDFS_HDR_BUF
    ld (hl), BDFS_MAGIC_0
    inc hl
    ld (hl), BDFS_MAGIC_1
    inc hl
    ex de, hl                       ; DE = vol_name field ptr
    pop hl                          ; HL = name ptr (saved on stack at entry)
    push hl                         ; restore stack for exit
    ld a, h
    or l
    jr z, @default_name
    ; custom name: copy up to BDFS_VOL_NAME_LEN chars, ensure null-terminated
    ld b, BDFS_VOL_NAME_LEN
@copy_name:
    ld a, (hl)
    or a
    jr z, @name_null_fill              ; end of source: null-fill remaining
    ld (de), a
    inc hl
    inc de
    djnz @copy_name
    ; wrote full BDFS_VOL_NAME_LEN chars: overwrite last with null terminator
    dec de
    xor a
    ld (de), a
    inc de
    jr @reserved
@name_null_fill:
    xor a
@name_null_fill_loop:
    ld (de), a
    inc de
    djnz @name_null_fill_loop
    jr @reserved
@default_name:
    ld hl, _BDFS_DEFAULT_PREFIX
    ld bc, _BDFS_DEFAULT_PREFIX_LEN
    ldir                            ; copy "BDFS-", DE now points past it
    ld a, (BDFS_DRIVE)
    ld (de), a
    inc de
    ld b, BDFS_VOL_NAME_LEN - _BDFS_DEFAULT_PREFIX_LEN - 1   ; remaining space after drive letter
@default_name_null_fill:
    xor a
    ld (de), a
    inc de
    djnz @default_name_null_fill
@reserved:
    xor a
    ld (de), a
    inc de
    ld (de), a
    ; write the buffer to flash
    xor a                           ; addr[23:16] = 0x00
    ld hl, 0x0000                   ; addr[15:0]
    ld de, BDFS_HDR_BUF
    ld bc, BDFS_HDR_SIZE
    call flash_page_program         ; Z=ok NZ=fail
    jr z, @write_ok
    ld a, BDFS_ERR_WRITE_FAIL
    jp @exit
@write_ok:
    ; read back to buffer
    xor a                           ; addr[23:16] = 0x00
    ld hl, 0x0000                   ; addr[15:0]
    ld de, BDFS_HDR_BUF
    ld bc, BDFS_HDR_SIZE
    call flash_read
    ; verify magic
    ld a, (BDFS_HDR_BUF + BDFS_HDR_MAGIC_OFFSET)
    cp BDFS_MAGIC_0
    jr nz, @verify_magic_fail
    ld a, (BDFS_HDR_BUF + BDFS_HDR_MAGIC_OFFSET + 1)
    cp BDFS_MAGIC_1
    jr nz, @verify_magic_fail
    ; success
    xor a                           ; Z set, A=0
    jr @exit
@verify_magic_fail:
    ld a, BDFS_ERR_VERIFY_FAIL
@exit:
    pop hl
    pop de
    pop bc
    or a
    ret

; bdfs_dir_open: prepare to iterate the current drive's directory
; assumes bdfs_select_drive has been called
; in:  —
; out: Z=ok, HL = pointer to null-terminated volume name (in BDFS_HDR_BUF)
;      NZ=error, A=BDFS_ERR_NOT_FORMATTED
; destroys: AF, HL
bdfs_dir_open:
    push bc
    push de
    xor a                           ; addr[23:16] = 0x00
    ld hl, 0x0000                   ; addr[15:0]
    ld de, BDFS_HDR_BUF
    ld bc, BDFS_HDR_SIZE
    call flash_read
    ld a, (BDFS_HDR_BUF + BDFS_HDR_MAGIC_OFFSET)
    cp BDFS_MAGIC_0
    jr nz, @not_formatted
    ld a, (BDFS_HDR_BUF + BDFS_HDR_MAGIC_OFFSET + 1)
    cp BDFS_MAGIC_1
    jr nz, @not_formatted
    ; initialise iterator state
    ld hl, BDFS_HDR_SIZE
    ld (_DIR_SCAN_OFST), hl
    xor a
    ld (_ACTIVE_COUNT), a
    ld hl, BDFS_HDR_BUF + BDFS_HDR_VOL_NAME_OFFSET
    xor a                           ; Z set, A=0
    jr @exit
@not_formatted:
    ld a, BDFS_ERR_NOT_FORMATTED
@exit:
    pop de
    pop bc
    ; A=0 on success (no return value), non-zero = error code → NZ
    or a                            
    ret

; bdfs_dir_next: read the next directory entry into BDFS_ENT_BUF
; in:  — (iterator state in _DIR_SCAN_OFST / _ACTIVE_COUNT, set by bdfs_dir_open)
; out: Z=ok, HL = pointer to entry (BDFS_ENT_BUF); check flags byte for deleted status
;      NZ=BDFS_ERR_END_OF_DIR, C = active entry count
; destroys: AF, BC, HL
bdfs_dir_next:
    push de
    xor a                           ; addr[23:16] = 0x00
    ld hl, (_DIR_SCAN_OFST)         ; addr[15:0] = current iterator position
    ld de, BDFS_ENT_BUF
    ld bc, BDFS_ENT_SIZE
    call flash_read
    ; empty entry signals end of directory
    ld a, (BDFS_ENT_BUF + BDFS_ENT_NAME_OFFSET)
    cp BDFS_ENT_EMPTY
    jr z, @empty
    ; advance iterator to next entry
    ld hl, (_DIR_SCAN_OFST)
    ld bc, BDFS_ENT_SIZE
    add hl, bc
    ld (_DIR_SCAN_OFST), hl
    ; increment active count only for non-deleted entries
    ld a, (BDFS_ENT_BUF + BDFS_ENT_FLAGS_OFFSET)
    bit BDFS_FLAG_DELETED_BIT, a
    jr z, @return                   ; deleted (bit 0 = 0): skip count increment
    ld a, (_ACTIVE_COUNT)
    inc a
    ld (_ACTIVE_COUNT), a
@return:
    ld hl, BDFS_ENT_BUF
    xor a                           ; Z set, A=0
    jr @exit
@empty:
    ld a, (_ACTIVE_COUNT)
    ld c, a                         ; C = active entry count
    ld a, BDFS_ERR_END_OF_DIR
@exit:
    pop de
    or a
    ret

; bdfs_file_write: write a file to the current drive
; assumes bdfs_select_drive has been called
; in:  HL = filename (null-terminated "NAME.EXT")
;      DE = source address in RAM
;      BC = length in bytes
; out: Z=ok, NZ=error (A=BDFS_ERR_*)
; destroys: AF, HL, IX
bdfs_file_write:
    ; Reject BC=0: flash_read with BC=0 underflows the loop counter to 0xFFFF and
    ; reads 65536 bytes, overwriting all RAM. Also _file_write_erase_sectors with B=0
    ; uses djnz which loops 256 times.
    ld a, b
    or c
    jr z, @empty                        ; BC=0: reject zero-length files
    ; Reject files > 0xF000 bytes: flash_bytes_to_sectors adds sector_size-1 before
    ; dividing; HL + 0x0FFF overflows 16 bits for any length above 0xF000.
    ld a, b
    cp 0xF1                             ; carry if B <= 0xF0
    jr nc, @too_large                   ; B >= 0xF1: BC > 0xF0FF > 0xF000
    cp 0xF0                             ; carry if B < 0xF0, Z if B == 0xF0
    jr nz, @size_ok                     ; B < 0xF0: BC <= 0xEFFF, OK
    ld a, c
    or a
    jr nz, @too_large                   ; B == 0xF0, C > 0: BC > 0xF000
@size_ok:
    push bc                             ; preserve length for caller
    push de                             ; preserve source addr for caller
    ld ix, _SRCH_BUF
    call _parse_filename                ; fills _SRCH_BUF[0:10]; preserves BC, DE, HL
    push hl                             ; filename
    call _file_write_data               ; BC=length, DE=source; preserves BC
    jr nz, @data_fail
    pop hl                              ; HL = filename; BC = length preserved
    ld ix, BDFS_ENT_BUF
    call _parse_filename                ; fills BDFS_ENT_BUF bytes 0-10; preserves BC, DE, HL
    ld hl, (_NEXT_FREE_SECTOR)
    ld (BDFS_ENT_BUF + BDFS_ENT_SECTOR_OFFSET), hl ; bytes 11-12, little-endian
    ld h, b
    ld l, c                             ; HL = length (BC has no ld (nn),bc form)
    ld (BDFS_ENT_BUF + BDFS_ENT_LENGTH_OFFSET), hl ; bytes 13-14, little-endian
    ld a, BDFS_FLAGS_INITIAL
    ld (BDFS_ENT_BUF + BDFS_ENT_FLAGS_OFFSET), a   ; all flag bits unprogrammed (erased state)
    ld hl, (_FREE_ENTRY_OFFSET)         ; flash byte offset of empty directory slot
    ld de, BDFS_ENT_BUF
    ld bc, BDFS_ENT_SIZE
    xor a                               ; addr[23:16] = 0; directory is always in sector 0
    call flash_page_program             ; Z=ok, NZ=timeout
    jr nz, @dir_fail
    xor a                               ; Z set, A = 0
    jr @exit
@dir_fail:
    ld a, BDFS_ERR_WRITE_FAIL
    or a                                ; NZ
    jr @exit
@data_fail:
    pop hl                              ; discard filename
    or a                                ; NZ (A = error code from _file_write_data)
@exit:
    pop de
    pop bc
    ret
@empty:
    ld a, BDFS_ERR_EMPTY_FILE
    or a                                ; NZ
    ret
@too_large:
    ld a, BDFS_ERR_FILE_TOO_LARGE
    or a                                ; NZ
    ret
; _file_write_data: verify format, scan directory, check space, erase and write file data
; in:  BC = length, DE = source
; out: Z=ok; _FREE_ENTRY_OFFSET and _NEXT_FREE_SECTOR populated by scan
;      NZ+A=BDFS_ERR_*
; destroys: AF, DE, HL, IX
_file_write_data:
    push bc                             ; [BC]        length
    push de                             ; [BC DE]     source
    call _verify_drive_formatted        ; destroys AF
    jr nz, @abort
    call _file_write_scan_dir           ; destroys AF, B, IX
    jr nz, @abort
    pop de                              ; source — pass to device check
    pop bc                              ; length — pass to device check
    push bc                             ; re-save length
    push de                             ; re-save source
    call _file_write_device_full_check  ; BC = length; Z=ok B=sectors_needed, NZ+A=err
    jr nz, @abort
    call _file_write_erase_sectors      ; B = sectors_needed; Z=ok, NZ+A=err
    jr nz, @abort
    pop de                              ; DE = source
    pop bc                              ; BC = length
    call _file_write_prog_pages         ; Z=ok, NZ+A=BDFS_ERR_WRITE_FAIL; preserves BC
    ret                                 ; Z or NZ propagated directly from prog_pages
@abort:
    pop de                              ; discard source
    pop bc                              ; discard length
    or a                                ; NZ (A = error code)
    ret


; _file_write_scan_dir: scan the directory to locate the first empty slot, check for duplicate
; names, and locate last active sector
; in:  —
; out: Z=ok; _FREE_ENTRY_OFFSET = first empty slot, _NEXT_FREE_SECTOR = first free sector
;      NZ+A=BDFS_ERR_DIR_FULL (all 255 entry slots occupied)
; destroys: AF, B, IX
_file_write_scan_dir:
    ld hl, 0x0000
    ld (_FREE_ENTRY_OFFSET), hl     ; = 0 (not yet found)
    ld hl, BDFS_DATA_START_SECTOR
    ld (_NEXT_FREE_SECTOR), hl      ; = first data sector
    ld ix, BDFS_HDR_SIZE            ; scan_offset = first entry
    ld b, 0                         ; entry count
@loop:
    call _file_write_scan_dir_entry ; Z=occupied, NZ=empty
    jr nz, @found_empty
    ld a, (BDFS_ENT_BUF + BDFS_ENT_FLAGS_OFFSET)
    bit BDFS_FLAG_DELETED_BIT, a
    jr z, @next                         ; deleted (bit 0 = 0): skip duplicate check
    call _compare_name_fields            ; Z=match (BDFS_ENT_BUF vs _SRCH_BUF)
    jr z, @duplicate
@next:
    ld de, BDFS_ENT_SIZE
    add ix, de                      ; advance scan_offset
    inc b                           ; entry count
    ld a, b
    cp _MAX_ENTRIES                 ; directory sector full
    jr z, @full
    jr @loop
@duplicate:
    ld a, BDFS_ERR_FILE_EXISTS
    or a                            ; NZ
    ret
@found_empty:
    push ix
    pop hl
    ld (_FREE_ENTRY_OFFSET), hl
    xor a                           ; Z: ok
    ret
@full:
    ld a, BDFS_ERR_DIR_FULL
    or a                            ; NZ
    ret
; _file_write_scan_dir_entry: read one directory entry at IX and update scan state
; in:  IX = flash byte offset of entry to read
; out: Z = occupied (active or deleted); _NEXT_FREE_SECTOR updated if active
;      NZ = empty entry (end of directory)
; destroys: AF
_file_write_scan_dir_entry:
    push bc
    push de
    push hl
    push ix
    pop hl                          ; HL = scan offset (flash address)
    xor a                           ; addr[23:16] = 0
    ld de, BDFS_ENT_BUF
    ld bc, BDFS_ENT_SIZE
    call flash_read
    ld a, (BDFS_ENT_BUF + BDFS_ENT_NAME_OFFSET)
    cp BDFS_ENT_EMPTY
    jr z, @empty
    ld a, (BDFS_ENT_BUF + BDFS_ENT_FLAGS_OFFSET)
    bit BDFS_FLAG_DELETED_BIT, a
    jr z, @done                                ; deleted (bit 0 = 0): skip sector update
    ; active: end_sector = start_sector + num_sectors
    ld hl, (BDFS_ENT_BUF + BDFS_ENT_LENGTH_OFFSET)
    call flash_bytes_to_sectors     ; A = num sectors
    ld hl, (BDFS_ENT_BUF + BDFS_ENT_SECTOR_OFFSET)
    ld d, 0
    ld e, a
    add hl, de                      ; HL = end_sector
    ld (_NEXT_FREE_SECTOR), hl      ; always ascending: last active entry wins
@done:
    xor a                           ; Z: occupied
    jr @exit
@empty:
    ld a, 1                         ; NZ: empty
@exit:
    pop hl
    pop de
    pop bc
    or a
    ret
; _file_write_device_full_check: check whether BC bytes fit in remaining device space
; in:  BC = file length in bytes
; out: Z=ok, B = sectors needed; NZ+A=BDFS_ERR_DISK_FULL
; destroys: AF
_file_write_device_full_check:
    push de
    push hl
    ld h, b
    ld l, c                         ; HL = length
    call flash_bytes_to_sectors     ; A = sectors_needed
    ld b, a                         ; B = sectors_needed
    ld hl, (_NEXT_FREE_SECTOR)
    ld d, 0
    ld e, a
    add hl, de                      ; HL = next_free_sector + sectors_needed
    push bc                         ; save B = sectors_needed; flash_get_sector_count destroys BC
    push hl
    call flash_get_sector_count     ; HL = total sector count
    ex de, hl                       ; HJ => DE = total sector count
    pop hl                          ; HL = next_free_sector + sectors_needed
    pop bc                          ; restore B = sectors_needed
    ; full if HL > DE (strictly greater than)
    ld a, h
    cp d
    jr c, @ok                                  ; HL < DE: ok
    jr nz, @fail                               ; H > D: full
    ld a, l
    cp e
    jr c, @ok                                  ; HL < DE (high byte equal): ok
    jr z, @ok                                  ; HL = DE: exactly fills device, ok
@fail:
    pop hl
    pop de
    ld a, BDFS_ERR_DISK_FULL
    or a                            ; NZ
    ret
@ok:
    pop hl
    pop de
    xor a                           ; Z; B = sectors_needed
    ret
; _file_write_erase_sectors: erase B sectors starting from _NEXT_FREE_SECTOR
; in:  B = sector count
; out: Z=ok, NZ+A=BDFS_ERR_ERASE_FAIL
; destroys: AF, B, IX
_file_write_erase_sectors:
    ld a, b
    or a
    ret z                              ; B=0: nothing to erase; djnz would loop 256 times
    ld ix, (_NEXT_FREE_SECTOR)
@loop:
    push ix
    pop hl                          ; HL = current sector number
    call flash_sector_erase         ; Z=ok, NZ=timeout
    jr nz, @fail
    inc ix                          ; next sector
    djnz @loop
    xor a                           ; Z: ok
    ret
@fail:
    ld a, BDFS_ERR_ERASE_FAIL
    or a                            ; NZ
    ret
; _file_write_prog_pages: write BC bytes from DE to flash starting at _NEXT_FREE_SECTOR
; in:  BC = length, DE = source
; out: Z=ok, NZ+A=BDFS_ERR_WRITE_FAIL
; destroys: AF, DE, HL
_file_write_prog_pages:
    push bc                         ; preserve length for caller
    ld hl, (_NEXT_FREE_SECTOR)
    call flash_sector_to_addr       ; A = addr[23:16], HL = addr[15:0]
    ld (_PAGE_ADDR_BANK), a         ; save addr[23:16] for use across page_program calls
@loop:
    ld a, b
    or c
    jr z, @ok                                 ; BC = 0: done
    ld a, b
    or a
    jr z, @partial                            ; B = 0: fewer than 256 bytes remain
    ; full 256-byte page
    ld a, (_PAGE_ADDR_BANK)         ; A = addr[23:16]
    push bc                         ; save remaining count
    ld bc, _PAGE_SIZE
    call flash_page_program         ; A:HL=addr, DE=src, BC=_PAGE_SIZE → Z=ok NZ=timeout; preserves HL, BC; DE advances
    pop bc                          ; restore remaining count
    jr nz, @fail
    inc h                           ; addr[15:8]++: advance to next page
    jr nz, @inc_ok
    ld a, (_PAGE_ADDR_BANK)         ; H wrapped: propagate carry into addr[23:16]
    inc a
    ld (_PAGE_ADDR_BANK), a
@inc_ok:
    dec b                           ; remaining -= 256
    jr @loop
@partial:
    ; B = 0, C = remaining bytes (< 256); write and finish
    ld a, (_PAGE_ADDR_BANK)         ; A = addr[23:16]
    call flash_page_program         ; A:HL=addr, DE=src, BC=C bytes
    jr nz, @fail
@ok:
    xor a                           ; Z set, A = 0
    jr @exit
@fail:
    ld a, BDFS_ERR_WRITE_FAIL
    or a                            ; NZ
@exit:
    pop bc                          ; restore length for caller
    ret



; bdfs_file_read: read a named file from the current drive into RAM
; assumes bdfs_select_drive has been called
; in:  HL = filename (null-terminated, case-sensitive, e.g. "HELLO.TXT")
;      DE = destination address
;      BC = max_size (0 = no limit); BDFS_ERR_FILE_TOO_LARGE if file exceeds this
; out: Z=ok, BC = bytes loaded
;      NZ=error (A=BDFS_ERR_*)
; destroys: AF, BC, DE, HL, IX
bdfs_file_read:
    call _find_file_entry                 ; HL=filename; Z=found, NZ=error (A=BDFS_ERR_*)
    jr nz, @error
    ld hl, (BDFS_ENT_BUF + BDFS_ENT_LENGTH_OFFSET)  ; HL = file_len
    ; check file length against max_size in BC (0 = no limit)
    ld a, b
    or c
    jr z, @load                           ; max_size = 0: skip check
    ld a, c
    sub l
    ld a, b
    sbc a, h                              ; max_size - file_len: carry if file_len > max_size
    jr c, @too_large
@load:
    ld b, h
    ld c, l                               ; BC = file_len
    ld hl, (BDFS_ENT_BUF + BDFS_ENT_SECTOR_OFFSET)
    call flash_sector_to_addr             ; HL=sector → A:HL = 24-bit byte address
    push bc                               ; save length (flash_read destroys BC)
    call flash_read                       ; A:HL=addr, DE=dest, BC=len
    pop bc                                ; BC = bytes loaded
    xor a                                 ; Z=ok
    ret
@too_large:
    ld a, BDFS_ERR_FILE_TOO_LARGE
    or a                                  ; NZ
    ret
@error:
    or a                                  ; NZ (A = error from _find_file_entry)
    ret

; helpers

; _verify_drive_formatted: read sector 0 header and verify BDFS magic bytes
; in:  —
; out: Z=ok (drive is formatted), NZ+A=BDFS_ERR_NOT_FORMATTED
; destroys: AF
_verify_drive_formatted:
    push bc
    push de
    push hl
    xor a
    ld hl, 0x0000
    ld de, BDFS_HDR_BUF
    ld bc, BDFS_HDR_SIZE
    call flash_read
    ld a, (BDFS_HDR_BUF + BDFS_HDR_MAGIC_OFFSET)
    cp BDFS_MAGIC_0
    jr nz, @fail
    ld a, (BDFS_HDR_BUF + BDFS_HDR_MAGIC_OFFSET + 1)
    cp BDFS_MAGIC_1
    jr nz, @fail
    xor a                           ; Z set, A=0
    jr @exit
@fail:
    ld a, BDFS_ERR_NOT_FORMATTED
@exit:
    pop hl
    pop de
    pop bc
    or a
    ret

; _parse_filename: parse 8.3 filename string into a caller-supplied buffer
; in:  HL = null-terminated filename (e.g. "HELLO.TXT"); case-sensitive, stored verbatim
;      IX = destination buffer (must hold BDFS_NAME_LEN + BDFS_EXT_LEN = 11 bytes)
; out: (IX+0)..(IX+7) = name space-padded to 8, (IX+8)..(IX+10) = ext space-padded to 3
; destroys: —
_parse_filename:
    push af
    push bc
    push de
    push hl
    push ix
    push ix
    pop de                              ; DE = IX (running write pointer)
    ld b, BDFS_NAME_LEN             ; 8 chars remaining in name field
@name_loop:
    ld a, (hl)
    or a
    jr z, @name_end                 ; null: end of string before name full
    cp '.'
    jr z, @dot                      ; dot: switch to ext
    ld (de), a
    inc hl
    inc de
    djnz @name_loop
    ; name field full: skip chars until dot or null
@skip_to_dot:
    ld a, (hl)
    or a
    jr z, @no_dot                   ; null reached with no dot
    inc hl
    cp '.'
    jr nz, @skip_to_dot
    jr @ext                         ; dot found, HL points to first ext char
@name_end:
    ; null found mid-name: space-fill remainder of name field
@name_fill:
    ld a, ' '
    ld (de), a
    inc de
    djnz @name_fill
@no_dot:
    ; no dot in filename: fill ext field with spaces (DE is already at base+8)
    ld b, BDFS_EXT_LEN
    ld a, ' '
@no_dot_fill:
    ld (de), a
    inc de
    djnz @no_dot_fill
    jr @exit
@dot:
    inc hl                          ; skip past the dot
    ; space-fill remainder of name field (B = chars still to fill)
@name_fill_after_dot:
    ld a, ' '
    ld (de), a
    inc de
    djnz @name_fill_after_dot
@ext:
    ; DE is already at base+8 after name fill (DE = ext field start)
    ld b, BDFS_EXT_LEN              ; 3 chars in ext field
@ext_loop:
    ld a, (hl)
    or a
    jr z, @ext_fill                 ; null: space-fill remaining ext
    ld (de), a
    inc hl
    inc de
    djnz @ext_loop
    jr @exit                        ; ext field full
@ext_fill:
    ld a, ' '
    ld (de), a
    inc de
    djnz @ext_fill
@exit:
    pop ix
    pop hl
    pop de
    pop bc
    pop af
    ret

; _compare_name_fields: 11-byte memcmp of BDFS_ENT_BUF[0:10] vs _SRCH_BUF[0:10]
; out: Z=match, NZ=no match
; destroys: AF
_compare_name_fields:
    push bc
    push de
    push hl
    ld de, BDFS_ENT_BUF
    ld hl, _SRCH_BUF
    ld b, BDFS_NAME_LEN + BDFS_EXT_LEN     ; 11 bytes
@loop:
    ld a, (de)
    cp (hl)
    jr nz, @done
    inc de
    inc hl
    djnz @loop
@done:
    pop hl
    pop de
    pop bc
    ret

; bdfs_file_delete: soft-delete a named file on the current drive
; Programs the flags byte from 0x01 (active) to 0x00 (deleted) — NOR-flash compatible (bit 1→0).
; The directory entry is not erased; the sector space is not reclaimed.
; assumes bdfs_select_drive has been called
; in:  HL = filename (null-terminated, case-sensitive, e.g. "HELLO.BIN")
; out: Z=ok, NZ=error (A=BDFS_ERR_*)
; destroys: AF
bdfs_file_delete:
    push ix                               ; protect caller's registers
    push bc
    push de
    push hl
    call _find_file_entry                 ; HL=filename; Z=found, IX=entry flash offset
    jr nz, @exit
    ld a, (BDFS_ENT_BUF + BDFS_ENT_FLAGS_OFFSET)
    res BDFS_FLAG_DELETED_BIT, a
    ld (BDFS_ENT_BUF + BDFS_ENT_FLAGS_OFFSET), a
    push ix
    pop hl                                ; HL = entry flash offset
    ld de, BDFS_ENT_FLAGS_OFFSET
    add hl, de                            ; HL = flash addr of flags byte
    xor a                                 ; addr[23:16] = 0; directory is in sector 0
    ld de, BDFS_ENT_BUF + BDFS_ENT_FLAGS_OFFSET
    ld bc, 1
    call flash_page_program               ; program 1 byte; Z=ok, NZ=timeout
    jr nz, @write_fail
    xor a                                 ; A=0, Z=ok
    jr @exit
@write_fail:
    ld a, BDFS_ERR_WRITE_FAIL
@exit:
    pop hl
    pop de
    pop bc
    pop ix
    or a
    ret

; _find_file_entry: locate a named file's directory entry on the current drive
; in:  HL = filename (null-terminated, case-sensitive, e.g. "HELLO.BIN")
; out: Z=found, BDFS_ENT_BUF = matching entry, IX = flash byte offset of entry
;      NZ, A = BDFS_ERR_FILE_NOT_FOUND or BDFS_ERR_NOT_FORMATTED
; destroys: AF, IX
_find_file_entry:
    push bc                               ; protect caller's registers
    push de
    push hl
    call _verify_drive_formatted
    jr nz, @exit                          ; A = BDFS_ERR_NOT_FORMATTED, NZ
    ld ix, _SRCH_BUF
    call _parse_filename                  ; fills _SRCH_BUF[0:10]
    ld ix, BDFS_HDR_SIZE                  ; IX = scan_offset (first directory entry)
    ld b, 0                               ; entry counter
@loop:
    push ix
    pop hl                                ; HL = scan_offset
    xor a                                 ; addr[23:16] = 0
    ld de, BDFS_ENT_BUF
    push bc                               ; save B=counter across flash_read
    ld bc, BDFS_ENT_SIZE
    call flash_read                       ; destroys AF, AF', BC, DE, HL
    pop bc                                ; restore B=counter
    ; check for end-of-directory sentinel
    ld a, (BDFS_ENT_BUF + BDFS_ENT_NAME_OFFSET)
    cp BDFS_ENT_EMPTY
    jr z, @not_found
    ; skip deleted entries (bit 0 = 0 means deleted in NOR flash)
    ld a, (BDFS_ENT_BUF + BDFS_ENT_FLAGS_OFFSET)
    bit BDFS_FLAG_DELETED_BIT, a
    jr z, @next                           ; deleted: skip
    ; compare name fields
    call _compare_name_fields             ; Z=match
    jr nz, @next
    ; match: IX = flash offset of this entry, BDFS_ENT_BUF = entry data
    xor a                                 ; A=0, Z=ok
    jr @exit
@next:
    ld de, BDFS_ENT_SIZE
    add ix, de
    inc b
    ld a, b
    cp _MAX_ENTRIES
    jr nc, @not_found
    jr @loop
@not_found:
    ld a, BDFS_ERR_FILE_NOT_FOUND
@exit:
    pop hl
    pop de
    pop bc
    or a
    ret

; bdfs_get_err_msg: return pointer to error message string for a BDFS_ERR_* code
; in:  A = BDFS_ERR_* code
; out: HL = pointer to null-terminated message string, or 0 if no message for this code
; destroys: AF, HL
bdfs_get_err_msg:
    cp BDFS_ERR_NO_DRIVE
    ld hl, _MSG_NO_DRIVE
    jr z, @ret
    cp BDFS_ERR_NO_DEVICE
    ld hl, _MSG_NO_DEVICE
    jr z, @ret
    cp BDFS_ERR_NOT_FORMATTED
    ld hl, _MSG_NOT_FORMATTED
    jr z, @ret
    cp BDFS_ERR_ERASE_FAIL
    ld hl, _MSG_ERASE_FAIL
    jr z, @ret
    cp BDFS_ERR_WRITE_FAIL
    ld hl, _MSG_WRITE_FAIL
    jr z, @ret
    cp BDFS_ERR_VERIFY_FAIL
    ld hl, _MSG_VERIFY_FAIL
    jr z, @ret
    cp BDFS_ERR_DIR_FULL
    ld hl, _MSG_DIR_FULL
    jr z, @ret
    cp BDFS_ERR_DISK_FULL
    ld hl, _MSG_DISK_FULL
    jr z, @ret
    cp BDFS_ERR_BAD_DRIVE
    ld hl, _MSG_BAD_DRIVE
    jr z, @ret
    cp BDFS_ERR_FILE_NOT_FOUND
    ld hl, _MSG_FILE_NOT_FOUND
    jr z, @ret
    cp BDFS_ERR_FILE_TOO_LARGE
    ld hl, _MSG_FILE_TOO_LARGE
    jr z, @ret
    cp BDFS_ERR_FILE_EXISTS
    ld hl, _MSG_FILE_EXISTS
    jr z, @ret
    cp BDFS_ERR_EMPTY_FILE
    ld hl, _MSG_EMPTY_FILE
    jr z, @ret
    ld hl, 0                          ; unknown code: no message
@ret:
    ret

; strings
_MSG_NO_DRIVE:          db "No drive selected", CHAR_LF, 0
_MSG_NO_DEVICE:         db "No device in slot", CHAR_LF, 0
_MSG_NOT_FORMATTED:     db "Not formatted", CHAR_LF, 0
_MSG_ERASE_FAIL:        db "Erase fail", CHAR_LF, 0
_MSG_WRITE_FAIL:        db "Write fail", CHAR_LF, 0
_MSG_VERIFY_FAIL:       db "Verify fail", CHAR_LF, 0
_MSG_DIR_FULL:          db "Directory full", CHAR_LF, 0
_MSG_DISK_FULL:         db "Disk full", CHAR_LF, 0
_MSG_BAD_DRIVE:         db "Invalid drive", CHAR_LF, 0
_MSG_FILE_NOT_FOUND:    db "File not found", CHAR_LF, 0
_MSG_FILE_TOO_LARGE:    db "File too large", CHAR_LF, 0
_MSG_FILE_EXISTS:       db "File exists", CHAR_LF, 0
_MSG_EMPTY_FILE:        db "Empty file", CHAR_LF, 0
_BDFS_DEFAULT_PREFIX:       db "BDFS-"
_BDFS_DEFAULT_PREFIX_LEN    equ $ - _BDFS_DEFAULT_PREFIX
