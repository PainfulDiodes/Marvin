    PUBLIC WELCOME_MSG
    PUBLIC BAD_CMD_MSG
    PUBLIC CMD_W_NULL_MSG

WELCOME_MSG:
                db "PainfulDiodes\n"
                db "MARVIN Z80 monitor\n"
                db "v1.3\n",0


BAD_CMD_MSG:    
                db "Bad command\n",0

CMD_W_NULL_MSG:
                db "No data\n",0
