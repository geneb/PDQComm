'=============================================================================
' VT52DISP.BAS
'
' VT52 windowed emulation.
'
' VT52Init Subroutine: Initializes all variables. Sets window to 1,1 - 25,80.
'                      Sets default colors to White - Foreground, Black -
'                      Background. Sets cursor to 1,1. Must be called !!!
'
' VT52Print Subroutine: Use this instead of PRINT to display text to the
'                      screen. Will print inside a 'Window' that you specify.
'
' SetVT52Window Subroutine:  Changes window VT52Print will print. To use,
'                      you must uncomment out the code below and set
'                      NumWindows to the number of windows you will be using.
'
' Include Files:
' Term.BI -   Defines the TermType Type
'    TYPE TermType
'       Monitor  AS INTEGER      True if you have a mono monitor else false
'       Bios     AS INTEGER      True if you want printing thru the BIOS
'                                instead of direct screen writes. Default
'                                is false (direct screen writes).
'       Fore     AS INTEGER      Current foreground color
'       Back     AS INTEGER      Current background color
'       TRow     AS INTEGER      Top row of window. Default is 1.
'       BRow     AS INTEGER      Bottom row of window. Default is 25.
'       LCol     AS INTEGER      Left column of window. Default is 1.
'       RCol     AS INTEGER      Right column of window. Default is 80.
'       CurRow   AS INTEGER      Location of cursor (row).
'       CurCol   AS INTEGER      Location of cursor (column).
'       DefFore  AS INTEGER      Default foreground color. Default is 7.
'       DefBack  AS INTEGER      Default background color. Default is 0.
'    END TYPE
'
' VT52.BI -   Declares routines and allocates a COMMON SHARED variable named
'             VT52 that is TermType.
' Copyright (c) 1991 Clearware Computing, By David Cleary
'=============================================================================

'*****************************************************************************
'
' .001 - 5/7/92 -    Fixed bug where an extra line feed was inserted if
'                    the length of the line was exactly the same as the
'                    right column. Speeded up all emulators by reducing
'                    the amount of times the cursor is updated.
'
' .002 - 9/22/92 -   Changed the variable, "Control" to "Ctrl" for
'                    compatibility with Visual Basic for DOS.
'
' .003 - 11/28/92 -  Changed the way some things are done to get Desqview
'                    not to crash. Also, fixed a bug introduced with change
'                    .002 that caused AnsiDisp to never line feed when doing
'                    single characters.
'
'*****************************************************************************

DEFINT A-Z

DECLARE FUNCTION PDQValI% (Text$)            'PDQ's replacement for VAL
DECLARE FUNCTION PDQMonitor% ()              'Determines type of video display
DECLARE FUNCTION ScanCodes% (Start%, Strng$) 'Scans a string looking for
                                             '  control codes
DECLARE FUNCTION OneColor% (Fore%, Back%)    'Creates a combined foreground
                                             '  and background value
DECLARE SUB PDQPrint (Text$, Row%, Col%, Colr%)  'Direct screen writes
DECLARE SUB BIOSPrint (Text$, Row%, Col%, Colr%) 'BIOS screen writes
DECLARE SUB WScroll (Wind AS ANY, Num%, UpDn%)   'Scrolls the screen

'$INCLUDE: 'TERM.BI'                   'Necessary include files
'$INCLUDE: 'VT52.BI'

DIM SHARED TempRow, TempCol            'Static variables

CONST TabStop = 8                      'Tab stop setting

'*****************************************************************************
'  Multiple window interface. To use, uncomment out the following lines. Set
'  the NumWindows constant to the maximun number of windows you will be using.
'  Use the SetVT52Window subroutine to switch active windows.
'*****************************************************************************

'CONST NumWindows = 4                 'Have 4 windows
'DIM SHARED Windows(1 TO NumWindows) AS TermType
'DIM SHARED WinTmpR(1 TO NumWindows), WinTmpC(1 TO NumWindows)

'SUB SetVT52Window (WinNum%) STATIC

'IF WinNum < 1 OR WinNum > NumWindows THEN EXIT SUB
'IF PreviousWin = 0 THEN PreviousWin = 1

'Windows(PreviousWin) = VT52
'WinTmpR(PreviousWin) = TempRow
'WinTmpC(PreviousWin) = TempCol
'VT52 = Windows(WinNum)
'TempRow = WinTmpR(WinNum)
'TempCol = WinTmpC(WinNum)
'PreviousWin = WinNum

'END SUB

'*****************************************************************************
'  End of multiple window interface.
'*****************************************************************************

SUB VT52Init STATIC                    'Initializes necessary variables

    DEF SEG = 0                         'Check for color or mono monitor
    IF PEEK(&H463) = &HB4 THEN
       VT52.Monitor = -1                'mono
    ELSE
       VT52.Monitor = 0                 'color
    END IF
    DEF SEG

    VT52.Fore = 7
    VT52.DefFore = VT52.Fore            'Default foreground color
    VT52.Back = 0
    VT52.DefBack = VT52.Back            'Default background color
    VT52.TRow = 1                       'Default window is fullscreen
    VT52.CurRow = VT52.TRow
    VT52.BRow = 25
    VT52.LCol = 1
    VT52.CurCol = VT52.LCol
    VT52.RCol = 80

END SUB

SUB VT52Print (VT52Strng$) STATIC      'Does the displaying of text

GOSUB VT52Locate                        'Set everything up
Start = 1
Strng$ = Remain$ + VT52Strng$
StrLen = LEN(Strng$)

DO
   Ctrl = ScanCodes(Start, Strng$)  'Look for control codes
   IF Ctrl THEN
      Txt$ = MID$(Strng$, Start, Ctrl - Start)
      Remain$ = MID$(Strng$, Ctrl)
      VT52Char = ASC(Remain$)
      GOSUB VT52Output

      SELECT CASE VT52Char            'Take action on cotrol code

      CASE 7                           'Bell
          BEEP

      CASE 8                           'BackSpace
          VT52.CurCol = VT52.CurCol - 1
          GOSUB VT52Locate
          Txt$ = " "
          GOSUB VT52Output
          VT52.CurCol = VT52.CurCol - 1
          GOSUB VT52Locate

      CASE 9                           'Tab
          VT52.CurCol = VT52.CurCol + TabStop
          GOSUB VT52Locate

      CASE 10                          'Newline
          VT52.CurRow = VT52.CurRow + 1
          IF VT52.CurRow > VT52.BRow THEN
             NumScrolls = 1
             GOSUB VT52Scroll
             VT52.CurRow = VT52.CurRow - 1
          END IF
          GOSUB VT52Locate

      CASE 12                          'Clear screen
          NumScrolls = VT52.BRow - VT52.TRow + 1
          GOSUB VT52Scroll
          VT52.CurRow = VT52.TRow
          VT52.CurCol = VT52.LCol
          GOSUB VT52Locate

      CASE 13                          'Carriage return
          VT52.CurCol = VT52.LCol
          GOSUB VT52Locate

      CASE 27                          'VT52 escape sequence
          IF Ctrl = StrLen THEN
             LOCATE VT52.CurRow, VT52.CurCol
             EXIT SUB
          END IF

          LenRem = LEN(Remain$)
          Term = ASC(MID$(Remain$, 2, 1))

          SELECT CASE Term

              CASE 65                    'Cursor Up
                  VT52.CurRow = VT52.CurRow - 1
                  GOSUB VT52Locate

              CASE 66                    'Cursor Down
                  VT52.CurRow = VT52.CurRow + 1
                  GOSUB VT52Locate

              CASE 67                    'Cursor Right
                  VT52.CurCol = VT52.CurCol + 1
                  GOSUB VT52Locate

              CASE 68                    'Cursor Left
                  VT52.CurCol = VT52.CurCol - 1
                  GOSUB VT52Locate

              CASE 70, 71                'Unsupported graphics characters

              CASE 72                    'Cursor home
                  VT52.CurRow = VT52.TRow
                  VT52.CurCol = VT52.LCol
                  GOSUB VT52Locate

              CASE 73                    'Reverse linefeed
                  VT52.CurRow = VT52.CurRow - 1
                  IF VT52.CurRow < VT52.TRow THEN
                     WScroll VT52, 1, -1
                  END IF
                  GOSUB VT52Locate

              CASE 74                    'Erase to end of screen
                  Txt$ = SPACE$((VT52.RCol - VT52.CurCol) + 1)
                  IF VT52.Bios THEN
                     BIOSPrint Txt$, VT52.CurRow, VT52.CurCol, OneColor(VT52.Fore, VT52.Back)
                  ELSE
                     PDQPrint Txt$, VT52.CurRow, VT52.CurCol, OneColor(VT52.Fore, VT52.Back)
                  END IF
                  Txt$ = SPACE$((VT52.RCol - VT52.LCol) + 1)
                  FOR I = VT52.CurRow + 1 TO VT52.BRow
                      IF VT52.Bios THEN
                         BIOSPrint Txt$, I, VT52.LCol, OneColor(VT52.Fore, VT52.Back)
                      ELSE
                         PDQPrint Txt$, I, VT52.LCol, OneColor(VT52.Fore, VT52.Back)
                      END IF
                  NEXT

              CASE 75                    'Erase EOL
                  Txt$ = SPACE$((VT52.RCol - VT52.CurCol) + 1)
                  IF VT52.Bios THEN
                     BIOSPrint Txt$, VT52.CurRow, VT52.CurCol, OneColor(VT52.Fore, VT52.Back)
                  ELSE
                     PDQPrint Txt$, VT52.CurRow, VT52.CurCol, OneColor(VT52.Fore, VT52.Back)
                  END IF

              CASE 89
                  IF LenRem < 4 THEN
                     LOCATE VT52.CurRow, VT52.CurCol
                     EXIT SUB
                  END IF
                  VT52.CurRow = VT52.TRow + ASC(MID$(Remain$, 3, 1)) - 32
                  VT52.CurCol = VT52.LCol + ASC(MID$(Remain$, 4, 1)) - 32
                  GOSUB VT52Locate
                  Ctrl = Ctrl + 2

              CASE 90                    'Unsupported IDENTIFY

              CASE 60, 61, 62            'Unsupported mode switch

          END SELECT

          Ctrl = Ctrl + 1

      END SELECT

      Start = Ctrl + 1
   ELSE
      EXIT DO
   END IF

LOOP

Txt$ = MID$(Strng$, Start)
GOSUB VT52Output
Remain$ = ""
LOCATE VT52.CurRow, VT52.CurCol
EXIT SUB

'*****************************************************************************
'  VT52Print GOSUBS
'*****************************************************************************

VT52Output:
    OutLen = LEN(Txt$)
    IF (VT52.CurCol + OutLen) > VT52.RCol + 1 THEN
       OutLft = VT52.RCol - VT52.CurCol + 1
       IF VT52.Bios THEN
          BIOSPrint LEFT$(Txt$, OutLft), VT52.CurRow, VT52.CurCol, OneColor(VT52.Fore, VT52.Back)
       ELSE
          PDQPrint LEFT$(Txt$, OutLft), VT52.CurRow, VT52.CurCol, OneColor(VT52.Fore, VT52.Back)
       END IF
       VT52.CurCol = VT52.LCol
       VT52.CurRow = VT52.CurRow + 1
       IF VT52.CurRow > VT52.BRow THEN
          NumScrolls = 1
          GOSUB VT52Scroll
       END IF
       GOSUB VT52Locate
       Txt$ = MID$(Txt$, OutLft + 1)
       GOTO VT52Output
    ELSE
       IF VT52.Bios THEN
          BIOSPrint Txt$, VT52.CurRow, VT52.CurCol, OneColor(VT52.Fore, VT52.Back)
       ELSE
          PDQPrint Txt$, VT52.CurRow, VT52.CurCol, OneColor(VT52.Fore, VT52.Back)
       END IF
       VT52.CurCol = VT52.CurCol + OutLen
       GOSUB VT52Locate
    END IF
RETURN

VT52Locate:
    IF VT52.CurRow < VT52.TRow THEN VT52.CurRow = VT52.TRow
    IF VT52.CurRow > VT52.BRow THEN VT52.CurRow = VT52.BRow
    IF VT52.CurCol < VT52.LCol THEN VT52.CurCol = VT52.LCol
    IF VT52.CurCol > VT52.RCol THEN VT52.CurCol = VT52.RCol
RETURN

VT52Scroll:
    WScroll VT52, NumScrolls, 0
RETURN

END SUB
