'=============================================================================
'  XYMODEM.BAS
'
'  XModem and YModem file transfer routines
'
'  XModemReceive% Function: Receives a file
'
'  XModemSend% Function:    Sends a file
'
'  XModem1KReceive% Function: Receives a file
'
'  XModem1KSend% Function:    Sends a file
'
'  YModemReceive% Function: Receives a file
'
'  YModemSend% Function:    Sends a file
'
'  Return Codes
'-------------------------------------------------------------------
'  0   - File sent successfully
'  1   - DOS file error
'  2   - Timeout Error
'  3   - Too many errors
'  4   - Receiver cancelled
'  5   - Transmitter cancelled (you can cancel sending by pressing Ctrl-X)
'  6   - Nothing to transfer
'
'  Copyright (c) 1991, 1992 Clearware Computing, By David Cleary
'  XModem-1 and YModem Copyright (c) 1991, 1992 by Mike Sax
'=============================================================================

DEFINT A-Z

DECLARE SUB XStat (Text$)
DECLARE SUB XStat1 (Action%, Text$, Percent&, Colr%, Wid%)
DECLARE FUNCTION XModemSend% (FileName$)
DECLARE FUNCTION XModemReceive% (FileName$)
DECLARE FUNCTION YModemReceive% (FileName$)
DECLARE FUNCTION YModemGReceive% (FileName$)
DECLARE FUNCTION XYModemReceive% (FileName$, YModem%)
DECLARE FUNCTION XYModemSend% (FileName$, Variant%)
DECLARE FUNCTION XModem1KReceive% (FileName$)
DECLARE FUNCTION XModem1KSend% (FileName$)
DECLARE FUNCTION YModemSend% (FileName$)
DECLARE FUNCTION YModemGSend% (FileName$)

'----- PDQComm Declares
DECLARE SUB ComPrint (Text$)
DECLARE SUB FlushBuffer ()
DECLARE FUNCTION ComInput$ (Bytes%)
DECLARE FUNCTION ComLoc% ()
DECLARE FUNCTION Checksum$ (Data$)
DECLARE FUNCTION CRC16$ (Data$)

'-----  PDQ Declares
DECLARE SUB Pause (Ticks%)
DECLARE FUNCTION BIOSInkey% ()
DECLARE FUNCTION PDQExist% (FileName$)
DECLARE FUNCTION PDQTimer& ()
DECLARE FUNCTION PDQValL& (Work$)

FUNCTION XModem1KReceive (FileName$)
    ' XModem1K Receive is handled automatically by the
    ' generic XModem receive function
    XModem1KReceive = XYModemReceive(FileName$, 0)
END FUNCTION

FUNCTION XModem1KSend (FileName$)
    XModem1KSend = XYModemSend(FileName$, 1)
END FUNCTION

FUNCTION XModemReceive (FileName$)
    XModemReceive = XYModemReceive(FileName$, 0)
END FUNCTION

FUNCTION XModemSend (FileName$)
    XModemSend = XYModemSend(FileName$, 0)
END FUNCTION

FUNCTION XYModemReceive% (FileName$, YModem%) STATIC
                                                  
'XModem, XModem-CRC, XModem-1K and YModem File Transfer Receive routine
'
'Return Codes
'-------------------------------------------------------------------
' 0   - File sent successfully
' 1   - DOS file error
' 2   - Timeout Error
' 3   - Too many errors
' 4   - Receiver cancelled
' 5   - Transmitter cancelled
' 6   - Nothing to receive (Filename = "")
'
' Variant: 0=Xmodem 1=XModem-1K 2=YModem 3=YModem-G

'XModem or first YModem Packet
' [SOH] - [Blk Num] - [~Blk Num] - [128 DATA BYTES] - [CRC or Checksum]
'XModem 1K or YModem Packet
' [STX] - [Blk Num] - [~Blk Num] - [1024 DATA BYTES] - [CRC or Checksum]


'-----  Set up some needed variables
SOH = 1                                'Start of header of 128 byte block
STX = 2                                'Start of header of 1K block
EOT = 4                                'End of transmission
ACK = 6                                'Packet OK
NAK = 21                               'Packet not OK
CAN = 24                               'Cancel
C = 67                                 'CRC transfer
G = 71                                 'YModem-G
TimeOut = 36                           '2 second timeout
BytesSent& = 0
FileNum = -1
XStatOpen = 0

'-----  Open file and start receiving
   IF YModem < 2 THEN GOSUB OpenFile
   GOSUB PurgeBuffer

'-----  Try 10 times to start transfer
   CRCRec = -1
   FOR I = 1 TO 10
      IF YModem = 3 THEN
         ComPrint "G"
      ELSEIF CRCRec THEN
         ComPrint CHR$(C)
      ELSE
         ComPrint CHR$(NAK)
      END IF
      GOSUB GetSOH
      IF Ok THEN EXIT FOR
      IF I = 4 THEN CRCRec = 0
   NEXT

   IF I > 10 THEN
      XYModemReceive = 2
      IF FileNum <> -1 THEN CLOSE #FileNum
      EXIT FUNCTION
   END IF

   TimeStart& = PDQTimer&
   FileN$ = FileName$
   FPath = INSTR(FileN$, "\")
   DO WHILE FPath
      FileN$ = MID$(FileN$, FPath + 1)
      FPath = INSTR(FileN$, "\")
   LOOP

'-----  YModem adds a block 0
   IF YModem THEN
      CurBlock = 0
      FirstBlock = -1
   ELSE
      CurBlock = 1
   END IF
   Errors = 0
   IF YModem THEN
      'Do nothing
   ELSEIF CRCRec THEN
      'XStat "Receiving " + FileN$ + "|by XMODEM-CRC" + STR$(BlockSize)
      XStat1 1, "Receiving " + FileN$ + "|by XMODEM-CRC" + STR$(BlockSize), 0, 112, 40
      XStatOpen = -1
   ELSE
      'XStat "Receiving " + FileN$ + "|by XMODEM"
      XStat1 1, "Receiving " + FileN$ + "|by XMODEM" + STR$(BlockSize), 0, 112, 40
      XStatOpen = -1
   END IF

'-----  Main Reception Loop
   DO
      GOSUB GetHeader                  'Get packet header
      IF NOT (Ok) THEN
         'XStat "Header Error Block " + STR$(CurBlock)
         XStat1 2, "Header Error Block " + STR$(CurBlock), BytesSent&, 112, 40
         GOSUB NakIt
         Errors = Errors + 1
      ELSE
         GOSUB GetDataBlock            'Get 128/1024 data bytes
         IF NOT (Ok) THEN
            'XStat "Data Error Block " + STR$(CurBlock)
            XStat1 2, "Data Error Block " + STR$(CurBlock), BytesSent&, 112, 40
            GOSUB NakIt
            Errors = Errors + 1
            GOTO TryAgain
         END IF

         GOSUB GetCheck                'Get CRC or checksum
         IF NOT (Ok) THEN
            'XStat "Check Error Block " + STR$(CurBlock)
            XStat1 2, "Check Error Block " + STR$(CurBlock), BytesSent&, 112, 40
            GOSUB NakIt
            Errors = Errors + 1
            GOTO TryAgain
         END IF

         IF CRCRec THEN
            OurCheck$ = CRC16$(DataBlock$)
         ELSE
            OurCheck$ = Checksum$(DataBlock$)
         END IF

'-----  See if our data is correct
         IF OurCheck$ <> DataCheck$ THEN
           'XStat "CheckSum Error Block " + STR$(CurBlock)
            XStat1 2, "CheckSum Error Block " + STR$(CurBlock), BytesSent&, 112, 40
            GOSUB NakIt
            Errors = Errors + 1
            GOTO TryAgain
         ELSE
            IF Block = (CurBlock AND &HFF) THEN
               IF YModem >= 2 AND FirstBlock THEN
                  FirstBlock = 0
                  IF YModem = 2 THEN ComPrint CHR$(ACK)
                  NameLen = INSTR(DataBlock$, CHR$(0)) - 1
                  IF NameLen < 0 THEN NameLen = 0
                  IF NameLen = 0 THEN
                     XYModemReceive = 6              ' Nothing to receive
                     'GOSUB PurgeBuffer
                     'IF XStatOpen THEN XStat ""
                     IF XStatOpen THEN XStat1 3, "", 0, 0, 0
                     EXIT FUNCTION
                  END IF
                  IF YModem = 2 THEN ComPrint CHR$(C) ELSE ComPrint CHR$(G)
                  IF FileName$ = "" THEN    ' if filename wasn't overridden
                     FileName$ = LEFT$(DataBlock$, NameLen)
                  END IF
                  FileLen& = PDQValL&(MID$(DataBlock$, NameLen + 2, 10))
                  GOSUB OpenFile
                  'XStat "Receiving " + FileName$ + " by YMODEM|" + STR$(FileLen& \ 1024 + 1) + " Y Blocks"
                  XStat1 1, "Receiving " + FileName$ + " by YMODEM|" + STR$(FileLen& \ 1024 + 1) + " Y Blocks", FileLen&, 112, 40
                  XStatOpen = -1
               ELSE
                  IF YModem < 3 THEN ComPrint CHR$(ACK) '---+ comment out this line
                  BytesSent& = BytesSent& + BlockSize   '   |
                  IF YModem > 1 AND BytesSent& > FileLen& AND FileLen& > 0 THEN
                     DataBlock$ = LEFT$(DataBlock$, BlockSize - (BytesSent& - FileLen&))
                     BytesSent& = FileLen&              '   |
                  END IF                                '   |
                  IF FileNum > 0 THEN PUT #FileNum, , DataBlock$
                     'XStat "Block " + STR$(CurBlock) + " Received"
                     XStat1 2, "Block " + STR$(CurBlock) + " Received", BytesSent&, 112, 40
               END IF                                   '   |
               'IF YModem < 3 THEN ComPrint CHR$(ACK)   '<--+ and enable this if you get
               CurBlock = CurBlock + 1                  '     errors during disk writes
            ELSE
               'XStat "Blocknumber incorrect " + STR$(CurBlock)
               XStat1 2, "Blocknumber incorrect " + STR$(CurBlock), BytesSent&, 112, 40
               GOSUB NakIt
               Errors = Errors + 1
               GOTO TryAgain
            END IF
            Errors = 0
         END IF
      END IF

TryAgain:
      IF Errors > 10 THEN
         ComPrint STRING$(8, CAN) + STRING$(8, 8)
         FlushBuffer
         IF FileNum > 0 THEN CLOSE FileNum
         'IF XStatOpen THEN XStat ""
         IF XStatOpen THEN XStat1 3, "", 0, 0, 0
         XYModemReceive = 3
         EXIT FUNCTION
      END IF

'-----  Start Of Header character
      GOSUB GetSOH
      IF NOT (Ok) THEN
         IF Char = CAN THEN            'Receiver cancel
            CLOSE #FileNum
            'IF XStatOpen THEN XStat ""
            IF XStatOpen THEN XStat1 3, "", 0, 0, 0
            XYModemReceive = 5
            EXIT FUNCTION
         ELSEIF Char = EOT THEN        'All done
            CLOSE #FileNum
            ComPrint CHR$(ACK)
            TimeEnd& = PDQTimer&
            IF TimeEnd& < TimeStart& THEN TimeEnd& = TimeEnd& + 1573039
            Elapsed& = (TimeEnd& - TimeStart&) \ 18     'EW 11-13-96
            IF Elapsed& = 0 THEN Elapsed& = 1           'EW 11-13-96
            CharsPerSec = BytesSent& \ Elapsed&         'EW 11-13-96
            'XStat "Transfer Complete" + STR$(CharsPerSec) + " Chars/Sec"
            XStat1 2, "Transfer Complete" + STR$(CharsPerSec) + " Chars/Sec", BytesSent&, 112, 40
            Pause 36
            'IF XStatOpen THEN XStat ""
            IF XStatOpen THEN XStat1 3, "", 0, 0, 0
            XYModemReceive = 0
            EXIT FUNCTION
         ELSE
            'XStat "SOH Error Block " + STR$(CurBlock) + ":" + STR$(Char)
            XStat1 2, "SOH Error Block " + STR$(CurBlock) + ":" + STR$(Char), BytesSent&, 112, 40
            GOSUB NakIt
            Errors = Errors + 1
            GOTO TryAgain
         END IF
      END IF
      IF BIOSInkey = CAN THEN EXIT DO   'CTRL-X aborts transfer
   LOOP

'-----  Dump out of transfer
AbortXYModemReceive:
   XYModemReceive = 4              ' Receiver cancelled
   ComPrint STRING$(8, CAN) + STRING$(8, 8)
   FlushBuffer
   'XStat "Transfer aborted!!!!"
   XStat1 2, "Transfer aborted!!!!", BytesSent&, 112, 40
   IF FileNum > 0 THEN CLOSE #FileNum
   Pause 36
   'XStat ""
   XStat1 3, "", 0, 0, 0
   EXIT FUNCTION

'----- Purge Buffer Sub
PurgeBuffer:
   Start& = PDQTimer&
   Ok = ComLoc%
   DO
      IF Ok <> ComLoc% THEN
         Ok = ComLoc%
         Start& = PDQTimer&
      END IF
   LOOP UNTIL PDQTimer& - Start& > TimeOut
   FlushBuffer
RETURN

'-----  NakIt Sub
NakIt:
   IF BIOSInkey = CAN THEN GOTO AbortXYModemReceive
   IF YModem = 3 THEN
      Errors = 11
   ELSE
      GOSUB PurgeBuffer
      ComPrint CHR$(NAK)
   END IF
RETURN

'-----  Get SOH Sub
GetSOH:
   Ok = 0
   Char = Ok
   Start& = PDQTimer&
   BlockSize = 128
   DO
   LOOP UNTIL ComLoc% > 0 OR PDQTimer& - Start& > TimeOut * 5
   IF ComLoc% THEN
      Byte$ = ComInput$(1)
      Char = ASC(Byte$)
      IF Char = SOH THEN Ok = -1: BlockSize = 128
      IF Char = STX THEN Ok = -1: BlockSize = 1024
   END IF
RETURN

'-----  Get Header Sub
GetHeader:
   Ok = 0
   Start& = PDQTimer&
   DO
   LOOP UNTIL ComLoc% >= 2 OR PDQTimer& - Start& > TimeOut
   IF ComLoc% >= 2 THEN
      Block = ASC(ComInput$(1))
      NotBlock = ASC(ComInput$(1))
      IF NotBlock = 255 - Block AND (Block = (CurBlock AND &HFF) OR Block = (CurBlock AND &HFF) - 1) THEN Ok = -1
   END IF
RETURN

'-----  Get Data Sub
GetDataBlock:
   Ok = 0
   Start& = PDQTimer&
   DO
   LOOP UNTIL ComLoc% >= BlockSize OR PDQTimer& - Start& > TimeOut * (BlockSize \ 128)
   IF ComLoc% >= BlockSize THEN
      DataBlock$ = ComInput$(BlockSize)
      Ok = -1
   END IF
RETURN

'-----  Get Check Sub
GetCheck:
   Ok = 0
   Start& = PDQTimer&
   IF CRCRec THEN Char = 2 ELSE Char = 1
   DO
   LOOP UNTIL ComLoc% >= Char OR PDQTimer& - Start& > TimeOut
   IF ComLoc% >= Char THEN
      DataCheck$ = ComInput$(Char)
      Ok = -1
   END IF
RETURN

OpenFile:
   IF FileName$ = "" THEN
      XYModemReceive = 6
      EXIT FUNCTION
   END IF
   FileNum = FREEFILE
   IF PDQExist(FileName$) THEN KILL FileName$
   OPEN FileName$ FOR BINARY AS #FileNum
   IF ERR THEN
      CLOSE #FileNum
      XYModemReceive = 1
      'IF XStatOpen THEN XStat ""
      IF XStatOpen THEN XStat1 3, "", 0, 0, 0
      EXIT FUNCTION
   END IF
RETURN

END FUNCTION

FUNCTION XYModemSend% (FileName$, Variant) STATIC

'XModem, XModem-CRC, XModem 1K and YModem File Transfer Send routine
'
'Return Codes
'-------------------------------------------------------------------
' 0   - File sent successfully
' 1   - DOS file error
' 2   - Timeout Error
' 3   - Too many errors
' 4   - Receiver cancelled
' 5   - Transmitter cancelled
'
' Variant: 0=Xmodem 1=XModem-1K 2=YModem 3=YModem-G

'-----  Set up some needed variables

SOH = 1                                'Start of header of 128 block
STX = 2                                'Start of header of 1024 block
EOT = 4                                'End of transmission
ACK = 6                                'Packet OK
NAK = 21                               'Packet not OK
CAN = 24                               'Cancel
C = 67                                 'CRC transfer
G = 71                                 'YModem-G transfer
TimeOut = 1080                         '60 second timeout
XStatOpen = 0

'----- Flush all buffers before we start...
'FlushBuffer

'-----  Open file and start xfer
IF Variant > 0 THEN BlockSize = 1024 ELSE BlockSize = 128
IF LEN(FileName$) = 0 THEN
   FileNum = -1
   FileLen& = 0
   NumBlocks = 0
ELSEIF PDQExist%(FileName$) THEN
   FileNum = FREEFILE
   OPEN FileName$ FOR BINARY AS #FileNum
   FileLen& = LOF(FileNum)
   NumBlocks = (FileLen& + BlockSize - 1) \ BlockSize
ELSE
   XYModemSend = 1
   ComPrint STRING$(8, CAN) + STRING$(5, 8)
   EXIT FUNCTION
END IF

'-----  Wait for receiver to signal OK
Valid$ = CHR$(NAK) + CHR$(CAN) + "C" + "G"   'List of valid characters
GOSUB XSendChar

'-----  No valid response from receiver
IF TOut THEN GOTO RecTimeOut

'-----  Receiver canceled
IF Char = CAN THEN GOTO RecCanceled

'-----  Transmitter cancelled
IF Char = NAK THEN                  'NAK means use checksum
   CRCSend = 0
   By$ = "Checksum"
ELSE
   CRCSend = -1                     'While C means use CRC
   By$ = "CRC"
END IF

IF Variant >= 2 THEN
   Block = 0
   FirstBlock = 1
ELSE
   Block = 1
END IF
BytesSent& = 0
Done = 0
Valid$ = CHR$(ACK) + CHR$(NAK) + CHR$(CAN)

'-----  XStat is the transfer status routine.
FileN$ = FileName$
FPath = INSTR(FileN$, "\")
DO WHILE FPath
   FileN$ = MID$(FileN$, FPath + 1)
   FPath = INSTR(FileN$, "\")
LOOP

Stat$ = "Sending " + FileN$ + " by|"
IF Variant < 2 THEN
   Stat$ = Stat$ + "XModem " + By$ + STR$(NumBlocks) + " Blocks"
ELSEIF Variant = 2 THEN
   Stat$ = Stat$ + "YModem " + STR$(NumBlocks) + " X-Blocks"
ELSE
   Stat$ = Stat$ + "YModem-G" + STR$(NumBlocks) + " X-Blocks"
END IF

'-----  Do we have a valid filename?
IF FileNum > 0 THEN
   XStatOpen = -1
    'XStat Stat$
    XStat1 1, Stat$, FileLen&, 112, 40
END IF
TimeStart& = PDQTimer&
'-----  Main processing loop
DO

'-----  Get data
   IF Variant >= 2 AND FirstBlock THEN
      BlockSize = 128
      GOSUB FillBlock0
   ELSE
      IF Variant > 0 THEN BlockSize = 1024 ELSE BlockSize = 128
      IF FileLen& - BytesSent& < 1024 AND Variant >= 2 THEN BlockSize = 128
      Buffer$ = INPUT$(BlockSize, #FileNum)
      BytesSent& = BytesSent& + BlockSize
   END IF

'-----  Last block of data
   IF BytesSent& >= FileLen& THEN
      Done = -1
      IF BytesSent& > FileLen& THEN
         Buffer$ = Buffer$ + STRING$(BytesSent& - FileLen&, 26)
         BytesSent& = FileLen&          'added 4-30-96
      END IF
   END IF

'-----  Calculate correct check code
   IF CRCSend THEN
      Check$ = CRC16$(Buffer$)
   ELSE
      Check$ = Checksum$(Buffer$)
   END IF

'-----  Main Xmit Loop
   Errors = 0
   DO
      IF BlockSize = 1024 THEN Header$ = CHR$(STX) ELSE Header$ = CHR$(SOH)
      Header$ = Header$ + CHR$(Block AND &HFF) + CHR$(&HFF - (Block AND &HFF))
      ComPrint Header$
      ComPrint Buffer$                 'Send Data
      ComPrint Check$                  'Send Checksum
      IF BIOSInkey = CAN THEN GOTO XmitCanceled

      IF FirstBlock THEN
         GOSUB YSendChar
      ELSEIF Variant < 3 THEN
         GOSUB XSendChar
      ELSEIF ComLoc THEN
         Byte$ = ComInput$(1)
         IF LEN(Byte$) THEN Char = ASC(Byte$)
      END IF

      IF TOut THEN GOTO RecTimeOut     'Receiver time out - Xfer aborted

'-----  Transmitter canceled
      IF Char = CAN THEN
         GOSUB XSendChar
         IF TOut THEN GOTO RecTimeOut
         IF Char = CAN THEN GOTO RecCanceled
      END IF

      IF Char = NAK THEN
         Errors = Errors + 1
         FlushBuffer
            'XStat "Checksum Error Block " + STR$(Block)
            XStat1 2, "Checksum Error Block " + STR$(Block), BytesSent&, 112, 40
            IF Errors = 10 THEN GOTO ManyErrs       '10 errors means quit
      ELSE
         EXIT DO
      END IF

   LOOP

   IF FileName$ = "" THEN
        'IF XStatOpen THEN XStat ""
        IF XStatOpen THEN XStat1 3, "", 0, 0, 0
        XYModem = 0
      EXIT FUNCTION
   END IF

    'XStat "Sent Block " + STR$(Block)
    XStat1 2, "Sent Block " + STR$(Block), BytesSent&, 112, 40
    FirstBlock = 0
   Block = Block + 1
LOOP UNTIL Done

'-----  Send EOT

Errors = 0
DO
   ComPrint CHR$(EOT)
   GOSUB XSendChar
   IF Char = ACK THEN EXIT DO       'An ACK to an EOT means we are all done
    'XStat "EOT Not Acknowledge"
    XStat1 2, "EOT Not Acknowledge", BytesSent&, 112, 40
    Errors = Errors + 1
   IF Errors = 10 THEN GOTO ManyErrs
LOOP

TimeEnd& = PDQTimer&
IF TimeEnd& < TimeStart& THEN TimeEnd& = TimeEnd& + 1573039
Elapsed& = (TimeEnd& - TimeStart&) \ 18     'EW 11-13-96
IF Elapsed& = 0 THEN Elapsed& = 1           'EW 11-13-96
CharsPerSec = BytesSent& \ Elapsed&         'EW 11-13-96
'XStat "Transfer Complete" + STR$(CharsPerSec) + " Chars/Sec"
XStat1 2, "Transfer Complete" + STR$(CharsPerSec) + " Chars/Sec", BytesSent&, 112, 40
Pause 36
'IF XStatOpen THEN XStat ""
IF XStatOpen THEN XStat1 3, "", 0, 0, 0
IF FileNum THEN CLOSE #FileNum
XYModemSend = 0                      'Signal success
EXIT FUNCTION

RecTimeOut:
   CLOSE #FileNum
    'IF XStatOpen THEN XStat ""
    IF XStatOpen THEN XStat1 3, "", 0, 0, 0
    XYModemSend = 2
   EXIT FUNCTION

ManyErrs:
   ComPrint STRING$(8, CAN) + STRING$(5, 8)
   CLOSE #FileNum
    'IF XStatOpen THEN XStat ""
    IF XStatOpen THEN XStat1 3, "", 0, 0, 0
    XYModemSend = 3
   EXIT FUNCTION

RecCanceled:
   CLOSE #FileNum
    'IF XStatOpen THEN XStat ""
    IF XStatOpen THEN XStat1 3, "", 0, 0, 0
    XYModemSend = 4
   EXIT FUNCTION

XmitCanceled:
   ComPrint STRING$(8, CAN) + STRING$(5, 8)
   CLOSE #FileNum
    'IF XStatOpen THEN XStat ""
    IF XStatOpen THEN XStat1 3, "", 0, 0, 0
    XYModemSend = 5
   EXIT FUNCTION

'-----  Receiver response sub
XSendChar:
   Start& = PDQTimer&
   Char = 0
   TOut = 0
   DO
      IF ComLoc% THEN
         Byte$ = ComInput$(1)
         IF INSTR(Valid$, Byte$) THEN
            Char = ASC(Byte$)
         END IF
      END IF
      Elapsed& = PDQTimer& - Start&
   LOOP UNTIL Char > 0 OR Elapsed& > TimeOut
   IF Char = 0 THEN TOut = -1
RETURN

YSendChar:
   Start& = PDQTimer&
   Char = 0
   TOut = 0
   DO
      IF ComLoc% THEN
         Byte$ = ComInput$(1)
         Char = ASC(Byte$)
      END IF
      Elapsed& = PDQTimer& - Start&
   LOOP UNTIL Char > 0 OR Elapsed& > TimeOut
   IF Char = 0 THEN TOut = -1
RETURN

FillBlock0:
   IF FileName$ = "" AND Variant >= 2 THEN   ' YModem end batch
      Buffer$ = STRING$(BlockSize, 0)
   ELSE
      Buffer$ = LTRIM$(RTRIM$(FileN$)) + CHR$(0) + LTRIM$(STR$(FileLen&))
      Buffer$ = Buffer$ + STRING$(BlockSize - LEN(Buffer$), 0)
   END IF
RETURN

END FUNCTION

FUNCTION YModemGReceive% (FileName$)

   YModemGReceive = XYModemReceive(FileName$, 3)

END FUNCTION

FUNCTION YModemGSend% (FileName$)
    YModemGSend = XYModemSend(FileName$, 3)
END FUNCTION

FUNCTION YModemReceive% (FileName$)
    ' If Filename$ is blank, the sender's proposed name
    ' will be used
    YModemReceive = XYModemReceive%(FileName$, 2)
END FUNCTION

FUNCTION YModemSend (FileName$)
    YModemSend = XYModemSend(FileName$, 2)
END FUNCTION

