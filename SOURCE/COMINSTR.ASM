;=============================================================================
;	Cominstr.asm
;
;	ComInstr%(Search$, Case%) Function: Searches the receive buffer for a string
;									  and returns its location.
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

	TempStr1 	DD 0
	TempStr2 	DD 0

.Code PDQComm_Text

   Include C_Struct.Inc                ;Defines common structure
   
IFDEF FS
   Extrn B$SACT:Proc
   Extrn B$SASS:Proc
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

	Extrn ComPeek:Proc
	Extrn ComLoc:Proc
	Extrn B$INS2:Proc
	Extrn B$UCAS:Proc

ComInstr Proc USES ES, Search:Ptr DWord, Case:Word

	LOCAL Temp:Word

	Mov	BX, Search							;Get address of Search descriptor
	Push	BX
	Lea	BX, TempStr1						;Address of our temp string descriptor
	Push	BX
	Call	B$SASS								;Do the assignment
	Cmp	Case, 0								;See if we want case sensitivity
	Jne	NoUCASE

	Lea	AX, TempStr1						;Get address of our search string
	Push	AX
	Call	B$UCAS								;Make it upper case
	Push	AX 									;Need to copy return to our temp string
	Lea	AX, TempStr1
	Push	AX
	Call	B$SASS								;Do string assignment

NoUCASE:
	Call	ComLoc								;Get number of characters in buffer
	Mov	Temp, AX
	Lea	AX, Temp
	Push	AX
	Call	ComPeek								;Get characters from buffer
	Push	AX
	Lea	AX, TempStr2
	Push	AX
	Call	B$SASS								;Assign it to our second temp string
	Cmp	Case, 0								;See if we want case sensitivity
	Jne	NoUCASE1

	Lea	AX, TempStr2						;Get address of our buffer	string
	Push	AX
	Call	B$UCAS								;Make it upper case
	Push	AX 									;Need to copy return to our temp string
	Lea	AX, TempStr2
	Push	AX
	Call	B$SASS								;Do string assignment

NoUCASE1:
	Lea	AX, TempStr2						;Get address of our source string
	Push	AX
	Lea	AX, TempStr1						;And our search string
	Push	AX
	Call	B$INS2								;Let INSTR$ do the work
	Push	AX 									;Save our answer
	Lea	AX, TempStr1						;Delete our temp strings
	Push	AX
	Call	StringRelease
	Lea	AX, TempStr2
	Push	AX
   Call  StringRelease
	Pop	AX 									;Restore answer
	Ret											;All done

ComInstr Endp
End
