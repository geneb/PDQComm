;=============================================================================
;	ComData.asm
;
;  PDQComm data
;
;  Copyright (c) 1990, 1991 Clearware Computing, By David Cleary
;=============================================================================

.Model Medium, Basic

.Data

   C$NumPorts     WORD 4               ;Maximum number of ports
   C$ActivePort   WORD 1               ;Currently active port
   C$ActiveIRQs   BYTE 4 DUP (0)       ;Table of IRQs used
   C$CommStruct1  BYTE 52 DUP (0)      ;Port 1 data structure
   C$CommStruct2  BYTE 52 DUP (0)      ;Port 2 data structure
   C$CommStruct3  BYTE 52 DUP (0)      ;Port 3 data structure
   C$CommStruct4  BYTE 52 DUP (0)      ;Port 4 data structure

;-----  ISR Offset table
   C$ISRTable     LABEL WORD
   C$ISR1Off      WORD C$Port1
   C$ISR2Off      WORD C$Port2
   C$ISR3Off      WORD C$Port3
   C$ISR4Off      WORD C$Port4

;-----  Structure offset table
   C$StructTable  LABEL WORD
   Struct1        WORD C$CommStruct1
   Struct2        WORD C$CommStruct2
   Struct3        WORD C$CommStruct3
   Struct4        WORD C$CommStruct4

   EXTRN C$INTTable:WORD

   PUBLIC C$NumPorts, C$ActivePort, C$ActiveIRQs, C$ISRTable, C$StructTable

.Code PDQComm_Text

   EXTRN C$ISR:Near

C$PORT1 Proc

   Push  AX
   Push  BX
   Push  CX
   Push  DX
   Push  SI
   Push  DI
   Push  ES
   Push  DS
   Mov   AX, DGROUP
   Mov   DS, AX
   Mov   SI, Struct1
   Jmp   C$ISR

C$PORT1 Endp

C$PORT2 Proc

   Push  AX
   Push  BX
   Push  CX
   Push  DX
   Push  SI
   Push  DI
   Push  ES
   Push  DS
   Mov   AX, DGROUP
   Mov   DS, AX
   Mov   SI, Struct2
   Jmp   C$ISR

C$PORT2 Endp

C$PORT3 Proc

   Push  AX
   Push  BX
   Push  CX
   Push  DX
   Push  SI
   Push  DI
   Push  ES
   Push  DS
   Mov   AX, DGROUP
   Mov   DS, AX
   Mov   SI, Struct3
   Jmp   C$ISR

C$PORT3 Endp

C$PORT4 Proc

   Push  AX
   Push  BX
   Push  CX
   Push  DX
   Push  SI
   Push  DI
   Push  ES
   Push  DS
   Mov   AX, DGROUP
   Mov   DS, AX
   Mov   SI, Struct4
   Jmp   C$ISR

C$PORT4 Endp

End
