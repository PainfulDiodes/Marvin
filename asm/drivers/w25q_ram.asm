; w25q_ram.asm - RAM for the W25Q flash driver
; Included in the target's RAM section at the end of its marvin.asm

W25Q_CS:            DEFS 1                  ; active CS byte for flash_cs_assert
W25Q_ID_MFR:        DEFS 1                  ; JEDEC manufacturer ID (cached by flash_select_slot)
W25Q_ID_TYPE:       DEFS 1                  ; JEDEC memory type
W25Q_ID_CAP:        DEFS 1                  ; JEDEC capacity code (see W25Q_CAP_* in w25q.inc)
