;=============================================================================
;  Fifoenbl.asm
;
;  SetFIFO(TrigLev%) Subroutine: Enables FIFOs on the 16550A
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;============================================================================= 


.Model Medium,Basic

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
	Extrn UARTTYPE:Proc

SETFIFO Proc , TrigLev:Ptr Word

	Local Scratch:Word

;-----  Check for open port
	Call  C$ENTRY                       ;Setup SI and see if ISR is active
	Jc    Exit                          ;If not, exit with error 52

;-----  See if we have a 16550A
	Mov   AX, [PDQ_Thr]
	Mov   Scratch, AX                   ;Put base address of port in Scratch
	Lea   AX, Scratch
	Push  AX
	Call  UARTTYPE                      ;Call UARTTYPE to see what we have
	Cmp   AX, 3                         ;A 3 says we have a 16550
	Je    Cont

;-----  We don't
	Mov   P$PDQErr, Ercd
	Jmp   Short Exit
	
;-----  We do, so set FIFOs
Cont:
	Mov   DX, [PDQ_Iir]
	Mov   BX, TrigLev
	Mov   AX, [BX]                      ;Put TrigLev in AX
	Or    AX, AX                        ;0 means restore 16450 mode. UARTTYPE
	Jz    Exit                          ;did that for us, so we are done

	Mov   CL, 4
	Shl   AL, CL                        ;Shift triglev so bits 2 and 3 are
	And   AL, 0C0h                      ;at 6 and 7. Mask
	Or    AL, 1                         ;Set bit 1
	Out   DX, AL                        ;Write it to FIFO register

Exit:
	Ret

SETFIFO Endp

End
