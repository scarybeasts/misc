MODE 7
PRINT "8271 TEST"
PRINT "LATENCY TEST"
PRINT "WRITE SPECIAL REGISTER"
*TAPE
P%=&2000
[ OPT 0
SEI
LDA #&40
STA &0D00
LDA #255
STA &FE64
LDA #0
STA &FE65
LDA #&7A
STA &FE80
.loop_cmd
LDA &FE80
AND #&40
BNE loop_cmd
LDA #&07
STA &FE81
.loop_p1
LDA &FE80
AND #&20
BNE loop_p1
LDA #&FF
STA &FE81
.loop_p2
LDA &FE80
AND #&20
BNE loop_p2
.loop_busy
LDA &FE80
AND #&80
BNE loop_busy
LDA &FE64
STA &70
CLI
RTS
]
FOR I%=1 TO 10
CALL &2000
PRINT 255-?&70
NEXT
