'=============================================================================
' D215DISP.BAS
'
' Data General D215 windowed emulation.
'
' D215Init Subroutine: Initializes all variables. Sets window to 1,1 - 24,80.
'                      Sets default colors to White - Foreground, Black -
'                      Background. Sets cursor to 1,1. Must be called !!!
'
' D215Print Subroutine: Use this instead of PRINT to display text to the
'                      screen. Will print inside a 'Window' that you specify.
'
' SetD215Window Subroutine: Changes window AnsiPrint will print. To use,
'                      you must uncomment out the code below and set
'                      NumWindows to the number of windows you will be using.
'
' Include Files:
' Term.BI -   Defines the TermType Type
'    TYPE TermType
'       Monitor  AS INTEGER      True if you have a mono monitor else false
'       Bios     AS INTEGER      True if you want printing through the BIOS
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
' D215.BI -   Declares routines and allocates a COMMON SHARED variable named
'             DG that is TermType.
' Copyright (c) 1990 Clearware Computing, By David Cleary
'=============================================================================

'*****************************************************************************
'
' .001 - 5/1/91 -    Fixed cursor location bug when cursor was at a window
'                    boundary.
'
' .002 - 5/7/92 -    Fixed bug where an extra line feed was inserted if
'                    the length of the line was exactly the same as the
'                    right column. Speeded up all emulators by reducing
'                    the amount of times the cursor is updated.
'
' .003  9/22/92 -    Changed variable "Control" to "Ctrl" for compatibility
'                    with Visual Basic for DOS
'
' .004 - 11/28/92 -  Changed the way some things are done to get Desqview
'                    not to crash. Also, fixed a bug introduced with change
'                    .002 that caused AnsiDisp to never line feed when doing
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

'$INCLUDE: 'TERM.BI'                         'Required include files
'$INCLUDE: 'D215.BI'

DIM SHARED Remain$, TempRow, TempCol, BlinkDisable 'Static variables

CONST TabStop = 8                      'Tab stop setting

'*****************************************************************************
'  Multiple window interface. To use, uncomment out the following lines. Set
'  the NumWindows constant to the maximum number of windows you will be using.
'  Use the SetAnsiWindow subroutine to switch active windows.
'*****************************************************************************

'CONST NumWindows = 4                  'Have 4 windows
'DIM SHARED Windows(1 TO NumWindows) AS TermType, WinRem$(1 TO NumWindows)
'DIM SHARED WinTmpR(1 TO NumWindows), WinTmpC(1 TO NumWindows)
'DIM SHARED WinBlnkDis(1 TO NumWindows)

'SUB SetAnsiWindow (WinNum%) STATIC

'IF WinNum < 1 OR WinNum > NumWindows THEN EXIT SUB
'IF PreviousWin = 0 THEN PreviousWin = 1

'Windows(PreviousWin) = D215
'WinRem$(PreviousWin) = Remain$
'WinTmpR(PreviousWin) = TempRow
'WinTmpC(PreviousWin) = TempCol
'WinBlnkDis(PreviousWin) = BlinkDisable
'D215 = Windows(WinNum)
'Remain$ = WinRem$(WinNum)
'TempRow = WinTmpR(WinNum)
'TempCol = WinTmpC(WinNum)
'BlinkDisable = WinBlnkDis(WinNum)
'PreviousWin = WinNum

'END SUB

'*****************************************************************************
'  End of multiple window interface.
'*****************************************************************************

SUB D215Init STATIC

    DEF SEG = 0                         'Check for color or mono monitor
    IF PEEK(&H463) = &HB4 THEN
       D215.Monitor = -1                'mono
    ELSE
       D215.Monitor = 0                 'color
    END IF
    DEF SEG

    D215.Fore = 7
    D215.DefFore = D215.Fore            'Default foreground color
    D215.Back = 0
    D215.DefBack = D215.Back            'Default background color
    D215.TRow = 1                       'Default window is 1,1 - 24,80
    D215.CurRow = D215.TRow
    D215.BRow = 24
    D215.LCol = 1
    D215.CurCol = D215.LCol
    D215.RCol = 80

END SUB

SUB D215Print (D215Strng$) STATIC

GOSUB D215Locate                       'Set everything up
Start = 1
Strng$ = Remain$ + D215Strng$
StrLen = LEN(Strng$)

DO
   Ctrl = ScanCodes(Start, Strng$)     'Look for control codes
   IF Ctrl THEN
      Txt$ = MID$(Strng$, Start, Ctrl - Start)
      Remain$ = MID$(Strng$, Ctrl)
      D215Char = ASC(Remain$)
      GOSUB D215Output

      SELECT CASE D215Char             'Take action on control codes

      CASE &O2                         'Reverse video off
         D215.Fore = D215.DefFore
         D215.Back = D215.DefBack

      CASE &O3                         'Blink enable
         BlinkDisable = 0

      CASE &O4                         'Blink disable
         BlinkDisable = -1

      CASE &O7                         'Bell
         BEEP

      CASE &O10, &O14                  'Clear screen / Cursor Home
         D215.Fore = D215.DefFore
         D215.Back = D215.DefBack
         Txt$ = SPACE$(D215.RCol - D215.LCol + 1)
         NumScrolls = D215.BRow - D215.TRow
         FOR I = 0 TO NumScrolls
            IF D215.Bios THEN
               BIOSPrint Txt$, D215.TRow + I, D215.LCol, OneColor(D215.Fore, D215.Back)
            ELSE
               PDQPrint Txt$, D215.TRow + I, D215.LCol, OneColor(D215.Fore, D215.Back)
            END IF
         NEXT
         D215.CurRow = D215.TRow
         D215.CurCol = D215.LCol
         GOSUB D215Locate

      CASE &O12                        'Newline
         LineFeed = 0
         D215.CurRow = D215.CurRow + 1
         IF D215.CurRow > D215.BRow THEN
            WScroll D215, 1, 0
            D215.CurRow = D215.CurRow - 1
         END IF
         D215.CurCol = D215.LCol
         GOSUB D215Locate

      CASE &O13                        'Erase EOL
         Txt$ = SPACE$((D215.RCol - D215.CurCol) + 1)
         IF D215.Bios THEN
            BIOSPrint Txt$, D215.CurRow, D215.CurCol, OneColor(D215.Fore, D215.Back)
         ELSE
            PDQPrint Txt$, D215.CurRow, D215.CurCol, OneColor(D215.Fore, D215.Back)
         END IF

      CASE &O15                        'Carriage return
         LineFeed = 0
         D215.CurCol = D215.LCol
         GOSUB D215Locate

      CASE &O16                        'Blink On
         IF NOT (BlinkDisable) THEN D215.Fore = D215.Fore OR &H10

      CASE &O17                        'Blink Off
         D215.Fore = D215.Fore AND &HF

      CASE &O20                        'Locate Cursor
         IF StrLen < Ctrl + 2 THEN
            LOCATE D215.CurRow, D215.CurCol
            EXIT SUB
         END IF
         Col = ASC(MID$(Remain$, 2, 1))
         Row = ASC(MID$(Remain$, 3, 1))
         IF Col <> &O177 THEN D215.CurCol = D215.LCol + Col
         IF Row <> &O177 THEN D215.CurRow = D215.TRow + Row
         GOSUB D215Locate
         Ctrl = Ctrl + 2

      CASE &O24                        'Underscore On
         IF D215.Monitor THEN D215.Fore = 1

      CASE &O25                        'Underscore off
         D215.Fore = D215.DefFore

      CASE &O26                        'Reverse video on
         D215.Fore = D215.DefBack
         D215.Back = D215.DefFore

      CASE &O27                        'Cursor Up
         D215.CurRow = D215.CurRow - 1
         IF D215.CurRow < D215.TRow THEN D215.CurRow = D215.BRow
         GOSUB D215Locate

      CASE &O30                        'Cursor Right
         D215.CurCol = D215.CurCol + 1
         IF D215.CurCol > D215.RCol THEN
            D215.CurCol = D215.LCol
            D215.CurRow = D215.CurRow + 1
            IF D215.CurRow > D215.BRow THEN
               WScroll D215, 1, 0
               D215.CurRow = D215.CurRow - 1
            END IF
         END IF
         GOSUB D215Locate

      CASE &O31                        'Cursor Left
         D215.CurCol = D215.CurCol - 1
         IF D215.CurCol < D215.LCol THEN
            D215.CurCol = D215.RCol
            D215.CurRow = D215.CurRow - 1
            IF D215.CurRow < D215.TRow THEN D215.CurRow = D215.BRow
         END IF
         GOSUB D215Locate

      CASE &O32                        'Cursor Down
         D215.CurRow = D215.CurRow + 1
         IF D215.CurRow > D215.BRow THEN D215.CurRow = D215.TRow
         GOSUB D215Locate

      CASE &O34                        'Dim On
         IF NOT (D215.Monitor) THEN D215.Fore = 8

      CASE &O35                        'Dim Off
         D215.Fore = D215.DefFore

      CASE &O36                        'Escape sequence
         IF Ctrl = StrLen THEN
            Remain$ = CHR$(&O36)
            LOCATE D215.CurRow, D215.CurCol
            EXIT SUB
         END IF

         Char = ASC(MID$(Remain$, 2, 1))
         SELECT CASE Char

            CASE &O103                 'Read Model ID
               'ComPrint D215ID$
               Ctrl = Ctrl + 1

            CASE &O104                 'Reverse Video On
               D215.Fore = D215.DefBack
               D215.Back = D215.DefFore
               Ctrl = Ctrl + 1

            CASE &O105                 'Reverse Video Off
               D215.Back = D215.DefBack
               D215.Fore = D215.DefFore
               Ctrl = Ctrl + 1

            CASE &O106
               IF StrLen > Ctrl + 2 THEN
                  Char = ASC(MID$(Remain$, 3, 1))
               ELSE
                  LOCATE D215.CurRow, D215.CurCol
                  EXIT SUB
               END IF

               SELECT CASE Char

                  CASE &O100
                     Ctrl = Ctrl + 2

                  CASE &O106           'Erase to end of screen
                     Txt$ = SPACE$((D215.RCol - D215.CurCol) + 1)
                     IF D215.Bios THEN
                        BIOSPrint Txt$, D215.CurRow, D215.CurCol, OneColor(D215.Fore, D215.Back)
                     ELSE
                        PDQPrint Txt$, D215.CurRow, D215.CurCol, OneColor(D215.Fore, D215.Back)
                     END IF
                     Txt$ = SPACE$((D215.RCol - D215.LCol) + 1)
                     FOR I = D215.CurRow + 1 TO D215.BRow
                        IF D215.Bios THEN
                           BIOSPrint Txt$, I, D215.LCol, OneColor(D215.Fore, D215.Back)
                        ELSE
                           PDQPrint Txt$, I, D215.LCol, OneColor(D215.Fore, D215.Back)
                        END IF
                     NEXT
                     Ctrl = Ctrl + 2

                  CASE &O125, 146
                     Ctrl = Ctrl + 3

                  CASE &O123
                     Ctrl = Ctrl + 4

                  CASE ELSE
                     Ctrl = Ctrl + 1

               END SELECT

            CASE &O117
               Ctrl = Ctrl + 1

         END SELECT

      END SELECT
      Start = Ctrl + 1
   ELSE
      IF LineFeed THEN
         D215.CurRow = D215.CurRow + 1
         D215.CurCol = D215.LCol
         IF D215.CurRow > D215.BRow THEN
            WScroll D215, 1, 0
            D215.CurRow = D215.CurRow - 1
         END IF
         GOSUB D215Locate
         LineFeed = 0
      END IF
      EXIT DO
   END IF

LOOP

Txt$ = MID$(Strng$, Start)
GOSUB D215Output
Remain$ = ""
LOCATE D215.CurRow, D215.CurCol
EXIT SUB

'*****************************************************************************
'  D215Print GOSUBS
'*****************************************************************************

D215Output:
   OutLen = LEN(Txt$)
   IF OutLen = 0 THEN RETURN
   IF (D215.CurCol + OutLen) > D215.RCol + 1 THEN
      OutLft = D215.RCol - D215.CurCol + 1
      IF D215.Bios THEN
         BIOSPrint LEFT$(Txt$, OutLft), D215.CurRow, D215.CurCol, OneColor(D215.Fore, D215.Back)
      ELSE
         PDQPrint LEFT$(Txt$, OutLft), D215.CurRow, D215.CurCol, OneColor(D215.Fore, D215.Back)
      END IF
      D215.CurCol = D215.LCol
      D215.CurRow = D215.CurRow + 1
      IF D215.CurRow > D215.BRow THEN
         WScroll D215, 1, 0
      END IF
      GOSUB D215Locate
      Txt$ = MID$(Txt$, OutLft + 1)
      GOTO D215Output
   ELSE
      IF D215.Bios THEN
         BIOSPrint Txt$, D215.CurRow, D215.CurCol, OneColor(D215.Fore, D215.Back)
      ELSE
         PDQPrint Txt$, D215.CurRow, D215.CurCol, OneColor(D215.Fore, D215.Back)
      END IF
      D215.CurCol = D215.CurCol + OutLen
      IF D215.CurCol > D215.RCol THEN LineFeed = -1
      GOSUB D215Locate
   END IF
RETURN

D215Locate:
   IF D215.CurRow < D215.TRow THEN D215.CurRow = D215.TRow
   IF D215.CurRow > D215.BRow THEN D215.CurRow = D215.BRow
   IF D215.CurCol < D215.LCol THEN D215.CurCol = D215.LCol
   IF D215.CurCol > D215.RCol THEN D215.CurCol = D215.RCol
RETURN

END SUB
