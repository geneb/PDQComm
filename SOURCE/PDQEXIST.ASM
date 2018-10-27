;********** PDQEXIST.ASM - determines if the named file/file spec is present

;Copyright (c) 1989 Ethan Winer
;BC7 conversion 3/90 J. Munro
;Modified for near and far strings 12/90 D.Cleary

;Syntax - There = PDQExist%(FSpec$)
;
;  Where FSpec$ holds the file specification, and There receives -1 if it
;  was there, or 0 if it wasn't.


.Model Medium, Basic
.Data
   IFDEF QLB
      P$PDQErr EQU b$errnum            ;Use QB's error variable if making
      Extrn b$errnum:Word              ;a quicklibrary
   ELSE
      Extrn P$PDQErr:Word
   ENDIF

.Code

IFDEF FS
    Extrn STRINGADDRESS:Proc  ;these are internal BASIC 7 routines
    Extrn STRINGLENGTH:Proc
ENDIF

PDQEXIST Proc Uses ES, FSpec:Word

    Local Buffer[80]:Byte ;copy the file name here to add a CHR$(0)
    Local DTA[44]:Byte    ;this holds the DTA

    Lea  DX,DTA           ;put address of DTA into DS:DX for set DTA service
    Mov  AH,1Ah           ;set DTA service - creates space for a file name
    Int  21h              ;call DOS

    Mov  AX,FSpec         ;get the address for the file name or specification
    Lea  DX,Buffer        ;get the address for the start of the buffer

;-- This code was extracted from ZEROFILE.ASM because we don't want to call
;   P$FreeTemp (added to ZEROFILE.ASM 3-6-90) when PDQExist is in a Quick Lib.
;
    Cld                    ;all string moves forward
    Mov  DI,DX             ;copy the buffer address into DI
    Mov  SI,AX             ;get the address for FileName$ descriptor
    Push DS                ;save DS

IFDEF FS
    Push ES                ;and ES
    Push SI                ;push FileName$ descriptor
    Call STRINGADDRESS     ;get address
    Pop  ES                ;retrieve ES
    Push DX                ;save segment of string data
    Push SI                ;push filename descriptor yet again
    Mov  SI,AX             ;put string address into SI
    Call STRINGLENGTH      ;get its length
    Mov  CX,AX             ;put its length into CX
    Pop  DX                ;now DS:SI points to the file name
    Push DS                ;ensure that ES = DS for Movsb below
    Mov  DS,DX             ;and that DS = string segment
    Pop  ES                ;it's up to our caller to save registers if needed
ELSE
    Mov  CX,[SI]
    Mov  SI,[SI+2]
    Push DS
    Pop  ES
ENDIF

    Mov  DX,DI             ;retread DX for Int below, DS:DX points at file
    Rep  Movsb             ;copy the name to the caller's local stack buffer
    Mov  ES:[DI],CL        ;tack on the zero byte

IFDEF FS    
    Push ES                ;put DS back on track
    Pop  DS
ENDIF

;-- end of extracted code (really irrelevant in this BASIC 7 version)

    Mov  P$PDQErr,CX      ;clear any previous errors (CX is conveniently 0)
    Mov  BX,CX            ;assume no matching files for now

    Mov  CL,00100111b     ;and put the attribute for all files into CL
    Mov  AH,4Eh           ;find first matching file name service
    Int  21h              ;call DOS
    Jc   Exit             ;we were right earlier, it's not there
    Dec  BX               ;it is there, decrement BX to -1 to show that

Exit:
    Mov  AX,BX            ;leave the function output in AX
    Ret

PDQEXIST Endp
End
