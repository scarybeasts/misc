\\ discbeast.asm
\\ It works with discs. It's a bit of a beast.

BASE = &4A00
ZP = &60

ABI_SETUP = (BASE + 0)
ABI_REINIT = (BASE + 3)
ABI_LOAD = (BASE + 6)
ABI_SEEK = (BASE + 9)
ABI_READ_TRACK = (BASE + 12)
ABI_READ_IDS = (BASE + 15)
ABI_READ_SECTORS = (BASE + 18)
ABI_TIME_DRIVE = (BASE + 21)
ABI_WRITE_SECTORS = (BASE + 24)
ABI_WRITE_TRACK = (BASE + 27)

DETECTED_NOTHING = 0
DETECTED_INTEL = 1
DETECTED_WD = 2

NMI = &0D00
OSBYTE = &FFF4
IRQ1V = &0204

INTEL_CMD_DRIVE0 = &40
INTEL_CMD_WRITE_SECTORS = &0B
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
INTEL_DRVOUT_WRITE_ENABLE = &01

WD_CMD_RESTORE = &00
WD_CMD_SEEK = &10
WD_CMD_READ_SECTOR_SETTLE = &84
WD_CMD_WRITE_SECTOR_SETTLE = &A4
WD_CMD_READ_ADDRESS = &C0
WD_CMD_READ_TRACK_SETTLE = &E4
WD_CMD_WRITE_TRACK_SETTLE = &F4

WD_STATUS_BIT_MOTOR_ON = &80
WD_STATUS_BIT_NOT_FOUND = &10
WD_STATUS_BIT_CRC_ERROR = &08
WD_STATUS_BIT_TYPE_II_III_LOST_BYTE = &04
WD_STATUS_BIT_TYPE_I_INDEX = &02
WD_STATUS_BIT_BUSY = &01

ORG ZP
GUARD (ZP + 48)

\\ 0
.var_zp_ABI_buf_1 SKIP 2
\\ 2
.var_zp_ABI_buf_2 SKIP 2
\\ 4
.var_zp_ABI_drive_speed SKIP 2
\\ 6
.var_zp_ABI_start SKIP 2
\\ 8
.var_zp_ABI_bail_bytes SKIP 2
\\ 10
.var_zp_ABI_bail_function SKIP 1
\\ 11
.var_zp_ABI_buf_3 SKIP 2
\\ 13
.var_zp_ABI_track SKIP 1
.var_zp_drive SKIP 1
.var_zp_side SKIP 1
.var_zp_drive_side_bits SKIP 1
.var_zp_drive_bits SKIP 1
.var_zp_temp SKIP 1
.var_zp_param_1 SKIP 1
.var_zp_param_2 SKIP 1
.var_zp_param_3 SKIP 1
.var_zp_param_4 SKIP 1
.var_zp_timer SKIP 2
.var_zp_system_VIA_IER SKIP 1
.var_zp_IRQ1V SKIP 2
.var_zp_byte_counter_reload SKIP 1
.var_zp_wd_base SKIP 2
.var_zp_wd_drvctrl SKIP 2
.var_zp_wd_dden_bit SKIP 1
.var_zp_wd_side_bit SKIP 1

ORG BASE
GUARD (BASE + &0800)

.discbeast_begin

    \\ base + 0, setup
    JMP entry_setup
    \\ base + 3, reinit
    JMP entry_reinit
    \\ base + 6, load
    JMP wd_load
    \\ base + 9, seek
    JMP wd_seek
    \\ base + 12, read track
    JMP wd_read_track
    \\ base + 15, read ids
    JMP wd_read_ids
    \\ base + 18, read sectors
    JMP wd_read_sectors
    \\ base + 21, time drive
    JMP wd_time_drive
    \\ base + 24, write sectors
    JMP wd_write_sectors
    \\ base + 27, write track
    JMP wd_write_track

.entry_setup
    PHA

    LDA #0
    TAX
    LDY #48
  .entry_setup_clear_loop
    STA ZP,X
    INX
    DEY
    BNE entry_setup_clear_loop

    PLA
    JSR store_drive_and_side

    \\ Try and make DFS safe.
    JSR disable_dfs

    \\ Set up timing.
    JSR timer_stop

    \\ Detect 8271 vs. 1770 on model B.
    \\ On i8271, &FE84 - &FE87 all map to the same data register.
    \\ On wd1770, &FE85 is the track register and &FE86 the sector register.
    LDX #42
    STX &FE85
    INX
    STX &FE86

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
    LDA #LO(intel_write_sectors)
    STA ABI_WRITE_SECTORS + 1
    LDA #HI(intel_write_sectors)
    STA ABI_WRITE_SECTORS + 2

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
    LDA #&08
    STA var_zp_wd_dden_bit
    LDA #&04
    STA var_zp_wd_side_bit
    \\ No reset.
    LDA #&20
    STA var_zp_drive_side_bits
    JMP detected_wd_common

.detected_wd_fe2x
    LDA #&28
    STA var_zp_wd_base
    LDA #&24
    STA var_zp_wd_drvctrl
    LDA #&20
    STA var_zp_wd_dden_bit
    LDA #&10
    STA var_zp_wd_side_bit
    \\ No reset.
    LDA #&04
    STA var_zp_drive_side_bits
    JMP detected_wd_common

.detected_wd_common
    LDA #&FE
    STA var_zp_wd_base + 1
    STA var_zp_wd_drvctrl + 1
    \\ Patch read / write loops, self modifying.
    LDA var_zp_wd_base
    STA wd_read_loop_patch_status_register + 1
    STA wd_write_loop_patch_status_register + 1
    STA wd_read_loop_fast_patch_status_register + 1
    STA wd_write_loop_fast_patch_status_register + 1
    CLC
    ADC #3
    STA wd_read_loop_patch_data_register + 1
    STA wd_write_loop_patch_data_register + 1
    STA wd_read_loop_fast_nmi_patch_data_register + 1
    STA wd_write_loop_fast_patch_data_register + 1

    \\ Vectors default to the wd versions so no need to write them.
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

.store_drive_and_side
    TAX
    AND #1
    STA var_zp_drive
    TXA
    AND #2
    LSR A
    STA var_zp_side
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
    JSR store_drive_and_side
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
    LDX var_zp_ABI_track
    JSR intel_set_param
    RTS

.intel_seek
    STA var_zp_ABI_track

    JSR intel_wait_ready

    LDA #INTEL_CMD_SEEK
    JSR intel_do_cmd
    LDA var_zp_ABI_track
    JSR intel_do_param

    JSR intel_wait_idle
    JSR intel_set_result
    RTS

.intel_read_ids
    JSR timer_enter

    \\ 4 bytes per ID on the 8271.
    LDA #&FC
    STA var_zp_byte_counter_reload

    JSR intel_wait_ready

    JSR intel_wait_index_and_start_timer

    LDA #INTEL_CMD_READ_IDS
    JSR intel_do_cmd
    \\ Track.
    LDA var_zp_ABI_track
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

    \\ Sample timing every 128 bytes.
    LDA #&80
    STA var_zp_byte_counter_reload

    JSR intel_wait_ready

    JSR intel_set_track

    JSR intel_wait_index_and_start_timer

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

    \\ Log final time.
    LDA var_zp_timer
    LDY #0
    STA (var_zp_ABI_buf_2),Y
    INC var_zp_ABI_buf_2
    LDA var_zp_timer + 1
    STA (var_zp_ABI_buf_2),Y
    INC var_zp_ABI_buf_2

    JSR intel_unset_track

    JSR timer_exit

    LDA var_zp_param_1
    LDX var_zp_param_2
    RTS

.intel_time_drive
    JSR timer_enter

    JSR intel_wait_ready

    JSR intel_wait_index_and_start_timer
    JSR intel_wait_no_index_pulse
    JSR intel_wait_index_pulse
    JSR timer_stop

    JSR timer_exit

    LDA var_zp_timer
    STA var_zp_ABI_drive_speed
    LDA var_zp_timer + 1
    STA var_zp_ABI_drive_speed + 1
    RTS

.intel_write_sectors
    STA var_zp_param_1
    STX var_zp_param_2
    STY var_zp_param_3

    JSR timer_enter

    JSR intel_wait_ready

    JSR intel_set_track

    JSR intel_wait_index_and_start_timer

    LDA #INTEL_CMD_WRITE_SECTORS
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

    JSR intel_write_loop
    JSR intel_set_result
    STA var_zp_param_1
    STX var_zp_param_2

    JSR timer_stop

    JSR intel_unset_track

    JSR timer_exit

    LDA var_zp_param_1
    LDX var_zp_param_2
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

.intel_wait_index_and_start_timer
    JSR intel_wait_no_index_pulse
    JSR intel_wait_index_pulse
    JSR timer_start
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

.intel_write_loop
    LDY #0
  .intel_write_loop_loop
    LDA &FE80
    ASL A
    AND #8
    BNE intel_write_loop_need_byte
    BCC intel_write_loop_done
    JMP intel_write_loop_loop
  .intel_write_loop_need_byte
    LDA (var_zp_ABI_buf_1),Y
    STA &FE84
    INC var_zp_ABI_bail_bytes
    BNE intel_write_loop_no_bail
    INC var_zp_ABI_bail_bytes + 1
    BNE intel_write_loop_no_bail
    \\ Bail mid-way through command.
    JMP intel_bail
  .intel_write_loop_no_bail
    INC var_zp_ABI_buf_1
    BNE intel_write_loop_loop
    INC var_zp_ABI_buf_1 + 1
    JMP intel_write_loop_loop
  .intel_write_loop_done
    RTS

.intel_bail
    LDA var_zp_ABI_bail_function
    \\ 0: stop writing bytes and wait for command to exit
    BEQ intel_wait_idle
    CMP #1
    \\ 1: reset controller
    BEQ intel_reset
    \\ 2: write weak bits for a bit
    JSR intel_reset
    LDA var_zp_drive_side_bits
    ORA #INTEL_DRVOUT_WRITE_ENABLE
    TAX
    LDA #INTEL_PARAM_DRVOUT
    JSR intel_set_param
    LDX #0
  .intel_bail_weak_bits_wait_loop
    DEX
    BNE intel_bail_weak_bits_wait_loop
    LDA #INTEL_PARAM_DRVOUT
    LDX var_zp_drive_side_bits
    JSR intel_set_param
    RTS

.intel_reset
    LDA #1
    STA &FE82
    LDX #20
  .intel_reset_wait_loop
    DEX
    BNE intel_reset_wait_loop
    STX &FE82
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
    \\ Make sure the motor spins down before potentially selecting a different
    \\ drive, otherwise spin-up on the new drive can be circumvented.
    JSR wd_reset

    \\ Set control register.
    \\ Clean out DDEN, SIDE, drive bits.
    LDA #3
    ORA var_zp_wd_dden_bit
    ORA var_zp_wd_side_bit
    EOR #&FF
    AND var_zp_drive_side_bits
    STA var_zp_drive_side_bits
    \\ And put in the new ones.
    \\ Drive 0 vs. 1 select is common to both variants.
    LDA var_zp_drive
    \\ Drive 0 -> 1, drive 1 -> 2.
    CLC
    ADC #1
    ORA var_zp_drive_side_bits
    LDX var_zp_side
    BEQ wd_load_no_upper_side
    ORA var_zp_wd_side_bit
  .wd_load_no_upper_side
    \\ DDEN is active low, so raise it for no DDEN (plain FM).
    ORA var_zp_wd_dden_bit

    STA var_zp_drive_side_bits
    LDY #0
    STA (var_zp_wd_drvctrl),Y

    \\ Restore track register -- there's only one for both drives.
    LDA var_zp_ABI_track
    INY
    STA (var_zp_wd_base),Y

    RTS

.wd_seek
    STA var_zp_ABI_track
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
    STA var_zp_param_1

    JSR timer_enter

    JSR wd_set_dden

    JSR wd_read_loop_fast_setup

    \\ Read track, spin up, head settle.
    LDA #WD_CMD_READ_TRACK_SETTLE
    JSR wd_do_command

    JSR wd_read_loop_fast

    \\ Put back control register.
    JSR wd_reset_dden

    JSR timer_exit

    JSR wd_set_result_type_2_3
    RTS

.wd_read_ids
    LDA #32
    STA var_zp_param_1
    \\ No errors yet.
    LDA #0
    STA var_zp_param_4
    \\ Use param_2 and param_3 to point to the scratch space.
    \\ We read 6-byte style 1770 IDs to the scratch space and the pick the
    \\ first 4 bytes of each.
    LDA var_zp_ABI_buf_1
    STA var_zp_param_2
    LDA var_zp_ABI_buf_1 + 1
    STA var_zp_param_3
    LDA var_zp_ABI_buf_3
    STA var_zp_ABI_buf_1
    LDA var_zp_ABI_buf_3 + 1
    STA var_zp_ABI_buf_1 + 1

    \\ Clear scratch page.
    LDA #0
    TAY
  .wd_read_ids_clear_scratch_loop
    STA (var_zp_ABI_buf_3),Y
    DEY
    BNE wd_read_ids_clear_scratch_loop

    JSR timer_enter

    \\ 6 bytes per ID on the 1770.
    LDA #&FA
    STA var_zp_byte_counter_reload

    JSR wd_do_spin_up_idle
    JSR wd_wait_index_and_start_timer

  .wd_read_ids_loop
    LDA #WD_CMD_READ_ADDRESS
    JSR wd_do_command

    JSR wd_read_loop

    \\ Delay a bit. This prevents ghost sector headers on some discs that
    \\ appear in the sync between header and data.
    LDY #8
  .wd_read_ids_loop_delay_loop
    JSR wd_delay
    DEY
    BNE wd_read_ids_loop_delay_loop

    \\ Bail loop if nothing found or data lost.
    \\ Also tag CRC error but continue.
    LDY #0
    LDA (var_zp_wd_base),Y
    TAX
    AND #(WD_STATUS_BIT_NOT_FOUND + WD_STATUS_BIT_TYPE_II_III_LOST_BYTE)
    BNE wd_read_ids_loop_done
    TXA
    AND #WD_STATUS_BIT_CRC_ERROR
    BEQ wd_read_ids_loop_no_crc_error
    LDA #1
    STA var_zp_param_4

  .wd_read_ids_loop_no_crc_error
    DEC var_zp_param_1
    BNE wd_read_ids_loop

  .wd_read_ids_loop_done
    JSR timer_stop

    \\ Copy 6-byte style IDs to 4-byte style IDs.
    LDA var_zp_param_2
    STA var_zp_ABI_buf_1
    LDA var_zp_param_3
    STA var_zp_ABI_buf_1 + 1
    CLC
    LDY #0
  .wd_copy_ids_loop
    LDA (var_zp_ABI_buf_3),Y
    STA (var_zp_ABI_buf_1),Y
    INY
    LDA (var_zp_ABI_buf_3),Y
    STA (var_zp_ABI_buf_1),Y
    INY
    LDA (var_zp_ABI_buf_3),Y
    STA (var_zp_ABI_buf_1),Y
    INY
    LDA (var_zp_ABI_buf_3),Y
    STA (var_zp_ABI_buf_1),Y
    INY
    LDA var_zp_ABI_buf_3
    ADC #2
    STA var_zp_ABI_buf_3
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

    LDY #0
    LDA (var_zp_wd_base),Y
    LDY var_zp_param_4
    BEQ wd_read_ids_no_crc_error
    ORA #WD_STATUS_BIT_CRC_ERROR
  .wd_read_ids_no_crc_error
    JSR wd_set_result_type_2_3_a_already_set
    RTS

.wd_read_sectors
    STA var_zp_param_1
    STX var_zp_param_2
    TYA
    AND #&1F
    STA var_zp_param_3

    JSR timer_enter

    \\ Sample timing every 128 bytes.
    LDA #&80
    STA var_zp_byte_counter_reload

    JSR wd_do_spin_up_idle
    JSR wd_wait_index_and_start_timer

    \\ Track register.
    LDY #1
    LDA var_zp_param_1
    STA (var_zp_wd_base),Y

  .wd_read_sector_loop
    \\ Sector register.
    LDY #2
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

    \\ Log final time.
    LDA var_zp_timer
    LDY #0
    STA (var_zp_ABI_buf_2),Y
    INC var_zp_ABI_buf_2
    LDA var_zp_timer + 1
    STA (var_zp_ABI_buf_2),Y
    INC var_zp_ABI_buf_2

    \\ Put back track register.
    LDA var_zp_ABI_track
    LDY #1
    STA (var_zp_wd_base),Y

    JSR timer_exit

    JSR wd_set_result_type_2_3
    RTS

.wd_time_drive
    JSR timer_enter

    JSR wd_do_spin_up_idle

    JSR wd_wait_index_and_start_timer
    JSR wd_wait_no_index_pulse
    JSR wd_wait_index_pulse
    JSR timer_stop

    JSR timer_exit

    LDA var_zp_timer
    STA var_zp_ABI_drive_speed
    LDA var_zp_timer + 1
    STA var_zp_ABI_drive_speed + 1
    RTS

.wd_write_sectors
    STA var_zp_param_1
    STX var_zp_param_2
    TYA
    AND #&1F
    STA var_zp_param_3

    JSR timer_enter

    JSR wd_do_spin_up_idle
    JSR wd_wait_index_and_start_timer

    \\ Track register.
    LDY #1
    LDA var_zp_param_1
    STA (var_zp_wd_base),Y

  .wd_write_sector_loop
    \\ Sector register.
    LDY #2
    LDA var_zp_param_2
    STA (var_zp_wd_base),Y

    LDA #WD_CMD_WRITE_SECTOR_SETTLE
    JSR wd_do_command

    JSR wd_write_loop

    \\ Bail if error.
    JSR wd_set_result_type_2_3
    AND #&1F
    BNE wd_write_sectors_error_out

    \\ Loop across all sectors.
    INC var_zp_param_2
    DEC var_zp_param_3
    BNE wd_write_sector_loop

  .wd_write_sectors_error_out
    JSR timer_stop

    \\ Put back track register.
    LDA var_zp_ABI_track
    LDY #1
    STA (var_zp_wd_base),Y

    JSR timer_exit

    JSR wd_set_result_type_2_3
    RTS

.wd_write_track
    STA var_zp_param_1

    JSR timer_enter

    JSR wd_set_dden

    \\ Write track, spin up, head settle.
    LDA #WD_CMD_WRITE_TRACK_SETTLE
    JSR wd_do_command

    LDA var_zp_param_1
    CMP #1
    BNE wd_write_track_fm
    \\ Use a faster variant, with no bail counter, for MFM.
    JSR wd_write_loop_fast
    JMP wd_write_track_post_write
  .wd_write_track_fm
    JSR wd_write_loop

  .wd_write_track_post_write
    \\ Put back control register.
    JSR wd_reset_dden

    JSR timer_exit

    JSR wd_set_result_type_2_3
    RTS

.wd_set_dden
    LDA var_zp_drive_side_bits
    LDX var_zp_param_1
    CPX #1
    BNE wd_write_track_not_dden
    EOR var_zp_wd_dden_bit
  .wd_write_track_not_dden
    LDY #0
    STA (var_zp_wd_drvctrl),Y
    RTS

.wd_reset_dden
    LDA var_zp_drive_side_bits
    LDY #0
    STA (var_zp_wd_drvctrl),Y
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

.wd_read_loop_fast_setup
    \\ Copy NMI code over.
    LDX #(wd_read_loop_fast_nmi_end - wd_read_loop_fast_nmi)
    LDY #0
  .wd_read_loop_setup_copy_loop
    LDA wd_read_loop_fast_nmi,Y
    STA NMI,Y
    INY
    DEX
    BNE wd_read_loop_setup_copy_loop
    \\ Patch in buffer pointer (minus one because we pre-increment).
    LDA var_zp_ABI_buf_1
    SEC
    SBC #1
    STA NMI + 12
    LDA var_zp_ABI_buf_1 + 1
    SBC #0
    STA NMI + 13
    RTS

.wd_read_loop_fast
  .wd_read_loop_fast_patch_status_register
    LDA &FEFF
    AND #1
    BNE wd_read_loop_fast

    \\ Nullify NMI handler again.
    LDA #&40
    STA NMI

    \\ Copy buffer pointer back.
    \\ The final INTRQ will have incremented our buffer pointer but we started
    \\ at -1, so it should be correct as-is.
    LDA NMI + 12
    STA var_zp_ABI_buf_1
    LDA NMI + 13
    STA var_zp_ABI_buf_1 + 1
    RTS

.wd_read_loop_fast_nmi
    \\ Pre-increment to avoid potential problems with recursive NMIs.
    \\ This comes at the cost of worse latency before we grab the data byte
    \\ (and lower NMI) by reading the data register.
    \\ The 1770 delivers NMI closer spaced than 64us in "read track" when it
    \\ gains sync part-way through a byte.
    INC NMI + 12
    BNE wd_read_loop_nmi_no_inc_hi
    INC NMI + 13
  .wd_read_loop_nmi_no_inc_hi
  .wd_read_loop_fast_nmi_patch_data_register
    LDX &FEFF
    STX &C000
    RTI
  .wd_read_loop_fast_nmi_end

.wd_write_loop
    LDY #0
  .wd_write_loop_load
    LDA (var_zp_ABI_buf_1),Y
    TAX
  .wd_write_loop_loop
  .wd_write_loop_patch_status_register
    LDA &FEFF
    LSR A
    AND #1
    BNE wd_write_loop_need_byte
    BCC wd_write_loop_done
    JMP wd_write_loop_loop
  .wd_write_loop_need_byte
  .wd_write_loop_patch_data_register
    STX &FEFF
    INC var_zp_ABI_bail_bytes
    BNE wd_write_loop_no_bail
    INC var_zp_ABI_bail_bytes + 1
    BNE wd_write_loop_no_bail
    \\ Bail mid-way through command.
    JMP wd_bail
  .wd_write_loop_no_bail
    INY
    BNE wd_write_loop_load
    INC var_zp_ABI_buf_1 + 1
    JMP wd_write_loop_load
  .wd_write_loop_done
    RTS

.wd_write_loop_fast
    LDY #0
  .wd_write_loop_fast_loop_load
    LDA (var_zp_ABI_buf_1),Y
    TAX
  .wd_write_loop_fast_loop
  .wd_write_loop_fast_patch_status_register
    LDA &FEFF
    LSR A
    AND #1
    BNE wd_write_loop_fast_need_byte
    BCC wd_write_loop_done
    JMP wd_write_loop_fast_loop
  .wd_write_loop_fast_need_byte
  .wd_write_loop_fast_patch_data_register
    STX &FEFF
    INY
    BNE wd_write_loop_fast_loop_load
    INC var_zp_ABI_buf_1 + 1
    JMP wd_write_loop_fast_loop_load

.wd_bail
    LDA var_zp_ABI_bail_function
    BEQ wd_wait_idle
    CMP #1
    BEQ wd_reset
    LDA var_zp_drive_side_bits
    EOR var_zp_wd_dden_bit
    LDY #0
    STA (var_zp_wd_drvctrl),Y
    LDX #0
  .wd_bail_dden_write_loop
    TXA
    LDY #3
    STA (var_zp_wd_base),Y
    INX
    LDY #0
    LDA (var_zp_wd_base),Y
    AND #1
    BNE wd_bail_dden_write_loop

    LDA var_zp_drive_side_bits
    LDY #0
    STA (var_zp_wd_drvctrl),Y
    RTS

.wd_reset
    LDA #0
    TAY
    STA (var_zp_wd_drvctrl),Y
    JSR wd_delay
    RTS

.wd_do_spin_up_idle
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
    AND #WD_STATUS_BIT_BUSY
    BNE wd_wait_idle_loop
    RTS

.wd_wait_index_and_start_timer
    JSR wd_wait_no_index_pulse
    JSR wd_wait_index_pulse
    JSR timer_start
    RTS

.wd_wait_no_index_pulse
    LDY #0
  .wd_wait_no_index_pulse_loop
    LDA (var_zp_wd_base),Y
    AND #WD_STATUS_BIT_TYPE_I_INDEX
    BNE wd_wait_no_index_pulse_loop
    RTS

.wd_wait_index_pulse
    LDY #0
  .wd_wait_index_pulse_loop
    LDA (var_zp_wd_base),Y
    AND #WD_STATUS_BIT_TYPE_I_INDEX
    BEQ wd_wait_index_pulse_loop
    RTS

.wd_set_result_type_1
    LDY #0
    LDA (var_zp_wd_base),Y
    TAX
    \\ Always success in 8271 terms for now.
    TYA
    RTS

.wd_set_result_type_2_3
    LDY #0
    LDA (var_zp_wd_base),Y
.wd_set_result_type_2_3_a_already_set
    LDY #0
    STY var_zp_temp
    TAX
    \\ Convert to 8271 return code equivalent.
    AND #WD_STATUS_BIT_NOT_FOUND
    BNE wd_set_result_not_found
    TXA
    AND #WD_STATUS_BIT_CRC_ERROR
    BNE wd_set_result_crc_error
    TXA
    AND #WD_STATUS_BIT_TYPE_II_III_LOST_BYTE
    BNE wd_set_result_lost_data
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
  .wd_set_result_lost_data
    LDA #&0A
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
    \\ Select the shift register interrupt enable, to avoid ever setting IER to
    \\ 0. Setting IER to 0 creates a window where a break will appear to the OS
    \\ to be a power on reset and everything would get wiped.
    LDA #&84
    STA &FE4E
    LDA #&7B
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
    LDA #&04
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

.discbeast_end

SAVE "BSTASM", discbeast_begin, discbeast_end
PUTFILE "DUTLASM", "DUTLASM", &5200
PUTTEXT "boot.txt", "!BOOT", 0
PUTBASIC "discbeast.bas", "DISCBST"
