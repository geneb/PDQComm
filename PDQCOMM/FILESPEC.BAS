' FILESPEC.BAS by Ronny Ong, April 5, 1988 - 100% Public Domain
' Modified for P.D.Q. by Dave Cleary
' From The QBNews Volume 1 No. 5
'
' This routine returns the full name of the currently-running EXE program,
' including the drive and path.  It's used by ANSITERM to find the path to
' the ANSITERM.CFG configuration file, in case ANSITERM isn't in the current
' directory when it was run.
'
' Compile:  BC /O FILESPEC;
' Link:     See ANSITERM.BAS for linking instructions

DECLARE FUNCTION GetFileSpec$ ()

TYPE RegType
  AX    AS INTEGER
  BX    AS INTEGER
  CX    AS INTEGER
  DX    AS INTEGER
  BP    AS INTEGER
  SI    AS INTEGER
  DI    AS INTEGER
  Flags AS INTEGER
END TYPE

FUNCTION GetFileSpec$ STATIC

DIM Regs AS RegType
DIM EnvBlkSeg AS INTEGER, EnvBlkPtr AS INTEGER, Char AS INTEGER

' The Program Segment Prefix is a 256-byte block which DOS
' creates below all normal transient programs loaded.  The PSP
' contains many important pieces of information about the
' transient program, including the location of its "environment
' block" in memory.

Regs.ax = &H6200 ' Int 21H, Function 62H is Get PSP.
CALL Interrupt(&H21, Regs, Regs)
DEF SEG = Regs.bx ' Select the segment containing the PSP.

' Get the segment of the environment block, stored at offset 2CH
' in the PSP.

EnvBlkSeg = PEEK(&H2C) + (PEEK(&H2D) * 256)

' Now select the segment of the environment block itself.
' Environment blocks are always paragraph-aligned.  That is, they
' begin only on even 16-byte address boundaries.  Offset 0,
' therefore, is always the start of the block as long as the
' segment is set properly.

DEF SEG = EnvBlkSeg

' Initialize a pointer to search forward sequentially through
' memory, looking for the double zero bytes which mark the end of
' the environment strings.

EnvBlkPtr = 0

DO
  IF PEEK(EnvBlkPtr) = 0 THEN
     IF PEEK(EnvBlkPtr + 1) = 0 THEN
        EXIT DO
     END IF
  END IF
  IF EnvBlkPtr = &H7FFF THEN ' Environment blocks are max of 32K.
     PRINT "End of environment block not found!"
     STOP
  ELSE
     EnvBlkPtr = EnvBlkPtr + 1
  END IF
LOOP

' Skip over the double zeroes and the 2-byte word count which
' precedes the filespec.

EnvBlkPtr = EnvBlkPtr + 4

Temp$ = "" ' Initialize filespec.

' Assemble Filespec, ensuring that it does not get too long.

DO
  Char = PEEK(EnvBlkPtr)
  IF Char THEN
     Temp$ = Temp$ + CHR$(Char)
     EnvBlkPtr = EnvBlkPtr + 1
  END IF
LOOP WHILE Char > 0 AND LEN(Temp$) < 80

' At this point, Filespec could be used in an OPEN statement to
' read/write the EXE file, but for this demonstration, it is
' simply displayed.

GetFileSpec$ = Temp$

END FUNCTION
