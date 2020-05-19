MODE7:VDU129,157,131:PRINT"HFE Grab v0.1":PRINT
E%=0:PRINT"Save tracks? ";:IF GET=89 THEN E%=E%+1:PRINT"Y" ELSE PRINT"N"
S%=0:F%=80:PRINT"80/40/Custom? ";:I%=GET
IF I%=52 THEN F%=40 ELSE IF I%<>56 THEN PRINT:INPUT S%:INPUT F%
PRINT STR$(S%)+"-"+STR$(F%)
REM HGASM base, zero page.
D%=&1100:Z%=&70
REM Buffers. &7B00 for HIMEM.
M%=&2A00:N%=&6A00
IF TOP>M%-&100 THEN PRINT"ERROR: out of space":END
REM CRC32s
DIM P% 4:DIM Q% 4:!Q%=-1

PROCinit:PRINT"Checking drive speed:":FOR I%=1 TO 8:CALL D%+6:B%=FNg16(&6000):PRINT B%;:NEXT:PRINT

FOR T%=S% TO F%
IF (T% MOD 4)=0 THEN PROCinit:A%=M%:X%=64:PROCclrp
O%=M%+(4096*(T% MOD 4))
PROCdotrack
PROCcrcf(P%)
IF T%=S% THEN ?(O%+5)=B%:?(O%+6)=B% DIV 256:PRINT "Track "+STR$(T%)+" speed, CRC32":I%=FNg16(O%+3):I%=I%*(3125/3072):PRINT I%:PRINT~!P%
REM No overread track in final CRC.
IF T%<>F% OR (T%<>40 AND T%<>80) THEN ?&70=P%:?&71=P% DIV 256:X%=Q%:Y%=Q% DIV 256:A%=4:CALL D%+27
IF (T% MOD 10)=0 THEN PRINT:PRINT CHR$(48+(T% DIV 10))+" ";
PRINT CHR$(128+C%)+CHR$(G%)+CHR$(H%);
IF (E% AND 2)=2 THEN PRINT "Track "+STR$(T%)+" CRC32 "+STR$~(!P%)
IF (E% AND 1)=1 AND ((T% MOD 4)=3 OR T%=F%) THEN PROCsave
NEXT
PROCcrcf(Q%)
PRINT:PRINT"Full CRC32: "+STR$~(!Q%)

END

DEF PROCdotrack
REM Clear buffer.
A%=N%:X%=17:PROCclrp

REM Seek, read sector IDs.
A%=T%:CALL D%+9
?Z%=&10:?(Z%+1)=N% DIV 256
?(Z%+2)=&90:?(Z%+3)=N% DIV 256
R%=USR(D%+12) AND &FF
?N%=1:?(N%+1)=R%:?(N%+2)=&FF
PROCcopy

REM Color green, no extra detail, CRC.
C%=2:G%=255:H%=32:!P%=-1
IF R%<>0 THEN C%=1:H%=33
REM Nothing.
IF R%=&18 THEN C%=4:ENDPROC

REM Logical track, sector, count.
V%=?(N%+&10):W%=?(N%+&12):U%=0
J%=N%+&10:K%=N%+&90
FOR I%=0 TO 31
IF FNg16(K%)<6122 THEN U%=U%+1:?&70=J%:?&71=J% DIV 256:X%=P%:Y%=P% DIV 256:A%=4:CALL D%+27 ELSE I%=31
IF ?J%<>T% THEN C%=6
IF ?(J%+2)>9 THEN C%=6
J%=J%+4:K%=K%+2
NEXT
IF (E% AND 4)=4 THEN PRINT"HEADERS "+STR$(U%)+" "+STR$~(!P%)
IF U%>10 THEN H%=43
IF U%<10 THEN H%=48+U%
REM Unreadable.
IF V%=0 AND T%<>0 THEN C%=4:ENDPROC

PROCreadsector
?(N%+2)=R%
IF R%<>&0E AND R%<>0 THEN ENDPROC
I%=N%+&D0:J%=FNg16(I%+12*2)-FNg16(I%):?(N%+3)=J%:?(N%+4)=J% DIV 256
IF J%>3120 THEN PRINT:PRINT"ERROR: write splices or corruption":PRINT J%:END
REM D for deleted data.
?(N%+&FF)=&FB
IF (R% AND &20)=&20 THEN G%=68:?(N%+&FF)=&F8

J%=N%+&FF
FOR I%=0 TO U%-1
K%=N%+&90+(I%*2)
A%=FNg16(K%+2)-FNg16(K%)
L%=2048
IF A%<2048 THEN L%=1024
IF A%<1024 THEN L%=512
IF A%<512 THEN L%=256
IF A%<256 THEN L%=128
IF (E% AND 4)=4 THEN PRINT"SECTOR "+STR$(L%)+"@"+STR$~(J%);
L%=L%+1
IF ?J%=&F8 THEN G%=68
REPEAT:A%=L%
IF A%>255 THEN A%=255
?&70=J%:?&71=J% DIV 256:X%=P%:Y%=P% DIV 256:CALL D%+27
J%=J%+A%
L%=L%-A%
UNTIL L%=0
IF (E% AND 4)=4 THEN PRINT" "+STR$~(!P%)
REM Yellow for non-standard post-sector.
IF ?(J%+2)<>&FF OR ?(J%+3)<>&FF THEN C%=3
REPEAT:J%=J%+1:L%=L%+1:UNTIL I%=U%-1 OR (!J% AND &FFFFFF)=&FE0000 OR J%>N%+3328
J%=J%+8
IF I%<>U%-1 AND L%<17 THEN C%=5
REPEAT:J%=J%+1:UNTIL I%=U%-1 OR (!J% AND &FFFFFF)=&FB0000 OR (!J% AND &FFFFFF)=&F80000 OR J%>N%+3328
J%=J%+2
NEXT
IF I%<>U% THEN PRINT"ERROR: missing sectors":END

PROCcopy
REM Clear old.
A%=N%:X%=17:PROCclrp

REM Check for re-read differences.
PROCreadsector
?Z%=0:?(Z%+1)=(N% DIV 256)+1
?(Z%+2)=0:?(Z%+3)=(O% DIV 256)+1
R%=USR(D%+24)
R%=R% AND &FF
REM Red if different.
IF R%<>0 THEN C%=1

ENDPROC

DEF PROCreadsector
?Z%=0:?(Z%+1)=(N% DIV 256)+1
?(Z%+2)=&D0:?(Z%+3)=N% DIV 256
A%=V%:X%=W%:Y%=&A1:R%=USR(D%+15) AND &FF
ENDPROC

DEF PROCcopy
?Z%=0:?(Z%+1)=N% DIV 256
?(Z%+2)=0:?(Z%+3)=O% DIV 256
A%=16:CALL D%+21
A%=O%+&E00:X%=2:PROCclrp
ENDPROC

DEF PROCsave
A%=1:IF T%>40 THEN A%=3
OSCLI("D."):OSCLI("DR."+STR$(A%)):OSCLI("SAVE TRKS"+STR$(T% DIV 4)+" "+STR$~(M%)+" +4000")
ENDPROC

DEF PROCinit
CALL D%+0
REM Drive 0, side 0, head load.
A%=0:X%=0:CALL D%+3
ENDPROC

DEF PROCclrp
?Z%=A%
?(Z%+1)=A% DIV 256
A%=X%
CALL D%+18
ENDPROC

DEF PROCcrcf(A%)
X%=?A% EOR &FF
Y%=?(A%+3) EOR &FF
?A%=Y%
?(A%+3)=X%
X%=?(A%+1) EOR &FF
Y%=?(A%+2) EOR &FF
?(A%+1)=Y%
?(A%+2)=X%
ENDPROC

DEF FNg16(A%)=?A%+?(A%+1)*256
