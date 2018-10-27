;=============================================================================
;  Scancdes.asm
;
;  ScanCodes Function:     Like INSTR except looks for control characters
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;=============================================================================

.Model Medium,Basic

.Code

IFDEF FS
   Extrn    C$FSInfo:Proc
ENDIF

ScanCodes Proc Uses ES DI SI, Start:Ptr Word, String:Ptr Word

   Local StrLen:Word
   
   Cld
   Mov   BX, String

IFDEF FS
   Call  C$FSInfo
   Mov   ES, DX
   Mov   DI, AX
ELSE
   Mov   CX, [BX]                      ;Put length of string in CX
   Mov   DI, [BX+2]                    ;And it's address in DI
   Push  DS
   Pop   ES
ENDIF

   Jcxz  Error                         ;Leave if null string
   Mov   StrLen, CX                    ;Save original length
   Mov   BX, Start
   Mov   AX, [BX]                      ;Get starting location
   Dec   AX                            ;Adjust for zero base
   Sub   CX, AX                        ;Adjust string length for start
   Jle   Error
   Add   DI, AX                        ;Adjust string address for start
   Mov   AL, 32                        ;Look for anything less than 32
   
StrLoop:   
   Scasb
   Ja    AllDone                       ;Loop until control code found or
   Loop  StrLoop                       ;end of string

   Xor   AX, AX                        ;End of string. Return 0
   Jmp   Short Exit

AllDone:
   Mov   AX, StrLen                    ;Control code found
   Sub   AX, CX                        ;Find it's position in string
   Inc   AX

Exit:
   Ret                                 ;All done

Error:
   Xor   AX, AX                        ;Return 0 if invalid data
   Jmp   Short Exit

ScanCodes Endp

End
