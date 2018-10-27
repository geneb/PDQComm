;=============================================================================
;  Flushbuf.asm
;
;  FlushBuffer Subroutine: Clears all buffer variables
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;=============================================================================

;*****************************************************************************
;
; .001 - 10/20/90 - Handles handshaking correctly when routine is called.
;
; .002 - 12/31/90 - Disables interrupts when resetting buffer variables
;
;*****************************************************************************

.Model Medium, Basic

.Code PDQComm_Text

   Include C_Struct.Inc                ;Defines common structure

   Extrn C$Entry:Near
   Extrn C$CheckHand:Near

FlushBuffer Proc USES SI

   Call  C$Entry                       ;Setup SI and see if ISR is active
   Jc    Exit                          ;If not, exit with error 52

   Cli                                 ;Suspend interrupts
   Xor   AX, AX                        ;Zero AX
   Mov   [PDQ_RecIn], AX               ;Set all these variables to zero
   Mov   [PDQ_RecOut], AX
   Mov   [PDQ_RecNum], AX
   Mov   [PDQ_OverRun], AX
   Sti                                 ;Enable them
   Call  C$CheckHand                   ;Clears up handshaking

Exit:
   Ret

FlushBuffer Endp

End
