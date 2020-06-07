\\ discbeast.asm
\\ It works with discs. It's a bit of a beast.

SCRATCH = &7000
BASE = &7100
ZP = &70

ABI_SETUP = (BASE + 0)
ABI_REINIT = (BASE + 3)
ABI_LOAD = (BASE + 6)
ABI_SEEK = (BASE + 9)
ABI_READ_TRACK = (BASE + 12)
ABI_READ_IDS = (BASE + 15)
ABI_READ_SECTORS = (BASE + 18)
ABI_TIME_DRIVE = (BASE + 21)

DETECTED_NOTHING = 0
DETECTED_INTEL = 1
DETECTED_WD = 2

NMI = &0D00
OSBYTE = &FFF4
IRQ1V = &0204

INTEL_CMD_DRIVE0 = &40
INTEL_CMD_READ_SECTORS_WITH_DELETED = &17
INTEL_CMD_READ_IDS = &1B
INTEL_CMD_SEEK = &29
INTEL_CMD_READ_STATUS = &2C
INTEL_CMD_SPECIFY = &35
INTEL_CMD_SET_PARAM = &3A
INTEL_PARAM_STEP_RATE = &0D
INTEL_PARAM_SETTLE_TIME = &0E
INTEL_PARAM_SPINDOWN_LOADTIME = &0F
INTEL_PARAM_BAD_TRACK_1_DRIVE_0 = &10
INTEL_PARAM_BAD_TRACK_2_DRIVE_0 = &11
INTEL_PARAM_TRACK_DRIVE_0 = &12
INTEL_PARAM_BAD_TRACK_1_DRIVE_1 = &18
INTEL_PARAM_BAD_TRACK_2_DRIVE_1 = &19
INTEL_PARAM_TRACK_DRIVE_1 = &1A
INTEL_PARAM_DRVOUT = &23
INTEL_DRVOUT_SELECT0 = &40
INTEL_DRVOUT_LOAD_HEAD = &08

WD_CMD_RESTORE = &00
WD_CMD_SEEK = &10
WD_CMD_READ_SECTOR_SETTLE = &84
WD_CMD_READ_ADDRESS = &C0
WD_CMD_READ_TRACK_SETTLE = &E4

WD_STATUS_BIT_NOT_FOUND = &10

ORG ZP
GUARD (ZP + 32)

\\ 0
.var_zp_ABI_buf_1 SKIP 2
\\ 2
.var_zp_ABI_buf_2 SKIP 2
\\ 4
.var_zp_ABI_drive_speed SKIP 2
\\ 6
.var_zp_ABI_start SKIP 2
\\ 8
.var_zp_ABI_stop SKIP 2
.var_zp_wd_base SKIP 2
.var_zp_wd_drvctrl SKIP 2
.var_zp_drive SKIP 1
.var_zp_side SKIP 1
.var_zp_drive_side_bits SKIP 1
.var_zp_drive_bits SKIP 1
.var_zp_track SKIP 1
.var_zp_temp SKIP 1
.var_zp_param_1 SKIP 1
.var_zp_param_2 SKIP 1
.var_zp_param_3 SKIP 1
.var_zp_timer SKIP 2
.var_zp_system_VIA_IER SKIP 1
.var_zp_IRQ1V SKIP 2
.var_zp_byte_counter_reload SKIP 1

ORG BASE
GUARD (BASE + 2048)

.discbeast_begin

    \\ base + 0, setup
    JMP entry_setup
    \\ base + 3, reinit
    JMP entry_reinit
    \\ base + 6, load
    JMP entry_not_set
    \\ base + 9, seek
    JMP entry_not_set
    \\ base + 12, read track
    JMP entry_not_set
    \\ base + 15, read ids
    JMP entry_not_set
    \\ base + 18, read sectors
    JMP entry_not_set
    \\ base + 21, time drive
    JMP entry_not_set

.entry_not_set
    BRK

.entry_setup
    TAX
    AND #1
    STA var_zp_drive
    TXA
    AND #2
    LSR A
    STA var_zp_side

    LDA #0
    STA var_zp_track
    STA var_zp_ABI_drive_speed
    STA var_zp_ABI_drive_speed + 1
    STA var_zp_ABI_start
    STA var_zp_ABI_start + 1
    STA var_zp_ABI_stop
    STA var_zp_ABI_stop + 1

    \\ Try and make DFS safe.
    JSR disable_dfs

    \\ Set up timing.
    JSR timer_stop

    \\ Set up default buffer to &C000.
    LDA #0
    STA var_zp_ABI_buf_1
    LDA #&C0
    STA var_zp_ABI_buf_1 + 1

    \\ Detect 8271 vs. 1770 on model B.
    \\ On i8271, &FE84 - &FE87 all map to the same data register.
    \\ On wd1770, &FE85 is the track register and &FE86 the sector register.
    LDA #42
    STA &FE85
    LDA #43
    STA &FE86

    JSR wd_delay

    LDA &FE85
    CMP #43
    BEQ detected_intel
    CMP #42
    BEQ detected_wd_fe8x

    \\ Detect 1770 on Master.
    LDA #42
    STA &FE29

    JSR wd_delay

    LDA &FE29
    CMP #42
    BEQ detected_wd_fe2x

    LDA #DETECTED_NOTHING
    RTS

.detected_intel
    \\ Set up vectors.
    LDA #LO(intel_load)
    STA ABI_LOAD + 1
    LDA #HI(intel_load)
    STA ABI_LOAD + 2
    LDA #LO(intel_seek)
    STA ABI_SEEK + 1
    LDA #HI(intel_seek)
    STA ABI_SEEK + 2
    LDA #LO(intel_read_ids)
    STA ABI_READ_IDS + 1
    LDA #HI(intel_read_ids)
    STA ABI_READ_IDS + 2
    LDA #LO(intel_read_sectors)
    STA ABI_READ_SECTORS + 1
    LDA #HI(intel_read_sectors)
    STA ABI_READ_SECTORS + 2
    LDA #LO(intel_time_drive)
    STA ABI_TIME_DRIVE + 1
    LDA #HI(intel_time_drive)
    STA ABI_TIME_DRIVE + 2

    \\ Calculate values for drive out parameter and command select bits.
    LDA var_zp_drive
    CLC
    ADC #1
    ROR A
    ROR A
    ROR A
    STA var_zp_drive_bits
    LDA var_zp_side
    ASL A
    ASL A
    ASL A
    ASL A
    ASL A
    ORA var_zp_drive_bits
    ORA #INTEL_DRVOUT_LOAD_HEAD
    STA var_zp_drive_side_bits

    LDA #DETECTED_INTEL
    STA var_zp_param_1
    JMP detected_common

.detected_wd_fe8x
    LDA #&84
    STA var_zp_wd_base
    LDA #&80
    STA var_zp_wd_drvctrl
    LDA #0
    LDX var_zp_side
    BEQ detected_wd_fe8x_not_side_1
    LDA #&04
  .detected_wd_fe8x_not_side_1
    \\ No reset, single density.
    ORA #&28
    STA var_zp_drive_side_bits
    JMP detected_wd_common

.detected_wd_fe2x
    LDA #&28
    STA var_zp_wd_base
    LDA #&24
    STA var_zp_wd_drvctrl
    LDA #0
    LDX var_zp_side
    BEQ detected_wd_fe2x_not_side_1
    LDA #&10
  .detected_wd_fe2x_not_side_1
    \\ Single density, no reset.
    ORA #&24
    STA var_zp_drive_side_bits
    JMP detected_wd_common

.detected_wd_common
    LDA #&FE
    STA var_zp_wd_base + 1
    STA var_zp_wd_drvctrl + 1
    \\ Patch read loop, self modifying.
    LDA var_zp_wd_base
    STA wd_read_loop_patch_status_register + 1
    CLC
    ADC #3
    STA wd_read_loop_patch_data_register + 1

    \\ Set up vectors.
    LDA #LO(wd_load)
    STA ABI_LOAD + 1
    LDA #HI(wd_load)
    STA ABI_LOAD + 2
    LDA #LO(wd_seek)
    STA ABI_SEEK + 1
    LDA #HI(wd_seek)
    STA ABI_SEEK + 2
    LDA #LO(wd_read_track)
    STA ABI_READ_TRACK + 1
    LDA #HI(wd_read_track)
    STA ABI_READ_TRACK + 2
    LDA #LO(wd_read_ids)
    STA ABI_READ_IDS + 1
    LDA #HI(wd_read_ids)
    STA ABI_READ_IDS + 2
    LDA #LO(wd_read_sectors)
    STA ABI_READ_SECTORS + 1
    LDA #HI(wd_read_sectors)
    STA ABI_READ_SECTORS + 2
    LDA #LO(wd_time_drive)
    STA ABI_TIME_DRIVE + 1
    LDA #HI(wd_time_drive)
    STA ABI_TIME_DRIVE + 2

    LDA #DETECTED_WD
    STA var_zp_param_1
    JMP detected_common

.detected_common
    \\ Select drive, head, controller parameters, and spin-up if needed.
    JSR ABI_LOAD

    \\ Seek to 0.
    LDA #0
    JSR ABI_SEEK

    \\ Time the drive.
    JSR ABI_TIME_DRIVE

    LDA var_zp_param_1
    RTS

.disable_dfs
    \\ *FX 140,0, aka. *TAPE
    LDA #&8C
    LDX #0
    LDY #0
    JSR OSBYTE

    \\ Install null NMI handler.
    LDA #&40
    STA NMI
    RTS

.entry_reinit
    JSR disable_dfs
    JSR timer_stop
    JSR ABI_LOAD
    RTS

.intel_load
    \\ Disable automatic spindown. On my machine, the 8271 is super picky about
    \\ starting up again after it spins down.
    LDA #INTEL_PARAM_SPINDOWN_LOADTIME
    LDX #&F8
    JSR intel_set_param
    \\ Also set seek time to 12ms, twice as fast as standard but still slow.
    LDA #INTEL_PARAM_STEP_RATE
    LDX #6
    JSR intel_set_param
    \\ Settle time to 20ms.
    LDA #INTEL_PARAM_SETTLE_TIME
    LDX #10
    JSR intel_set_param

    \\ Reset bad track parameters.
    LDA #INTEL_PARAM_BAD_TRACK_1_DRIVE_0
    LDX #&FF
    JSR intel_set_param
    LDA #INTEL_PARAM_BAD_TRACK_2_DRIVE_0
    LDX #&FF
    JSR intel_set_param
    LDA #INTEL_PARAM_BAD_TRACK_1_DRIVE_1
    LDX #&FF
    JSR intel_set_param
    LDA #INTEL_PARAM_BAD_TRACK_2_DRIVE_1
    LDX #&FF
    JSR intel_set_param

    \\ Spin up and load head.
    JSR intel_set_drvout

    RTS

.intel_set_param
    \\ A=param, X=value.
    TAY
    LDA #INTEL_CMD_SET_PARAM
    JSR intel_do_cmd
    TYA
    JSR intel_do_param
    TXA
    JSR intel_do_param
    JSR intel_wait_idle
    RTS

.intel_set_drvout
    LDA #INTEL_PARAM_DRVOUT
    LDX var_zp_drive_side_bits
    JSR intel_set_param
    RTS

.intel_set_track
    LDA #INTEL_PARAM_TRACK_DRIVE_0
    LDX var_zp_drive
    BEQ intel_set_track_not_drive_1
    LDA #INTEL_PARAM_TRACK_DRIVE_1
  .intel_set_track_not_drive_1
    LDX var_zp_param_1
    JSR intel_set_param
    RTS

.intel_unset_track
    LDA #INTEL_PARAM_TRACK_DRIVE_0
    LDX var_zp_drive
    BEQ intel_unset_track_not_drive_1
    LDA #INTEL_PARAM_TRACK_DRIVE_1
  .intel_unset_track_not_drive_1
    LDX var_zp_track
    JSR intel_set_param
    RTS

.intel_seek
    STA var_zp_track

    JSR intel_wait_ready

    LDA #INTEL_CMD_SEEK
    JSR intel_do_cmd
    LDA var_zp_track
    JSR intel_do_param

    JSR intel_wait_idle
    JSR intel_set_result
    RTS

.intel_read_ids
    JSR timer_enter

    JSR intel_wait_ready

    JSR intel_wait_no_index_pulse
    JSR intel_wait_index_pulse

    JSR timer_start

    \\ 4 bytes per ID on the 8271.
    LDA #&FC
    STA var_zp_byte_counter_reload

    LDA #INTEL_CMD_READ_IDS
    JSR intel_do_cmd
    \\ Track.
    LDA var_zp_track
    JSR intel_do_param
    \\ Always zero.
    LDA #0
    JSR intel_do_param
    \\ Number, 0 is max == 32.
    LDA #0
    JSR intel_do_param

    JSR intel_read_loop

    JSR timer_stop

    \\ We started the timer on the index pulse, and the Intel read ids command
    \\ will start on the _next_ index pulse so to get correct timings we need
    \\ to subtract one revolutions worth of timing.
    \\ Back up to buffer start.
    LDA var_zp_ABI_buf_2
    SEC
    SBC #64
    STA var_zp_ABI_buf_2
    LDA var_zp_ABI_buf_2 + 1
    SBC #0
    STA var_zp_ABI_buf_2 + 1
    \\ Iterate the 32 entries and subtract.
    LDX #32
    LDY #0
  .intel_read_ids_subtract_loop
    LDA (var_zp_ABI_buf_2),Y
    SEC
    SBC var_zp_ABI_drive_speed
    STA (var_zp_ABI_buf_2),Y
    INY
    LDA (var_zp_ABI_buf_2),Y
    SBC var_zp_ABI_drive_speed + 1
    STA (var_zp_ABI_buf_2),Y
    INY

    DEX
    BNE intel_read_ids_subtract_loop

    \\ Advance buffer back to end.
    LDA var_zp_ABI_buf_2
    CLC
    ADC #64
    STA var_zp_ABI_buf_2
    LDA var_zp_ABI_buf_2 + 1
    ADC #0
    STA var_zp_ABI_buf_2 + 1

    JSR timer_exit

    JSR intel_set_result
    RTS

.intel_read_sectors
    STA var_zp_param_1
    STX var_zp_param_2
    STY var_zp_param_3

    JSR timer_enter

    JSR intel_wait_ready

    JSR intel_set_track

    JSR intel_wait_no_index_pulse
    JSR intel_wait_index_pulse
    JSR timer_start

    LDA #INTEL_CMD_READ_SECTORS_WITH_DELETED
    JSR intel_do_cmd
    \\ Track.
    LDA var_zp_param_1
    JSR intel_do_param
    \\ Start sector.
    LDA var_zp_param_2
    JSR intel_do_param
    \\ Number sectors.
    LDA var_zp_param_3
    JSR intel_do_param

    JSR intel_read_loop
    JSR intel_set_result
    STA var_zp_param_1
    STX var_zp_param_2

    JSR timer_stop

    JSR intel_unset_track

    JSR timer_exit

    LDA var_zp_param_1
    LDX var_zp_param_2
    RTS

.intel_time_drive
    JSR timer_enter

    JSR intel_wait_ready

    JSR intel_wait_no_index_pulse
    JSR intel_wait_index_pulse
    JSR timer_start
    JSR intel_wait_no_index_pulse
    JSR intel_wait_index_pulse
    JSR timer_stop

    JSR timer_exit

    LDA var_zp_timer
    STA var_zp_ABI_drive_speed
    LDA var_zp_timer + 1
    STA var_zp_ABI_drive_speed + 1
    RTS

.intel_wait_ready
    LDA #INTEL_CMD_READ_STATUS
    JSR intel_do_cmd
    JSR intel_wait_idle
    LDA &FE81
    LDX var_zp_drive
    BNE intel_wait_ready_drive_1
    \\ Check RDY0.
    AND #&04
    BEQ intel_wait_ready
    RTS
  .intel_wait_ready_drive_1
    \\ Check RDY0.
    AND #&40
    BEQ intel_wait_ready
    RTS

.intel_wait_no_index_pulse
    LDA #INTEL_CMD_READ_STATUS
    JSR intel_do_cmd
    JSR intel_wait_idle
    LDA &FE81
    AND #&10
    BNE intel_wait_no_index_pulse
    RTS

.intel_wait_index_pulse
    LDA #INTEL_CMD_READ_STATUS
    JSR intel_do_cmd
    JSR intel_wait_idle
    LDA &FE81
    AND #&10
    BEQ intel_wait_index_pulse
    RTS

.intel_do_cmd
    ORA var_zp_drive_bits
    STA &FE80
  .intel_do_cmd_loop
    LDA &FE80
    AND #&40
    BNE intel_do_cmd_loop
    RTS

.intel_do_param
    STA &FE81
  .intel_do_param_loop
    LDA &FE80
    AND #&20
    BNE intel_do_param_loop
    RTS

.intel_read_loop
    \\ X is the byte counter for how often we log a timing sample.
    LDX #&FF
    LDY #0
  .intel_read_loop_loop
    LDA &FE80
    ASL A
    AND #8
    BNE intel_read_loop_got_byte
    BCC intel_read_loop_done
    JMP intel_read_loop_loop
  .intel_read_loop_got_byte
    LDA &FE84
    STA (var_zp_ABI_buf_1),Y
    INX
    BNE intel_read_loop_no_byte_counter
    \\ Byte counter hit. Capture timing.
    SEI
    LDA var_zp_timer
    STA (var_zp_ABI_buf_2),Y
    LDA var_zp_timer + 1
    CLI
    INC var_zp_ABI_buf_2
    STA (var_zp_ABI_buf_2),Y
    INC var_zp_ABI_buf_2
    \\ Reset byte counter.
    LDX var_zp_byte_counter_reload
  .intel_read_loop_no_byte_counter
    INC var_zp_ABI_buf_1
    BNE intel_read_loop_loop
    INC var_zp_ABI_buf_1 + 1
    JMP intel_read_loop_loop
  .intel_read_loop_done
    RTS

.intel_wait_idle
    LDA &FE80
    AND #&80
    BNE intel_wait_idle
    RTS

.intel_set_result
    LDA &FE81
    TAX
    RTS

.wd_load
    \\ Set control register. Drive 0 vs. 1 select is common to both variants.
    LDA var_zp_drive
    \\ Drive 0 -> 1, drive 1 -> 2.
    CLC
    ADC #1
    \\ Add in reset, density and side.
    ORA var_zp_drive_side_bits
    LDY #0
    STA (var_zp_wd_drvctrl),Y

    RTS

.wd_seek
    STA var_zp_track
    CMP #0
    BEQ wd_seek_to_0
    \\ Desired track goes in data register.
    LDY #3
    STA (var_zp_wd_base),Y
    LDA #WD_CMD_SEEK
    JSR wd_do_command
    JSR wd_wait_idle
    JSR wd_set_result_type_1
    RTS

  .wd_seek_to_0
    \\ Command 0, no flags is retore to track 0 + spin up.
    LDA #WD_CMD_RESTORE
    JSR wd_do_command
    JSR wd_wait_idle
    JSR wd_set_result_type_1
    RTS

.wd_read_track
    JSR timer_enter

    \\ Read track, spin up, head settle.
    LDA #WD_CMD_READ_TRACK_SETTLE
    JSR wd_do_command

    JSR wd_read_loop

    JSR timer_exit

    JSR wd_set_result_type_2_3
    RTS

.wd_read_ids
    JSR timer_enter

    LDA #32
    STA var_zp_param_1
    \\ Use param_2 and param_3 to point to the scratch space.
    \\ We read 6-byte style 1770 IDs to the scratch space and the pick the
    \\ first 4 bytes of each.
    LDA var_zp_ABI_buf_1
    STA var_zp_param_2
    LDA var_zp_ABI_buf_1 + 1
    STA var_zp_param_3
    LDA #LO(SCRATCH)
    STA var_zp_ABI_buf_1
    LDA #HI(SCRATCH)
    STA var_zp_ABI_buf_1 + 1
    JSR clear_scratch

    JSR wd_do_spin_up_idle
    JSR wd_wait_no_index_pulse
    JSR wd_wait_index_pulse

    JSR timer_start

    \\ 6 bytes per ID on the 1770.
    LDA #&FA
    STA var_zp_byte_counter_reload

  .wd_read_ids_loop
    LDA #WD_CMD_READ_ADDRESS
    JSR wd_do_command

    JSR wd_read_loop

    \\ Bail loop if nothing found.
    JSR wd_set_result_type_2_3
    TXA
    AND #WD_STATUS_BIT_NOT_FOUND
    BNE wd_read_ids_loop_done

    DEC var_zp_param_1
    BNE wd_read_ids_loop

  .wd_read_ids_loop_done
    JSR timer_stop

    \\ Copy 6-byte style IDs to 4-byte style IDs.
    LDA var_zp_param_2
    STA var_zp_ABI_buf_1
    LDA var_zp_param_3
    STA var_zp_ABI_buf_1 + 1
    LDX #0
    LDY #0
  .wd_copy_ids_loop
    LDA SCRATCH,X
    STA (var_zp_ABI_buf_1),Y
    INX
    INY
    LDA SCRATCH,X
    STA (var_zp_ABI_buf_1),Y
    INX
    INY
    LDA SCRATCH,X
    STA (var_zp_ABI_buf_1),Y
    INX
    INY
    LDA SCRATCH,X
    STA (var_zp_ABI_buf_1),Y
    INX
    INY
    INX
    INX
    CPY #128
    BNE wd_copy_ids_loop

    LDA var_zp_ABI_buf_1
    CLC
    ADC #128
    STA var_zp_ABI_buf_1
    LDA var_zp_ABI_buf_1 + 1
    ADC #0
    STA var_zp_ABI_buf_1 + 1

    JSR timer_exit

    JSR wd_set_result_type_2_3
    RTS

.wd_read_sectors
    STA var_zp_param_1
    STX var_zp_param_2
    TYA
    AND #&1F
    STA var_zp_param_3

    JSR timer_enter

    JSR wd_do_spin_up_idle
    JSR wd_wait_no_index_pulse
    JSR wd_wait_index_pulse
    JSR timer_start

  .wd_read_sector_loop
    \\ Track register.
    LDY #1
    LDA var_zp_param_1
    STA (var_zp_wd_base),Y
    \\ Sector register.
    INY
    LDA var_zp_param_2
    STA (var_zp_wd_base),Y

    LDA #WD_CMD_READ_SECTOR_SETTLE
    JSR wd_do_command

    JSR wd_read_loop

    \\ Bail if error.
    JSR wd_set_result_type_2_3
    AND #&1F
    BNE wd_read_sectors_error_out

    \\ Loop across all sectors.
    INC var_zp_param_2
    DEC var_zp_param_3
    BNE wd_read_sector_loop

  .wd_read_sectors_error_out
    JSR timer_stop

    \\ Put back track register.
    LDA var_zp_track
    LDY #1
    STA (var_zp_wd_base),Y

    JSR timer_exit

    JSR wd_set_result_type_2_3
    RTS

.wd_time_drive
    JSR timer_enter

    JSR wd_do_spin_up_idle

    JSR wd_wait_no_index_pulse
    JSR wd_wait_index_pulse
    JSR timer_start
    JSR wd_wait_no_index_pulse
    JSR wd_wait_index_pulse
    JSR timer_stop

    JSR timer_exit

    LDA var_zp_timer
    STA var_zp_ABI_drive_speed
    LDA var_zp_timer + 1
    STA var_zp_ABI_drive_speed + 1
    RTS

.wd_do_command
    LDY #0
    STA (var_zp_wd_base),Y
    JSR wd_delay
    RTS

.wd_read_loop
    LDX #&FF
    LDY #0
  .wd_read_loop_loop
  .wd_read_loop_patch_status_register
    LDA &FEFF
    LSR A
    AND #1
    BNE wd_read_loop_got_byte
    BCC wd_read_loop_done
    JMP wd_read_loop_loop
  .wd_read_loop_got_byte
  .wd_read_loop_patch_data_register
    LDA &FEFF
    STA (var_zp_ABI_buf_1),Y
    INX
    BNE wd_read_loop_no_byte_counter
    \\ Byte counter hit. Capture timing.
    SEI
    LDA var_zp_timer
    STA (var_zp_ABI_buf_2),Y
    LDA var_zp_timer + 1
    CLI
    INC var_zp_ABI_buf_2
    STA (var_zp_ABI_buf_2),Y
    INC var_zp_ABI_buf_2
    \\ Reset byte counter.
    LDX var_zp_byte_counter_reload
  .wd_read_loop_no_byte_counter
    INC var_zp_ABI_buf_1
    BNE wd_read_loop_loop
    INC var_zp_ABI_buf_1 + 1
    JMP wd_read_loop_loop
  .wd_read_loop_done
    RTS

.wd_do_spin_up_idle
    JSR wd_wait_motor_off
    \\ Seek to current track.
    LDY #1
    LDA (var_zp_wd_base),Y
    LDY #3
    STA (var_zp_wd_base),Y
    LDA #WD_CMD_SEEK
    JSR wd_do_command
    JSR wd_wait_idle
    RTS

.wd_delay
    \\ Longest delay in the datasheet is 64us.
    \\ Delay for a little over 64us.
    \\ (Will be longer if the BNE crosses a page boundary!)
    LDX #25
  .wd_delay_loop
    DEX
    BNE wd_delay_loop
    RTS

.wd_wait_idle
    LDY #0
  .wd_wait_idle_loop
    LDA (var_zp_wd_base),Y
    AND #1
    BNE wd_wait_idle_loop
    RTS

.wd_wait_motor_off
    LDY #0
  .wd_wait_motor_off_loop
    LDA (var_zp_wd_base),Y
    AND #&80
    BNE wd_wait_motor_off_loop
    RTS

.wd_wait_no_index_pulse
    LDY #0
  .wd_wait_no_index_pulse_loop
    LDA (var_zp_wd_base),Y
    AND #&02
    BNE wd_wait_no_index_pulse_loop
    RTS

.wd_wait_index_pulse
    LDY #0
  .wd_wait_index_pulse_loop
    LDA (var_zp_wd_base),Y
    AND #&02
    BEQ wd_wait_index_pulse_loop
    RTS

.wd_set_result_type_1
    LDY #0
    LDA (var_zp_wd_base),Y
    TAX
    \\ Always success in 8271 terms for now.
    LDA #0
    RTS

.wd_set_result_type_2_3
    LDY #0
    STY var_zp_temp
    LDA (var_zp_wd_base),Y
    TAX
    \\ Convert to 8271 return code equivalent.
    AND #&10
    BNE wd_set_result_not_found
    TXA
    AND #&08
    BNE wd_set_result_crc_error
  .wd_set_result_add_deleted
    TXA
    AND #&20
    ORA var_zp_temp
    RTS

  .wd_set_result_crc_error
    LDA #&0E
    STA var_zp_temp
    JMP wd_set_result_add_deleted
  .wd_set_result_not_found
    TXA
    AND #&0E
    BNE wd_set_result_sector_crc_error
    LDA #&18
    STA var_zp_temp
    JMP wd_set_result_add_deleted
  .wd_set_result_sector_crc_error
    LDA #&0C
    STA var_zp_temp
    JMP wd_set_result_add_deleted

.timer_irq
    \\ Clear IRQ.
    LDA #&40
    STA &FE6D
    \\ Increment 16-bit timer.
    INC var_zp_timer
    BEQ timer_irq_do_inc_hi
    LDA &FC
    RTI
  .timer_irq_do_inc_hi
    INC var_zp_timer + 1
    LDA &FC
    RTI

.timer_enter
    SEI
    \\ System VIA IRQs off.
    LDA &FE4E
    STA var_zp_system_VIA_IER
    LDA #&7F
    STA &FE4E
    \\ Replace IRQ1V
    LDA IRQ1V
    STA var_zp_IRQ1V
    LDA IRQ1V + 1
    STA var_zp_IRQ1V + 1
    LDA #LO(timer_irq)
    STA IRQ1V
    LDA #HI(timer_irq)
    STA IRQ1V + 1

    LDA #0
    STA var_zp_timer
    STA var_zp_timer + 1
    STA var_zp_byte_counter_reload

    CLI
    RTS

.timer_exit
    SEI
    \\ Restore system VIA IER.
    LDA var_zp_system_VIA_IER
    STA &FE4E
    \\ Restore IRQ1V.
    LDA var_zp_IRQ1V
    STA IRQ1V
    LDA var_zp_IRQ1V + 1
    STA IRQ1V + 1
    CLI
    RTS

.timer_start
    \\ Start 64 us timer.
    LDA #0
    STA &FE65
    \\ Continuous T1.
    LDA #&40
    STA &FE6B
    \\ T1 IRQ active.
    LDA #(&80 + &40)
    STA &FE6E
    LDA var_zp_ABI_start
    ORA var_zp_ABI_start + 1
    BNE timer_wait_after_start
    RTS
  .timer_wait_after_start
    LDX var_zp_ABI_start
    LDY var_zp_ABI_start + 1
  .timer_wait_after_start_loop
    CPX var_zp_timer
    BNE timer_wait_after_start_loop
    CPY var_zp_timer + 1
    BNE timer_wait_after_start_loop
    RTS

.timer_stop
    \\ Just disable the timer IRQ.
    LDA #&7F
    STA &FE6E
    \\ T1 counter to 0.
    LDA #0
    STA &FE64
    STA &FE65
    \\ One shot T1.
    STA &FE6B
    \\ Prepare T1 for quick 64us start.
    LDA #&3E
    STA &FE64
    \\ One shot will now have shot, clear IFR.
    LDA #&7F
    STA &FE4D
    RTS

.clear_scratch
    LDA #0
    LDX #0
  .clear_scratch_loop
    STA SCRATCH,X
    DEX
    BNE clear_scratch_loop
    RTS

.discbeast_end

SAVE "BSTASM", discbeast_begin, discbeast_end
PUTFILE "DUTLASM", "DUTLASM", &7A00
PUTTEXT "boot.txt", "!BOOT", 0
PUTBASIC "discbeast.bas", "DISCBST"
