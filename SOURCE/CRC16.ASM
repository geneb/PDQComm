;=============================================================================
;  Crc16.asm
;
;  CRC16$(Strng$) Function:   Calculates the 16 bit CRC of incoming string
;                             returns it as a 2 byte string
;
;  Copyright (c) 1990, 1991 Clearware Computing, By David Cleary
;=============================================================================

;*****************************************************************************
;
; .001 - 9/18/90 - Fixed farstring errors.
;
; .002 - 12/26/90 - Modified for both near and far strings.
;
; .003 - 8/8/91 - Fixed string space corruption error with near strings
;
;*****************************************************************************

.Model Medium,Basic

.Data

   StrDesc  DWORD 0
   CRCDat   WORD 0

.Code

IFDEF FS
   Extrn    C$FSInfo:Proc              ;Farstring support
   Extrn    StringAssign:Proc          ;Farstring assign
   Extrn    StringRelease:Proc         ;Farstring delete
ELSE
   StringAssign EQU <B$ASSN>
   Extrn    B$ASSN:Proc
   StringRelease EQU <B$STDL>
   Extrn    B$STDL:Proc
ENDIF

CRC16 Proc Uses ES SI, StrPtr:Ptr Word

   Local StrPos:Word

   Lea   AX, StrDesc
   Push  AX
   Call  StringRelease                 ;Release old CRC data

   Mov   BX, StrPtr

IFDEF FS   
   Call  C$FSInfo
ELSE
   Mov   CX, [BX]
   Mov   AX, [BX+2]
ENDIF

   Jcxz  AllDone
   Push  DS
   Mov   SI, AX

IFDEF FS
   Mov   DS, DX
ENDIF

   Xor   DX, DX                        ;Zero DX
   
CrcLoop:
   Mov   SS:StrPos, CX                 ;Save string length in StrPos
   Lodsb                               ;Put char into AL
   Xchg  DH, DL                        ;Fancy algorithm for CRC
   Xor   DL, AL                        ;I haven't got the faintest idea
   Mov   AL, DL                        ;what it is doing
   Mov   CL, 4
   Shr   AL, CL
   Xor   DL, AL
   Mov   BL, DL
   Mov   AH, DL
   Shl   AH, CL
   Xor   DH, AH
   Xor   BH, BH
   Inc   CL
   Shl   BX, CL
   Xor   DX, BX
   Mov   CX, SS:StrPos
   Loop  CrcLoop                       ;Loop until CX is zero
   Xchg  DH, DL                        ;The move stores the string backwards
   Mov   SS:CrcDat, DX                 ;DX contains the CRC

Exit:
   Pop   DS                            ;Restore DS
   Push  DS
   Mov   AX, Offset CRCDat
   Push  AX
   Mov   AX, 2
   Push  AX
   Push  DS
   Lea   AX, StrDesc
   Push  AX
   Xor   AX, AX
   Push  AX
   Call  StringAssign

AllDone:
   Lea   AX, StrDesc
   Ret
 
CRC16 Endp

End
