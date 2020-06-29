MODE7:VDU133,157,131:PRINT"Oiled Otter v0.1":PRINT
REM Machine code.
D%=&7200:Z%=&70
REM Output, track.
O%=&FF:T%=-1

PROCsetup
PROCseek0
PRINT"OK TRK0"

REPEAT

INPUT A$
IF A$="ON" THEN PROCon
IF A$="OFF" THEN PROCoff
IF A$="NUKE" THEN PROCnuke
IF A$="IN" THEN PROCstepin
IF A$="OUT" THEN PROCstepout
IF A$="0" THEN PROCseek0
IF A$="WTRK" THEN PROCwtrk

UNTIL FALSE

DEF PROCsetup
REM User port
REM Output pins high
?&FE60=&FF
REM User port bits 0-5 output, 6-7 input.
?&FE62=&3F
ENDPROC

DEF PROCr(A%)
O%=O% AND NOT A%
?&FE60=O%
ENDPROC

DEF PROCs(A%)
O%=O% OR A%
?&FE60=O%
ENDPROC

DEF PROCon
IF (O% AND &03)=0 THEN ENDPROC
PROCr(&03)
PROCwait(100)
ENDPROC

DEF PROCoff
PROCs(&03)
ENDPROC

DEF PROCnuke
PROCon
PROCr(&04)
PROCwait(50)
PROCs(&04)
PROCoff
ENDPROC

DEF PROCstepin
PROCr(&08)
PROCr(&10)
PROCwait(1)
PROCs(&10)
PROCwait(1)
ENDPROC

DEF PROCstepout
PROCs(&08)
PROCr(&10)
PROCwait(1)
PROCs(&10)
PROCwait(1)
ENDPROC

DEF PROCseek0
IF FNtrk0 THEN ENDPROC
REPEAT
PROCstepout
UNTIL FNtrk0
T%=0
ENDPROC

DEF PROCwtrk
*LOAD TFORM0 4000
PROCon
PROCseek0
MODE7
PROCgentab
?Z%=0:?(Z%+1)=&40
CALL D%
REM Video state will have been messed up.
MODE7
PROCoff
ENDPROC

DEF FNtrk0
IF (?&FE60 AND &80)=&80 THEN =0 ELSE =1

DEF PROCwait(A%)
X%=TIME:REPEAT:UNTIL TIME>X%+A%+1
ENDPROC

DEF PROCgentab
A%=&7E00
REM Data nibbles 0x0 to 0xF, all clock bits set.
FOR I%=0 TO 15
!A%=&FF:!(A%+4)=0:!(A%+8)=&FF:!(A%+12)=0
!(A%+16)=&FF:!(A%+20)=0:!(A%+24)=&FF:!(A%+28)=0
IF I% AND 8 THEN ?(A%+4)=&FF
IF I% AND 4 THEN ?(A%+12)=&FF
IF I% AND 2 THEN ?(A%+20)=&FF
IF I% AND 1 THEN ?(A%+28)=&FF
A%=A%+32
NEXT
REM Special clock bit combinations.
REM Clock &C, data &F
!&7D00=&FF:!&7D08=&FF:!&7D10=0:!&7D18=0
!&7D04=&FF:!&7D0C=&FF:!&7D14=&FF:!&7D1C=&FF
REM Clock &7, data &E
!&7D20=0:!&7D28=&FF:!&7D30=&FF:!&7D38=&FF
!&7D24=&FF:!&7D2C=&FF:!&7D34=&FF:!&7D3C=0
REM Clock &7, data &B
!&7D40=0:!&7D48=&FF:!&7D50=&FF:!&7D58=&FF
!&7D44=&FF:!&7D4C=0:!&7D54=&FF:!&7D5C=&FF
ENDPROC
