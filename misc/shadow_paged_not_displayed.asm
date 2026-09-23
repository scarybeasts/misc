CPU 1

OSWRCH = &FFEE
OSBYTE = &FFF4

ORG &2F00

.test_start
  SEI

  \\ MODE2.
  LDA #22
  JSR OSWRCH
  LDA #2
  JSR OSWRCH

  \\ Interlace off, cursor off.
  LDA #8
  STA &FE00
  LDA #&C0
  STA &FE01

  \\ CRTC MA to 0.
  LDA #12
  STA &FE00
  STZ &FE01
  LDA #13
  STA &FE00
  STZ &FE01

  LDA #0
  STA self_modify + 2
  LDY #0
  .loop3
  LDA #&55
  .self_modify
  STA &FF00,Y
  INY
  BNE loop3
  INC self_modify + 2
  LDA self_modify + 2
  CMP #&2F
  BNE loop3

  \\ Page in LYNNE, HAZEL, don't display them.
  LDA #&0C
  STA &FE34

  .loop
  JMP loop

.test_end

SAVE "!BOOT", test_start, test_end
