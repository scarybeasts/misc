addr_silence = &900
addr_song_metadata = &A10
addr_sample_starts = &A20
addr_sample_ends = &A30
addr_advance_tables = &5600
addr_song = &3100
addr_scope_chan1 = &E00
addr_scope_chan2 = &F00
addr_scope_chan3 = &1000
addr_scope_y_table = &1100
addr_scope_glyph_table = &1200

ORG &00
GUARD &1F

.var_timer_lo SKIP 1
.var_timer_hi SKIP 1
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

\\ Calibrated for default BPM, song speed 7.
\\ 64us per loop, 50Hz, 10 loops per decrement.
\\ (1000000.0 / 64 / 50 / 10) * 7
timer_reload = 219

ORG &30
GUARD &FF

.zero_page_play_start

\\ The zero-page play loop at &30.
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

  .do_channel1_check_wrap
  LDA channel1_load + 2
  .channel1_compare_max
  CMP #&FF
  BNE no_channel1_wrap
  .channel1_sample_reload
  LDA #&FF
  STA channel1_load + 2
  .channel1_sample_reload_max
  LDA #&FF
  STA channel1_compare_max + 1
  .channel1_post_check_wrap
  \\ 103 cycles (25 remain)
  .channel2_check_wrap
  LDA channel2_load + 2
  .channel2_compare_max
  CMP #&FF
  BNE no_channel2_wrap
  .channel2_sample_reload
  LDA #&FF
  STA channel2_load + 2
  .channel2_sample_reload_max
  LDA #&FF
  STA channel2_compare_max + 1
  .channel2_post_check_wrap
  \\ 120 cycles (8 remain)
  LDA #LO(do_channel3_check_wrap)
  STA main_loop_jump + 1
  JMP main_loop
  .no_channel1_wrap
  NOP:NOP:NOP
  JMP channel1_post_check_wrap
  .no_channel2_wrap
  NOP:NOP:NOP
  JMP channel2_post_check_wrap

  .do_channel3_check_wrap
  LDA channel3_load + 2
  .channel3_compare_max
  CMP #&FF
  BNE no_channel3_wrap
  .channel3_sample_reload
  LDA #&FF
  STA channel3_load + 2
  .channel3_sample_reload_max
  LDA #&FF
  STA channel3_compare_max + 1
  .channel3_post_check_wrap
  \\ 103 cycles (25 remain)
  .load_next_do_after_channel3_check
  LDA #LO(jmp_do_timing_decrement)
  STA main_loop_jump + 1
  JSR jsr_wait_12_cycles
  NOP
  LDA &00
  JMP main_loop
  .no_channel3_wrap
  NOP:NOP:NOP
  JMP channel3_post_check_wrap

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
  .jmp_do_timing_decrement
  JMP do_timing_decrement
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

ORG &2000
GUARD &2FFF

\\ The entry point.
.binary_start
  SEI

{
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
  LDY #16
  .loop2
  STA addr_silence + &100,X
  INX
  DEY
  BNE loop2
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

  \\ Set up the sample end and reload points.
  LDA #HI(addr_silence) + 1
  STA channel1_compare_max + 1
  STA channel2_compare_max + 1
  STA channel3_compare_max + 1
  STA channel1_sample_reload_max + 1
  STA channel2_sample_reload_max + 1
  STA channel3_sample_reload_max + 1
  LDA #HI(addr_silence)
  STA channel1_sample_reload + 1
  STA channel2_sample_reload + 1
  STA channel3_sample_reload + 1

  \\ Point the tables advances at the first advance table.
  LDA #0
  STA channel1_advance + 1
  STA channel2_advance + 1
  STA channel3_advance + 1
  LDA #HI(addr_advance_tables)
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

  \\ Set timer to fire right away in order to load the first song line.
  LDA #0
  STA var_timer_hi
  LDA #1
  STA var_timer_lo

  \\ Initialize the song pointer.
  LDA #LO(addr_song)
  STA var_song_lo
  LDA #HI(addr_song)
  STA var_song_hi

  \\ Setup channel periods.
  LDA addr_song_metadata + 1
  AND #&0F
  ORA #&80
  STA channel1_period + 1
  LDA addr_song_metadata + 2
  AND #&0F
  ORA #&A0
  STA channel2_period + 1
  LDA addr_song_metadata + 3
  AND #&0F
  ORA #&C0
  STA channel3_period + 1

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

  .scope_y_table
  EQUB 0, 0, 0, 0, 40, 40, 40, 80, 80, 80, 120, 120, 120, 160, 160, 160
  .scope_glyph_table
  EQUB &23, &23, &2C, &70, &23, &2C, &70, &23, &2C, &70, &23, &2C, &70, &23, &2C, &70

  .setup_hardware
  \\ System VIA port A to output.
  LDA #&FF
  STA &FE43
  \\ Keyboard to auto-scan mode.
  LDA #&0B
  STA &FE40

  \\ Channels 1, 2, 3 to period 1, 2, 3.
  .channel1_period
  LDA #&81
  JSR sound_write
  LDA #0
  JSR sound_write
  .channel2_period
  LDA #&A2
  JSR sound_write
  LDA #0
  JSR sound_write
  .channel3_period
  LDA #&C3
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

  .play_entry
  \\ At write gate +3us. Write targets are +10us and then every +16us after.
  \\ The play loop writes the bus at +8us. It took 3us to jump here. There's
  \\ another 3us to jump out of here.
  \\ Need to wait 26 - 8 - 3 - 3 = 12us of NOPs, or 24 cycles.
  JSR jsr_wait_12_cycles
  JSR jsr_wait_12_cycles
  LDA &00
  JMP main_loop

\\ The jumps in this block are cycle counted and must not cross pages.
CLEAR P%, &8000
ALIGN &100
GUARD (P% + &FF)

  .do_timing_decrement
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  DEC var_timer_lo
  BNE no_timer_lo_zero
  DEC var_timer_hi
  BPL no_timer_hi_hit
  \\ 108 cycles (20 remain)
  LDA #LO(jmp_do_load_channel1)
  STA load_next_do_after_channel3_check + 1
  LDA #LO(timer_reload)
  STA var_timer_lo
  LDA #HI(timer_reload)
  STA var_timer_hi
  \\ 123 cycles (5 remain)
  NOP
  JMP main_loop
  .no_timer_lo_zero
  \\ 102 cycles (26 remain)
  JSR jsr_wait_12_cycles
  NOP:NOP:NOP:NOP
  LDA &00
  JMP main_loop
  .no_timer_hi_hit
  \\ 109 cycles (19 remain)
  JSR jsr_wait_12_cycles
  NOP:NOP
  JMP main_loop

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
  JSR jsr_wait_12_cycles
  NOP
  LDA &00
  JMP main_loop
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
  ADC #HI(addr_advance_tables) - 1
  STA channel1_advance + 2
  \\ 111 cycles (17 remain)
  JSR jsr_wait_12_cycles
  NOP
  JMP main_loop

  .do_exec_channel1_instrument
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  LDA #LO(jmp_do_load_channel2)
  STA load_next_do_after_channel3_check + 1
  \\ 99 cycles (29 remain)
  LDY var_next_instrument
  LDA addr_sample_starts,Y
  STA channel1_load + 2
  LDA #0
  STA channel1_load + 1
  LDA addr_sample_ends,Y
  STA channel1_compare_max + 1
  \\ 121 cycles (7 remain)
  NOP:NOP
  JMP main_loop

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
  JSR jsr_wait_12_cycles
  NOP
  LDA &00
  JMP main_loop
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
  ADC #HI(addr_advance_tables) - 1
  STA channel2_advance + 2
  \\ 111 cycles (17 remain)
  JSR jsr_wait_12_cycles
  NOP
  JMP main_loop

  .do_exec_channel2_instrument
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  LDA #LO(jmp_do_load_channel3)
  STA load_next_do_after_channel3_check + 1
  \\ 99 cycles (29 remain)
  LDY var_next_instrument
  LDA addr_sample_starts,Y
  STA channel2_load + 2
  LDA #0
  STA channel2_load + 1
  LDA addr_sample_ends,Y
  STA channel2_compare_max + 1
  \\ 121 cycles (7 remain)
  NOP:NOP
  JMP main_loop

\\ The jumps in this block are cycle counted and must not cross pages.
CLEAR P%, &8000
ALIGN &100
GUARD (P% + &FF)

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
  JSR jsr_wait_12_cycles
  NOP
  LDA &00
  JMP main_loop
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
  ADC #HI(addr_advance_tables) - 1
  STA channel3_advance + 2
  \\ 111 cycles (17 remain)
  JSR jsr_wait_12_cycles
  NOP
  JMP main_loop

  .do_exec_channel3_instrument
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  LDA #LO(jmp_do_increment_song_pointer)
  STA load_next_do_after_channel3_check + 1
  \\ 99 cycles (29 remain)
  LDY var_next_instrument
  LDA addr_sample_starts,Y
  STA channel3_load + 2
  LDA #0
  STA channel3_load + 1
  LDA addr_sample_ends,Y
  STA channel3_compare_max + 1
  \\ 121 cycles (7 remain)
  NOP:NOP
  JMP main_loop

  .do_increment_song_pointer
  \\ 89 cycles (39 remain)
  LDA #LO(jmp_do_scope_chan1_clear_load)
  STA main_loop_jump + 1
  LDA #LO(jmp_do_timing_decrement)
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
  CPY addr_song_metadata
  BNE no_song_hi_hit
  LDA #HI(addr_song)
  STA var_song_hi
  \\ 125 cycles (3 remain)
  JMP main_loop
  .no_song_lo_hit
  \\ 110 cycles (18 remain)
  JSR jsr_wait_12_cycles
  LDA &00
  JMP main_loop
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

\\ The jumps in this block are cycle counted and must not cross pages.
CLEAR P%, &8000
ALIGN &100
GUARD (P% + &FF)

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
  LDA #LO(do_channel1_check_wrap)
  STA main_loop_jump + 1
  LDY var_scope_chan1_ptr_lo
  CPY #&4F
  BEQ scope_wrap
  INC var_scope_chan1_ptr_lo
  INC var_scope_chan2_ptr_lo
  INC var_scope_chan3_ptr_lo
  \\ 116 cycles (12 remain)
  NOP:NOP:NOP
  LDA &00
  JMP main_loop
  .scope_wrap
  LDA #&29
  STA var_scope_chan1_ptr_lo
  LDA #&19
  STA var_scope_chan2_ptr_lo
  LDA #&09
  STA var_scope_chan3_ptr_lo
  \\ 117 cycles (11 remain)
  NOP:NOP:NOP:NOP
  JMP main_loop

CLEAR P%, &8000

.zero_page_play_copy
  SKIP zero_page_play_length

.binary_end

COPYBLOCK zero_page_play_start, zero_page_play_end, zero_page_play_copy

SAVE "PLAY", binary_start, binary_end
PUTFILE "tables.out", "ADVTAB", 0
PUTFILE "conv.out", "SONG", 0
INCLUDE SONG_DETAILS_FILE
