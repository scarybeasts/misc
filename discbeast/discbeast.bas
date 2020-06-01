MODE7:VDU129,157,131:PRINT"Disc BEAST v0.1":PRINT
REM DISCBEAST base and zero page.
D%=&7000:Z%=&70
REM UTILS base and zero page.
U%=&7A00:W%=&50
REM Read/write buffer.
B%=&6000
REM For parsed command values.
DIM V%(3)
REM For OSWORD.
DIM O% 15:FOR I%=0 TO 15:?(O%+I%)=0:NEXT
?(O%+1)=B%:?(O%+2)=B% DIV 256
REM For CRC.
DIM C% 3

REPEAT

INPUT A$:IF LEN(A$)<4 THEN A$="????"
P$=MID$(A$,5):A$=LEFT$(A$,4)
FOR I%=0 TO 3:V%(I%)=-1:NEXT

I%=0
REPEAT
J%=INSTR(P$," "):IF J%=0 THEN J%=LEN(P$)
Q$=LEFT$(P$,J%)
IF LEN(Q$)<>0 AND Q$<>" " THEN V%(I%)=EVAL(Q$):I%=I%+1
P$=RIGHT$(P$,LEN(P$)-J%)
UNTIL LEN(P$)=0
P%=I%

IF A$="INIT" THEN PROCinit
IF A$="OWRD" THEN PROCowrd
IF A$="DUMP" THEN PROCdump
IF A$="SEEK" THEN PROCseek
IF A$="RIDS" THEN PROCclr:PROCrids:PROCres:V%(0)=-1:PROCdump
IF A$="READ" THEN PROCclr:PROCread:PROCres:PROCcrc:V%(0)=-1:PROCdump
IF A$="RTRK" THEN PROCclr:PROCrtrk:PRINT"LEN: "+STR$(I%-B%):V%(0)=-1:PROCdump
IF A$="TIME" THEN PROCtime:I%=?Z%+?(Z%+1)*256:PRINT"DRIVE SPEED: "+STR$(I%)

UNTIL FALSE

DEF PROCinit
A%=V%(0):T%=0
IF A%<0 THEN A%=0
IF A%>1 THEN A%=1
E%=USR(D%+0) AND &FF
IF E%=0 THEN PRINT"FAIL"
IF E%=1 THEN PRINT"OK 8271"
IF E%=2 THEN PRINT"OK 1770"
PRINT"DRIVE "+STR$(A%)
?O%=A%
ENDPROC

DEF PROCclr
?W%=B%:?(W%+1)=B% DIV 256:A%=0:X%=16:CALL U%+0
ENDPROC

DEF PROCres
I%=R% AND &FF
J%=(R% DIV 256) AND &FF
PRINT"RESULT: &" + STR$~(I%);
IF I%<>J% THEN PRINT" (&"+STR$~(J%)+")" ELSE PRINT
ENDPROC

DEF PROCcrc
!C%=-1
I%=?Z%+(?(Z%+1)*256)-B%
J%=I%
K%=B%

REPEAT
?W%=C%:?(W%+1)=C% DIV 256
?(W%+2)=K%:?(W%+3)=(K% DIV 256)
IF J%>=256 THEN L%=256 ELSE L%=J%
A%=L%:IF A%=256 THEN A%=0
CALL U%+9
J%=J%-L%:K%=K%+L%
UNTIL J%=0

X%=?C% EOR &FF
Y%=?(C%+3) EOR &FF
?C%=Y%
?(C%+3)=X%
X%=?(C%+1) EOR &FF
Y%=?(C%+2) EOR &FF
?(C%+1)=Y%
?(C%+2)=X%
PRINT"CRC32 "+STR$(I%)+" BYTES: "+STR$~(!C%)
ENDPROC

DEF PROCowrd
?(O%+5)=P%-1
?(O%+6)=V%(0)
IF P%>1 THEN FOR I%=2 TO P%:?(O%+5+I%)=V%(I%-1):NEXT
A%=&7F:X%=O% AND &FF:Y%=O% DIV 256:CALL&FFF1:R%=?(O%+6+P%)
PRINT"OSWORD &7F: &"+STR$~(R%)
ENDPROC

DEF PROCseek
A%=V%(0):CALL D%+3:T%=A%
ENDPROC

DEF PROCrids
?Z%=B%:?(Z%+1)=B% DIV 256:R%=USR(D%+9)
ENDPROC

DEF PROCread
?Z%=B%:?(Z%+1)=B% DIV 256
A%=V%(0):IF A%=-1 THEN A%=T%
X%=V%(1):IF X%=-1 THEN X%=0
Y%=V%(2):IF Y%=-1 THEN Y%=&21
R%=USR(D%+12)
ENDPROC

DEF PROCrtrk
?Z%=B%:?(Z%+1)=B% DIV 256:R%=USR(D%+6)
I%=?Z%+?(Z%+1)*256
ENDPROC

DEF PROCtime
?Z%=B%:?(Z%+1)=B%:CALL D%+15
ENDPROC

DEF PROCdump
A%=V%(0):IF A%<0 THEN A%=0
FOR I%=0 TO 63
PRINT" "+FNhex(?(B%+A%+I%));
IF I% MOD 8=7 THEN PRINT
NEXT
ENDPROC

DEF FNhex(A%)
A$=STR$~(A%)
IF LEN(A$)=1 THEN A$="0"+A$
=A$
