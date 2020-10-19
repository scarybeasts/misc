\\ test.asm
\\ Trying to land some 8271 advanced tricks.

BASE = &2800
ZP = &70

ORG BASE

.i8271_begin

    \\ base + &00, setup
    JMP entry_setup
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
    \\ base + &12, writefm
    JMP entry_write_fm
    \\ base + &15, read ids
    JMP i8271_read_ids

.entry_setup
    \\ NMI vector to RTI.
    LDA #&40
    STA &0D00
    JSR i8271_spin_up
    JSR i8271_wait_ready
    LDA #0
    JSR i8271_seek
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

.entry_write_fm
    STA &80
    STX &81
    STY &82
    \\ Kick off the write at the start of the track.
    JSR i8271_wait_index
    JSR nmi_write_fm_setup
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
    LDA &70
    STA nmi_write + 2
    LDA &71
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
    LDA &70
    STA nmi_read + 5
    LDA &71
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

.nmi_write_fm_setup
    \\ Patch nmi_write_fm with buffer address.
    LDA &70
    STA nmi_write_fm + 5
    LDA &71
    STA nmi_write_fm + 6
    \\ Patch first jump state.
    LDA #LO(nmi_write_fm_wait_1)
    STA nmi_write_fm + 2
    LDA #HI(nmi_write_fm_wait_1)
    STA nmi_write_fm + 3
    \\ Wait count.
    LDA #4
    STA &72
    \\ NMI vector to JMP nmi_write_fm.
    LDA #&40
    STA &0D00
    LDA #LO(nmi_write_fm)
    STA &0D01
    LDA #HI(nmi_write_fm)
    STA &0D02
    LDA #&4C
    STA &0D00
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

.nmi_write_fm
    PHA
    JSR &FFFF
    LDA &FFFF
    STA &FE84
    INC nmi_write_fm + 5
    BNE nmi_write_fm_done
    INC nmi_write_fm + 6
  .nmi_write_fm_done
    PLA
    RTI

.nmi_write_fm_wait_1
    DEC &72
    BEQ nmi_write_fm_wait_1_done
    RTS
  .nmi_write_fm_wait_1_done
    LDA #LO(nmi_write_fm_specify_cmd)
    STA nmi_write_fm + 2
    LDA #HI(nmi_write_fm_specify_cmd)
    STA nmi_write_fm + 3
    RTS

.nmi_write_fm_specify_cmd
    LDA #&75
    STA &FE80
    LDA #LO(nmi_write_fm_specify_post_cmd)
    STA nmi_write_fm + 2
    LDA #HI(nmi_write_fm_specify_post_cmd)
    STA nmi_write_fm + 3
    RTS

.nmi_write_fm_specify_post_cmd
    LDA #LO(nmi_write_fm_specify_target)
    STA nmi_write_fm + 2
    LDA #HI(nmi_write_fm_specify_target)
    STA nmi_write_fm + 3
    RTS

.nmi_write_fm_specify_target
    LDA #&24
    STA &FE81
    LDA #LO(nmi_write_fm_wait_2)
    STA nmi_write_fm + 2
    LDA #HI(nmi_write_fm_wait_2)
    STA nmi_write_fm + 3
    LDA #16
    STA &72
    RTS

.nmi_write_fm_wait_2
    DEC &72
    BEQ nmi_write_fm_wait_2_done
    RTS
  .nmi_write_fm_wait_2_done
    LDA #LO(nmi_write_fm_specify_clocks)
    STA nmi_write_fm + 2
    LDA #HI(nmi_write_fm_specify_clocks)
    STA nmi_write_fm + 3
    RTS

.nmi_write_fm_specify_clocks
    LDA #&C7
    STA &FE81
    LDA #LO(nmi_write_fm_idle)
    STA nmi_write_fm + 2
    LDA #HI(nmi_write_fm_idle)
    STA nmi_write_fm + 3
    RTS

.nmi_write_fm_idle
    RTS

.i8271_end

SAVE "IASM", i8271_begin, i8271_end
PUTBASIC "t0.bas", "T0"
PUTBASIC "latency.bas", "LATENCY"
PUTBASIC "wfm.bas", "WFM"
