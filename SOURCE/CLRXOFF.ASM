;=============================================================================
;	ClrXOff.asm
;
;	ClearXOff:	Subroutine that manually restarts the transmitter after a
;					XOff is received.
;					CALL ClearXOff
;
;	Copyright (c) 1992 Clearware Computing, By David Cleary
;=============================================================================

.Model Medium,Basic

.Code PDQComm_Text

   Include C_Struct.Inc                ;Defines common structure

   Extrn C$Entry:Near

ClearXOff Proc USES SI

   Call  C$Entry                       ;Setup SI and see if ISR is active
   Jc    Exit                          ;If not, exit with error

	Xor	AX, AX
	Mov	[PDQ_XOff], AX						;Clear XOff flag
   
Exit:
   Ret

ClearXOff EndP

End
