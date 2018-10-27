;=============================================================================
;  Comlinp.asm
;
;  ComLineInput(Innstr$,Timeout%) Subroutine:   Line Input routine for Comport
;
;  Copyright (c) 1990, 1991 Clearware Computing, By David Cleary
;=============================================================================

;*****************************************************************************
;
; .001 - 9/21/90 - Rewrote entirely due to some weird far string stuff.
;
; .002 - 12/26/90 - Modified for near and far strings. If TIMEOUT% = 0, will
;                   never time out.
;
; .003 - 5/1/91 - Changed timeout to .5 sec in linefeed check.
;
; .004 - 10/6/91 - Did not set error 62 when buffer was full.
;
;*****************************************************************************

.Model Medium,Basic

.Data

   IFDEF QLB
      P$PDQErr EQU b$errnum            ;Use QB's error variable if making
      Extrn b$errnum:Word              ;a quick library
   ELSE
      Extrn P$PDQErr:Word              ;Holds error code
   ENDIF

   NulString   DW 0                    ;Null string descriptor

.Code PDQComm_Text

   Include C_Struct.Inc                ;Defines common structure


IFDEF FS
   Extrn C$FSINFO:Proc
   Extrn STRINGASSIGN:Proc             ;Assigns fixed to variable string
   Extrn STRINGRELEASE:Proc            ;Deletes a string
ELSE
   STRINGASSIGN EQU <B$ASSN>
   Extrn STRINGASSIGN:Proc             ;Assigns fixed to variable string
ENDIF

   Extrn C$CHECKHAND:Near              ;Checks handshaking
   Extrn C$ENTRY:Near                  ;PDQComm entry routine
   Extrn C$START:Near                  ;Timer routines
   Extrn C$ELAPSED:Near

COMLINEINPUT Proc Uses SI DI ES, String:Ptr Word, TimeOut:Ptr Word

   Local TOut:Word, Buffer[256]:Byte
   
   Call  C$ENTRY                       ;Setup SI and see if ISR is active
   Jnc   Cont                          ;Exit with error if not
   Jmp   Exit

Cont:
   Mov   BX, TimeOut                   ;Calculate time out in 1/18th's
   Mov   AX, [BX]                      ;of a second
   Mov   CL, 4
   Shl   AX, CL                        ;Multiply Timeout by 16 (close enough)
   Mov   TOut, AX                      ;and save it
   Call  C$START                       ;Start timer
   Lea   AX, Buffer
   Mov   DI, AX                        ;DS:DI now points to our buffer
   Mov   BX, [PDQ_RBufSeg]
   Mov   ES, BX
   Mov   BX, [PDQ_RecOut]              ;ES:BX points to com buffer
   Mov   CX, 256                       ;Max line length
   
LineLoop:
   Mov   AX, [PDQ_RecNum]              ;See if characters are in buffer
   Or    AX, AX
   Jne   BufFull                       ;There are characters so get them
   Cmp   TOut, 0
   Je    LineLoop                      ;No timeout
   Call  C$ELAPSED
   Cmp   AX, TOut                      ;No characters so see if we timed out
   Jle   LineLoop                      ;We did timeout. Exit with what we
   Jmp   Short TError                  ;have and a timeout error

BufFull:
   Mov   AL, ES:[BX]                   ;Get character from buffer
   Dec   Word Ptr [PDQ_RecNum]         ;Decrement number of characters in buf
   Inc   BX                            ;Inc buffer pointer
   Cmp   BX, [PDQ_RecLength]           ;Check for wrap
   Jl    NoWrap
   Xor   BX, BX                        ;We wrapped so zero RecOut
   
NoWrap:
   Mov   [PDQ_RecOut], BX              ;Store new value
   Cmp   AL, 13                        ;See if its a CR
   Je    AllDone                       ;It is so we are all done
   Mov   Byte Ptr[DI], AL              ;Save it in new string
   Inc   DI                            ;Point to next position
   Loop  LineLoop                      ;Loop while CX > 0

   Mov   Word Ptr [P$PDQErr], 62       ;We fell thru so set error code
   Jmp   Short NoLF                    ;And don't check for LF character
   
AllDone:
   Call  C$START                       ;Start a new timeout period

LFLoop:
   Mov   AX, [PDQ_RecNum]              ;See if anything in buffer
   Or    AX, AX
   Jne   ChkLF                         ;Continue checking until Timeout
   Call  C$ELAPSED
   Cmp   AX, 9                         ;Use 1/2 second timeout
   Jg    NoLF
   Jmp   Short LFLoop
   
ChkLF:   
   Mov   AL, ES:[BX]                   ;See if character is a LF
   Cmp   AL, 10
   Jne   NoLF
   Dec   Word Ptr [PDQ_RecNum]         ;Just change RecNum and RecOut to
   Inc   BX                            ;reflect removing it from buffer
   Cmp   BX, [PDQ_RecLength]
   Jl    NoWrap2
   Xor   BX, BX
   
NoWrap2:
   Mov   [PDQ_RecOut], BX              ;Save new RecOut
   
NoLF:
   Push  DS                            ;Push Data segment
   Mov   AX, 256
   Sub   AX, CX                        ;This is the length of the string
   Jz    DoNull
   Lea   CX, Buffer
   Push  CX
   Push  AX

DoString:
   Push  DS
   Push  String
   Xor   AX, AX
   Push  AX
   Call  STRINGASSIGN                  ;Assign it to the passed in string
   
Exit:
   Call  C$CHECKHAND
   Ret                                 ;All done

TError:
   Mov   Word Ptr [P$PDQErr], 24       ;Set error 24
   Jmp   Short NoLF                    ;and return what is left

DoNull:
   Lea   AX, NulString                 ;Push address of null descriptor
   Push  AX
   Xor   AX, AX
   Push  AX                            ;Push 0 for length
   Jmp   Short DoString
   
COMLINEINPUT Endp

End
   
   
