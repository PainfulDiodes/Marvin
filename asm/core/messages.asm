    PUBLIC WELCOME_MSG
    PUBLIC BAD_CMD_MSG
    PUBLIC CMD_W_NULL_MSG
    PUBLIC HELP_MSG
    PUBLIC BDFS_HELP_MSG

WELCOME_MSG:
                defm "MARVIN "
                INCLUDE "asm/core/version.inc"
                defm "\n"
                db "A simple Z80 homebrew monitor program\n"
                db "(c) Stephen Willcock 2024\n"
                db "https://github.com/PainfulDiodes\n",0

BAD_CMD_MSG:    
                db "Command not recognised:\n",0

CMD_W_NULL_MSG:
                db "No data to write\n",0

HELP_MSG:
                db "r <addr>                   read memory\n"
                db "w <addr> <data>            write memory\n"
                db "x [addr]                   execute (default 8000)\n"
                db ":                          load Intel HEX\n"
                db "b / B                      BASIC cold / warm start\n"
                db ";                          comment (ignored)\n"
                db "?                          this help\n",0

BDFS_HELP_MSG:
                db "@A-F                       select drive\n"
                db "d                          directory (active + deleted count)\n"
                db "D                          directory (all entries inc deleted)\n"
                db "f [name]                   format drive\n"
                db "s <n.ext> [<addr> [<len>]] save to file\n"
                db "l <n.ext> [<addr>]         load from file\n"
                db "e <n.ext>                  delete file\n",0
