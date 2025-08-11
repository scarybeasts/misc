addr_input_song_start = &70
addr_input_song_end = &71
addr_input_advance_tables_src = &72
addr_input_advance_tables_dst = &73
addr_input_advance_tables_len = &74
addr_input_period_1 = &75
addr_input_period_2 = &76
addr_input_period_3 = &77
addr_input_song_speed = &78

addr_sample_starts = &120
addr_sample_ends = &130
addr_sample_wraps = &140
addr_sample_wraps_fine = &150
addr_sample_starts_fine = &160
addr_scope_chan1 = &200
addr_scope_chan2 = &300
addr_scope_chan3 = &400
addr_scope_y_table = &500
addr_scope_glyph_table = &600
\\ Spills 24 bytes past 1 page.
addr_silence = &700
addr_lookup_channel = &900
addr_lookup_note = &940
addr_lookup_instr = &980
addr_lookup_row_skip = &9C0

\\ Player variables from &00 - &1F.
\\ Avoid colliding with input parameter space at &70.
ORG &00
GUARD &1F

.var_song_tick_counter SKIP 1
.var_song_row_skip_counter SKIP 1
.var_song_lo SKIP 1
.var_song_hi SKIP 1
.var_next_byte SKIP 1
.var_scope_chan1_ptr_lo SKIP 1
.var_scope_chan1_ptr_hi SKIP 1
.var_scope_chan2_ptr_lo SKIP 1
.var_scope_chan2_ptr_hi SKIP 1
.var_scope_chan3_ptr_lo SKIP 1
.var_scope_chan3_ptr_hi SKIP 1
.var_scope_value SKIP 1
.var_temp_x SKIP 1
.var_channel1_instr SKIP 1
.var_channel2_instr SKIP 1
.var_channel3_instr SKIP 1

ORG &40
GUARD &FF

.zero_page_play_start

\\ The zero-page play loop at &40.
  .main_loop
  \\ 0 cycles
  .channel1_load
  LDY &FFFF
  LDA channel1_load + 1
  .channel1_advance
  ADC &FFFF,X
  \\ 5 cycles, shorter 2 cycle 1MHz write.
  STY &FE4F
  \\ 16 cycles (next slot 16+32 == 48 cycles)
  STA channel1_load + 1
  \\ TODO: can save a cycle here by using a branch / INC. This comes at the
  \\ cost of leaving the carry flag potentially clear, potentially set as we
  \\ exit each channel block.
  LDA channel1_load + 2
  ADC #0
  STA channel1_load + 2
  \\ 27 cycles

  .channel2_load
  LDY &FFFF
  LDA channel2_load + 1
  .channel2_advance
  ADC &FFFF,X
  STA channel2_load + 1
  INX
  \\ 5 cycles, shorter 2 cycle 1MHz write.
  STY &FE4F
  \\ 48 cycles (next slot 48+32 == 80 cycles)
  LDA channel2_load + 2
  ADC #0
  STA channel2_load + 2
  \\ 56 cycles

  .channel3_load
  LDY &FFFF
  LDA channel3_load + 1
  .channel3_advance
  ADC &FFFF,X
  STA channel3_load + 1
  LDA channel3_load + 2
  ADC #0
  \\ 5 cycles, shorter 2 cycle 1MHz write.
  STY &FE4F
  \\ 80 cycles
  STA channel3_load + 2
  \\ 83 cycles (45 remain)

  .main_loop_jump
  JMP jmp_do_scope_chan1_clear_load

  \\ All jump targets: 86 cycles (42 remain)

  \\ The channel 3 wrap check is currently hosted in the zero page.
  \\ This is because it hosts a self-modified jump.
  \\ TODO: some of these per-instrument lookups could be a lot faster if we
  \\ wanted to self-modify the values when the note is played.
  .do_channel3_check_wrap
  \\ 86 cycles (42 remain)
  .load_next_do_after_channel3_check
  LDA #LO(jmp_do_vsync_check)
  STA main_loop_jump + 1
  LDY var_channel3_instr
  LDA channel3_load + 2
  CMP addr_sample_ends,Y
  BNE no_channel3_wrap
  LDA addr_sample_wraps,Y
  BEQ no_channel3_sample_loop
  STA channel3_load + 2
  LDA channel3_load + 1
  \\ Warning: carry set. Must be catered for in lookup table.
  ADC addr_sample_wraps_fine,Y
  STA channel3_load + 1
  \\ 122 cycles (6 remain)
  JMP jmp_main_loop_6
  .no_channel3_wrap
  \\ 104 cycles (24 remain)
  JMP jmp_main_loop_24
  .no_channel3_sample_loop
  \\ 110 cycles (18 remain)
  LDA #HI(addr_silence)
  STA channel3_load + 2
  LDA #&F
  STA var_channel3_instr
  CLC
  JMP jmp_main_loop_6

  .jmp_do_scope_chan1_clear_load
  JMP do_scope_chan1_clear_load
  .jmp_do_scope_chan1_render
  JMP do_scope_chan1_render
  .jmp_do_scope_chan2_clear_load
  JMP do_scope_chan2_clear_load
  .jmp_do_scope_chan2_render
  JMP do_scope_chan2_render
  .jmp_do_scope_chan3_clear_load
  JMP do_scope_chan3_clear_load
  .jmp_do_scope_chan3_render
  JMP do_scope_chan3_render
  .jmp_do_scope_inc
  JMP do_scope_inc
  .jmp_do_channel1_check_wrap
  JMP do_channel1_check_wrap
  .jmp_do_channel2_check_wrap
  JMP do_channel2_check_wrap
  .jmp_do_vsync_check
  JMP do_vsync_check
  .jmp_do_song_tick
  JMP do_song_tick
  .jmp_do_load_song_byte
  JMP do_load_song_byte
  .jmp_do_song_byte_decode
  JMP do_song_byte_decode
  .jmp_do_song_byte_decode_2
  JMP do_song_byte_decode_2
  .jmp_do_song_byte_decode_3
  JMP do_song_byte_decode_3
  .jmp_do_song_byte_decode_4
  JMP do_song_byte_decode_4
  .jmp_do_commit_channel
  JMP do_commit_channel
  .jmp_do_check_row_skip
  JMP do_check_row_skip

.zero_page_play_end

zero_page_play_length = (zero_page_play_end - zero_page_play_start)

ORG &1900
GUARD &2000

.binary_start

\\ The jumps in this block are cycle counted and must not cross pages.
CLEAR P%, &8000
ALIGN &100
GUARD (P% + &FF)

  .do_channel1_check_wrap
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_channel2_check_wrap)
  STA main_loop_jump + 1
  LDY var_channel1_instr
  LDA channel1_load + 2
  CMP addr_sample_ends,Y
  BNE no_channel_wrap
  LDA addr_sample_wraps,Y
  BEQ no_channel1_sample_loop
  STA channel1_load + 2
  LDA channel1_load + 1
  \\ Warning: carry set. Must be catered for in lookup table.
  ADC addr_sample_wraps_fine,Y
  STA channel1_load + 1
  \\ 125 cycles (3 remain)
  JMP main_loop
  .no_channel_wrap
  \\ 107 cycles (21 remain)
  JMP jmp_main_loop_21
  .no_channel1_sample_loop
  \\ 113 cycles (15 remain)
  LDA #HI(addr_silence)
  STA channel1_load + 2
  LDA #&F
  STA var_channel1_instr
  CLC
  JMP main_loop

  .do_channel2_check_wrap
  \\ 89 cycles (39 remain)
  LDA #LO(do_channel3_check_wrap)
  STA main_loop_jump + 1
  LDY var_channel2_instr
  LDA channel2_load + 2
  CMP addr_sample_ends,Y
  BNE no_channel_wrap
  LDA addr_sample_wraps,Y
  BEQ no_channel2_sample_loop
  STA channel2_load + 2
  LDA channel2_load + 1
  \\ Warning: carry set. Must be catered for in lookup table.
  ADC addr_sample_wraps_fine,Y
  STA channel2_load + 1
  \\ 125 cycles (3 remain)
  JMP main_loop
  .no_channel2_sample_loop
  \\ 113 cycles (15 remain)
  LDA #HI(addr_silence)
  STA channel2_load + 2
  LDA #&F
  STA var_channel2_instr
  CLC
  JMP main_loop

  .do_vsync_check
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  \\ 94 cycles (34 remain)
  LDA #2
  BIT &FE4D
  BEQ no_vsync_hit
  STA &FE4D
  LDA #LO(jmp_do_song_tick)
  STA load_next_do_after_channel3_check + 1
  \\ 115 cycles (13 remain)
  JMP jmp_main_loop_13
  .no_vsync_hit
  \\ 105 cycles (23 remain)
  JMP jmp_main_loop_23

  .do_song_tick
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  \\ 94 cycles (34 remain)
  DEC var_song_tick_counter
  BNE no_song_tick_hit
  .self_modify_song_ticks_reload
  LDA #0
  STA var_song_tick_counter
  \\ 106 cycles (22 remain)
  DEC var_song_row_skip_counter
  BNE no_row_skip_hit
  LDA #LO(jmp_do_load_song_byte)
  STA load_next_do_after_channel3_check + 1
  \\ 118 cycles (10 remain)
  JMP jmp_main_loop_10
  .no_song_tick_hit
  \\ 102 cycles (26 remain)
  LDA #LO(jmp_do_vsync_check)
  STA load_next_do_after_channel3_check + 1
  \\ 107 cycles (21 remain)
  JMP jmp_main_loop_21
  .no_row_skip_hit
  \\ 114 cycles (14 remain)
  LDA #LO(jmp_do_vsync_check)
  STA load_next_do_after_channel3_check + 1
  \\ 119 cycles (9 remain)
  JMP jmp_main_loop_9

  .do_load_song_byte
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  LDA #LO(jmp_do_song_byte_decode)
  STA load_next_do_after_channel3_check + 1
  LDY #0
  LDA (var_song_lo),Y
  STA var_next_byte
  INC var_song_lo
  BNE no_song_ptr_hi
  INC var_song_hi
  \\ 121 cycles (7 remain)
  NOP:NOP
  JMP main_loop
  .no_song_ptr_hi
  \\ 117 cycles (11 remain)
  JMP jmp_main_loop_11

  .do_song_byte_decode
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  LDY var_next_byte
  BMI special_command
  \\ 99 cycles (29 remain)
  LDA #LO(jmp_do_song_byte_decode_2)
  STA load_next_do_after_channel3_check + 1
  \\ 104 cycles (24 remain)
  LDA addr_lookup_note,Y
  STA self_modify_advance_hi_value + 1
  \\ 112 cycles (16 remain)
  LDA addr_lookup_instr,Y
  STA self_modify_instr_value + 1
  \\ 120 cycles (8 remain)
  JMP jmp_main_loop_8
  .special_command
  LDA #LO(jmp_do_load_song_byte)
  STA load_next_do_after_channel3_check + 1
  \\ 105 cycles (23 remain)
  .self_modify_song_restart
  LDA #0
  STA var_song_hi
  LDA #0
  STA var_song_lo
  \\ 115 cycles (13 remain)
  JMP jmp_main_loop_13

  .do_check_row_skip
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  LDY var_next_byte
  LDA addr_lookup_row_skip,Y
  STA var_song_row_skip_counter
  BNE row_skip
  \\ 106 cycles (22 remain)
  LDA #LO(jmp_do_load_song_byte)
  STA load_next_do_after_channel3_check + 1
  \\ 111 cycles (17 remain)
  JMP jmp_main_loop_17
  .row_skip
  \\ 107 cycles (21 remain)
  LDA #LO(jmp_do_vsync_check)
  STA load_next_do_after_channel3_check + 1
  \\ 112 cycles (16 remain)
  JMP jmp_main_loop_16

\\ The jumps in this block are cycle counted and must not cross pages.
CLEAR P%, &8000
ALIGN &100
GUARD (P% + &FF)

  .do_scope_inc
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_channel1_check_wrap)
  STA main_loop_jump + 1
  LDY var_scope_chan1_ptr_lo
  CPY #&4F
  BEQ scope_wrap
  INC var_scope_chan1_ptr_lo
  INC var_scope_chan2_ptr_lo
  INC var_scope_chan3_ptr_lo
  \\ 116 cycles (12 remain)
  JMP jmp_main_loop_12
  .scope_wrap
  LDA #&29
  STA var_scope_chan1_ptr_lo
  LDA #&19
  STA var_scope_chan2_ptr_lo
  LDA #&09
  STA var_scope_chan3_ptr_lo
  \\ 117 cycles (11 remain)
  JMP jmp_main_loop_11

CLEAR P%, &8000

  \\ Players blocks that contain no branches, so don't need to worry about page
  \\ crossings.

  .do_scope_chan1_clear_load
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_render)
  STA main_loop_jump + 1
  \\ 94 cycles (34 remain)
  LDY var_scope_chan1_ptr_lo
  STY scope_chan1_y_store + 1
  LDA addr_scope_chan1,Y
  TAY
  LDA #&20
  STA (var_scope_chan1_ptr_lo),Y
  \\ 115 cycles (13 remain)
  LDY #0
  LDA (channel1_load + 1),Y
  STA var_scope_value
  \\ 125 cycles (3 remain)
  JMP main_loop

  .do_scope_chan1_render
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan2_clear_load)
  STA main_loop_jump + 1
  \\ 94 cycles (34 remain)
  STX var_temp_x
  LDX var_scope_value
  LDY addr_scope_y_table,X
  LDA addr_scope_glyph_table,X
  STA (var_scope_chan1_ptr_lo),Y
  TYA
  \\ Self-modified by previous clear / load.
  .scope_chan1_y_store
  STA addr_scope_chan1
  LDX var_temp_x
  \\ 123 cycles (5 remain)
  NOP
  JMP main_loop

  .do_scope_chan2_clear_load
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan2_render)
  STA main_loop_jump + 1
  \\ 94 cycles (34 remain)
  LDY var_scope_chan2_ptr_lo
  STY scope_chan2_y_store + 1
  LDA addr_scope_chan2,Y
  TAY
  LDA #&20
  STA (var_scope_chan2_ptr_lo),Y
  \\ 115 cycles (13 remain)
  LDY #0
  LDA (channel2_load + 1),Y
  STA var_scope_value
  \\ 125 cycles (3 remain)
  JMP main_loop

  .do_scope_chan2_render
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan3_clear_load)
  STA main_loop_jump + 1
  \\ 94 cycles (34 remain)
  STX var_temp_x
  LDX var_scope_value
  LDY addr_scope_y_table,X
  LDA addr_scope_glyph_table,X
  STA (var_scope_chan2_ptr_lo),Y
  TYA
  \\ Self-modified by previous clear / load.
  .scope_chan2_y_store
  STA addr_scope_chan2
  LDX var_temp_x
  \\ 123 cycles (5 remain)
  NOP
  JMP main_loop

  .do_scope_chan3_clear_load
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan3_render)
  STA main_loop_jump + 1
  \\ 94 cycles (34 remain)
  LDY var_scope_chan3_ptr_lo
  STY scope_chan3_y_store + 1
  LDA addr_scope_chan3,Y
  TAY
  LDA #&20
  STA (var_scope_chan3_ptr_lo),Y
  \\ 115 cycles (13 remain)
  LDY #0
  LDA (channel3_load + 1),Y
  STA var_scope_value
  \\ 125 cycles (3 remain)
  JMP main_loop

  .do_scope_chan3_render
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_inc)
  STA main_loop_jump + 1
  \\ 94 cycles (34 remain)
  STX var_temp_x
  LDX var_scope_value
  LDY addr_scope_y_table,X
  LDA addr_scope_glyph_table,X
  STA (var_scope_chan3_ptr_lo),Y
  TYA
  \\ Self-modified by previous clear / load.
  .scope_chan3_y_store
  STA addr_scope_chan3
  LDX var_temp_x
  \\ 123 cycles (5 remain)
  NOP
  JMP main_loop

  .do_song_byte_decode_2
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  LDA #LO(jmp_do_song_byte_decode_3)
  STA load_next_do_after_channel3_check + 1
  \\ 99 cycles (29 remain)
  LDY self_modify_instr_value + 1
  LDA addr_sample_starts,Y
  STA self_modify_load_hi_value + 1
  LDA addr_sample_starts_fine,Y
  STA self_modify_load_lo_value + 1
  \\ 119 cycles (9 remain)
  JMP jmp_main_loop_9

  .do_song_byte_decode_3
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  LDA #LO(jmp_do_song_byte_decode_4)
  STA load_next_do_after_channel3_check + 1
  \\ 99 cycles (29 remain)
  LDY var_next_byte
  LDA addr_lookup_channel,Y
  TAY
  LDA table_channel_code_advance_hi,Y
  STA self_modify_advance_hi_store + 1
  STY self_modify_decode_4_channel + 1
  \\ 120 cycles (8 remain)
  JMP jmp_main_loop_8

  .do_song_byte_decode_4
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  LDA #LO(jmp_do_commit_channel)
  STA load_next_do_after_channel3_check + 1
  \\ 99 cycles (29 remain)
  .self_modify_decode_4_channel
  LDY #00
  LDA table_channel_code_load_hi,Y
  STA self_modify_load_hi_store + 1
  LDA table_channel_code_load_lo,Y
  STA self_modify_load_lo_store + 1
  LDA table_channel_var_instr,Y
  STA self_modify_instr_store + 1
  \\ 125 cycles (3 remain)
  JMP main_loop

  .do_commit_channel
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  LDA #LO(jmp_do_check_row_skip)
  STA load_next_do_after_channel3_check + 1
  \\ 99 cycles (29 remain)
  .self_modify_advance_hi_value
  LDA #00
  .self_modify_advance_hi_store
  STA &00
  .self_modify_load_hi_value
  LDA #00
  .self_modify_load_hi_store
  STA &00
  .self_modify_load_lo_value
  LDA #00
  .self_modify_load_lo_store
  STA &00
  .self_modify_instr_value
  LDA #00
  .self_modify_instr_store
  STA &00
  \\ 119 cycles (9 remain)
  JMP jmp_main_loop_9


  .jmp_main_loop_24
  NOP
  .jmp_main_loop_22
  NOP
  .jmp_main_loop_20
  NOP
  .jmp_main_loop_18
  NOP
  .jmp_main_loop_16
  NOP
  .jmp_main_loop_14
  NOP
  .jmp_main_loop_12
  NOP
  .jmp_main_loop_10
  NOP
  .jmp_main_loop_8
  NOP
  .jmp_main_loop_6
  JMP main_loop

  .jmp_main_loop_23
  NOP
  .jmp_main_loop_21
  NOP
  .jmp_main_loop_19
  NOP
  .jmp_main_loop_17
  NOP
  .jmp_main_loop_15
  NOP
  .jmp_main_loop_13
  NOP
  .jmp_main_loop_11
  NOP
  .jmp_main_loop_9
  LDA &00
  JMP main_loop

  .scope_y_table
  EQUB 0, 0, 0, 0, 40, 40, 40, 80, 80, 80, 120, 120, 120, 160, 160, 160
  .scope_glyph_table
  EQUB &23, &23, &2C, &70, &23, &2C, &70, &23, &2C, &70, &23, &2C, &70, &23, &2C, &70
  .table_channel_code_advance_hi
  EQUB channel1_advance + 2, channel2_advance + 2, channel3_advance + 2
  .table_channel_code_load_hi
  EQUB channel1_load + 2, channel2_load + 2, channel3_load + 2
  .table_channel_code_load_lo
  EQUB channel1_load + 1, channel2_load + 1, channel3_load + 1
  .table_channel_var_instr
  EQUB var_channel1_instr, var_channel2_instr, var_channel3_instr

\\ The entry point.
.binary_exec
  SEI

{
  \\ Read and fully use any input parameters from the zero page.
  \\ They will be trashed below in the relocation loop.

{
  \\ Input parameter: channel periods.
  LDA addr_input_period_1
  AND #&0F
  ORA #&80
  STA self_modify_channel1_period + 1
  LDA addr_input_period_2
  AND #&0F
  ORA #&A0
  STA self_modify_channel2_period + 1
  LDA addr_input_period_3
  AND #&0F
  ORA #&C0
  STA self_modify_channel3_period + 1
}

{
  \\ Input parameter: advance tables base.
  LDA addr_input_advance_tables_dst
  STA self_modify_init_advance_tables + 1
  STA self_modify_store_advance_table_dst + 2
  LDA addr_input_advance_tables_src
  STA self_modify_load_advance_table_src + 2

  \\ Unpack advance tables.
  \\ They come in packed, which helps fit everything in memory. We might
  \\ unpack into the DFS workspace now that everything is loaded.
  .loop_table
  LDX #64
  .loop_note
  .self_modify_load_advance_table_src
  LDA &FF00
  STA var_temp_x
  INC self_modify_load_advance_table_src + 1
  BNE no_advance_table_src_wrap
  INC self_modify_load_advance_table_src + 2
  .no_advance_table_src_wrap
  LDY #4
  .loop_unpack
  LDA var_temp_x
  AND #3
  .self_modify_store_advance_table_dst
  STA &FF00
  INC self_modify_store_advance_table_dst + 1
  BNE no_advance_table_dst_wrap
  INC self_modify_store_advance_table_dst + 2
  .no_advance_table_dst_wrap
  LDA var_temp_x
  LSR A
  LSR A
  STA var_temp_x
  DEY
  BNE loop_unpack
  DEX
  BNE loop_note
  DEC addr_input_advance_tables_len
  BNE loop_table

  \\ Update the values in the note lookup array to be based at the address of
  \\ the advance tables.
  CLC
  LDX #63
  .loop_note_rebase
  LDA addr_lookup_note,X
  ADC addr_input_advance_tables_dst
  STA addr_lookup_note,X
  DEX
  BPL loop_note_rebase
}

{
  \\ Input parameter: song start and end.
  LDA #0
  STA var_song_lo
  LDA addr_input_song_start
  STA var_song_hi
  STA self_modify_song_restart + 1
}

{
  \\ Input parameter: song speed.
  LDA addr_input_song_speed
  STA self_modify_song_ticks_reload + 1
}

  \\ Relocate the player code into the zero and stack pages.
  LDA #LO(zero_page_play_copy)
  STA load + 1
  LDA #HI(zero_page_play_copy)
  STA load + 2
  LDA #LO(zero_page_play_start)
  STA store + 1
  LDA #HI(zero_page_play_start)
  STA store + 2
  LDY #LO(zero_page_play_length)
  LDX #HI(zero_page_play_length)
  .loop
  .load
  LDA &FFFF
  .store
  STA &FFFF
  INC load + 1
  BNE no_load_wrap
  INC load + 2
  .no_load_wrap
  INC store + 1
  BNE no_store_wrap
  INC store + 2
  .no_store_wrap
  DEY
  BNE loop
  DEX
  BPL loop
}

{
  \\ Create the silence page.
  LDA #&FF
  LDX #0
  .loop
  STA addr_silence,X
  INX
  BNE loop
  \\ Extend by some bytes to cater for the out-of-band wrapping.
  LDX #0
  LDY #24
  .loop2
  STA addr_silence + &100,X
  INX
  DEY
  BNE loop2
}

{
  \\ Set up the silent sample metadata.
  LDA #HI(addr_silence)
  STA addr_sample_starts + &F
  STA addr_sample_wraps + &F
  LDA #0
  STA addr_sample_wraps_fine + &F
  LDA #HI(addr_silence) + 1
  STA addr_sample_ends + &F
}

{
  \\ Initialize the oscilloscope state.
  LDA #0
  LDX #0
  .loop
  STA addr_scope_chan1,X
  STA addr_scope_chan2,X
  STA addr_scope_chan3,X
  INX
  BNE loop
}

{
  \\ Calculate the lookup tables for scope rendering.
  LDX #0
  .loop
  TXA
  AND #&0F
  TAY
  LDA scope_y_table,Y
  STA addr_scope_y_table,X
  LDA scope_glyph_table,Y
  STA addr_scope_glyph_table,X
  INX
  BNE loop
  \\ &FF is special and used for the silence page -- make it central.
  LDX #&FF
  LDY #8
  LDA scope_y_table,Y
  STA addr_scope_y_table,X
  LDA scope_glyph_table,Y
  STA addr_scope_glyph_table,X
}

  \\ Set up the MODE 7 line preambles (color, gfx) for scope rendering.
  \\ Red graphics.
  LDA #&91
  STA &7C28 + (0 * 40)
  STA &7C28 + (1 * 40)
  STA &7C28 + (2 * 40)
  STA &7C28 + (3 * 40)
  STA &7C28 + (4 * 40)
  \\ Yellow graphics.
  LDA #&93
  STA &7D18 + (0 * 40)
  STA &7D18 + (1 * 40)
  STA &7D18 + (2 * 40)
  STA &7D18 + (3 * 40)
  STA &7D18 + (4 * 40)
  \\ Magenta graphics.
  LDA #&95
  STA &7E08 + (0 * 40)
  STA &7E08 + (1 * 40)
  STA &7E08 + (2 * 40)
  STA &7E08 + (3 * 40)
  STA &7E08 + (4 * 40)

  \\ Point the channel addresses at the silence page.
  LDA #0
  STA channel1_load + 1
  STA channel2_load + 1
  STA channel3_load + 1
  LDA #HI(addr_silence)
  STA channel1_load + 2
  STA channel2_load + 2
  STA channel3_load + 2

  \\ Set initial instruments to the silent sample.
  LDA #&0F
  STA var_channel1_instr
  STA var_channel2_instr
  STA var_channel3_instr

  \\ Point the tables advances at the first advance table.
  LDA #0
  STA channel1_advance + 1
  STA channel2_advance + 1
  STA channel3_advance + 1
  .self_modify_init_advance_tables
  LDA #0
  STA channel1_advance + 2
  STA channel2_advance + 2
  STA channel3_advance + 2

  \\ Setup MODE7 scope pointers.
  \\ Row 1
  LDA #&7C
  STA var_scope_chan1_ptr_hi
  LDA #&29
  STA var_scope_chan1_ptr_lo
  \\ Row 7.
  LDA #&7D
  STA var_scope_chan2_ptr_hi
  LDA #&19
  STA var_scope_chan2_ptr_lo
  \\ Row 13.
  LDA #&7E
  STA var_scope_chan3_ptr_hi
  LDA #&09
  STA var_scope_chan3_ptr_lo

  \\ Set song tick and line skip counters to fire on first vsync.
  LDA #1
  STA var_song_tick_counter
  STA var_song_row_skip_counter

  JSR setup_hardware

  \\ Consistent register state.
  \\ X is used as the index to the advances tables.
  LDX #&FF
  TXS
  LDX #0
  LDY #0

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

  LDA &00
  JMP play_entry

  .play_entry
  \\ At write gate +3us. Write targets are +10us and then every +16us after.
  \\ The play loop writes the bus at +8us. It took 3us to jump here. There's
  \\ another 3us to jump out of here.
  \\ Need to wait 26 - 8 - 3 - 3 = 12us of NOPs, or 24 cycles.
  JSR jsr_wait_12_cycles
  JSR jsr_wait_12_cycles
  LDA &00
  JMP main_loop

  .setup_hardware
  \\ System VIA port A to output.
  LDA #&FF
  STA &FE43
  \\ Keyboard to auto-scan mode.
  LDA #&0B
  STA &FE40

  \\ Channels 1, 2, 3 to period 1, 2, 3.
  .self_modify_channel1_period
  LDA #0
  JSR sound_write
  LDA #0
  JSR sound_write
  .self_modify_channel2_period
  LDA #0
  JSR sound_write
  LDA #0
  JSR sound_write
  .self_modify_channel3_period
  LDA #0
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

.zero_page_play_copy
  SKIP zero_page_play_length

.binary_end

COPYBLOCK zero_page_play_start, zero_page_play_end, zero_page_play_copy

SAVE "PLAY", binary_start, binary_end, binary_exec
PUTFILE "adv_tables.out", "ADVTAB", 0
PUTFILE "lookup_tables.out", "LOOKTAB", 0
PUTFILE "conv.out", "SONG", 0
INCLUDE SONG_DETAILS_FILE
