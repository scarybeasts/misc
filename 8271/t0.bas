MODE 7
PRINT "8271 TEST"
PRINT "READ THE UNREADABLE"
PRINT "READ LOGICAL T0 ON T20"
*LOAD IASM 2800
*TAPE
REM init
CALL &2800
REM seek 20
PRINT "(seek 20)"
A%=20:CALL &2803
REM format 1 sector, logical IDs 0
PRINT "(format)"
!&5000=0
?&70=0
?&71=&50
A%=20:X%=&21:CALL &2806
REM normal way to read track mismatch
PRINT "(set track register)"
A%=0:CALL &280C
PRINT "(read)"
A%=0:X%=0:Y%=&21:CALL &280F
PRINT "SHOULD READ REAL TRACK 0"
PRINT "SHOULD GET 31373238"
PRINT "ACTUAL: " + STR$~(!&5000)
REM re-seek
PRINT "(seek 0)"
A%=0:CALL &2803
PRINT "(seek 20)"
A%=20:CALL &2803
REM read logical track 0 trick
PRINT "(mutant read)"
A%=20:X%=0:Y%=&21:CALL &2809
PRINT "SHOULD GET E5E5E5E5"
PRINT "ACTUAL: " + STR$~(!&5000)
