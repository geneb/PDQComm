;=============================================================================
;  Rts.asm
;
;  Rts(Toggle%) Subroutine: Sets state of RTS line
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;=============================================================================


.Model Medium,Basic

.Code PDQComm_Text

   Include C_Struct.Inc                ;Defines common structure

   Extrn C$Entry:Near

RTS Proc Uses SI, Toggle:Ptr Word

   Call  C$Entry                       ;Set up SI and see if ISR is active
   Jc    Exit                          ;If not, exit with error 52

   Mov   DX, [PDQ_Mcr]                 ;Get address of UARTS MCR register
   In    AL, DX                        ;Get its data
   Mov   BX, Toggle
   Mov   BX, [BX]
   Or    BX, BX
   Jz    ClearRTS

   Or    AL, 2                         ;If RTS hi, set bit 1 to a 1
   Jmp   Short OutRTS

ClearRTS:
   And   AL, 0FDH                      ;If RTS lo, set bit 1 to a 0

OutRTS:
   Out   DX, AL                        ;Send it back out

Exit:
   Ret

RTS Endp

End
