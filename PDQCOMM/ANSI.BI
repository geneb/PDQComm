DEFINT A-Z

DECLARE SUB AnsiInit ()
DECLARE SUB AnsiPrint (Text$)
DECLARE SUB SetAnsiWindow (WinNum%)

COMMON SHARED /Ansi/ Ansi AS TermType
