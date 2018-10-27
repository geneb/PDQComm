;=============================================================================
;  Comeof.asm
;
;  ComEOF% Function: Returns True (-1) if there are no characters in buffer
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;=============================================================================


.Model Medium,Basic

.Code PDQComm_Text

   Include C_Struct.Inc                ;Defines common structure

   Extrn C$Entry:Near
   
ComEof Proc Uses SI

   Call  C$Entry                       ;Setup SI and see if ISR is active
   Jc    Exit                          ;If not, exit with error

   Mov   AX, [PDQ_RecNum]              ;Get number of characters in buffer
   Or    AX, AX
   Jne   NotEOF
   Mov   AX, -1                        ;Set return to TRUE if AX is not zero
   Jmp   Short Exit
   
NotEOF:
   Xor   AX, AX
   
Exit:
   Ret

ComEof Endp

End
