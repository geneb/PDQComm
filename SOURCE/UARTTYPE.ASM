;=============================================================================
;  Uarttype.asm
;
;  UARTType%(Address%) Function:  Returns the type of UART at the specified
;                                 address.
;
;  0 - 8250 / 8250B
;  1 - 8250A / 16450
;  2 - 16550
;  3 - 16550A
;  -1 - Unknown
;
;  Copyright (c) 1990, 1991 Clearware Computing, By David Cleary
;=============================================================================

;*****************************************************************************
;
; .001 - 8/8/91 - Added call to IsAPort
;
; .002 - 12/30/91 - Changed where interrupts are disabled
;
;*****************************************************************************

.Model Medium,Basic
   
.Code PDQComm_Text

   Extrn    IsAPort:Proc

UARTType Proc , Address:Ptr Word

   Local ScratchW:Word, Scratch:Byte

;-----  Set up address
   Mov   BX, Address
   Mov   DX, [BX]                      ;Put base address of port into DX

;-----  Check if port is valid
   Mov   ScratchW, DX                  ;Save DX
   Push  BX
   Call  IsAPort
   Or    AX, AX
   Jz    PortNotValid

;-----  Restore register
PortValid:
   Mov   DX, ScratchW

;-----  Check for 8250A / 16450
   Cli                                 ;Disable interrupts
   Add   DX, 7                         ;Point DX at Scratchpad register
   In    AL, DX
   Mov   Scratch, AL                   ;Save scratch just in case
   Mov   AL, 42                        ;The answer to everything
   Out   DX, AL                        ;Write it to the scratchpad
   In    AL, DX                        ;Read it back
   Cmp   AL, 42                        ;See if we have a winner
   Je    ChkFIFO

;-----  No scratch register, so it is an 8250 / 8250-B
   Xor   AX, AX                        ;It hasn't so exit with 0
   Jmp   Short Exit

;-----  Check for FIFO's
ChkFIFO:
   Mov   AL, Scratch                   ;Restore scratch register just in case
   Out   DX, AL
   Sub   DX, 5                         ;Point DX to FIFO control register
   In    AL, DX                        ;Read it
   Test  AL, 30h                       ;If these bits aren't 0, then
   Jz    Cont                          ;we have a strange UART
   Mov   AX, -1
   Jmp   Short Exit

Cont:   
   Mov   AL, 1
   Out   DX, AL                        ;Enable FIFO mode
   In    AL, DX
   Test  AL, 0C0h                      ;See if FIFOs were enabled
   Jnz   Cont1
   Mov   AX, 1                         ;They weren't so we don't have a 16550
   Jmp   Short Exit

;----- See if we have a 16550 or 16550A
Cont1:
   Mov   CL, 6                         ;The 16550 FIFOs don't work right. To
   Shr   AL, CL                        ;distinguish this part from the fixed
   Mov   Scratch, AL                   ;16550A, National sets bits 6&7 instead
   Xor   AL, AL                        ;of just 7 on the 16550A. The shift 
   Out   DX, AL                        ;puts either a 2 or 3 in AL.
   Mov   Al, Scratch                   ;Turn FIFOs off
   And   AX, 0FFh

Exit:
   Sti                                 ;Enable interrupts
   Ret

PortNotValid:
   Mov   AX, -1
   Jmp   Exit

UARTType Endp
   
End
   
