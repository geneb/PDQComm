;=============================================================================
;  Buffover.asm
;
;  Overrun% Function:   Returns status of receive buffer.
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;=============================================================================


.Model Medium,Basic
   
.Code PDQComm_Text

   Include C_Struct.Inc                ;Defines common structure

   Extrn C$Entry:Near                  ;Sets up common structure and error
                                       ;checks
   
OverRun Proc Uses SI

   Call  C$Entry                       ;Set up everything and check for errors
   Jc    Exit                          ;Carry set if error   
   Mov   AX, [PDQ_OverRun]             ;Return Overrun flag in AX

Exit:
   Ret

OverRun Endp

End
   
