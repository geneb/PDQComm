;=============================================================================
;  GLStat.asm
;
;  GetLineStatus(Stat as LSType):  Returns the status of all lines.
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;============================================================================= 


.Model Medium,Basic

.Code PDQComm_Text

   Include C_Struct.Inc                ;Defines common structure

   Extrn C$Entry:Near

GetLineStatus Proc Uses SI, LStat:Ptr Word

   Call  C$Entry                       ;Set up SI and check if ISR active
   Jc    Exit                          ;If not, exit with error

   Mov   BX, LStat                     ;Put address of LStat in BX
   Mov   AH, 010h                      ;Put first bit mask in AH
   Mov   DX, [PDQ_Msr]                 ;Put address of UART MSR in DX
   In    AL, DX                        ;Load MSR into AL

CheckLoop:
   Xor   CX, CX                        ;Zero CX
   Test  AL, AH                        ;Test a bit
   Jz    NotActive                     
   Dec   CX                            ;If active, make CX -1
NotActive:
   Mov   [BX], CX                      ;Store in LStat
   Inc   BX                            ;Add 2 to BX to point at next
   Inc   BX                            ;element in LStat
   Shl   AH, 1                         ;Shift our mask
   Jnc   CheckLoop                     ;Continue until last 4 bits are done

Exit:
   Ret

GetLineStatus Endp

End
