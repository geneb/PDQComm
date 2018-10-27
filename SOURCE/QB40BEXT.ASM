;=============================================================================
;  QB40BEXT.ASM
;
;  B_OnExit routine stub file for use with QB 4.0b.
;
;  Copyright (c) 1991 Clearware Computing, By David Cleary
;=============================================================================

.Model Medium, Basic

.Code

   Extrn    _onexit:Proc

B_OnExit Proc , ExitSeg:Word, ExitOff:Word

   Push  ExitSeg                       ;Push the segment:offset for
   Push  ExitOff                       ;_onexit
   Call  _onexit
   Add   SP, 4                         ;Clean up stack (_onexit is C type)
   Ret

B_OnExit Endp

End
