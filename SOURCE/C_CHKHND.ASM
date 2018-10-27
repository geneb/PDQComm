;=============================================================================
;  C$Chkhnd.asm
;
;  C$CheckHand:   Internal routine to handle handshaking.
;
;  Copyright (c) 1990 Clearware Computing, By David Cleary
;=============================================================================

;*****************************************************************************
;
; .001 - 9/15/90 - Fixed a persistent bug in hardware handshaking.
;
;*****************************************************************************

.Model Medium, Basic

.Code PDQComm_Text

   Include C_Struct.Inc                ;Defines common structure

C$CheckHand Proc Near Uses AX

   Mov   AX, [PDQ_HandMeth]
   Or    AX, AX
   Jz    Exit                          ;If no handshaking, then exit
   Mov   BX, [PDQ_HandStat]
   Or    BX, BX
   Jz    Exit                          ;If handshake off, then exit
   Mov   BX, [PDQ_RecNum]              ;See if buffer is near empty
   Cmp   BX, [PDQ_NearEmpty]
   Jg    Exit                          ;No we aren't so exit
   Dec   AX                            ;See what type of handshake we are using
   Jz    CTS                           ;We have CTS handshaking

Xon:
   Mov   DX, [PDQ_Thr]                 ;Get UART's xmit register
   Mov   AL, 17                        ;Put XON into AL
   Out   DX, AL                        ;Send it out
   Jmp   Short ClearFlag

CTS:
   Mov   DX, [PDQ_Mcr]                 ;Get UART's modem control register
   In    AL, DX                        ;Input it
   Or    AL, 2                         ;Set bit #1
   Out   DX, AL                        ;And send it back out

ClearFlag:
   Xor   AX, AX
   Mov   [PDQ_HandStat], AX            ;Clear flag

Exit:
   Ret                                 ;All done

C$CheckHand Endp

End
