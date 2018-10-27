;=============================================================================
;  Parsecom.asm
;
;  ParseComParam() Subroutine: Opens a com port
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;=============================================================================

;*****************************************************************************
;
; .001 - 12/26/90 - Modified for both near and far strings.
;
; .002 - 3/11/91 - Saved delimit char for PDQPARSE.
;
;*****************************************************************************

.Model Medium,Basic

.Data

   IFDEF QLB
      P$PDQErr EQU b$errnum            ;Use QB's error variable if creating
      Extrn b$errnum:Word              ;a quicklibrary
      Ercd     EQU 5
   ELSE
      Extrn P$PDQErr:Word
      Ercd     EQU -1
   ENDIF
   
   Extrn P$DELIMITCHAR:Byte            ;this is in PDQPARSE.ASM
   
   StrLen   DW 0                       ;String Descriptor
   StrAdd   DW 0

.Code PDQComm_Text

Include  C_Modem.Inc                   ;Defines Modem Structure

IFDEF FS
   Extrn    STRINGASSIGN:Proc          ;Assigns fixed to variable string
   Extrn    STRINGRELEASE:Proc         ;Deletes a string
   Extrn    C$FSINFO:Proc
ELSE
   STRINGASSIGN EQU <B$ASSN>
   STRINGRELEASE EQU <B$STDL>
   Extrn    STRINGASSIGN:Proc          ;Assigns fixed to variable string
   Extrn    STRINGRELEASE:Proc         ;Deletes a string
ENDIF

   Extrn    PDQRESTORE:Proc
   Extrn    PDQPARSE:Proc
   Extrn    PDQVALI:Proc
   Extrn    PDQVALL:Proc
   Extrn    C$UCASE:Near

PARSECOMPARAM Proc USES ES SI DI, Param:Ptr Word, Port:Ptr Word, Modem:Ptr Word, BLen:Ptr Word, Hand:Ptr Word

   Local OldDelimitChar:Byte
   
   Call  PDQRESTORE                    ;Initialize PDQPARSE routine
   Mov   AL, P$DELIMITCHAR             ;Save Delimit Char
   Mov   OldDelimitChar, AL
   Mov   Byte Ptr P$DELIMITCHAR, 58    ;Set ':' as delimit char
   Push  Param
   Call  PDQPARSE                      ;Parse out the com port
   Mov   BX, AX

IFDEF FS
   Call  C$FSINFO                      ;This checks to see if PDQPARSE
ELSE
   Mov   CX, [BX]
   Mov   AX, [BX+2]
ENDIF

   Jcxz  Error                         ;returned a null string

Cont0:
   Add   AX, CX                        ;Add length of string to string offset
   Dec   AX                            ;Adjust for zero based
   Mov   BX, AX

IFDEF FS
   Mov   ES, DX                        ;Put DX into ES
   Mov   AL, ES:[BX]                   ;Get last character in string
ELSE
   Mov   AL, [BX]
ENDIF

   Sub   AL, 48
   XOr   AH, AH                        ;Zero AH
   Mov   BX, Port
   Mov   [BX], AX                      ;Store value in Port

   Mov   Byte Ptr P$DELIMITCHAR, 44    ;Set ',' as delimit char
   Push  Param
   Call  PDQPARSE                      ;Parse out baud rate
   Mov   BX, AX
   
IFDEF FS
   Call  C$FSINFO
   Or    CX, CX
   Jnz   Cont1
ELSE
   Cmp   Word Ptr[BX], 0
   Jne   Cont1
ENDIF

Error:
   Mov   Word Ptr [P$PDQErr], Ercd
   Jmp   Exit


Cont1:
   Push  BX                            ;BX contains temp string of baud rate
   Call  PDQVALL                       ;Get its value
   Mov   DI, Modem
   Mov   [Modem_BaudLSB], AX
   Mov   [Modem_BaudMSB], DX           ;Store in Modem Structure

   Push  Param
   Call  PDQPARSE                      ;Parse out parity
   Mov   BX, AX

IFDEF FS   
   Call  C$FSINFO
ELSE
   Mov   CX, [BX]
   Mov   BX, [BX+2]
ENDIF

   Jcxz  Error

Cont2:

IFDEF FS
   Mov   BX, AX
   Mov   ES, DX
   Mov   AL, ES:[BX]
ELSE
   Mov   AL, [BX]
ENDIF

   Call  C$UCASE                       ;Make sure its upper case
   Mov   DI, Modem
   Mov   Byte Ptr[Modem_Parity], AL

   Push  Param
   Call  PDQPARSE
   Mov   BX, AX                        ;Parse out data bits

IFDEF FS
   Call  C$FSINFO
ELSE
   Mov   CX, [BX]
   Mov   BX, [BX+2]
ENDIF

   Jcxz  Error

Cont3:

IFDEF FS
   Mov   BX, AX
   Mov   ES, DX
   Mov   AL, ES:[BX]
ELSE
   Mov   AL, [BX]
ENDIF

   Sub   AL, 48
   Xor   AH, AH
   Mov   DI, Modem
   Mov   [Modem_DBits], AX             ;And store in structure

   Push  Param
   Call  PDQPARSE                      ;Parse out stop bits
   Mov   BX,AX

IFDEF FS
   Call  C$FSINFO
ELSE
   Mov   CX, [BX]
   Mov   BX, [BX+2]
ENDIF

   Jcxz  Error

Cont4:

IFDEF FS
   Mov   BX, AX
   Mov   ES, DX
   Mov   AL, ES:[BX]
ELSE
   Mov   AL, [BX]
ENDIF

   Sub   AL, 48
   Xor   AH, AH
   Mov   DI, Modem
   Mov   [Modem_SBits], AX             ;And store in structure

PLoop:
   Push  Param
   Call  PDQPARSE                      ;Parse out rest
   Mov   BX, AX

IFDEF FS
   Call  C$FSINFO
ELSE
   Mov   CX, [BX]
   Mov   BX, [BX+2]
ENDIF

   Jcxz  PDone

IFDEF FS
   Mov   BX, AX
   Mov   ES, DX
   Mov   AL, ES:[BX]
ELSE
   Mov   AL, [BX]
ENDIF

   Call  C$UCASE
   Cmp   AL, "R"
   Jne   HndShk

IFDEF FS   
   Mov   AL, ES:[BX+1]
ELSE
   Mov   AL, [BX+1]
ENDIF

   Call  C$UCASE
   Cmp   AL, "B"
   Jne   HndShk

RecBuf:
   Cmp   CX, 2
   Jg    Cont5
   Jmp   Error

Cont5:   
   Add   BX, 2
   Sub   CX, 2

IFDEF FS   
   Push  DX
ELSE
   Push  DS
ENDIF

   Push  BX
   Push  CX
   Push  DS
   Mov   AX, Offset StrLen
   Push  AX
   Xor   AX, AX
   Push  AX
   Call  STRINGASSIGN                  ;Create new string without RB
   Mov   AX, Offset StrLen
   Push  AX
   Call  PDQVALI                       ;Get its value
   Mov   BX, BLen
   Mov   [BX], AX                      ;And store it in BLen
   Mov   AX, Offset StrLen
   Push  AX
   Call  STRINGRELEASE                 ;Delete string
   Jmp   Short PLoop

HndShk:

IFDEF FS
   Push  ES
ELSE
   Push  DS
ENDIF

   Push  BX
   Push  CX
   Push  DS
   Push  Hand
   Xor   AX, AX
   Push  AX
   Call  STRINGASSIGN                  ;Assign it to Hand
   Jmp   Short PLoop

PDone:
   Mov   AL, OldDelimitChar
   Mov   P$DELIMITCHAR, AL             ;Restore delimit char
   Call  PDQRESTORE                    ;And restore Parse pointers

Exit:
   Ret

PARSECOMPARAM Endp

End
