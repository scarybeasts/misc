#include <err.h>
#include <fcntl.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static uint8_t period_to_note[1024];
static uint8_t note_used[36 + 1];
static uint8_t note_remap[36 + 1];
static uint8_t converted[256];
static uint32_t converted_index;

static void
callback_collect_notes(uint32_t note1,
                       uint32_t note2,
                       uint32_t note3,
                       uint32_t note4,
                       uint32_t instr1,
                       uint32_t instr2,
                       uint32_t instr3,
                       uint32_t instr4) {
  (void) instr1;
  (void) instr2;
  (void) instr3;
  (void) instr4;
  note_used[note1] = 1;
  note_used[note2] = 1;
  note_used[note3] = 1;
  note_used[note4] = 1;
}

static void
callback_do_convert(uint32_t note1,
                    uint32_t note2,
                    uint32_t note3,
                    uint32_t note4,
                    uint32_t instr1,
                    uint32_t instr2,
                    uint32_t instr3,
                    uint32_t instr4) {
  uint8_t val;
  note1 = note_remap[note1];
  note2 = note_remap[note2];
  note3 = note_remap[note3];
  note4 = note_remap[note4];
  if (instr1 > 0) {
    instr1--;
  }
  if (instr2 > 0) {
    instr2--;
  }
  if (instr3 > 0) {
    instr3--;
  }
  if (instr4 > 0) {
    instr4--;
  }

  converted[converted_index + 0] = ((instr1 << 5) | note1);
  converted[converted_index + 1] = ((instr2 << 5) | note2);
  converted[converted_index + 2] = ((instr3 << 5) | note3);
  converted[converted_index + 3] = ((instr4 << 5) | note4);
  converted_index += 4;
}

static void
iterate_pattern(uint8_t* p_pattern, void* p) {
  uint32_t line;
  void (*p_callback)(uint32_t,
                     uint32_t,
                     uint32_t,
                     uint32_t,
                     uint32_t,
                     uint32_t,
                     uint32_t,
                     uint32_t) = p;

  for (line = 0; line < 64; ++line) {
    uint32_t period1 = (((p_pattern[0] & 0x0F) << 8) | p_pattern[1]);
    uint32_t period2 = (((p_pattern[4] & 0x0F) << 8) | p_pattern[5]);
    uint32_t period3 = (((p_pattern[8] & 0x0F) << 8) | p_pattern[9]);
    uint32_t period4 = (((p_pattern[12] & 0x0F) << 8) | p_pattern[13]);
    uint32_t note1 = period_to_note[period1];
    uint32_t note2 = period_to_note[period2];
    uint32_t note3 = period_to_note[period3];
    uint32_t note4 = period_to_note[period4];
    uint32_t instr1 = ((p_pattern[0] & 0xF0) | (p_pattern[2] >> 4));
    uint32_t instr2 = ((p_pattern[4] & 0xF0) | (p_pattern[6] >> 4));
    uint32_t instr3 = ((p_pattern[8] & 0xF0) | (p_pattern[10] >> 4));
    uint32_t instr4 = ((p_pattern[12] & 0xF0) | (p_pattern[14] >> 4));

    p_callback(note1, note2, note3, note4, instr1, instr2, instr3, instr4);

    p_pattern += (4 * 4);
  }
}

int
main(int argc, const char** argv) {
  uint8_t patterns[1024 * 16];
  uint8_t advance_tables[256 * 36];
  uint32_t line;
  uint32_t i;
  uint32_t note;
  uint8_t* p_buf;

  const char* p_infiles[16];

  const char* p_outfile = NULL;
  const char* p_tablesfile = NULL;
  uint32_t num_infiles = 0;
  int fd_out = -1;
  uint32_t num_notes_used = 0;

  const int periods[] = {
      856,808,762,720,678,640,604,570,538,508,480,453,
      428,404,381,360,339,320,302,285,269,254,240,226,
      214,202,190,180,170,160,151,143,135,127,120,113,
      0,
  };

  for (i = 1; i < argc; ++i) {
    const char* p_arg = argv[i];
    const char* p_next_arg = NULL;
    if ((i + 1) < argc) {
      p_next_arg = argv[i + 1];
    }
    if (!strcmp(p_arg, "-o")) {
      p_outfile = p_next_arg;
      ++i;
    } else if (!strcmp(p_arg, "-t")) {
      p_tablesfile = p_next_arg;
      ++i;
    } else {
      if (num_infiles == 16) {
        errx(1, "too many infiles");
      }
      p_infiles[num_infiles] = p_arg;
      num_infiles++;
    }
  }

  for (i = 0; i < 36; ++i) {
    uint32_t period = periods[i];
    period_to_note[period] = (i + 1);
  }

  for (i = 0; i < num_infiles; ++i) {
    int fd_in = open(p_infiles[i], O_RDONLY);
    if (fd_in == -1) {
      errx(1, "cannot open input file");
    }
    (void) read(fd_in, (patterns + (i * 1024)), 1024);
    (void) close(fd_in);
  }

  for (i = 0; i < num_infiles; ++i) {
    iterate_pattern((patterns + (i * 1024)), callback_collect_notes);
  }

  for (i = 1; i <= 36; ++i) {
    if (note_used[i]) {
      num_notes_used++;
      note_remap[i] = num_notes_used;
    }
  }

  printf("total notes used: %d\n", num_notes_used);

  fd_out = open(p_outfile, O_WRONLY | O_CREAT | O_TRUNC, 0666);
  if (fd_out == -1) {
    errx(1, "cannot open output file");
  }

  for (i = 0; i < num_infiles; ++i) {
    converted_index = 0;
    iterate_pattern((patterns + (i * 1024)), callback_do_convert);

    (void) write(fd_out, converted, 256);
  }

  (void) close(fd_out);

  p_buf = advance_tables;
  for (i = 1; i <= 36; ++i) {
    uint32_t j;
    double step_size;
    double current_steps_float;
    uint32_t current_steps_int;
    double amiga_period;
    double amiga_freq;
    /* 15kHz. */
    double beeb_freq = (1000000 / 64.0);

    if (!note_used[i]) {
      continue;
    }

    amiga_period = periods[i - 1];
    amiga_freq = ((28375160.0 / 8.0) / amiga_period);

    step_size = (amiga_freq / beeb_freq);
    current_steps_float = 0.0;
    current_steps_int = 0;

    for (j = 0; j < 256; ++j) {
      uint32_t current_steps_rounded;
      current_steps_float += step_size;
      current_steps_rounded = round(current_steps_float);
      *p_buf = (current_steps_rounded - current_steps_int);
      current_steps_int = current_steps_rounded;
      p_buf++;
    }
  }
  if (p_tablesfile != NULL) {
    int tables_fd = open(p_tablesfile, O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (tables_fd == -1) {
      errx(1, "cannot open output tables file");
    }
    (void) write(tables_fd, advance_tables, (256 * num_notes_used));
    (void) close(tables_fd);
  }

  return 0;
}
