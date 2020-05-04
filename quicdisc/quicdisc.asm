\\ quicdisc.asm
\\ Generates quicdisc.ssd.
\\ Usage:
\\ *QUICDSC (loads and calls at &1900 which initializes and auto-detects
\\ floppy controller). Supports 8271, BBC B 1770, BBC Master 1770.
\\ By default the track buffer is &6000 but you can change it before any read
\\ call by modifying the pointer at &70.
\\ Currently, all access is to drive 0 (or drive 2 for the upper side).
\\ A%=5:CALL&1903
\\ Returns immediately; seek to track 5 in progress.
\\ R%=USR(&1909) AND &FF
\\ Now R% contains 0 if the command is done, nonzero otherwise.
\\ Returns immediately; all of current track is being read into &6000.
\\ A%=0:CALL&1906
\\ If you want to read a track on the upper side of the disc (i.e. drive 1),
\\ use A%=1 for the read.

BASE = &1900
ZP = &70

ABI_INIT = (BASE + 0)
ABI_SEEK = (BASE + 3)
ABI_READ_TRACK = (BASE + 6)
ABI_GET_STATUS = (BASE + 9)
ABI_WAIT = (BASE + 12)

NMI = &0D00
OSBYTE = &FFF4

INTEL_CMD_DRIVE0 = &40
INTEL_CMD_READ_SECTORS = &13
INTEL_CMD_SEEK = &29
INTEL_CMD_READ_STATUS = &2C
INTEL_CMD_SPECIFY = &35
INTEL_CMD_SET_PARAM = &3A
INTEL_PARAM_SPINDOWN_LOADTIME = &0F
INTEL_PARAM_DRVOUT = &23
INTEL_DRVOUT_SELECT0 = &40
INTEL_DRVOUT_LOAD_HEAD = &08

WD_CMD_RESTORE = &00
WD_CMD_SEEK = &10
WD_CMD_READ_SECTOR_MUTI_SETTLE = &94

ORG ZP
GUARD (ZP + 16)

.var_zp_buf_ptr SKIP 2
.var_zp_wd_base SKIP 2
.var_zp_wd_drvctrl SKIP 2
.var_zp_wd_sd_0_lower SKIP 1
.var_zp_wd_sd_0_upper SKIP 1
.var_zp_track SKIP 1
.var_zp_temp SKIP 1

ORG BASE
GUARD (BASE + 512)

.quicdisc_begin

    \\ base + 0, init
    JMP entry_init
    \\ base + 3, seek
    JMP entry_not_set
    \\ base + 6, read track
    JMP entry_not_set
    \\ base + 9, get status
    JMP entry_not_set
    \\ base + 12, wait
    JMP wait_command_finish

.entry_not_set
    BRK

.entry_init
    \\ *FX 140,0, aka. *TAPE
    LDA #&8C
    LDX #0
    LDY #0
    JSR OSBYTE

    \\ Set up default buffer to &6000.
    LDA #0
    STA var_zp_buf_ptr
    LDA #&60
    STA var_zp_buf_ptr + 1

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

    RTS

.detected_intel
    \\ Set up vectors.
    LDA #LO(intel_seek)
    STA ABI_SEEK + 1
    LDA #HI(intel_seek)
    STA ABI_SEEK + 2
    LDA #LO(intel_read_track)
    STA ABI_READ_TRACK + 1
    LDA #HI(intel_read_track)
    STA ABI_READ_TRACK + 2
    LDA #LO(intel_get_status)
    STA ABI_GET_STATUS + 1
    LDA #HI(intel_get_status)
    STA ABI_GET_STATUS + 2

    \\ Copy over and patch NMI routine.
    LDA #&84
    JSR copy_patch_nmi_routine

    \\ Disable automatic spindown. On my machine, the 8271 is super picky about
    \\ starting up again after it spins down, requiring a seek to track 0??
    \\ Also set seek time to 12ms, twice as fast as standard but still slow.
    LDA #INTEL_CMD_SET_PARAM
    JSR intel_do_cmd
    LDA #INTEL_PARAM_SPINDOWN_LOADTIME
    JSR intel_do_param
    \\ No auto unload, head load 16ms.
    LDA #&F8
    JSR intel_do_param
    JSR wait_command_finish

    \\ Spin up and load head.
    LDA #0
    JSR intel_set_drvout

    \\ Seek to 0.
    LDA #0
    JSR ABI_SEEK
    JSR wait_command_finish
    RTS

.detected_wd_fe8x
    LDA #&84
    STA var_zp_wd_base
    LDA #&80
    STA var_zp_wd_drvctrl
    LDA #&09
    STA var_zp_wd_sd_0_lower
    LDA #&0D
    STA var_zp_wd_sd_0_upper
    JMP detected_wd_common

.detected_wd_fe2x
    LDA #&28
    STA var_zp_wd_base
    LDA #&24
    STA var_zp_wd_drvctrl
    LDA #&21
    STA var_zp_wd_sd_0_lower
    LDA #&31
    STA var_zp_wd_sd_0_upper
    JMP detected_wd_common

.detected_wd_common
    LDA #&FE
    STA var_zp_wd_base + 1
    STA var_zp_wd_drvctrl + 1

    \\ Set up vectors.
    LDA #LO(wd_seek)
    STA ABI_SEEK + 1
    LDA #HI(wd_seek)
    STA ABI_SEEK + 2
    LDA #LO(wd_read_track)
    STA ABI_READ_TRACK + 1
    LDA #HI(wd_read_track)
    STA ABI_READ_TRACK + 2
    LDA #LO(wd_get_status)
    STA ABI_GET_STATUS + 1
    LDA #HI(wd_get_status)
    STA ABI_GET_STATUS + 2

    \\ Copy over and patch NMI routine.
    LDA var_zp_wd_base
    CLC
    ADC #3
    JSR copy_patch_nmi_routine

    \\ Seek to 0.
    LDA #0
    JSR ABI_SEEK
    JSR wait_command_finish
    RTS

.intel_set_drvout
    \\ A=0, lower side. A=1, upper side.
    \\ Set drvout including side. Upper side select is 0x20.
    TAX
    LDA #(INTEL_CMD_DRIVE0 + INTEL_CMD_SET_PARAM)
    JSR intel_do_cmd
    LDA #INTEL_PARAM_DRVOUT
    JSR intel_do_param
    TXA
    AND #&01
    ASL A
    ASL A
    ASL A
    ASL A
    ASL A
    ORA #(INTEL_DRVOUT_SELECT0 + INTEL_DRVOUT_LOAD_HEAD)
    JSR intel_do_param
    JSR wait_command_finish
    RTS

.intel_seek
    STA var_zp_track

    JSR intel_wait_ready

    LDA #(INTEL_CMD_DRIVE0 + INTEL_CMD_SEEK)
    JSR intel_do_cmd
    LDA var_zp_track
    JSR intel_do_param
    RTS

.intel_read_track
    JSR intel_set_drvout
    JSR reset_buf_ptr

    JSR intel_wait_ready

    LDA #(INTEL_CMD_DRIVE0 + INTEL_CMD_READ_SECTORS)
    JSR intel_do_cmd
    \\ Track.
    LDA var_zp_track
    JSR intel_do_param
    \\ Start sector.
    LDA #0
    JSR intel_do_param
    \\ 10x 256 byte sectors.
    LDA #&2A
    JSR intel_do_param
    RTS

.intel_get_status
    \\ Return nonzero if busy.
    LDA &FE80
    AND #&80
    RTS

.intel_wait_ready
    LDA #(INTEL_CMD_DRIVE0 + INTEL_CMD_READ_STATUS)
    JSR intel_do_cmd
    JSR wait_command_finish
    LDA &FE81
    \\ Check RDY0.
    AND #&04
    BEQ intel_wait_ready
    RTS

.intel_do_cmd
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

.wd_seek
    STA var_zp_track
    CMP #0
    BEQ wd_seek_to_0
    \\ Desired track goes in data register.
    LDY #3
    STA (var_zp_wd_base),Y
    LDY #0
    LDA #WD_CMD_SEEK
    STA (var_zp_wd_base),Y
    JMP wd_delay_and_rts
  .wd_seek_to_0
    \\ Command 0, no flags is retore to track 0 + spin up.
    LDY #0
    LDA #WD_CMD_RESTORE
    STA (var_zp_wd_base),Y
.wd_delay_and_rts
    JSR wd_delay
    RTS

.wd_read_track
    JSR reset_buf_ptr

    \\ Set side.
    CMP #0
    BEQ wd_read_track_lower
    LDA var_zp_wd_sd_0_upper
    JMP wd_read_track_set_side_done
  .wd_read_track_lower
    LDA var_zp_wd_sd_0_lower
  .wd_read_track_set_side_done
    LDY #0
    STA (var_zp_wd_drvctrl),Y

    \\ Start sector.
    LDY #2
    LDA #0
    STA (var_zp_wd_base),Y
    \\ Command. Read, multiple sectors, spin up, head settle.
    LDY #0
    LDA #WD_CMD_READ_SECTOR_MUTI_SETTLE
    STA (var_zp_wd_base),Y

    JMP wd_delay_and_rts

.wd_get_status
    \\ Return nonzero if busy.
    LDY #0
    LDA (var_zp_wd_base),Y
    AND #&01
    RTS

.wd_delay
    \\ Longest delay we use is write command -> read busy bit, 48us.
    LDX #20
  .wd_delay_loop
    DEX
    BNE wd_delay_loop
    RTS

.wait_command_finish
    JSR ABI_GET_STATUS
    BNE wait_command_finish
    RTS

.reset_buf_ptr
    LDX var_zp_buf_ptr
    STX NMI + 6
    LDX var_zp_buf_ptr + 1
    STX NMI + 7
    RTS

.nmi_routine
    STA var_zp_temp
    LDA $FEFF
    STA $C000
    INC NMI + 6
    BNE nmi_routine_no_inc_hi
    INC NMI + 7
  .nmi_routine_no_inc_hi
    LDA var_zp_temp
    RTI
.nmi_routine_end

.copy_patch_nmi_routine
    \\ Patch the data register read.
    STA nmi_routine + 3

    LDX #0
  .copy_nmi_loop
    LDA nmi_routine, X
    STA NMI, X
    INX
    CPX #(nmi_routine_end - nmi_routine)
    BNE copy_nmi_loop
    RTS

.quicdisc_end

SAVE "QUICDSC", quicdisc_begin, quicdisc_end
