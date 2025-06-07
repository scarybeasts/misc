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
addr_scope_chan1 = &200
addr_scope_chan2 = &300
addr_scope_chan3 = &400
addr_scope_y_table = &500
addr_scope_glyph_table = &600
\\ Spills 24 bytes past 1 page.
addr_silence = &700

\\ Player variables from &00 - &1F.
\\ Avoid colliding with input parameter space at &70.
ORG &00
GUARD &1F

.var_song_tick_counter SKIP 1
.var_song_lo SKIP 1
.var_song_hi SKIP 1
.var_next_byte SKIP 1
.var_next_instrument SKIP 1
.var_scope_chan1_ptr_lo SKIP 1
.var_scope_chan1_ptr_hi SKIP 1
.var_scope_chan2_ptr_lo SKIP 1
.var_scope_chan2_ptr_hi SKIP 1
.var_scope_chan3_ptr_lo SKIP 1
.var_scope_chan3_ptr_hi SKIP 1
.var_scope_value SKIP 1
.var_temp_x SKIP 1
.var_channel1_instrument SKIP 1
.var_channel2_instrument SKIP 1
.var_channel3_instrument SKIP 1

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
  .do_channel3_check_wrap
  \\ 86 cycles (42 remain)
  .load_next_do_after_channel3_check
  LDA #LO(jmp_do_vsync_check)
  STA main_loop_jump + 1
  LDY var_channel3_instrument
  LDA channel3_load + 2
  CMP addr_sample_ends,Y
  BNE no_channel3_wrap
  LDA addr_sample_wraps,Y
  BEQ no_channel3_sample_loop
  STA channel3_load + 2
  LDA channel3_load + 1
  \\ The CMP above will have set the carry flag.
  CLC
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
  STA var_channel3_instrument
  JMP jmp_main_loop_8

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
  .jmp_do_load_channel1
  JMP do_load_channel1
  .jmp_do_exec_channel1_note
  JMP do_exec_channel1_note
  .jmp_do_exec_channel1_instrument
  JMP do_exec_channel1_instrument
  .jmp_do_load_channel2
  JMP do_load_channel2
  .jmp_do_exec_channel2_note
  JMP do_exec_channel2_note
  .jmp_do_exec_channel2_instrument
  JMP do_exec_channel2_instrument
  .jmp_do_load_channel3
  JMP do_load_channel3
  .jmp_do_exec_channel3_note
  JMP do_exec_channel3_note
  .jmp_do_exec_channel3_instrument
  JMP do_exec_channel3_instrument
  .jmp_do_increment_song_pointer
  JMP do_increment_song_pointer

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
  LDY var_channel1_instrument
  LDA channel1_load + 2
  CMP addr_sample_ends,Y
  BNE no_channel_wrap
  LDA addr_sample_wraps,Y
  BEQ no_channel1_sample_loop
  STA channel1_load + 2
  LDA channel1_load + 1
  \\ The CMP above will have set the carry flag.
  CLC
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
  STA var_channel1_instrument
  NOP
  JMP main_loop

  .do_channel2_check_wrap
  \\ 89 cycles (39 remain)
  LDA #LO(do_channel3_check_wrap)
  STA main_loop_jump + 1
  LDY var_channel2_instrument
  LDA channel2_load + 2
  CMP addr_sample_ends,Y
  BNE no_channel_wrap
  LDA addr_sample_wraps,Y
  BEQ no_channel2_sample_loop
  STA channel2_load + 2
  LDA channel2_load + 1
  \\ The CMP above will have set the carry flag.
  CLC
  ADC addr_sample_wraps_fine,Y
  STA channel2_load + 1
  \\ 125 cycles (3 remain)
  JMP main_loop
  .no_channel2_sample_loop
  \\ 113 cycles (15 remain)
  LDA #HI(addr_silence)
  STA channel2_load + 2
  LDA #&F
  STA var_channel2_instrument
  NOP
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
  LDA #LO(jmp_do_load_channel1)
  STA load_next_do_after_channel3_check + 1
  .self_modify_song_ticks_reload
  LDA #0
  STA var_song_tick_counter
  \\ 111 cycles (17 remain)
  JMP jmp_main_loop_17
  .no_song_tick_hit
  LDA #LO(jmp_do_vsync_check)
  STA load_next_do_after_channel3_check + 1
  \\ 107 cycles (21 remain)
  JMP jmp_main_loop_21

  .do_load_channel1
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  LDY #0
  LDA (var_song_lo),Y
  BNE has_channel1_note
  \\ 103 cycles (25 remain)
  LDA #LO(jmp_do_load_channel2)
  STA load_next_do_after_channel3_check + 1
  JMP jmp_main_loop_20
  .has_channel1_note
  \\ 104 cycles (24 remain)
  STA var_next_byte
  LSR A:LSR A:LSR A:LSR A:LSR A
  STA var_next_instrument
  LDA #LO(jmp_do_exec_channel1_note)
  STA load_next_do_after_channel3_check + 1
  \\ 125 cycles (3 remain)
  JMP main_loop

  .do_exec_channel1_note
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  LDA #LO(jmp_do_exec_channel1_instrument)
  STA load_next_do_after_channel3_check + 1
  \\ 99 cycles (29 remain)
  LDA var_next_byte
  AND #&1F
  \\ Carry should already be cleared on entry.
  CLC
  .self_modify_advance_table_channel1
  ADC #0
  STA channel1_advance + 2
  \\ 111 cycles (17 remain)
  JMP jmp_main_loop_17

  .do_exec_channel1_instrument
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  LDA #LO(jmp_do_load_channel2)
  STA load_next_do_after_channel3_check + 1
  \\ 99 cycles (29 remain)
  LDY var_next_instrument
  STY var_channel1_instrument
  LDA addr_sample_starts,Y
  STA channel1_load + 2
  LDA #0
  STA channel1_load + 1
  \\ 117 cycles (11 remain)
  JMP jmp_main_loop_11

\\ The jumps in this block are cycle counted and must not cross pages.
CLEAR P%, &8000
ALIGN &100
GUARD (P% + &FF)

  .do_load_channel2
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  LDY #1
  LDA (var_song_lo),Y
  BNE has_channel2_note
  \\ 103 cycles (25 remain)
  LDA #LO(jmp_do_load_channel3)
  STA load_next_do_after_channel3_check + 1
  JMP jmp_main_loop_20
  .has_channel2_note
  \\ 104 cycles (24 remain)
  STA var_next_byte
  LSR A:LSR A:LSR A:LSR A:LSR A
  STA var_next_instrument
  LDA #LO(jmp_do_exec_channel2_note)
  STA load_next_do_after_channel3_check + 1
  \\ 125 cycles (3 remain)
  JMP main_loop

  .do_exec_channel2_note
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  LDA #LO(jmp_do_exec_channel2_instrument)
  STA load_next_do_after_channel3_check + 1
  \\ 99 cycles (29 remain)
  LDA var_next_byte
  AND #&1F
  \\ Carry should already be cleared on entry.
  CLC
  .self_modify_advance_table_channel2
  ADC #0
  STA channel2_advance + 2
  \\ 111 cycles (17 remain)
  JMP jmp_main_loop_17

  .do_exec_channel2_instrument
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  LDA #LO(jmp_do_load_channel3)
  STA load_next_do_after_channel3_check + 1
  \\ 99 cycles (29 remain)
  LDY var_next_instrument
  STY var_channel2_instrument
  LDA addr_sample_starts,Y
  STA channel2_load + 2
  LDA #0
  STA channel2_load + 1
  \\ 117 cycles (11 remain)
  JMP jmp_main_loop_11

  .do_load_channel3
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  LDY #2
  LDA (var_song_lo),Y
  BNE has_channel3_note
  \\ 103 cycles (25 remain)
  LDA #LO(jmp_do_increment_song_pointer)
  STA load_next_do_after_channel3_check + 1
  JMP jmp_main_loop_20
  .has_channel3_note
  \\ 104 cycles (24 remain)
  STA var_next_byte
  LSR A:LSR A:LSR A:LSR A:LSR A
  STA var_next_instrument
  LDA #LO(jmp_do_exec_channel3_note)
  STA load_next_do_after_channel3_check + 1
  \\ 125 cycles (3 remain)
  JMP main_loop

  .do_exec_channel3_note
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  LDA #LO(jmp_do_exec_channel3_instrument)
  STA load_next_do_after_channel3_check + 1
  \\ 99 cycles (29 remain)
  LDA var_next_byte
  AND #&1F
  \\ Carry should already be cleared on entry.
  CLC
  .self_modify_advance_table_channel3
  ADC #0
  STA channel3_advance + 2
  \\ 111 cycles (17 remain)
  JMP jmp_main_loop_17

  .do_exec_channel3_instrument
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  LDA #LO(jmp_do_increment_song_pointer)
  STA load_next_do_after_channel3_check + 1
  \\ 99 cycles (29 remain)
  LDY var_next_instrument
  STY var_channel3_instrument
  LDA addr_sample_starts,Y
  STA channel3_load + 2
  LDA #0
  STA channel3_load + 1
  \\ 117 cycles (11 remain)
  JMP jmp_main_loop_11

  .do_increment_song_pointer
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  LDA #LO(jmp_do_vsync_check)
  STA load_next_do_after_channel3_check + 1
  \\ 99 cycles (29 remain)
  LDA var_song_lo
  \\ Carry should already be cleared on entry.
  ADC #4
  STA var_song_lo
  \\ 107 cycles (21 remain)
  BCC no_song_lo_hit
  LDY var_song_hi
  INY
  .self_modify_song_end_check
  CPY #0
  BNE no_song_hi_hit
  .self_modify_song_restart
  LDA #0
  STA var_song_hi
  \\ 123 cycles (5 remain)
  NOP
  JMP main_loop
  .no_song_lo_hit
  \\ 108 cycles (20 remain)
  JMP jmp_main_loop_20
  .no_song_hi_hit
  \\ 121 cycles (7 remain)
  \\ Force STY abs, 4 cycles, for the zero page write.
  EQUB &8C, var_song_hi, &00
  JMP main_loop

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

\\ The jumps in this block are cycle counted and must not cross pages.
CLEAR P%, &8000
ALIGN &100
GUARD (P% + &FF)

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

  .jmp_main_loop_24
  NOP
  NOP
  .jmp_main_loop_20
  NOP
  NOP
  NOP
  NOP
  .jmp_main_loop_12
  NOP
  NOP
  .jmp_main_loop_8
  NOP
  .jmp_main_loop_6
  JMP main_loop

  .jmp_main_loop_23
  NOP
  .jmp_main_loop_21
  NOP
  NOP
  .jmp_main_loop_17
  NOP
  NOP
  .jmp_main_loop_13
  NOP
  .jmp_main_loop_11
  NOP
  LDA &00
  JMP main_loop

  .scope_y_table
  EQUB 0, 0, 0, 0, 40, 40, 40, 80, 80, 80, 120, 120, 120, 160, 160, 160
  .scope_glyph_table
  EQUB &23, &23, &2C, &70, &23, &2C, &70, &23, &2C, &70, &23, &2C, &70, &23, &2C, &70

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
  SEC
  SBC #1
  STA self_modify_advance_table_channel1 + 1
  STA self_modify_advance_table_channel2 + 1
  STA self_modify_advance_table_channel3 + 1
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
}

{
  \\ Input parameter: song start and end.
  LDA #0
  STA var_song_lo
  LDA addr_input_song_start
  STA var_song_hi
  STA self_modify_song_restart + 1
  LDA addr_input_song_end
  STA self_modify_song_end_check + 1
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
  STA var_channel1_instrument
  STA var_channel2_instrument
  STA var_channel3_instrument

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

  \\ Set song tick counter to fire on first vsync.
  LDA #1
  STA var_song_tick_counter

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
PUTFILE "tables.out", "ADVTAB", 0
PUTFILE "conv.out", "SONG", 0
INCLUDE SONG_DETAILS_FILE
