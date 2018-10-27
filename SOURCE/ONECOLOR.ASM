;----- OneColor.Asm - combines foreground and background colors

;Copyright (c) 1988 Ethan Winer
;Modified for MASM 5.1 and PDQComm by Dave Cleary 1991


;Syntax - Colr% = OneColor%(FG%, BG%)
;
;equivalent:
;OneColor% = (FG% AND 16) * 8 + ((BG% AND 7) * 16) + (FG% AND 15)

.Model Medium, Basic
.Code

OneColor Proc Uses SI, FG:Ptr Word, BG:Ptr Word

    Mov  SI,FG            ;get address for FG%
    Mov  AX,[SI]          ;put it in AX
    Mov  BX,AX            ;save it in BX too
    And  AX,16            ;AND it with 16
    Mov  CL,3             ;multiply times 8
    Shl  AX,CL
    And  BX,15            ;AND FG with 15
    Add  AX,BX            ;add (FG AND 16) and (FG AND 15)

    Mov  SI,BG            ;get the address for BG
    Mov  BX,[SI]          ;put it in BX
    And  BX,7             ;mask off possibly illegal bits to prevent flashing
    Mov  CL,4             ;multiply times 16
    Shl  BX,CL
    Add  AX,BX            ;the result is now in AL
    Xor  AH,AH            ;clear AH to use all of AX
    Ret

OneColor Endp

End
