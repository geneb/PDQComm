;=============================================================================
;  Mcrexit.asm
;
;  SetMCRExit Subroutine: Sets state of DTR and RTS when port is closed
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;=============================================================================

;*****************************************************************************
;
; .001 - 12/26/90 - Changed variable name for MCR register.
;
;*****************************************************************************

.Model Medium,Basic

.Code PDQComm_Text

   Include C_Struct.Inc                ;Defines common structure

   Extrn C$Entry:Near

SetMCRExit Proc Uses SI, DTR:Ptr Word, RTS:Ptr Word

   Call  C$Entry                       ;Setup SI and see if ISR is active
   Jc    Exit                          ;If not, exit with error 52

   Mov   AL, [PDQ_McrReg]              ;Put current status of MCR in AX
   Mov   BX, DTR                       ;Get value of DTR
   Mov   BX, [BX]
   Or    BX, BX
   Jz    DTRLo
   Or    AL, 1                         ;If DTR hi, then make bit 0 hi
   Jmp   Short RTSChk

DTRLo:
   And   AL, 0FEH                      ;If DTR lo, then make bit 0 lo

RTSChk:
   Mov   BX, RTS                       ;Get value of RTS
   Mov   BX, [BX]
   Or    BX, BX
   Jz    RTSLo
   Or    AL, 2                         ;If RTS hi, then make bit 1 hi
   Jmp   Short StoreMCR

RTSLo:
   And   AL, 0FDH                      ;If RTS lo, then make bit 1 lo

StoreMCR:
   Mov   [PDQ_McrReg], AL              ;Save new status

Exit:
   Ret

SetMCRExit Endp

End
