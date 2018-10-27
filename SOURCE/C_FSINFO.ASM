;=============================================================================
;  C$FSInfo.asm
;
;  Internal routine to return farstring info.
;
;  Copyright (c) 1990,1991 Clearware Computing, By David Cleary
;=============================================================================

;*****************************************************************************
;
; .001 - 12/30/91 - Added Word on Local declaration.
;
;*****************************************************************************


.Model Medium,Basic
   
.Code

   Extrn StringAddress:Proc
   Extrn StringLength:Proc

C$FSInfo Proc Uses BX ES

   Local StrLen:Word

   Push  BX                            ;Descriptor comes in BX
   Push  BX                            ;Push it twice
   Call  StringLength                  ;Get the string length
   Mov   StrLen, AX                    ;Save it temporarily
   Call  StringAddress                 ;Get the string address
   Mov   CX, StrLen                    ;Put string length in CX

   Ret                                 ;DX:AX contains string address
C$FSInfo Endp                          ;CX contains the length

End
   
