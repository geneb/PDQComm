;=============================================================================
;  ISAPORT.asm
;
;  IsAPort:    Function that determines if a serial port is at the specified
;              address.
;              Bool = IsAPort(PAdr%)
;
;   Copyright (c) 1991, 1992 Clearware Computing, By David Cleary
;=============================================================================

;*****************************************************************************
;
; .001 - 2/19/92 - Went back to basics. Although the previous routine was
;                  very ingenious, too many "compatible" modem chip sets
;                  had problems emulating the real thing.
;
; .002 - 5/7/92 -  Changed yet again to get it to work under Windows.
;
; .003 - 4/25/93 - Added delays after OUTs to give the hardware a chance
;                  to catch up.
;
;*****************************************************************************

.Model Medium, Basic

.Code PDQComm_Text

IsAPort Proc, PAddress:Ptr Word

   LOCAL Temp:BYTE, Temp1:BYTE

   Cli                                 ;Turn interrupts off
   Mov   BX, PAddress
   Mov   DX, [BX]                      ;Get the address of the port to check
   Add   DX, 3
   In    AL, DX                        ;Read LCR
   Mov   Temp, AL                      ;Save it
   Or    AL, 80h                       ;Set DLAB
   Out   DX, AL                        ;Write LCR
   Jmp   $+2                           ;Delay
   Sub   DX, 3                         ;Point to RBR
   In    AL, DX                        ;Read LSB of divisor latch
   Mov   Temp1, AL                     ;Save it
   Mov   AL, 30h                       ;Set value for 2400 baud
   Out   DX, AL                        ;Write it
   Jmp   $+2                           ;Delay
   In    AL, DX                        ;Read it back
   Cmp   AL, 30h                       ;See if it stuck
   Jne   NotAPort                      ;It didn't, so split
   Add   DX, 3                         ;Point to LCR again
   Mov   AL, Temp                      ;Reset LCR
   Out   DX, AL
   Jmp   $+2
   Sub   DX, 3                         ;Read back RBR
   In    AL, DX
   In    AL, DX                        ;Read it twice
   Cmp   AL, 30h                       ;See if it is different
   Je    NotAPort                      ;It isn't so split
   Add   DX, 3
   Mov   AL, Temp                      ;Reset to original baud rate
   Or    AL, 80h
   Out   DX, AL
   Jmp   $+2
   Sub   DX, 3
   Mov   AL, Temp1
   Out   DX, AL
   Jmp   $+2
   Add   DX, 3
   Mov   AL, Temp
   Out   DX, AL
   Jmp   $+2
   Sti
   Mov   AX, -1                        ;Return true
   Ret

NotAPort:
   Add   DX, 3
   Mov   AL, Temp
   Or    AL, 80h
   Out   DX, AL
   Jmp   $+2
   Sub   DX, 3
   Mov   AL, Temp1
   Out   DX, AL
   Add   DX, 3
   Mov   AL, Temp
   Out   DX, AL
   Jmp   $+2
   Sti
   Mov   AX, -1                        ;Return true
   Xor   AX, AX                        ;Zero AX
   Ret

IsAPort Endp

End
