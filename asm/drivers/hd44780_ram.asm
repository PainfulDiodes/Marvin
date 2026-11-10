; hd44780_ram.asm - RAM for the HD44780 LCD driver
; Included in the target's RAM section at the end of its marvin.asm

LCD_CURSOR_COL:     DEFS 1                  ; column (0..LCD_LINE_LEN-1)
