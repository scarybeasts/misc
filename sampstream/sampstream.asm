BASE = &2000
ZP = &80

ZP_BUF = (ZP + 0)

BUF1 = &5800
BUF2 = &6C00
RENDER_ROW1 = (&6700 + (4 * 8))
RENDER_ROW2 = (&6840 + (4 * 8))
DOT_VALUE_PAGE = &5600
DOT_Y_HISTORY_PAGE = &5700

QUICDISC_BASE = &1900
QUICDISC_ZP = &70
QUICDISC_INIT = (QUICDISC_BASE + 0)
QUICDISC_SEEK = (QUICDISC_BASE + 3)
QUICDISC_READ = (QUICDISC_BASE + 6)
QUICDISC_STATUS = (QUICDISC_BASE + 9)
QUICDISC_WAIT = (QUICDISC_BASE + 12)
QUICDISC_BUF = (QUICDISC_ZP + 0)

DISC_START_TRACK = 1
\\ 153us - 2 for overhead == 6.5kHz
PLAYBACK_RATE = ((1000000 / 6500) - 2)

ORG ZP
GUARD (ZP + 16)
.var_zp_buf SKIP 2
.var_zp_byte1 SKIP 1
.var_zp_byte2 SKIP 1
.var_zp_track SKIP 1
.var_zp_side SKIP 1
.var_zp_disc_seeking SKIP 1
.var_zp_render_row1 SKIP 2
.var_zp_render_row2 SKIP 2
.var_zp_dot_x SKIP 1

ORG BASE

.sampstream_begin

    SEI

    LDA #LO(BUF1)
    STA var_zp_buf
    LDA #HI(BUF1)
    STA var_zp_buf + 1
    LDA #DISC_START_TRACK
    STA var_zp_track
    LDA #0
    STA var_zp_side
    STA var_zp_disc_seeking

    LDA #LO(RENDER_ROW1)
    STA var_zp_render_row1
    LDA #HI(RENDER_ROW1)
    STA var_zp_render_row1 + 1
    LDA #LO(RENDER_ROW2)
    STA var_zp_render_row2
    LDA #HI(RENDER_ROW2)
    STA var_zp_render_row2 + 1
    LDA #0
    STA var_zp_dot_x

    LDA #8
    LDX #0
  .clear_dot_history_page_loop
    STA DOT_Y_HISTORY_PAGE, X
    INX
    BNE clear_dot_history_page_loop
    LDA #&80
  .calculate_dot_value_page_loop
    STA DOT_VALUE_PAGE, X
    LSR A
    BNE no_dot_value_rollover
    LDA #&80
  .no_dot_value_rollover
    INX
    BNE calculate_dot_value_page_loop

    \\ Subtract 32 here so that we draw at the start of the screen row, not
    \\ the start of where the scope actually changes.
    SEC
    LDA var_zp_render_row2
    SBC #32
    STA var_zp_render_row2
    LDY #0
    CLC
    LDX #40
  .render_draw_line
    LDA #&FF
    STA (var_zp_render_row2),Y
    LDA var_zp_render_row2
    ADC #8
    STA var_zp_render_row2
    BNE no_render_draw_line_wrap
    INC var_zp_render_row2 + 1
    CLC
  .no_render_draw_line_wrap
    DEX
    BNE render_draw_line

    LDA #LO(RENDER_ROW2)
    STA var_zp_render_row2
    LDA #HI(RENDER_ROW2)
    STA var_zp_render_row2 + 1

    JSR QUICDISC_INIT

    \\ Load the first couple of tracks.
    LDA var_zp_track
    INC var_zp_track
    JSR QUICDISC_SEEK
    JSR QUICDISC_WAIT
    LDA #LO(BUF1)
    STA QUICDISC_BUF
    LDA #HI(BUF1)
    STA QUICDISC_BUF + 1
    LDA #0
    JSR QUICDISC_READ
    JSR QUICDISC_WAIT
    LDA var_zp_track
    INC var_zp_track
    JSR QUICDISC_SEEK
    JSR QUICDISC_WAIT
    LDA #LO(BUF2)
    STA QUICDISC_BUF
    LDA #HI(BUF2)
    STA QUICDISC_BUF + 1
    LDA #0
    JSR QUICDISC_READ
    JSR QUICDISC_WAIT

    \\ Set up audio.
    \\ System VIA port A to output.
    LDA #&FF
    STA &FE43
    \\ Keyboard to auto-scan.
    LDA #&0B
    STA &FE40
    \\ Zero volumes.
    LDA #&FF
    JSR sound_write_slow
    LDA #&DF
    JSR sound_write_slow
    LDA #&BF
    JSR sound_write_slow
    LDA #&9F
    JSR sound_write_slow
    \\ Period to 1 on tone channels (1, 2, 3)
    LDA #&C1
    JSR sound_write_slow
    LDA #0
    JSR sound_write_slow
    LDA #&A1
    JSR sound_write_slow
    LDA #0
    JSR sound_write_slow
    LDA #&81
    JSR sound_write_slow
    LDA #0
    JSR sound_write_slow

    \\ Leave the sound write gate open all the time.
    \\ Leaving the sound write gate open has been know to lead to SN state
    \\ corruption, but in our limited case of only ever changing the volume on
    \\ a single channel, it works.
    \\LDA #&9F
    \\STA &FE4F
    \\LDA #0
    \\STA &FE40

    \\ Set up USER VIA timer.
    \\ Continuous T1.
    LDA #&40
    STA &FE6B
    LDA #PLAYBACK_RATE
    STA &FE64
    LDA #0
    STA &FE65
    \\ Clear IFR just in case.
    LDA #&7F
    STA &FE6D

    \\ Main loop.
.main
    \\ Load 2 half bytes into 2 bytes.
    LDY #0
    LDA (var_zp_buf),Y
    TAX
    AND #&0F
    STA var_zp_byte2
    LDA #0
    STA (var_zp_buf),Y
    TXA
    LSR A
    LSR A
    LSR A
    LSR A
    STA var_zp_byte1

    \\ Deliver first half.
    LDA #&40
  .timer_wait_1
    BIT &FE6D
    BEQ timer_wait_1
    STA &FE6D
    LDA var_zp_byte1
    ORA #&90
    \\STA &FE4F
    JSR sound_write_slow

    LDX var_zp_dot_x
    INC var_zp_dot_x
    LDA DOT_Y_HISTORY_PAGE, X
    CMP #8
    BCS value1_history_row2
    TAY
    LDA (var_zp_render_row1),Y
    EOR DOT_VALUE_PAGE, X
    STA (var_zp_render_row1),Y
    JMP value1_history_done
  .value1_history_row2
    AND #&07
    TAY
    LDA (var_zp_render_row2),Y
    EOR DOT_VALUE_PAGE, X
    STA (var_zp_render_row2),Y

  .value1_history_done
    LDA var_zp_byte1
    STA DOT_Y_HISTORY_PAGE, X
    CMP #8
    BCS value1_draw_row2
    TAY
    LDA (var_zp_render_row1),Y
    EOR DOT_VALUE_PAGE, X
    STA (var_zp_render_row1),Y
    JMP value1_draw_done
  .value1_draw_row2
    AND #&07
    TAY
    LDA (var_zp_render_row2),Y
    EOR DOT_VALUE_PAGE, X
    STA (var_zp_render_row2),Y

  .value1_draw_done
    \\ Swap buffers if needed.
    INC var_zp_buf
    BNE no_buffer_swap
    LDX var_zp_buf + 1
    CPX #(HI(BUF1) + &09)
    BEQ swap_to_buf2
    CPX #(HI(BUF2) + &09)
    BEQ swap_to_buf1
    INX
    STX var_zp_buf + 1
    JMP no_buffer_swap

  .swap_to_buf1
    \\ Set seek to pending.
    LDA #2
    STA var_zp_disc_seeking

    \\ Swap to buf1 read, buf2 disc load.
    LDA #HI(BUF1)
    STA var_zp_buf + 1
    LDA #HI(BUF2)
    STA QUICDISC_BUF + 1

    JMP second_byte

  .swap_to_buf2
    \\ Set seek to pending.
    LDA #2
    STA var_zp_disc_seeking

    \\ Swap to buf2 read, buf1 disc load.
    LDA #HI(BUF2)
    STA var_zp_buf + 1
    LDA #HI(BUF1)
    STA QUICDISC_BUF + 1

    JMP second_byte

  .no_buffer_swap
    \\ If we didn't swap buffers, we may still be pending seek or seeking.
    LDX var_zp_disc_seeking
    BEQ second_byte
    DEX
    BEQ do_seek_end_check
    \\ Seek is pending. Set state to seeking and then seek.
    STX var_zp_disc_seeking

    LDX var_zp_track
    CPX #80
    BEQ do_side_swap
    TXA
    LDY var_zp_side
    BEQ do_seek_up
    \\ On drive 2, seeking down.
    DEX
    STX var_zp_track
    JMP do_seek
  .do_seek_up
    INX
    STX var_zp_track
  .do_seek
    JSR QUICDISC_SEEK

    JMP second_byte

  .do_seek_end_check
    JSR QUICDISC_STATUS
    BNE second_byte
    \\ Seek ended. Switch to read.
    STA var_zp_disc_seeking
    LDA var_zp_side
    JSR QUICDISC_READ

    JMP second_byte

  .do_side_swap
    LDA #1
    STA var_zp_side
    \\ We're already at track 79, no need to seek. Seek to 78 next time.
    LDA #78
    STA var_zp_track

    JMP second_byte

  .second_byte
    \\ Deliver second half.
    LDA #&40
  .timer_wait_2
    BIT &FE6D
    BEQ timer_wait_2
    STA &FE6D
    LDA var_zp_byte2
    ORA #&90
    \\STA &FE4F
    JSR sound_write_slow

    LDX var_zp_dot_x
    LDA DOT_Y_HISTORY_PAGE, X
    CMP #8
    BCS value2_history_row2
    TAY
    LDA (var_zp_render_row1),Y
    EOR DOT_VALUE_PAGE, X
    STA (var_zp_render_row1),Y
    JMP value2_history_done
  .value2_history_row2
    AND #&07
    TAY
    LDA (var_zp_render_row2),Y
    EOR DOT_VALUE_PAGE, X
    STA (var_zp_render_row2),Y

  .value2_history_done
    LDA var_zp_byte2
    STA DOT_Y_HISTORY_PAGE, X
    CMP #8
    BCS value2_draw_row2
    TAY
    LDA (var_zp_render_row1),Y
    EOR DOT_VALUE_PAGE, X
    STA (var_zp_render_row1),Y
    JMP value2_draw_done
  .value2_draw_row2
    AND #&07
    TAY
    LDA (var_zp_render_row2),Y
    EOR DOT_VALUE_PAGE, X
    STA (var_zp_render_row2),Y

  .value2_draw_done
    INX
    STX var_zp_dot_x
    TXA
    AND #&07
    BEQ do_dot_next_byte

    JMP main

  .do_dot_next_byte
    CLC
    LDA var_zp_render_row1
    ADC #8
    STA var_zp_render_row1
    BNE zp_render_row1_no_rollover
    INC var_zp_render_row1 + 1
    CLC

  .zp_render_row1_no_rollover
    LDA var_zp_render_row2
    ADC #8
    STA var_zp_render_row2
    BNE zp_render_row2_no_rollover
    INC var_zp_render_row2 + 1

  .zp_render_row2_no_rollover
    TXA
    BEQ do_dot_restart_row

    JMP main

  .do_dot_restart_row
    LDA #LO(RENDER_ROW1)
    STA var_zp_render_row1
    LDA #HI(RENDER_ROW1)
    STA var_zp_render_row1 + 1
    LDA #LO(RENDER_ROW2)
    STA var_zp_render_row2
    LDA #HI(RENDER_ROW2)
    STA var_zp_render_row2 + 1

    JMP main

.sound_write_slow
    STA &FE4F
    LDX #&00
    STX &FE40
    \\ Sound write held low for 8us.
    \\ Seems to work at 6us, not 5us on an issue 3 beeb.
    NOP
    NOP
    NOP
    NOP
    LDX #&08
    STX &FE40
    RTS

.sampstream_end

SAVE "SSTREAM", sampstream_begin, sampstream_end
PUTFILE "QUICDSC", "QUICDSC", &1900
PUTFILE "boot.txt", "!BOOT", 0
