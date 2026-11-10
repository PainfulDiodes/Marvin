    INCLUDE "asm/core/chars.inc"

    EXTERN CMD_BUFFER, RAMSTART
    EXTERN STACK

    PUBLIC marvin_coldstart
    PUBLIC marvin_warmstart
    PUBLIC mon_dispatch

    EXTERN con_puts
    EXTERN con_putchar
    EXTERN con_getchar
    EXTERN hex_byte_val
    EXTERN con_putchar_hex
    EXTERN WELCOME_MSG
    EXTERN BAD_CMD_MSG
    EXTERN CMD_W_NULL_MSG
    EXTERN HELP_MSG
    IFDEF INCLUDE_BASIC
    EXTERN BASIC_PROMPT_MSG
    EXTERN START
    EXTERN WARM
    ENDIF
    IFDEF HAS_FLASH
    EXTERN bdfs_init
    EXTERN bdfs_get_drive
    EXTERN monitor_bdfs_format
    EXTERN monitor_bdfs_dir
    EXTERN monitor_bdfs_dir_all
    EXTERN monitor_bdfs_drive
    EXTERN monitor_bdfs_save
    EXTERN monitor_bdfs_load
    EXTERN monitor_bdfs_delete
    EXTERN BDFS_HELP_MSG
    ENDIF

; ****************************************************
; *  Marvin - a Z80 homebrew monitor program
; * (c) Stephen Willcock 2024
; * https://github.com/PainfulDiodes
; ****************************************************

; ENTRY POINTS
; initialisation, then fall through into the main loop

marvin_coldstart:
    ld hl,WELCOME_MSG
    call con_puts
    IFDEF HAS_FLASH
    call bdfs_init
    ENDIF

marvin_warmstart:
    ld sp, STACK
    ; point DE to zero - this is the default address argument for commands
    ld de,0x0000

; MAIN PROGRAM LOOP
; prompt, read a command line, dispatch it, repeat

_monitor_loop:
    ; point HL to the beginning of the input buffer
    ld hl,CMD_BUFFER
    IFDEF HAS_FLASH
    call bdfs_get_drive
    jr nz, @no_drive
    call con_putchar            ; drive letter
@no_drive:
    ENDIF
    ld a,']'
    call con_putchar
@get_cmd:
    ; get character from console
    call con_getchar
    ; backspace? handle before echo (CHAR_BS or CHAR_DEL - Mac keyboard sends DEL)
    cp CHAR_BS
    jr z,@bs
    cp CHAR_DEL
    jr z,@bs
    ; echo the character to console
    call con_putchar
    ; is CR?
    cp CHAR_CR
    ; yes: skip this
    jr z,@get_cmd
    ; is tab?
    cp CHAR_TAB
    ; yes: skip this
    jr z,@get_cmd
    ; escape?
    cp CHAR_ESC
    ; yes
    jr z, @esc
    ; end of line?
    cp CHAR_LF
    ; yes
    jr z, @end       
    ; no: add character to the buffer
    ld(hl),a
    ; move pointer to next buffer location - we're not checking for overrun
    inc hl
    ; next character
    jr @get_cmd
@bs:
    ; don't move pointer back if already at start of buffer
    ld bc,CMD_BUFFER
    or a                    ; clear carry flag
    sbc hl,bc               ; HL - CMD_BUFFER; sets Z if at start
    jr z,@bs_end            ; at start: don't echo, don't move
    dec hl                  ; move pointer back one position
    add hl,bc               ; restore HL
    ld a,CHAR_BS              ; BS: move cursor back
    call con_putchar
    ld a,' '                ; space: erase character
    call con_putchar
    ld a,CHAR_BS              ; BS: reposition cursor
    call con_putchar
    jr @get_cmd
@bs_end:
    add hl,bc               ; restore HL (= CMD_BUFFER)
    jr @get_cmd
    ; do escape
@esc:
    ; new line
    ld a,CHAR_LF
    call con_putchar
    ; back to prompt
    jr _monitor_loop
@end:
    ; string terminator
    ld a,0
    ; add terminator to end of buffer
    ld(hl),a
    ld hl,CMD_BUFFER
    call mon_dispatch
    jp _monitor_loop

; process command from buffer
; HL = pointer to command string
; out: Z = success, NZ = error
;
; Called from the main loop, and from BASIC's OSCLI for * commands.
; It has no ret of its own on the command paths: it jumps (jp, not
; call) to the command routine, and the command's ret returns
; directly to mon_dispatch's caller. Each command therefore sets
; Z/NZ itself before its ret. Exceptions (which don't leak stack):
; - x hands control to the program: its ret returns to the caller,
;   or it can jump to MARVIN_WARMSTART, which resets SP
; - b/B enter BASIC, which sets its own SP (from HIMEM); BYE
;   returns via marvin_warmstart, which resets SP
mon_dispatch:
@skip_space:
    ; load character from buffer
    ld a,(hl)
    ; skip leading spaces
    cp ' '
    jr nz,@check
    inc hl
    jr @skip_space
@check:
    ; end of string?
    cp 0
    ; yes - empty line - return to caller
    ret z
    ; advance the buffer pointer
    inc hl
    cp 'r'
    jr z,_cmd_read
    cp 'w'
    jp z,_cmd_write
    cp 'x'
    jp z,_cmd_execute
    IFDEF INCLUDE_BASIC
    cp 'b'
    jp z,_cmd_basic_cold
    cp 'B'
    jp z,_cmd_basic_warm
    ENDIF
    ; ':' = load from intel hex format
    cp ':'
    jp z,_cmd_load
    IFDEF HAS_FLASH
    cp 'f'
    jp z,monitor_bdfs_format
    cp 'D'
    jp z,monitor_bdfs_dir_all
    cp 'd'
    jp z,monitor_bdfs_dir
    cp '@'
    jp z,monitor_bdfs_drive
    cp 's'
    jp z,monitor_bdfs_save
    cp 'l'
    jp z,monitor_bdfs_load
    cp 'e'
    jp z,monitor_bdfs_delete
    ENDIF
    cp ';'
    ret z
    cp '?'
    jp z,_cmd_help
@bad:
    ld hl,BAD_CMD_MSG
    call con_puts
    ld a,' '
    call con_putchar
    ld hl,CMD_BUFFER
    call con_puts
    ld a,CHAR_LF
    call con_putchar
    or 0FFh             ; NZ = error
    ret

; COMMANDS

; READ
; read bytes from memory and send hex values to console
_cmd_read:                   
    ; load character from buffer
    ld a,(hl)
    ; end of string?
    cp 0
    ; yes: no address argument, so skip to read row
    jr z, @row
    ; parse first pair of characters
    call hex_byte_val
    ; load into upper byte of memory pointer
    ld d,a
    ; parse second pair of characters
    call hex_byte_val
    ; load into lower byte of memory pointer
    ld e,a
@row:
    ; initialise byte counter - each row will have this many bytes
    ld c, 0x10
    ; print DE content: the read address
    ld a,d
    call con_putchar_hex
    ld a,e
    call con_putchar_hex
    ; separator between address and data
    ld a,':'
    call con_putchar
    ld a,' '
    call con_putchar
    ; get a byte
@byte:            
    ld a,(de)
    ; and print it
    call con_putchar_hex
    ; add space between bytes
    ld a,' '
    call con_putchar
    ; next address
    inc de
    ; reduce byte counter
    ; TODO djnz ?
    dec c
    ; repeat if the counter is not 0
    jr nz, @byte
    ; otherwise, new line
    ld a,CHAR_LF
    call con_putchar
    cp a                ; Z = success
    ret

; WRITE

; write bytes to memory interpreting hex values from console
_cmd_write:
    ; load character from buffer
    ld a,(hl)
    ; end of string?
    cp 0
    ; yes: no data
    jr z, @null
    ; parse first pair of characters - address high
    call hex_byte_val
    ; load into upper byte of memory pointer
    ld d,a
    ; parse second pair of characters - address low
    call hex_byte_val
    ; load into lower byte of memory pointer
    ld e,a
@data:
    ; load character from buffer
    ld a,(hl)
    ; end of string?
    cp 0
    ; yes: we're done
    jr z, @end
    ; parse data byte
    call hex_byte_val
    ; write byte to memory
    ld (de),a
    ; advance destination pointer
    inc de
    jr @data
@end:
    cp a                ; Z = success
    ret
    ; w with no data
@null:
    ld hl,CMD_W_NULL_MSG
    call con_puts
    cp a                ; Z = success
    ret

; EXECUTE

; start executing from given address
_cmd_execute:                
    ; load character from buffer
    ld a,(hl)
    ; end of string?
    cp 0
    ; yes - no data
    jp z, @exec_df
    ; parse first pair of characters - address high
    call hex_byte_val
    ; load into upper byte of memory pointer
    ld d,a
    ; parse second pair of characters - address low
    call hex_byte_val
    ; load into lower byte of memory pointer
    ld e,a
    ld hl,de
    ; execute from address
    jp (hl)
    ; start executing from default address
@exec_df:
    ld hl,RAMSTART
    ; execute from address
    jp (hl)

; LOAD

; load from INTEL HEX - records are read from the buffer
_cmd_load:
    ; load character from buffer
    ld a,(hl)
    ; end of string?
    cp 0
    ; yes: no data - quit
    jp z, @end
    ; parse first pair of characters - byte count
    call hex_byte_val
    cp 0 
    ; yes - zero byte count - quit 
    jp z, @end
    ; load byte count into C
    ld c,a
    ; parse address high
    call hex_byte_val
    ; load into upper byte of memory pointer
    ld d,a
    ; parse address low
    call hex_byte_val
    ; load into lower byte of memory pointer
    ld e,a
    ; parse record type
    call hex_byte_val
    ; record type zero?
    cp 0
    ; no: quit 
    jp nz, @end
@data:
    ; load character from buffer
    ld a,(hl)
    ; end of string?
    cp 0
    ; yes: we're done
    jr z, @end
    ; no:
    ; parse data byte
    call hex_byte_val
    ; write byte to memory
    ld (de),a
    ; advance destination pointer
    inc de
    ; decrement byte counter
    ; TODO djnz
    dec c
    ; if byte counter not zero then go again
    jr nz,@data
@end:
    cp a                ; Z = success
    ret

    IFDEF INCLUDE_BASIC

; BASIC

; b: BBC BASIC cold start, B: warm start
_cmd_basic_cold:
    ld a,CHAR_LF
    call con_putchar
    jp START
_cmd_basic_warm:
    ld a,CHAR_LF
    call con_putchar
    jp WARM

    ENDIF

; HELP

; ? = show command summary
_cmd_help:
    ld hl, HELP_MSG
    call con_puts
    IFDEF HAS_FLASH
    ld hl, BDFS_HELP_MSG
    call con_puts
    ENDIF
    cp a                ; Z = success
    ret