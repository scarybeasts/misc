MODE 7
PRINT "8271 TEST"
PRINT "WRITE ARBITRARY FM"
*LOAD IASM 2800
*TAPE
REM init, seeks to 0
CALL &2800
REM seek 20
PRINT "(seek 20)"
A%=20:CALL &2803
REM format 1 sector
PRINT "(format)"
!&5000=&01000014
?&70=0
?&71=&50
A%=20:X%=&21:CALL &2806
REM crazy write trick
PRINT "(mutant write)"
B%=&5000
PROCrun(16, &FF):PROCrun(6, &00)
?B%=&FE
!(B%+1)=&01EE0014
?(B%+5)=&FF
?(B%+6)=&FF
A%=20:X%=0:Y%=&21:CALL &2812
REM and check sector IDs
PRINT "(read ids)"
A%=20:X%=2:CALL &2815
PRINT "EXPECT: 1000014 1EE0014"
PRINT ~!&5000
PRINT ~!&5004
END

DEF PROCrun(X%, Y%)
FOR I%=1 TO X%:?B%=Y%:B%=B%+1:NEXT
ENDPROC
