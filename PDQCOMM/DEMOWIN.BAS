'=============================================================================
'  DEMOWIN.BAS
'
'  Demonstration of PDQComm terminal emulations.
'
'  Copyright (c) 1991 Clearware Computing, By David Cleary
'
'  Note: In order to run this demo, you must un-comment the SetTTYWindow
'        routine in TTYDISP.BAS.  See the comments there.
'
'  Compile: BC /O/V DemoWin;
'  Link:    LINK EX/PACKC/F DemoWin + AnsiDisp + TTYDisp, , NUL, COMMQB4;
'=============================================================================
DEFINT A-Z

'$INCLUDE: 'TERM.BI'                   'Required by all emulations
'$INCLUDE: 'ANSI.BI'                   'Required for ANSI
'$INCLUDE: 'TTY.BI'                    'Required for TTY

DIM Message$(1 TO 10)                  'This holds the messages

CR$ = CHR$(13) + CHR$(10)              'Used a lot so make it a variable

'-----  Fill our message array
Message$(1) = CR$ + "       Welcome to the"
Message$(2) = CR$ + "     Full Moon Software"
Message$(3) = CR$ + "          PDQComm"
Message$(4) = CR$ + "    Window Emulation Demo."
Message$(5) = CR$ + "     We want to be your"
Message$(6) = CR$ + "          FAVORITE"
Message$(7) = CR$ + "     software company!!!"
Message$(8) = CR$ + " Please call 1-860-350-8188"
Message$(9) = CR$ + "    to satisfy all your"
Message$(10) = CR$ + "        BASIC needs."

CurMsg = 1                             'Current message number
LOCATE , , 0                           'Turn cursor off

'-----  Initialize windows
   AnsiInit                            'Set up ANSI defaults

   TTYInit                             'Set up TTY window #1 defaults
   TTY.TRow = 3                        'We have a 1 line window
   TTY.BRow = 3
   TTY.LCol = 26
   TTY.RCol = 54
   TTY.Fore = 14                       'Yellow on Black

   SetTTYWindow 2                      'Switch to window 2
   TTYInit                             'Set window #2 defaults
   TTY.TRow = 8                        'Define our window
   TTY.BRow = 16
   TTY.LCol = 27
   TTY.RCol = 54
   TTY.Fore = 14                       'Yellow foreground with
   TTY.Back = 1                        'Blue background

'-----  Display ANSI background screen
   OPEN "COMPUTER.ANS" FOR BINARY AS #1
   DO
      AnsiIn$ = INPUT$(128, #1)
      AnsiPrint AnsiIn$
   LOOP UNTIL EOF(1)
   CLOSE #1

'-----  Start our message display
   GOSUB DisplayMessage
   ON TIMER(5) GOSUB DisplayMessage
   TIMER ON

'-----  Now do our main display
   SetTTYWindow 2                      'TTY window 2 active

   TTYPrint CHR$(12)                   'Does a window CLS
   TTYPrint "Welcome to the PDQComm " + CR$
   TTYPrint "terminal emulation demo." + CR$
   TTYPrint "This demo is currently " + CR$
   TTYPrint "using 2 different terminal" + CR$
   TTYPrint "emulations in three " + CR$
   TTYPrint "different windows." + CR$
   TTYPrint CR$ + "Press any key to continue"
   DO
   LOOP UNTIL LEN(INKEY$)

   TTYPrint CHR$(12)
   TTYPrint "The computer background was" + CR$
   TTYPrint "drawn using ANSI emulation," + CR$
   TTYPrint "while this window and the " + CR$
   TTYPrint "one at the top of the " + CR$
   TTYPrint "screen are using TTY " + CR$
   TTYPrint "emulation." + CR$
   TTYPrint CR$ + "Press any key to continue"
   DO
   LOOP UNTIL LEN(INKEY$)

   TTYPrint CHR$(12)
   TTYPrint "The computer on your screen" + CR$
   TTYPrint "will now display what you" + CR$
   TTYPrint "type. Please press Escape" + CR$
   TTYPrint "to quit this demo." + CR$

   LOCATE , , 1                        'Turn cursor on
   DO                                  'Work like a typewriter
      A$ = INKEY$
      IF A$ = CHR$(27) THEN EXIT DO
      IF A$ = CHR$(13) THEN A$ = CR$
      IF LEN(A$) THEN TTYPrint A$
   LOOP

CLS                                    'All done
END


'-----  Subroutine that displays messages in window 1
DisplayMessage:
   SetTTYWindow 1                      'Make window 1 active
   TTYPrint Message$(CurMsg)           'Print current message
   CurMsg = CurMsg + 1                 'Increment message counter
   IF CurMsg > 10 THEN CurMsg = 1      'Roll over message counter
   SetTTYWindow 2                      'Make window 2 active
   TTYPrint ""                         'This forces cursor back to window 2
RETURN
