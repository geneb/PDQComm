;=============================================================================
;  Closecom.asm
;
;  CloseCom Subroutine: Closes comm port
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;=============================================================================

;*****************************************************************************
;
; .001 - 9/18/90 - Cleared error code because of B_ONEXIT.
;
; .002 - 12/26/90 - Added multiport support. Now restores UART and PIC to
;                   state when port was opened.
;
; .003 - 12/10/91 - Added support for "AT" IRQs.
;
;*****************************************************************************

.Model Medium, Basic

.Data

   IFDEF QLB
      P$PDQErr EQU b$errnum            ;Use QB's error variable if making
      Extrn b$errnum:Word              ;a quicklibrary
      Ercd     EQU 5
   ELSE
      Extrn P$PDQErr:Word              ;Holds error code
      Ercd     EQU -1
   ENDIF

   EXTRN C$NumPorts:WORD, C$ActivePort:WORD, C$ActiveIRQs:BYTE

.Code PDQComm_Text

   Include C_Struct.Inc                ;Defines common structure

   Extrn C$ENTRY:Near
   Extrn SETACTIVEPORT:Proc
   Extrn B$SETM:Proc
   
CLOSECOM Proc Uses SI DS

;-----  Set up address of Comm structure in SI and check if port is open

   Call  C$ENTRY                       ;Set up SI and see if ISR is active
   Jnc   Cont                          ;Exit with an error if not
   Xor   AX, AX
   Mov   P$PDQErr, AX                  ;Clear any error code because of B_ONEXIT
   Jmp   Short Exit

;-----  Make port and IRQ inactive - release buffer memory
Cont:
   Xor   AX, AX
   Mov   [PDQ_ComFlag], AX             ;Make ISR inactive

   Mov   BX, C$ActivePort
   Dec   BX
   Mov   C$ActiveIRQs[BX], AL          ;Make IRQ inactive
   Mov   BX, [PDQ_RBufSeg]             ;Release receive buffer memory
   Mov   ES, BX
   Mov   AH, 49h
   Int   21h

;-----  Return memory to QB
IFDEF QLB                              ;Call SETMEM if this is for QB
   Mov   AX, [PDQ_RecLength]
   Cwd                                 ;Convert it to a long
   Add   AX, 32                        ;Allow for a little extra
   Push  DX
   Push  AX
   Call  B$SETM                        ;Push and call SETMEM
ENDIf

;----- Restore state of 8259 controller
   Cli                                 ;Disable Interrupts
Cont1:
   Mov   CX, [PDQ_IntLevel]            ;Generate bit mask from int level
   Cmp   CX, 10h
   Jge   ATIRQ1
   Mov   DX, 21h
   Jmp   Cont5

ATIRQ1:
   Mov   DX, 0A1h

Cont5:
   And   CX, 7
   Mov   BL, 1
   Shl   BL, CL                        ;IRQ level bit is set
   And   BL, [PDQ_PIC]                 ;Restore to previos state
   In    AL, DX                        ;Get the current PIC
   Or    AL, BL                        ;Set desired bit
   Out   DX, AL                        ;Set PIC

;-----  Restore state of UART
   Mov   DX, [PDQ_Ier]                 ;Reset UART Interrupts
   Mov   AL, [PDQ_IerReg]
   Out   DX, AL
   
   Inc   DX                            ;Reset UART parameters
   Inc   DX
   Mov   AL, [PDQ_LcrReg]
   Out   DX, AL

   Inc   DX                            ;Reset Modem control pins
   Mov   AX, [PDQ_McrReg]
   Out   DX, AL
   Sti                                 ;Enable Interrupts

;----- Reset ISR vector back to what it was
   Mov   AX, [PDQ_IntLevel]            ;Set up for a INT 21h function 25h
   Mov   AH, 25H
   Mov   DX, [PDQ_OldVecOfs]           ;DS:DX is the vector we are installing
   Mov   BX, [PDQ_OldVecSeg]           ;PDQ_IntLevel is the interrupt
   Mov   DS, BX
   Int   21H

Exit:
   Ret

CLOSECOM Endp

C$ENDCOM Proc

   LOCAL PortNum:Word
   
   Mov   CX, C$NumPorts               ;Get number of ports in CX
   Mov   PortNum, 1                    ;Start with port 1
   
CloseLoop:
   Push  CX                            ;Save CX
   Lea   BX, PortNum
   Push  BX                            ;Push address of port number
   Call  SetActivePort                 ;Make it active
   Call  CloseCom                      ;And close it
   Inc   PortNum                       ;Go to next port
   Pop   CX                            ;Restore CX
   Loop  CloseLoop                     ;And continue until all are closed
   Ret

C$ENDCOM Endp
   
End
