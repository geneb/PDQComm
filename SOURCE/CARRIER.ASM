;=============================================================================
;  Carrier.asm
;
;  Carrier% Function:   Checks the state of the CD line. Returns True (-1)
;                       if CD is active and False (0) if not
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;============================================================================= 


.Model Medium,Basic

.Code PDQComm_Text

   Include C_Struct.Inc                ;Defines common structure

   Extrn C$Entry:Near

Carrier Proc Uses SI

   Call  C$Entry                       ;Set up SI and check if ISR active
   Jc    Exit                          ;If not, exit with error

   Mov   DX, [PDQ_Msr]                 ;Put address of UART MSR in DX
   In    AL, DX                        ;Load MSR into AL
   And   AL, 080h                      ;Mask out correct bit
   Je    CDLow                         ;Jump if CD low state

   Mov   AX, -1                        ;Set return TRUE
   Jmp   Short Exit                    ;And leave

CDLow:
   Xor   AX, AX                        ;Set return FALSE

Exit:
   Ret

Carrier Endp

End
