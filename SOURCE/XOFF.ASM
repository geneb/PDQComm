;=============================================================================
;  Xoff.asm
;
;  XOff Function: Checks the state of the XOff flag
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;=============================================================================

.Model Medium,Basic

.Code PDQComm_Text

   Include C_Struct.Inc                ;Defines common structure

   Extrn C$Entry:Near

XOff Proc USES SI

   Call  C$Entry                       ;Setup SI and see if ISR is active
   Jc    Exit                          ;If not, exit with error

   Mov   AX, [PDQ_XOff]                ;Return XOff flag
   
Exit:
   Ret

XOff EndP

End
