;=============================================================================
;  Comprint.asm
;
;  ComPrint(OutStr$) Subroutine: Outputs a string to the comport
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;=============================================================================

;*****************************************************************************
;
; .001 - 9/15/90 - Fixed bug with CTS handshaking.
;
; .002 - 12/26/90 - Modified for near and far strings. XON/XOFF handshaking
;                   now handled internally.
;
; .003 - 2/6/91 - Added string length check and variable time out.
;
;*****************************************************************************

.Model Medium,Basic

.Data

   IFDEF QLB
      P$PDQErr EQU b$errnum            ;Use QB's error variable if making
      Extrn b$errnum:Word              ;a quicklibrary
   ELSE
      Extrn P$PDQErr:Word
   ENDIF

   PUBLIC C$PRINTTO
   C$PRINTTO   DW 90                   ;ComPrint time out (5 second default)
   StrLoc      DW 1                    ;Remembers position of string if
                                       ;a timeout occurs
.Code PDQComm_Text

   Include C_Struct.Inc                ;Defines common structure

   Extrn C$ENTRY:Near
   Extrn C$START:Near
   Extrn C$ELAPSED:Near

   IFDEF FS
      Extrn C$FSINFO:Proc
   ENDIF

COMPRINT Proc USES ES SI DI, Str:Ptr Word

   Call  C$ENTRY                       ;Setup SI and see if ISR is active
   Jc    Exit                          ;If not, exit with error 52

   Mov   BX, [PDQ_HandMeth]            ;Determine handshaking
   Cmp   BX, 1
   Jne   NoHand
   Mov   BL, 010h                      ;If RTS/CTS then make BL=10h
   Jmp   Short Cont1

NoHand:
   Xor   BL, BL                        ;else zero BL

Cont1:
   Push  BX                            ;Save BX
   Mov   BX, Str
   
IFDEF FS
   Call  C$FSINFO                      ;Get info on incoming string
ELSE
   Mov   CX, [BX]                      ;Do it manually for near strings
   Mov   AX, [BX+2]                    ;CX contains length
   Push  DS                            ;DX:AX points to string
   Pop   DX
ENDIF

   Pop   BX                            ;Restore BX
   Jcxz  Exit
   Mov   DI, AX
   Mov   ES, DX                        ;ES:DI points to string
   Cmp   CX, StrLoc                    ;Make sure StrLoc isn't > CX
   Jge   SameString                    ;It isn't so process normally
   Mov   StrLoc, 1                     ;Problem, so send whole string.

SameString:
   Sub   CX, StrLoc
   Inc   CX                            ;Adjust string in case only a partial
   Add   DI, StrLoc                    ;one went out last time
   Dec   DI
   
SendLoop:
   Call  C$WaitForHand                 ;Wait until its OK to send
   Or    AX, AX
   Jne   Error
   Mov   AL, ES:[DI]                   ;Put character in AL
   Mov   DX, [PDQ_Thr]                 ;Get address of the Xmit register
   Out   DX, AL                        ;Output character
   Inc   StrLoc
   Inc   DI
   Loop  SendLoop                      ;Continue until string is finished
   
AllDone:
   Mov   AX,1
   Mov   StrLoc, AX                    ;Reset StrLoc to 1

Exit:
   Ret

Error:
   Mov   Word Ptr [P$PDQErr], 24       ;If timeout then do error 24
   Jmp   Short Exit
   
COMPRINT Endp

C$WAITFORHAND Proc Near Uses ES CX

   Call  C$START
   Mov   DX, [PDQ_Lsr]                 ;Put address of LSR in DX
   
XmitLoop:
   Mov   AX, C$PRINTTO                 ;If 0 then no time out
   Or    AX, AX
   Jz    NoTO1                         
   Call  C$ELAPSED                     ;Get elapsed time
   Cmp   AX, C$PRINTTO                 ;See if time out has passed
   Jge   TimeOut                       ;If so, exit with timeout error

NoTO1:
   In    AL, DX
   And   AL, 020h                      ;Check on status of the line
   Jz    XmitLoop                      ;If Xmit register empty then continue
   Mov   DX, [PDQ_Msr]                 ;Put the address of the modem status
                                       ;register in DX
HandLoop:
   Mov   AX, C$PRINTTO
   Or    AX, AX
   Jz    NoTO2
   Call  C$ELAPSED                     ;Get elapsed time
   Cmp   AX, C$PRINTTO
   Jge   Timeout

NoTO2:
   Or    BL, BL
   Jz    XOff                          ;Skip if XOff or no handshaking used
   In    AL, DX
   And   AL, BL                        ;Get MSR data
   Cmp   AL, BL                        ;And it with handshaking mask
   Jne   HandLoop                      ;Wait until they are equal
   Xor   AX, AX                        ;Clear AX
   Jmp   Short HandEx

XOff:
   Cmp   Word Ptr[PDQ_XOff], 0         ;Loop until XOff flag is cleared
   Jne   HandLoop
   Xor   AX, AX

HandEx:
   Ret

TimeOut:
   Mov   AX,-1                         ;Put -1 into AX
   Jmp   Short HandEx                  ;And return

C$WAITFORHAND Endp

End
