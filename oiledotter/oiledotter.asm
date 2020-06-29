\\ oiledotter.asm
\\ A tool to directly drive the wires to a disc drive.

BASE = &7200
ZP = &70

ABI_WRITE_TRACK = (BASE + 0)

ORG ZP
GUARD (ZP + 16)

\\ 0
.var_zp_ABI_buf SKIP 2
\\ 2
.var_zp_saw_no_index SKIP 1

ORG BASE
GUARD (BASE + 256)

.oiledotter_begin

    \\ base + 0, write track
    JMP entry_write_track

.entry_write_track
    SEI

    \\ Buffer must be aligned to a page.
    LDA #0
    STA var_zp_ABI_buf

    LDA #1
    STA var_zp_saw_no_index

    \\ Set up 6845 video into a ready-to-go state.
    \\ Disable cursor.
    LDA #10:STA &FE00:LDA #&20:STA &FE01
    \\ Set screen start address to the first 32us of data.
    LDY #0
    LDA #12:STA &FE00:LDA (var_zp_ABI_buf),Y:INY:STA &FE01
    LDA #13:STA &FE00:LDA (var_zp_ABI_buf),Y:INY:STA &FE01
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

    LDA #0

  .main_loop_64cyc
    \\ 0cyc
    LDA #12:STA &FE00:LDA (var_zp_ABI_buf),Y:INY:STA &FE01
    \\ 20cyc
    LDA #13:STA &FE00:LDA (var_zp_ABI_buf),Y:INY:STA &FE01
    \\ 40cyc
    BNE main_loop_no_y_rollover
    INC var_zp_ABI_buf + 1
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
    ORA #&04
    STA &FE60

    \\ Restore just enough 6845 registers for a working DRAM refresh.
    LDA #0:STA &FE00:LDA #63:STA &FE01
    LDA #9:STA &FE00:LDA #7:STA &FE01

    CLI
    RTS

.oiledotter_end

SAVE "OOASM", oiledotter_begin, oiledotter_end
PUTTEXT "boot.txt", "!BOOT", 0
PUTBASIC "oiledotter.bas", "OOTTER"
PUTFILE "TFORM0", "TFORM0", &4000
