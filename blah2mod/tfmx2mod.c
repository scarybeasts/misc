#include <err.h>
#include <fcntl.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

struct tfmx_track_state {
  uint8_t pattern_id;
  uint32_t pattern_offset;
  uint8_t* p_data;
};

struct tfmx_macro {
  uint32_t start_offset;
  uint32_t first_begin;
  uint16_t first_len;
};

struct tfmx_state {
  uint8_t* p_mdat;
  uint8_t* p_mdat_end;
  uint64_t mdat_len;
  uint8_t* p_smpl;
  uint64_t smpl_len;
  uint8_t* p_macros;
  uint8_t* p_curr_trackstep;
  uint8_t* p_end_trackstep;
  struct tfmx_track_state tracks[8];
  struct tfmx_macro macros[256];
  uint8_t* p_trackstep;
  uint8_t* p_pattern_indexes;
  uint8_t* p_macro_indexes;
};

enum {
  k_mod_max_rows = (64 * 64),
};

struct mod_state {
  /* 64 patterns worth. */
  uint8_t mod_rows[k_mod_max_rows * (4 * 4)];
  uint32_t mod_num_rows;
  uint32_t mod_row_base;
  uint32_t mod_row;
  uint32_t mod_num_patterns;

  uint8_t tfmx_macro_to_mod_sample[256];
  uint8_t mod_sample_to_tfmx_macro[256];
  uint32_t mod_num_samples;
};

static uint32_t
get_u16be(uint8_t* p) {
  uint32_t ret = p[1];
  ret |= (p[0] << 8);
  return ret;
}

static uint32_t
get_u32be(uint8_t* p) {
  uint32_t ret = p[3];
  ret |= (p[2] << 8);
  ret |= (p[1] << 16);
  ret |= (p[0] << 24);
  return ret;
}

void
put_u16be(uint8_t* p_buf, uint16_t val) {
  p_buf[0] = (val >> 8);
  p_buf[1] = (val & 0xFF);
}

int
tfmx_read_trackstep(struct tfmx_state* p_tfmx_state) {
  uint8_t* p_mdat = p_tfmx_state->p_mdat;
  uint8_t* p_mdat_end = p_tfmx_state->p_mdat_end;
  int ended = 0;

  while (1) {
    uint16_t trackstep_value = get_u16be(p_tfmx_state->p_curr_trackstep);
    if (trackstep_value == 0xEFFE) {
      uint16_t trackstep_command =
          get_u16be(p_tfmx_state->p_curr_trackstep + 2);
      switch (trackstep_command) {
      case 0x01:
        (void) printf("warning: ending on trackstep loop\n");
        ended = 1;
        break;
      case 0x02:
        (void) printf("warning: ignoring trackstep tempo command\n");
        break;
      default:
        errx(1, "unknown trackstep command 0x%x", trackstep_command);
        break;
      }
      p_tfmx_state->p_curr_trackstep += 16;
    } else {
      uint32_t i;
      uint8_t* p_pattern_indexes = p_tfmx_state->p_pattern_indexes;
      /* Row of 8 pattern IDs. */
      for (i = 0; i < 8; ++i) {
        uint8_t pattern_id = p_tfmx_state->p_curr_trackstep[i * 2];
        if (pattern_id < 0x80) {
          uint32_t pattern_offset;
          if ((p_pattern_indexes + (pattern_id * 4) + 4) > p_mdat_end) {
            errx(1, "pattern id out of bounds");
          }
          pattern_offset = get_u32be(p_pattern_indexes + (pattern_id * 4));
          if ((p_mdat + pattern_offset) > p_mdat_end) {
            errx(1, "pattern offset out of bounds");
          }
          p_tfmx_state->tracks[i].pattern_id = pattern_id;
          p_tfmx_state->tracks[i].pattern_offset = pattern_offset;
          p_tfmx_state->tracks[i].p_data = (p_mdat + pattern_offset);
        } else {
          p_tfmx_state->tracks[i].pattern_id = 0;
          p_tfmx_state->tracks[i].p_data = NULL;
        }
      }
      p_tfmx_state->p_curr_trackstep += 16;
      break;
    }

    if (ended) {
      return 0;
    }

    if (p_tfmx_state->p_curr_trackstep == p_tfmx_state->p_end_trackstep) {
      errx(1, "trackstep ran out of bounds");
    }
  }

  return 1;
}

int
tfmx_read_track(struct tfmx_state* p_tfmx_state,
                struct mod_state* p_mod_state,
                uint32_t track) {
  int end_of_data;
  uint8_t* p_mdat = p_tfmx_state->p_mdat;
  uint8_t* p_mdat_end = p_tfmx_state->p_mdat_end;
  uint8_t* p_data = p_tfmx_state->tracks[track].p_data;

  p_mod_state->mod_row = p_mod_state->mod_row_base;
  end_of_data = 0;

  while (1) {
    uint8_t note;
    uint8_t wait_ticks;

    if ((p_data + 4) > p_mdat_end) {
      errx(1, "pattern data ran out of bounds");
    }

    wait_ticks = 0;
    note = p_data[0];

    if (note < 0xF0) {
      /* Note. */
      uint8_t actual_note;
      uint8_t* p_mod;
      uint8_t macro;
      uint8_t channel;
      uint8_t mod_sample;
      uint8_t finetune;
      uint16_t amiga_period;

      static const uint16_t note_periods[] = {
          /* C-0 to B-0. */
          1710,1614,1524,1438,1357,1281,1209,1141,1077,1017,960,908,
          /* C-1 to B-1. */
          856,810,764,720,680,642,606,571,539,509,480,454,
          /* C-2 to B-2. */
          428,404,381,360,340,320,303,286,270,254,240,227,
          /* C-3 to B-3. */
          214,202,191,180,170,160,151,143,135,127,120,113,
      };

      actual_note = (note & 0x3F);
      macro = p_data[1];
      channel = (p_data[2] & 0x0F);
      finetune = p_data[3];

      switch (note & 0xC0) {
      case 0x00:
        break;
      case 0x40:
        errx(1, "note high bits 0x40");
        break;
      case 0x80:
        /* Finetune is actually a wait command. */
        wait_ticks = finetune;
        finetune = 0;
        break;
      case 0xC0:
        errx(1, "note high bits 0xC0");
        break;
      }

      if (actual_note >= 48) {
        errx(1, "note out of range");
      }
      amiga_period = note_periods[actual_note];

      mod_sample = p_mod_state->tfmx_macro_to_mod_sample[macro];
      if (mod_sample == 0) {
        uint8_t* p_macro;
        uint8_t* p_macro_index;
        uint32_t macro_index;
        int had_macro_begin;
        int had_macro_len;
        int is_macro_stopped;

        /* Increment first because samples start at 1. */
        p_mod_state->mod_num_samples++;
        if (p_mod_state->mod_num_samples == 32) {
          errx(1, "too many MOD samples");
        }
        mod_sample = p_mod_state->mod_num_samples;
        p_mod_state->tfmx_macro_to_mod_sample[macro] = mod_sample;
        p_mod_state->mod_sample_to_tfmx_macro[mod_sample] = macro;

        p_macro_index = (p_tfmx_state->p_macro_indexes + (macro * 4));
        if ((p_macro_index + 4) > p_mdat_end) {
          errx(1, "macro index out of bounds");
        }
        macro_index = get_u32be(p_macro_index);
        p_tfmx_state->macros[macro].start_offset = macro_index;
        p_macro = (p_mdat + macro_index);
        
        had_macro_begin = 0;
        had_macro_len = 0;
        is_macro_stopped = 0;

        while (1) {
          uint32_t arg;
          if ((p_macro + 4) > p_mdat_end) {
            errx(1, "macro ran out of bounds");
          }
          switch (p_macro[0]) {
          case 0x00:
            /* DMA off + reset. */
            break;
          case 0x01:
            /* DMA on. */
            break;
          case 0x02:
            /* Set sample begin (offset into sample file). */
            arg = p_macro[3];
            arg |= (p_macro[2] << 8);
            arg |= (p_macro[1] << 16);
            if (!had_macro_begin) {
              p_tfmx_state->macros[macro].first_begin = arg;
              had_macro_begin = 1;
            }
            break;
          case 0x03:
            /* Set sample length (in words). */
            arg = p_macro[3];
            arg |= (p_macro[2] << 8);
            if (!had_macro_len) {
              p_tfmx_state->macros[macro].first_len = arg;
              had_macro_len = 1;
            }
            break;
          case 0x04:
            /* Wait. */
            break;
          case 0x05:
            /* Loop. */
            (void) printf("warning: ignoring macro loop\n");
          case 0x07:
            /* Stop. */
            is_macro_stopped = 1;
            break;
          case 0x08:
            /* Add note. */
            if (p_macro[1] != 0) {
              /*errx(1, "macro add note has a note");*/
            }
            if (p_macro[2] != 0) {
              errx(1, "macro add note has unknown");
            }
            if (p_macro[3] != 0) {
              errx(1, "macro add note has finetune");
            }
            break;
          case 0x09:
            /* Set note. */
            break;
          case 0x0B:
            /* Portamento. */
            break;
          case 0x0C:
            /* Vibrato. */
            break;
          case 0x0D:
            /* Add volume. */
            break;
          case 0x0E:
            /* Set volume. */
            break;
          case 0x0F:
            /* Envelope. */
            break;
          case 0x11:
            /* Add begin. */
            break;
          case 0x14:
            /* Wait for key up. */
            break;
          case 0x18:
            /* Sample loop. */
            break;
          case 0x19:
            /* One shot sample. */
            break;
          case 0x1A:
             /* Wait for DMA. */
             break;
          default:
            errx(1, "unknown macro %d command 0x%x", macro, p_macro[0]);
            break;
          }

          if (is_macro_stopped) {
            break;
          }

          p_macro += 4;
        }
      }
      if (channel > 3) {
        errx(1, "channel out of range");
      }
      if (finetune != 0) {
        errx(1, "finetune not zero");
      }

      p_mod = (p_mod_state->mod_rows + (p_mod_state->mod_row * (4 * 4)));
      p_mod += (channel * 4);
      p_mod[0] = ((mod_sample & 0xF0) | (amiga_period >> 8));
      p_mod[1] = ((uint8_t) amiga_period);
      p_mod[2] = ((mod_sample & 0x0F) << 4);
      p_mod[3] = 0;
    } else {
      /* Command. */
      switch (note) {
      case 0xF0:
        /* End this piece pattern data, and next trackstep? */
        end_of_data = note;
        break;
      case 0xF1:
        /* Loop within this piece of pattern data. */
        (void) printf("warning: ignoring pattern loop command\n");
      case 0xF3:
        /* Wait ticks. */
        wait_ticks = p_data[1];
        break;
      case 0xF4:
        /* End this piece of pattern data. */
        end_of_data = note;
        break;
      case 0xF5:
        /* Key up. */
        break;
      case 0xF7:
        (void) printf("warning: ignoring pattern envelope command\n");
        break;
      default:
        errx(1, "unknown pattern command 0x%x", note);
        break;
      }
    }

    p_mod_state->mod_row += wait_ticks;

    if (p_mod_state->mod_row >= k_mod_max_rows) {
      errx(1, "MOD row out of bounds");
    }
    if (p_mod_state->mod_row > p_mod_state->mod_num_rows) {
      p_mod_state->mod_num_rows = p_mod_state->mod_row;
    }

    if (end_of_data) {
      return end_of_data;
    }

    p_data += 4;
  }
}

int
main(int argc, const char* argv[]) {
  const char* p_mdat_file;
  const char* p_smpl_file;
  uint8_t* p_mdat;
  uint64_t mdat_len;
  uint32_t subsong;
  int fd;
  struct stat statbuf;
  uint32_t i;
  char string[32];
  uint8_t buf[4];

  uint32_t num_subsongs;

  uint32_t tfmx_trackstep_start;
  uint16_t tfmx_subsong_start[16];
  uint16_t tfmx_subsong_end[16];
  struct tfmx_state tfmx_state;
  uint32_t tfmx_num_tracksteps;

  struct mod_state mod_state;
  uint32_t mod_num_patterns;

  (void) memset(&tfmx_state, '\0', sizeof(tfmx_state));
  (void) memset(&mod_state, '\0', sizeof(mod_state));

  p_mdat_file = argv[1];
  p_smpl_file = argv[2];
  subsong = atoi(argv[3]);

  fd = open(p_mdat_file, O_RDONLY);
  if (fd == -1) { 
    errx(1, "cannot open mdat file");
  }
  (void) fstat(fd, &statbuf);
  mdat_len = statbuf.st_size;
  tfmx_state.mdat_len = mdat_len;
  p_mdat = malloc(mdat_len);
  tfmx_state.p_mdat = p_mdat;
  tfmx_state.p_mdat_end = (p_mdat + mdat_len);
  (void) read(fd, p_mdat, mdat_len);
  (void) close(fd);

  fd = open(p_smpl_file, O_RDONLY);
  if (fd == -1) { 
    errx(1, "cannot open smpl file");
  }
  (void) fstat(fd, &statbuf);
  tfmx_state.smpl_len = statbuf.st_size;
  tfmx_state.p_smpl = malloc(tfmx_state.smpl_len);
  (void) read(fd, tfmx_state.p_smpl, tfmx_state.smpl_len);
  (void) close(fd);

  if (mdat_len < 512) {
    errx(1, "mdat file too short");
  }
  if (memcmp(p_mdat, "TFMX", 4)) {
    errx(1, "mdat file bad magic");
  }

  /* Two types of TFMX: fixed offset and dynamic offset structures. */
  tfmx_trackstep_start = get_u32be(p_mdat + 0x1d0);
  if (tfmx_trackstep_start > 0) {
    tfmx_state.p_trackstep = (p_mdat + tfmx_trackstep_start);
    tfmx_state.p_pattern_indexes = (p_mdat + get_u32be(p_mdat + 0x1d4));
    tfmx_state.p_macro_indexes = (p_mdat + get_u32be(p_mdat + 0x1d8));
  } else {
    tfmx_state.p_trackstep = (p_mdat + 0x800);
    tfmx_state.p_pattern_indexes = (p_mdat + 0x400);
    tfmx_state.p_macro_indexes = (p_mdat + 0x600);
  }

  num_subsongs = 0;
  for (i = 0; i < 16; ++i) {
    uint16_t start = get_u16be(p_mdat + 0x100 + (i * 2));
    uint16_t end = get_u16be(p_mdat + 0x140 + (i * 2));
    if ((start != 0) || (end != 0)) {
      if (start > end) {
        errx(1, "subsong start after end");
      }
      num_subsongs = (i + 1);
    }

    if (tfmx_state.p_trackstep + ((end + 1) * 16) > tfmx_state.p_mdat_end) {
      errx(1, "subsong trackstep out of range");
    }

    tfmx_subsong_start[i] = start;
    tfmx_subsong_end[i] = end;
  }
  if (subsong >= num_subsongs) {
    errx(1, "subsong out of range");
  }

  tfmx_state.p_curr_trackstep =
      (tfmx_state.p_trackstep + (tfmx_subsong_start[subsong] * 16));
  tfmx_state.p_end_trackstep =
      (tfmx_state.p_trackstep + (tfmx_subsong_end[subsong] * 16) + 16);
  tfmx_num_tracksteps = 0;

  while (tfmx_read_trackstep(&tfmx_state)) {
    mod_state.mod_row_base = mod_state.mod_num_rows;

    for (i = 0; i < 8; ++i) {
      int read_track_ret;
      uint8_t* p_data = tfmx_state.tracks[i].p_data;
      if (p_data == NULL) {
        continue;
      }
      read_track_ret = tfmx_read_track(&tfmx_state, &mod_state, i);
      (void) printf("trackstep %d track %d ret %d end row %d\n",
                    tfmx_num_tracksteps,
                    i,
                    read_track_ret,
                    mod_state.mod_row);
    }

    tfmx_num_tracksteps++;
  }

  fd = open("out.mod", O_WRONLY | O_CREAT | O_TRUNC, 0600);
  if (fd == -1) {
    errx(1, "cannot open output file");
  } 

  /* MOD name, 20 characters, NULL padded. */
  (void) memset(string, '\0', sizeof(string));
  (void) snprintf(string, sizeof(string), "%s:%d", p_mdat_file, subsong);
  (void) write(fd, string, 20);
  /* MOD samples. */
  for (i = 1; i <= mod_state.mod_num_samples; ++i) {
    uint8_t tfmx_macro = mod_state.mod_sample_to_tfmx_macro[i];

    (void) printf("    MOD sample %d is TFMX macro %d @0x%x\n",
                  i,
                  tfmx_macro,
                  tfmx_state.macros[tfmx_macro].start_offset);

    (void) memset(string, '\0', sizeof(string));
    (void) snprintf(string, sizeof(string), "%s:%d", p_smpl_file, tfmx_macro);
    (void) write(fd, string, 22);
    /* Length in words, big endian. */
    put_u16be(buf, tfmx_state.macros[tfmx_macro].first_len);
    (void) write(fd, buf, 2);
    /* Finetune. */
    buf[0] = 0;
    (void) write(fd, buf, 1);
    /* Volume. TODO. */
    buf[0] = 64;
    (void) write(fd, buf, 1);
    /* Repeat start and length, both in words, big endian. TODO. */
    put_u16be(buf, 0);
    (void) write(fd, buf, 2);
    put_u16be(buf, 1);
    (void) write(fd, buf, 2);
  }
  (void) memset(string, '\0', sizeof(string));
  for (i = (mod_state.mod_num_samples + 1); i <= 31; ++i) {
    (void) write(fd, string, 30);
  }

  mod_num_patterns = (mod_state.mod_num_rows / 64);
  if (mod_state.mod_num_rows % 64) {
    mod_num_patterns++;
  }

  /* MOD song length, and byte that's always set to 127. */
  buf[0] = mod_num_patterns;
  (void) write(fd, buf, 1);
  buf[0] = 127;
  (void) write(fd, buf, 1);
  /* MOD song positions. */
  for (i = 0; i < 128; ++i) {
    uint8_t position;
    if (i < mod_num_patterns) {
      position = i;
    } else {
      position = 0;
    }
    (void) write(fd, &position, 1);
  }
  /* MOD signature. */
  (void) write(fd, "M.K.", 4);
  /* MOD pattern data. */
  (void) write(fd, mod_state.mod_rows, (mod_num_patterns * 64 * 4 * 4));
  /* MOD sample data. */
  for (i = 1; i <= mod_state.mod_num_samples; ++i) {
    uint8_t tfmx_macro = mod_state.mod_sample_to_tfmx_macro[i];
    (void) write(
        fd,
        (tfmx_state.p_smpl + tfmx_state.macros[tfmx_macro].first_begin),
        (tfmx_state.macros[tfmx_macro].first_len * 2));
  }

  (void) close(fd);

  (void) free(tfmx_state.p_smpl);
  (void) free(p_mdat);

  return 0;
}
