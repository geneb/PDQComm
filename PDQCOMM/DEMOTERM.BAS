'********* DEMOTERM.BAS - Simple Terminal Program

'   Copyright (c) Crescent Software 1990
'   Written by Nash Bly

'   Note: This demo requires Crescent Software's P.D.Q. to compile and link.
'         See MSTERM.BAS for a demo that does not require P.D.Q.

'   THIS PROGRAM IS INTENDED TO BE COMPILED TO DISK

'   BC DemoTerm /o;
'   LINK /nod /noe /e /far /packc DemoTerm _NoVal _NoRead _NoError _NoNet
'     _NoField , , nul, PDQComm PDQ
'   Then use Exe2Com for minimum program size!

'-------- Here are the essential statements for any PDQComm program

DEFINT A-Z                                      'don't leave home without it

'$INCLUDE: 'PDQDecl.bas'                        'PDQ declares and types
'$INCLUDE: 'CommDecl.bas'                       'PDQComm declares and types


'-------- Some variable initializations and a function definition


    DIM Registers AS RegType                    'type defined in PDQDECL.BAS
    DIM Port(4)                                 'hold com port addresses

    One = 1                                     'save a few bytes by using
    Bottom = 25                                 'variables instead of CONST
    Norm = 7                                    'normal print color
    Space = 32                                  'for CHR$(32)
    Inverse = 112                               'inverse print color
    Reset$ = "ATZ" + CHR$(13)                   'reset the modem command
                                                'and two strings for printing
    Clear$ = STRING$(79, Space)
    Menu$ = "Alt-X-Exit  ALT-D-Dial  Alt-H-HangUp  Alt-E-Echo:On/Off  Alt-L-Log-On/Off"


    CLS                                         'and off we go


'-------- Check available ports and ask user to input Com Port Number


    GetComPorts Port(1), Port(2), Port(3), Port(4)  'get available ports

    DO                                          'com port choice loop
        GoodPort = 0                            'preset flag to false
        PDQPrint "Enter com port number - ", Bottom, One, Norm
        LOCATE Bottom, Bottom                   'locate cursor position
        KeyPress = BIOSInkey                    'get user input
        IF KeyPress THEN                        'if a key was pressed
            IF KeyPress = 27 THEN               'if <ESC> was pressed
                CLS                             'clear the screen
                END                             'and exit the program
            END IF                              'otherwise
            ComNum$ = CHR$(KeyPress)            'convert choice to a string
            PRINT ComNum$;                      'print the choice
            ComNum = PDQValI(ComNum$)           'convert choice to a number
            IF Port(ComNum) = 0 OR ComNum > 4 THEN  'if it is an invalid port
                CursorOff                           'turn off cursor
                PDQPrint Clear$, Bottom, One, Norm  'clear line 25 and warn
                PDQPrint "Port " + ComNum$ + " not available", Bottom, One, Norm
                PDQSound 2500, 2                'wake up user
                Pause 27                        'pause to read warning
                CursorOn                        'turn on cursor
            ELSE                                'if choice is valid then
                GoodPort = -1                   'set flag true
            END IF
            PDQPrint Clear$, Bottom, One, Norm  'clear line 25
        END IF
    LOOP UNTIL GoodPort                         'keep asking until good


'-------- Ask user if a modem will be used


    PDQPrint "Are you using a modem? (Y/N) - ", Bottom, One, Norm
    LOCATE Bottom, 32                           'prompt and locate cursor
    GOSUB YesNo                                 'get yes/no response
                                                'KeyPress = 89 or 78 (Y or N)
    CLS                                         'clear the screen



'-------- Open the Com Port and check for errors


    CursorOff                                   'cursor off, display message
    PDQPrint "Initializing port - stand by", Bottom, One, Norm

    OpenCom "Com" + ComNum$ + ":1200,N,8,1,RB2048,NON"    'open the com port

    ComErr = ERR                                'remember error number

    IF ComErr THEN                              'if there was an open error
        CLS
        PRINT "Sorry, unable to open Com port"  'ever so sorry
        PRINT "Error - "; PDQMessage$(ComErr)   'here's the error message
        CursorOn
        END                                     'terminate execution

    ELSEIF KeyPress = 89 THEN                   'if no error and using modem
        IF ComLoc THEN In$ = ComInput$(ComLoc)  'clear the com input buffer
        Ok = 0                                  'preset flag to not ok
        FOR I = 1 TO 2                          'reset modem loop 2 trys max
            ComPrint Reset$                     'send modem a reset command
            In$ = ""                            'init the com input string
            Start& = PDQTimer&                  'remember start time
            DO                                  'modem response loop
                IF ComLoc THEN                  'if any chars in com buffer
                    In$ = In$ + ComInput$(One)  'add them to com input string
                    IF INSTR(In$, "OK") THEN    'if modem responds "OK" then
                        Ok = -1                 'set flag Ok true
                        EXIT DO                 'exit modem response loop
                    END IF
                END IF
            LOOP WHILE PDQTimer& - Start& < 72  'wait for "OK" for 4 seconds
            IF Ok THEN EXIT FOR                 'if Ok then done waiting
        NEXT

        IF NOT Ok THEN                          'if no modem response then
            PRINT "Warning - no modem recognized"  'display a warning
        ELSE                                    'if modem OK then
            PRINT "OK"                          'echo it to the screen
        END IF

    END IF


'------- Main Keyboard and Com Port Input Loop


    GOSUB Menu                                  'display menu
    CursorOn                                    'turn on text cursor

    DO                                          'com and keyboard input loop
        KeyPress = BIOSInkey                    'get a key press

        SELECT CASE KeyPress                    'process key press
        CASE -45                                'if Alt-X pressed
            Row = CSRLIN                        'save cursor row
            Col = POS(0)                        'save cursor column
            CursorOff                           'turn off cursor
            PDQPrint Clear$, Bottom, One, Norm  'clear line 25
            PDQPrint "Exit to DOS? (Y/N)", Bottom, One, Norm
            PDQSound 2500, 2                    'ask about exiting
            LOCATE Bottom, 20                   'locate cursor position
            GOSUB YesNo                         'get user response
            IF KeyPress = 78 THEN               'reponse no, then
                GOSUB Menu                      'restore line 25 menu
                LOCATE Row, Col                 'restore cursor position
                CursorOn                        'turn on the cursor
            ELSE                                'if yes is exit response
                EXIT DO                         'exit input loop
            END IF

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


        BreakOff
        DO WHILE ComLoc                         'if com input buffer waiting
            In$ = ComInput$(One)                'input a single character
            IF In$ = CHR$(13) THEN              'if a CR is received then
                PRINT                           'print CR-LF to the screen
                IF LogOn THEN PRINT #1,         'print it to disk if needed
            ELSEIF In$ <> CHR$(10) THEN         'if other then LF received
                PRINT In$;                      'print the char to the screen
                IF LogOn THEN PRINT #1, In$;    'print it to disk if needed
            END IF
            GOSUB Scroll                        'scroll screen if needed
        LOOP                                    'get another char from buffer
        BreakOn



'-------- End of Main Input Loop


    LOOP                                        'get next keyboard/com input




'------- Close port, disk and end program


    CloseCom                                    'all input done, close port
    IF LogOn THEN CLOSE #1                      'close file if still open
    CLS                                         'clear the screen
    CursorOn                                    'turn on the cursor
    END                                         'end the program




'***************************************************************************
'****************************  Menu Routines  ******************************
'***************************************************************************


'-------- Dial a phone number

Dial:                                           'dial a phone number

    Row = CSRLIN                                'save cursor row
    Col = POS(0)                                'save cursor column
    Phone$ = STRING$(30, Space)                 'init phone number string

    PDQPrint Clear$, Bottom, One, Norm          'promt for phone number
    PDQPrint "Enter number to dial: - ", Bottom, One, Norm

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
            PDQPrint "Disk error - " + PDQMessage$(DosErr), Bottom, One, Norm
        ELSE                                    'else display closing message
            PDQPrint "Closing " + FileName$, Bottom, One, Norm
        END IF
        Pause 27                                'pause to read message
    ELSE                                        'if file not already open
        FileName$ = STRING$(30, Space)          'init file name string
        PDQPrint Clear$, Bottom, One, Norm      'prompt for file name input
        PDQPrint "Enter file name:", Bottom, One, Norm
        LOCATE Bottom, 18                       'locate at file name field
        BIOSInput FileName$, Inverse            'get user input file name
        CursorOff

        FileName$ = UCASE$(RTRIM$(LTRIM$(FileName$)))   'trim the result
        LenName = LEN(FileName$)                'remember the length

        IF LenName THEN                         'if a name was entered then
            OverWrite = -1                      'preset overwrite to yes
            IF PDQExist(FileName$) THEN         'if the file exists then
                PDQPrint Clear$, Bottom, One, Norm
                PDQPrint FileName$ + " Exists, overwrite it? (Y/N)", Bottom, One, Norm
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
                DosErr = ERR                    'remember DOS error
                IF NOT DosErr THEN              'if no DOS error then
                    SEEK #1, LOF(1) + 1         'seek to end of file
                    DosErr = ERR                'remember dos error
                END IF
            END IF

            PDQPrint Clear$, Bottom, One, Norm  'clear the input prompt

            IF DosErr THEN                      'if there was an error
                PDQSound 2500, 2                'beep and display message
                PDQPrint "Disk error - " + PDQMessage$(DosErr), Bottom, One, Norm
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
    PDQPrint "Hanging up modem - stand by", Bottom, One, Norm

    IF ComLoc THEN In$ = ComInput$(ComLoc)      'clear com buffer
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
        CALL Interrupt(&H10, Registers)         'BIOS Int 10H
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
