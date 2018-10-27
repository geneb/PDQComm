'=============================================================================
'  ANSIDISP.BAS
'
'  ANSI windowed emulation.
'
'  AnsiInit Subroutine: Initializes all variables. Sets window to 1,1 - 25,80.
'                       Sets default colors to White - Foreground, Black -
'                       Background. Sets cursor to 1,1. Must be called !!!
'
'  AnsiPrint Subroutine: Use this instead of PRINT to display text to the
'                       screen. Will print inside a 'Window' that you specify.
'
'  SetAnsiWindow Subroutine:  Changes window AnsiPrint will print. To use,
'                       you must uncomment out the code below and set
'                       NumWindows to the number of windows you will be using.
'
'  Include Files:
'  Term.BI -   Defines the TermType Type
'     TYPE TermType
'        Monitor  AS INTEGER      True if you have a mono monitor else false
'        Bios     AS INTEGER      True if you want printing thru the BIOS
'                                 instead of direct screen writes. Default
'                                 is false (direct screen writes).
'        Fore     AS INTEGER      Current foreground color
'        Back     AS INTEGER      Current background color
'        TRow     AS INTEGER      Top row of window. Default is 1.
'        BRow     AS INTEGER      Bottom row of window. Default is 25.
'        LCol     AS INTEGER      Left column of window. Default is 1.
'        RCol     AS INTEGER      Right column of window. Default is 80.
'        CurRow   AS INTEGER      Location of cursor (row).
'        CurCol   AS INTEGER      Location of cursor (column).
'        DefFore  AS INTEGER      Default foreground color. Default is 7.
'        DefBack  AS INTEGER      Default background color. Default is 0.
'     END TYPE
'
'  Ansi.BI -   Declares routines and allocates a COMMON SHARED variable named
'              ANSI that is TermType.
'  Copyright (c) 1991 Clearware Computing, By David Cleary
'=============================================================================

'*****************************************************************************
'
' .001 - 9/9/91 -    Fixed cursor position bug when passed a value of 0.
'
' .002 - 5/7/92 -    Fixed bug where an extra line feed was inserted if
'                    the length of the line was exactly the same as the
'                    right column. Speeded up all emulators by reducing
'                    the amount of times the cursor is updated.
'
' .003 - 9/22/92 -   Changed variable "Control" to "Ctrl" for compatibility
'                    with Visual Basic for DOS
'
' .004 - 11/28/92 -  Changed the way some things are done to get Desqview
'                    not to crash. Also, fixed a bug introduced with change
'                    .002 that caused AnsiDisp to never line feed when doing
'                    single characters.
'
' .005 - 1/15/93 -   Mistakenly used MASM comments instead of BASIC comments
'                    on multiple window interface code. Now checks if using 
'                    the BIOS when an ANSI clear screen is issued.
'
'*****************************************************************************

DEFINT A-Z

DECLARE FUNCTION PDQValI% (Text$)       'PDQ's replacement for VAL function
DECLARE FUNCTION ScanCodes% (Start%, Strng$) 'Scans a string looking for
                                             '  control codes
DECLARE FUNCTION OneColor% (Fore%, Back%)    'Creates a combined foreground
                                             '  and background value
DECLARE SUB PDQPrint (Text$, Row%, Col%, Colr%)   'Direct screen writes
DECLARE SUB BIOSPrint (Text$, Row%, Col%, Colr%)  'BIOS screen writes
DECLARE SUB WScroll (Wind AS ANY, Num%, UpDn%)    'Scrolls the screen

'$INCLUDE: 'TERM.BI'                    'Required include files
'$INCLUDE: 'ANSI.BI'

DIM SHARED AnsiChar$, AnsiTerm$, Remain$, TempRow, TempCol  'Static variables

CONST TabStop = 8                       'Tab stop setting

'*****************************************************************************
'  Multiple window interface. To use, uncomment out the following lines. Set
'  the NumWindows constant to the maximum number of windows you will be using.
'  Use the SetAnsiWindow subroutine to switch active windows.
'*****************************************************************************

'CONST NumWindows = 4                   'Have 4 windows
'DIM SHARED Windows(1 TO NumWindows) AS TermType, WinRem$(1 TO NumWindows)
'DIM SHARED WinTmpR(1 TO NumWindows), WinTmpC(1 TO NumWindows)

'SUB SetAnsiWindow (WinNum%) STATIC

'IF WinNum < 1 OR WinNum > NumWindows THEN EXIT SUB
'IF PreviousWin = 0 THEN PreviousWin = 1

'Windows(PreviousWin) = Ansi
'WinRem$(PreviousWin) = Remain$
'WinTmpR(PreviousWin) = TempRow
'WinTmpC(PreviousWin) = TempCol
'Ansi = Windows(WinNum)
'Remain$ = WinRem$(WinNum)
'TempRow = WinTmpR(WinNum)
'TempCol = WinTmpC(WinNum)
'PreviousWin = WinNum

'END SUB

'*****************************************************************************
'  End of multiple window interface.
'*****************************************************************************

SUB AnsiInit STATIC                     'Initializes necessary variables

    AnsiChar$ = "[0123456789;=ABCDHJKfmnsuhl"
    AnsiTerm$ = "ABCDHJKfmnsuh"

    DEF SEG = 0                         'Check for color or mono monitor
    IF PEEK(&H463) = &HB4 THEN
        Ansi.Monitor = -1
    ELSE
        Ansi.Monitor = 0
    END IF
    DEF SEG

    Ansi.Fore = 7
    Ansi.DefFore = Ansi.Fore            'Default foreground color
    Ansi.Back = 0
    Ansi.DefBack = Ansi.Back            'Default background color
    Ansi.TRow = 1                       'Default window is full screen
    Ansi.CurRow = Ansi.TRow
    Ansi.BRow = 25
    Ansi.LCol = 1
    Ansi.CurCol = Ansi.LCol
    Ansi.RCol = 80

END SUB

SUB AnsiPrint (AnsiStrng$) STATIC       'Does the displaying of text

GOSUB AnsiLocate                        'Set everything up
Start = 1
Strng$ = Remain$ + AnsiStrng$
StrLen = LEN(Strng$)

DO
   Ctrl = ScanCodes(Start, Strng$)  'Look for control codes
   IF Ctrl THEN
      Txt$ = MID$(Strng$, Start, Ctrl - Start)
      Remain$ = MID$(Strng$, Ctrl)
      AnsiChar = ASC(Remain$)
      GOSUB AnsiOutput

      SELECT CASE AnsiChar            'Take action on control code

      CASE 7                          'Bell
         BEEP

      CASE 8                          'BackSpace
         Ansi.CurCol = Ansi.CurCol - 1
         GOSUB AnsiLocate
         Txt$ = " "
         GOSUB AnsiOutput
         Ansi.CurCol = Ansi.CurCol - 1
         GOSUB AnsiLocate

      CASE 9                          'Tab
         Ansi.CurCol = Ansi.CurCol + TabStop
         GOSUB AnsiLocate

      CASE 10                         'Newline
         Ansi.CurRow = Ansi.CurRow + 1
         IF Ansi.CurRow > Ansi.BRow THEN
            WScroll Ansi, 1, 0
            Ansi.CurRow = Ansi.CurRow - 1
         END IF
         GOSUB AnsiLocate

      CASE 12                         'Clear screen
         LineFeed = 0
         NumScrolls = Ansi.BRow - Ansi.TRow
         Txt$ = SPACE$(Ansi.RCol - Ansi.LCol + 1)
         FOR I = 0 TO NumScrolls
            IF Ansi.Bios THEN
               BIOSPrint Txt$, Ansi.TRow + I, Ansi.LCol, OneColor(Ansi.Fore, Ansi.Back)
            ELSE
               PDQPrint Txt$, Ansi.TRow + I, Ansi.LCol, OneColor(Ansi.Fore, Ansi.Back)
            END IF
         NEXT
         Ansi.CurRow = Ansi.TRow
         Ansi.CurCol = Ansi.LCol
         GOSUB AnsiLocate

      CASE 13                         'Carriage return
         LineFeed = 0
         Ansi.CurCol = Ansi.LCol
         GOSUB AnsiLocate

      CASE 27                         'ANSI Escape sequence
         IF Ctrl = StrLen THEN
            Remain$ = CHR$(27)
            LOCATE Ansi.CurRow, Ansi.CurCol
            EXIT SUB
         END IF

         RemLen = LEN(Remain$)
         FOR I = 2 TO RemLen
            Char$ = MID$(Remain$, I, 1)

            IF INSTR(AnsiChar$, Char$) = 0 THEN
               Ctrl = Ctrl + I
               GOTO EscDone
            END IF

            IF INSTR(AnsiTerm$, Char$) THEN
               Term = ASC(Char$)
               Remain$ = MID$(Remain$, 3)

               SELECT CASE Term

               CASE 65              'Cursor Up
                  Scratch = PDQValI(Remain$)
                  IF Scratch <= 0 THEN Scratch = 1
                  Ansi.CurRow = Ansi.CurRow - Scratch
                  GOSUB AnsiLocate

               CASE 66              'Cursor Down
                  Scratch = PDQValI(Remain$)
                  IF Scratch <= 0 THEN Scratch = 1
                  Ansi.CurRow = Ansi.CurRow + Scratch
                  GOSUB AnsiLocate

               CASE 67              'Cursor Right
                  Scratch = PDQValI(Remain$)
                  IF Scratch <= 0 THEN Scratch = 1
                  Ansi.CurCol = Ansi.CurCol + Scratch
                  GOSUB AnsiLocate

               CASE 68              'Cursor Left
                  Scratch = PDQValI(Remain$)
                  IF Scratch <= 0 THEN Scratch = 1
                  Ansi.CurCol = Ansi.CurCol - Scratch
                  GOSUB AnsiLocate

               CASE 72, 102         'Set cursor position
                  Ansi.CurRow = Ansi.TRow + PDQValI(Remain$) - 1
                  Scratch = INSTR(LEFT$(Remain$, I), ";")
                  IF Scratch THEN
                     Ansi.CurCol = Ansi.LCol + PDQValI(MID$(Remain$, Scratch + 1)) - 1
                  ELSE
                     Ansi.CurCol = Ansi.LCol
                  END IF
                  GOSUB AnsiLocate

               CASE 74              'CLS
                  NumScrolls = Ansi.BRow - Ansi.TRow
                  Txt$ = SPACE$(Ansi.RCol - Ansi.LCol + 1)
                  FOR J = 0 TO NumScrolls
                     IF Ansi.BIOS THEN
                        BIOSPrint Txt$, Ansi.TRow + J, Ansi.LCol, OneColor(Ansi.Fore, Ansi.Back) 
                     ELSE
                        PDQPrint Txt$, Ansi.TRow + J, Ansi.LCol, OneColor(Ansi.Fore, Ansi.Back)
                     END IF
                  NEXT
                  Ansi.CurRow = Ansi.TRow
                  Ansi.CurCol = Ansi.LCol
                  GOSUB AnsiLocate

               CASE 75              'Erase EOL
                  Txt$ = SPACE$((Ansi.RCol - Ansi.CurCol) + 1)
                  IF Ansi.Bios THEN
                     BIOSPrint Txt$, Ansi.CurRow, Ansi.CurCol, OneColor(Ansi.Fore, Ansi.Back)
                  ELSE
                     PDQPrint Txt$, Ansi.CurRow, Ansi.CurCol, OneColor(Ansi.Fore, Ansi.Back)
                  END IF

               CASE 109             'SetColor
                  SColn = 1
                  FOR J = 1 TO INSTR(Remain$, "m")
                     Char$ = MID$(Remain$, J, 1)
                     IF Char$ <> ";" THEN
                        Scratch = PDQValI(MID$(Remain$, SColn))
                        SELECT CASE Scratch

                        CASE 0      'Norm Atributes
                           Ansi.Fore = Ansi.DefFore
                           Ansi.Back = Ansi.DefBack

                        CASE 1      'Bold
                           Ansi.Fore = Ansi.Fore OR 8

                        CASE 4      'Underline
                           IF Ansi.Monitor THEN Ansi.Fore = 1

                        CASE 5      'Blink
                           IF NOT (Ansi.Monitor) THEN Ansi.Fore = Ansi.Fore OR 16

                        CASE 7      'Reverse video
                           'SWAP Ansi.Fore, Ansi.Back
                           Ansi.Fore = 0  'Reverse video are theses
                           Ansi.Back = 7  'colors according to ANSI.SYS

                        CASE 8      'Concealed on
                           Ansi.Fore = 0
                           Ansi.Back = 0

                        CASE 30, 32, 35, 37
                           IF NOT (Ansi.Monitor) THEN
                              Ansi.Fore = Scratch - 30 OR (Ansi.Fore AND 24)
                           END IF

                        CASE 31, 33
                           IF NOT (Ansi.Monitor) THEN
                              Ansi.Fore = Scratch - 27 OR (Ansi.Fore AND 24)
                           END IF

                        CASE 34, 36
                           IF NOT (Ansi.Monitor) THEN
                              Ansi.Fore = Scratch - 33 OR (Ansi.Fore AND 24)
                           END IF

                        CASE 40, 42, 45, 47
                           IF NOT (Ansi.Monitor) THEN
                              Ansi.Back = Scratch - 40
                           END IF

                        CASE 41, 43
                           IF NOT (Ansi.Monitor) THEN
                              Ansi.Back = Scratch - 37
                           END IF

                        CASE 44, 46
                           IF NOT (Ansi.Monitor) THEN
                              Ansi.Back = Scratch - 43
                           END IF

                        END SELECT
                        J = INSTR(SColn, Remain$, ";")
                        SColn = J + 1
                        IF J = 0 THEN EXIT FOR
                     END IF

                  NEXT J

               CASE 115             'Save cursor position
                  TempRow = Ansi.CurRow
                  TempCol = Ansi.CurCol

               CASE 117             'Restore cursor position
                  IF TempRow THEN
                     Ansi.CurRow = TempRow
                     Ansi.CurCol = TempCol
                     GOSUB AnsiLocate
                  END IF

               END SELECT
               Ctrl = Ctrl + I - 1
               GOTO EscDone
            END IF
         NEXT
         LOCATE Ansi.CurRow, Ansi.CurCol
         EXIT SUB
      END SELECT

EscDone:
      Start = Ctrl + 1
   ELSE
      IF LineFeed THEN
         Ansi.CurRow = Ansi.CurRow + 1
         Ansi.CurCol = Ansi.LCol
         IF Ansi.CurRow > Ansi.BRow THEN
            WScroll Ansi, 1, 0
            Ansi.CurRow = Ansi.CurRow - 1
         END IF
         GOSUB AnsiLocate
         LineFeed = 0
      END IF
      EXIT DO
   END IF

LOOP

Txt$ = MID$(Strng$, Start)
GOSUB AnsiOutput
Remain$ = ""
LOCATE Ansi.CurRow, Ansi.CurCol
EXIT SUB

'*****************************************************************************
'  AnsiPrint GOSUBS
'*****************************************************************************

AnsiOutput:
    OutLen = LEN(Txt$)
    IF OutLen = 0 THEN RETURN
    IF (Ansi.CurCol + OutLen) > Ansi.RCol + 1 THEN
       OutLft = Ansi.RCol - Ansi.CurCol + 1
       IF Ansi.Bios THEN
          BIOSPrint LEFT$(Txt$, OutLft), Ansi.CurRow, Ansi.CurCol, OneColor(Ansi.Fore, Ansi.Back)
       ELSE
          PDQPrint LEFT$(Txt$, OutLft), Ansi.CurRow, Ansi.CurCol, OneColor(Ansi.Fore, Ansi.Back)
       END IF
       Ansi.CurCol = Ansi.LCol
       Ansi.CurRow = Ansi.CurRow + 1
       IF Ansi.CurRow > Ansi.BRow THEN
          WScroll Ansi, 1, 0
       END IF
       GOSUB AnsiLocate
       Txt$ = MID$(Txt$, OutLft + 1)
       GOTO AnsiOutput
    ELSE
       IF Ansi.Bios THEN
          BIOSPrint Txt$, Ansi.CurRow, Ansi.CurCol, OneColor(Ansi.Fore, Ansi.Back)
       ELSE
          PDQPrint Txt$, Ansi.CurRow, Ansi.CurCol, OneColor(Ansi.Fore, Ansi.Back)
       END IF
       Ansi.CurCol = Ansi.CurCol + OutLen
       IF Ansi.CurCol > Ansi.RCol THEN LineFeed = -1
       GOSUB AnsiLocate
    END IF
RETURN

AnsiLocate:
    IF Ansi.CurRow < Ansi.TRow THEN Ansi.CurRow = Ansi.TRow
    IF Ansi.CurRow > Ansi.BRow THEN Ansi.CurRow = Ansi.BRow
    IF Ansi.CurCol < Ansi.LCol THEN Ansi.CurCol = Ansi.LCol
    IF Ansi.CurCol > Ansi.RCol THEN Ansi.CurCol = Ansi.RCol
RETURN

END SUB
