;=============================================================================
;  C_ComISR.asm
;
;  The main ISR and receive ISR
;
;  Copyright (c) 1990, 1991 Clearware Computing, By David Cleary
;=============================================================================

.Model Medium, Basic

Include C_Struct.Inc

.Data

   IFDEF QLB
      P$PDQErr EQU b$errnum            ;Use QB's error variable if making
      Extrn b$errnum:Word              ;a quick library
      Ercd  EQU 5
   ELSE
      Extrn P$PDQErr:Word              ;Holds error code
      Ercd  EQU -1
   ENDIF

   PUBLIC C$RXInt, C$TXInt, C$LSRInt, C$MSRInt, C$INTTable

;-----  Contained in COMDATA.ASM
   EXTRN C$NumPorts:WORD, C$ActivePort:WORD, C$ActiveIRQs:BYTE
   EXTRN C$StructTable:WORD

;-----  Table for service routines
   C$INTTable  LABEL Word
   C$MSRInt    WORD C$IRET
   C$TXInt     WORD C$IRET
   C$RXInt     WORD C$RXISR
   C$LSRInt    WORD C$IRET

.Code PDQComm_Text

C$ISR Proc Near

;-----  Check if port is active
   Cmp   Word Ptr[PDQ_ComFlag], -1
   Jne   C$IRET                        ;We shouldn't be here - leave

;-----  See if we have valid interrupt
   Mov   DX, [PDQ_Iir]                 ;See what needs servicing
   In    AL, DX
   Test  AL, 1
   Jne   C$IRET                        ;Nothing does, so leave

;-----  Jump to appropriate routine
   And   AX, 7
   Mov   BX, AX
   Jmp   C$INTTable [BX]

C$ISR Endp

C$RXISR Proc Near                      ;Our receive ISR

Rec:
   Mov   DX, [PDQ_Rbr]                 ;Put receive register address in DX
   In    AL, DX                        ;Read receive register
   Mov   BX, [PDQ_RecIn]               ;Put receive buffer pointer in BX
   Mov   ES, [PDQ_RBufSeg]             ;Load ES:BX with address of buffer
   Mov   ES:[BX], AL                   ;Put character in buffer
   Mov   CX, Word Ptr[PDQ_HandMeth]
   Test  CX, 2                         ;Check for XON handshaking
   Jz    NoXoff
   
   Cmp   AL, 19                        ;See if XOFF was sent
   Jne   NotXoff
   Mov   Word Ptr[PDQ_XOff], -1        ;If so, set XOFF to -1 and exit
   Jmp   RecISRExit                    ;and leave
   
NotXoff:
   Cmp   Word Ptr[PDQ_XOff], -1
   Jne   ClearXOff                     ;Pass XON if XOFF never sent
   Cmp   AL, 17                        ;See if XON sent
   Jne   ClearXoff
   Mov   Word Ptr[PDQ_XOff], 0         ;If so, clear XOFF and exit
   Jmp   RecISRExit

ClearXOff:
   Mov   Word Ptr[PDQ_XOff], 0         ;Clear XOff flag
   
NoXoff:
   Inc   Word Ptr[PDQ_RecIn]           ;Increment buffer pointer
   Mov   AX, [PDQ_RecLength]
   Cmp   [PDQ_RecIn], AX               ;Check for buffer wrap around
   Jne   NoLoop
   Mov   Word Ptr[PDQ_RecIn], 0        ;If so, set pointer to 0
   
NoLoop:
   Cmp   [PDQ_RecNum], AX              ;Check for buffer overrun
   Jl    NoOverRun
   Mov   Word Ptr[PDQ_OverRun], -1     ;And set overrun bit to -1
   Jmp   RecISRExit
   
NoOverRun:
   Inc   Word Ptr[PDQ_RecNum]          ;Increment buffer counter
   Or    CX, CX                        ;Check if handshaking enabled
   Jz    RecISRExit
   Mov   AX, [PDQ_NearFull]
   Cmp   [PDQ_RecNum], AX              ;Check if buffer is nearfull
   Jle   RecISRExit                    ;If not, exit
   Mov   Word Ptr[PDQ_HandStat], -1    ;Else, set Handstat to -1
   Test  CX, 2                         ;See if RTS or XON handshaking
   Jz    Rts
   
   Mov   DX, [PDQ_Thr]                 ;Send XOFF
   Mov   AL, 19
   Out   DX, AL
   Jmp   RecISRExit
   
Rts:
   Mov   DX, [PDQ_Mcr]                 ;If RTS handshaking
   In    AL, DX
   And   AL, 0FDh                      ;Clear bit #1
   Out   DX, AL                        ;And drop RTS line

RecISRExit:
   Mov   DX, Word Ptr[PDQ_Lsr]         ;See if any more characters are ready
   In    AL, DX
   Test  AL, 1
   Jnz   Rec                           ;Go get next character

C$RXISR Endp

C$IRET Proc Near

   Mov   AX, 32                        ;Clear interrupt from PIC
   Cmp   Word Ptr[PDQ_IntLevel], 10h
   Jle   XTIrq
   Out   0A0h, AL                      ;For high "AT" IRQs
	Jmp	$+2									;Give PIC time to settle
	Jmp	$+2

XTIrq:
   Out   32, AL                        ;Clear "XT" PIC
	Jmp	$+2									;Give PIC time to settle
	Jmp	$+2
   Pop   DS                            ;Restore machine state
   Pop   ES
   Pop   DI
   Pop   SI
   Pop   DX
   Pop   CX
   Pop   BX
   Pop   AX
   Iret                                ;Interrupt return

C$IRET Endp

C$SETISRVECTOR Proc Near Uses SI ES DS ;Sets up our interrupt vector

; SI - Offset of CommStruct
; BX - Offset of ISR
; AL - Int Level

   Push  BX                            ;Save BX
   Mov   AH, 35h
   Int   21h                           ;Perform int 21 func 35 to get old
   Mov   [PDQ_OldVecOfs], BX           ;ISR address and save it
   Mov   [PDQ_OldVecSeg], ES
   Mov   AH, 25h
   Pop   DX                            ;Perform int 21 func 25 to load
   Push  CS                            ;new ISR address
   Pop   DS                            ;DS points to CS
   Int   21h
   
   Ret

C$SETISRVECTOR Endp

C$ENTRY Proc Near Uses AX              ;Called before all PDQComm routines

;-----  Load active structure
   Mov   BX, C$ActivePort
   Dec   BX
   Shl   BX, 1
   Mov   SI, C$StructTable [BX]

   Xor   AX, AX
   Mov   P$PDQErr, AX                  ;Clear error code
   Mov   AX, [PDQ_ComFlag]             ;Check if ISR is active. If not,
   Or    AX, AX                        ;return error code 52
   Jnz   NoError                       ;OR always clears carry flag
   Mov   AX, 52
   Mov   P$PDQErr, AX
   Stc                                 ;Set Carry flag

NoError:
   Ret

C$ENTRY Endp

SETACTIVEPORT Proc , PortNum:Ptr Word  ;Changes currently active port

   Mov   BX, PortNum                   ;Put requested port into AX
   Mov   AX, [BX]
   Cmp   AX, 0
   Jle   SetError                      ;Can't be less than 0
   Cmp   AX, C$NumPorts
   Jg    SetError                      ;Can't be greater than max ports
   Mov   C$ActivePort, AX              ;Make it active

SetExit:
   Ret

SetError:
   Mov   P$PDQErr, Ercd
   Jmp   Short SetExit

SETACTIVEPORT Endp

End
