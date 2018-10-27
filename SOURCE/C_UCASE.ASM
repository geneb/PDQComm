;=============================================================================
;  C$Ucase.asm
;
;  Internal routine returns ASCII value in AL as uppercase.
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;=============================================================================


.Model Medium,Basic
   
.Code PDQComm_Text

C$Ucase Proc Near

   Cmp   AL, 90                        ;See if value isn't uppercase
   Jle   AllDone
   Sub   AL, 32
                                       ;It is not so subtract 32
AllDone:
   Ret
   
C$Ucase Endp

End
   
