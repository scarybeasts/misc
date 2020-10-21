\\ test.asm
\\ Trying to land some 8271 advanced tricks.

BASE = &2800
ZP = &70

ORG ZP
.var_zp_param_track_buf SKIP 2
.var_zp_param_marker_buf SKIP 2
.var_zp_param_drive_speed SKIP 2
GUARD (ZP + 15)

ORG (ZP + 16)
GUARD (ZP + 32)
.var_zp_A SKIP 1
.var_zp_X SKIP 1
.var_zp_Y SKIP 1
.var_zp_count SKIP 1
.var_zp_lead_in_length SKIP 2
.var_zp_track_length SKIP 2
.var_zp_marker_buf SKIP 2
.var_zp_marker_count SKIP 2
.var_zp_marker SKIP 1

ORG BASE

.i8271_begin

    \\ base + &00, load
    JMP entry_load
    \\ base + &03, seek
    JMP i8271_seek
    \\ base + &06, format
    JMP i8271_format
    \\ base + &09, read0
    JMP entry_read0
    \\ base + &0C, set track register
    JMP i8271_set_track_register
    \\ base + &0F, read
    JMP i8271_read
    \\ base + &12, write fm test
    JMP entry_write_fm_test
    \\ base + &15, read ids
    JMP i8271_read_ids
    \\ base + &18, write track
    JMP entry_write_track
    \\ base + &1B, reset
    JMP i8271_reset

.entry_load
    JSR i8271_reset
    JSR i8271_spin_up
    JSR i8271_wait_ready
    RTS

.i8271_spin_up
    LDA #&23
    LDX #&48
    JSR i8271_wsr
    RTS

.i8271_wsr
    STA &80
    STX &81
    LDA #&7A
    JSR i8271_cmd
    LDA &80
    JSR i8271_param
    LDA &81
    JSR i8271_param
    JSR i8271_wait_cmd
    RTS

.i8271_cmd
    STA &FE80
  .i8271_cmd_loop
    LDA &FE80
    AND #&40
    BNE i8271_cmd_loop
    RTS

.i8271_param
    STA &FE81
  .i8271_param_loop
    LDA &FE80
    AND #&20
    BNE i8271_param_loop
    RTS

.i8271_wait_cmd
    LDA &FE80
    AND #&80
    BNE i8271_wait_cmd
    LDX &FE81
    RTS

.i8271_get_status
    LDA #&6C
    JSR i8271_cmd
    JSR i8271_wait_cmd
    RTS

.i8271_wait_ready
    JSR i8271_get_status
    TXA
    AND #&04
    BEQ i8271_wait_ready
    RTS

.i8271_reset
    LDA #1
    STA &FE82
    NOP:NOP:NOP:NOP:NOP:NOP:NOP:NOP:NOP:NOP
    LDA #0
    STA &FE82

    \\ Select *TAPE.
    LDA #&8C
    LDX #0
    LDY #0
    JSR &FFF4

    \\ NMI vector to RTI.
    LDA #&40
    STA &0D00

    \\ Reset clobbers the no DMA setting. Put it back.
    LDA #&17
    LDX #&C1
    JSR i8271_wsr
    RTS

.i8271_seek
    STA &80
    LDA #&69
    JSR i8271_cmd
    LDA &80
    JSR i8271_param
    JSR i8271_wait_cmd
    RTS

.i8271_format
    STA &80
    STX &81
    JSR nmi_write_setup
    LDA #&63
    JSR i8271_cmd
    LDA &80
    JSR i8271_param
    \\ GAP3
    LDA #21
    JSR i8271_param
    LDA &81
    JSR i8271_param
    \\ GAP5
    LDA #0
    JSR i8271_param
    \\ GAP1
    LDA #16
    JSR i8271_param
    JSR i8271_wait_cmd
    RTS

.i8271_read
    STA &80
    STX &81
    STY &82
    JSR nmi_read_setup
    LDA #&53
    JSR i8271_cmd
    LDA &80
    JSR i8271_param
    LDA &81
    JSR i8271_param
    LDA &82
    JSR i8271_param
    JSR i8271_wait_cmd
    RTS

.i8271_wait_index
  .i8271_wait_index_0
    JSR i8271_get_status
    TXA
    AND #&10
    BNE i8271_wait_index_0
  .i8271_wait_index_1
    JSR i8271_get_status
    TXA
    AND #&10
    BEQ i8271_wait_index_1
    RTS

.wait_256_iters
    LDX #0
  .wait_256_iters_loop
    DEX
    BNE wait_256_iters_loop
    RTS

.entry_read0
    STA &80
    STX &81
    STY &82
    \\ Kick off the read at the start of the track.
    JSR i8271_wait_index
    JSR nmi_read_setup
    LDA #&53
    JSR i8271_cmd
    LDA &80
    JSR i8271_param
    LDA &81
    JSR i8271_param
    LDA &82
    JSR i8271_param
    \\ Read command started. Need to wait a bit to avoid trashing registers
    \\ before the 8271 commits to them.
    JSR wait_256_iters
    \\ Change the track register by partially starting another read (provide
    \\ only the first parameter).
    LDA #&53
    JSR i8271_cmd
    LDA #0
    JSR i8271_param
    \\ Should still be ok to wait for busy to lower on this mutant command.
    JSR i8271_wait_cmd
    RTS

.i8271_set_track_register
    TAX
    LDA #&12
    JSR i8271_wsr
    RTS

.entry_write_fm_test
    STA &80
    STX &81
    STY &82
    \\ Patch first jump state.
    LDA #LO(nmi_write_fm_test_wait_1)
    STA nmi_write_fm_test + 2
    LDA #HI(nmi_write_fm_test_wait_1)
    STA nmi_write_fm_test + 3
    \\ Wait count.
    LDA #4
    STA var_zp_count
    \\ Kick off the write at the start of the track.
    JSR i8271_wait_index
    JSR nmi_write_fm_test_setup
    LDA #&4B
    JSR i8271_cmd
    LDA &80
    JSR i8271_param
    LDA &81
    JSR i8271_param
    LDA &82
    JSR i8271_param
    \\ Write is now running.
    \\ All the fun happens in the NMI callbacks.
    JSR i8271_wait_cmd
    RTS

.entry_write_track
    STA &80
    \\ Set up write track buffer.
    LDA var_zp_param_track_buf
    STA nmi_write_track + 5
    LDA var_zp_param_track_buf + 1
    STA nmi_write_track + 6
    \\ Set up markers buffer.
    LDA var_zp_param_marker_buf
    STA var_zp_marker_buf
    LDA var_zp_param_marker_buf + 1
    STA var_zp_marker_buf + 1
    \\ Set up count-up for to re-start of track.
    LDA &74
    CLC
    ADC #(16 + 6 + 7 + 11 + 6 + 1)
    STA var_zp_lead_in_length
    LDA &75
    ADC #0
    STA var_zp_lead_in_length + 1
    \\ Set up count-up for the full track write.
    LDA &74
    STA var_zp_track_length
    LDA &75
    STA var_zp_track_length + 1
    \\ Set up first state for the actual track write.
    JSR nmi_write_track_setup_wait

    \\ NMI vector to JMP nmi_write_track_lead_in
    LDA #&40
    STA &0D00
    LDA #LO(nmi_write_track_lead_in)
    STA &0D01
    LDA #HI(nmi_write_track_lead_in)
    STA &0D02
    LDA #&4C
    STA &0D00

    \\ Kick off the write at the start of the track.
    JSR i8271_wait_index
    LDA #&4B
    JSR i8271_cmd
    LDA &80
    JSR i8271_param
    LDA #&DB
    JSR i8271_param
    \\ 1 sector, 8192 bytes.
    LDA #&C1
    JSR i8271_param
    \\ Write is now running.
    \\ All the fun happens in the NMI callbacks.
    JSR i8271_wait_cmd
    RTS

.i8271_read_ids
    STA &80
    STX &81
    JSR nmi_read_setup
    LDA #&5B
    JSR i8271_cmd
    LDA &80
    JSR i8271_param
    LDA #0
    JSR i8271_param
    LDA &81
    JSR i8271_param
    JSR i8271_wait_cmd
    RTS

.nmi_write_setup
    \\ Patch nmi_write with buffer address.
    LDA var_zp_param_track_buf
    STA nmi_write + 2
    LDA var_zp_param_track_buf + 1
    STA nmi_write + 3
    \\ NMI vector to JMP nmi_write.
    LDA #&40
    STA &0D00
    LDA #LO(nmi_write)
    STA &0D01
    LDA #HI(nmi_write)
    STA &0D02
    LDA #&4C
    STA &0D00
    RTS

.nmi_read_setup
    \\ Patch nmi_read with buffer address.
    LDA var_zp_param_track_buf
    STA nmi_read + 5
    LDA var_zp_param_track_buf + 1
    STA nmi_read + 6
    \\ NMI vector to JMP nmi_read.
    LDA #&40
    STA &0D00
    LDA #LO(nmi_read)
    STA &0D01
    LDA #HI(nmi_read)
    STA &0D02
    LDA #&4C
    STA &0D00
    RTS

.nmi_write_fm_test_setup
    \\ Patch nmi_write_fm_test with buffer address.
    LDA var_zp_param_track_buf
    STA nmi_write_fm_test + 5
    LDA var_zp_param_track_buf + 1
    STA nmi_write_fm_test + 6
    \\ NMI vector to JMP nmi_write_fm_test.
    LDA #&40
    STA &0D00
    LDA #LO(nmi_write_fm_test)
    STA &0D01
    LDA #HI(nmi_write_fm_test)
    STA &0D02
    LDA #&4C
    STA &0D00
    RTS

.nmi_write_track_setup_wait
    JSR nmi_write_track_state_specify_reload_1
    JSR nmi_write_track_state_specify_reload_2
    JSR nmi_write_track_state_specify_reload_3
    RTS

.nmi_write
    PHA
    LDA &FFFF
    STA &FE84
    INC nmi_write + 2
    BNE nmi_write_done
    INC nmi_write + 3
  .nmi_write_done
    PLA
    RTI

.nmi_read
    PHA
    LDA &FE84
    STA &FFFF
    INC nmi_read + 5
    BNE nmi_read_done
    INC nmi_read + 6
  .nmi_read_done
    PLA
    RTI

.nmi_write_fm_test
    PHA
    JSR &FFFF
    LDA &FFFF
    STA &FE84
    INC nmi_write_fm_test + 5
    BNE nmi_write_fm_test_done
    INC nmi_write_fm_test + 6
  .nmi_write_fm_test_done
    PLA
    RTI

.nmi_write_track_lead_in
    PHA
    LDA #&FF
    STA &FE84
    INC var_zp_lead_in_length
    BNE nmi_write_track_lead_in_done
    INC var_zp_lead_in_length + 1
    BNE nmi_write_track_lead_in_done
    \\ Should be hitting start of track, so start writing actual bytes.
    LDA #LO(nmi_write_track)
    STA &0D01
    LDA #HI(nmi_write_track)
    STA &0D02
  .nmi_write_track_lead_in_done
    PLA
    RTI

.nmi_write_track
    PHA
    JSR &FFFF
    LDA &FFFF
    STA &FE84
    INC nmi_write_track + 5
    BNE nmi_write_track_count
    INC nmi_write_track + 6
  .nmi_write_track_count
    INC var_zp_track_length
    BNE nmi_write_track_rti
    INC var_zp_track_length + 1
    BNE nmi_write_track_rti
    JSR i8271_reset
  .nmi_write_track_rti
    PLA
    RTI

.nmi_write_fm_test_wait_1
    DEC var_zp_count
    BEQ nmi_write_fm_test_wait_1_done
    RTS
  .nmi_write_fm_test_wait_1_done
    LDA #LO(nmi_write_fm_test_specify_cmd)
    STA nmi_write_fm_test + 2
    LDA #HI(nmi_write_fm_test_specify_cmd)
    STA nmi_write_fm_test + 3
    RTS

.nmi_write_fm_test_specify_cmd
    LDA #&75
    STA &FE80
    LDA #LO(nmi_write_fm_test_specify_post_cmd)
    STA nmi_write_fm_test + 2
    LDA #HI(nmi_write_fm_test_specify_post_cmd)
    STA nmi_write_fm_test + 3
    RTS

.nmi_write_fm_test_specify_post_cmd
    LDA #LO(nmi_write_fm_test_specify_target)
    STA nmi_write_fm_test + 2
    LDA #HI(nmi_write_fm_test_specify_target)
    STA nmi_write_fm_test + 3
    RTS

.nmi_write_fm_test_specify_target
    LDA #&24
    STA &FE81
    LDA #LO(nmi_write_fm_test_wait_2)
    STA nmi_write_fm_test + 2
    LDA #HI(nmi_write_fm_test_wait_2)
    STA nmi_write_fm_test + 3
    LDA #16
    STA var_zp_count
    RTS

.nmi_write_fm_test_wait_2
    DEC var_zp_count
    BEQ nmi_write_fm_test_wait_2_done
    RTS
  .nmi_write_fm_test_wait_2_done
    LDA #LO(nmi_write_fm_test_specify_clocks)
    STA nmi_write_fm_test + 2
    LDA #HI(nmi_write_fm_test_specify_clocks)
    STA nmi_write_fm_test + 3
    RTS

.nmi_write_fm_test_specify_clocks
    LDA #&C7
    STA &FE81
    LDA #LO(nmi_write_fm_test_idle)
    STA nmi_write_fm_test + 2
    LDA #HI(nmi_write_fm_test_idle)
    STA nmi_write_fm_test + 3
    RTS

.nmi_write_fm_test_idle
    RTS

.nmi_write_track_state_wait
    INC var_zp_marker_count
    BNE nmi_write_track_state_wait_rts
    INC var_zp_marker_count + 1
    BNE nmi_write_track_state_wait_rts
    LDA #LO(nmi_write_track_state_specify_cmd)
    STA nmi_write_track + 2
    LDA #HI(nmi_write_track_state_specify_cmd)
    STA nmi_write_track + 3
  .nmi_write_track_state_wait_rts
    RTS

.nmi_write_track_state_specify_cmd
    LDA #&75
    STA &FE80
    LDA #LO(nmi_write_track_state_specify_post_cmd_wait)
    STA nmi_write_track + 2
    LDA #HI(nmi_write_track_state_specify_post_cmd_wait)
    STA nmi_write_track + 3
    RTS

.nmi_write_track_state_specify_post_cmd_wait
    LDA #LO(nmi_write_track_state_specify_target)
    STA nmi_write_track + 2
    LDA #HI(nmi_write_track_state_specify_target)
    STA nmi_write_track + 3
    RTS

.nmi_write_track_state_specify_target
    LDA #&24
    STA &FE81
    LDA #LO(nmi_write_track_state_specify_post_target_wait)
    STA nmi_write_track + 2
    LDA #HI(nmi_write_track_state_specify_post_target_wait)
    STA nmi_write_track + 3
    LDA #8
    STA var_zp_count
    RTS

.nmi_write_track_state_specify_post_target_wait
    DEC var_zp_count
    BNE nmi_write_track_state_specify_post_target_wait_rts
    LDA #LO(nmi_write_track_state_specify_marker)
    STA nmi_write_track + 2
    LDA #HI(nmi_write_track_state_specify_marker)
    STA nmi_write_track + 3
  .nmi_write_track_state_specify_post_target_wait_rts
    RTS

.nmi_write_track_state_specify_marker
    LDA var_zp_marker
    STA &FE81
    LDA #LO(nmi_write_track_state_specify_reload_1)
    STA nmi_write_track + 2
    LDA #HI(nmi_write_track_state_specify_reload_1)
    STA nmi_write_track + 3
    RTS

.nmi_write_track_state_specify_reload_1
    STY &83
    LDY #0
    LDA (var_zp_marker_buf),Y
    STA var_zp_marker_count
    INC var_zp_marker_buf
    LDY &83
    LDA #LO(nmi_write_track_state_specify_reload_2)
    STA nmi_write_track + 2
    LDA #HI(nmi_write_track_state_specify_reload_2)
    STA nmi_write_track + 3
    RTS

.nmi_write_track_state_specify_reload_2
    STY &83
    LDY #0
    LDA (var_zp_marker_buf),Y
    STA var_zp_marker_count + 1
    INC var_zp_marker_buf
    LDY &83
    LDA #LO(nmi_write_track_state_specify_reload_3)
    STA nmi_write_track + 2
    LDA #HI(nmi_write_track_state_specify_reload_3)
    STA nmi_write_track + 3
    RTS

.nmi_write_track_state_specify_reload_3
    STY &83
    LDY #0
    LDA (var_zp_marker_buf),Y
    STA var_zp_marker
    INC var_zp_marker_buf
    LDY &83
    LDA #LO(nmi_write_track_state_wait)
    STA nmi_write_track + 2
    LDA #HI(nmi_write_track_state_wait)
    STA nmi_write_track + 3
    RTS

.i8271_end

SAVE "IASM", i8271_begin, i8271_end
PUTBASIC "t0.bas", "T0"
PUTBASIC "latency.bas", "LATENCY"
PUTBASIC "wfm.bas", "WFM"
PUTBASIC "wtrack.bas", "WTRACK"
