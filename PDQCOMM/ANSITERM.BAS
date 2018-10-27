'=============================================================================
'  ANSITERM.BAS
'
'  Terminal program with ANSI emulation and X/YModem file transfer.
'
'  Copyright (c) 1991, 1992 Clearware Computing, By David Cleary
'
'  To compile this program using QB 4.5 do the following.  Replace the
'  COMMQB4 libary name at the end of the link line as needed when using
'  other versions of BASIC.
'
'  Compile: BC /O AnsiTerm;
'  Link:    LINK /EX/PACKC/F AnsiTerm + AnsiDisp + FileSpec + XYmodem +
'           XStat1, , NUL, QB COMMQB4;
'=============================================================================

DEFINT A-Z

'$INCLUDE: 'CommDecl.Bas'              'PDQComm Declarations
'$INCLUDE: 'Term.Bi'                   'Both of these are needed for
'$INCLUDE: 'Ansi.Bi'                   '  ANSI emulation

' BASIC Declares
DECLARE FUNCTION GetFileSpec$ ()
DECLARE SUB ReadDialDir (FileName$, Numbers$())
DECLARE SUB BIOSInput (Work$, Attr%)

'-------- Initialize some variables

   DIM DialDir$(1 TO 10)

   One = 1                             'Saves a few bytes to declare
   Bottom = 25                         '  these as variables instead of
   Norm = 7                            '  constants
   Reverse = 112
   Space = 32
   Reset$ = "ATZ" + CHR$(13)
   Stat$ = SPACE$(80)
   Menu$ = "ALT +: Quit  Dial  HangUp  Configure  Log:    Upload  dOwnload"

   CLS
   LOCATE , , One
   AnsiInit                            'This sets the defaults for emulation
   Ansi.BRow = 24                      'We want to use the bottom row for status

'-----  Look for configuration file
   Path$ = GetFileSpec$                'Search for a configuration file
   Config$ = LEFT$(Path$, INSTR(Path$, ".")) + "CFG"

   IF PDQExist(Config$) THEN           'If we have a configuration file,
      OPEN Config$ FOR BINARY AS #1
      GET #1, , ComNum                 'This is our Comm Port
      GET #1, , Baud&                  'This is our baud rate
      GET #1, , Tone                   'This tells if we have touch-tone
      CLOSE #1                         '  or pulse dialing
   ELSE
      GOSUB GetConfig                  'If no configuration file exists,
   END IF

'-----  Read dialing directory if one exists
   DialFile$ = LEFT$(Path$, INSTR(Path$, ".")) + "DIR"
   IF PDQExist(DialFile$) THEN                 'See if one exists
      CALL ReadDialDir(DialFile$, DialDir$())  'Read it up
   END IF

   GOSUB OpenPort                      'Go and open the port

   GOSUB Menu                          'Display Menu

   DO
      KeyPress = BIOSInkey             'This gets keyboard input
      SELECT CASE KeyPress             'While this processes it

'-----  Exit Program   ALT-Q
         CASE -16
            LSET Stat$ = "Exit to DOS? (Y/N)"
            Noise = -1
            GOSUB DoStat               'Prompt with sound
            LOCATE Bottom, 20
            GOSUB YesNo                'Yes/No answer
            IF KeyPress = 78 THEN
               GOSUB Menu              'If no, display menu
               AnsiPrint ""            ' and reposition cursor
            ELSE
               EXIT DO
            END IF

'-----  Dial Out       ALT-D
         CASE -32
            Phone$ = SPACE$(30)
            LSET Stat$ = "Enter number to dial: - "
            GOSUB DoStat
            LOCATE Bottom, Bottom
            BIOSInput Phone$, Reverse
            Phone$ = LTRIM$(RTRIM$(Phone$))
            GOSUB Menu
            AnsiPrint ""
            IF LEN(Phone$) THEN GOSUB DialOut

'-----  Hang Up        ALT-H
         CASE -35
            LSET Stat$ = "Hanging up modem - stand by"
            GOSUB DoStat
            Pause Bottom
            ComPrint "+++"
            Pause Bottom
            ComPrint "ATH" + CHR$(13)
            GOSUB Menu

'-----  Change Configuration   ALT-C
         CASE -46
            CloseCom
            GOSUB GetConfig
            GOSUB OpenPort
            GOSUB Menu

'-----  Log To Disk    ALT-L
         CASE -38
            IF LogOn THEN              'If we are logging, then we stop
               LogOn = 0
               CLOSE #1                'Close our log file
               DosErr = ERR            'Check for errors
               IF DosErr THEN
                  LSET Stat$ = "Disk error - " + STR$(DosErr)
                  Noise = -1
                  GOSUB DoStat
               ELSE
                  LSET Stat$ = "Closing " + FileName$
                  GOSUB DoStat
               END IF
               Pause Bottom
            ELSE                       'Else start logging
               FileName$ = SPACE$(30)
               LSET Stat$ = "Enter file name:"
               GOSUB DoStat
               LOCATE Bottom, 18
               BIOSInput FileName$, Reverse
               FileName$ = UCASE$(RTRIM$(LTRIM$(FileName$)))
               LenName = LEN(FileName$)
               IF LenName THEN
                  OverWrite = -1
                  IF PDQExist(FileName$) THEN
                     LSET Stat$ = FileName$ + " Exists, overwrite it? (Y/N)"
                     Noise = -1
                     GOSUB DoStat
                     LOCATE Bottom, LenName + 30
                     GOSUB YesNo
                     IF KeyPress = 78 THEN OverWrite = 0
                     IF NOT OverWrite THEN
                        LSET Stat$ = "Append to " + FileName$ + "? (Y/N)"
                        GOSUB DoStat
                        LOCATE Bottom, LenName + 19
                        GOSUB YesNo
                        AppendTo = -1
                        IF KeyPress = 78 THEN AppendTo = 0
                     END IF
                  END IF

                  IF OverWrite THEN
                     OPEN FileName$ FOR OUTPUT AS #1
                     DosErr = ERR
                  ELSEIF AppendTo THEN
                     OPEN FileName$ FOR APPEND AS #1
                     DosErr = ERR
                  END IF

                  IF DosErr THEN
                     LSET Stat$ = "Disk error - " + STR$(DosErr)
                     GOSUB DoStat
                     LogOn = 0
                     Pause Bottom
                  ELSEIF OverWrite OR AppendTo THEN
                     LogOn = -1
                     LSET Stat$ = "Opening: " + FileName$
                     GOSUB DoStat
                     Pause Bottom
                  END IF
               END IF
            END IF
            GOSUB Menu
            AnsiPrint ""

'-----  Function Keys for Dialing Directory  F1 - F10
         CASE -66 TO -59
            Phone$ = DialDir$(-KeyPress - 58)
            IF LEN(Phone$) THEN GOSUB DialOut

'-----  Upload a File
         CASE -22
            AnsiPrint ""
            LSET Stat$ = "Select Protocol [X)modem, Y)modem, G)-ymodem]:"
            GOSUB DoStat
            LOCATE Bottom, 48
            DO
               Char = BIOSInkey
            LOOP UNTIL Char = 88 OR Char = 120 OR Char = 89 OR Char = 121 OR Char = 71 OR Char = 103
            IF Char = 88 OR Char = 120 THEN
               FileName$ = SPACE$(30)
               LSET Stat$ = "Enter file name to upload:"
               GOSUB DoStat
               LOCATE Bottom, 31
               BIOSInput FileName$, Reverse
               FileName$ = UCASE$(LTRIM$(RTRIM$(FileName$)))
            ELSE
               REDIM FileName$(1 TO 5)
               NumFiles = 0
               DO
                  LSET Stat$ = "Enter file #" + STR$(NumFiles + 1) + " to upload:"
                  GOSUB DoStat
                  LOCATE Bottom, 27
                  FileName$ = SPACE$(30)
                  BIOSInput FileName$, Reverse
                  FileName$ = RTRIM$(FileName$)
                  IF LEN(FileName$) THEN
                     NumFiles = NumFiles + 1
                     FileName$(NumFiles) = FileName$
                     IF NumFiles = 5 THEN EXIT DO
                  END IF
               LOOP WHILE LEN(FileName$)
            END IF
            GOSUB Menu
            LOCATE , , Zero
            IF HandShake$ = "XON" THEN SetHandshaking "NON"
            IF Char = 88 OR Char = 120 THEN
               RetCode = XModem1KSend(FileName$)
            ELSE
               FOR I = 1 TO NumFiles
                  IF Char = 89 OR Char = 121 THEN
                     RetCode = YModemSend(FileName$(I))
                  ELSE
                     RetCode = YModemGSend(FileName$(I))
                  END IF
                  IF RetCode THEN EXIT FOR
                  LSET Stat$ = FileName$(I) + " Sent"
                  GOSUB DoStat
               NEXT
               IF Char = 89 OR Char = 121 THEN
                  RetCode = YModemSend("")
               ELSE
                  RetCode = YModemGSend("")
               END IF
            END IF
            SetHandshaking HandShake$
            IF RetCode THEN
               LSET Stat$ = "Upload failed - return code " + STR$(RetCode)
            ELSE
               LSET Stat$ = "Upload successful"
            END IF
            Noise = -1
            GOSUB DoStat
            Pause Bottom
            GOSUB Menu
            LOCATE , , One

'-----  Download a File
         CASE -24
            AnsiPrint ""
            LSET Stat$ = "Select Protocol [X)modem, Y)modem, G)-ymodem]:"
            GOSUB DoStat
            LOCATE Bottom, 48
            DO
               Char = BIOSInkey
            LOOP UNTIL Char = 88 OR Char = 120 OR Char = 89 OR Char = 121 OR Char = 71 OR Char = 103
            IF Char = 88 OR Char = 120 THEN
               FileName$ = SPACE$(30)
               LSET Stat$ = "Enter file name to download:"
               GOSUB DoStat
               LOCATE Bottom, 31
               BIOSInput FileName$, Reverse
               FileName$ = UCASE$(LTRIM$(RTRIM$(FileName$)))
            ELSE
               FileName$ = ""
            END IF
            GOSUB Menu
            LOCATE , , 0
            IF HandShake$ = "XON" THEN SetHandshaking "NON"
            IF Char = 88 OR Char = 120 THEN
               RetCode = XModem1KReceive(FileName$)
            ELSE
               DO
                  IF Char = 71 OR Char = 103 THEN
                     RetCode = YModemGReceive(FileName$)
                  ELSE
                     RetCode = YModemReceive(FileName$)
                  END IF
                  LSET Stat$ = FileName$ + " received"
                  GOSUB DoStat
                  FileName$ = ""
               LOOP UNTIL RetCode
               IF RetCode = 6 THEN RetCode = 0
            END IF
            SetHandshaking HandShake$
            IF RetCode THEN
               LSET Stat$ = "Download failed - return code " + STR$(RetCode)
            ELSE
               LSET Stat$ = "Download successful"
            END IF
            Noise = -1
            GOSUB DoStat
            Pause Bottom
            GOSUB Menu
            LOCATE , , One

'-----  Normal keys out the port
         CASE IS > 0
            ComPrint CHR$(KeyPress)

'-----  Extended key code
         CASE IS < 0
            ComPrint CHR$(0) + CHR$(-KeyPress)

      END SELECT

'-----  Servive Port
      IF ComLoc THEN
         Text$ = ComInput$(ComLoc)
         AnsiPrint Text$
         IF LogOn THEN PUT #1, , Text$
      END IF

'-----  IMPORTANT !!! Check for buffer overrun condition
      IF OverRun THEN
         LSET Stat$ = "Buffer overrun!!!"
         Noise = -1
         GOSUB DoStat
         FlushBuffer
         Pause Bottom
         GOSUB Menu
      END IF

   LOOP

   CloseCom
   IF LogOn THEN CLOSE #1
   CLS
END

'*****************************************************************************
'-----  Subroutines

Menu:                                     'display line 25 menu
   LSET Stat$ = ""
   PDQPrint Stat$, Bottom, One, Reverse   'clear line 25
   PDQPrint Menu$, Bottom, One, Reverse   'print the menu string

   PDQPrint "Q", Bottom, 8, Norm          'highlight menu keys
   PDQPrint "D", Bottom, 14, Norm
   PDQPrint "H", Bottom, 20, Norm
   PDQPrint "C", Bottom, 28, Norm
   PDQPrint "L", Bottom, 39, Norm
   PDQPrint "U", Bottom, 47, Norm
   PDQPrint "O", Bottom, 56, Norm

   IF LogOn THEN                          'if disk log is on then
      PDQPrint "On", Bottom, 43, Reverse  'highlight on
   ELSE                                   'if disk log is off then
      PDQPrint "Off", Bottom, 43, Reverse 'highlight off
   END IF
RETURN

YesNo:
   YesNoCol = POS(0)                      'save cursor column
   DO                                     'key press loop
      LOCATE Bottom, YesNoCol             'locate cursor position
      KeyPress = BIOSInkey                'get user input
      IF KeyPress THEN                    'if a key was pressed
         IF KeyPress > 90 THEN KeyPress = KeyPress - 32  'upper case swap
         PRINT CHR$(KeyPress);            'print the key
      END IF
   LOOP UNTIL KeyPress = 89 OR KeyPress = 7  'loop until a valid choice
RETURN

'----- Reconfigure
GetConfig:
   LSET Stat$ = "Enter Com port number - "
   GOSUB DoStat
   LOCATE Bottom, Bottom
   DO
      KeyPress = BIOSInkey
      IF KeyPress THEN
         IF KeyPress = 27 THEN
            LOCATE Row, Col
            GOSUB Menu
            RETURN
         END IF
         PDQPrint CHR$(KeyPress), Bottom, Bottom, Norm
         ComNum = PDQValI(CHR$(KeyPress))
         IF ComNum < 1 AND ComNum > 4 THEN
            SOUND 2500, 2
         ELSE
            EXIT DO
         END IF
      END IF
   LOOP

   LSET Stat$ = "What baud rate do you want? "
   GOSUB DoStat
   Baud$ = SPACE$(5)
   LOCATE Bottom, 29
   BIOSInput Baud$, Reverse
   Baud& = PDQValL(Baud$)

   LSET Stat$ = "Do you have a touch-tone phone? (Y/N) - "
   GOSUB DoStat
   LOCATE Bottom, 40
   GOSUB YesNo
   IF KeyPress = 89 THEN Tone = -1 ELSE Tone = 0

   OPEN Config$ FOR BINARY AS #2
   PUT #2, , ComNum
   PUT #2, , Baud&
   PUT #2, , Tone
   CLOSE #2

   GOSUB Menu
   AnsiPrint ""
RETURN

'-----  Open Com Port
OpenPort:
   LSET Stat$ = "Initializing port - stand by"
   GOSUB DoStat
   OpenCom "COM" + STR$(ComNum) + ":" + STR$(Baud&) + ",N,8,1,RB4096,NON"
   ComErr = ERR
   IF ComErr THEN
      LSET Stat$ = "Sorry - communications error " + STR$(ComErr)
      Noise = -1
      GOSUB DoStat
      Pause Bottom
      CLS
      END
   END IF

   IF Baud& > 2400 THEN
      HandShake$ = "RTS"
   ELSE
      HandShake$ = "XON"
   END IF
   SetHandshaking HandShake$
   REDIM Ports(1 TO 4)
   GetComPorts Ports(1), Ports(2), Ports(3), Ports(4)
   IF UARTType(Ports(ComNum)) = 3 THEN
      SetFIFO 14
   END IF
   ERASE Ports

   Pause 18
   ComPrint Reset$
RETURN

'----- Dial Out
DialOut:
   IF Tone THEN Dial$ = "ATDT" ELSE Dial$ = "ATDP"
   Dial$ = Dial$ + Phone$ + CHR$(13)
   LSET Stat$ = "Dialing " + Phone$
   GOSUB DoStat
   ComPrint Dial$
   Pause Bottom
   GOSUB Menu
RETURN

'-----  Print staus line
DoStat:
   PDQPrint Stat$, Bottom, One, Norm
   IF Noise THEN
      SOUND 2500, 2
      Noise = 0
   END IF
RETURN

SUB BIOSInput (Work$, Attr%)

'-----  Emulates PDQ's BIOSInput routine
CurRow = CSRLIN
CurCol = POS(0)
PDQPrint Work$, CurRow, CurCol, Attr
ColOfs = 0
ColMax = LEN(Work$)
DO
   Char = BIOSInkey
   SELECT CASE Char

      CASE 13
         EXIT DO

      CASE 8
         ColOfs = ColOfs - 1
         IF ColOfs < 0 THEN ColOfs = 0
         PDQPrint " ", CurRow, CurCol + ColOfs, Attr
         LOCATE , CurCol + ColOfs

      CASE 32 TO 128
         PDQPrint CHR$(Char), CurRow, CurCol + ColOfs, Attr
         MID$(Work$, ColOfs + 1, 1) = CHR$(Char)
         ColOfs = ColOfs + 1
         IF ColOfs = ColMax THEN
            ColOfs = ColOfs - 1
         END IF
         LOCATE , CurCol + ColOfs

      CASE ELSE
   END SELECT
LOOP

END SUB

SUB ReadDialDir (FileName$, Numbers$()) STATIC

   MaxNum = UBOUND(Numbers$)              'Determine max amount of numbers
   CurNum = 1                             'Array pointer
   FileNum = FREEFILE                     'Get a file handle
   OPEN FileName$ FOR INPUT AS #FileNum   'Open the file

   DO
      LINE INPUT #FileNum, Line$          'Read a line
      Comment = INSTR(Line$, "'")         'Parse out comments
      IF Comment THEN
         Line$ = LEFT$(Line$, Comment - 1)
      END IF
      Line$ = LTRIM$(RTRIM$(Line$))       'Remove all spaces

      IF LEN(Line$) THEN                  'After all this, if we have anything
         Numbers$(CurNum) = Line$         '  consider it a phone number
         CurNum = CurNum + 1
      END IF

   LOOP UNTIL EOF(FileNum) OR CurNum > MaxNum   'Continue until we reach the
                                                ' the end of file or out of
   CLOSE #FileNum                               ' numbers

END SUB
