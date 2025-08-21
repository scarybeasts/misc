#include <err.h>
#include <fcntl.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int
main(int argc, const char** argv) {
  uint8_t period_to_note[1024];
  uint8_t note_remap[36 + 1];
  /* Row skip, channel, note, instrument. */
  uint8_t combination_remap[64 * 4 * 64 * 32];
  uint8_t note_array[36];
  uint32_t num_notes_used;
  uint32_t num_combinations_used;
  uint8_t channel_combination_array[256];
  uint8_t note_combination_array[256];
  uint8_t instr_combination_array[256];
  uint8_t row_skip_combination_array[256];
  uint8_t patterns[1024 * 32];
  uint8_t converted[((4 * 64) * 32) + 1];
  uint8_t advance_tables[(256 / 4) * 36];
  uint8_t* p_buf;
  uint32_t converted_index;
  const char* p_infiles[32];
  uint32_t i_args;
  uint32_t i_infiles;
  uint32_t i_periods;
  uint32_t i_notes;

  const char* p_outfile = NULL;
  const char* p_adv_tables_file = NULL;
  const char* p_lookup_tables_file = NULL;
  uint32_t num_infiles = 0;
  int fd_out = -1;

  static const int periods[] = {
      856,808,762,720,678,640,604,570,538,508,480,453,
      428,404,381,360,339,320,302,285,269,254,240,226,
      214,202,190,180,170,160,151,143,135,127,120,113,
      0,
  };

  for (i_args = 1; i_args < argc; ++i_args) {
    const char* p_arg = argv[i_args];
    const char* p_next_arg = NULL;
    if ((i_args + 1) < argc) {
      p_next_arg = argv[i_args + 1];
    }
    if (!strcmp(p_arg, "-o")) {
      p_outfile = p_next_arg;
      ++i_args;
    } else if (!strcmp(p_arg, "-a")) {
      p_adv_tables_file = p_next_arg;
      ++i_args;
    } else if (!strcmp(p_arg, "-l")) {
      p_lookup_tables_file = p_next_arg;
      ++i_args;
    } else {
      if (num_infiles == 32) {
        errx(1, "too many infiles");
      }
      p_infiles[num_infiles] = p_arg;
      num_infiles++;
    }
  }

  (void) memset(period_to_note, '\0', sizeof(period_to_note));
  for (i_periods = 0; i_periods < 36; ++i_periods) {
    uint32_t period = periods[i_periods];
    period_to_note[period] = (i_periods + 1);
  }

  for (i_infiles = 0; i_infiles < num_infiles; ++i_infiles) {
    int fd_in = open(p_infiles[i_infiles], O_RDONLY);
    if (fd_in == -1) {
      errx(1, "cannot open input file");
    }
    (void) read(fd_in, (patterns + (i_infiles * 1024)), 1024);
    (void) close(fd_in);
  }

  (void) memset(note_remap, 0xFF, sizeof(note_remap));
  (void) memset(combination_remap, 0xFF, sizeof(combination_remap));
  (void) memset(channel_combination_array,
                '\0',
                sizeof(channel_combination_array));
  (void) memset(note_combination_array, '\0', sizeof(note_combination_array));
  (void) memset(instr_combination_array, '\0', sizeof(instr_combination_array));
  (void) memset(row_skip_combination_array,
                '\0',
                sizeof(row_skip_combination_array));
  num_notes_used = 0;
  num_combinations_used = 0;
  converted_index = 0;

  for (i_infiles = 0; i_infiles < num_infiles; ++i_infiles) {
    uint32_t i_rows;
    uint8_t* p_pattern = (patterns + (i_infiles * 1024));
    uint8_t pending_channel = 0;
    uint8_t pending_note = 0;
    uint8_t pending_instr = 0;
    uint8_t num_rows_since_last = 0;

    for (i_rows = 0; i_rows <= 64; ++i_rows) {
      uint32_t i_channels;

      for (i_channels = 0; i_channels < 4; ++i_channels) {
        int has_value;
        int is_pattern_end;
        uint32_t period = 0;
        uint32_t instr = 0;
        uint32_t note = 0;

        if (i_rows < 64) {
          period = ((p_pattern[(i_channels * 4)] & 0x0F) << 8);
          period |= p_pattern[(i_channels * 4) + 1];
          note = period_to_note[period];
          instr = (p_pattern[(i_channels * 4)] & 0xF0);
          instr |= (p_pattern[(i_channels * 4) + 2] >> 4);
        }

        has_value = ((instr != 0) && (note != 0));
        is_pattern_end = ((i_rows == 64) && (i_channels == 3));

        if ((pending_note != 0) && (has_value || is_pattern_end)) {
          uint8_t value;
          uint32_t combination;

          combination = (num_rows_since_last << 13);
          combination |= (pending_channel << 11);
          combination |= (pending_note << 5);
          combination |= (pending_instr - 1);
          if (combination_remap[combination] == 0xFF) {
            combination_remap[combination] = num_combinations_used;
            if (note_remap[pending_note] == 0xFF) {
              note_remap[pending_note] = num_notes_used;
              note_array[num_notes_used] = pending_note;
              num_notes_used++;
            }

            channel_combination_array[num_combinations_used] = pending_channel;
            note_combination_array[num_combinations_used] =
                note_remap[pending_note];
            instr_combination_array[num_combinations_used] =
                (pending_instr - 1);
            row_skip_combination_array[num_combinations_used] =
                num_rows_since_last;
            num_combinations_used++;
          }
          value = combination_remap[combination];
          converted[converted_index] = value;
          converted_index++;

          num_rows_since_last = 0;
        }

        if (has_value) {
          pending_channel = i_channels;
          pending_note = note;
          pending_instr = instr;
        }
      }

      num_rows_since_last++;

      p_pattern += (4 * 4);
    }
  }

  /* End of song. */
  converted[converted_index] = 0xFF;
  converted_index++;

  printf("total notes used: %d\n", num_notes_used);
  printf("total combinations used: %d\n", num_combinations_used);

  fd_out = open(p_outfile, O_WRONLY | O_CREAT | O_TRUNC, 0666);
  if (fd_out == -1) {
    errx(1, "cannot open output file");
  }
  (void) write(fd_out, converted, converted_index);
  (void) close(fd_out);

  p_buf = advance_tables;
  for (i_notes = 0; i_notes < num_notes_used; ++i_notes) {
    uint32_t i_steps;
    double step_size;
    double current_steps_float;
    uint32_t current_steps_int;
    double amiga_period;
    double amiga_freq;
    uint8_t packed_accum;
    uint32_t note = note_array[i_notes];
    /* 15kHz. */
    double beeb_freq = (1000000 / 64.0);

    amiga_period = periods[note - 1];
    amiga_freq = ((28375160.0 / 8.0) / amiga_period);

    step_size = (amiga_freq / beeb_freq);
    current_steps_float = 0.0;
    current_steps_int = 0;

    packed_accum = 0;
    for (i_steps = 0; i_steps < 256; ++i_steps) {
      uint32_t current_steps_rounded;
      uint8_t value;
      current_steps_float += step_size;
      current_steps_rounded = round(current_steps_float);
      value = (current_steps_rounded - current_steps_int);
      current_steps_int = current_steps_rounded;
      packed_accum >>= 2;
      packed_accum |= (value << 6);
      if ((i_steps & 3) == 3) {
        *p_buf = packed_accum;
        p_buf++;
        packed_accum = 0;
      }
    }
  }
  if (p_adv_tables_file != NULL) {
    int tables_fd = open(p_adv_tables_file, O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (tables_fd == -1) {
      errx(1, "cannot open output advance tables file");
    }
    (void) write(tables_fd, advance_tables, ((256 / 4) * num_notes_used));
    (void) close(tables_fd);
  }
  if (p_lookup_tables_file != NULL) {
    uint32_t write_size = 64;
    int tables_fd = open(p_lookup_tables_file,
                         O_WRONLY | O_CREAT | O_TRUNC,
                         0666);
    if (tables_fd == -1) {
      errx(1, "cannot open output lookup tables file");
    }
    if (num_combinations_used > 64) {
      write_size = 128;
    }
    (void) write(tables_fd, channel_combination_array, write_size);
    (void) write(tables_fd, note_combination_array, write_size);
    (void) write(tables_fd, instr_combination_array, write_size);
    (void) write(tables_fd, row_skip_combination_array, write_size);
    (void) close(tables_fd);
  }

  return 0;
}
