;=============================================================================
;  Setcom.asm
;
;  SetCom(Config as ModemType) Subroutine: Changes config of an open port
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;=============================================================================

;*****************************************************************************
;
; .001 - 5/1/91 - Checks to see that DBits, SBits and Parity are correct.
;
; .002 - 7/29/91 - Removed check to see if port is valid. That is now handled
;                  by IsAPort%.
;
;*****************************************************************************

.Model Medium, Basic

.Data

   IFDEF QLB
      P$PDQErr EQU b$errnum            ;Use QB's error variable if making
      Extrn b$errnum:Word              ;a quick library
      Ercd     EQU 5
   ELSE
      Extrn P$PDQErr:Word              ;Holds error code
      Ercd     EQU -1
   ENDIF

.Code PDQComm_Text

   Include C_Struct.Inc               ;Defines common structure
   Include C_Modem.Inc                ;Defines Modem structure

   Extrn B$DVI4:Proc                   ;QB Long Int Divide
   Extrn C$ENTRY:Near
   
SETCOM Proc Uses ES SI DI, Modem:Ptr Word

   Local MSB:Byte, LSB:Byte, LCR:Byte

   Call  C$ENTRY                       ;Setup SI and see if ISR is active
   Jnc   Cont                          ;If not, exit with error 52
   Jmp   Exit

Cont:
   Mov   DI, Modem                     ;Put address of Modem into DI
   Mov   AX, [Modem_BaudMSB]
   Push  AX
   Mov   AX, [Modem_BaudLSB]
   Push  AX
   Mov   AX, 1                         ;8250 UARTS have a 16 bit word it uses
   Push  AX                            ;to set the baud rate. It is 115200\
   Mov   AX, 49664                     ;the baud rate you want. We use QB's
   Push  AX                            ;long divide to do this.

   Call  B$DVI4
   Mov   MSB, AH                       ;The answer will always be in integer
   Mov   LSB, AL                       ;range. We will save them for later.

   Mov   DI, Modem
   Mov   AX, [Modem_DBits]             ;This sets up the Line Control Register
                                       ;which determines word size, parity,
   Cmp   AL, 5
   Jl    ParamError
   Cmp   AL, 8
   Jg    ParamError
   Shr   AL, 1                         ;etc. See data book on INS8250 for more
   Shr   AL, 1                         ;info
   Shr   AL, 1
   Or    AX, 2
   Mov   CL, [Modem_Parity]            ;Check parity
   Cmp   CL, "E"
   Jne   OddP
   Mov   CL, 018h                      ;Even parity needs a 18h
   Jmp   Short EndPar
   
OddP:
   Cmp   CL, "O"
   Jne   NoPar
   Mov   CL, 008h                      ;Odd parity needs an 8h
   Jmp   Short EndPar
   
NoPar:
   Cmp   CL, "N"
   Jne   ParamError
   Xor   CL, CL                        ;No parity is a zero
   
EndPar:
   Or    AL, CL
   Shl   CL, 1
   Shl   CL, 1
   Shl   CL, 1
   Mov   CX, [Modem_SBits]
   Or    CL, CL
   Jz    ParamError
   Cmp   CL, 2
   Jg    ParamError
   Shr   CL, 1
   Shl   CL, 1
   Shl   CL, 1
   Or    AL, CL                        ;The LCR is an 8 bit value.
   Mov   LCR, AL                       ;Save it for later
   
   Cli                                 ;Disable interrupt while we do this
   Mov   DX, [PDQ_Lcr]                 ;Put address of LCR into dx
   Or    AL, 080h                      ;Set bit in LCR so we can set baud
   Out   DX, AL
   Mov   AL, LSB                       ;Put LSB of baud divisor in AL
   Mov   DX, [PDQ_Rbr]                 ;Put address of port in DX
   Out   DX, AL
   Mov   AL, MSB                       ;Put MSB of baud divisor in AL
   Inc   DX                            ;Increment port address
   Out   DX, AL
   Mov   AL, LCR                       ;Retrieve correct LCR value
   Mov   DX, [PDQ_Lcr]                 ;And port address
   Out   DX, AL                        ;And ship it
   Sti                                 ;Enable interrupts

Exit:
   Ret

ParamError:
   Mov   Word Ptr[P$PDQErr], Ercd
   Jmp   Short Exit

SETCOM Endp

End

   
