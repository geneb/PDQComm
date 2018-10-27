;=============================================================================
;  Checksum.asm
;
;  CheckSum$(Strng$) Function:   Calculates the checksum of a string. It is
;                                returned as a 1 byte string
;
;  Copyright (c) 1990, 1991 Clearware Computing, By David Cleary
;=============================================================================

;*****************************************************************************
;
; .001 - 12/26/90 - Modified for both near and far strings.
;
; .002 - 8/8/91 - Fixed string space corruption with near strings.
;
;*****************************************************************************

.Model Medium,Basic

.Data

   StrDesc  DWORD 0
   ChkDat   BYTE 0

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

CheckSum Proc Uses ES SI, StrPtr:Ptr Word

   Lea   AX, StrDesc
   Push  AX
   Call  StringRelease                 ;Delete old checksum data
   Mov   BX, StrPtr                    ;Put address of descriptor in BX

IFDEF FS   
   Call  C$FSInfo                      ;DX:AX holds address of string data
                                       ;CX holds length
ELSE
   Mov   CX, [BX]
   Mov   AX, [BX+2]
ENDIF

   Jcxz  AllDone                       ;We got a null string so exit
   Push  DS                            ;Save DS
   Mov   SI, AX

IFDEF FS   
   Mov   DS, DX                        ;Point DS:SI at string
ENDIF

   Xor   BL, BL                        ;Zero BL
   
ChkLoop:
   Lodsb
   Add   BL, AL                        ;Add bytes
   Loop  ChkLoop                       ;Until string is done
   Mov   SS:ChkDat, BL                 ;Put BL into string
   
Exit:
   Pop   DS                            ;Restore DS
   Push  DS
   Mov   AX, Offset ChkDat
   Push  AX
   Mov   AX, 1
   Push  AX                            ;Assign from fixed length
   Push  DS
   Lea   AX, StrDesc
   Push  AX
   Xor   AX, AX
   Push  AX                            ;To variable length
   Call  StringAssign                  ;Assign it

AllDone:
   Lea   AX, StrDesc
   Ret

CheckSum Endp

End
