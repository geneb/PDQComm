;=============================================================================
;  OpencomX.asm
;
;  OpencomX(Address%, IRQ%) Subroutine: Opens a com
;               port with non-standard parameters
;
;  Copyright (c) 1990, 1991 Clearware Computing, By David Cleary
;=============================================================================
;*****************************************************************************
;
; .001 - 5/1/91 - Cleaned up error codes like OpenCom.
;
; .002 - 8/8/91 - Added call to IsAPort.
;
; .003 - 12/10/91 - Added support for "AT" IRQs.
;
; .004 - 1/20/92 - Fixed bug that caused port to be closed if you tried to
;                  open it a second time. Fixed bug that caused subsequent
;                  opens to fail if you tried to open a non-existant port.
;
;*****************************************************************************

.Model Medium,Basic

.Data

   IFDEF QLB
      P$PDQErr EQU b$errnum            ;Use QB's error variable if making
      Extrn b$errnum:Word              ;a quicklibrary
      Ercd     EQU 5
   ELSE
      Extrn P$PDQErr:Word              ;Holds error code
      Ercd     EQU -1
   ENDIF

   EXTRN C$ActiveIRQs:BYTE, C$ActivePort:WORD, C$ISRTable:WORD

.Code PDQComm_Text

   Include  C_Struct.Inc               ;Defines common structure

   Extrn    B$SETM:Proc                ;Decreases QB's heap for buffer
   Extrn    C$SETISRVECTOR:Near        ;Sets an ISR vector
   Extrn    FLUSHBUFFER:Proc           ;Flushes receive buffer
   Extrn    C$ENTRY:Near               ;Puts address of com structure in SI
   Extrn    C$ENDCOM:Proc              ;Needed for B_OnExit
   Extrn    IsAPort:Proc               ;Checks for port

   IFDEF FS
      Extrn    B_ONEXIT:Proc           ;Closes com port automatically
   ELSE
      Extrn    B_OnExit:Proc           ;Closes com port automatically
   ENDIF
   
OPENCOMX Proc USES SI DI, Address:Ptr Word, IRQ:Ptr Word

;-----  Set up address of Com structure in SI and check if port is open
   Call  C$ENTRY
   Xor   AX, AX
   Mov   P$PDQErr, AX
   Mov   AX, [PDQ_ComFlag]
   Or    AX, AX
   Jz    Cont0
   Mov   AX, 52
   Jmp   AlreadyOpen

;----- Check for valid and unused IRQ
Cont0:
   Mov   BX, IRQ
   Mov   AX, [BX]                      ;Get interrupt level requested
   Cmp   AX, 0                         ;Check to see that it is between
   Jle   BadIRQ                        ;1 and 7
   Cmp   AX, 7
   Jle   Cont1

;-----  Check for IRQ 10 - 15
   Cmp   AX, 10
   Jl    BadIRQ
   Cmp   AX, 15
   Jle   Cont1                         ;We have an IRQ between 10 and 15

BadIRQ:
   Mov   AX, Ercd
   Jmp   Error

IRQError:
   Mov   AX, 52
   Jmp   Error
   
Cont1:
   Cmp   AL, C$ActiveIRQs              ;Check against already active IRQ's
   Je    IRQError
   Cmp   AL, C$ActiveIRQs[1]
   Je    IRQError
   Mov   BX, C$ActivePort
   Dec   BX
   Mov   C$ActiveIRQs[BX], AL          ;Save current IRQ
   Test  AL, 8                         ;Check if we have an AT IRQ
   Jnz   ATIRQ                         ;We do, so handle it diferently

;-----  IRQ 1 - 7
   Or    AX, 8                         ;Save it as an Int Level
   Jmp   Cont2

;-----  IRQ 10 - 15
ATIRQ:
   Add   AX, 68h

;-----  Do Address
Cont2:
   Mov   [PDQ_IntLevel], AX
   Mov   BX, Address
   Mov   AX, [BX]
   Or    AX, AX                        ;Check for a valid address
   Jne   Cont3
   Mov   AX, Ercd                      ;Put error code in AX
   Jmp   Error

Cont3:
   Mov   [PDQ_Thr], AX                 ;Transmit register
   Push  BX
   Call  IsAPort                       ;See if port is real
   Or    AX, AX
   Jnz   Cont4                         ;It is, so continue
   Mov   AX, 54                        ;Set error 54
   Jmp   Error                         ;And split

Cont4:
   Mov   AX, [PDQ_Thr]                 ;Restore AX
   Mov   [PDQ_Rbr], AX                 ;Receive register
   Inc   AX
   Mov   [PDQ_Ier], AX                 ;Interrupt enable register
   Inc   AX
   Mov   [PDQ_Iir], AX                 ;Interrupt identification register
   Inc   AX
   Mov   [PDQ_Lcr], AX                 ;Line control register
   Inc   AX
   Mov   [PDQ_Mcr], AX                 ;Modem control register
   Inc   AX
   Mov   [PDQ_Lsr], AX                 ;Line status register
   Inc   AX
   Mov   [PDQ_Msr], AX                 ;Modem status register
   Mov   BX, 512
   Mov   [PDQ_RecLength], BX           ;Make receive buffer 512 bytes

IFDEF QLB                              ;Call SETMEM if this is for QB
   Push  BX                            ;Save BX
   Add   BX, 32                        ;Allow for a little extra
   Mov   AX, BX
   Neg   AX                            ;Put in AX and make it negative
   Cwd                                 ;Convert it to a long
   Push  DX
   Push  AX
   Call  B$SETM                        ;Push and call SETMEM
   Pop   BX                            ;Restore BX
ENDIf

;-----  Allocate receive buffer
   Mov   CL, 4                         ;Divide by 16 to get the number of
   Shr   BX, CL                        ;paragraphs
   Inc   BX                            ;Round up
   Mov   AH, 48h
   Int   21h                           ;If no carry, then everything fine
   Jnc   NoErr
   Mov   AX, 7                         ;Out of memory. Put error code in AX
   Jmp   Error                         ;And split
   
NoErr:
   Mov   [PDQ_RBufSeg], AX
   Mov   AX, [PDQ_RecLength]           ;Set up Nearfull and NearEmpty marks
   Sub   AX, 64
   Mov   [PDQ_NearFull], AX
   Mov   AX, 032
   Mov   [PDQ_NearEmpty], AX

   Xor   AX, AX                        ;Assume no handshaking
   Mov   [PDQ_HandMeth], AX

;-----  Save state of UART registers
   Mov   DX, [PDQ_Ier]
   In    AL, DX
   Mov   [PDQ_IerReg], AL              ;Save Interrupt Enable Register
   Inc   DX                            ;Two INCs faster/less code
   Inc   DX                            ;than a MOV
   In    AL, DX
   Mov   [PDQ_LcrReg], AL              ;Save Line Control Register
   Inc   DX
   In    AL, DX
   Mov   [PDQ_McrReg], AL              ;Save Modem Control Register

;-----  Initialize buffer
   Mov   AX, -1
   Mov   [PDQ_ComFlag], AX             ;Make ComFlag true
   Call  FLUSHBUFFER                   ;Start with a clean slate

;-----  Initialize ISR vector
   Mov   AX, [PDQ_IntLevel]            ;Put interrupt level in AX
   Mov   BX, C$ActivePort
   Mov   [PDQ_ComPort], BX
   Dec   BX
   Shl   BX, 1
   Mov   BX, C$ISRTable[BX]
   Call  C$SETISRVECTOR                ;And set ISR vector

;----- Initialize UART registers and 8259 PIC
   Cli                                 ;Disable interrupts
   Mov   DX, [PDQ_Mcr]
   Mov   AL, 00Bh                      ;Set modem control lines
   Out   DX, AL                        ;And output it to UART
   Mov   DX, [PDQ_Lsr]
   In    AL, DX                        ;Access registers to reset
   Mov   DX, [PDQ_Rbr]
   In    AL, DX                        ;Do the same with this one
   Mov   CX, [PDQ_IntLevel]            ;Generate bit mask from int level
   Cmp   CX, 10h
   Jge   ATIRQ1
   Mov   DX, 21h
   Jmp   Cont5

ATIRQ1:
   Mov   DX, 0A1h

Cont5:
   In    AL, DX
   Mov   [PDQ_PIC], AL
   And   CX, 7
   Mov   BL, 1
   Shl   BL, CL                        ;IRQ level bit is set
   Not   BL                            ;Now IRQ level bit is clear
   And   AL, BL                        ;Mask out that bit
   Out   DX, AL                        ;Set PIC

   Mov   AL, 1
   Mov   DX, [PDQ_Ier]
   Out   DX, AL                        ;Enable interrupts on UART

   Sti                                 ;Enable interrupts
   Push  CS                            ;Push current code segment
   Lea   AX, C$ENDCOM                  ;Get offset of CloseCom
   Push  AX
   Call  B_OnExit                      ;Register it with B_OnExit
   
Exit:
   Ret                                 ;We are done

Error:
   Mov   P$PDQErr, AX                  ;Put error code in PDQErr
   Mov   Word Ptr [PDQ_ComFlag], 0     ;Set port not open flag
   Mov   BX, C$ActivePort
   Dec   BX
   Mov   Byte Ptr C$ActiveIRQs[BX], 0  ;Reset used IRQ
   Mov   AX, [PDQ_RBufSeg]             ;Check if memory was allocated
   Or    AX, AX
   Jz    Exit                          ;If it was, try to release it
   Mov   ES, AX
   Mov   AH, 49h
   Int   21h
   Jmp   Short Exit                    ;And leave

AlreadyOpen:
   Mov   P$PDQErr, AX
   Jmp   Short Exit

OPENCOMX Endp

End
   
