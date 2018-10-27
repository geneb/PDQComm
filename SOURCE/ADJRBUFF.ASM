;=============================================================================
;  Adjrbuff.asm
;
;  AdjustRecBuffer(BuffSize%, Nempty%, Nfull%) Subroutine: Adjusts the size
;     of the receive buffer and also sets the nearempty and nearfull points.
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;=============================================================================

.Model Medium, Basic

.Data

   IFDEF QLB
      P$PDQErr EQU b$errnum            ;Use QB's error variable if making
      Extrn b$errnum:Word              ;a quicklibrary
      Ercd     EQU 5
   ELSE
      Extrn P$PDQErr:Word              ;Holds error code
      Ercd     EQU -1
   ENDIF

.Code PDQComm_Text

   Include C_Struct.Inc                ;Defines common structure

   Extrn C$ENTRY:Near
   Extrn FLUSHBUFFER:Proc
   Extrn B$SETM:Proc
   
ADJUSTRECBUFFER Proc, BuffSize:Ptr Word, NEmpty:Ptr Word, NFull:Ptr Word

;-----  Set up address of Comm structure in SI and check if port is open

   Call  C$ENTRY                       ;Set up SI and see if ISR is active
   Jc    Exit                          ;Exit with an error if not

;-----  Get size of requested buffer
   Mov   BX, BuffSize
   Mov   AX, [BX]
   Or    AX, AX
   Jz    NearPoints

;-----  Make it at least 128 bytes
   Cmp   AX, 128
   Jge   Cont
   Mov   AX, 128

Cont:
   Mov   [PDQ_RecLength], AX

;-----  Release old buffer
   Mov   AX, [PDQ_RBufSeg]
   Mov   ES, AX
   Mov   AH, 49h
   Int   21h

;-----  Adjust QB's memory
IFDEF QLB
   Mov   AX, 32800
   Xor   DX, DX
   Push  DX
   Push  AX
   Call  B$SETM
   Mov   AX, [PDQ_RecLength]
   Neg   AX                            ;Put in AX and make it negative
   Cwd                                 ;Convert it to a long
   Sub   AX, 32                        ;Allow for a little extra
   Push  DX
   Push  AX
   Call  B$SETM                        ;Push and call SETMEM
ENDIF

;-----  Create new buffer
   Mov   BX, [PDQ_RecLength]
   Mov   CL, 4
   Shr   BX, CL
   Inc   BX
   Mov   AH, 48h
   Int   21h
   Jnc   NoErr
   Mov   P$PDQErr, 7
   Jmp   Short Exit

NoErr:
   Mov   [PDQ_RBufSeg], AX

;-----  Do near points
NearPoints:
   Mov   BX, NEmpty
   Mov   AX, [BX]
   Cmp   AX, 0
   Jle   NearError
   Cmp   AX, [PDQ_RecLength]
   Jge   NearError
   Mov   [PDQ_NearEmpty], AX
   Mov   BX, NFull
   Mov   AX, [BX]
   Cmp   AX, 0
   Jle   NearError
   Cmp   AX, [PDQ_RecLength]
   Jge   NearError
   Mov   [PDQ_NearFull], AX
   Call  FlushBuffer

Exit:
   Ret

NearError:
   Mov   P$PDQErr, Ercd
   Jmp   Short Exit

ADJUSTRECBUFFER Endp

End
