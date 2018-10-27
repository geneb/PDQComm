;=============================================================================
;  Opencom.asm
;
;  Opencom(Param$) Subroutine: Opens a com port
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;=============================================================================

;*****************************************************************************
;
; .001 - 8/5/90 - Added support for B_OnExit and made call to B$SETM if
;                 library is for QB.
;
; .002 - 9/18/90 - Added support for RTS as handshaking parameter due to
;                  docs.
;
; .003 - 12/26/90 - Added multiport support. Modified for both near and
;                   far strings. Saves state of UART and PIC for restoration
;                   when port is closed.
;
; .004 - 5/1/91 - Cleaned up some wrong error codes.
;
; .005 - 7/29/91 - Now calls IsAPort to see if port is real.
;
; .006 - 12/10/91 - Added support for 4 ports.
;
; .007 - 1/20/92 - Fixed bug that caused port to be closed if you tried to
;                  open it a second time. Fixed bug that caused subsequent
;                  opens to fail if you tried to open a non-existant port.
;
;*****************************************************************************

.Model Medium,Basic

   ModemType Struc
      Baud     DD ?
      Parity   DB ?
      DBits    DW ?
      SBits    DW ?
   ModemType Ends

.Data

   IFDEF QLB
      P$PDQErr EQU b$errnum            ;Use QB's error variable if making
      Extrn b$errnum:Word              ;a quicklibrary
      Ercd     EQU 5
   ELSE
      Extrn P$PDQErr:Word              ;Holds error code
      Ercd     EQU -1
   ENDIF
   
   Hand        DW 0
   HandAdd     DW 0
   Modem       ModemType <0,0,0,0>
   EXTRN C$ActivePort:WORD, C$ActiveIRQs:BYTE, C$ISRTable:WORD

.Code PDQComm_Text

   Include  C_Struct.Inc              ;Defines common structure
   Include  C_Modem.Inc

IFDEF FS                               ;Farstring routines
   Extrn    C$FSINFO:Proc
ENDIF

   Extrn    C$UCASE:Near
   Extrn    B$SETM:Proc                ;Decreases QB's heap for buffer
   Extrn    GETCOMPORTS:Proc           ;Gets com port addresses
   Extrn    PARSECOMPARAM:Proc         ;Parses OpenCom command line
   Extrn    C$SETISRVECTOR:Near        ;Sets an ISR vector
   Extrn    FLUSHBUFFER:Proc           ;Flushes receive buffer
   Extrn    SETCOM:Proc                ;Sets UART to correct parameters
   Extrn    C$ENDCOM:Proc              ;Needed for B_OnExit
   Extrn    C$ENTRY:Near               ;Sets up CommStruct
   Extrn    ISAPORT:Proc               ;Checks if port is valid

   IFDEF FS
      Extrn    B_ONEXIT:Proc           ;Closes com port automatically
   ELSE
      Extrn    B_OnExit:Proc           ;Closes com port automatically
   ENDIF
   
OPENCOM Proc USES SI DI, Param:Ptr Word

   Local Port1:Word, Port2:Word, Port3:Word, Port4:Word, ParseChar:Word

;-----  Set up address of Com structure in SI and check if port is open
   Call  C$ENTRY                       ;Set up pointer to commstruct
   Xor   AX, AX
   Mov   P$PDQErr, AX                  ;Clear error
   Mov   AX, [PDQ_ComFlag]
   Or    AX, AX
   Jz    Cont0
   Mov   AX, 52                        ;Put error code in AX
   Jmp   AlreadyOpen

;-----  Make the parameter string uppercase and save it
Cont0:
   Mov   BX, Param                     ;See if we were passed a null string

IFDEF FS
   Call  C$FSINFO
ELSE
   Mov   CX, [BX]
ENDIF

   Or    CX, CX
   Jnz   NotNull
   Mov   AX, Ercd
   Jmp   Error

;-----  Get the address of all reported com ports
NotNull:
   Lea   AX, Port1
   Push  AX
   Lea   AX, Port2
   Push  AX
   Lea   AX, Port3
   Push  AX
   Lea   AX, Port4
   Push  AX
   Call  GETCOMPORTS                   ;Get the addresses of all the com ports
   
   Mov   AX, Port3                     ;Some older BIOS don't report Com 3 and
   Or    AX, AX                        ;4 so we fudge it with default values
   Jne   Cont1
   Mov   AX, 03E8h
   Mov   Port3, AX
   
Cont1:
   Mov   AX, Port4
   Or    AX, AX
   Jne   Cont2
   Mov   AX, 02E8h
   Mov   Port4, AX

;-----  Parse our parameter string
Cont2:
   Push  Param
   Lea   AX, [PDQ_ComPort]             ;Push address of comport in structure
   Push  AX
   Mov   AX, Offset Modem
   Push  AX                            ;Push address of Modem structure
   Lea   AX, [PDQ_RecLength]           ;Push address of receive buffer length
   Push  AX
   Mov   AX, Offset Hand
   Push  AX                            ;Push address of handshake descriptor
   Call  PARSECOMPARAM                 ;And parse out parameters

;-----  See if we had a good parameter string
   Mov   AX, P$PDQErr                  ;If an error is returned, then a
   Or    AX, AX                        ;bad parameter string was given
   Jz    GoodParam
   Jmp   Error
   
;----- Set up register addresses and interrupt level
GoodParam:
   Mov   AX, [PDQ_ComPort]             ;Set up addresses
   Cmp   AX, 1                         ;Port 1
   Jne   Sel2                          ;Check to see if it is COM2 in
   Cmp   Port1, 02F8h                  ;COM1's space. This happens if
   Jne   NotCom2                       ;COM2 is the only port in the
   Mov   AX, 000Bh                     ;System
   Jmp   Short IntLevCont

NotCom2:
   Mov   AX, 000Ch

IntLevCont:   
   Mov   [PDQ_IntLevel], AX
   Mov   AX, Port1
   Jmp   Short EndSel

Sel2:
   Cmp   AX, 2                         ;Port 2
   Jne   Sel3
   Mov   AX, 000Bh
   Mov   [PDQ_IntLevel], AX
   Mov   AX, Port2
   Jmp   Short EndSel

Sel3:                                  ;Port 3
   Cmp   AX, 3
   Jne   Sel4
   Mov   AX, 000Ch
   Mov   [PDQ_IntLevel], AX
   Mov   AX, Port3
   Jmp   Short EndSel

Sel4:
   Cmp   AX, 4                         ;Port 4
   Jne   SelElse
   Mov   AX, 000Bh
   Mov   [PDQ_IntLevel], AX
   Mov   AX, Port4
   Jmp   Short EndSel

SelElse:
   Mov   AX, Ercd                      ;Put error code in AX
   Jmp   Error                         ;And split

;-----  Make sure we aren't using the same int level as another port
EndSel:
   Mov   CX, [PDQ_IntLevel]            ;Check to see that IRQs
   And   CX, 7                         ;aren't reused
   Cmp   CL, C$ActiveIRQs
   Je    IRQError
   Cmp   CL, C$ActiveIRQs[1]
   Jne   IRQOk

IRQError:
   Mov   AX, 52
   Jmp   Error

IRQOk:
   Mov   BX, C$ActivePort
   Dec   BX
   Mov   C$ActiveIRQs[BX], CL          ;Save current IRQ
   Or    AX, AX                        ;Check for a valid address
   Jz    NoPort
   Mov   Port1, AX                     ;Save AX
   Lea   AX, Port1
   Push  AX                            ;Set up parameter to pass
   Call  IsAPort                       ;See if port is valid
   Or    AX, AX
   Mov   AX, Port1                     ;Restore AX
   Jnz   Cont3

NoPort:
   Mov   AX, 54                        ;Bad file mode error
   Jmp   Error

Cont3:
   Mov   [PDQ_Thr], AX                 ;Transmit register
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

   Mov   BX, [PDQ_RecLength]           ;Check for valid buffer length
   Cmp   BX, 128
   Jge   Cont4
   Mov   BX, 128
   Mov   [PDQ_RecLength], BX           ;Make it at least 128 bytes
   
Cont4:

IFDEF QLB                              ;Call SETMEM if this is for QB
   Mov   AX, BX
   Neg   AX                            ;Put in AX and make it negative
   Cwd                                 ;Convert it to a long
   Sub   AX, 32                        ;Allow for a little extra
   Push  DX
   Push  AX
   Call  B$SETM                        ;Push and call SETMEM
ENDIf

;-----  Allocate receive buffer memory
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

;----- Determine handshaking to be used
   Mov   BX, Offset Hand               ;Determine handshaking used

IFDEF FS
   Call  C$FSINFO
   Mov   BX, AX
   Mov   ES, DX
   Mov   AL, ES:[BX]
ELSE
   Mov   BX, [BX+2]
   Mov   AL, [BX]
ENDIF

   Call  C$UCASE
   Cmp   AL, 67                        ;Check for both CTS and RTS due
   Je    DoHand                        ;to docs
   Cmp   AL, 82
   Jne   Sel2h

DoHand:
   Mov   AX, 1
   Mov   [PDQ_HandMeth], AX            ;CTS/RTS is a 1
   Jmp   Short EndSelh

Sel2h:
   Cmp   AL, 88
   Jne   SelElseh
   Mov   AX, 2
   Mov   [PDQ_HandMeth], AX            ;XON/XOFF is a 2
   Jmp   Short EndSelh

SelElseh:
   Xor   AX, AX                        ;Assume no handshaking
   Mov   [PDQ_HandMeth], AX

;-----  Save state of important UART registers
EndSelh:
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

;-----  Set UART baud rate and initialize buffer
   Mov   AX, -1
   Mov   [PDQ_ComFlag], AX             ;Make ComFlag true
   Call  FLUSHBUFFER                   ;Start with a clean slate
   Mov   AX,Offset Modem
   Push  AX
   Call  SETCOM                        ;Set UART to correct parameters
   Mov   AX, P$PDQErr                  ;If an error is returned, then port
   Or    AX, AX                        ;is not really there
   Jnz   Error

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
   In    AL, DX                        ;Do the same with this on
   Mov   CX, [PDQ_IntLevel]            ;Generate bit mask from int level
   And   CX, 7
   Mov   BL, 1
   Shl   BL, CL                        ;IRQ level bit is set
   Mov   [PDQ_PIC], BL                 ;Save it
   In    AL, 21h
   And   [PDQ_PIC], AL                 ;Save state of PIC before
   Not   BL                            ;Now IRQ level bit is clear
   And   AL, BL                        ;Mask out that bit
   Out   21h, AL                       ;Set PIC
   Mov   AL, 1
   Mov   DX, [PDQ_Ier]
   Out   DX, AL                        ;Enable interrupts on UART

;-----  Register routine to close ports upon termination
   Sti                                 ;Enable interrupts
   Push  CS                            ;Push current code segment
   Lea   AX, C$ENDCOM                  ;Get offset of ending routine
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

OPENCOM Endp

End
   
