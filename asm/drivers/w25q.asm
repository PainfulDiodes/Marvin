; w25q.asm - W25Q series NOR flash driver for BeanBoardSPI hardware SPI
;
; All functions preserve caller registers unless documented otherwise.

; SPI CS values (SPI_CS_IDLE, SPI_CS_SLOT0-6) are in system.asm.
; W25Q flash cartridge slots occupy SPI_CS_SLOT1-6.
; Port addresses (SPI_CTRL, SPI_DATA) are in system.asm.

; Device geometry
W25Q_SECTOR_SIZE    EQU 4096    ; erase unit (Sector Erase command, 4KB)
W25Q_PAGE_SIZE      EQU 256     ; write unit (Page Program command)

; Command bytes
W25Q_CMD_JEDEC_ID   EQU 0x9F    ; Read JEDEC ID
W25Q_CMD_READ       EQU 0x03    ; Read Data
W25Q_CMD_WREN       EQU 0x06    ; Write Enable
W25Q_CMD_SE         EQU 0x20    ; Sector Erase (4KB)
W25Q_CMD_PP         EQU 0x02    ; Page Program
W25Q_CMD_RDSR       EQU 0x05    ; Read Status Register 1

; Status register bits
W25Q_BUSY_BIT       EQU 0       ; bit 0: BUSY (1 = operation in progress)

; Polling timeout (loop iterations)
; At 10MHz Z80 with ~134 T-states/iteration (~13 µs): 0xFFFF ≈ 0.88s
; Covers W25Q16/W25Q128 worst-case 400ms sector erase.
W25Q_POLL_TIMEOUT   EQU 0xFFFF

; JEDEC manufacturer IDs
W25Q_MFR_WINBOND    EQU 0xEF    ; Winbond NOR flash

; Capacity codes (JEDEC third byte, returned by flash_read_jedec_id and cached in W25Q_ID_CAP)
; Capacity byte = log2(bits); e.g. 0x15 = log2(16Mbit) + constant
W25Q_CAP_8MBIT      EQU 0x14    ; W25Q80   - 1 MByte
W25Q_CAP_16MBIT     EQU 0x15    ; W25Q16   - 2 MByte
W25Q_CAP_32MBIT     EQU 0x16    ; W25Q32   - 4 MByte
W25Q_CAP_64MBIT     EQU 0x17    ; W25Q64   - 8 MByte
W25Q_CAP_128MBIT    EQU 0x18    ; W25Q128  - 16 MByte
; W25Q_CAP_256MBIT EQU 0x19  ; W25Q256 - 32 MByte - not supported: requires 4-byte addressing above 16MB

    EXTERN SPI_CTRL, SPI_CS_IDLE            ; system.asm - BeanBoardSPI port addresses
    EXTERN spi_byte                         ; spi_beanboardspi_rev*.asm - SPI byte transfer

    PUBLIC flash_read
    PUBLIC flash_read_jedec_id
    PUBLIC flash_sector_erase
    PUBLIC flash_page_program
    PUBLIC flash_select_slot
    PUBLIC flash_has_device
    PUBLIC flash_get_device_id
    PUBLIC flash_get_device_name
    PUBLIC flash_get_capacity_mb
    PUBLIC flash_get_sector_count
    PUBLIC flash_bytes_to_sectors
    PUBLIC flash_sector_to_addr
    PUBLIC W25Q_SECTOR_SIZE
    PUBLIC W25Q_PAGE_SIZE
    PUBLIC W25Q80_NAME
    PUBLIC W25Q16_NAME
    PUBLIC W25Q32_NAME
    PUBLIC W25Q64_NAME
    PUBLIC W25Q128_NAME

; RAM variables: w25q_ram.asm

; flash_has_device: check whether a W25Q device was detected when the slot was last selected
; in:  — (uses W25Q_ID_MFR cached by flash_select_slot)
; out: Z = W25Q device present, NZ = no device
; destroys: AF
flash_has_device:
    ld a, (W25Q_ID_MFR)
    cp W25Q_MFR_WINBOND
    ret

; flash_get_device_id: return JEDEC ID cached by the last flash_select_slot call
; out: A = manufacturer ID, B = memory type, C = capacity
; destroys: AF, BC
flash_get_device_id:
    ld a, (W25Q_ID_TYPE)
    ld b, a
    ld a, (W25Q_ID_CAP)
    ld c, a
    ld a, (W25Q_ID_MFR)
    ret

; flash_read_jedec_id: read 3-byte JEDEC ID
; out: A = manufacturer ID, B = memory type, C = capacity
; destroys: AF, BC, DE, HL
flash_read_jedec_id:
    ld a, (W25Q_CS)             ; RAM var selected status for current slot
    out (SPI_CTRL), a
    ld a, W25Q_CMD_JEDEC_ID
    call spi_byte         ; received byte discarded
    ld a, 0x00
    call spi_byte
    ld d, a                     ; manufacturer in D
    ld a, 0x00
    call spi_byte
    ld e, a                     ; memory type in E
    ld a, 0x00
    call spi_byte
    ld l, a                     ; capacity in L
    ld a, SPI_CS_IDLE
    out (SPI_CTRL), a
    ld c, l                     ; C = capacity
    ld b, e                     ; B = memory type
    ld a, d                     ; A = manufacturer ID
    ret

; _flash_write_enable: send Write Enable command (own CS transaction)
; destroys: nothing
_flash_write_enable:
    push af
    ld a, (W25Q_CS)
    out (SPI_CTRL), a
    ld a, W25Q_CMD_WREN
    call spi_byte
    ld a, SPI_CS_IDLE
    out (SPI_CTRL), a
    pop af
    ret

; _flash_poll_busy: poll status register until BUSY (bit 0) clears or timeout
; out: Z = done (not busy), NZ = timeout
; destroys: AF, BC, DE
_flash_poll_busy:
    ld de, W25Q_POLL_TIMEOUT
@loop:
    ld a, (W25Q_CS)
    out (SPI_CTRL), a
    ld a, W25Q_CMD_RDSR
    call spi_byte
    ld a, 0x00
    call spi_byte         ; A = status register byte
    ld b, a                     ; save in B before deassert clobbers A
    ld a, SPI_CS_IDLE
    out (SPI_CTRL), a
    bit W25Q_BUSY_BIT, b        ; Z=1 if BUSY bit is 0 (not busy)
    jr z, @done
    dec de
    ld a, d
    or e
    jr nz, @loop
    or 1                        ; timeout: set NZ (A was 0, or 1 = 1)
    ret
@done:
    ret                         ; Z set: operation complete

; flash_read: read BC bytes from flash address A:HL into RAM at DE
; in:  A  = addr[23:16]
;      HL = addr[15:0]  (H = addr[15:8], L = addr[7:0])
;      DE = destination (RAM pointer)
;      BC = byte count
; out: DE = one past last byte written, BC = 0
; destroys: AF, AF', BC, DE, HL
flash_read:
    ex af, af'                  ; A' = addr[23:16]; save BEFORE BC check clobbers A
    ld a, b
    or c
    jr z, @empty                ; BC=0: nothing to read; dec bc would underflow to 0xFFFF
    ld a, (W25Q_CS)
    out (SPI_CTRL), a
    ld a, W25Q_CMD_READ
    call spi_byte
    ex af, af'                  ; A = addr[23:16]
    call spi_byte         ; send addr[23:16]
    ld a, h
    call spi_byte         ; send addr[15:8]
    ld a, l
    call spi_byte         ; send addr[7:0]
@loop:
    ld a, 0x00
    call spi_byte         ; clock in received byte
    ld (de), a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, @loop
    ld a, SPI_CS_IDLE
    out (SPI_CTRL), a
    ret
@empty:
    ret

; flash_sector_erase: send Write Enable, erase a 4KB sector, poll until done
; in:  HL = sector number
; out: Z = ok, NZ = timeout
; destroys: AF
;
; The W25Q sector erase command takes a 24-bit byte address as three bytes:
; addr[23:16], addr[15:8], addr[7:0]. Sectors are 4096-byte aligned so addr[7:0]
; is always 0. The full byte address is sector_num << 12; discarding the always-zero
; low byte gives addr[23:8] = sector_num << 4. Four add hl,hl shifts HL into H:L
; as addr[23:16]:addr[15:8], ready to send as two SPI bytes.
flash_sector_erase:
    push bc
    push de
    push hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl                  ; HL = sector_num << 4 = addr[23:8] (H=addr[23:16], L=addr[15:8])
    call _flash_write_enable
    ld a, (W25Q_CS)
    out (SPI_CTRL), a
    ld a, W25Q_CMD_SE
    call spi_byte
    ld a, h
    call spi_byte         ; addr[23:16]
    ld a, l
    call spi_byte         ; addr[15:8]
    ld a, 0x00
    call spi_byte         ; addr[7:0] = 0
    ld a, SPI_CS_IDLE
    out (SPI_CTRL), a
    call _flash_poll_busy       ; Z=ok NZ=timeout
    pop hl
    pop de
    pop bc
    ret

; flash_page_program: send Write Enable, write BC bytes from DE to flash address A:HL, poll
; in:  A  = addr[23:16]
;      HL = addr[15:0]  (H = addr[15:8], L = addr[7:0])
;      DE = source (RAM pointer)
;      BC = byte count (must be ≤ remaining bytes in 256-byte page)
; out: Z = ok, NZ = timeout
;      DE = one past last byte written (caller may use this to chain page writes)
; destroys: AF, AF'
flash_page_program:
    push bc
    push hl
    ex af, af'                  ; A' = addr[23:16]; save before CS assert clobbers A
    call _flash_write_enable
    ld a, (W25Q_CS)
    out (SPI_CTRL), a
    ld a, W25Q_CMD_PP
    call spi_byte
    ex af, af'                  ; A = addr[23:16]
    call spi_byte         ; send addr[23:16]
    ld a, h
    call spi_byte         ; send addr[15:8]
    ld a, l
    call spi_byte         ; send addr[7:0]
@loop:
    ld a, (de)
    call spi_byte
    inc de
    dec bc
    ld a, b
    or c
    jr nz, @loop
    ld a, SPI_CS_IDLE
    out (SPI_CTRL), a
    push de                         ; poll_busy clobbers DE; preserve advanced source pointer
    call _flash_poll_busy           ; Z=ok NZ=timeout; pop does not disturb flags
    pop de                          ; restore DE = one past last byte written
    pop hl
    pop bc
    ret

; flash_select_slot: select active cartridge slot - defined in W25Q_CS - and cache the device JEDEC ID
; in:  A = slot number (1-6)
; out: —  (JEDEC ID cached in W25Q_ID_MFR, W25Q_ID_TYPE, W25Q_ID_CAP)
; destroys: AF, BC, DE, HL
flash_select_slot:
    inc a                       ; A = slot + 1 (bit position of CS line)
    ld b, a                     ; B = shift count
    ld a, 1
@loop:
    rlca
    djnz @loop                                ; A = 1 << (slot+1): the active-low CS bit for this slot
    cpl                         ; invert: 0xFF with CS bit cleared
    ld (W25Q_CS), a
    call flash_read_jedec_id    ; A=mfr, B=type, C=cap (uses W25Q_CS just set)
    ld (W25Q_ID_MFR), a
    ld a, b
    ld (W25Q_ID_TYPE), a
    ld a, c
    ld (W25Q_ID_CAP), a
    ret

; flash_get_device_name: return name string for the cached device
; in:  — (uses W25Q_ID_CAP cache populated by flash_select_slot)
; out: HL = pointer to null-terminated device name string
; destroys: AF, BC, HL
flash_get_device_name:
    call flash_get_device_id         ; C = cap
    ld a, c
    cp W25Q_CAP_16MBIT
    ld hl, W25Q16_NAME
    ret z
    cp W25Q_CAP_32MBIT
    ld hl, W25Q32_NAME
    ret z
    cp W25Q_CAP_64MBIT
    ld hl, W25Q64_NAME
    ret z
    cp W25Q_CAP_128MBIT
    ld hl, W25Q128_NAME
    ret z
    cp W25Q_CAP_8MBIT
    ld hl, W25Q80_NAME
    ret z
    ld hl, _MSG_UNKNOWN_DEVICE
    ret

; flash_get_capacity_mb: return device capacity in megabytes
; in:  — (uses W25Q_ID_CAP cache populated by flash_select_slot)
; out: A = capacity in MB
; destroys: AF, BC
flash_get_capacity_mb:
    call flash_get_device_id         ; C = cap
    ld a, c
    sub W25Q_CAP_8MBIT               ; shift count (0=1MB, 1=2MB, ...)
    ld b, a
    ld a, 1
@shift:
    dec b
    jp m, @done
    rlca
    jr @shift
@done:
    ret

; flash_get_sector_count: return total 4KB sector count for the current device
; in:  — (uses W25Q_ID_CAP cached by flash_select_slot)
; out: HL = sector count (256 for W25Q80, 512 for W25Q16, 1024 for W25Q32, ...)
; destroys: AF, BC, HL
flash_get_sector_count:
    ld a, (W25Q_ID_CAP)
    sub W25Q_CAP_8MBIT          ; A = shift count (0 for W25Q80, 1 for W25Q16, ...)
    ld b, a
    ld hl, 256                  ; base: W25Q80 has 256 sectors
@shift:
    dec b
    jp m, @done                                   ; shifted enough
    add hl, hl                  ; HL <<= 1
    jr @shift
@done:
    ret

; flash_bytes_to_sectors: ceiling division of a byte count by the sector size
; in:  HL = byte count - max 0xF000 = 61440; files longer than this will overflow silently
;      (bdfs_file_write enforces this limit — remove that guard if this is fixed)
; out: A  = ceil(HL / W25Q_SECTOR_SIZE)
; destroys: AF, DE, HL
;
; NOTE this function is fixed to the sector size being 2^12=4096
;       Also this calculation effectively limits the max file size to 0xF000 = 61440 
;       - adding sector_size-1 must not overflow 16 bits
;
; num sectors = ceil(length / _SECTOR_SIZE)  
;   = (length + _SECTOR_SIZE - 1) / _SECTOR_SIZE
;   = (length + 4096 - 1) / 4096 
;   = (length + 4096 - 1) >> 12
; Adding divisor-1 before truncating gives the ceiling without a remainder check.
; 4096 = 2^12, so >> 12 replaces / 4096; HL >> 12 is done as H >> 4 (load H,
; shift 4 times) to avoid 12 individual shift instructions.
flash_bytes_to_sectors:
    ld de, W25Q_SECTOR_SIZE - 1
    add hl, de                      ; HL = length + (sector_size - 1)
    ld a, h
    srl a
    srl a
    srl a
    srl a                           ; A = HL >> 12 = ceil(length / 4096)
    ret

; flash_sector_to_addr: convert a sector number to a 24-bit flash byte address in A:HL form
; in:  HL = sector number
; out: A  = addr[23:16], HL = addr[15:0] (H = addr[15:8], L = 0)
; destroys: AF, HL
;
; byte_addr = sector_num << 12. Split as A:HL for flash_read / flash_page_program:
;   addr[23:8] = sector_num << 4 (four add hl,hl); then A=H (addr[23:16]),
;   H=L (addr[15:8]), L=0 (addr[7:0] always 0: sectors are 4096-byte aligned).
flash_sector_to_addr:
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl                      ; HL = sector_num << 4 = addr[23:8] (H=addr[23:16], L=addr[15:8])
    ld a, h                         ; A = addr[23:16]
    ld h, l                         ; H = addr[15:8]
    ld l, 0                         ; L = addr[7:0] = 0
    ret

; strings
_MSG_UNKNOWN_DEVICE:    db "unknown", 0
W25Q80_NAME:    db "W25Q80", 0
W25Q16_NAME:    db "W25Q16", 0
W25Q32_NAME:    db "W25Q32", 0
W25Q64_NAME:    db "W25Q64", 0
W25Q128_NAME:   db "W25Q128", 0
