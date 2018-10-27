;=============================================================================
;  C$Time.asm
;
;  C$Start:    Internal routine - Starts elapsed time.
;  C$Elapsed:  Internal routine - Returns elapsed time.
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;=============================================================================

;*****************************************************************************
;
; .001 - 4/25/93 - Logic error. Removed the negation. Not needed.
;
;*****************************************************************************

.Model Medium, Basic

.Data

   TStart   DW 0                       ;This stores the starting ticks

.Code PDQComm_Text

C$Start Proc Near Uses Es

   Xor   Ax, Ax
   Mov   Es, Ax
   Mov   Ax, Es:[046Ch]                ;Read number of ticks from low memory
   Mov   TStart, Ax                    ;Save it for later

   Ret

C$Start Endp   

C$Elapsed Proc Near Uses Es

   Xor   Ax, Ax
   Mov   Es, Ax
   Mov   Ax, Es:[046Ch]                ;Read number of ticks from low memory
   Sub   Ax, TStart                    ;Subtract start ticks from it

Cont:
   Ret

C$Elapsed Endp

End
