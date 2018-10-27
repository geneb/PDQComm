;=============================================================================
;  Setprtto.asm
;
;  SetComPrintTO(Seconds%) Subroutine: Sets the number of seconds before a
;                                ComPrint time out error occurs. A 0 is
;                                no timeout.
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;=============================================================================

.Model Medium, Basic

.Data

   Extrn C$PrintTO:Word

.Code PDQComm_Text

SetComPrintTO Proc , Seconds:Ptr Word

   Mov   BX, Seconds
   Mov   AX, [BX]                      ;Get number of seconds requested
   Mov   CL, 4                         ;Multiply by 16 for ticks
   Shl   AX, CL                        ;(Close enough to 18)
   Mov   C$PrintTO, AX                 ;Save it

   Ret

SetComPrintTO Endp

End
