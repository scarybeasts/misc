\\ oiledotter.asm
\\ A tool to directly drive the wires to a disc drive.

BASE = &7200
ZP = &70

ABI_WRITE_TRACK = (BASE + 0)

ORG ZP
GUARD (ZP + 16)

\\ 0
.var_zp_ABI_buf_1 SKIP 2
\\ 2
.var_zp_ABI_buf_2 SKIP 2
\\ 4
.var_zp_ABI_length SKIP 2
\\ 6
.var_zp_saw_no_index SKIP 1
\\ 7
.var_zp_source_buf_copy SKIP 2
.var_zp_dest_buf_copy SKIP 2
.var_zp_markers_buf SKIP 2
.var_zp_markers_count SKIP 1

ORG BASE
GUARD (BASE + 1024)

.oiledotter_begin

    \\ base + 0, write track
    JMP entry_write_track
    \\ base + 3, copy
    JMP entry_copy
    \\ base + 6, trks to otter
    JMP entry_trks_to_otter

.entry_write_track
    SEI

    \\ Turn the write gate on.
    LDA &FE60
    ORA #&C0
    AND #&FB
    STA &FE60

    \\ Buffer must be aligned to a page.
    LDA #0
    STA var_zp_ABI_buf_1

    LDA #1
    STA var_zp_saw_no_index

    \\ Set up video ULA register: MODE4
    LDA #&08
    STA &FE20
    \\ Set up video ULA colors: black, white
    LDA #&07
    LDX #8
    CLC
  .ula_color_black_loop
    STA &FE21
    ADC #&10
    DEX
    BNE ula_color_black_loop

    LDA #&80
    LDX #8
    CLC
  .ula_color_white_loop
    STA &FE21
    ADC #&10
    DEX
    BNE ula_color_white_loop

    \\ Set up 6845 video into a ready-to-go state.
    \\ Disable cursor.
    LDA #10:STA &FE00:LDA #&20:STA &FE01
    \\ Set screen start address to the first 32us of data.
    LDY #0
    LDA #12:STA &FE00:LDA (var_zp_ABI_buf_1),Y:INY:STA &FE01
    LDA #13:STA &FE00:LDA (var_zp_ABI_buf_1),Y:INY:STA &FE01
    \\ Disable interlace.
    LDA #8:STA &FE00:LDA #0:STA &FE01
    \\ No vertical adjust.
    LDA #5:STA &FE00:LDA #0:STA &FE01
    \\ Screen is just one character row
    LDA #4:STA &FE00:LDA #0:STA &FE01
    \\ Vsync at this one character row
    LDA #7:STA &FE00:LDA #0:STA &FE01

    \\ Wait for vsync to get to stable known position.
    LDA #2
    STA &FE4D
  .wait_vsync_1
    BIT &FE4D
    BEQ wait_vsync_1

    \\ Now at HC=0, VC=0, SC=0
    \\ Switch to single scanline 4 characters.
    LDA #9:STA &FE00:LDA #0:STA &FE01
    LDA #0:STA &FE00:LDA #3:STA &FE01
    \\ Warning: DRAM refresh must now be done manually!
    \\ Wait long enough for new frame to start.
    LDX #0
  .wait_new_frame
    LDA &00,X
    INX
    BNE wait_new_frame

    \\ Prepare for video unleash below.
    LDA #0:STA &FE00

    \\ Video is primed and ready to go.
    JMP wait_index_high

\\ Start a fresh page here because the main loop is extremely timing sensitive
\\ and we can't have any branches crossing pages.
ORG (BASE + 256)

    \\ Look for index pulse edge (active low) for when to go.
    \\ Need to see index high. Honor DRAM refresh.
  .wait_index_high
    LDA &00,X
    INX
    LDA &FE60
    AND #&40
    BEQ wait_index_high

    \\ Need to see index low. Honor DRAM refresh.
  .wait_index_low
    LDA &00,X
    INX
    LDA &FE60
    AND #&40
    BNE wait_index_low

    \\ Unleash the video!
    LDA #31:STA &FE01
    \\ Now aligned to even cycle.

  .main_loop_64cyc
    \\ 0cyc
    LDA #12:STA &FE00:LDA (var_zp_ABI_buf_1),Y:INY:STA &FE01
    \\ 20cyc
    LDA #13:STA &FE00:LDA (var_zp_ABI_buf_1),Y:INY:STA &FE01
    \\ 40cyc
    BNE main_loop_no_y_rollover
    INC var_zp_ABI_buf_1 + 1
    \\ 47cyc
    LDA &FE60
    AND #&40
    \\ 54cyc
    BEQ main_loop_no_y_rollover_no_index_high
    \\ 56cyc
    LDA #0
    STA var_zp_saw_no_index
    \\ 61cyc
    JMP main_loop_64cyc

  .main_loop_no_y_rollover_no_index_high
    \\ 57cyc
    NOP:NOP
    JMP main_loop_64cyc

  .main_loop_no_y_rollover
    \\ 43cyc
    LDA &FE60
    \\ 48cyc
    AND #&40
    ORA var_zp_saw_no_index
    BEQ main_loop_done
    \\ 55cyc
    LDA &00,X
    INX
    \\ 61 cyc
    JMP main_loop_64cyc

  .main_loop_done
    \\ Turn off drive write gate.
    LDA &FE60
    ORA #(&C0 + &04)
    STA &FE60

    \\ Restore just enough 6845 registers for a working DRAM refresh.
    LDA #0:STA &FE00:LDA #63:STA &FE01
    LDA #9:STA &FE00:LDA #7:STA &FE01

    LDA #4:STA &FE00:LDA #38:STA &FE01

    CLI
    RTS

.entry_copy
    LDA var_zp_ABI_length
    ORA var_zp_ABI_length + 1
    BEQ entry_copy_done
    LDY #0
  .entry_copy_loop
    LDA (var_zp_ABI_buf_2),Y
    STA (var_zp_ABI_buf_1),Y
    INC var_zp_ABI_buf_2
    BNE entry_copy_no_inc_hi_1
    INC var_zp_ABI_buf_2 + 1
  .entry_copy_no_inc_hi_1
    INC var_zp_ABI_buf_1
    BNE entry_copy_no_inc_hi_2
    INC var_zp_ABI_buf_1 + 1
  .entry_copy_no_inc_hi_2
    INC var_zp_ABI_length
    BNE entry_copy_loop
    INC var_zp_ABI_length + 1
    BNE entry_copy_loop
  .entry_copy_done
    RTS

.entry_trks_to_otter
    \\ Fill otter buffer with 0xFF data bytes.
    \\ Len: 6400 nibbles (negated).
    LDA #&00
    STA var_zp_ABI_length
    LDA #&E7
    STA var_zp_ABI_length + 1

    LDA var_zp_ABI_buf_1
    STA var_zp_dest_buf_copy
    LDA var_zp_ABI_buf_1 + 1
    STA var_zp_dest_buf_copy + 1

    LDY #0
  .write_ff_loop
    LDA #&2B
    STA (var_zp_dest_buf_copy),Y
    INY
    LDA #&E0
    STA (var_zp_dest_buf_copy),Y
    INY
    BNE write_ff_no_buf_rollover
    INC var_zp_dest_buf_copy + 1
  .write_ff_no_buf_rollover
    INC var_zp_ABI_length
    BNE write_ff_loop
    INC var_zp_ABI_length + 1
    BNE write_ff_loop

    \\ Get track length and fixup to 3125 if 0.
    LDY #6
    LDA (var_zp_ABI_buf_2),Y
    STA var_zp_ABI_length
    INY
    LDA (var_zp_ABI_buf_2),Y
    STA var_zp_ABI_length + 1
    BNE track_length_not_0
    LDA #&35
    STA var_zp_ABI_length
    LDA #&0C
    STA var_zp_ABI_length + 1
  .track_length_not_0
    \\ Negate.
    CLC
    LDA var_zp_ABI_length
    EOR #&FF
    ADC #1
    STA var_zp_ABI_length
    LDA var_zp_ABI_length + 1
    EOR #&FF
    ADC #0
    STA var_zp_ABI_length + 1

    \\ Convert data bytes.
    LDA var_zp_ABI_buf_1
    STA var_zp_dest_buf_copy
    LDA var_zp_ABI_buf_1 + 1
    STA var_zp_dest_buf_copy + 1
    LDA var_zp_ABI_buf_2
    STA var_zp_source_buf_copy
    LDA var_zp_ABI_buf_2 + 1
    CLC
    ADC #&02
    STA var_zp_source_buf_copy + 1

  .convert_data_bytes_loop
    \\ First nibble.
    LDY #0
    LDA (var_zp_source_buf_copy),Y
    AND #&F0
    ASL A
    INY
    STA (var_zp_dest_buf_copy),Y
    LDA #&2A
    ADC #0
    DEY
    STA (var_zp_dest_buf_copy),Y
    \\ Second nibble.
    LDA (var_zp_source_buf_copy),Y
    ASL A:ASL A:ASL A:ASL A:ASL A
    INY:INY:INY
    STA (var_zp_dest_buf_copy),Y
    LDA #&2A
    ADC #0
    DEY
    STA (var_zp_dest_buf_copy),Y

    \\ Increments.
    INC var_zp_source_buf_copy
    BNE convert_data_no_src_rollover
    INC var_zp_source_buf_copy + 1
  .convert_data_no_src_rollover
    LDA var_zp_dest_buf_copy
    CLC
    ADC #4
    STA var_zp_dest_buf_copy
    LDA var_zp_dest_buf_copy + 1
    ADC #0
    STA var_zp_dest_buf_copy + 1
    INC var_zp_ABI_length
    BNE convert_data_bytes_loop
    INC var_zp_ABI_length + 1
    BNE convert_data_bytes_loop

    \\ Replace marker bytes.
    \\ Sector ID markers at offset 0x100 in TRKS file.
    LDA var_zp_ABI_buf_2
    STA var_zp_markers_buf
    LDA var_zp_ABI_buf_2 + 1
    CLC
    ADC #&01
    STA var_zp_markers_buf + 1
    JSR do_marker_list
    \\ Data markers at offset 0x140 in TRKS file.
    LDA var_zp_ABI_buf_2
    CLC
    ADC #&40
    STA var_zp_markers_buf
    LDA var_zp_ABI_buf_2 + 1
    ADC #&01
    STA var_zp_markers_buf + 1
    JSR do_marker_list

    \\ Done.
    RTS

.do_marker_list
    LDA #32
    STA var_zp_markers_count
  .markers_loop
    LDY #0
    LDA (var_zp_markers_buf),Y
    STA var_zp_source_buf_copy
    STA var_zp_dest_buf_copy
    INY
    ORA (var_zp_markers_buf),Y
    BNE more_markers
    JMP markers_done
  .more_markers
    LDA (var_zp_markers_buf),Y
    STA var_zp_source_buf_copy + 1
    STA var_zp_dest_buf_copy + 1
    \\ Multiply dest index by 4.
    CLC
    ROL var_zp_dest_buf_copy
    ROL var_zp_dest_buf_copy + 1
    CLC
    ROL var_zp_dest_buf_copy
    ROL var_zp_dest_buf_copy + 1
    \\ Add baselines in to make final source / dest pointers.
    CLC
    LDA var_zp_dest_buf_copy
    ADC var_zp_ABI_buf_1
    STA var_zp_dest_buf_copy
    LDA var_zp_dest_buf_copy + 1
    ADC var_zp_ABI_buf_1 + 1
    STA var_zp_dest_buf_copy + 1
    CLC
    LDA var_zp_source_buf_copy
    ADC var_zp_ABI_buf_2
    STA var_zp_source_buf_copy
    LDA var_zp_source_buf_copy + 1
    ADC var_zp_ABI_buf_2 + 1
    ADC #&02
    STA var_zp_source_buf_copy + 1
    \\ Write first nibble, always data 0xF clock 0xC.
    LDY #0
    LDA #&29
    STA (var_zp_dest_buf_copy),Y
    INY
    LDA #&00
    STA (var_zp_dest_buf_copy),Y
    \\ Write second nibble, depends on marker type.
    LDY #0
    LDA (var_zp_source_buf_copy),Y
    LDY #2
    AND #&0F
    CMP #&08
    BEQ marker_deleted_data
    CMP #&0B
    BEQ marker_data
    \\ marker_sector_id
    LDA #&29
    STA (var_zp_dest_buf_copy),Y
    INY
    LDA #&20
    STA (var_zp_dest_buf_copy),Y
    JMP marker_post_write
  .marker_deleted_data
    LDA #&29
    STA (var_zp_dest_buf_copy),Y
    INY
    LDA #&60
    STA (var_zp_dest_buf_copy),Y
    JMP marker_post_write
  .marker_data
    LDA #&29
    STA (var_zp_dest_buf_copy),Y
    INY
    LDA #&40
    STA (var_zp_dest_buf_copy),Y

  .marker_post_write
    \\ Finally make sure there are sync bytes before the marker byte.
    LDA var_zp_source_buf_copy
    SEC
    SBC #2
    STA var_zp_source_buf_copy
    LDA var_zp_source_buf_copy + 1
    SBC #0
    STA var_zp_source_buf_copy + 1
    \\ Sync bytes are ok if there are 2x 0 preceding the marker byte.
    LDY #0
    LDA (var_zp_source_buf_copy),Y
    INY
    ORA (var_zp_source_buf_copy),Y
    BEQ sync_bytes_ok
    \\ Sync needs fixing. Write 6x 0 preceding the marker byte.
    LDA var_zp_dest_buf_copy
    SEC
    SBC #24
    STA var_zp_dest_buf_copy
    LDA var_zp_dest_buf_copy + 1
    SBC #0
    STA var_zp_dest_buf_copy + 1
    \\ 6 bytes, 12 nibbles.
    LDX #12
    LDY #0
  .sync_byte_write_loop
    LDA #&2A
    STA (var_zp_dest_buf_copy),Y
    INY
    LDA #&00
    STA (var_zp_dest_buf_copy),Y
    INY
    DEX
    BNE sync_byte_write_loop

  .sync_bytes_ok
    DEC var_zp_markers_count
    BEQ markers_done
    LDA var_zp_markers_buf
    CLC
    ADC #2
    STA var_zp_markers_buf
    JMP markers_loop
  .markers_done
    RTS

.oiledotter_end

SAVE "OOASM", oiledotter_begin, oiledotter_end
PUTTEXT "boot.txt", "!BOOT", 0
PUTBASIC "oiledotter.bas", "OOTTER"
PUTFILE "TFORM0", "TFORM0", &4000
