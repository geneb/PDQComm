;=============================================================================
;  Getpcon.asm
;
;  GetPortConfig(Port%,Config as ModemType) Subroutine: Gets current port
;  configuration
;
;	Copyright (c) 1990, 1991 1992 Clearware Computing, By David Cleary
;=============================================================================

;*****************************************************************************
;
; .001 - 8/8/91 - Now calls IsAPort to see if port is real.
;
; .002 - 8/17/92 - Fixed bug in call to IsAPort
;
;*****************************************************************************

.Model Medium,Basic

   ModemType   Struc
      Baud     DD ?
      Parity   DB ?
      DBits    DW ?
      SBits    DW ?
   ModemType   Ends

.Data

   IFDEF QLB
      P$PDQErr EQU b$errnum            ;Use QB's error variable if making
      Extrn b$errnum:Word              ;a quicklibrary
      Ercd     EQU 5
   ELSE
      Extrn P$PDQErr:Word              ;Holds error code
      Ercd     EQU -1
   ENDIF
   
.Code PDQComm_Text

   Extrn GETCOMPORTS:Proc              ;Gets addresses of ports
   Extrn B$DVI4:Proc                   ;Long integer division
   Extrn IsAPort:Proc
   
GETPORTCONFIG Proc USES SI,Port:Ptr Word, Config:Ptr ModemType

   Local Port1:Word, Port2:Word, Port3:Word, Port4:Word
   Local THR:Word, LCR:Word, LCRData:Byte

   Lea   AX, Port1                     ;Get addresses of com ports
   Push  AX
   Lea   AX, Port2
   Push  AX
   Lea   AX, Port3
   Push  AX
   Lea   AX, Port4
   Push  AX
   Call  GETCOMPORTS

   Mov   BX, Port                      ;Get port asked for
   Mov   BX, [BX]
   
   Cmp   BX, 1
   Jne   Sel2
   Mov   AX, Port1
   Mov   THR, AX
   Jmp   Short EndSel
   
Sel2:
   Cmp   BX, 2
   Jne   Sel3
   Mov   AX, Port2
   Mov   THR, AX
   Jmp   Short EndSel

Sel3:
   Cmp   BX, 3                         ;Some older bios' do not report com 3
   Jne   Sel4                          ;or 4 so we fudge it with what its
   Mov   AX, Port3                     ;supposed to be
   Or    AX, AX
   Jnz   NoFudge1
   Mov   AX, 03E8h
   
NoFudge1:
   Mov   THR, AX
   Jmp   Short EndSel

Sel4:
   Cmp   BX, 4
   Jne   CaseElse
   Mov   AX, Port4
   Or    AX, AX
   Jnz   NoFudge2
   Mov   AX, 02E8h
   
NoFudge2:
   Mov   THR, AX
   Jmp   Short EndSel

CaseElse:
   Mov   AX, Ercd
   Jmp   Error                         ;Bad port selection

EndSel:
	Cli											;Disable interrupts
	Mov	Port1, AX							;Store port address in Port1
	Lea	AX, Port1							;Load address into AX
   Push  AX
   Call  IsAPort                       ;See if there is a port
   Jz    BadPort
   Mov   AX, THR                       ;Restore AX
   Add   AX, 3                         ;Set up addresses for other ports that
   Mov   LCR, AX                       ;are used

   Mov   DX, LCR
   In    AL, DX
   Mov   LCRData, AL                   ;Save it for later
   Or    AL, 080h
   Out   DX, AL

   Mov   DX, THR                       ;Get baud rate divisor LSB
   In    AL, DX
   Mov   BL, AL                        ;Save it for a minute
   Inc   DX                            ;Get baud rate divisor MSB
   In    AL, DX
   Xor   AH, AH
   Mov   CL, 8
   SAL   AX, CL                        ;Multiply it by 256 by shifting
   Mov   BH, AH                        ;Put the lsb back
   Mov   AL, LCRData
   Mov   DX, LCR
   Out   DX, AL                        ;Restore UART
   Sti                                 ;Enable interrupts

   Mov   SI, Config                    ;Put address of structure in SI
   Xor   DX, DX                        ;Zero DX
   Push  DX
   Push  BX                            ;Push divisor for long divide
   Mov   AX, 0C200h
   Mov   DX, 1                         ;Put 115200 into DX,AX
   Push  DX
   Push  AX
   Call  B$DVI4                        ;Do division, DX,AX will contain baud
   Mov   [SI], AX
   Mov   [SI+2], DX                    ;Store it in structure

   Mov   AL, LCRData                   ;Num DBits= (LCRData AND 3) + 5
   XOr   AH, AH
   And   AL, 3
   Add   AL, 5
   Mov   [SI+5], AX                    ;Store in structure

   Mov   AL, LCRData                   ;Num SBits= (LCRData AND 4) \4 +1
   And   AL,4
   Shr   AL,1
   Shr   AL,1
   Add   AL,1
   Mov   [SI+7], AX                    ;Store in structure

   Mov   AL, LCRData                   ;Parity= (LCRData AND 18h)
   And   AL, 018h                      ;Parity=0 - No Parity
   Jz    NoPar
   Cmp   AL, 018h                      ;Parity=18h - Even Parity
   Je    EPar
   Mov   AL, "O"
   Jmp   Short SavePar
   
NoPar:
   Mov   AL, "N"                       ;Else Odd Parity
   Jmp   Short SavePar
   
EPar:
   Mov   AL, "E"

SavePar:
   Mov   [SI+4], AL
   
Exit: 
   Ret

Error:
   Mov   P$PDQErr, AX                  ;Exit with error
   Jmp   Short Exit

BadPort:
   Sti
   Mov   AX, 54                        ;Port not there so exit with error 54
   Jmp   Short Error
   
GETPORTCONFIG Endp

End
