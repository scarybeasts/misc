MODE7:HIMEM=&4A00
VDU129,157,131:PRINT"Disc BEAST v0.3.2":PRINT
REM BSTASM, DUTLASM, Buffers.
D%=&4A00:Z%=&60:U%=&5200:W%=&50:B%=&5C00
REM Params, globals.
DIM V%(8),G%(8)
REM CRC.
DIM C% 11
F$="DISC":G%(6)=1:G%(7)=1

REPEAT

INPUT A$:IF LEN(A$)<4 THEN A$="????"
P$=MID$(A$,5):A$=LEFT$(A$,4)
FOR I%=0 TO 8:V%(I%)=-1:NEXT

I%=0
REPEAT
J%=INSTR(P$," "):IF J%=0 THEN J%=LEN(P$)
Q$=LEFT$(P$,J%)
IF LEN(Q$)<>0 AND Q$<>" " AND Q$<"A" THEN V%(I%)=EVAL(Q$):I%=I%+1
P$=RIGHT$(P$,LEN(P$)-J%)
UNTIL LEN(P$)=0
P%=I%

REM Buffers. &5400-&7BFF.
B%=&5C00:PROCbufs(B%,B%+4096):PROCs16(Z%+6,G%(3)):PROCs16(Z%+8,-G%(4))
IF A$="INIT" THEN PROCsetup:A$=""
IF A$="DUMP" THEN PROCdump(V%(0)):A$=""
IF A$="BFIL" THEN PROCbfil:A$=""
IF A$="BSET" THEN PROCbset:A$=""
IF A$="SEEK" THEN T%=V%(0):PROCseek:A$=""
IF A$="RIDS" THEN PROCclr:PROCrids:PROCres:PRINT"SECTOR HEADERS: "+STR$(S%):PROCdump(0):A$=""
IF A$="READ" THEN PROCclr:PROCread:PROCres:PROCdtim:L%=FNg16(Z%)-B%:!C%=-1:PROCcrca32(B%,L%,C%):PROCcrcf32(C%):PRINT"CRC32 "+STR$(L%)+" BYTES: "+STR$~(!C%):PROCdump(0):A$=""
IF A$="RTRK" THEN PROCclr:PROCrtrk:PROCres:PRINT"LEN: "+STR$(S%):PROCdump(0):A$=""
IF A$="WRIT" THEN PROCwrit:PROCres:A$=""
IF A$="WTRK" THEN PROCwtrk:PROCres:A$=""
IF A$="TIME" THEN PROCtime:PRINT"DRIVE SPEED: "+STR$(FNdrvspd):A$=""
IF A$="DTRK" THEN PROCdtrk:A$=""
IF A$="DCRC" THEN PROCdcrc:A$=""
IF A$="HFEG" THEN PROChfeg:A$=""
IF A$="HFEP" THEN PROChfep:A$=""
IF A$="DBUG" THEN PROCgset(2):A$=""
IF A$="STRT" THEN PROCgset(3):A$=""
IF A$="BAIL" THEN PROCgset(4):A$=""
IF A$="DSTP" THEN PROCgset(5):A$=""
IF A$="FDRV" THEN PROCgset(6):A$=""
IF A$="AUTO" THEN PROCgset(7):A$=""
IF A$="DR40" THEN PROCgset(8):A$=""
IF A$="BFUN" THEN ?(Z%+10)=V%(0):A$=""
IF A$="FSYS" THEN F$=Q$:G%(6)=-1:PRINT"FSYS "+F$:A$=""
IF A$="CMFM" THEN PROCcmfm:A$=""

IF A$<>"" THEN PRINT "UNKNOWN COMMAND"

UNTIL FALSE

DEF PROCgset(A%)
G%(A%)=V%(0):PRINT A$+" "+STR$(V%(0))
ENDPROC

DEF PROCsetup
A%=V%(0):T%=0
IF A%<0 THEN A%=0
G%(0)=A%
A%=USR(D%) AND &FF
IF A%=0 THEN PRINT"FAIL":END
IF A%=1 THEN PRINT"OK 8271"
IF A%=2 THEN PRINT"OK 1770"
G%(1)=A%
PRINT"DRIVE "+STR$(G%(0))+" SPEED: "+STR$(FNdrvspd)
PRINT"ENSURE DRIVE IN 80 TRACK MODE"
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
J%=(R% AND &FF00) DIV 256
PRINT"RESULT: &" + STR$~(I%);
IF I%<>J% THEN PRINT" (&"+STR$~(J%)+")" ELSE PRINT
ENDPROC

DEF PROCdtim
A%=V%(3)/128
X%=FNg16(B%+4096)
Y%=FNg16(B%+4096+A%*2)
PRINT"TIME: "+STR$(Y%-X%)
ENDPROC

DEF PROCstor(A%,X%,Y%)
PROCs16(W%,A%)
Y%=-Y%:PROCs16(W%+4,Y%)
A%=X%:CALL U%
ENDPROC

DEF PROCcopy(A%,X%,Y%):PROCs16(W%,A%):PROCs16(W%+2,X%):Y%=-Y%:PROCs16(W%+4,Y%):CALL U%+3:ENDPROC

DEF PROCmfm(A%,X%,Y%):PROCs16(W%,A%):PROCs16(W%+2,X%):Y%=-Y%:PROCs16(W%+4,Y%):CALL U%+15:ENDPROC

DEF PROCcmp(A%,X%,Y%):PROCs16(W%,A%):PROCs16(W%+2,X%):Y%=-Y%:PROCs16(W%+4,Y%):R%=USR(U%+12) AND &FF:ENDPROC

DEF PROCcrc16(A%,X%)
PROCs16(W%+2,A%)
X%=-X%:PROCs16(W%+4,X%)
X%=&FF:Y%=&FF
R%=USR(U%+6):X%=(R% AND &FF00) DIV &100:Y%=(R% AND &FF0000) DIV &10000
R%=X%*256+Y%
ENDPROC

DEF PROCcrca32(A%,X%,Y%)
PROCs16(W%,Y%):PROCs16(W%+2,A%)
X%=-X%:PROCs16(W%+4,X%)
CALL U%+9
ENDPROC

DEF PROCcrcf32(A%)
!(C%+8)=!A% EOR &FFFFFFFF
?A%=?(C%+11)
?(A%+1)=?(C%+10)
?(A%+2)=?(C%+9)
?(A%+3)=?(C%+8)
ENDPROC

DEF PROCbufs(A%,Y%):PROCs16(Z%,A%):PROCs16(Z%+2,Y%):PROCs16(Z%+11,&7000):ENDPROC

DEF PROCseek
A%=T%:IF A%=-1 THEN A%=0
IF G%(5) THEN A%=A%*2
CALL D%+9
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
ENDPROC

DEF PROCrw(I%)
IF V%(0)=-1 THEN V%(0)=T%
IF V%(1)=-1 THEN V%(1)=0
IF V%(2)=-1 THEN V%(2)=1
IF V%(3)=-1 THEN V%(3)=256
X%=V%(1):Y%=V%(2):A%=V%(3)
IF A%=256 THEN Y%=Y%+&20
IF A%=512 THEN Y%=Y%+&40
IF A%=1024 THEN Y%=Y%+&60
IF A%=2048 THEN Y%=Y%+&80
IF A%=4096 THEN Y%=Y%+&A0
A%=V%(0):R%=USR(D%+I%)
ENDPROC

DEF PROCread:PROCrw(18):ENDPROC

DEF PROCwrit:PROCrw(24):ENDPROC

DEF PROCrtrk
IF G%(1)<>2 THEN PRINT"RTRK 1770 ONLY":ENDPROC
S%=FNg16(Z%):A%=V%(0):R%=USR(D%+12):S%=FNg16(Z%)-S%
ENDPROC

DEF PROCwtrk
IF G%(1)<>2 THEN PRINT"WTRK 1770 ONLY":ENDPROC
A%=V%(0):R%=USR(D%+27)
ENDPROC

DEF PROCcmfm:PROCcopy(B%+4096,B%,4096):PROCmfm(B%,B%+4096,4096):ENDPROC

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
IF J%=0 THEN ENDPROC
FOR I%=0 TO J%-1
IF FNcrcerr(I%) THEN VDU129:PRINT"SECTOR "+STR$(I%)+" CRC ERROR"
IF FNsizem(I%) THEN VDU131:PRINT"SECTOR "+STR$(I%)+" SIZE MISMATCH"
IF FNidtrk(I%)<>T% THEN VDU134:PRINT"SECTOR "+STR$(I%)+" TRACK MISMATCH"
NEXT
PRINT "TRACK CRC32 "+STR$~(!C%)
ENDPROC

DEF PROCtcrc
!C%=-1
J%=?(B%+5)
IF J%=0 THEN !C%=0:ENDPROC
FOR I%=0 TO J%-1
VDU8,48+I%
K%=1
IF FNcrcerr(I%) THEN K%=0
L%=FNidtrk(I%)
IF L%=&FF OR (L%=0 AND T%<>0) THEN K%=0
L%=FNrsiz(I%)+1
M%=FNsaddr(I%)
N%=?M%:?M%=N% OR &F0
IF K%=1 THEN PROCcrca32(M%,L%,C%)
?M%=N%
NEXT
PROCcrcf32(C%)
ENDPROC

DEF PROCtrk:IF T% AND 1 THEN B%=&6C00 ELSE B%=&5C00
VDU135,46:PROCclr:VDU8,83:PROCseek:PROCgtrk:PROCtcrc:!(B%+12)=!C%:VDU8,8
ENDPROC

DEF PROCpcrc:VDU130:PRINT "DISC CRC32 "+STR$~(!(C%+4))
IF (T%=41 OR T%=81) AND !C%<>0 THEN PRINT"WARN: PAST END TRACK"
ENDPROC

DEF PROCchks
A%=G%(5):I%=80:IF G%(8) THEN I%=40
PRINT"(DRIVE TYPE "+STR$(I%)+", DOUBLE STEP: "+STR$(A%)+")"
IF A% AND V%(7)>40 THEN PRINT"ERR: >40 TRACKS AND DOUBLE STEP"
ENDPROC

DEF PROCauto
V%(6)=V%(0):IF V%(0)=-1 THEN V%(6)=0
V%(7)=V%(1):IF V%(1)=-1 THEN V%(7)=40
IF G%(7)=0 OR G%(8) THEN ENDPROC
IF G%(1)<>2 THEN PRINT"AUTO 1770 ONLY":ENDPROC
PRINT"WARN: DRIVE MUST BE 80 TRACK":G%(5)=0
FOR T%=1 TO 21 STEP 20
PROCseek:PROCbufs(B%,B%+4096):PROCrids:R%=R% AND &FF:PRINT"TRACK "+STR$(T%)+" READ IDS: &"+STR$~(R%)
IF R%=0 THEN T%=100
NEXT
IF T%=41 THEN G%(5)=1
I%=80-G%(5)*40:PRINT"AUTO DISC TRACKS: "+STR$(I%)
IF V%(1)=-1 THEN V%(7)=I%
ENDPROC

DEF PROCdcrc
PROCauto:PROCchks
!(C%+4)=-1
FOR T%=V%(6) TO V%(7)
IF (T% AND 3)=0 THEN PRINT:PRINT STR$(T%);
PROCretry
IF R%=2 THEN T%=V%(7) ELSE PRINT" "+STR$~(!C%);
NEXT
PRINT:IF R%=2 THEN PRINT"FAIL" ELSE PROCcrcf32(C%+4):PROCpcrc
ENDPROC

DEF PROCretry
V%(4)=5
REPEAT:V%(4)=V%(4)-1:PROCtrk
S%=0:IF R%=1 OR R%=2 THEN VDU7,129,33,8,8:IF V%(4)<>0 THEN PROCwait(100):T%=T%-1:PROCseek:T%=T%+1:PROCseek:S%=1
UNTIL S%=0 OR V%(4)=0
PROCcrca32(C%,4,C%+4)
ENDPROC

DEF PROChfeg
PROCauto:PROCchks
PRINT:VDU132,157,134:PRINT"HFE Grab v0.3"
!(C%+4)=-1:V%(5)=V%(2)
PRINT"TRACKS "+STR$(V%(6))+" TO "+STR$(V%(7))
IF V%(5)=0 THEN PRINT"(NOT SAVING)"
FOR T%=V%(6) TO V%(7)
IF (T% AND 1)=0 THEN PROCstor(&5C00,0,8192)
IF (T% MOD 10)=0 THEN PRINT:PRINT STR$(T%)+" ";
IF T%=0 THEN VDU32
PROCretry
IF R%<>2 AND T%=V%(7) THEN PROCcrcf32(C%+4):!(B%+28)=!(C%+4)
IF R%<>2 THEN PROChfegy ELSE T%=V%(7)
NEXT
PRINT:IF R%=2 THEN PRINT"FAIL" ELSE PROCpcrc
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
VDU128+I%,K%,J%
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
PROCfsel:OSCLI("SAVE TRKS"+STR$(T% AND &FE)+" 5C00 +2000")
ENDPROC

DEF PROCfsel
OSCLI(F$)
A%=G%(6):IF T%>40 THEN A%=A%+2
IF G%(6)>-1 THEN OSCLI("DR."+STR$(A%))
ENDPROC

DEF PROChfep
V%(6)=V%(0):IF V%(0)=-1 THEN V%(6)=0
V%(7)=V%(1):IF V%(1)=-1 THEN V%(7)=40
PRINT"HFE PUT TRACKS "+STR$(V%(6))+" TO "+STR$(V%(7))
FOR T%=V%(6) TO V%(7)
VDU46:PROCfsel:OSCLI("LOAD TRKS"+STR$(T% AND &FE)+" 5C00"):PROCreinit
IF T% AND 1 THEN PROCcopy(&5C00,&6C00,4096)
PROCcopy(&5B00,&6B00,256):PROCcopy(&6E00,&5E00,3328):PROCmfm(&5E00,&6E00,3328)
J%=?(B%+5):IF J%>0 THEN PROChfef
PROCs16(W%,&5E00):PROCs16(W%+4,-6656):CALL U%+18
PROCseek
REPEAT
PROCbufs(&5E00,&5400):V%(0)=1:PROCwtrk:R%=R% AND &FF
IF R%=&A THEN VDU42
UNTIL R%<>&A
IF R%<>0 THEN PROCres
NEXT
ENDPROC

DEF PROChfef:FOR I%=0 TO J%-1:PROChfet(FNg16(B%+&100+I%*2)):PROChfet(FNg16(B%+&140+I%*2)):NEXT:ENDPROC

DEF PROChfet(A%)
A%=A%*2+&5E00:?A%=&F5:A%=A%+1
IF ?A%=&FE THEN ?A%=&7E
IF ?A%=&EF THEN ?A%=&6F
IF ?A%=&EA THEN ?A%=&6A
IF !(A%-5)=&AAAAAAAA THEN ENDPROC
FOR K%=2 TO 13:?(A%-K%)=&AA:NEXT
ENDPROC

DEF PROCgtrk
?B%=G%(1):?(B%+1)=T%:?(B%+2)=?(Z%+4):?(B%+3)=?(Z%+5):?(B%+&10)=3
PROCbufs(B%+&20,B%+&A0):PROCs16(Z%+6,0):PROCs16(Z%+8,0):VDU8,73:PROCrids
REM More 1770 ghosts.
IF S%=0 THEN R%=&18
R%=R% AND &FF:?(B%+4)=R%:?(B%+5)=S%
IF R%=&18 THEN R%=0:ENDPROC

IF R%<>0 THEN ?(B%+8)=1
IF R%<>0 AND G%(1)=1 THEN R%=1:ENDPROC
VDU8,82:IF G%(1)=1 THEN PROCg8271 ELSE PROCg1770
IF R%<>0 THEN ENDPROC

REM Timing based sector sizes.
J%=?(B%+5)
FOR I%=0 TO J%-1
IF I%=J%-1 THEN L%=FNtlen ELSE L%=FNcstime(I%+1)
L%=L%-FNcstime(I%)-24
A%=4
IF L%<2048 THEN A%=3
IF L%<1024 THEN A%=2
IF L%<512 THEN A%=1
IF L%<256 THEN A%=0
?(B%+&E0+I%)=A%
NEXT

REM Parse sectors.
FOR I%=0 TO J%-1
VDU8,48+I%
IF I%=0 THEN M%=FNcstime(I%)-1 ELSE M%=FNg16(B%+&100+(I%-1)*2)+FNcstime(I%)-FNcstime(I%-1)
P%=!(B%+&20+I%*4)
N%=0
FOR K%=-10 TO 10
L%=B%+&200+M%+K%
IF (?L%=&FE OR ?L%=&CE) AND !(L%+1)=P% THEN N%=1:M%=M%+K%:PROCs16(B%+&100+I%*2,M%):K%=10
NEXT
IF G%(2) AND N%=0 THEN PRINT"DBUG: HDR "+STR$~(X%):PROCdump(&200+M%-32)
FOR K%=14 TO 30
L%=B%+&200+M%+K%
IF ?L%=&FB OR ?L%=&CB OR ?L%=&F8 OR ?L%=&C8 THEN N%=N%+1:M%=M%+K%:PROCs16(B%+&140+I%*2,M%):K%=30
NEXT
IF N%=2 THEN PROCgtrky:R%=0 ELSE R%=2:I%=J%-1
NEXT
IF R%=0 AND ?(B%+8)=1 THEN R%=1
REM 1770 sees ghosts.
IF R%=2 AND ?(B%+4)<>0 THEN ?(B%+4)=&18:?(B%+5)=0:R%=3:ENDPROC
IF R%<>1 THEN ENDPROC
REM Check for weak bits.
FOR I%=0 TO J%-1
IF FNcrcerr(I%) THEN PROCweak
NEXT
R%=1
ENDPROC

DEF PROCweak
PROCrsec(I%)
IF R%<>0 AND R%<>&E THEN ENDPROC
A%=FNrsiz(I%):X%=FNssize(FNidsiz(I%))
IF X%<A% THEN A%=X%
PROCcmp(&5400,FNsaddr(I%)+1,A%)
A%=B%+&E0+I%:X%=FNg16(W%)-&5400
IF R%<>0 THEN ?A%=?A%+&20:PROCs16(B%+&F00+I%*2,X%)
ENDPROC

DEF PROCrsec(A%)
K%=0:IF A%>0 THEN K%=FNstime(A%)
PROCs16(Z%+6,K%):PROCs16(Z%+8,0):PROCbufs(&5400,&100)
V%(0)=FNidtrk(A%):V%(1)=FNidsec(A%):V%(2)=1:V%(3)=FNssize(FNidsiz(A%))
PROCread:R%=R% AND &FF
ENDPROC

DEF PROCgtrky
K%=B%+&E0+I%:M%=?K%+1
REM Try other sector sizes if CRC16 fails.
REPEAT:M%=M%-1
A%=FNssize(M%)+1
N%=?L%:?L%=N% OR &F0:PROCcrc16(L%,A%):?L%=N%
S%=?(L%+A%)*256+?(L%+A%+1)
UNTIL R%=S% OR M%=0
REM Tag size / CRC mismatches.
IF R%=S% THEN ?K%=M% ELSE M%=?K%:?K%=(?K%)+&80:?(B%+8)=1
IF M%<>FNidsiz(I%) THEN ?K%=(?K%)+&40
ENDPROC

DEF PROCg1770
FOR I%=1 TO 32
FOR J%=1 TO 4
PROCbufs(B%+&200,B%+&180):V%(0)=0:PROCrtrk:R%=R% AND &FF
IF R%<>0 THEN PROCres
IF R%=0 THEN J%=4
NEXT
K%=0
FOR J%=&202 TO &240
IF ?(B%+J%)=&CE THEN K%=1:J%=&240
IF ?(B%+J%)=&FE AND ?(B%+J%-2)=0 THEN J%=&240
NEXT
IF K%=0 THEN I%=32
NEXT
R%=0:PROCs16(B%+6,S%)
ENDPROC

DEF PROCg8271
PROCstor(B%+&200,&FF,3125):PROCstor(&5400,0,2048)
PROCs16(B%+6,3125):J%=?(B%+5):K%=0
FOR I%=0 TO J%-1
REM Write in sector header and CRC.
M%=B%+&200+FNcstime(I%)-1
?M%=&FE:!(M%+1)=!(B%+&20+I%*4)
PROCcrc16(M%,5):?(M%+5)=(R% AND &FF00) DIV 256:?(M%+6)=R%
M%=M%+7+17
PROCs16(Z%+6,K%):K%=FNstime(I%):PROCs16(Z%+8,0)
PROCbufs(&5400,&100)
V%(0)=FNidtrk(I%):V%(1)=FNidsec(I%):V%(2)=1:V%(3)=2048
R%=0:IF V%(0)<>&FF AND (T%=0 OR V%(0)<>0) THEN PROCread:R%=R% AND &FF
IF R%=&18 THEN PRINT"SECTOR READ FAILED: "+STR$~(V%(0))+" "+STR$~(V%(1)):END
REM Copy in sector data.
IF R% AND &20 THEN ?M%=&F8 ELSE ?M%=&FB
M%=M%+1
IF I%=J%-1 THEN L%=3328 ELSE L%=FNcstime(I%+1)
L%=L%-(M%-B%-&200)
PROCcopy(M%,&5400,L%)
NEXT:R%=0
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
DEF FNsaddr(A%):=B%+&200+FNg16(B%+&140+A%*2)
DEF FNstime(A%):=FNg16(B%+&A0+A%*2)
DEF FNtlen:=FNg16(B%+6)

DEF FNcstime(A%)
A%=FNstime(A%)
=A%*(FNtlen/FNdrvspd)

DEF FNdrvspd:=FNg16(Z%+4)
