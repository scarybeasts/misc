OSWRCH = &FFEE
OSBYTE = &FFF4

ORG &2000

.test_start
  SEI

  \\ *TV0,1 to disable interlace.
  LDA #144
  LDX #0
  LDY #1
  JSR OSBYTE

  \\ MODE4.
  LDA #22
  JSR OSWRCH
  LDA #4
  JSR OSWRCH

  \\ Print some characters.
  LDA #15
  STA &70
  .loop_characters_outer
  LDX #65
  LDY #60
  .loop_characters_inner
  TXA
  JSR OSWRCH
  INX
  DEY
  BNE loop_characters_inner
  DEC &70
  BNE loop_characters_outer

  LDA #8
  STA &FE00
  .vsync_check
  \\ Disable interlace.
  LDA #0
  STA &FE01
  LDA #2
  STA &FE4D
  .vsync_loop
  BIT &FE4D
  BEQ vsync_loop
  STA &FE4D
  \\ Enable interlace.
  LDA #1
  STA &FE01
  LDX #10
  JSR delay
  \\ vsync will have fired again if we're in the even frame.
  LDA &FE4D
  AND #2
  BEQ vsync_check

  \\ We're in the even frame, but R6 was hit to the frame counter is ready to
  \\ become odd in the next frame.
  \\ Embrace the oddness... become the oddness. Make sure R6 isn't hit again.
  LDA #6
  STA &FE00
  LDA #&FF
  STA &FE01

  \\ Interlace sync and video, no cursor.
  LDA #8
  STA &FE00
  LDA #&C3
  STA &FE01

  \\ Effectively 8 scanlines per row.
  LDA #9
  STA &FE00
  LDA #14
  STA &FE01

  .loop
  JMP loop

  .delay
  DEX
  BNE delay
  RTS

.test_end

SAVE "!BOOT", test_start, test_end
