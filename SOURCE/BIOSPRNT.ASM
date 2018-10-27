;=============================================================================
;  Biosprint.asm
;
;  BiosPrint Subroutine:   Clone of PDQPrint, except it prints thru the BIOS.
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;=============================================================================

.Model Medium, Basic

.Code

IFDEF FS
   Extrn    C$FSInfo:Proc
ENDIF   

BIOSPrint Proc Uses ES SI, Text:Ptr DWord, Row:Ptr Word, Col:Ptr Word, Color:Ptr Word

   Mov   BX, Text

IFDEF FS
   Call  C$FSInfo
   Mov   ES, DX                        ;Length is in CX
   Mov   SI, AX                        ;ES:SI points to string data
ELSE
   Mov   CX, [BX]                      ;Put length of text in CX
   Mov   SI, [BX+2]                    ;And it's address in SI
   Push  DS
   Pop   ES
ENDIF

   Mov   BX, Row
   Mov   AX, [BX]
   Dec   Ax
   Mov   DH, AL                        ;Put row in DH and adjust for zero based
   Mov   BX, Col
   Mov   AX, [BX]
   Dec   Ax
   Mov   DL, AL                        ;Put col in DL and adjust for zero based
   Mov   BX, Color
   Mov   BX, [BX]                      ;Put color in BL
   Xor   BH, BH
   Mov   AX, 1300h                     ;Calling function 13h subfunction 0
   Push  BP
   Mov   BP, SI                        ;ES:SI holds address of string
   Int   10h                           ;Do interrupt
   Pop   BP                            ;Restore BP
   Ret                                 ;All done

BIOSPrint Endp

End
