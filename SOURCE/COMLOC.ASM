;=============================================================================
;  Comloc.asm
;
;  ComLoc% Function: Returns number of characters in buffer
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;=============================================================================


.Model Medium,Basic

.Code PDQComm_Text 

	Include C_Struct.Inc                 ;Defines common structure
	
	Extrn C$Entry:Near

ComLoc Proc Uses SI

	Call  C$Entry                       ;Setup SI and see if ISR is active
	Jc    Exit                          ;If not, exit with error

	Mov   AX, [PDQ_RecNum]              ;Get number of characters in buffer
	
Exit:  
	Ret

ComLoc Endp

End
