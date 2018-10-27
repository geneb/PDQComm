'=============================================================================
'  XSTAT.BAS
'
'  File transfer status window
'
'  Copyright (c) 1991 Clearware Computing, By David Cleary
'=============================================================================
DEFINT A-Z

DECLARE SUB XStat (Text$)
DECLARE SUB PDQPrint (Text$, Row%, Col%, Colr%)

SUB XStat (Text$) STATIC

'-----  The first time XStat is called, it saves part of the screen and
'  displays a window. It will print two lines of text that are contained
'  in Text$. The lines are separated by a "|" character. Then, each time
'  XStat is called again, it will display a third line. Calling XStat with
'  a null string will close the window and restore the underlying screen.

   DIM Stat AS STRING * 35, ScrBuf(1 TO 240) AS LONG

'-----  If we are active, display line of text unless we got a null string
   IF Active THEN
      IF LEN(Text$) THEN
         LSET Stat = SPACE$(17 - LEN(Text$) \ 2) + Text$
         PDQPrint Stat, 14, 22, 112
      ELSE
         Active = 0
         GOSUB RestoreWin              'This closes the window
      END IF

'-----  Else, save underlying screen and draw new window
   ELSE
      Active = -1
      GOSUB SaveWin
      Split = INSTR(Text$, "|")
      IF Split THEN
         Temp$ = LEFT$(Text$, Split - 1)
         LSET Stat = SPACE$(17 - LEN(Temp$) \ 2) + Temp$
         PDQPrint Stat, 11, 22, 112
         Temp$ = MID$(Text$, Split + 1)
         LSET Stat = SPACE$(17 - LEN(Temp$) \ 2) + Temp$
         PDQPrint Stat, 12, 22, 112
      ELSE
         LSET Stat = SPACE$(17 - LEN(Text$) \ 2) + Text$
         PDQPrint Stat, 11, 22, 112
      END IF
   END IF

   EXIT SUB

'-----  This routine saves the screen and draws the window
SaveWin:
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
   FOR I = 9 TO 14
      FOR J = 19 TO 58
         ArrayPtr = ArrayPtr + 1
         ScrBuf(ArrayPtr) = PEEK((I * 160) + (2 * J)) * &H100& + PEEK((I * 160) + (2 * J) + 1)
      NEXT
   NEXT

   Win$ = "ษออออออออออออออออออออออออออออออออออออออป"
   PDQPrint Win$, 10, 20, 112
   FOR I = 11 TO 14
      Win$ = "บ                                      บ"
      PDQPrint Win$, I, 20, 112
   NEXT
   Win$ = "ศออออออออออออออออออออออออออออออออออออออผ"
   PDQPrint Win$, 15, 20, 112
   DEF SEG
RETURN

'-----  This routine restores the screen back to its original state
RestoreWin:
   DEF SEG = MonSeg

   ArrayPtr = 0
   FOR I = 9 TO 14
      FOR J = 19 TO 58
         ArrayPtr = ArrayPtr + 1
         POKE ((I * 160) + (2 * J)), ScrBuf(ArrayPtr) \ &H100
         POKE ((I * 160) + (2 * J) + 1), ScrBuf(ArrayPtr) AND &HFF
      NEXT
   NEXT
   DEF SEG
RETURN

END SUB
