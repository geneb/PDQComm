'=============================================================================
'  ASCIIXFR.BAS
'
'  ASCII file transfer routines
'
'  ASCIIReceive% Function: Receives a file
'
'  ASCIISend% Function:    Sends a file
'
'  Return Codes
'-------------------------------------------------------------------
'  0   - File sent successfully
'  1   - DOS file error
'  2   - Timeout Error
'  3   - Too many errors
'  4   - Receiver cancelled
'  5   - Transmitter cancelled
'
'  Copyright (c) 1991 Clearware Computing, By David Cleary
'=============================================================================

DEFINT A-Z

DECLARE SUB XStat (Text$)
DECLARE FUNCTION ASCIISend% (FileName$)
DECLARE FUNCTION ASCIIReceive% (FileName$)

'----- PDQComm Declares
DECLARE SUB ComPrint (Text$)
DECLARE SUB FlushBuffer ()
DECLARE FUNCTION ComInput$ (Bytes%)
DECLARE FUNCTION ComLoc% ()
DECLARE FUNCTION CheckSum$ (Data$)
DECLARE FUNCTION CRC16$ (Data$)

'-----  P.D.Q. Declares
DECLARE SUB Pause (Ticks%)
DECLARE FUNCTION PDQExist% (FileName$)
DECLARE FUNCTION PDQTimer& ()

FUNCTION ASCIIReceive% (FileName$) STATIC

'ASCII File Transfer Receive routine
'
'Return Codes
'-------------------------------------------------------------------
' 0   - File sent successfully
' 1   - DOS file error
' 2   - Timeout Error
' 3   - Too many errors
' 4   - Receiver cancelled
' 5   - Transmitter cancelled


'-----  Set up some needed variables
XEOF = 26                              'End of file
TimeOut = 540                          '30 second timeout
Buffer$ = SPACE$(128)
BPtr = 0
BytesRec& = 0

'-----  Open file and start receiving

    FileNum = FREEFILE
    IF PDQExist(FileName$) THEN KILL FileName$
    OPEN FileName$ FOR BINARY AS #FileNum
    IF ERR THEN
       CLOSE #FileNum
       ASCIIReceive = 1
       EXIT FUNCTION
    END IF

    XStat "Receiving " + FileName$ + "|using ASCII protocol"

'-----  Main reception loop
    DO
       IF ComLoc THEN
          Char$ = ComInput$(1)
          IF ASC(Char$) = XEOF THEN EXIT DO 'EOF means file transfer complete
          BPtr = BPtr + 1
          MID$(Buffer$, BPtr, 1) = Char$

          IF BPtr = 128 THEN                'When we have 128 characters
             PUT #FileNum, , Buffer$        '  write it
             BPtr = 0
             BytesRec& = BytesRec& + 128
             XStat "Received " + STR$(BytesRec&) + " bytes"
          END IF
          LastRec& = PDQTimer&
       END IF

    LOOP UNTIL PDQTimer& - LastRec& > TimeOut

'-----  Write last characters
    IF BPtr THEN
       Buffer$ = LEFT$(Buffer$, BPtr)
       PUT #FileNum, , Buffer$
       XStat "Received " + STR$(BytesRec&) + " bytes"
    END IF

'-----  Set exit code and close file
    IF PDQTimer& - LastRec& > TimeOut THEN
       ASCIIReceive = 2
    ELSE
       ASCIIReceive = 0
    END IF

    Buffer$ = ""
    XStat Buffer$
    CLOSE #FileNum

END FUNCTION

FUNCTION ASCIISend% (FileName$) STATIC

'ASCII File Transfer Send routine
'
'Return Codes
'-------------------------------------------------------------------
' 0   - File sent successfully
' 1   - DOS file error
' 2   - Timeout Error
' 3   - Too many errors
' 4   - Receiver cancelled
' 5   - Transmitter cancelled

'-----  Set up some needed variables
NumBytes& = 0                          'Bytes sent
TimeOut = 540                          '30 second timeout


'-----  Open file and start transfer
    IF PDQExist(FileName$) THEN
       FileNum = FREEFILE
       OPEN FileName$ FOR BINARY AS #FileNum
       XStat "Sending " + FileName$ + "|using ASCII protocol"
    ELSE
       ASCIISend = 1
       EXIT FUNCTION
    END IF

'-----  Main transmission loop
    DO
       Buffer$ = INPUT$(128, #FileNum)
       BytesSent& = BytesSent& + LEN(Buffer$)
       XStat "Sent " + STR$(BytesSent&) + " bytes"
       Retries = 0

'----- Print until complete
       DO
          ComPrint Buffer$
          IF ERR = 0 THEN EXIT DO
          Retries = Retries + 1
       LOOP UNTIL Retries > 10

'----- If receiver stopped us, then exit with error
       IF Retries > 10 THEN
          XStat "Receiver timed out"
          CLOSE #FileNum
          ASCIISend = 2
          Buffer$ = ""
          XStat Buffer$
          EXIT FUNCTION
       END IF

    LOOP UNTIL EOF(FileNum)

'-----  Send EOF to signal we are done and exit
    ComPrint CHR$(26)
    CLOSE #FileNum
    ASCIISend = 0
    Buffer$ = ""
    XStat Buffer$

END FUNCTION
