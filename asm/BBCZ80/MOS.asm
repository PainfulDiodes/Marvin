; MOS - Machine Operating System
;
; OS interface for BBC BASIC Z80.
; Delegates I/O to Marvin drivers via EXTERN linkage.
; See BBCZ80-repo
;
; Line ending handling:
;   Marvin's USB driver translates CR→LF in, LF→CR+LF out.
;   MOS compensates: LF→CR on input, swallow CR on output.
;   On beanboard/beandeck console: LF→CR is harmless (keyboard
;   returns CR directly), CR swallow is safe (LCD uses LF).

    PUBLIC OSINIT
    PUBLIC OSRDCH
    PUBLIC OSWRCH
    PUBLIC OSKEY
    PUBLIC OSLINE
    PUBLIC PROMPT
    PUBLIC OSSAVE
    PUBLIC OSLOAD
    PUBLIC OSOPEN
    PUBLIC OSSHUT
    PUBLIC OSBGET
    PUBLIC OSBPUT
    PUBLIC OSSTAT
    PUBLIC GETEXT
    PUBLIC GETPTR
    PUBLIC PUTPTR
    PUBLIC RESET
    PUBLIC BYE
    PUBLIC TRAP
    PUBLIC LTRAP
    PUBLIC OSCLI
    PUBLIC OSCALL
;
    EXTERN ESCAPE       ; MAIN.Z80 - escape handler
    EXTERN EXTERR       ; MAIN.Z80 - external error
    EXTERN CRLF         ; MAIN.Z80 - output CR+LF
    EXTERN VERMSG       ; MAIN.Z80 - version message
;
    EXTERN ACCS         ; DATA.Z80 - string accumulator
    EXTERN USER         ; DATA.Z80 - end of data segment (PAGE)
;
    EXTERN con_putchar      ; console - write character
    EXTERN con_getchar      ; console - blocking read
    EXTERN con_readchar     ; console - non-blocking read
    EXTERN marvin_warmstart ; monitor - cold start
    EXTERN mon_dispatch     ; monitor - parse and dispatch command from HL
    EXTERN CMD_BUFFER       ; monitor - command buffer
    EXTERN SYSTEM_RAMSTART  ; system - start of Marvin system RAM
;
IFDEF HAS_FLASH
    INCLUDE "asm/bdfs/bdfs.inc"
    EXTERN bdfs_select_drive
    EXTERN bdfs_set_drive
    EXTERN bdfs_file_write
    EXTERN bdfs_file_read
    EXTERN bdfs_get_err_msg
    EXTERN bdfs_get_drive
ENDIF
;
; Character constants
;
CR          EQU 0DH
LF          EQU 0AH
ESC         EQU 1BH
BS          EQU 08H
DEL         EQU 7FH
;
; Error constants
;
ERR_EXTERNAL EQU 254    ; error number for externally-generated errors passed to EXTERR
;
;
; ---- OS Initialisation ----
;
;OSINIT - Initialise hardware and return memory layout.
;   Outputs: DE = initial value of HIMEM (top of RAM)
;            HL = initial value of PAGE (user program)
;   Destroys: A,B,C,D,E,H,L,F
;
OSINIT:
    XOR A
    LD B,INILEN
    LD HL,_FLAGS
CLRTAB:
    LD (HL),A               ; Clear local state
    INC HL
    DJNZ CLRTAB
    LD HL,ACCS
    LD (HL),CR              ; No auto-run file
    LD DE,SYSTEM_RAMSTART   ; HIMEM - reserve Marvin system RAM and stack
    LD HL,USER              ; PAGE  - start of user program area
    RET
;
;
; ---- Console Output ----
;
;OSWRCH - Write a character to console output.
;   Inputs: A = character.
;   Destroys: Nothing
;
OSWRCH:
    PUSH AF
    CP CR
    JR Z,_OSWRCH_DONE   ; Swallow CR (Marvin adds CR before LF)
    CALL con_putchar
_OSWRCH_DONE:
    POP AF
    RET
;
;PROMPT - Output the command prompt.
;   Destroys: A,F
;
PROMPT:
    LD A,'>'
    JP OSWRCH
;
;
; ---- Console Input ----
;
;OSRDCH - Read from the current input stream (keyboard).
;   Outputs: A = character
;   Destroys: A,F
;
OSRDCH:
    LD A,(_INKEY)       ; Check for buffered key
    OR A
    JR Z,_OSRDCH_CALL
    PUSH HL
    LD HL,_INKEY
    LD (HL),0           ; Clear buffer
    POP HL
    RET
_OSRDCH_CALL:
    CALL con_getchar    ; Blocking read
    CP LF               ; Marvin returns LF for Enter
    RET NZ
    LD A,CR             ; Convert to CR for BASIC
    RET
;
;OSKEY - Read key with time-limit, test for ESCape.
;   Inputs: HL = time limit (centiseconds)
;   Outputs: Carry reset if time-out.
;            If carry set, A = character.
;   Destroys: A,H,L,F
;
OSKEY:
    LD A,(_INKEY)       ; Check buffered key
    PUSH HL
    LD HL,_INKEY
    LD (HL),0
    POP HL
    OR A
    SCF
    RET NZ              ; Return buffered key
    PUSH DE
_OSKEY_LOOP:
    CALL con_readchar ; Non-blocking read
    OR A
    JR NZ,_OSKEY_GOT
    DEC HL              ; Decrement timeout
    LD A,H
    OR L
    JR NZ,_OSKEY_LOOP
    POP DE
    OR A                ; Clear carry = timeout
    RET
_OSKEY_GOT:
    POP DE
    CP LF               ; Marvin returns LF for Enter
    JR NZ,_OSKEY_NOTLF
    LD A,CR             ; Convert to CR for BASIC
_OSKEY_NOTLF:
    CP ESC
    SCF
    RET NZ              ; Non-ESC key, carry set
    PUSH HL             ; ESC pressed
    LD HL,_FLAGS
    BIT 6,(HL)          ; Escape disabled?
    JR NZ,_OSKEY_ESCDIS
    SET 7,(HL)          ; Set escape flag
_OSKEY_ESCDIS:
    POP HL
    RET
;
;OSLINE - Read a complete line, terminated by CR.
;   Inputs: HL addresses destination buffer.
;           (L=0)
;   Outputs: Buffer filled, terminated by CR.
;            A=0.
;   Destroys: A,B,C,D,E,H,L,F
;
OSLINE:
_OSLINE_LOOP:
    CALL OSRDCH
    CP CR
    JR Z,_OSLINE_DONE
    CP BS
    JR Z,_OSLINE_BS
    CP DEL
    JR Z,_OSLINE_BS
    CP ESC
    JR Z,_OSLINE_ESC
    CP ' '
    JR C,_OSLINE_LOOP   ; Ignore control characters
    LD B,A              ; Save character
    LD A,L
    CP 254              ; Buffer full?
    LD A,B              ; Restore character
    JR NC,_OSLINE_LOOP  ; Full, ignore
    LD (HL),A           ; Store character
    INC L
    CALL OSWRCH         ; Echo
    JR _OSLINE_LOOP
;
_OSLINE_BS:
    LD A,L
    OR A
    JR Z,_OSLINE_LOOP   ; At start, nothing to delete
    DEC L
    LD A,BS
    CALL OSWRCH
    LD A,' '
    CALL OSWRCH
    LD A,BS
    CALL OSWRCH
    JR _OSLINE_LOOP
;
_OSLINE_DONE:
    LD (HL),CR          ; Terminate line
    CALL CRLF
    XOR A               ; A=0
    LD L,A              ; L=0 (point to buffer start)
    RET
;
_OSLINE_ESC:
    LD (HL),CR          ; Terminate line
    CALL CRLF
    LD HL,_FLAGS
    RES 7,(HL)          ; Clear escape flag
    JP ESCAPE           ; Abort
;
;
; ---- Trap Handlers ----
;
;TRAP - Test ESCAPE flag and abort if set;
;       every 20th call, poll keyboard for ESCape.
;   Destroys: A,H,L,F
;
TRAP:
    LD HL,_TRPCNT
    DEC (HL)
    CALL Z,_TEST
LTRAP:
    LD A,(_FLAGS)
    OR A
    RET P               ; Bit 7 clear, no escape
    LD HL,_FLAGS        ; Escape pending
    RES 7,(HL)          ; Acknowledge
    JP ESCAPE           ; Abort
;
;_TEST - Non-blocking keyboard poll for ESCape.
;   Destroys: A,F
;
_TEST:
    LD (HL),20          ; Reset trap counter
    CALL con_readchar ; Non-blocking poll
    OR A
    RET Z               ; No data
    CP LF               ; Marvin returns LF for Enter
    JR NZ,_TEST_NOTLF
    LD A,CR             ; Convert to CR for BASIC
_TEST_NOTLF:
    CP ESC
    JR Z,_TEST_ESC
    LD (_INKEY),A       ; Buffer non-ESC key
    RET
_TEST_ESC:
    LD HL,_FLAGS
    BIT 6,(HL)          ; Escape disabled?
    RET NZ
    SET 7,(HL)          ; Set escape flag
    RET
;
;
; ---- System Control ----
;
;RESET - Reset OS state. Called by the BASIC error handler before reporting an
;error and returning to the command loop. Must return to caller.
;
RESET:
    RET                 ; No-op: no OS state to reset on Marvin
;
;BYE - Return to Marvin monitor.
;
BYE:
    JP marvin_warmstart ; Enter Marvin prompt
;
;OSCLI - Process an "operating system" command.
;   Inputs: HL addresses command string (after '*'), CR terminated
;
OSCLI:
    ld de,CMD_BUFFER     ; copy command string into monitor buffer,
_OSCLI_COPY:             ; translating CR terminator to NUL
    ld a,(hl)
    cp CR
    jr z,_OSCLI_DONE
    ld (de),a
    inc hl
    inc de
    jr _OSCLI_COPY
_OSCLI_DONE:
    xor a
    ld (de),a            ; NUL terminator
    ld hl,CMD_BUFFER
    call mon_dispatch
    ret z                ; Z = success: return to BASIC
    ld a,ERR_EXTERNAL
    call EXTERR
    DEFM "OSCLI error"
    DEFB 0
;
;OSCALL - Call OS function (not used).
;
OSCALL:
    RET
;
;
; ---- File Operations ----
;
;OSSAVE - Save an area of memory to a file.
;   Inputs: HL addresses filename (term CR)
;           DE = start address of data to save
;           BC = length of data to save (bytes)
;   Destroys: A,B,C,D,E,H,L,F
;
OSSAVE:
IFDEF HAS_FLASH
    push de                     ; save source (_normalise_filename destroys DE)
    call _normalise_filename     ; HL→normalised; BC preserved; Z=ok, NZ+A=BDFS_ERR_BAD_DRIVE
    pop de                      ; restore source (does not affect flags)
    jr nz, _ossave_err
    call bdfs_get_drive         ; Z=ok A=drive, NZ+A=BDFS_ERR_NO_DRIVE
    jr nz, _ossave_err
    call bdfs_select_drive      ; Z=ok, NZ+A=BDFS_ERR_*
    jr nz, _ossave_err
    call bdfs_file_write        ; HL=filename, DE=src, BC=len; Z=ok, NZ+A=BDFS_ERR_*
    jr nz, _ossave_err
    ret
_ossave_err:
    call _bdfs_error       ; does not return
ELSE
    XOR A
    CALL EXTERR
    DEFM "No file system available"
    DEFB 0
ENDIF
;
;OSLOAD - Load a file into memory.
;   Inputs: HL addresses filename (term CR)
;           DE = destination address
;           BC = maximum space available
;   Outputs: carry SET = success; carry CLEAR = file too large
;   Destroys: A,B,C,D,E,H,L,F
;
OSLOAD:
IFDEF HAS_FLASH
    push de                     ; save dest (_normalise_filename destroys DE)
    call _normalise_filename     ; HL→normalised; BC preserved; Z=ok, NZ+A=BDFS_ERR_BAD_DRIVE
    pop de                      ; restore dest
    jr nz, _osload_err
    call bdfs_get_drive         ; Z=ok A=drive, NZ+A=BDFS_ERR_NO_DRIVE
    jr nz, _osload_err
    call bdfs_select_drive      ; Z=ok, NZ+A=BDFS_ERR_*
    jr nz, _osload_err
    call bdfs_file_read         ; HL=filename, DE=dest, BC=max_space; Z=ok, BC=bytes_loaded; NZ+A=BDFS_ERR_*
    jr nz, _osload_err
    scf                         ; carry SET = success
    ret
_osload_err:
    ; OSLOAD is supposed to signal "file too large" by returning carry clear, 
    ; letting BASIC raise its own "Too big" error rather than an OS-level error. 
    ; The carry-clear convention comes from the BBC BASIC MOS spec
    cp BDFS_ERR_FILE_TOO_LARGE
    jr z, _osload_too_large
    call _bdfs_error            ; A = BDFS_ERR_*; does not return
_osload_too_large:
    or a                        ; carry CLEAR = file too large; BASIC raises the error
    ret
ELSE
    XOR A
    CALL EXTERR
    DEFM "No file system available"
    DEFB 0
ENDIF
;
;OSOPEN - Open a file for reading or writing.
;   Inputs: HL addresses filename (term CR)
;           Carry set for OPENIN, cleared for OPENOUT.
;   Outputs: A = file channel (0 = cannot open)
;   Destroys: A,B,C,D,E,H,L,F
;
OSOPEN:
    XOR A               ; A=0, cannot open
    RET
;
;OSSHUT - Close disk file(s).
;   Inputs: E = file channel
;           If E=0 all files are closed.
;   Destroys: A,B,C,D,E,H,L,F
;
OSSHUT:
    RET
;
;OSBGET - Read a byte from a random disk file.
;   Inputs: E = file channel
;   Outputs: A = byte read
;            Carry set if last byte of file.
;   Destroys: A,B,C,F
;
OSBGET:
    XOR A               ; A=0
    SCF                 ; Carry set = EOF
    RET
;
;OSBPUT - Write a byte to a random disk file.
;   Inputs: E = file channel
;           A = byte to write
;   Destroys: A,B,C,F
;
OSBPUT:
    RET
;
;OSSTAT - Read file status.
;   Inputs: E = file channel
;   Outputs: Z flag set = EOF
;   Destroys: A,D,E,H,L,F
;
OSSTAT:
    XOR A               ; Z set = EOF
    RET
;
;GETPTR - Return file pointer.
;   Inputs: E = file channel
;   Outputs: DEHL = pointer (0-&7FFFFF)
;   Destroys: A,B,C,D,E,H,L,F
;
GETPTR:
    LD DE,0
    LD HL,0
    RET
;
;PUTPTR - Update file pointer.
;   Inputs: A = file channel
;           DEHL = new pointer
;   Destroys: A,B,C,D,E,H,L,F
;
PUTPTR:
    RET
;
;GETEXT - Find file size.
;   Inputs: E = file channel
;   Outputs: DEHL = file size
;   Destroys: A,B,C,D,E,H,L,F
;
GETEXT:
    LD DE,0
    LD HL,0
    RET
;
;
; ---- Local State ----
;
; Flags byte:
;   Bit 6: Escape disabled
;   Bit 7: Escape flag (pending escape)
;
_TRPCNT:
    DEFB 20
_FLAGS:
    DEFB 0
_INKEY:
    DEFB 0
INILEN  EQU $-_FLAGS
;
;
IFDEF HAS_FLASH
; ---- BDFS filename normalisation and error bridge ----
;
; _normalise_filename: normalise a BBC BASIC filename in ACCS
; in:  HL = CR-terminated filename
; out: Z=ok, HL = null-terminated normalised filename
;           (advances past 'X:' drive prefix if present and valid)
;      NZ+A = BDFS_ERR_BAD_DRIVE if drive letter invalid
; side-effect: calls bdfs_set_drive if drive prefix found
; preserves: BC; destroys: DE
;
_normalise_filename:
    push bc
    ; Step 1: walk string, upcase letters, replace CR with NUL; DE ends at NUL
    ld d, h
    ld e, l
_norm_upcase_loop:
    ld a, (de)
    cp CR
    jr z, _norm_got_cr
    cp 'a'
    jr c, _norm_not_lower
    cp 'z'+1
    jr nc, _norm_not_lower
    sub 'a'-'A'             ; convert to upper
_norm_not_lower:
    ld (de), a
    inc de
    jr _norm_upcase_loop
_norm_got_cr:
    xor a
    ld (de), a              ; NUL-terminate; DE = ptr to NUL
    ; Step 2: check for drive prefix 'X:' (string already upcased)
    ld a, (hl)
    cp 'A'
    jr c, _norm_no_drive
    cp 'Z'+1
    jr nc, _norm_no_drive
    inc hl
    ld a, (hl)
    dec hl
    cp ':'
    jr nz, _norm_no_drive
    ld a, (hl)              ; A = drive letter
    push de                 ; save NUL ptr across call
    call bdfs_set_drive     ; Z=ok, NZ+A=BDFS_ERR_BAD_DRIVE; destroys AF
    pop de
    jr nz, _norm_bad_drive
    inc hl
    inc hl                  ; advance past 'X:'
    jr _norm_check_dot
_norm_bad_drive:
    pop bc
    ret                     ; A = BDFS_ERR_BAD_DRIVE, NZ
_norm_no_drive:
    ; Step 3: scan from HL for '.'; append ".BBC\0" at DE if none found
_norm_check_dot:
    push hl                 ; save filename start for return
    ld b, h
    ld c, l                 ; BC = scan pointer
_norm_dot_scan:
    ld a, (bc)
    or a
    jr z, _norm_no_dot
    cp '.'
    jr z, _norm_has_dot
    inc bc
    jr _norm_dot_scan
_norm_has_dot:
    pop hl
    xor a                   ; A = 0 (ok)
    pop bc
    ret
_norm_no_dot:
    ld a, '.'
    ld (de), a
    inc de
    ld a, 'B'
    ld (de), a
    inc de
    ld a, 'B'
    ld (de), a
    inc de
    ld a, 'C'
    ld (de), a
    inc de
    xor a
    ld (de), a              ; NUL terminator
    pop hl
    xor a                   ; A = 0 (ok)
    pop bc
    ret
;
; _bdfs_error: bridge a BDFS error code to BBC BASIC's EXTERR handler
; in:  A = BDFS_ERR_* code
; does not return — aborts to BASIC error handler via JP EXTERR
;
_bdfs_error:
    push af
    call bdfs_get_err_msg   ; A → HL = null-terminated message (or 0 if unknown)
    ld a, h
    or l
    jr nz, _bdfs_error_go
    ld hl, _MSG_IO_ERR
_bdfs_error_go:
    pop af                  ; restore A = BDFS error code (passed to EXTERR as error number)
    push hl                 ; EXTERR's first instruction is POP HL: picks up our message ptr
    JP EXTERR               ; no return; BASIC error handler resets SP
_MSG_IO_ERR:
    DEFM "I/O error"
    DEFB 0
ENDIF
;
FIN:
