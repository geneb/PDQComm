;=============================================================================
;  Break.asm
;
;  Break Subroutine: Sends a BREAK to the remote system.
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;============================================================================= 


.Model Medium,Basic

.Code PDQComm_Text

   Include C_Struct.Inc                ;Defines common structure

   Extrn C$Entry:Near
   Extrn C$Start:Near
   Extrn C$Elapsed:Near

SendBreak Proc Uses SI, Ticks:Ptr Word

   Call  C$Entry                       ;Set up SI and check if ISR active
   Jc    Exit                          ;If not, exit with error

   Mov   BX, Ticks
   Mov   CX, [BX]
   Mov   DX, [PDQ_Lcr]                 ;Put address of UART MSR in DX
   In    AL, DX                        ;Load MSR into AL
   Or    AL, 040h                      ;Mask out correct bit
   Out   DX, AL
   Call  C$Start                       ;Start elapsed time counter

TLoop:
   Call  C$Elapsed                     ;Get elapsed time
   Cmp   AX, CX                        ;Are we done?
   Jl    TLoop

   In    AL, DX                        ;Tell UART to stop sending
   And   AL, 0BFh
   Out   DX, AL

Exit:
   Ret

SendBreak Endp

End
