;=============================================================================
;	Compeek.asm
;
;	ComPeek$(NumBytes%) Function:	Returns a string from the receive buffer
;											without removing it.
;
;	Copyright (c) 1992 Clearware Computing, By David Cleary
;=============================================================================

.Model Medium,Basic

.Data

   IFDEF QLB
      P$PDQErr EQU b$errnum            ;Use QB's error variable if creating
      Extrn b$errnum:Word              ;a quicklibrary
   ELSE
      Extrn P$PDQErr:Word
   ENDIF 
   
   RetString   DD 0                    ;String descriptors
   ScrString   DD 0
   NulString   DD 0
   
.Code PDQComm_Text

   Include C_Struct.Inc                ;Defines common structure
   
IFDEF FS
   Extrn B$SACT:Proc
   Extrn STRINGASSIGN:Proc             ;Assigns fixed to variable string
   Extrn STRINGRELEASE:Proc            ;Deletes a string
ELSE
   STRINGASSIGN EQU <B$ASSN>
   STRINGRELEASE EQU <B$STDL>
   Extrn STRINGASSIGN:Proc             ;Assigns fixed to variable string
   Extrn STRINGRELEASE:Proc            ;Deletes a string
   Extrn B$SCAT:Proc
   Extrn B$SASS:Proc
ENDIF

   Extrn C$ENTRY:Near                  ;PDQComm entry routine


COMPEEK Proc Uses ES SI DI,NumBytes:Ptr Word

   Push  DS                            ;Set up return string as a null
   Lea   AX, NulString
   Push  AX
   Xor   BX, BX
   Push  BX
   Push  DS
   Lea   AX, RetString
   Push  AX
   Push  BX
   Call  STRINGASSIGN                  ;Null return string
  
   Call  C$ENTRY                       ;Setup SI and see if ISR is active
   Jc    Exit                          ;Exit with error if not

   Mov   AX, [PDQ_RecNum]              ;See how many characters in buffer
   Or    AX, AX
   Jnz   BufFull                       ;If there are chars, then process
   Mov   AX, 62
   Mov   P$PDQErr, AX                  ;If buffer empty, exit with error
   Jmp   Short Exit

BufFull:
   Mov   BX, NumBytes                  ;If more bytes are requested than
   Mov   CX, [BX]                      ;available, then adjust down
   Cmp   CX, 0
   Jle   Exit                          ;If no bytes requested, return a null
   Cmp   CX, AX                        ;string
   Jle   NoAdjust
   Mov   CX, AX                        ;CX contains number of bytes requested

NoAdjust:
   Mov   AX, [PDQ_RecOut]              ;See if buffer circles
   Add   AX, CX
   Cmp   AX, [PDQ_RecLength]
   Jle   NoCircle

   Mov   AX, [PDQ_RecLength]           ;Put the length of buffer in AX
   Sub   AX, [PDQ_RecOut]              ;Subtract the buffer pointer from it
   Sub   CX, AX                        ;And adjust CX to what's left
   Lea   DI, ScrString                 ;Put address of descriptor in DI
	Call	C$PEEKBUF
   Mov   AX, CX                        ;Put remainder in AX
   Lea   DI, RetString                 ;Put address of descriptor in DI
	Call	C$PEEKBUF

IFDEF FS                               ;Farstring Concatenation
   Push  DI
   Lea   AX, ScrString
   Push  AX
   Push  DI
   Call  B$SACT                        ;Concatenate return string to output
ELSE
   Lea   AX, ScrString                 ;Nearstring Concatenation
   Push  AX
   Push  DI
   Call  B$SCAT
   Push  AX
   Lea   AX, RetString
   Push  AX
   Call  B$SASS
ENDIF
   
   Lea   AX, ScrString
   Push  AX
   Call  STRINGRELEASE                 ;Deallocate our temp string
   Jmp   Short Exit                    ;We are all done
   
NoCircle:
   Mov   AX, CX
   Lea   DI, RetString                 ;Put address of descriptor in DI
	Call	C$PEEKBUF							 ;Get string

Exit:
   Lea   AX, RetString                 ;Return string
   Ret

COMPEEK Endp


C$PEEKBUF Proc Near Uses ES CX DI

;AX contains number of bytes requested
;DI contains the offset of the string descriptor

   Push  AX                            ;Save NumBytes requested
   Mov   BX, [PDQ_RBufSeg]             ;Push buffer segment
   Push  BX
   Mov   BX, [PDQ_RecOut]              ;offset
   Push  BX
   Push  AX                            ;and numbytes
   Push  DS                            ;Push tempstring's segment
   Push  DI                            ;and offset
   Xor   AX, AX                        ;Push a length of zero so B$ASSN
   Push  AX                            ;knows its a variable length string
   Call  STRINGASSIGN                  ;Assign the string
   Pop   CX                            ;Restore number of bytes requested

   Ret                                 ;Return with address of string in BX
C$PEEKBUF Endp

End
   
   
