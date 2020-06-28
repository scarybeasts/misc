MODE7:VDU133,157,131:PRINT"Oiled Otter v0.1":PRINT
REM Machine code.
D%=&7000:Z%=&70
REM Output, track.
O%=&FF:T%=-1

PROCsetup

REPEAT

INPUT A$
IF A$="ON" THEN O%=O% AND &FC:?&FE60=O%
IF A$="OFF" THEN O%=O% OR &03:?&FE60=O%

UNTIL FALSE

DEF PROCsetup
REM User port
REM Output pins high
?&FE60=&FF
REM User port bits 0-5 output, 6-7 input.
?&FE62=&3F
ENDPROC
