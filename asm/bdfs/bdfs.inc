; bdfs.inc - BeanDeck File System constants
;
; Included by bdfs.asm (pure data layer) and monitor_bdfs.asm (monitor presentation layer).

; Entry flags byte — NOR flash: each bit starts at 1 (erased) and can only be programmed to 0.
; To trigger a flag: flash_page_program the flags byte with the relevant bit cleared.
; To check a flag:   bit BDFS_FLAG_x_BIT, a — Z if the bit was programmed (flag triggered).
BDFS_FLAG_DELETED_BIT EQU 0    ; bit 0: programmed to 0 when file is soft-deleted
BDFS_FLAG_BIT1        EQU 1    ; reserved
BDFS_FLAG_BIT2        EQU 2    ; reserved
BDFS_FLAG_BIT3        EQU 3    ; reserved
BDFS_FLAG_BIT4        EQU 4    ; reserved
BDFS_FLAG_BIT5        EQU 5    ; reserved
BDFS_FLAG_BIT6        EQU 6    ; reserved
BDFS_FLAG_BIT7        EQU 7    ; reserved
; Initial flags value written when creating a directory entry — all bits unprogrammed (erased state).
; Matches the erased flash state so no bits are consumed at creation time.
BDFS_FLAGS_INITIAL    EQU 0xFF

; Format field sizes
BDFS_NAME_LEN         EQU 8
BDFS_EXT_LEN          EQU 3

; Directory header offsets
BDFS_HDR_VOL_NAME_OFFSET     EQU 2       ; 12 bytes

; Directory entry offsets (8.3 filename: name and ext fields, space-padded, no dot stored)
BDFS_ENT_NAME_OFFSET         EQU 0       ; 8 bytes, space-padded uppercase basename
BDFS_ENT_EXT_OFFSET          EQU 8       ; 3 bytes, space-padded uppercase extension
BDFS_ENT_SECTOR_OFFSET       EQU 11      ; 2 bytes, little-endian start sector
BDFS_ENT_LENGTH_OFFSET       EQU 13      ; 2 bytes, little-endian file length in bytes
BDFS_ENT_FLAGS_OFFSET        EQU 15      ; 1 byte

; Drive range
BDFS_FIRST_DRIVE        EQU 'A'
BDFS_LAST_DRIVE         EQU 'F'

; Error codes
BDFS_ERR_NO_DRIVE       EQU 1
BDFS_ERR_NO_DEVICE      EQU 2
BDFS_ERR_NOT_FORMATTED  EQU 3
BDFS_ERR_ERASE_FAIL     EQU 4
BDFS_ERR_WRITE_FAIL     EQU 5
BDFS_ERR_VERIFY_FAIL    EQU 6
BDFS_ERR_DIR_FULL       EQU 7
BDFS_ERR_DISK_FULL      EQU 8
BDFS_ERR_END_OF_DIR     EQU 9
BDFS_ERR_BAD_DRIVE      EQU 10
BDFS_ERR_FILE_NOT_FOUND EQU 11
BDFS_ERR_FILE_TOO_LARGE EQU 12
BDFS_ERR_FILE_EXISTS    EQU 13
BDFS_ERR_EMPTY_FILE     EQU 14
