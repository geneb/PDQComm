'=============================================================================
' TTYDISP.BAS
'
' TTY windowed emulation.
'
' TTYInit Subroutine: Initializes all variables. Sets window to 1,1 - 25,80.
'                      Sets default colors to White - Foreground, Black -
'                      Background. Sets cursor to 1,1. Must be called !!!
'
' TTYPrint Subroutine: Use this instead of PRINT to display text to the
'                      screen. Will print inside a 'Window' that you specify.
'
' SetTTYWindow Subroutine:  Changes window TTYPrint will print. To use,
'                      you must uncomment out the code below and set
'                      NumWindows to the number of windows you will be using.
'
' Include Files:
' Term.BI -   Defines the TermType Type
'    TYPE TermType
'       Monitor  AS INTEGER        True if you have a mono monitor else false
'       Bios     AS INTEGER        True if you want printing thru the BIOS
'                                  instead of direct screen writes. Default
'                                  is false (direct screen writes).
'       Fore     AS INTEGER        Current foreground color
'       Back     AS INTEGER        Current background color
'       TRow     AS INTEGER        Top row of window. Default is 1.
'       BRow     AS INTEGER        Bottom row of window. Default is 25.
'       LCol     AS INTEGER        Left column of window. Default is 1.
'       RCol     AS INTEGER        Right column of window. Default is 80.
'       CurRow   AS INTEGER        Location of cursor (row).
'       CurCol   AS INTEGER        Location of cursor (column).
'       DefFore  AS INTEGER        Default foreground color. Default is 7.
'       DefBack  AS INTEGER        Default background color. Default is 0.
'    END TYPE
'
' TTY.BI -   Declares routines and allocates a COMMON SHARED variable named
'             TTY that is TermType.
' Copyright (c) 1991 Clearware Computing, By David Cleary
'=============================================================================

'*****************************************************************************
'
' .001 - 5/7/92 -    Fixed bug where an extra line feed was inserted if
'                    the length of the line was exactly the same as the
'                    right column. Speeded up all emulators by reducing
'                    the amount of times the cursor is updated.
'
' .002  9/22/92 -    Changed variable "Control" to "Ctrl" for compatibility
'                    with Visual Basic for DOS
'
' .003 - 11/28/92 -  Changed the way some things are done to get Desqview
'                    not to crash. Also, fixed a bug introduced with change
'                    .001 that caused AnsiDisp to never line feed when doing
'                    single characters.
'
'*****************************************************************************

DEFINT A-Z

DECLARE FUNCTION PDQValI% (Text$)            'PDQ's replacement for VAL
DECLARE FUNCTION ScanCodes% (Start%, Strng$) 'Scans a string looking for
                                             '  control codes
DECLARE FUNCTION OneColor% (Fore%, Back%)    'Creates a combined foreground
                                             '  and background value
DECLARE SUB PDQPrint (Text$, Row%, Col%, Colr%)  'Direct screen writes
DECLARE SUB BIOSPrint (Text$, Row%, Col%, Colr%) 'BIOS screen writes
DECLARE SUB WScroll (Wind AS ANY, Num%, UpDn%)   'Scrolls the screen

'$INCLUDE: 'TERM.BI'                             'Required include files
'$INCLUDE: 'TTY.BI'

DIM SHARED TempRow, TempCol            'Static variables

CONST TabStop = 8                      'Tab stop setting

'*****************************************************************************
' Multiple window interface. To use, uncomment out the following lines. Set
' the NumWindows constant to the maximum number of windows you will be using.
' Use the SetTTYWindow subroutine to switch active windows.
'*****************************************************************************

'CONST NumWindows = 4                 'Have 4 windows
'DIM SHARED Windows(1 TO NumWindows) AS TermType
'DIM SHARED WinTmpR(1 TO NumWindows), WinTmpC(1 TO NumWindows)

'SUB SetTTYWindow (WinNum%) STATIC

'IF WinNum < 1 OR WinNum > NumWindows THEN EXIT SUB
'IF PreviousWin = 0 THEN PreviousWin = 1

'Windows(PreviousWin) = TTY
'WinTmpR(PreviousWin) = TempRow
'WinTmpC(PreviousWin) = TempCol
'TTY = Windows(WinNum)
'TempRow = WinTmpR(WinNum)
'TempCol = WinTmpC(WinNum)
'PreviousWin = WinNum

'END SUB

'*****************************************************************************
'  End of multiple window interface.
'*****************************************************************************

SUB TTYInit STATIC                 'Initializes necessary variables

   DEF SEG = 0                         'Check for color or mono monitor
   IF PEEK(&H463) = &HB4 THEN
      TTY.Monitor = -1                 'Mono
   ELSE
      TTY.Monitor = 0                  'Color
   END IF
   DEF SEG

   TTY.Fore = 7
   TTY.DefFore = TTY.Fore              'Default foreground color
   TTY.Back = 0
   TTY.DefBack = TTY.Back              'Default background color
   TTY.TRow = 1                        'Default window is fullscreen
   TTY.CurRow = TTY.TRow
   TTY.BRow = 25
   TTY.LCol = 1
   TTY.CurCol = TTY.LCol
   TTY.RCol = 80

END SUB

SUB TTYPrint (TTYStrng$) STATIC        'Does the displaying of text

GOSUB TTYLocate                         'Set everything up
Start = 1
Strng$ = TTYStrng$
StrLen = LEN(Strng$)

DO
   Ctrl = ScanCodes(Start, Strng$)  'Look for control codes
   IF Ctrl THEN
      Txt$ = MID$(Strng$, Start, Ctrl - Start)
      Remain$ = MID$(Strng$, Ctrl)
      TTYChar = ASC(Remain$)
      GOSUB TTYOutput

      SELECT CASE TTYChar              'Take action on control code

      CASE 7                           'Bell
         BEEP

      CASE 8                           'BackSpace
         TTY.CurCol = TTY.CurCol - 1
         GOSUB TTYLocate
         Txt$ = " "
         GOSUB TTYOutput
         TTY.CurCol = TTY.CurCol - 1
         GOSUB TTYLocate

      CASE 9                           'Tab
         TTY.CurCol = TTY.CurCol + TabStop
         GOSUB TTYLocate

      CASE 10                          'Newline
         LineFeed = 0
         TTY.CurRow = TTY.CurRow + 1
         IF TTY.CurRow > TTY.BRow THEN
            WScroll TTY, 1, 0
            TTY.CurRow = TTY.CurRow - 1
         END IF
         GOSUB TTYLocate

      CASE 12                          'Clear screen
         NumScrolls = TTY.BRow - TTY.TRow + 1
         Txt$ = SPACE$(TTY.RCol - TTY.LCol + 1)
         FOR I = 0 TO NumScrolls
            IF TTY.Bios THEN
               BIOSPrint Txt$, TTY.TRow + I, TTY.LCol, OneColor(TTY.Fore, TTY.Back)
            ELSE
               PDQPrint Txt$, TTY.TRow + I, TTY.LCol, OneColor(TTY.Fore, TTY.Back)
            END IF
         NEXT
         TTY.CurRow = TTY.TRow
         TTY.CurCol = TTY.LCol

      CASE 13                          'Carriage return
         LineFeed = 0
         IF AddLineFeeds THEN
            TTY.CurRow = TTY.CurRow + 1
            IF TTY.CurRow > TTY.BRow THEN
               WScroll TTY, 1, 0
               TTY.CurRow = TTY.CurRow - 1
             END IF
          END IF
          TTY.CurCol = TTY.LCol
          GOSUB TTYLocate

      END SELECT

      Start = Ctrl + 1
   ELSE
      IF LineFeed THEN
         TTY.CurRow = TTY.CurRow + 1
         TTY.CurCol = TTY.LCol
         IF TTY.CurRow > TTY.BRow THEN
            WScroll TTY, 1, 0
            TTY.CurCol = TTY.CurCol - 1
         END IF
         GOSUB TTYLocate
         LineFeed = 0
      END IF
      EXIT DO
   END IF

LOOP

Txt$ = MID$(Strng$, Start)
GOSUB TTYOutput
LOCATE TTY.CurRow, TTY.CurCol
EXIT SUB

'*****************************************************************************
'  TTYPrint GOSUBS
'*****************************************************************************

TTYOutput:
   OutLen = LEN(Txt$)
   IF OutLen = 0 THEN RETURN
   IF (TTY.CurCol + OutLen) > TTY.RCol + 1 THEN
      OutLft = TTY.RCol - TTY.CurCol + 1
      IF TTY.Bios THEN
         BIOSPrint LEFT$(Txt$, OutLft), TTY.CurRow, TTY.CurCol, OneColor(TTY.Fore, TTY.Back)
      ELSE
         PDQPrint LEFT$(Txt$, OutLft), TTY.CurRow, TTY.CurCol, OneColor(TTY.Fore, TTY.Back)
      END IF
      TTY.CurCol = TTY.LCol
      TTY.CurRow = TTY.CurRow + 1
      IF TTY.CurRow > TTY.BRow THEN
         WScroll TTY, 1, 0
         TTY.CurRow = TTY.CurRow - 1
      END IF
      GOSUB TTYLocate
      Txt$ = MID$(Txt$, OutLft + 1)
      GOTO TTYOutput
   ELSE
      IF TTY.Bios THEN
         BIOSPrint Txt$, TTY.CurRow, TTY.CurCol, OneColor(TTY.Fore, TTY.Back)
      ELSE
         PDQPrint Txt$, TTY.CurRow, TTY.CurCol, OneColor(TTY.Fore, TTY.Back)
      END IF
      TTY.CurCol = TTY.CurCol + OutLen
      IF TTY.CurCol > TTY.RCol THEN LineFeed = -1
      GOSUB TTYLocate
   END IF
RETURN

TTYLocate:
   IF TTY.CurRow < TTY.TRow THEN TTY.CurRow = TTY.TRow
   IF TTY.CurRow > TTY.BRow THEN TTY.CurRow = TTY.BRow
   IF TTY.CurCol < TTY.LCol THEN TTY.CurCol = TTY.LCol
   IF TTY.CurCol > TTY.RCol THEN TTY.CurCol = TTY.RCol
RETURN

END SUB
