OSWRCH = &FFEE
OSBYTE = &FFF4
OSCLI = &FFF7

addr_tmp1 = &70
addr_tmp2 = &71
addr_tmp3 = &72
addr_tmp4 = &73

addr_lookup_tables = &BE00
addr_song_start = &BB00
addr_advance_tables_load = &1C00
addr_advance_tables = &0400
advance_tables_len = 24

addr_sample_starts = &120
addr_sample_ends = &130
addr_sample_wraps = &140
addr_sample_wraps_fine = &150
addr_sample_starts_fine = &160
addr_zero_page_backup = &2200
addr_D_page_backup = &2300
addr_lookup_channel = addr_lookup_tables
addr_lookup_note = addr_lookup_tables + &80
addr_lookup_instr = addr_lookup_tables + &100
addr_lookup_row_skip = addr_lookup_tables + &180
\\ Spills 64 bytes past 1 page.
addr_silence = &2400

\\ Player variables from &00 - &1F.
ORG &00
GUARD &20

.var_song_tick_counter SKIP 1
.var_song_row_skip_counter SKIP 1
.var_next_byte SKIP 1
.var_channel1_instr SKIP 1
.var_channel2_instr SKIP 1
.var_channel3_instr SKIP 1
.var_tmp SKIP 1
.var_palette_index SKIP 1
.var_palette_ptr SKIP 2
.var_vsync_palette_state SKIP 1
.var_palette_1 SKIP 2
.var_flash_index SKIP 1
.var_flash_frame_timer SKIP 1
.var_rng SKIP 1
.var_palette_list_base SKIP 1

ORG &40
GUARD &100

.zero_page_play_start

\\ The zero-page play loop at &40.
  .main_loop
  \\ 0 cycles
  .channel1_load
  LDY &FF00
  LDA channel1_load + 1
  \\ 5 cycles, shorter 2 cycle 1MHz write.
  STY &FE4F
  \\ 12 cycles (next slot 12+32 == 44 cycles)
  .channel1_advance
  ADC &FF00,X
  STA channel1_load + 1
  ROL self_modify_advance_carries + 1
  \\ 24 cycles

  .channel2_load
  LDA &FF00
  ORA #&20
  TAY
  LDA channel2_load + 1
  .channel2_advance
  ADC &FF00,X
  \\ 5 cycles, shorter 2 cycle 1MHz write.
  STY &FE4F
  \\ 44 cycles (next slot 44+32 == 76 cycles)
  STA channel2_load + 1
  ROL self_modify_advance_carries + 1
  \\ 52 cycles

  .channel3_load
  LDA &FF00
  ORA #&40
  TAY
  LDA channel3_load + 1
  .channel3_advance
  ADC &FF00,X
  \\ 4 cycle STA abs for alignment.
  EQUB &8D, channel3_load + 1, &00
  \\ 5 cycles, shorter 2 cycle 1MHz write.
  STY &FE4F
  \\ 76 cycles
  INX
  ROL self_modify_advance_carries + 1
  \\ 83 cycles

  \\ Uses the result of the ROL.
  BNE do_advance_carries

  .main_loop_jump
  JMP do_channel1_check_wrap

  \\ All jump targets: 88 cycles (40 remain)

  .do_advance_carries
  \\ 86 cycles
  .self_modify_advance_carries
  LDY #0
  LDA table_carries_1,Y
  ADC channel1_load + 2
  STA channel1_load + 2
  LDA table_carries_2,Y
  ADC channel2_load + 2
  STA channel2_load + 2
  LDA table_carries_3,Y
  ADC channel3_load + 2
  STA channel3_load + 2
  LDA #0
  STA self_modify_advance_carries + 1
  \\ 123 cycles
  NOP
  JMP main_loop

.zero_page_play_end

zero_page_play_length = (zero_page_play_end - zero_page_play_start)

ORG &2700
GUARD &2800

.binary_start

 \\ Put here first to align to $100.
.cwSteps
  \\ cw1
  EQUB &07,&17,&47,&57,&27,&37,&67,&77,&87,&97,&C7,&D7,&A3,&B3,&E3,&F3
  EQUB &07,&17,&47,&57,&27,&37,&67,&77,&83,&93,&C3,&D3,&A3,&B3,&E3,&F3
  EQUB &07,&17,&47,&57,&23,&33,&63,&73,&81,&91,&C1,&D1,&A3,&B3,&E3,&F3
  EQUB &03,&13,&43,&53,&21,&31,&61,&71,&80,&90,&C0,&D0,&A3,&B3,&E3,&F3
  \\ cw2
  EQUB &07,&17,&47,&57,&27,&37,&67,&77,&87,&97,&C7,&D7,&A3,&B3,&E3,&F3
  EQUB &07,&17,&47,&57,&27,&37,&67,&77,&86,&96,&C6,&D6,&A3,&B3,&E3,&F3
  EQUB &07,&17,&47,&57,&26,&36,&66,&76,&86,&96,&C6,&D6,&A3,&B3,&E3,&F3
  EQUB &06,&16,&46,&56,&26,&36,&66,&76,&84,&94,&C4,&D4,&A3,&B3,&E3,&F3
  \\ cw3
  EQUB &07,&17,&47,&57,&27,&37,&67,&77,&87,&97,&C7,&D7,&A3,&B3,&E3,&F3
  EQUB &07,&17,&47,&57,&27,&37,&67,&77,&86,&96,&C6,&D6,&A3,&B3,&E3,&F3
  EQUB &07,&17,&47,&57,&26,&36,&66,&76,&82,&92,&C2,&D2,&A3,&B3,&E3,&F3
  EQUB &06,&16,&46,&56,&22,&32,&62,&72,&84,&94,&C4,&D4,&A3,&B3,&E3,&F3
  \\ cw4
  EQUB &07,&17,&47,&57,&27,&37,&67,&77,&87,&97,&C7,&D7,&A3,&B3,&E3,&F3
  EQUB &07,&17,&47,&57,&27,&37,&67,&77,&85,&95,&C5,&D5,&A3,&B3,&E3,&F3
  EQUB &07,&17,&47,&57,&25,&35,&65,&75,&81,&91,&C1,&D1,&A3,&B3,&E3,&F3
  EQUB &05,&15,&45,&55,&21,&31,&61,&71,&85,&95,&C5,&D5,&A3,&B3,&E3,&F3

CLEAR P%, &8000
ORG &2800
GUARD &2900

.post_main_blocks_page_start

  .do_next_or_vsync_check
  JMP body_do_next_or_vsync_check

  .do_frame_tick_1
  JMP body_do_frame_tick_1

  .do_frame_tick_2
  JMP body_do_frame_tick_2

  .do_frame_tick_3
  JMP body_do_frame_tick_3

  .do_song_byte_decode_2
  JMP body_do_song_byte_decode_2

  .do_song_byte_decode_3
  JMP body_do_song_byte_decode_3

  .do_song_byte_decode_4
  JMP body_do_song_byte_decode_4

  .do_commit_channel
  JMP body_do_commit_channel

  .do_palette_1_setup
  JMP body_do_palette_1_setup

  .do_palette_2_setup
  JMP body_do_palette_2_setup

  .do_trigger_flash
  JMP body_do_trigger_flash

  \\ TODO: some of these per-instrument lookups could be a lot faster if we
  \\ wanted to self-modify the values when the note is played.
  .do_channel1_check_wrap
  \\ 88 cycles
  LDA #LO(do_channel2_check_wrap)
  STA main_loop_jump + 1
  LDY var_channel1_instr
  LDA channel1_load + 2
  EOR addr_sample_ends,Y
  BNE no_channel1_wrap
  LDA addr_sample_wraps,Y
  STA channel1_load + 2
  LDA channel1_load + 1
  ADC addr_sample_wraps_fine,Y
  STA channel1_load + 1
  \\ 122 cycles
  JMP jmp_main_loop_6
  .no_channel1_wrap
  \\ 106 cycles
  JMP body_no_channel1_wrap

  .do_channel2_check_wrap
  \\ 88
  LDA #LO(do_channel3_check_wrap)
  STA main_loop_jump + 1
  LDY var_channel2_instr
  LDA channel2_load + 2
  EOR addr_sample_ends,Y
  BNE no_channel2_wrap
  LDA addr_sample_wraps,Y
  STA channel2_load + 2
  LDA channel2_load + 1
  ADC addr_sample_wraps_fine,Y
  STA channel2_load + 1
  \\ 122 cycles
  JMP jmp_main_loop_6
  .no_channel2_wrap
  \\ 106 cycles
  JMP body_no_channel2_wrap

  .do_channel3_check_wrap
  \\ 88
  LDA #LO(do_next_or_vsync_check)
  STA main_loop_jump + 1
  LDY var_channel3_instr
  LDA channel3_load + 2
  EOR addr_sample_ends,Y
  BNE no_channel3_wrap
  LDA addr_sample_wraps,Y
  STA channel3_load + 2
  LDA channel3_load + 1
  ADC addr_sample_wraps_fine,Y
  STA channel3_load + 1
  \\ 122
  JMP jmp_main_loop_6
  .no_channel3_wrap
  \\ 106 cycles
  JMP body_no_channel3_wrap

  .do_song_byte_decode
  \\ 88 cycles
  LDY var_next_byte
  BMI special_command
  \\ 86 cycles (42 remain)
  LDA #LO(do_song_byte_decode_2)
  STA main_loop_jump + 1
  LDA addr_lookup_note,Y
  STA self_modify_advance_hi_value + 1
  LDA addr_lookup_instr,Y
  STA self_modify_instr_value + 1
  LDA addr_lookup_row_skip,Y
  STA var_song_row_skip_counter
  \\ 121 cycles
  NOP:NOP
  JMP main_loop
  .special_command
  \\ 94 cycles
  LDA #LO(do_channel1_check_wrap)
  STA main_loop_jump + 1
  .self_modify_song_restart
  LDA #LO(addr_song_start)
  STA self_modify_song_ptr + 1
  LDA #HI(addr_song_start)
  STA self_modify_song_ptr + 2
  \\ 111 cycles
  JMP jmp_main_loop_17

  .do_palette_iteration
  \\ 88 cycles
  LDY var_palette_index
  LDA (var_palette_ptr),Y
  STA &FE21
  INY
  LDA (var_palette_ptr),Y
  STA &FE21
  INY
  STY var_palette_index
  CPY #16
  BNE more_palette
  LDA #LO(do_channel1_check_wrap)
  STA main_loop_jump + 1
  \\ 125 cycles
  JMP main_loop
  .more_palette
  \\ 121 cycles
  NOP:NOP
  JMP main_loop

  .table_channel_code_advance_hi
  EQUB channel1_advance + 2, channel2_advance + 2, channel3_advance + 2
  .table_channel_code_load_hi
  EQUB channel1_load + 2, channel2_load + 2, channel3_load + 2
  .table_channel_code_load_lo
  EQUB channel1_load + 1, channel2_load + 1, channel3_load + 1
  .table_channel_var_instr
  EQUB var_channel1_instr, var_channel2_instr, var_channel3_instr
  .table_carries_1
  EQUB 0, 0, 0, 0, 1, 1, 1, 1
  .table_carries_2
  EQUB 0, 0, 1, 1, 0, 0, 1, 1
  .table_carries_3
  EQUB 0, 1, 0, 1, 0, 1, 0, 1

.post_main_blocks_page_end

CLEAR P%, &8000
ORG &2900
GUARD &2A00

\\ The jumps in this block are cycle counted and must not cross pages.

  .body_no_channel1_wrap
  \\ 109 cycles
  LDA channel1_load + 2
  EOR #HI(addr_silence)
  BNE no_channel_silence
  LDA #&F
  STA var_channel1_instr
  \\ 121 cycles
  NOP:NOP
  JMP main_loop
  .no_channel_silence
  \\ 117 cycles
  JMP jmp_main_loop_11

  .body_no_channel2_wrap
  \\ 109 cycles
  LDA channel2_load + 2
  EOR #HI(addr_silence)
  BNE no_channel_silence
  LDA #&F
  STA var_channel2_instr
  \\ 121 cycles
  NOP:NOP
  JMP main_loop

  .body_no_channel3_wrap
  \\ 109 cycles
  LDA channel3_load + 2
  EOR #HI(addr_silence)
  BNE no_channel_silence
  LDA #&F
  STA var_channel3_instr
  \\ 121 cycles
  NOP:NOP
  JMP main_loop

  .body_do_next_or_vsync_check
  \\ 91 cycles
  LDA var_song_row_skip_counter
  BEQ is_next
  \\ 96 cycles
  \\ vsync is lowered in do_frame_tick.
  LDA &FE4D
  AND #2
  BEQ no_vsync
  LDA var_vsync_palette_state
  BEQ timing_frame_tick
  \\ 111 cycles
  LDA #LO(do_palette_1_setup)
  STA main_loop_jump + 1
  LDA #0
  STA var_vsync_palette_state
  \\ 121 cycles
  NOP:NOP
  JMP main_loop
  .timing_frame_tick
  \\ 112 cycles 
  LDA #LO(do_frame_tick_1)
  STA main_loop_jump + 1
  LDA #1
  STA var_vsync_palette_state
  \\ 122 cycles
  JMP jmp_main_loop_6
  .is_next
  \\ 97 cycles
  LDA #LO(do_song_byte_decode)
  STA main_loop_jump + 1
  .self_modify_song_ptr
  LDA &FFFF
  STA var_next_byte
  INC self_modify_song_ptr + 1
  BNE no_song_ptr_hi
  INC self_modify_song_ptr + 2
  \\ 123 cycles
  NOP
  JMP main_loop
  .no_song_ptr_hi
  \\ 118 cycles
  JMP jmp_main_loop_10
  .no_vsync
  \\ 107 cycles
  LDA &FE4D
  AND #&40
  BNE timing_palette_2
  LDA #LO(do_channel1_check_wrap)
  STA main_loop_jump + 1
  \\ 122 cycles
  JMP jmp_main_loop_6
  .timing_palette_2
  LDA #LO(do_palette_2_setup)
  STA main_loop_jump + 1
  \\ 123 cycles
  NOP
  JMP main_loop

  .body_do_frame_tick_1
  \\ 91 cycles
  LDA #LO(do_frame_tick_2)
  STA main_loop_jump + 1
  \\ Clear vsync.
  \\ 96 cycles
  LDA #2
  STA &FE4D
  DEC var_song_tick_counter
  BNE no_song_tick_hit
  \\ MOD speed 6 vsyncs ticks per line.
  LDA #6
  STA var_song_tick_counter
  DEC var_song_row_skip_counter
  \\ 121 cycles
  NOP:NOP
  JMP main_loop
  .no_song_tick_hit
  \\ 112 cycles
  JMP jmp_main_loop_16

  .body_do_frame_tick_2
  \\ 91 cycles
  LDY var_flash_index
  BMI no_current_flash
  LDA table_palette_lists,Y
  CLC
  ADC var_palette_list_base
  STA var_palette_1
  LDA #HI(cwSteps)
  STA var_palette_1 + 1
  DEY
  STY var_flash_index
  LDA #LO(do_frame_tick_3)
  STA main_loop_jump + 1
  \\ 123 cycles
  NOP
  JMP main_loop
  .no_current_flash
  \\ 97 cycles
  DEC var_flash_frame_timer
  BNE no_flash_frame_timer_hit
  LDA #64
  STA var_flash_frame_timer
  \\ 109 cycles
  LDA var_rng
  CMP #&A0
  BCS no_flash_triggered
  \\ 116 cycles
  LDA #LO(do_trigger_flash)
  STA main_loop_jump + 1
  \\ 121 cycles
  NOP:NOP
  JMP main_loop
  .no_flash_triggered
  \\ 117 cycles
  LDA #LO(do_frame_tick_3)
  STA main_loop_jump + 1
  \\ 122 cycles
  JMP jmp_main_loop_6
  .no_flash_frame_timer_hit
  \\ 105 cycles
  LDA #LO(do_frame_tick_3)
  STA main_loop_jump + 1
  LDA #LO(palPicRest)
  STA var_palette_1
  LDA #HI(palPicRest)
  STA var_palette_1 + 1
  \\ 120 cycles
  JMP jmp_main_loop_8

CLEAR P%, &8000
ORG &2A00
GUARD &2B00

  \\ More blocks with branches.

  .body_do_frame_tick_3
  \\ 91 cycles
  LDA #LO(do_channel1_check_wrap)
  STA main_loop_jump + 1
  \\ Check keyboard interrupt.
  LDA &FE4D
  AND #1
  BEQ no_exit
  JMP do_exit
  .no_exit
  \\ 107 cycles
  \\ Mix up the random number.
  LDA &00,X
  EOR var_rng
  EOR channel1_load + 1
  EOR &FE64
  STA var_rng
  \\ 125 cycles
  JMP main_loop

CLEAR P%, &8000

  \\ Player blocks that contain no branches, so don't need to worry about page
  \\ crossings.

  .body_do_song_byte_decode_2
  \\ 91 cycles
  LDA #LO(do_song_byte_decode_3)
  STA main_loop_jump + 1
  LDY self_modify_instr_value + 1
  LDA addr_sample_starts,Y
  STA self_modify_load_hi_value + 1
  LDA addr_sample_starts_fine,Y
  STA self_modify_load_lo_value + 1
  \\ 116 cycles
  JMP jmp_main_loop_12

  .body_do_song_byte_decode_3
  \\ 91 cycles
  LDA #LO(do_song_byte_decode_4)
  STA main_loop_jump + 1
  LDY var_next_byte
  LDA addr_lookup_channel,Y
  TAY
  LDA table_channel_code_advance_hi,Y
  STA self_modify_advance_hi_store + 1
  STY self_modify_decode_4_channel + 1
  \\ 117 cycles
  JMP jmp_main_loop_11

  .body_do_song_byte_decode_4
  \\ 91 cycles
  LDA #LO(do_commit_channel)
  STA main_loop_jump + 1
  .self_modify_decode_4_channel
  LDY #00
  LDA table_channel_code_load_hi,Y
  STA self_modify_load_hi_store + 1
  LDA table_channel_code_load_lo,Y
  STA self_modify_load_lo_store + 1
  LDA table_channel_var_instr,Y
  STA self_modify_instr_store + 1
  \\ 122 cycles
  JMP jmp_main_loop_6

  .body_do_commit_channel
  \\ 91 cycles
  LDA #LO(do_channel1_check_wrap)
  STA main_loop_jump + 1
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
  \\ 116 cycles
  JMP jmp_main_loop_12

  .body_do_palette_1_setup
  \\ 91 cycles
  LDA #LO(do_palette_iteration)
  STA main_loop_jump + 1
  LDA var_palette_1
  STA var_palette_ptr
  LDA var_palette_1 + 1
  STA var_palette_ptr + 1
  LDA #0
  STA var_palette_index
  \\ 113 cycles
  JMP jmp_main_loop_15

  .body_do_palette_2_setup
  \\ 91 cycles
  LDA #LO(do_palette_iteration)
  STA main_loop_jump + 1
  \\ Cancel timer IRQ.
  LDA #&40
  STA &FE4D
  LDA #LO(palCred)
  STA var_palette_ptr
  LDA #HI(palCred)
  STA var_palette_ptr + 1
  LDA #0
  STA var_palette_index
  \\ 119 cycles
  JMP jmp_main_loop_9

  .body_do_trigger_flash
  \\ 91 cycles
  LDA #LO(do_channel1_check_wrap)
  STA main_loop_jump + 1
  LDA #14
  STA var_flash_index
  LDA var_rng
  AND #3
  CLC
  ROR A:ROR A:ROR A
  STA var_palette_list_base
  LDA #HI(cwSteps)
  STA var_palette_1 + 1
  \\ 122 cycles
  JMP jmp_main_loop_6

  .jmp_main_loop_26
  NOP
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

  .jmp_main_loop_31
  NOP
  .jmp_main_loop_29
  NOP
  .jmp_main_loop_27
  NOP
  .jmp_main_loop_25
  NOP
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

.oscli_load_data_1
  EQUS "LOAD BDRUM 4000"
  EQUB &0D
.oscli_load_data_2
  EQUS "LOAD SDRUM 4B00"
  EQUB &0D
.oscli_load_data_3
  EQUS "LOAD SHAKER 5600"
  EQUB &0D
.oscli_load_data_4
  EQUS "LOAD BASS 5A00"
  EQUB &0D
.oscli_load_data_5
  EQUS "LOAD BRIGHT 5C00"
  EQUB &0D
.oscli_load_data_6
  EQUS "LOAD TRI32 6800"
  EQUB &0D
.oscli_load_data_7
  EQUS "LOAD GUITAR 6A00"
  EQUB &0D
.oscli_load_data_8
  EQUS "LOAD LOOKTAB 7E00"
  EQUB &0D
.oscli_load_data_9
  EQUS "LOAD SONG 7B00"
  EQUB &0D
.oscli_load_data_10
  EQUS "LOAD ADVTAB 1C00"
  EQUB &0D
.oscli_load_screen
  EQUS "LOAD SCREEN 3000"
  EQUB &0D

.init_metadata
{
  LDA #0
  LDX #&20
  .loop
  STA &0100,X
  INX
  CPX #&70
  BNE loop
}
{
  LDA #HI(addr_silence)
  LDX #0
  .loop
  STA addr_sample_wraps,X
  INX
  CPX #16
  BNE loop
}
  \\ 1, BDRUM
  LDA #&80
  STA addr_sample_starts + (1-1)
  LDA #&8A
  STA addr_sample_ends + (1-1)
  \\ 2, SDRUM
  LDA #&8B
  STA addr_sample_starts + (2-1)
  LDA #&91
  STA addr_sample_ends + (2-1)
  \\ 3, SHAKER
  LDA #&96
  STA addr_sample_starts + (3-1)
  LDA #&97
  STA addr_sample_ends + (3-1)
  \\ 4, BASS128
  LDA #&9A
  STA addr_sample_starts + (4-1)
  LDA #&80
  STA addr_sample_starts_fine + (4-1)
  LDA #&9B
  STA addr_sample_ends + (4-1)
  LDA #&9A
  STA addr_sample_wraps + (4-1)
  LDA #&80
  STA addr_sample_wraps_fine + (4-1)
  \\ 5, BRIGHT
  LDA #&9C
  STA addr_sample_starts + (5-1)
  LDA #&A7
  STA addr_sample_ends + (5-1)
  \\ 6, TRI32
  LDA #&A8
  STA addr_sample_starts + (6-1)
  LDA #&E0
  STA addr_sample_starts_fine + (6-1)
  LDA #&A9
  STA addr_sample_ends + (6-1)
  LDA #&A8
  STA addr_sample_wraps + (6-1)
  LDA #&E0
  STA addr_sample_wraps_fine + (6-1)
  \\ 7, GUITAR
  LDA #&AA
  STA addr_sample_starts + (7-1)
  LDA #&BA
  STA addr_sample_ends + (7-1)

  RTS

.load_data
  LDX #LO(oscli_load_data_1)
  LDY #HI(oscli_load_data_1)
  JSR OSCLI
  LDX #LO(oscli_load_data_2)
  LDY #HI(oscli_load_data_2)
  JSR OSCLI
  LDX #LO(oscli_load_data_3)
  LDY #HI(oscli_load_data_3)
  JSR OSCLI
  LDX #LO(oscli_load_data_4)
  LDY #HI(oscli_load_data_4)
  JSR OSCLI
  LDX #LO(oscli_load_data_5)
  LDY #HI(oscli_load_data_5)
  JSR OSCLI
  LDX #LO(oscli_load_data_6)
  LDY #HI(oscli_load_data_6)
  JSR OSCLI
  LDX #LO(oscli_load_data_7)
  LDY #HI(oscli_load_data_7)
  JSR OSCLI
  LDX #LO(oscli_load_data_8)
  LDY #HI(oscli_load_data_8)
  JSR OSCLI
  LDX #LO(oscli_load_data_9)
  LDY #HI(oscli_load_data_9)
  JSR OSCLI
  LDX #LO(oscli_load_data_10)
  LDY #HI(oscli_load_data_10)
  JSR OSCLI

  \\ Copy $4000 - $7FFF to bank 4, $8000.
  SEI
  LDA #4
  STA &FE30

  LDA #0
  STA addr_tmp1
  STA addr_tmp3
  LDA #&40
  STA addr_tmp2
  LDA #&80
  STA addr_tmp4

  LDY #0
  .swram_loop
  LDA (addr_tmp1),Y
  STA (addr_tmp3),Y
  INY
  BNE swram_loop
  INC addr_tmp2
  INC addr_tmp4
  LDA addr_tmp2
  CMP #&80
  BNE swram_loop

  LDA &F4
  STA &FE30
  CLI

  LDX #LO(oscli_load_screen)
  LDY #HI(oscli_load_screen)
  JSR OSCLI

  RTS

\\ The entry point.
.binary_exec
  SEI

  \\ Interlace off.
  LDA #144
  LDX #0
  LDY #1
  JSR OSBYTE

  \\ MODE 1
  LDA #22
  JSR OSWRCH
  LDA #1
  JSR OSWRCH

  \\ Cursor off, direct approach.
  LDA #8
  STA &FE00
  LDA #&C0
  STA &FE01

{
  \\ Display off, via the palette, since it will be reset for the effects.
  LDX #15
  .loop
  TXA
  ASL A:ASL A:ASL A:ASL A
  ORA #7
  STA &FE21
  DEX
  BPL loop
}

  JSR load_data

  \\ Unload DFS before we trash its workspace.
  \\ *TAPE
  LDA #140
  LDX #0
  LDY #0
  JSR OSBYTE

  \\ Now that data is loaded, switch to the sideways RAM, and disable
  \\ interrupts. Doing these before loading results in them getting lost.
  SEI

  LDA #4
  STA &FE30

  JSR init_metadata
  JSR save_os
  JSR init_player
  JSR init_hardware

  \\ Wait for vsync then use a VIA timer to wait until the correct place in
  \\ the frame for the mid-frame palette switch.
  \\ There's a tiny amount of timing jitter here of a few microseconds,
  \\ depending how "late" the BIT's read cycle notices the timer hit.
  LDA #2
  STA &FE4D
{
  .loop
  BIT &FE4D
  BEQ loop
}
  \\ Timing here determined empirically via trial and error.
  LDA #&C0
  STA &FE44
  LDA #&2B
  STA &FE45
  LDA #&40
  STA &FE4D
{
  .loop
  BIT &FE4D
  BEQ loop
}
  \\ 19968us, non-interlaced frame time.
  LDA #&FE
  STA &FE44
  LDA #&4D
  STA &FE45

  \\ Consistent register state.
  \\ X is used as the index to the advances tables.
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
  \\ The play loop writes the bus at +6us. It took 3us to jump here. There's
  \\ another 3us to jump out of here.
  \\ Need to wait 26 - 6 - 3 - 3 = 14us of NOPs, or 28 cycles.
  JSR jsr_wait_12_cycles
  JSR jsr_wait_12_cycles
  NOP:NOP
  LDA &00
  JMP main_loop

.init_hardware
  \\ System VIA port A to output.
  LDA #&FF
  STA &FE43
  \\ Keyboard to auto-scan mode.
  LDA #&0B
  STA &FE40

  \\ Clear CA2 interrupt (keyboard) in case it is set.
  LDA #1
  STA &FE4D

  \\ System VIA used in continuous T1 mode.
  LDA #&40
  STA &FE4B

  \\ Disable system VIA IRQs.
  \\ We trash a lot of OS workspaces, so we don't want the MOS vsync or timer
  \\ handler running once we are exiting and loading the next stage.
  LDA #&7F
  STA &FE4E

  \\ User VIA T1 to 257us cycle, to assist with randomness.
  LDA #&40
  STA &FE6B
  LDA #&FF
  STA &FE64
  LDA #0
  STA &FE65

  \\ Channels 1, 2, 3 to period 3, 2, 1.
  LDA #&83
  JSR sound_write
  LDA #0
  JSR sound_write
  LDA #&A2
  JSR sound_write
  LDA #0
  JSR sound_write
  LDA #&C1
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

.init_player
{
  \\ Unpack advance tables.
  \\ They come in packed, which helps fit everything in memory. We might
  \\ unpack into the DFS workspace now that everything is loaded.
  LDA #advance_tables_len
  STA var_tmp
  .loop_table
  LDX #64
  .loop_note
  .self_modify_load_advance_table_src
  LDA addr_advance_tables_load
  STA var_next_byte
  INC self_modify_load_advance_table_src + 1
  BNE no_advance_table_src_wrap
  INC self_modify_load_advance_table_src + 2
  .no_advance_table_src_wrap
  LDY #4
  .loop_unpack
  LDA var_next_byte
  AND #3
  .self_modify_store_advance_table_dst
  STA addr_advance_tables
  INC self_modify_store_advance_table_dst + 1
  BNE no_advance_table_dst_wrap
  INC self_modify_store_advance_table_dst + 2
  .no_advance_table_dst_wrap
  LDA var_next_byte
  LSR A
  LSR A
  STA var_next_byte
  DEY
  BNE loop_unpack
  DEX
  BNE loop_note
  \\ Number of 256 byte tables to output.
  DEC var_tmp
  BNE loop_table

  \\ Update the values in the note lookup array to be based at the address of
  \\ the advance tables.
  CLC
  LDX #127
  .loop_note_rebase
  LDA addr_lookup_note,X
  ADC #HI(addr_advance_tables)
  STA addr_lookup_note,X
  DEX
  BPL loop_note_rebase
}

  \\ Relocate the player code into the zero page.
  LDX #0
  .loop_zero_page_setup
  LDA zero_page_play_copy,X
  STA zero_page_play_start,X
  INX
  CPX #LO(zero_page_play_length)
  BNE loop_zero_page_setup

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
  LDY #64
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

  \\ Point the channel addresses at the silence page.
  LDA #HI(addr_silence)
  STA channel1_load + 2
  STA channel2_load + 2
  STA channel3_load + 2

  \\ Set initial instruments to the silent sample.
  LDA #&F
  STA var_channel1_instr
  STA var_channel2_instr
  STA var_channel3_instr

  \\ Point the tables advances at the first advance table.
  LDA #HI(addr_advance_tables)
  STA channel1_advance + 2
  STA channel2_advance + 2
  STA channel3_advance + 2

  \\ Set song tick and line skip counters to fire on first vsync.
  LDA #1
  STA var_song_tick_counter
  STA var_song_row_skip_counter

  \\ Set up color flash.
  LDA #LO(palPicRest)
  STA var_palette_1
  LDA #HI(palPicRest)
  STA var_palette_1 + 1
  LDA #&FF
  STA var_flash_index
  LDA #64
  STA var_flash_frame_timer

  LDA #&FF
  STA var_rng

  RTS

.oscli_disc
  EQUS "DISC"
  EQUB &0D

.oscli_run_next_program
  EQUS "RUN PINTRO"
  EQUB &0D

.save_os
  \\ Backup pages.
  \\ Zero page, probably needed!
  LDX #0
  .loop_zero_page_backup
  LDA &00,X
  STA addr_zero_page_backup,X
  INX
  BNE loop_zero_page_backup
  \\ Page D contains the extended filesystem vectors, which are used even after
  \\ we unload DFS with *TAPE.
  .loop_D_page_backup
  LDA &D00,X
  STA addr_D_page_backup,X
  INX
  BNE loop_D_page_backup

  RTS

.restore_os
  \\ Restore pages.
  LDX #0
  .loop_zero_page_restore
  LDA addr_zero_page_backup,X
  STA &00,X
  INX
  BNE loop_zero_page_restore
  .loop_D_page_restore
  LDA addr_D_page_backup,X
  STA &D00,X
  INX
  BNE loop_D_page_restore

  \\ Doesn't seem to be necessary, but put back the currently selected ROM.
  LDA &F4
  STA &FE30

  RTS

.do_exit
  \\ Close sound write gate.
  LDA #&08
  STA &FE40

  \\ Silence tone channels.
  LDA #&9F
  JSR sound_write
  LDA #&BF
  JSR sound_write
  LDA #&DF
  JSR sound_write

  JSR restore_os

  LDX #LO(oscli_disc)
  LDY #HI(oscli_disc)
  JSR OSCLI

  LDX #LO(oscli_run_next_program)
  LDY #HI(oscli_run_next_program)
  JMP OSCLI

.zero_page_play_copy
  SKIP zero_page_play_length

ALIGN &10
.palPicRest \ picture region, rest: L0-2 black, L3 sky
  EQUB &07,&17,&47,&57,&27,&37,&67,&77,&87,&97,&C7,&D7,&A3,&B3,&E3,&F3
.palCred \ credits region, constant
  EQUB &07,&17,&47,&57,&22,&32,&62,&72,&81,&91,&C1,&D1,&A5,&B5,&E5,&F5
.table_palette_lists
  EQUB &00,&10,&10,&10,&10,&20,&20,&20,&20,&30,&30,&30,&20,&10,&00

.binary_end

COPYBLOCK zero_page_play_start, zero_page_play_end, zero_page_play_copy

SAVE "PINTRO", binary_start, binary_end, binary_exec
PUTFILE "lookup_tables.out", "LOOKTAB", 0
PUTFILE "adv_tables.out", "ADVTAB", 0
PUTFILE "conv.out", "SONG", 0
PUTFILE "sample.bdrum", "BDRUM", 0
PUTFILE "sample.sdrum", "SDRUM", 0
PUTFILE "sample.shaker", "SHAKER", 0
PUTFILE "sample.bass128", "BASS", 0
PUTFILE "sample.bright", "BRIGHT", 0
PUTFILE "sample.tri32", "TRI32", 0
PUTFILE "sample.guitar", "GUITAR", 0
PUTFILE "screen", "SCREEN", 0
