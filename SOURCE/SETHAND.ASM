;=============================================================================
;  Sethand.asm
;
;  SetHandshaking(Meth$) Subroutine: Changes handshaking method
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;=============================================================================

;*****************************************************************************
;
; .001 - 10/20/90 - Added support for RTS as handshaking parameter due to
;                    docs.
;
; .002 - 12/26/90 - Modified for both near and far strings.
;
;*****************************************************************************

.Model Medium,Basic

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

   Include C_Struct.Inc                ;Defines common structure

   Extrn C$ENTRY:Near
   Extrn C$UCASE:Near

   IFDEF FS
      Extrn C$FSINFO:Proc
   ENDIF
   
SETHANDSHAKING Proc Uses ES DS SI DI, Meth:Ptr Word

   Call  C$ENTRY                       ;Set up SI and see if ISR is active
   Jc    Exit                          ;If not, exit with error 52

   Mov   BX, Meth
   
IFDEF FS
   Call  C$FSINFO
ELSE
   Mov   CX, [BX]
   Mov   AX, [BX+2]
ENDIF

   Jcxz  Exit
   Mov   BX, AX

IFDEF FS   
   Mov   ES, DX
   Mov   AL, ES:[BX]
ELSE
   Mov   AL, [BX]
ENDIF

   Call  C$UCASE
   Cmp   AL, "N"                       ;See what type of handshaking is
   Je    None                          ;requested
   Cmp   AL, "C"                       ;Use either CTS or RTS
   Je    CTS
   Cmp   AL, "R"
   Je    CTS
   Cmp   AL, "X"
   Jne   Error                         ;Invalid type so exit with an error
   Mov   AX, 2
   Jmp   Short Seth

CTS:
   Mov   AX, 1
   Jmp   Short Seth

None:
   Xor   AX, AX

Seth:   
   Mov   [PDQ_HandMeth], AX            ;Store appropriate type

Exit:
   Ret

Error:
   Mov   Word Ptr [P$PDQErr], Ercd     ;Set Illegal Function Call error
   Jmp   Short Exit

SETHANDSHAKING Endp

End
