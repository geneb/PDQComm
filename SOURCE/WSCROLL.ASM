;=============================================================================
;  WScroll.asm
;
;  WScroll Subroutine:     Scrolls a window up or down on the screen
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;=============================================================================

.Model Medium, Basic

.Code

WScroll Proc Uses SI, WPtr:Ptr Word, NLines:Ptr Word, UpDn:Ptr Word

   Local SaveAttr:Byte
   
   Mov   Si,WPtr                       ;Load address of window type in SI
   Mov   Al, Byte Ptr [Si + 6]         ;Get the background attribute
   Mov   Cl, 4
   Shl   Al, Cl                        ;Shift it over by 4
   Mov   Ah, Byte Ptr [Si + 4]
   And   Ah, 0Fh                       ;Mask out blink
   Or    Al, Ah                        ;Or it with the foreground attribute
   Mov   SaveAttr, Al                  ;Save it for later
   Mov   Ch, Byte Ptr [Si + 8]         ;Load top row
   Dec   Ch                            ;Make it zero based
   Mov   Cl, Byte Ptr [Si + 12]        ;Load left column
   Dec   Cl                            ;Make it zero based
   Mov   Dh, Byte Ptr [Si + 10]        ;Load bottom row
   Dec   Dh                            ;Make it zero based
   Mov   Dl, Byte Ptr [Si + 14]        ;Load right column
   Dec   Dl                            ;Make it zero based
   Mov   Bx, UpDn                      ;Get up/down flag
   Mov   Ax, [Bx]
   Or    Ax, Ax                        ;See if it is not zero
   Mov   Ah, 6                         ;Assume up
   Jz    Cont                          ;Zero is up
   Inc   Ah                            ;Not zero so make it down

Cont:
   Mov   Bx, NLines
   Mov   Al, Byte Ptr [Bx]             ;Load number of lines in Al
   Mov   Bh, SaveAttr                  ;Put attribute back in Bh
   Int   10h                           ;Do interrupt

   Ret
   
WScroll Endp

End
