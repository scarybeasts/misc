ORG &2000

\\ The entry point.
.binary_start
  SEI

  JSR init_hardware

  \\ Build a couple of waveform tables, exponential saw-ish.
  \\ 256 byte for 1 cycle, plays a 244Hz sound at 62.5kHz playback.
  \\ For SN tone channel 1.
  LDX #0
  .loop_table1
  TXA
  LSR A:LSR A:LSR A:LSR A
  ORA #&90
  STA &3000,X
  INX
  BNE loop_table1

  \\ 128 byte for 1 cycle, plays a 488Hz sound at 62.5kHz playback.
  \\ For SN tone channel 2.
  LDX #0
  .loop_table2
  TXA
  LSR A:LSR A:LSR A
  AND #&0F
  ORA #&B0
  STA &4000,X
  INX
  BNE loop_table2

  \\ Silence on noise.
  LDA #&FF
  STA &FE4F
  \\ Open the sound write gate and leave open.
  LDA &00
  LDA #&00
  \\ 5 cycles, shorter 2 cycle 1MHz write.
  STA &FE40
  \\ Aligned to even cycle.
  \\ 1us for SN write gate to low, then 9us before it's the time to change
  \\ the bus value.
  \\ For a total requirement of 10us, and 16us multiples thereafter.

  NOP:NOP:NOP:NOP
  LDX #0
  LDA #&9F
  \\ +6us

  .loop
  STA &00
  STA &FE4F
  \\ +10us
  LDA &3000,X
  LDY &4000,X
  STA &00
  STY &FE4F
  \\ +18us
  INX
  STA &00
  JMP loop

  .init_hardware
  \\ System VIA port A to output.
  LDA #&FF
  STA &FE43
  \\ Keyboard to auto-scan mode.
  LDA #&0B
  STA &FE40

  \\ Channels 1, 2, 3 to period 1, 2, 3.
  LDA #&81
  JSR sound_write
  LDA #0
  JSR sound_write
  LDA #&A2
  JSR sound_write
  LDA #0
  JSR sound_write
  LDA #&C3
  JSR sound_write
  LDA #0
  JSR sound_write

  \\ Tone 1, 2, 3 to midpoint volume and noise channel to silent.
  LDA #&93
  JSR sound_write
  LDA #&B3
  JSR sound_write
  LDA #&D3
  JSR sound_write
  LDA #&FF
  JSR sound_write

  RTS

  .sound_write
  STA &FE4F
  LDA #&00
  STA &FE40
  \\ Sound write held low for 8us, which is plenty.
  NOP:NOP:NOP:NOP
  LDA #&08
  STA &FE40
  RTS

  .jsr_wait_12_cycles
  RTS

.binary_end

SAVE "!BOOT", binary_start, binary_end
