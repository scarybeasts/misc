\\ hfegrab.asm
\\ Grab HFEs directly from a beeb.

BASE = &1100
ZP = &70
DATA_BUF = &6000
TIMING_BUF = &5F00

ABI_INIT = (BASE + 0)
ABI_LOAD_HEAD = (BASE + 3)
ABI_TIME_TRACK = (BASE + 6)
ABI_SEEK = (BASE + 9)
ABI_READ_SECTOR_IDS = (BASE + 12)
ABI_READ_SECTORS = (BASE + 15)
ABI_CLEAR_PAGES = (BASE + 18)
ABI_COPY_PAGES = (BASE + 21)
ABI_CHECK_WEAK = (BASE + 24)
ABI_CRC32 = (BASE + 27)

INTEL_CMD_READ_SECTORS_AND_DELETED = &17
INTEL_CMD_READ_SECTOR_IDS = &1B
INTEL_CMD_SEEK = &29
INTEL_CMD_READ_STATUS = &2C
INTEL_CMD_WRITE_SPECIAL_REGISTER = &3A

INTEL_SR_STEP_RATE = &0D
INTEL_SR_HEAD_SETTLE_TIME = &0E
INTEL_SR_HEAD_LOAD = &0F
INTEL_SR_DRIVE_0_BAD_TRACK_1 = &10
INTEL_SR_DRIVE_0_BAD_TRACK_2 = &11
INTEL_SR_DRIVE_0_TRACK = &12
INTEL_SR_MODE = &17
INTEL_SR_DRIVE_1_BAD_TRACK_1 = &18
INTEL_SR_DRIVE_1_BAD_TRACK_2 = &19
INTEL_SR_DRIVE_1_TRACK = &1A
INTEL_SR_DRVOUT = &23

INTEL_DRVOUT_LOAD_HEAD = &08
INTEL_DRVOUT_SIDE_2 = &20

INTEL_STATUS_DATA_BYTE = &04
INTEL_STATUS_PARAM_BUSY = &20
INTEL_STATUS_COMMAND_BUSY = &40
INTEL_STATUS_BUSY = &80

INTEL_DRIVE_READY_1 = &40
INTEL_DRIVE_STATUS_INDEX = &10
INTEL_DRIVE_READY_0 = &04

INTEL_DRIVE_0 = &40
INTEL_DRIVE_1 = &80

OSBYTE = &FFF4

ORG ZP
GUARD (ZP + 32)

.var_zp_ABI_buf_1 SKIP 2
.var_zp_ABI_buf_2 SKIP 2
.var_zp_data_buf SKIP 2
.var_zp_timing_buf SKIP 2
.var_zp_extra_buf SKIP 2
.var_zp_temp_1 SKIP 1
.var_zp_temp_2 SKIP 1
.var_zp_temp_3 SKIP 1
.var_zp_drive SKIP 1
.var_zp_ready SKIP 1
.var_zp_side SKIP 1
.var_zp_track SKIP 1
.var_zp_timer_count SKIP 2
.var_zp_timer_update_count SKIP 1
.var_zp_timer_update_reload SKIP 1

ORG BASE

.hfegrab_begin

    \\ base + &00, init
    JMP entry_init
    \\ base + &03, load head
    JMP entry_load_head
    \\ base + &06, time track
    JMP entry_time_track
    \\ base + &09, seek
    JMP entry_seek
    \\ base + &0C, read sector ids
    JMP entry_read_sector_ids
    \\ base + &0F, read sectors
    JMP entry_read_sectors
    \\ base + &12, clear pages
    JMP entry_clear_pages
    \\ base + &15, copy pages
    JMP entry_copy_pages
    \\ base + &18, check weak
    JMP entry_check_weak
    \\ base + &1B, CRC32
    JMP entry_crc_32

.entry_init
    \\ *FX 140,0, aka. *TAPE
    LDA #&8C
    LDX #0
    LDY #0
    JSR OSBYTE

    \\ Commandeer the USER VIA for timing.
    \\ Continuous TIMER1.
    LDA #$40
    STA &FE6B
    \\ Interrupts off, we poll.
    LDA #&7F
    STA &FE6E

    \\ Reset controller.
    LDA #1
    STA &FE82
    LDX #10
  .reset_loop
    DEX
    BNE reset_loop
    LDA #0
    STA &FE82

    \\ Clear NMI handler.
    \\ &40 == RTI
    LDA #&40
    STA &0D00

    \\ Clear variables.
    LDA #0
    STA var_zp_drive
    STA var_zp_ready
    STA var_zp_side
    STA var_zp_track
    STA var_zp_timer_count
    STA var_zp_timer_count + 1
    STA var_zp_timer_update_count

    \\ Set default buffers.
    LDA #LO(DATA_BUF)
    STA var_zp_ABI_buf_1
    LDA #HI(DATA_BUF)
    STA var_zp_ABI_buf_1 + 1
    LDA #LO(TIMING_BUF)
    STA var_zp_ABI_buf_2
    LDA #HI(TIMING_BUF)
    STA var_zp_ABI_buf_2 + 1

    \\ Set special registers.
    \\ Bad tracks.
    LDA #INTEL_SR_DRIVE_0_BAD_TRACK_1
    LDX #&FF
    JSR intel_write_special_register
    LDA #INTEL_SR_DRIVE_0_BAD_TRACK_2
    LDX #&FF
    JSR intel_write_special_register
    LDA #INTEL_SR_DRIVE_1_BAD_TRACK_1
    LDX #&FF
    JSR intel_write_special_register
    LDA #INTEL_SR_DRIVE_1_BAD_TRACK_2
    LDX #&FF
    JSR intel_write_special_register
    \\ Current track.
    LDA #INTEL_SR_DRIVE_0_TRACK
    LDX #0
    JSR intel_write_special_register
    LDA #INTEL_SR_DRIVE_1_TRACK
    LDX #0
    JSR intel_write_special_register
    \\ Step, settle, load times.
    \\ This includes selecting no automatic head unload.
    LDA #INTEL_SR_STEP_RATE
    LDX #&0C
    JSR intel_write_special_register
    LDA #INTEL_SR_HEAD_SETTLE_TIME
    LDX #&0A
    JSR intel_write_special_register
    LDA #INTEL_SR_HEAD_LOAD
    LDX #&F8
    JSR intel_write_special_register
    \\ Mode. DMA off.
    LDA #INTEL_SR_MODE
    LDX #&C1
    JSR intel_write_special_register

    RTS

.entry_load_head
    CMP #0
    BEQ load_head_drive_0
    LDA #INTEL_DRIVE_1
    LDY #INTEL_DRIVE_READY_1
    JMP load_head_drive_done
  .load_head_drive_0
    LDA #INTEL_DRIVE_0
    LDY #INTEL_DRIVE_READY_0
  .load_head_drive_done
    STA var_zp_drive
    STY var_zp_ready

    TXA
    BEQ load_head_side_done
    LDA #INTEL_DRVOUT_SIDE_2
  .load_head_side_done
    STA var_zp_side

    LDA var_zp_drive
    ORA var_zp_side
    ORA #INTEL_DRVOUT_LOAD_HEAD
    TAX
    LDA #INTEL_SR_DRVOUT
    JSR intel_write_special_register

    JSR intel_wait_ready

    LDA #0
    JSR ABI_SEEK

    RTS

.entry_time_track
    SEI
    JSR wait_track_start_no_index
    JSR wait_track_start_index
    JSR timer_start

  .entry_time_track_loop_1
    JSR timer_check_update
    JSR intel_get_drive_status
    AND #INTEL_DRIVE_STATUS_INDEX
    BNE entry_time_track_loop_1
  .entry_time_track_loop_2
    JSR timer_check_update
    JSR intel_get_drive_status
    AND #INTEL_DRIVE_STATUS_INDEX
    BEQ entry_time_track_loop_2

    JSR timer_check_update
    LDY #0
    LDA var_zp_timer_count
    STA (var_zp_ABI_buf_1), Y
    INY
    LDA var_zp_timer_count + 1
    STA (var_zp_ABI_buf_1), Y

    CLI
    RTS

.entry_seek
    STA var_zp_track
    LDA #INTEL_CMD_SEEK
    ORA var_zp_drive
    JSR intel_send_command
    LDA var_zp_track
    JSR intel_send_param
    JSR intel_wait_command_done
    RTS

.entry_read_sector_ids
    SEI
    LDA #(4 - 1)
    JSR reset_buffers
    JSR wait_track_start
    JSR timer_start
    LDA #INTEL_CMD_READ_SECTOR_IDS
    ORA var_zp_drive
    JSR intel_send_command
    LDA var_zp_track
    JSR intel_send_param
    LDA #0
    JSR intel_send_param
    \\ 0 for number gives the max, 32.
    LDA #0
    JSR intel_send_param

    JSR do_data_loop

    CLI
    RTS

.entry_read_sectors
    SEI
    \\ A = track, X = sector, Y = size and number
    STA var_zp_temp_1
    STX var_zp_temp_2
    STY var_zp_temp_3

    \\ Set track register to match requested track.
    LDA #INTEL_SR_DRIVE_0_TRACK
    LDX var_zp_side
    BEQ entry_read_sectors_is_side_0_1
    LDA #INTEL_SR_DRIVE_1_TRACK
  .entry_read_sectors_is_side_0_1
    LDX var_zp_temp_1
    JSR intel_write_special_register

    \\ Do the read.
    LDA #(256 - 1)
    JSR reset_buffers
    JSR wait_track_start
    JSR timer_start
    LDA #INTEL_CMD_READ_SECTORS_AND_DELETED
    ORA var_zp_drive
    JSR intel_send_command
    LDA var_zp_temp_1
    JSR intel_send_param
    LDA var_zp_temp_2
    JSR intel_send_param
    LDA var_zp_temp_3
    JSR intel_send_param

    JSR do_data_loop
    STA var_zp_temp_1

    \\ Put that track register back.
    LDA #INTEL_SR_DRIVE_0_TRACK
    LDX var_zp_side
    BEQ entry_read_sectors_is_side_0_2
    LDA #INTEL_SR_DRIVE_1_TRACK
  .entry_read_sectors_is_side_0_2
    LDX var_zp_track
    JSR intel_write_special_register

    LDA var_zp_temp_1
    CLI
    RTS

.entry_clear_pages
    TAX

    LDA var_zp_ABI_buf_1
    STA var_zp_data_buf
    LDA var_zp_ABI_buf_1 + 1
    STA var_zp_data_buf + 1

    LDA #0
    LDY #0
  .entry_clear_pages_byte_loop
    STA (var_zp_data_buf), Y
    INY
    BNE entry_clear_pages_byte_loop
    INC var_zp_data_buf + 1
    DEX
    BNE entry_clear_pages_byte_loop

    RTS

.entry_copy_pages
    TAX

    LDA var_zp_ABI_buf_1
    STA var_zp_data_buf
    LDA var_zp_ABI_buf_1 + 1
    STA var_zp_data_buf + 1
    LDA var_zp_ABI_buf_2
    STA var_zp_extra_buf
    LDA var_zp_ABI_buf_2 + 1
    STA var_zp_extra_buf + 1

    LDY #0
  .entry_copy_pages_byte_loop
    LDA (var_zp_data_buf), Y
    STA (var_zp_extra_buf), Y
    INY
    BNE entry_copy_pages_byte_loop
    INC var_zp_data_buf + 1
    INC var_zp_extra_buf + 1
    DEX
    BNE entry_copy_pages_byte_loop

    RTS

.entry_check_weak
    LDA var_zp_ABI_buf_1
    STA var_zp_data_buf
    LDA var_zp_ABI_buf_1 + 1
    STA var_zp_data_buf + 1
    LDA var_zp_ABI_buf_2
    STA var_zp_extra_buf
    LDA var_zp_ABI_buf_2 + 1
    STA var_zp_extra_buf + 1
    LDA var_zp_ABI_buf_2
    STA var_zp_timing_buf
    LDA var_zp_ABI_buf_2 + 1
    CLC
    ADC #13
    STA var_zp_timing_buf + 1
    LDA #0
    STA var_zp_temp_1
    LDA #&80
    STA var_zp_temp_2

    \\ Check 12 * 256 == 3072 bytes.
    LDX #12
    LDY #0
  .entry_check_weak_byte_loop
    LDA (var_zp_data_buf), Y
    CMP (var_zp_extra_buf), Y
    BEQ entry_check_weak_match
    \\ Mismatch. Log it.
    LDA #1
    STA var_zp_temp_1
    STY var_zp_temp_3
    LDY #0
    LDA (var_zp_timing_buf), Y
    ORA var_zp_temp_2
    STA (var_zp_timing_buf), Y
    LDY var_zp_temp_3
  .entry_check_weak_match
    LSR var_zp_temp_2
    BCC entry_check_weak_next_byte
    LDA #&80
    STA var_zp_temp_2
    INC var_zp_timing_buf
    BNE entry_check_weak_next_byte
    INC var_zp_timing_buf + 1
  .entry_check_weak_next_byte
    INY
    BNE entry_check_weak_byte_loop
    INC var_zp_data_buf + 1
    INC var_zp_extra_buf + 1
    DEX
    BNE entry_check_weak_byte_loop

    LDA var_zp_temp_1
    RTS

.entry_crc_32
    \\ A = count (0 == 256)
    \\ X, Y = pointer to CRC (big endian)
    \\ var_zp_ABI_buf = source data
    STX var_zp_extra_buf
    STY var_zp_extra_buf + 1
    STA var_zp_temp_1
    LDA var_zp_ABI_buf_1
    STA var_zp_data_buf
    LDA var_zp_ABI_buf_1 + 1
    STA var_zp_data_buf + 1

  .entry_crc_32_byte_loop
    LDY #0
    LDA (var_zp_data_buf), Y
    LDY #3
    EOR (var_zp_extra_buf), Y
    STA (var_zp_extra_buf), Y

    LDA #8
    STA var_zp_temp_2
  .entry_crc_32_shift_loop
    LDY #3
    LDA (var_zp_extra_buf), Y
    AND #1
    STA var_zp_temp_3

    LDY #0
    LDX #4
    CLC
  .entry_crc_32_rotate_loop
    LDA (var_zp_extra_buf), Y
    ROR A
    STA (var_zp_extra_buf), Y
    INY
    DEX
    BNE entry_crc_32_rotate_loop

    LDA var_zp_temp_3
    BEQ entry_crc_32_no_eor
    LDY #0
    LDA (var_zp_extra_buf), Y
    EOR #&ED
    STA (var_zp_extra_buf), Y
    INY
    LDA (var_zp_extra_buf), Y
    EOR #&B8
    STA (var_zp_extra_buf), Y
    INY
    LDA (var_zp_extra_buf), Y
    EOR #&83
    STA (var_zp_extra_buf), Y
    INY
    LDA (var_zp_extra_buf), Y
    EOR #&20
    STA (var_zp_extra_buf), Y

  .entry_crc_32_no_eor
    DEC var_zp_temp_2
    BNE entry_crc_32_shift_loop

    INC var_zp_data_buf
    BNE entry_crc_32_no_hi_inc
    INC var_zp_data_buf + 1
  .entry_crc_32_no_hi_inc
    DEC var_zp_temp_1
    BNE entry_crc_32_byte_loop

    RTS

.do_data_loop
    JSR timer_check_update
    LDA &FE80
    BPL do_data_loop_done
    AND #INTEL_STATUS_DATA_BYTE
    BEQ do_data_loop

    LDA &FE84
    LDY #0
    STA (var_zp_data_buf), Y
    INC var_zp_data_buf
    BNE do_data_loop_no_inc_hi
    INC var_zp_data_buf + 1
  .do_data_loop_no_inc_hi
    LDA var_zp_timer_update_count
    BEQ do_data_loop_capture_timing
    DEC var_zp_timer_update_count
    JMP do_data_loop

  .do_data_loop_capture_timing
    LDA var_zp_timer_count
    STA (var_zp_timing_buf), Y
    INC var_zp_timing_buf
    BNE do_data_loop_timing_no_inc_hi_1
    INC var_zp_timing_buf + 1
  .do_data_loop_timing_no_inc_hi_1
    LDA var_zp_timer_count + 1
    STA (var_zp_timing_buf), Y
    INC var_zp_timing_buf
    BNE do_data_loop_timing_no_inc_hi_2
    INC var_zp_timing_buf + 1
  .do_data_loop_timing_no_inc_hi_2
    LDA var_zp_timer_update_reload
    STA var_zp_timer_update_count
    JMP do_data_loop

  .do_data_loop_done
    LDA &FE81
    RTS

.reset_buffers
    STA var_zp_timer_update_reload
    LDA #0
    STA var_zp_timer_update_count
    LDA var_zp_ABI_buf_1
    STA var_zp_data_buf
    LDA var_zp_ABI_buf_1 + 1
    STA var_zp_data_buf + 1
    LDA var_zp_ABI_buf_2
    STA var_zp_timing_buf
    LDA var_zp_ABI_buf_2 + 1
    STA var_zp_timing_buf + 1
    RTS

.wait_track_start
    JSR wait_track_start_no_index
    JSR wait_track_start_index
    RTS

.wait_track_start_no_index
    JSR intel_get_drive_status
    AND #INTEL_DRIVE_STATUS_INDEX
    BNE wait_track_start_no_index
    RTS

.wait_track_start_index
    JSR intel_get_drive_status
    AND #INTEL_DRIVE_STATUS_INDEX
    BEQ wait_track_start_index
    RTS

.timer_start
    \\ 64us.
    LDA #62
    STA &FE64
    LDA #0
    STA &FE65
    STA var_zp_timer_count
    STA var_zp_timer_count + 1
    LDA #&7F
    STA &FE6D
    RTS

.timer_check_update
    LDA &FE6D
    BEQ timer_check_update_done
    STA &FE6D
    INC var_zp_timer_count
    BNE timer_check_update_done
    INC var_zp_timer_count + 1
  .timer_check_update_done
    RTS

.intel_write_special_register
    TAY
    LDA #INTEL_CMD_WRITE_SPECIAL_REGISTER
    ORA var_zp_drive
    JSR intel_send_command
    TYA
    JSR intel_send_param
    TXA
    JSR intel_send_param
    JSR intel_wait_command_done
    RTS

.intel_get_drive_status
    LDA #INTEL_CMD_READ_STATUS
    ORA var_zp_drive
    JSR intel_send_command
    JSR intel_wait_command_done
    RTS

.intel_wait_ready
    JSR intel_get_drive_status
    AND var_zp_ready
    BEQ intel_wait_ready
    RTS

.intel_send_command
    STA &FE80
  .intel_send_command_loop
    JSR timer_check_update
    LDA &FE80
    AND #INTEL_STATUS_COMMAND_BUSY
    BNE intel_send_command_loop
    RTS

.intel_send_param
    STA &FE81
  .intel_send_param_loop
    JSR timer_check_update
    LDA &FE80
    AND #INTEL_STATUS_PARAM_BUSY
    BNE intel_send_param_loop
    RTS

.intel_wait_command_done
    JSR timer_check_update
    LDA &FE80
    TAX
    AND #INTEL_STATUS_BUSY
    BNE intel_wait_command_done
    LDA &FE81
    RTS

.hfegrab_end

SAVE "HGASM", hfegrab_begin, hfegrab_end
PUTTEXT "boot.txt", "!BOOT", 0
PUTBASIC "load.bas", "LOAD"
PUTBASIC "hfegrab.bas", "HFEGRAB"
