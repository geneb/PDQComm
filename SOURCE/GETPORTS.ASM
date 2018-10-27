;=============================================================================
;  GETPORTS.ASM
;
;  CALL GetComPorts(Port1%, Port2%, Port3%, Port4%)
;
;  Subroutine: Gets com port addresses
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;=============================================================================


.Model Medium,Basic

.Code PDQComm_Text

GetComPorts Proc Uses ES, Port1:Ptr Word, Port2:Ptr Word, Port3:Ptr Word, Port4:Ptr Word

   Xor   AX, AX
   Mov   ES, AX                        ;Zero ES
   
   Mov   BX, Port1                     ;Look in low memory for port addresses
   Mov   AX, ES:[0400H]
   Mov   [BX], AX

   Mov   BX, Port2
   Mov   AX, ES:[0402H]
   Mov   [BX], AX

   Mov   BX, Port3
   Mov   AX, ES:[0404H]
   Mov   [BX], AX

   Mov   BX, Port4
   Mov   AX, ES:[0406H]
   Mov   [BX], AX

   Ret
GetComPorts Endp

End
