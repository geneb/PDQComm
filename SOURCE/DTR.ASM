;=============================================================================
;  DTR.asm
;
;  DTR(State%) Subroutine: Raises or lowers the DTR signal
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;============================================================================= 


.Model Medium,Basic

.Code PDQComm_Text

   Include C_Struct.Inc                ;Defines common structure

   Extrn C$Entry:Near

DTR Proc Uses SI, Toggle:Ptr Word

   Call  C$Entry                       ;Setup SI and see if ISR is active
   Jc    Exit                          ;If not, exit with error 52

   Mov   DX, [PDQ_Mcr]                 ;Get address of UART Modem control reg
   In    AL, DX                        ;Get its data
   Mov   BX, Toggle
   Mov   BX, [BX]                      ;See what we are going to do with DTR
   Or    BX, BX
   Jz    ClearDTR

   Or    AL, 1                         ;To set it, or it with 1
   Jmp   Short OutDTR

ClearDTR:
   And   AL, 0FEH                      ;To clear it, and it with FE

OutDTR:
   Out   DX, AL                        ;Send it back

Exit:
   Ret

DTR Endp

End
