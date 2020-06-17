MODE7:VDU129,157,131:PRINT"Disc BEAST v0.1":PRINT
REM DISCBEAST code and zero page.
D%=&7000+&100:Z%=&70
REM UTILS base and zero page.
U%=&7A00:W%=&50
REM Read/write buffers. 4k x3.
B%=&4000
REM Command params, globals.
DIM V%(8),G%(4)
REM For OSWORD.
DIM O% 15:FOR I%=0 TO 15:?(O%+I%)=0:NEXT
?(O%+1)=B%:?(O%+2)=B% DIV 256
REM For CRC.
DIM C% 11

REPEAT

INPUT A$:IF LEN(A$)<4 THEN A$="????"
P$=MID$(A$,5):A$=LEFT$(A$,4)
FOR I%=0 TO 8:V%(I%)=-1:NEXT

I%=0
REPEAT
J%=INSTR(P$," "):IF J%=0 THEN J%=LEN(P$)
Q$=LEFT$(P$,J%)
IF LEN(Q$)<>0 AND Q$<>" " THEN V%(I%)=EVAL(Q$):I%=I%+1
P$=RIGHT$(P$,LEN(P$)-J%)
UNTIL LEN(P$)=0
P%=I%

PROCbufs(B%,B%+4096):PROCs16(Z%+6,G%(3)):PROCs16(Z%+8,-G%(4))
IF A$="INIT" THEN PROCsetup
IF A$="OWRD" THEN PROCowrd
IF A$="DUMP" THEN PROCdump(V%(0))
IF A$="BFIL" THEN PROCbfil
IF A$="BSET" THEN PROCbset
IF A$="SEEK" THEN PROCseek
IF A$="RIDS" THEN PROCclr:PROCrids:PROCres:PRINT"SECTOR HEADERS: "+STR$(S%):PROCdump(0)
IF A$="READ" THEN PROCclr:PROCread:PROCres:L%=FNg16(Z%)-B%:!C%=-1:PROCcrca32(B%,L%,C%):PROCcrcf32(C%):PRINT"CRC32 "+STR$(L%)+" BYTES: "+STR$~(!C%):PROCdump(0)
IF A$="RTRK" THEN PROCclr:PROCrtrk:PROCres:PRINT"LEN: "+STR$(S%):PROCdump(0)
IF A$="WRIT" THEN PROCwrit:PROCres
IF A$="WTRK" THEN PROCwtrk:PROCres
IF A$="TIME" THEN PROCtime:PRINT"DRIVE SPEED: "+STR$(FNdrvspd)
IF A$="DTRK" THEN PROCdtrk
IF A$="DCRC" THEN PROCdcrc
IF A$="HFEG" THEN PROChfeg
IF A$="DBUG" THEN G%(2)=NOT G%(2):PRINT"DBUG "+STR$(G%(2))
IF A$="STRT" THEN G%(3)=V%(0)
IF A$="BAIL" THEN G%(4)=V%(0)
IF A$="BFUN" THEN ?(Z%+10)=V%(0)

UNTIL FALSE

DEF PROCsetup
A%=V%(0):T%=0
IF A%<0 THEN A%=0
G%(0)=A%
A%=USR(D%) AND &FF
IF A%=0 THEN PRINT"FAIL":END
IF A%=1 THEN PRINT"OK 8271"
IF A%=2 THEN PRINT"OK 1770"
G%(1)=A%
?O%=A%
PRINT"DRIVE "+STR$(G%(0))+" SPEED: "+STR$(FNdrvspd)
ENDPROC

DEF PROCreinit:CALL D%+3:ENDPROC

DEF PROCclr:PROCstor(B%,0,4096):ENDPROC

DEF PROCbfil
A%=0:X%=0
IF V%(1)<>-1 THEN A%=V%(0):X%=V%(1) ELSE X%=V%(0)
Y%=4096-A%
PROCstor(B%+A%,X%,Y%)
ENDPROC

DEF PROCbset
A%=V%(0)
FOR I%=1 TO 8
IF V%(I%)<>-1 THEN ?(B%+A%+I%-1)=V%(I%)
NEXT
ENDPROC

DEF PROCres
I%=R% AND &FF
J%=(R% AND &FF00) DIV &100
PRINT"RESULT: &" + STR$~(I%);
IF I%<>J% THEN PRINT" (&"+STR$~(J%)+")" ELSE PRINT
ENDPROC

DEF PROCstor(A%,X%,Y%)
?W%=A%:?(W%+1)=A% DIV 256:A%=X%
Y%=-Y%
?(W%+4)=Y%:?(W%+5)=(Y% AND &FF00) DIV 256
CALL U%
ENDPROC

DEF PROCcopy(A%,X%,Y%)
?W%=A%:?(W%+1)=A% DIV 256
?(W%+2)=X%:?(W%+3)=X% DIV 256
Y%=-Y%
?(W%+4)=Y%:?(W%+5)=(Y% AND &FF00) DIV 256
CALL U%+3
ENDPROC

DEF PROCcrc16(A%,X%)
?(W%+2)=A%:?(W%+3)=A% DIV 256
X%=-X%
?(W%+4)=X%:?(W%+5)=(X% AND &FF00) DIV 256
X%=&FF:Y%=&FF
R%=USR(U%+6):X%=(R% AND &FF00) DIV &100:Y%=(R% AND &FF0000) DIV &10000
R%=X%*256+Y%
ENDPROC

DEF PROCcrca32(A%,X%,Y%)
?W%=Y%:?(W%+1)=Y% DIV 256
?(W%+2)=A%:?(W%+3)=A% DIV 256
X%=-X%
?(W%+4)=X%:?(W%+5)=(X% AND &FF00) DIV 256
CALL U%+9
ENDPROC

DEF PROCcrcf32(A%)
!(C%+8)=!A% EOR &FFFFFFFF
?A%=?(C%+11)
?(A%+1)=?(C%+10)
?(A%+2)=?(C%+9)
?(A%+3)=?(C%+8)
ENDPROC

DEF PROCowrd
?(O%+5)=P%-1
?(O%+6)=V%(0)
IF P%>1 THEN FOR I%=2 TO P%:?(O%+5+I%)=V%(I%-1):NEXT
A%=&7F:X%=O%:Y%=O% DIV 256:CALL&FFF1:R%=?(O%+6+P%)
PRINT"OSWORD &7F: &"+STR$~(R%)
ENDPROC

DEF PROCbufs(A%,Y%):PROCs16(Z%,A%):PROCs16(Z%+2,Y%):ENDPROC

DEF PROCseek
A%=V%(0)
IF A%=-1 THEN A%=0
CALL D%+9:T%=A%
ENDPROC

DEF PROCrids
K%=FNg16(Z%+2)
R%=USR(D%+15)
S%=0
IF (R% AND &FF)=&18 THEN ENDPROC
J%=FNdrvspd
REM Sectors in one rev.
FOR I%=0 TO 31
L%=FNg16(K%+I%*2)
IF L%>0 AND L%<J% THEN S%=S%+1 ELSE I%=31
NEXT
IF S%=0 THEN ENDPROC
REM Timing based sector sizes.
FOR I%=0 TO S%-1
IF I%=S%-1 THEN L%=J% ELSE L%=FNg16(K%+(I%+1)*2)
L%=L%-FNg16(K%+I%*2)
A%=4
IF L%<2048 THEN A%=3
IF L%<1024 THEN A%=2
IF L%<512 THEN A%=1
IF L%<256 THEN A%=0
?(K%+64+I%)=A%
NEXT
ENDPROC

DEF PROCrw(R%)
X%=V%(1):IF X%=-1 THEN X%=0
Y%=V%(2):IF Y%=-1 THEN Y%=1
A%=V%(3):IF A%=-1 THEN A%=256
IF A%=256 THEN Y%=Y%+&20
IF A%=512 THEN Y%=Y%+&40
IF A%=1024 THEN Y%=Y%+&60
IF A%=2048 THEN Y%=Y%+&80
IF A%=4096 THEN Y%=Y%+&A0
A%=V%(0):IF A%=-1 THEN A%=T%
R%=USR(D%+R%)
ENDPROC

DEF PROCread:PROCrw(18):ENDPROC

DEF PROCwrit:PROCrw(24):ENDPROC

DEF PROCrtrk
IF G%(1)<>2 THEN PRINT"RTRK 1770 ONLY":ENDPROC
S%=FNg16(Z%)
R%=USR(D%+12)
S%=FNg16(Z%)-S%
ENDPROC

DEF PROCwtrk
IF G%(1)<>2 THEN PRINT"WTRK 1770 ONLY":ENDPROC
R%=USR(D%+27)
ENDPROC

DEF PROCtime:CALL D%+21:ENDPROC

DEF PROCdump(A%)
IF A%<0 THEN A%=0
FOR I%=0 TO 63
PRINT" "+FNhex(?(B%+A%+I%));
IF I% MOD 8=7 THEN PRINT
NEXT
ENDPROC

DEF PROCdtrk
PROCtrk
J%=?(B%+5)
PRINT"TRACK "+STR$(T%)+" "+STR$(J%)+" SECTORS, LEN "+STR$(FNtlen)
IF R%=2 THEN PRINT"FAIL"
IF J%=0 THEN B%=&4000:ENDPROC
FOR I%=0 TO J%-1
IF FNcrcerr(I%) THEN VDU129:PRINT"SECTOR "+STR$(I%)+" CRC ERROR"
IF FNsizem(I%) THEN VDU131:PRINT"SECTOR "+STR$(I%)+" SIZE MISMATCH"
IF FNidtrk(I%)<>T% THEN VDU134:PRINT"SECTOR "+STR$(I%)+" TRACK MISMATCH"
NEXT
PRINT "TRACK CRC32 "+STR$~(!C%)
B%=&4000
ENDPROC

DEF PROCtcrc
!C%=-1
J%=?(B%+5)
IF J%=0 THEN !C%=0:ENDPROC
FOR I%=0 TO J%-1
K%=1
IF FNcrcerr(I%) THEN K%=0
IF FNidtrk(I%)=0 AND T%<>0 THEN K%=0
L%=FNrsiz(I%)+1
M%=FNsaddr(I%)
IF K%=1 THEN PROCcrca32(M%,L%,C%)
NEXT
PROCcrcf32(C%)
ENDPROC

DEF PROCtrk
IF T% AND 1 THEN B%=&6000 ELSE B%=&5000
PROCclr
V%(0)=T%:PROCseek
PROCgtrk:PROCtcrc
ENDPROC

DEF PROCpcrc:PROCcrcf32(C%+4):VDU130:PRINT "DISC CRC32 "+STR$~(!(C%+4)):ENDPROC

DEF PROCdcrc
!(C%+4)=-1
V%(7)=V%(0)
IF V%(7)=-1 THEN V%(7)=40
FOR T%=0 TO V%(7)
PRINT"TRACK "+STR$(T%)+" ";
V%(4)=5
REPEAT
V%(4)=V%(4)-1
PROCtrk
IF R%<>0 THEN PRINT"(RETRY) ";:PROCwait(200):I%=T%:V%(0)=0:PROCseek:V%(0)=I%:PROCseek
UNTIL R%=0 OR V%(4)=0
PROCcrca32(C%,4,C%+4)
IF R%>1 THEN T%=V%(7) ELSE PRINT"CRC32 "+STR$~(!C%)
NEXT
IF R%>1 THEN PRINT"FAIL" ELSE PROCpcrc
B%=&4000
ENDPROC

DEF PROChfeg
PRINT:VDU132,157,134:PRINT"HFE Grab v0.2"
!(C%+4)=-1
V%(5)=V%(2)
V%(6)=V%(0)
V%(7)=V%(1)
IF V%(6)=-1 THEN V%(6)=0:V%(7)=40
IF V%(7)=-1 THEN V%(7)=V%(6):V%(6)=0
PRINT"TRACKS "+STR$(V%(6))+" TO "+STR$(V%(7))
IF V%(5)<>0 THEN PRINT"SAVING TO DRIVE 1"
FOR T%=V%(6) TO V%(7)
IF (T% AND 1)=0 THEN PROCstor(&5000,0,8192)
IF (T% MOD 10)=0 THEN PRINT:PRINT STR$(T%)+" ";
IF T%=0 THEN PRINT" ";
VDU135,46
REM Retries.
V%(4)=5
REPEAT
V%(4)=V%(4)-1
PROCtrk
IF R%<>0 THEN VDU7,8,8,129,33:PROCwait(200):I%=T%:V%(0)=0:PROCseek:V%(0)=I%:PROCseek
UNTIL R%=0 OR V%(4)=0
PROCcrca32(C%,4,C%+4)
IF R%<2 THEN PROChfegy ELSE T%=V%(7)
NEXT
PRINT
IF R%<2 THEN PROCpcrc ELSE PRINT"FAIL"
B%=&4000
ENDPROC

DEF PROChfegy
REM Display character and color.
I%=2:J%=32:K%=255
A%=?(B%+5)
IF A%<10 THEN J%=48+A%
IF A%>10 THEN J%=43
L%=?(B%+4)
IF L%=&18 THEN I%=4:J%=33
IF A%>0 THEN PROChfegs
VDU8,8,128+I%,K%,J%
PROCsave:PROCreinit
ENDPROC

DEF PROChfegs
Y%=0
FOR X%=0 TO A%-1
IF FNidtrk(X%)<>T% THEN I%=7
IF FNidtrk(X%)=0 AND T%<>0 THEN I%=6
IF FNsizem(X%) THEN I%=3
IF FNcrcerr(X%) THEN I%=1
IF ?FNsaddr(X%)=&F8 OR ?FNsaddr(X%)=&C8 THEN K%=68
Y%=Y%+FNrsiz(X%)
NEXT
IF Y%>2560 THEN I%=5
ENDPROC

DEF PROCsave
IF V%(5)=0 THEN ENDPROC
IF (T% AND 1)=0 AND T%<>V%(7) THEN ENDPROC
OSCLI("DISC")
IF T%<=40 THEN OSCLI("DR.1") ELSE OSCLI("DR.3")
OSCLI("SAVE TRKS"+STR$(T% AND &FE)+" 5000 +2000")
ENDPROC

DEF PROCgtrk
?B%=G%(1):?(B%+1)=T%:?(B%+2)=?(Z%+4):?(B%+3)=?(Z%+5)
PROCbufs(B%+&20,B%+&A0):PROCrids
R%=R% AND &FF:?(B%+4)=R%:?(B%+5)=S%:J%=S%
IF R%=&18 THEN R%=0:ENDPROC

IF R%<>0 THEN ?(B%+8)=1
IF R%<>0 AND G%(1)=1 THEN R%=1:ENDPROC
IF G%(1)=1 THEN PROCg8271 ELSE PROCg1770
IF R%<>0 THEN ENDPROC

REM Find sectors in raw track.
FOR I%=0 TO J%-1
X%=FNcstime(I%)-1
Y%=!(B%+&20+I%*4)
N%=0
FOR K%=-10 TO 10
L%=B%+&200+X%+K%
IF (?L%=&FE OR ?L%=&CE OR ?L%=&F9) AND !(L%+1)=Y% THEN N%=1:X%=X%+K%:?(B%+&100+I%*2)=X%:?(B%+&101+I%*2)=X% DIV 256:K%=10
NEXT
IF G%(2) AND N%=0 THEN PRINT"DBUG: HDR "+STR$~(X%):PROCdump(&200+X%-32)
FOR K%=14 TO 30
L%=B%+&200+X%+K%
IF ?L%=&FB OR ?L%=&CB OR ?L%=&F8 OR ?L%=&C8 THEN N%=N%+1:X%=X%+K%:?(B%+&140+I%*2)=X%:?(B%+&141+I%*2)=X% DIV 256:K%=30
NEXT
IF N%=2 THEN PROCgtrky:R%=0 ELSE R%=2:I%=J%-1
NEXT
IF R%=0 AND ?(B%+8)=1 THEN R%=1
REM 1770 sees ghosts.
IF R%=2 AND ?(B%+4)<>0 THEN ?(B%+4)=&18:?(B%+5)=0:R%=1
ENDPROC

DEF PROCgtrky
K%=B%+&E0+I%
M%=FNssize(?K%)
REM Tag size / CRC mismatches.
IF ?K%<>FNidsiz(I%) THEN ?K%=(?K%)+&40
N%=?L%:?L%=?L% OR &F0:PROCcrc16(L%,M%+1):?L%=N%
L%=L%+M%+1:S%=?L%*256+?(L%+1)
IF R%<>S% THEN ?K%=(?K%)+&80:?(B%+8)=1
ENDPROC

DEF PROCg1770
FOR I%=1 TO 4
PROCbufs(B%+&200,B%+&180)
PROCrtrk:R%=R% AND &FF
IF G%(2) AND R%<>0 THEN PRINT"DBUG: RTRK":PROCres
IF R%=0 THEN I%=4
NEXT
R%=0:PROCs16(B%+6,S%)
ENDPROC

DEF PROCg8271
PROCstor(B%+&200,&FF,3125)
K%=0
FOR I%=0 TO J%-1
REM Write in sector header and CRC.
M%=B%+&200+FNcstime(I%)-1
?M%=&FE:!(M%+1)=!(B%+&20+I%*4)
PROCcrc16(M%,5):?(M%+5)=R% DIV 256:?(M%+6)=R%
M%=M%+7+17
G%(3)=K%:K%=FNstime(I%)
PROCbufs(&4000,&4800)
V%(0)=FNidtrk(I%):V%(1)=FNidsec(I%):V%(2)=1:V%(3)=2048:PROCread:R%=R% AND &FF
IF R%=&18 THEN PRINT"SECTOR READ FAILED":END
REM Copy in sector data.
IF R% AND &20 THEN ?M%=&F8 ELSE ?M%=&FB
M%=M%+1
IF I%=J%-1 THEN L%=3328 ELSE L%=FNcstime(I%+1)
L%=L%-(M%-B%-&200)
PROCcopy(M%,&4000,L%)
NEXT
R%=0
ENDPROC

DEF PROCwait(A%)
X%=TIME:REPEAT:UNTIL TIME>X%+A%
ENDPROC

DEF FNhex(A%)
A$=STR$~(A%)
IF LEN(A$)=1 THEN A$="0"+A$
=A$

DEF FNg16(A%):=?A%+?(A%+1)*256
DEF PROCs16(A%,X%):?A%=X%:?(A%+1)=(X% AND &FF00) DIV 256:ENDPROC

DEF FNssize(A%)
A%=A% AND 7
IF A%=1 THEN =256
IF A%=2 THEN =512
IF A%=3 THEN =1024
IF A%=4 THEN =2048
=128
DEF FNcrcerr(A%):=?(B%+&E0+A%) AND &80
DEF FNsizem(A%):=?(B%+&E0+A%) AND &40
DEF FNidtrk(A%):=?(B%+&20+A%*4)
DEF FNidsec(A%):=?(B%+&20+A%*4+2)
DEF FNidsiz(A%):=?(B%+&20+A%*4+3)
DEF FNrsiz(A%):A%=?(B%+&E0+A%):=FNssize(A%)
DEF FNsaddr(A%):=B%+&200+?(B%+&140+A%*2)+?(B%+&141+A%*2)*256
DEF FNstime(A%):=FNg16(B%+&A0+A%*2)
DEF FNtlen:=FNg16(B%+6)

DEF FNcstime(A%)
A%=FNstime(A%)
X%=FNtlen:IF X%=0 THEN X%=3125
=(3125/FNdrvspd)*(X%/3125)*A%

DEF FNdrvspd:=FNg16(Z%+4)
