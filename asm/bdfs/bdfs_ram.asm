; bdfs_ram.asm - RAM for the BeanDeck File System
; Included in the target's RAM section at the end of its marvin.asm

    PUBLIC BDFS_HDR_BUF
    PUBLIC BDFS_ENT_BUF
    PUBLIC BDFS_DRIVE

BDFS_HDR_BUF:       DEFS BDFS_HDR_SIZE      ; directory header r/w buffer
BDFS_ENT_BUF:       DEFS BDFS_ENT_SIZE      ; entry scan buffer
_SRCH_BUF:          DEFS 11                 ; search key (8 name + 3 ext)
_DIR_SCAN_OFST:     DEFS 2                  ; directory iterator scan offset
_ACTIVE_COUNT:      DEFS 1                  ; active entry count
BDFS_DRIVE:         DEFS 1                  ; active drive letter ('A'-'F', 0=none)
_FREE_ENTRY_OFFSET: DEFS 2                  ; first free dir entry byte offset from scan
_NEXT_FREE_SECTOR:  DEFS 2                  ; next free sector number from scan
_PAGE_ADDR_BANK:    DEFS 1                  ; addr[23:16] during page writes
