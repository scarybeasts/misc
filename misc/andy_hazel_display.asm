CPU 1

OSWRCH = &FFEE
OSBYTE = &FFF4

ORG &2000

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

  \\ Display and page in LYNNE, HAZEL.
  LDA #&0D
  STA &FE34

  \\ Page in ANDY.
  LDA #&80
  STA &FE30

  \\ Fill!
  LDA #&80
  STA &71
  STZ &70
  LDY #0
  .loop1
  LDA #1
  STA (&70),Y
  INY
  BNE loop1
  INC &71
  LDA &71
  CMP #&90
  BNE loop1

  LDA #&C0
  STA &71
  LDY #0
  .loop2
  LDA #&44
  STA (&70),Y
  INY
  BNE loop2
  INC &71
  LDA &71
  CMP #&E0
  BNE loop2

  LDA #&30
  STA &71
  LDY #0
  .loop3
  LDA #&55
  STA (&70),Y
  INY
  BNE loop3
  INC &71
  LDA &71
  CMP #&80
  BNE loop3

  .loop
  JMP loop

.test_end

SAVE "!BOOT", test_start, test_end
