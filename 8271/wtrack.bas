MODE 7:HIMEM=&2800
PRINT "8271 TRKS WRITER"
*LOAD IASM 2800
PRINT "READING FROM DRIVE 1"
PRINT "WRITING TO DRIVE 0"
PRINT "40 TRACKS"
PRINT "PRESS RETURN TO START"
INPUT A$

REM set up drive speed: 3125
A%=-3125
?&74=A%
?&75=(A% AND &FF00) DIV 256
REM replace bad clocks byte
?&76=1

FOR T%=0 TO 40
REM reset
CALL &281B
*DISC
*DRIVE 1
PRINT"R";
PROCreadtrack
REM load
CALL &2800
REM seek
A%=T%:CALL &2803
PRINT"W";
PROCwritetrack
PRINT".";
NEXT
END

DEF PROCreadtrack
IF (T% AND 1)=0 THEN OSCLI("LOAD TRKS" + STR$(T%) + " 5C00")
IF (T% AND 1)=0 THEN B%=&5C00 ELSE B%=&6C00
ENDPROC

DEF PROCwritetrack
REM format
?&5000=T%
?&5001=1
?&5002=&DB
?&5003=1
?&70=0
?&71=&50
A%=T%:X%=&21:CALL &2806
REM write track
S%=?(B%+5)
C%=&4000
IF S%>0 THEN PROCmarkers
?C%=0
?(C%+1)=0
?&70=B% AND &FF
?&71=((B%+&200) AND &FF00) DIV &100
?&72=0
?&73=&40
A%=T%:CALL &2818
ENDPROC

DEF PROCmarkers
M%=0
FOR I%=0 TO S%
REM sector header then sector body
PROCmarker(B%+&100+(I%*2))
PROCmarker(B%+&140+(I%*2))
NEXT
ENDPROC

DEF PROCmarker(X%)
J%=?X%+(?(X%+1)*256)
IF M%=0 THEN K%=J%-10 ELSE K%=(J%-M%)-15
K%=-K%
?C%=K% AND &FF
?(C%+1)=(K% AND &FF00) DIV &100
?(C%+2)=&C7
C%=C%+3
M%=J%
ENDPROC

DEF PROCrun(X%, Y%)
FOR I%=1 TO X%:?B%=Y%:B%=B%+1:NEXT
ENDPROC

DEF PROCcall(X%)
R%=USR(X%)
A%=R% AND &FF
X%=(R% AND &FF00) DIV &100
PRINT" =&" + STR$~(X%) + " (" + STR$~(A%) + ")"
ENDPROC
