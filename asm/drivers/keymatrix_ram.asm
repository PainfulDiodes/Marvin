; keymatrix_ram.asm - RAM for the matrix keyboard driver
; Included in the target's RAM section at the end of its marvin.asm

    PUBLIC KEY_MATRIX_BUFFER, CAPS_LOCK_STATE

KEY_MATRIX_BUFFER:  DEFS 8                  ; keyscan buffer
CAPS_LOCK_STATE:    DEFS 1                  ; caps lock state (0=off, 1=on)
