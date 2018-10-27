'=============================================================================
' VT10DISP.BAS
'
' VT100 windowed emulation.
'
' VT100Init Subroutine: Initializes all variables. Sets window to 1,1 - 25,80.
'                       Sets default colors to White - Foreground, Black -
'                       Background. Sets cursor to 1,1. Must be called !!!
'
' VT100Print Subroutine: Use this instead of PRINT to display text to the
'                      screen. Will print inside a 'Window' that you specify.
'
' SetVT100Window Subroutine:  Changes window VT100Print will print. To use,
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
' VT100.BI -   Declares routines and allocates a COMMON SHARED variable named
'             VT100 that is TermType.
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
DECLARE FUNCTION ScanCodes% (Start%, Strng$) 'Scans a string looking for
                                             '  control codes
DECLARE FUNCTION OneColor% (Fore%, Back%)    'Creates a combined foreground
                                             '  and background value
DECLARE SUB PDQPrint (Text$, Row%, Col%, Colr%)  'Direct screen writes
DECLARE SUB BIOSPrint (Text$, Row%, Col%, Colr%) 'BIOS screen writes
DECLARE SUB WScroll (Wind AS ANY, Num%, UpDn%)   'Scrolls the screen

'$INCLUDE: 'TERM.BI'                   'Required include files
'$INCLUDE: 'VT100.BI'

DIM SHARED VT100Term$                  'Global variable

CONST TabStop = 8                      'Tab stop setting

'*****************************************************************************
' Multiple window interface. To use, uncomment out the following lines. Set
' the NumWindows constant to the maximun number of windows you will be using.
' Use the SetVT100Window subroutine to switch active windows.
'*****************************************************************************

'CONST NumWindows = 4                 'Have 4 windows
'DIM SHARED Windows(1 TO NumWindows) AS TermType, WinRem$(1 TO NumWindows)
'DIM SHARED WinTmpR(1 TO NumWindows), WinTmpC(1 TO NumWindows)

'SUB SetVT100Window (WinNum%) STATIC

'IF WinNum < 1 OR WinNum > NumWindows THEN EXIT SUB
'IF PreviousWin = 0 THEN PreviousWin = 1

'Windows(PreviousWin) = VT100
'WinRem$(PreviousWin) = Remain$
'WinTmpR(PreviousWin) = TempRow
'WinTmpC(PreviousWin) = TempCol
'VT100 = Windows(WinNum)
'Remain$ = WinRem$(WinNum)
'TempRow = WinTmpR(WinNum)
'TempCol = WinTmpC(WinNum)
'PreviousWin = WinNum

'END SUB

'*****************************************************************************
'  End of multiple window interface.
'*****************************************************************************

SUB VT100Init STATIC                  'Initializes necessary variables

    VT100Term$ = "ABCDHfmqKJrl"
    DEF SEG = 0                         'Check for color or mono monitor
    IF PEEK(&H463) = &HB4 THEN
        VT100.Monitor = -1
    ELSE
        VT100.Monitor = 0
    END IF
    DEF SEG

    VT100.Fore = 7
    VT100.DefFore = VT100.Fore          'Default foreground color
    VT100.Back = 0
    VT100.DefBack = VT100.Back          'Default background color
    VT100.TRow = 1                      'Default window is fullscreen
    VT100.CurRow = VT100.TRow
    VT100.BRow = 25
    VT100.LCol = 1
    VT100.CurCol = VT100.LCol
    VT100.RCol = 80

END SUB

SUB VT100Print (VT100Strng$) STATIC   'Does the displaying of text.

GOSUB VT100Locate                      'Set everything up
Start = 1
Strng$ = Remain$ + VT100Strng$
StrLen = LEN(Strng$)

DO
   Ctrl = ScanCodes(Start, Strng$)  'Look for control codes
   IF Ctrl THEN
      Txt$ = MID$(Strng$, Start, Ctrl - Start)
      Remain$ = MID$(Strng$, Ctrl)
      VT100Char = ASC(Remain$)
      GOSUB VT100Output

      SELECT CASE VT100Char            'Take action on control code

      CASE 7                           'Bell
         BEEP

      CASE 8                           'BackSpace
         VT100.CurCol = VT100.CurCol - 1
         GOSUB VT100Locate
         Txt$ = " "
         GOSUB VT100Output
         VT100.CurCol = VT100.CurCol - 1
         GOSUB VT100Locate

      CASE 9                           'Tab
         VT100.CurCol = VT100.CurCol + TabStop
         GOSUB VT100Locate

      CASE 10                          'Newline
         LineFeed = 0
         VT100.CurRow = VT100.CurRow + 1
         IF VT100.CurRow > VT100.BRow THEN
            WScroll VT100, 1, 0
            VT100.CurRow = VT100.CurRow - 1
         END IF
         GOSUB VT100Locate

      CASE 12                          'Clear screen
         NumScrolls = VT100.BRow - VT100.TRow + 1
         Txt$ = SPACE$(VT100.RCol - VT100.LCol + 1)
         FOR I = 0 TO NumScrolls
            IF VT100.Bios THEN
               BIOSPrint Txt$, VT100.TRow + I, VT100.LCol, OneColor(VT100.Fore, VT100.Back)
            ELSE
               PDQPrint Txt$, VT100.TRow + I, VT100.LCol, OneColor(VT100.Fore, VT100.Back)
            END IF
         NEXT
         VT100.CurRow = VT100.TRow
         VT100.CurCol = VT100.LCol
         GOSUB VT100Locate

      CASE 13                          'Cariage return
         LineFeed = 0
         VT100.CurCol = VT100.LCol
         GOSUB VT100Locate

      CASE 27                          'VT100 escape sequence
         IF Ctrl = StrLen THEN
            LOCATE VT100.CurRow, VT100.CurCol
            EXIT SUB
         END IF

         Char$ = MID$(Remain$, 2, 1)
         RemLen = LEN(Remain$)
         SELECT CASE Char$

         CASE "#"                 'Unsupported line size modes
            Ctrl = Ctrl + 2

         CASE "(", ")"              'Unsupported Character Sets
            Ctrl = Ctrl + 2

         CASE "["                   'CSI Sequence
            RemLen = LEN(Remain$)
            FOR I = 3 TO RemLen
               Char$ = MID$(Remain$, I, 1)

               IF INSTR(VT100Term$, Char$) THEN
                  Term = ASC(Char$)
                  Remain$ = MID$(Remain$, 3)

                  SELECT CASE Term

                  CASE 65              'Cursor Up
                     Scratch = PDQValI(Remain$)
                     IF Scratch < 1 THEN Scratch = 1
                     VT100.CurRow = VT100.CurRow - Scratch
                     GOSUB VT100Locate

                  CASE 66              'Cursor Down
                     Scratch = PDQValI(Remain$)
                     IF Scratch < 1 THEN Scratch = 1
                     VT100.CurRow = VT100.CurRow + Scratch
                     GOSUB VT100Locate

                  CASE 67              'Cursor Right
                     Scratch = PDQValI(Remain$)
                     IF Scratch < 1 THEN Scratch = 1
                     VT100.CurCol = VT100.CurCol + Scratch
                     GOSUB VT100Locate

                  CASE 68              'Cursor Left
                     Scratch = PDQValI(Remain$)
                     IF Scratch < 1 THEN Scratch = 1
                     VT100.CurCol = VT100.CurCol - Scratch
                     GOSUB VT100Locate

                  CASE 72, 102         'Set cursor position
                     VT100.CurRow = VT100.TRow + PDQValI(Remain$) - 1
                     Scratch = INSTR(LEFT$(Remain$, I), ";")
                     IF Scratch THEN
                        VT100.CurCol = VT100.LCol + PDQValI(MID$(Remain$, Scratch + 1)) - 1
                     ELSE
                        VT100.CurCol = VT100.LCol
                     END IF
                     GOSUB VT100Locate

                  CASE 74              'Screen Clear Functions
                     Scratch = PDQValI(LEFT$(Remain$, 1))
                     SELECT CASE Scratch

                     CASE 0         'From cursor to end of screen
                        Txt$ = SPACE$((VT100.RCol - VT100.CurCol) + 1)
                        IF VT100.Bios THEN
                           BIOSPrint Txt$, VT100.CurRow, VT100.CurCol, OneColor(VT100.Fore, VT100.Back)
                        ELSE
                           PDQPrint Txt$, VT100.CurRow, VT100.CurCol, OneColor(VT100.Fore, VT100.Back)
                        END IF
                        Txt$ = SPACE$((VT100.RCol - VT100.LCol) + 1)
                        FOR J = VT100.CurRow + 1 TO VT100.BRow
                           IF VT100.Bios THEN
                              BIOSPrint Txt$, J, VT100.LCol, OneColor(VT100.Fore, VT100.Back)
                           ELSE
                              PDQPrint Txt$, J, VT100.LCol, OneColor(VT100.Fore, VT100.Back)
                           END IF
                        NEXT

                     CASE 1         'From start of screen to cursor
                        Txt$ = SPACE$((VT100.CurCol - VT100.LCol) + 1)
                        IF VT100.Bios THEN
                           BIOSPrint Txt$, VT100.CurRow, VT100.LCol, OneColor(VT100.Fore, VT100.Back)
                        ELSE
                           PDQPrint Txt$, VT100.CurRow, VT100.LCol, OneColor(VT100.Fore, VT100.Back)
                        END IF
                        Txt$ = SPACE$((VT100.RCol - VT100.LCol) + 1)
                        FOR J = VT100.TRow TO VT100.CurRow - 1
                           IF VT100.Bios THEN
                              BIOSPrint Txt$, J, VT100.LCol, OneColor(VT100.Fore, VT100.Back)
                           ELSE
                              PDQPrint Txt$, J, VT100.LCol, OneColor(VT100.Fore, VT100.Back)
                           END IF
                        NEXT

                     CASE 2       'Entire screen
                        NumScrolls = VT100.BRow - VT100.TRow + 1
                        Txt$ = SPACE$(VT100.RCol - VT100.LCol + 1)
                        FOR I = 0 TO NumScrolls
                           IF VT100.Bios THEN
                              BIOSPrint Txt$, VT100.TRow + I, VT100.LCol, OneColor(VT100.Fore, VT100.Back)
                           ELSE
                              PDQPrint Txt$, VT100.TRow + I, VT100.LCol, OneColor(VT100.Fore, VT100.Back)
                           END IF
                        NEXT
                     END SELECT

                  CASE 75              'Line clear functions
                     Scratch = PDQValI(LEFT$(Remain$, 1))
                     SELECT CASE Scratch

                     CASE 0       'From cursor to end of line
                        Txt$ = SPACE$((VT100.RCol - VT100.CurCol) + 1)
                        IF VT100.Bios THEN
                           BIOSPrint Txt$, VT100.CurRow, VT100.CurCol, OneColor(VT100.Fore, VT100.Back)
                        ELSE
                           PDQPrint Txt$, VT100.CurRow, VT100.CurCol, OneColor(VT100.Fore, VT100.Back)
                        END IF

                     CASE 1       'From start of line to cursor
                        Txt$ = SPACE$((VT100.CurCol - VT100.LCol) + 1)
                        IF VT100.Bios THEN
                           BIOSPrint Txt$, VT100.CurRow, VT100.LCol, OneColor(VT100.Fore, VT100.Back)
                        ELSE
                           PDQPrint Txt$, VT100.CurRow, VT100.LCol, OneColor(VT100.Fore, VT100.Back)
                        END IF

                     CASE 2       'Entire line
                        NumScrolls = VT100.BRow - VT100.TRow + 1
                        Txt$ = SPACE$((VT100.RCol - VT100.LCol) + 1)
                        IF VT100.Bios THEN
                           BIOSPrint Txt$, VT100.CurRow, VT100.LCol, OneColor(VT100.Fore, VT100.Back)
                        ELSE
                           PDQPrint Txt$, VT100.CurRow, VT100.LCol, OneColor(VT100.Fore, VT100.Back)
                        END IF
                     END SELECT

                  CASE 108             'SetMode
                     IF ASC(Remain$) = 63 THEN
                        Mode = PDQValI(MID$(Remain$, 2))
                        SELECT CASE Mode

                        CASE 2
                           VT52Mode = -1
                        END SELECT
                     END IF


                  CASE 109             'SetColor
                     SColn = 1
                     FOR J = 1 TO INSTR(Remain$, "m")
                        Char$ = MID$(Remain$, J, 1)
                        IF Char$ <> ";" THEN
                           Scratch = PDQValI(MID$(Remain$, SColn))
                           SELECT CASE Scratch

                           CASE 0      'Norm Atributes
                              VT100.Fore = VT100.DefFore
                              VT100.Back = VT100.DefBack

                           CASE 1      'Bold.
                              VT100.Fore = VT100.Fore OR 8

                           CASE 4      'Underline.
                              IF VT100.Monitor THEN VT100.Fore = 1

                           CASE 5      'Blink.
                              IF NOT (VT100.Monitor) THEN VT100.Fore = VT100.Fore OR 16

                           CASE 7      'Reverse video.
                              'SWAP VT100.Fore, VT100.Back
                              VT100.Fore = 0  'Reverse video are theses
                              VT100.Back = 7  'colors according to VT100.SYS

                           END SELECT
                        ELSE
                           J = INSTR(SColn, Remain$, ";")
                           SColn = J + 1
                           IF J = 0 THEN EXIT FOR
                        END IF
                     NEXT J

                  CASE 115             'Save cursor position
                     TempRow = VT100.CurRow
                     TempCol = VT100.CurCol

                  CASE 117             'Restore cursor position
                     IF TempRow THEN
                        VT100.CurRow = TempRow
                        VT100.CurCol = TempCol
                        GOSUB VT100Locate
                     END IF

                  END SELECT
                  Ctrl = Ctrl + I - 1
                  GOTO EscDone
               END IF
            NEXT I
            LOCATE VT100.CurRow, VT100.CurCol
            EXIT SUB

         CASE ELSE

            IF VT52Mode THEN        'VT52 Compatable mode
               IF INSTR("ABCDFGHIJKYZ<=>12", Char$) THEN
                  Term = ASC(Char$)

                  SELECT CASE Term

                  CASE 65              'Cursor Up (A)
                     VT100.CurRow = VT100.CurRow - 1
                     GOSUB VT100Locate

                  CASE 66              'Cursor Down (B)
                     VT100.CurRow = VT100.CurRow + 1
                     GOSUB VT100Locate

                  CASE 67              'Cursor Right (C)
                     VT100.CurCol = VT100.CurCol + 1
                     GOSUB VT100Locate

                  CASE 68              'Cursor Left (D)
                     VT100.CurCol = VT100.CurCol - 1
                     GOSUB VT100Locate

                  CASE 70, 71          'Unsupported graphics characters (F,G)

                  CASE 72              'Cursor home (H)
                     VT100.CurRow = VT100.TRow
                     VT100.CurCol = VT100.LCol
                     GOSUB VT100Locate

                  CASE 73              'Reverse linefeed (I)
                     VT100.CurRow = VT100.CurRow - 1
                     IF VT100.CurRow < VT100.TRow THEN
                        WScroll VT100, 1, -1
                     END IF
                     GOSUB VT100Locate

                  CASE 74              'Erase to end of screen  (J)
                     Txt$ = SPACE$((VT100.RCol - VT100.CurCol) + 1)
                     IF VT100.Bios THEN
                        BIOSPrint Txt$, VT100.CurRow, VT100.CurCol, OneColor(VT100.Fore, VT100.Back)
                     ELSE
                        PDQPrint Txt$, VT100.CurRow, VT100.CurCol, OneColor(VT100.Fore, VT100.Back)
                     END IF
                     Txt$ = SPACE$((VT100.RCol - VT100.LCol) + 1)
                     FOR I = VT100.CurRow + 1 TO VT100.BRow
                        IF VT100.Bios THEN
                           BIOSPrint Txt$, I, VT100.LCol, OneColor(VT100.Fore, VT100.Back)
                        ELSE
                           PDQPrint Txt$, I, VT100.LCol, OneColor(VT100.Fore, VT100.Back)
                        END IF
                     NEXT

                  CASE 75              'Erase EOL  (K)
                     Txt$ = SPACE$((VT100.RCol - VT100.CurCol) + 1)
                     IF VT100.Bios THEN
                        BIOSPrint Txt$, VT100.CurRow, VT100.CurCol, OneColor(VT100.Fore, VT100.Back)
                     ELSE
                        PDQPrint Txt$, VT100.CurRow, VT100.CurCol, OneColor(VT100.Fore, VT100.Back)
                     END IF

                  CASE 89              'Direct Cursor Address (Y)
                     IF RemLen < 4 THEN
                        LOCATE VT100.CurRow, VT100.CurCol
                        EXIT SUB
                     END IF
                     VT100.CurRow = VT100.TRow + ASC(MID$(Remain$, 3, 1)) - 32
                     VT100.CurCol = VT100.LCol + ASC(MID$(Remain$, 4, 1)) - 32
                     GOSUB VT100Locate
                     Ctrl = Ctrl + 2

                  CASE 90              'Unsuported IDENTIFY (Z)

                  CASE 60              'Enter ANSI compatable mode (<)
                     VT52Mode = 0

                  CASE 61, 62          'Unsuported mode switch (=,>)

                  CASE 49, 50          'Unsupported grphics mode (1,2)

                  END SELECT
                  Ctrl = Ctrl + 1
               END IF

            ELSE                       'ANSI Mode

               Term = ASC(Char$)
               SELECT CASE Term

               CASE 68           'Index (D)
                  VT100.CurRow = VT100.CurRow + 1
                  IF VT100.CurRow > VT100.BRow THEN
                     WScroll VT100, 1, 0
                     VT100.CurRow = VT100.CurRow - 1
                  END IF
                  GOSUB VT100Locate

               CASE 77           'Reverse Index (M)
                  VT100.CurRow = VT100.CurRow - 1
                  IF VT100.CurRow < VT100.TRow THEN
                     WScroll VT100, 1, -1
                  END IF
                  GOSUB VT100Locate

               CASE 55           'Save cursor (7)
                  TempRow = VT100.CurRow
                  TempCol = VT100.CurCol

               CASE 56           'Restore Cursor (8)
                  VT100.CurRow = TempRow
                  VT100.CurCol = TempCol
                  GOSUB VT100Locate
               END SELECT
               Ctrl = Ctrl + 1
            END IF

         END SELECT
      END SELECT
EscDone:
      Start = Ctrl + 1
   ELSE
      IF LineFeed THEN
         VT100.CurRow = VT100.CurRow + 1
         VT100.CurCol = VT100.LCol
         IF VT100.CurRow > VT100.BRow THEN
            WScroll VT100, 1, 0
            VT100.CurRow = VT100.CurRow - 1
         END IF
         GOSUB VT100Locate
         LineFeed = 0
      END IF
      EXIT DO
   END IF

LOOP

Txt$ = MID$(Strng$, Start)
GOSUB VT100Output
Remain$ = ""
LOCATE VT100.CurRow, VT100.CurCol
EXIT SUB

'*****************************************************************************
'  VT100Print GOSUBS
'*****************************************************************************

VT100Output:
   OutLen = LEN(Txt$)
   IF OutLen = 0 THEN RETURN
   IF (VT100.CurCol + OutLen) > VT100.RCol + 1 THEN
      OutLft = VT100.RCol - VT100.CurCol + 1
      IF VT100.Bios THEN
         BIOSPrint LEFT$(Txt$, OutLft), VT100.CurRow, VT100.CurCol, OneColor(VT100.Fore, VT100.Back)
      ELSE
         PDQPrint LEFT$(Txt$, OutLft), VT100.CurRow, VT100.CurCol, OneColor(VT100.Fore, VT100.Back)
      END IF
      VT100.CurCol = VT100.LCol
      VT100.CurRow = VT100.CurRow + 1
      IF VT100.CurRow > VT100.BRow THEN
         WScroll VT100, 1, 0
      END IF
      GOSUB VT100Locate
      Txt$ = MID$(Txt$, OutLft + 1)
      GOTO VT100Output
   ELSE
      IF VT100.Bios THEN
         BIOSPrint Txt$, VT100.CurRow, VT100.CurCol, OneColor(VT100.Fore, VT100.Back)
      ELSE
         PDQPrint Txt$, VT100.CurRow, VT100.CurCol, OneColor(VT100.Fore, VT100.Back)
      END IF
      VT100.CurCol = VT100.CurCol + OutLen
      IF VT100.CurCol > VT100.RCol THEN LineFeed = -1
      GOSUB VT100Locate
   END IF
RETURN

VT100Locate:
   IF VT100.CurRow < VT100.TRow THEN VT100.CurRow = VT100.TRow
   IF VT100.CurRow > VT100.BRow THEN VT100.CurRow = VT100.BRow
   IF VT100.CurCol < VT100.LCol THEN VT100.CurCol = VT100.LCol
   IF VT100.CurCol > VT100.RCol THEN VT100.CurCol = VT100.RCol
RETURN

END SUB
