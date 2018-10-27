'============================================================================
'  XSTAT.BAS
'
'  File transfer status window
'
'  Copyright (c) 1991 Clearware Computing, By David Cleary
'
'Call XStat1 initially with an Action% = 1 to open its window.  Text$ is the
'text that goes on the top half of the window, and you can embed "|" markers
'in the text to indicate a line break.  Percent& is the maximum value you'll
'be using (in this case, the file size).  Colr% and Wide% are the box color
'and box width respectively.
'
'To update the status you'll call XStat1 repeatedly with Action% = 2.  Now
'Text$ holds what is to go on the second line (one line, "|" is not allowed),
'and Percent& is the intermediate value (number of bytes transferred so far).
'
'When you're all done call XStat1 with Action% = 3 (the other parameters are
'ignored) to close the window and restore the previous screen contents.
'============================================================================
DEFINT A-Z

DECLARE SUB PDQPrint (Text$, Row%, Col%, Colr%)
DECLARE SUB XStat1 (Action%, Text$, Percent&, Colr%, Wid%)
DECLARE SUB GasGauge (Row%, Col%, Min&, Max&, value&, Wide%, Colr%)
DECLARE SUB BoxBas (URow%, LCol%, LRow%, RCol%, BoxType%, Colr%)

'Single line constants
CONST SHLine$ = "Ä", SVLine$ = "³", STLCor$ = "Ú", STRCor$ = "¿", SBLCor$ = "À", SBRCor$ = "Ù"

'Double line constants
CONST DHLine$ = "Í", DVLine$ = "º", DTLCor$ = "É", DTRCor$ = "»", DBLCor$ = "È", DBRCor$ = "¼"

SUB BoxBas (URow%, LCol%, LRow%, RCol%, BoxType%, Colr%)

SELECT CASE BoxType
   CASE 1                              'Single line box
      HLine$ = SHLine$
      VLine$ = SVLine$
      TLC$ = STLCor$
      TRC$ = STRCor$
      BLC$ = SBLCor$
      BRC$ = SBRCor$
   CASE 2                              'Double line box
      HLine$ = DHLine$
      VLine$ = DVLine$
      TLC$ = DTLCor$
      TRC$ = DTRCor$
      BLC$ = DBLCor$
      BRC$ = DBRCor$
   CASE ELSE                           'Illeagle type
      EXIT SUB
END SELECT

'Do top
Pad$ = TLC$ + STRING$(RCol - LCol - 1, HLine$) + TRC$
PDQPrint Pad$, URow, LCol, Colr

'Do middle
Pad$ = VLine$ + STRING$(RCol - LCol - 1, " ") + VLine$
FOR I = URow + 1 TO LRow - 1
   PDQPrint Pad$, I, LCol, Colr
NEXT

'Do bottom
Pad$ = BLC$ + STRING$(RCol - LCol - 1, HLine$) + BRC$
PDQPrint Pad$, LRow, LCol, Colr

END SUB

SUB GasGauge (Row, Col, Min&, Max&, value&, Wide, Colr) STATIC

  sRow = Row                            'retrieve the current cursor location
  sCol = Col                            'and draw a box there
  NewWide = Wide - 2                    'exclude the border dimensions
  'CALL Box0(sRow, sCol, sRow + 4, sCol + Wide + 1, 1, Colr)
  BoxBas sRow, sCol, sRow + 4, sCol + Wide + 1, 1, Colr
 
  sRow = sRow + 1                       'bump the row and column, because
  sCol = sCol + 1                       ' we're printing at the next ones
  IF LEN(Pad$) <> Wide THEN Pad$ = SPACE$(Wide) 'holds title, bars, legends
  Part! = (value& - Min& + 1) / (Max& - Min& + 1)   'percent divided by 100
  LSET Pad$ = STR$(INT(Part! * 100)) + " percent completed:"
  PDQPrint Pad$, sRow, sCol, Colr
 
  sRow = sRow + 1                         'the gauge itself is on the next line
  NumBlocks = Wide * Part!              'calculate the number of solid blocks
  NumShades = Wide - NumBlocks          'and then the number of shaded blocks
  IF NumShades THEN
     LSET Pad$ = STRING$(NumBlocks, 219) + STRING$(NumShades, 176)
  ELSE
     LSET Pad$ = STRING$(NumBlocks, 219)
  END IF
  PDQPrint Pad$, sRow, sCol, Colr

  'This next block of code prints the lower and upper limits beneath the
  'progress bar at each end.  If you prefer to remove this code you should
  'also change the call to Box0 above to use Row + 3 instead of Row + 4.
  sRow = sRow + 1
  LSET Pad$ = LTRIM$(STR$(Min&))
  Max$ = LTRIM$(STR$(Max&))
  MaxLen = LEN(Max$)
  MID$(Pad$, Wide - MaxLen + 1) = Max$
  PDQPrint Pad$, sRow, sCol, Colr

END SUB

SUB XStat1 (Action%, Text$, Percent&, Colr%, Wid%) STATIC

SELECT CASE Action

   CASE 1                              'Save Screen
      sColr = Colr                     'Save some variables
      sWid = Wid
      sMax& = Percent&
      sLines = 1
      Pad$ = SPACE$(sWid - 2)
      Bar = INSTR(Text$, "|")          'Determine number of lines
      DO WHILE Bar
        sLines = sLines + 1
        Bar = INSTR(Bar + 1, Text$, "|")
      LOOP
      sLines = sLines + 8
      REDIM ScrArray(1 TO sLines * sWid)
      sCol = 40 - sWid \ 2
      sRow = 13 - sLines \ 2

'-----  This routine saves the screen and draws the window
      IF MonSeg = 0 THEN
        DEF SEG = 0
        IF PEEK(&H463) = &HB4 THEN
          MonSeg = &HB000
        ELSE
          MonSeg = &HB800
        END IF
      END IF

      DEF SEG = MonSeg

      ArrayPtr = 0
      FOR I = sRow - 1 TO sRow + sLines - 2
        FOR J = sCol - 1 TO sCol + sWid - 2
          ArrayPtr = ArrayPtr + 1
           Temp& = PEEK((I * 160) + (2 * J)) * &H100& + PEEK((I * 160) + (2 * J) + 1)
           IF Temp& AND &H8000 THEN
             Temp& = Temp& - 65536
           END IF
           ScrArray(ArrayPtr) = Temp&
        NEXT
      NEXT

      'CALL Box0(sRow, sCol, sRow + sLines - 6, sCol + sWid - 1, 2, sColr)
      BoxBas sRow, sCol, sRow + sLines - 6, sCol + sWid - 1, 2, sColr
      IF sMax& <> 0 THEN
        CALL GasGauge(sRow + sLines - 5, sCol, 0&, Percent&, 0&, sWid - 2, sColr)
      END IF
      Bar = INSTR(Text$, "|")          'Determine number of lines
      OldBar = 1
      tLines = 1
      DO WHILE Bar
        Temp$ = MID$(Text$, OldBar, Bar - OldBar)
        LSET Pad$ = SPACE$((sWid - 2) \ 2 - (LEN(Temp$) \ 2)) + Temp$
        PDQPrint Pad$, sRow + tLines, sCol + 1, sColr
        tLines = tLines + 1
        OldBar = Bar + 1
        Bar = INSTR(Bar + 1, Text$, "|")
      LOOP
      Temp$ = MID$(Text$, OldBar)
      LSET Pad$ = SPACE$((sWid - 2) \ 2 - (LEN(Temp$) \ 2)) + Temp$
      PDQPrint Pad$, sRow + tLines, sCol + 1, sColr
      LSET Pad$ = ""
      PDQPrint Pad$, sRow + tLines + 1, sCol + 1, sColr

   CASE 2                              'Normal processing
      LSET Pad$ = SPACE$((sWid - 2) \ 2 - (LEN(Text$) \ 2)) + Text$
      PDQPrint Pad$, sRow + tLines + 1, sCol + 1, sColr
      IF sMax& <> 0 THEN
        CALL GasGauge(sRow + sLines - 5, sCol, 0&, sMax&, Percent&, sWid - 2, sColr)
      END IF

   CASE 3                              'Restore Screen
      DEF SEG = MonSeg

      ArrayPtr = 0
      FOR I = sRow - 1 TO sRow + sLines - 2
        FOR J = sCol - 1 TO sCol + sWid - 2
          ArrayPtr = ArrayPtr + 1
          IF ScrArray(ArrayPtr) < 0 THEN
            Temp& = 65536 + ScrArray(ArrayPtr)
          ELSE
            Temp& = ScrArray(ArrayPtr)
          END IF
        POKE ((I * 160) + (2 * J)), Temp& \ &H100
        POKE ((I * 160) + (2 * J) + 1), Temp& AND &HFF
        NEXT
      NEXT
      DEF SEG
      ERASE ScrArray

END SELECT

END SUB

