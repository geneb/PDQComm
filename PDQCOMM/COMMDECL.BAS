'-----------------------------------------------------------------------------
' COMMDECL.BAS - Declarations for PDQComm routines
'
' To use this with PDQDECL.BAS, you will need to comment out or delete the
' section below that contains routines included in both P.D.Q. and PDQCOMM.
'-----------------------------------------------------------------------------

'-----  PDQComm Function Declarations
DECLARE FUNCTION Carrier% ()
DECLARE FUNCTION Checksum$ (Block$)
DECLARE FUNCTION ComEof% ()
DECLARE FUNCTION ComInput$ (NumBytes%)
DECLARE FUNCTION ComInstr% (Text$, SCase%)
DECLARE FUNCTION ComLoc% ()
DECLARE FUNCTION ComPeek$ (NumBytes%)
DECLARE FUNCTION CRC16$ (Block$)
DECLARE FUNCTION IsAPort% (Address%)
DECLARE FUNCTION OverRun% ()
DECLARE FUNCTION ScanCodes% (Start%, Text$)
DECLARE FUNCTION UARTType% (Address%)
DECLARE FUNCTION XOff% ()
DECLARE FUNCTION XModemSend% (FileName$)
DECLARE FUNCTION XModemReceive% (FileName$)
DECLARE FUNCTION XModem1KSend% (FileName$)
DECLARE FUNCTION XModem1KReceive% (FileName$)
DECLARE FUNCTION YModemSend% (FileName$)
DECLARE FUNCTION YModemReceive% (FileName$)
DECLARE FUNCTION YModemGSend% (FileName$)
DECLARE FUNCTION YModemGReceive% (FileName$)

'-----  PDQComm Subroutine Declarations
DECLARE SUB AdjustRecBuffer (BufferSize%, NEmpty%, NFull%)
DECLARE SUB BIOSPrint (Text$, Row%, Col%, Colr%)
DECLARE SUB ClearXOff ()
DECLARE SUB CloseCom ()
DECLARE SUB ComLineInput (Lne$, TimeOut%)
DECLARE SUB ComPrint (OutStr$)
DECLARE SUB DTR (State%)
DECLARE SUB FlushBuffer ()
DECLARE SUB GetComPorts (C1%, C2%, C3%, C4%)
DECLARE SUB GetLineStatus (StatType AS ANY)
DECLARE SUB GetPortConfig (Port%, Config AS ANY)
DECLARE SUB OpenCom (Parm$)
DECLARE SUB OpenComX (Address%, IRQ%)
DECLARE SUB ParseComParam (Parm$, Port%, Config AS ANY, Blen%, Hand$)
DECLARE SUB RTS (State%)
DECLARE SUB SetActivePort (Port%)
DECLARE SUB SetCom (Par AS ANY)
DECLARE SUB SetFIFO (TrigLev%)
DECLARE SUB SetMCRExit (DTRState%, RTSState%)
DECLARE SUB SetHandshaking (Hand$)

'-----  PDQ Functions and Subs, comment out or delete if using PDQDECL.BAS
DECLARE FUNCTION BIOSInkey% ()
DECLARE FUNCTION PDQExist% (FileName$)
DECLARE FUNCTION PDQParse$ (Work$)
DECLARE FUNCTION PDQTimer& ()
DECLARE FUNCTION PDQValI% (Number$)
DECLARE FUNCTION PDQValL& (Number$)
DECLARE SUB Pause (Ticks%)
DECLARE SUB PDQPrint (Work$, Row%, Column%, Colr%)
DECLARE SUB PDQRestore ()
DECLARE SUB SetDelimitChar (Char%)

'-----  Type structures used by PDQComm
TYPE ModemType
   Baud AS LONG
   Parity AS STRING * 1
   DBits AS INTEGER
   SBits AS INTEGER
END TYPE

TYPE LStatType
   CTS AS INTEGER
   DSR AS INTEGER
   RI AS INTEGER
   DCD AS INTEGER
END TYPE

