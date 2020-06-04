MODE7:VDU129,157,131:PRINT"Disc BEAST v0.1":PRINT
REM DISCBEAST code and zero page.
D%=&7000+&100:Z%=&70
REM UTILS base and zero page.
U%=&7A00:W%=&50
REM Read/write buffer. 4k plus a page for timing.
B%=&5000
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

PROCbufs(0,4096)
IF A$="INIT" THEN PROCinit
IF A$="OWRD" THEN PROCowrd
IF A$="DUMP" THEN PROCdump
IF A$="SEEK" THEN PROCseek
IF A$="RIDS" THEN PROCclr:PROCrids:PROCres:PRINT"SECTOR HEADERS: "+STR$(S%):V%(0)=-1:PROCdump
IF A$="READ" THEN PROCclr:PROCread:PROCres:PROCcrc:V%(0)=-1:PROCdump
IF A$="RTRK" THEN PROCclr:PROCrtrk:PRINT"LEN: "+STR$(S%):V%(0)=-1:PROCdump
IF A$="TIME" THEN PROCtime:PRINT"DRIVE SPEED: "+STR$(FNg16(Z%+4))
IF A$="HFEG" THEN PROChfeg

UNTIL FALSE

DEF PROCinit
A%=V%(0):T%=0
IF A%<0 THEN A%=0
IF A%>1 THEN A%=1
E%=USR(D%+0) AND &FF
IF E%=0 THEN PRINT"FAIL":END
IF E%=1 THEN PRINT"OK 8271"
IF E%=2 THEN PRINT"OK 1770"
PRINT"DRIVE "+STR$(A%)+" SPEED "+STR$(FNg16(Z%+4))
?O%=A%
ENDPROC

DEF PROCclr
?W%=B%:?(W%+1)=B% DIV 256:A%=0:X%=17:CALL U%+0
ENDPROC

DEF PROCres
I%=R% AND &FF
J%=(R% DIV 256) AND &FF
PRINT"RESULT: &" + STR$~(I%);
IF I%<>J% THEN PRINT" (&"+STR$~(J%)+")" ELSE PRINT
ENDPROC

DEF PROCcrc
!C%=-1
I%=FNg16(Z%)-B%
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

DEF PROCbufs(A%,X%)
Y%=B%+A%:?Z%=Y%:?(Z%+1)=Y% DIV 256
Y%=B%+X%:?(Z%+2)=Y%:?(Z%+3)=Y% DIV 256
ENDPROC

DEF PROCseek
A%=V%(0):CALL D%+3:T%=A%
ENDPROC

DEF PROCrids
K%=FNg16(Z%+2)
R%=USR(D%+9) AND &FF
IF R%<>0 THEN ENDPROC
S%=0
REM Drive speed.
J%=FNg16(Z%+4)
REM Sectors in one rev.
FOR I%=0 TO 31
L%=FNg16(K%+I%*2)
IF L%<J% THEN S%=S%+1
NEXT
REM Timing based sector sizes.
FOR I%=0 TO S%-1
IF I%=S%-1 THEN L%=J% ELSE L%=FNg16(K%+(I%+1)*2)
L%=L%-FNg16(K%+I%*2)
A%=3
IF L%<1024 THEN A%=2
IF L%<512 THEN A%=1
IF L%<256 THEN A%=0
?(K%+64+I%)=A%
NEXT
ENDPROC

DEF PROCread
A%=V%(0):IF A%=-1 THEN A%=T%
X%=V%(1):IF X%=-1 THEN X%=0
Y%=V%(2):IF Y%=-1 THEN Y%=&21
R%=USR(D%+12)
ENDPROC

DEF PROCgets:S%=FNg16(Z%):ENDPROC

DEF PROCrtrk
R%=USR(D%+6)
PROCgets:S%=S%-B%
ENDPROC

DEF PROCtime
CALL D%+15
PROCgets
ENDPROC

DEF PROCdump
A%=V%(0):IF A%<0 THEN A%=0
FOR I%=0 TO 63
PRINT" "+FNhex(?(B%+A%+I%));
IF I% MOD 8=7 THEN PRINT
NEXT
ENDPROC

DEF PROChfeg
VDU132,157,134:PRINT"HFE Grab v0.1":PRINT
IF E%<>2 THEN PRINT"1770 ONLY":ENDPROC
FOR T%=0 TO 40
PRINT"TRACK " + STR$(T%)
V%(0)=T%:PROCseek:PROCclr
?B%=E%:?(B%+1)=T%:?(B%+2)=?(Z%+4):?(B%+3)=?(Z%+5)
PROCbufs(&20,&A0):PROCrids:?(B%+4)=R%
IF R%<>&18 THEN ?(B%+5)=S%:J%=S%:PROChfeg2
PRINT"SECTORS: "+STR$(?(B%+5))
NEXT
ENDPROC

DEF PROChfeg2
PRINT"RTRK"
PROCbufs(&200,&180):PROCrtrk:?(B%+6)=S%:?(B%+7)=S% DIV 256
A%=0
REM Find sectors in raw track read.
FOR I%=0 TO J%-1
X%=FNg16(Z%+4)
X%=(3125/X%)*(FNg16(B%+&A0+I%*2)-1)
Y%=!(B%+&20+I%*4)
FOR K%=-2 TO 2
L%=B%+&200+X%+K%
IF (?L%=&FE OR ?L%=&CE) AND !(L%+1)=Y% THEN A%=A%+1:X%=X%+K%:?(B%+&100+I%*2)=X%:?(B%+&101+I%*2)=X% DIV 256:K%=2
NEXT
FOR K%=14 TO 30
L%=B%+&200+X%+K%
IF ?L%=&FB OR ?L%=&CB OR ?L%=&F8 OR ?L%=&C8 THEN A%=A%+1:X%=X%+K%:?(B%+&140+I%*2)=X%:?(B%+&141+I%*2)=X% DIV 256:K%=30
NEXT
NEXT
IF A%<>J%*2 THEN PRINT"RTRK MISSING SECTORS"
ENDPROC

DEF FNhex(A%)
A$=STR$~(A%)
IF LEN(A$)=1 THEN A$="0"+A$
=A$

DEF FNg16(A%):=?A%+?(A%+1)*256
