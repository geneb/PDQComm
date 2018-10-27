'**********  TSRTERM.BAS  - TSR Terminal Program

'   Copyright (c) Crescent Software 1990
'   Written by Nash Bly and Dave Cleary

'   Note: This demo requires Crescent Software's P.D.Q. to compile and link.
          See MSTERM.BAS for a demo that does not require P.D.Q.

'   THIS PROGRAM IS INTENDED TO BE COMPILED TO DISK

'   BC TSRTerm /o;
'   LINK /nod /noe /e /far /packc TSRTerm _NoVal _NoError _NoRead _NoNet
'        _NoField STR02048, , nul, PDQComm PDQ
'   Then use Exe2Com for minimum program size!

'Note that the communications parameters are hard-coded into this program to
'save code and memory.  You may want to add an option to read them from the
'command line, or offer the choice to change them when the program pops up.
'Another possible enhancement to consider is checking to see if the display
'is in a 43- or 50-line mode, and using the additional lines for display.
       
'-------- Here are the essential statements for any PDQComm program

DEFINT A-Z                                      'don't leave home without it

'$INCLUDE: 'PDQDECL.bAS'                        'PDQ declares and types
'$INCLUDE: 'COMMDECL.BAS'                       'PDQComm declares and types

DECLARE SUB ScreenSave (ScrnMem())              'screen save/restore subs
DECLARE SUB ScreenRest (ScrnMem())
DECLARE SUB VidCfg (Mono, Page)


'-------- Some variable initializations and a function definition


    DIM Registers AS RegType                    'type defined in PDQDECL.BAS
    DIM Screen1(1 TO 2000), Screen2(1 TO 2000)  'holds saved screens

    ID$ = "TSRTerm 1.0 Copyright 1990 by Cresent Software"  'TSR ID

    One = 1                                     'save a few bytes with
    Bottom = 25                                 'a few integer constants
    Norm = 7                                    'normal print color
    Inverse = 112                               'inverse print color
    Reset$ = "ATZ" + CHR$(13)                   'reset the modem command
                                                'and two strings for printing
    Clear$ = STRING$(79, 32)
    Menu$ = "Alt-X-Exit  ALT-D-Dial  Alt-H-HangUp  Alt-E-Echo:On/Off  Alt-L-Log-On/Off"

    HotKey = &H82E                              'Alt-C is the hot key

    DGroup = TSRInstalled(ID$)                  'are we already installed?
    IF DGroup THEN GOTO DeInstall               'yes, so deinstall

    CLS                                         'clear the screen and display
    GOSUB Menu                                  '  the menu
    ResRow = 1
    ResCol = 1
    ScreenSave Screen1()                        'save current screen and cursor

    CLS
    PRINT ID$                                   'print out TSR ID
    PRINT "Press Alt-C to pop up, run again to deinstall."



'-------- Open the Com Port and check for errors


    PRINT "Initializing Port - Standby"

    OpenCom "COM1:1200,N,8,1,RB512,XON"         'open the com port

    ComErr = ERR                                'remember error number

    IF ComErr THEN                              'if there was an open error
        CLS
        PRINT "Sorry, Unable to Open Com Port"  'ever so sorry
        PRINT "Error - "; PDQMessage$(ComErr)   'here's the error message
        CursorOn
        END                                     'terminate execution

    ELSE                                        'if no error
        IF ComLoc THEN in$ = ComInput$(ComLoc)  'clear the com input buffer
        Ok = 0                                  'preset flag to not ok
        FOR I = 1 TO 2                          'reset modem loop 2 trys max
            ComPrint Reset$                     'send modem a reset command
            in$ = ""                            'init the com input string
            Start& = PDQTimer&                  'remember start time
            DO                                  'modem response loop
                IF ComLoc THEN                  'if any chars in com buffer
                    in$ = in$ + ComInput$(One)  'add them to com input string
                    IF INSTR(in$, "OK") THEN    'if modem responds "OK" then
                        Ok = -1                 'set flag ok true
                        EXIT DO                 'exit modem response loop
                    END IF
                END IF
            LOOP WHILE PDQTimer& - Start& < 72  'wait for "OK" 4 for seconds
            IF Ok THEN EXIT FOR                 'if Ok then done waiting
        NEXT

        IF NOT Ok THEN                          'if no modem response then
            PRINT "WARNING: - No Modem Recognized"  'display a warning
        END IF

    END IF

    PopUpHere HotKey, ID$                       'this sets up the TSR
    GOTO EndRes                                 'must be after PopUpHere

'------- Main Keyboard and Com Port Input Loop


    BreakOff                                    'disable CTRL-BREAK
    DosRow = CSRLIN
    DosCol = POS(0)
    ScreenSave Screen2()                        'save underlying screen

    ScreenRest Screen1()
    LOCATE ResRow, ResCol                       'pop up TSR screen
    CursorOn                                    'turn on text cursor

    DO                                          'com and keyboard input loop
        KeyPress = BIOSInkey                    'get a key press

        SELECT CASE KeyPress                    'process key press
        CASE -45                                'if Alt-X pressed
            ResRow = CSRLIN                     'save cursor row
            ResCol = POS(0)                     'save cursor column
            ScreenSave Screen1()                'save TSR screen
            ScreenRest Screen2()                'restore underlying screen
            LOCATE DosRow, DosCol               'restore cursor
            BreakOn                             'enable CTRL-BREAK
            PopDown                             'Go away

        CASE -32                                'if Alt-D pressed
            GOTO Dial                           'dial a phone number

        CASE -35                                'if Alt-H pressed
            GOTO HangUp                         'hang up modem

        CASE -18                                'if Alt-E pressed
            GOTO Echo                           'toggle screen echo

        CASE -38                                'if Alt-L pressed
            GOTO LogFile                        'Open/Close a disk file

        CASE 3                                  'if Ctrl-C pressed
            ComPrint CHR$(3)                    'send it to com port only

        CASE 13                                 'if RETURN pressed
            ComPrint CHR$(KeyPress)             'send it to com port
            IF EchoOn THEN                      'if screen echo is on then
                PRINT                           'print CR-LF to screen
                GOSUB Scroll                    'scroll screen if needed
                IF LogOn THEN PRINT #1,         'print to it disk if needed
            END IF

        CASE IS > 0                             'if any other key pressed
            ComPrint CHR$(KeyPress)             'print to com port
            IF EchoOn THEN                      'if screen echo is on
                PRINT CHR$(KeyPress);           'print the char on screen
                GOSUB Scroll                    'scroll screen if needed
                IF LogOn THEN PRINT #1, CHR$(KeyPress);    'print it to disk
            END IF

        CASE ELSE                               'no key, do nothing
        END SELECT

GetCom:

'------- Com port character input loop


        DO WHILE ComLoc                         'if com input buffer waiting
            in$ = ComInput$(One)                'input a single character
            IF in$ = CHR$(13) THEN              'if a CR is received then
                PRINT                           'print CR-LF to the screen
                IF LogOn THEN PRINT #1,         'print it to disk if needed
            ELSEIF in$ <> CHR$(10) THEN         'if other then LF received
                PRINT in$;                      'print the char to the screen
                IF LogOn THEN PRINT #1, in$;    'print it to disk if needed
            END IF
            GOSUB Scroll                        'scroll screen if needed
        LOOP                                    'get another char from buffer



'-------- End of Main Input Loop


    LOOP                                        'get next keyboard/com input




'------- Close port, disk and end program


DeInstall:
    CloseCom                                    'all input done, close port
    IF LogOn THEN CLOSE #1                      'close file if still open
    Success = PopDeinstall(DGroup, ID$)         'remove TSR
    IF Success THEN                             'if everthing OK, then we are
      PRINT "TSRTerm removed from memory"       'done
    ELSE
      PRINT "Could not deinstall. Please reboot!!!" 'something went wrong
    END IF                                      'print warning message

    END                                         'end the program

EndRes:
   EndTSR ID$                                   'this installs our TSR and
   END                                          'pops down




'***************************************************************************
'****************************  Menu Routines  ******************************
'***************************************************************************


'-------- Dial a phone number

Dial:                                           'dial a phone number

    Row = CSRLIN                                'save cursor row
    Col = POS(0)                                'save cursor column
    Phone$ = STRING$(30, 32)                    'init phone number string

    PDQPrint Clear$, Bottom, One, Norm          'promt for phone number
    PDQPrint "Enter Number to Dial: - ", Bottom, One, Norm

    LOCATE Bottom, Bottom                       'locate cursor position
    BIOSInput Phone$, Inverse                   'get user input of number

    Phone$ = RTRIM$(LTRIM$(Phone$))             'trim all spaces from number

    IF LEN(Phone$) THEN
        CursorOff                               'turn off cursor
        Dial$ = "ATDT " + Phone$ + CHR$(13)     'init modem command string

        PDQPrint Clear$, Bottom, One, Norm      'display dialing message
        PDQPrint "Dialing - " + Phone$, Bottom, One, Norm

        ComPrint Dial$                          'send dial command to modem

        IF LogOn AND EchoOn THEN                'if logging and echoing then
            PRINT #1, "Dialing - "; Phone$      'send dialing message to disk
        END IF

        Pause 27                                'pause to read message
    END IF

    GOSUB Menu                                  'redisplay menu
    LOCATE Row, Col                             'restore cursor position
    CursorOn                                    'turn on the cursor


    GOTO GetCom                                 'go get com input



'------- Log activity to disk


LogFile:                                        'open/close disk file
                                                'and log activity to it

    Row = CSRLIN                                'save cursor row
    Col = POS(0)                                'save cursor column

    IF LogOn THEN                               'if file already open
        LogOn = 0                               'toggle flag to closed

        CursorOff                               'turn off the cursor
        CLOSE #1                                'close the file
        DosErr = ERR                            'check for error
        PDQPrint Clear$, Bottom, One, Norm      'clear line 25 menu
        IF DosErr THEN                          'if there was a dos error
            PDQSound 2500, 2                    'beep and display message
            PDQPrint "Disk Error - " + PDQMessage$(DosErr), Bottom, One, Norm
        ELSE                                    'else display closing message
            PDQPrint "Closing " + FileName$, Bottom, One, Norm
        END IF
        Pause 27                                'pause to read message
    ELSE                                        'if file not already open
        FileName$ = STRING$(30, 32)             'init file name string
        PDQPrint Clear$, Bottom, One, Norm      'prompt for file name input
        PDQPrint "Enter File Name:", Bottom, One, Norm
        LOCATE Bottom, 18                       'locate at file name field
        BIOSInput FileName$, Inverse            'get user input file name
        CursorOff

        FileName$ = UCASE$(RTRIM$(LTRIM$(FileName$)))   'trim the result
        LenName = LEN(FileName$)                'remember the length

        IF LenName THEN                         'if a name was entered then
            OverWrite = -1                      'preset overwrite to yes
            IF PDQExist(FileName$) THEN         'if the file exists then
                PDQPrint Clear$, Bottom, One, Norm
                PDQPrint FileName$ + " Exists, Overwrite it? (Y/N)", Bottom, One, Norm
                PDQSound 2500, 2                'ask about overwriting it
                LOCATE Bottom, LenName + 30     'locate cursor position
                GOSUB YesNo                     'get user response
                IF KeyPress = 78 THEN OverWrite = 0 'reponse no, reset flag

                IF NOT OverWrite THEN           'overwrite no, ask to append
                    PDQPrint Clear$, Bottom, One, Norm
                    PDQPrint "Append to " + FileName$ + "? (Y/N)", Bottom, One, Norm
                    LOCATE Bottom, LenName + 19 'locate cursor position
                    GOSUB YesNo                 'get answer in keypress
                    AppendTo = -1               'preset flag true
                    IF KeyPress = 78 THEN AppendTo = 0  'answer no, reset flag
                END IF
            END IF

            IF OverWrite THEN                   'if overwrite is yes then
                OPEN FileName$ FOR OUTPUT AS #1 'open the file for output
                DosErr = ERR                    'remember dos error
            ELSEIF AppendTo THEN                'else if append is yes then
                OPEN FileName$ FOR BINARY AS #1 'open the file for binary
                DosErr = ERR                    'remember dos error
                IF NOT DosErr THEN              'if no dos error then
                    SEEK #1, LOF(1) + 1         'seek to end of file
                    DosErr = ERR                'remember dos error
                END IF
            END IF

            PDQPrint Clear$, Bottom, One, Norm  'clear the input prompt

            IF DosErr THEN                      'if there was an error
                PDQSound 2500, 2                'beep and display message
                PDQPrint "Disk Error - " + PDQMessage$(DosErr), Bottom, One, Norm
                LogOn = 0                       'reset flag to closed
                Pause 27                        'pause to read message
            ELSEIF OverWrite OR AppendTo THEN   'display open message                                    'no error, print open message
                LogOn = -1                      'toggle flag to open
                PDQPrint "Opening: " + FileName$, Bottom, One, Norm
                Pause 27                        'pause to read message
            END IF
        END IF
    END IF

    GOSUB Menu                                  'restore/update the menu
    LOCATE Row, Col                             'restore cursor postion
    CursorOn                                    'turn on the cursor


    GOTO GetCom                                 'go get com input



'-------- Hang Up Modem


HangUp:                                         'hang up the modem

    CursorOff                                   'turn off the cursor
    PDQPrint Clear$, Bottom, One, Norm          'print a message
    PDQPrint "Hanging Up Modem - Standby", Bottom, One, Norm

    IF ComLoc THEN in$ = ComInput$(ComLoc)      'clear com buffer
    ComPrint "+++"                              'put modem in command mode
    Pause 27                                    'pause for 1.5 seconds
    ComPrint "ATH" + CHR$(13)                   'send hang up command

    GOSUB Menu                                  'restore menu
    CursorOn                                    'turn on the cursor


    GOTO GetCom                                 'go get com input



'-------- Toggle Screen Echo On/Off


Echo:                                           'toggle screen echo on/off

    IF EchoOn THEN                              'if echo already on then
        EchoOn = 0                              'reset flag to false
    ELSE                                        'if echo already off then
        EchoOn = -1                             'set flag to true
    END IF                                      'update the menu
    GOSUB Menu


    GOTO GetCom                                 'go get com input



'***************************************************************************
'*****************************  SubRoutines  *******************************
'***************************************************************************


'-------- Scroll the screen up 1 line

Scroll:                                         'scroll screen up 1 line

    IF CSRLIN = 24 THEN                         'if cursor near bottom
        Registers.AX = &H601                    'AH=Service 6 / AL=Up 1 Line
        Registers.BX = 7 * 256                  'BH=Color / BL=Nothing
        Registers.CX = 0                        'CH=ULR / CL=ULC (Base 0,0)
        Registers.DX = (79) + 256 * (23)        'DH=LRR / DL=LRC
        CALL INTERRUPT(&H10, Registers)         'BIOS Int 10H
        LOCATE 23, 1                            'move cursor up one line
    END IF

    RETURN



'-------- Display Line 25 Menu


Menu:                                           'display line 25 menu

    PDQPrint Clear$, Bottom, One, Norm          'clear line 25
    PDQPrint Menu$, Bottom, One, Norm           'print the menu string

    PDQPrint "Alt-X", Bottom, One, Inverse      'highlight menu keys
    PDQPrint "Alt-D", Bottom, 13, Inverse
    PDQPrint "Alt-H", Bottom, 25, Inverse
    PDQPrint "Alt-E", Bottom, 39, Inverse
    PDQPrint "Alt-L", Bottom, 58, Inverse

    IF EchoOn THEN                              'if echo is on then
        PDQPrint "On", Bottom, 50, Inverse      'highlight on
    ELSE                                        'if echo is off then
        PDQPrint "Off", Bottom, 53, Inverse     'highlight off
    END IF

    IF LogOn THEN                               'if disk log is on then
        PDQPrint "On", Bottom, 68, Inverse      'highlight on
    ELSE                                        'if disk log is off then
        PDQPrint "Off", Bottom, 71, Inverse     'highlight off
    END IF


    RETURN



YesNo:

    CursorOn
    YesNoCol = POS(0)                           'save cursor column
    DO                                          'key press loop
        LOCATE Bottom, YesNoCol                 'locate curosr position
        KeyPress = BIOSInkey                    'get user input
        IF KeyPress THEN                        'if a key was pressed
            IF KeyPress > 90 THEN KeyPress = KeyPress - 32  'upper case swap
            PRINT CHR$(KeyPress);               'print the key
        END IF
    LOOP UNTIL KeyPress = 89 OR KeyPress = 78   'loop until a valid choice
    CursorOff

    RETURN

SUB ScreenRest (ScrArray%())

CALL VidCfg(Mono, Page)

IF Mono THEN ToSeg = &HB000 ELSE ToSeg = &HB800
ToOfs = Page * &H1000

FromSeg = VARSEG(ScrArray(1))
FromOfs = VARPTR(ScrArray(1))

BlockCopy FromSeg, FromOfs, ToSeg, ToOfs, 4000

END SUB

SUB ScreenSave (ScrArray%())

CALL VidCfg(Mono, Page)

IF Mono THEN FromSeg = &HB000 ELSE FromSeg = &HB800
FromOfs = Page * &H1000

ToSeg = VARSEG(ScrArray(1))
ToOfs = VARPTR(ScrArray(1))

BlockCopy FromSeg, FromOfs, ToSeg, ToOfs, 4000

END SUB

SUB VidCfg (Mono%, Page%)

DEF SEG = 0

IF PEEK(&H463) = &H4B THEN Mono = -1 ELSE Mono = 0
Page = PEEK(&H462)

DEF SEG

END SUB
