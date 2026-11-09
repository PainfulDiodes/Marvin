    PUBLIC WELCOME_MSG
    PUBLIC BAD_CMD_MSG
    PUBLIC CMD_W_NULL_MSG
    PUBLIC HELP_MSG
    PUBLIC BDFS_HELP_MSG

WELCOME_MSG:
                db "PainfulDiodes\n"
                db "MARVIN Z80 monitor\n"
                INCLUDE "asm/core/version.inc"
                db "\n",0


BAD_CMD_MSG:    
                db "Bad command:\n",0

CMD_W_NULL_MSG:
                db "No data\n",0

HELP_MSG:
                db "r=read w=write x=exec\n"
                db ":=hex b/B=BASIC ;=comment ?=help\n",0

BDFS_HELP_MSG:
                db "@=drive d=dir D=dir-all f=fmt s=save\n",0
