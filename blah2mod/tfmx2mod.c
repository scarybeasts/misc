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
  uint8_t transpose;
  uint32_t pattern_offset;
  uint8_t* p_data;
};

struct tfmx_macro {
  uint32_t meta_offset;
  uint32_t data_offset;
  uint16_t data_len;
  uint32_t repeat_start;
  uint16_t repeat_len;
  uint8_t volume;
  uint8_t env_delta;
  uint8_t env_ticks;
  uint8_t env_target;
  int32_t add_note;
  int32_t set_note;
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
  k_mod_max_patterns = 128,
};

struct mod_state {
  /* 64 patterns worth. */
  uint8_t mod_rows[k_mod_max_patterns * 64 * (4 * 4)];
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
get_u24be(uint8_t* p) {
  uint32_t ret = p[2];
  ret |= (p[1] << 8);
  ret |= (p[0] << 16);
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

void
tfmx_read_macro(struct tfmx_state* p_tfmx_state, uint8_t macro) {
  uint8_t* p_macro_data;
  int had_macro_loop_declaration;
  int is_macro_stopped;
  int32_t load_macro;
  uint32_t load_macro_start;

  struct tfmx_macro* p_macro = &p_tfmx_state->macros[macro];
  uint8_t* p_mdat = p_tfmx_state->p_mdat;
  uint8_t* p_mdat_end = p_tfmx_state->p_mdat_end;

  /* The value used in MOD files for no repeat. */
  p_macro->repeat_len = 1;
  p_macro->add_note = -1;
  p_macro->set_note = -1;

  had_macro_loop_declaration = 0;
  is_macro_stopped = 0;

  load_macro = macro;
  load_macro_start = 0;

  while (1) {
    uint32_t arg;

    if (load_macro >= 0) {
      uint32_t macro_index;
      uint8_t* p_macro_index =
          (p_tfmx_state->p_macro_indexes + (load_macro * 4));
      if ((p_macro_index + 4) > p_mdat_end) {
        errx(1, "macro index out of bounds");
      }

      macro_index = get_u32be(p_macro_index);
      if (p_macro->meta_offset == 0) {
        p_macro->meta_offset = macro_index;
      } else {
        (void) printf("marco %d jumping to macro %d@0x%x, start %d\n",
                      macro,
                      load_macro,
                      macro_index,
                      load_macro_start);
      }
      p_macro_data = (p_mdat + macro_index);
      if (load_macro_start > 0) {
        p_macro_data += (load_macro_start * 4);
      }

      load_macro = -1;
      load_macro_start = 0;
    }

    if ((p_macro_data + 4) > p_mdat_end) {
      errx(1, "macro ran out of bounds");
    }
    switch (p_macro_data[0]) {
    case 0x00:
      /* DMA off + reset. */
      break;
    case 0x01:
      /* DMA on. */
      break;
    case 0x02:
      /* Set sample begin (offset into sample file). */
      if (p_macro->set_note != -1) {
        (void) printf("warning: set note in macro %d, clearing sample\n",
                      macro);
        p_macro->data_offset = 0;
        p_macro->data_len = 0;
      }
      arg = get_u24be(p_macro_data + 1);
      if (p_macro->data_offset == 0) {
        p_macro->data_offset = arg;
      }
      break;
    case 0x03:
      /* Set sample length (in words). */
      arg = get_u16be(p_macro_data + 2);
      if (p_macro->data_len == 0) {
        p_macro->data_len = arg;
      }
      break;
    case 0x04:
      /* Wait. */
      break;
    case 0x05:
      /* Loop. */
      (void) printf("warning: ignoring macro loop\n");
      break;
    case 0x06:
      /* Jump to macro. */
      load_macro = p_macro_data[1];
      load_macro_start = get_u16be(p_macro_data + 2);
      break;
    case 0x07:
      /* Stop. */
      is_macro_stopped = 1;
      break;
    case 0x08:
      /* Add note. */
      if (p_macro->add_note != -1) {
        errx(1, "macro has second add note");
      }
      p_macro->add_note = p_macro_data[1];
      if (p_macro_data[2] != 0) {
        (void) printf("warning: ignoring unknown in macro add note\n");
      }
      if (p_macro_data[3] != 0) {
        (void) printf("warning: ignoring finetune in macro add note\n");
      }
      break;
    case 0x09:
      /* Set note. */
      /* Often used to play a quick sound (such as a bass drum) followed by
       * the actual note (such as a bass note).
       * e.g. Apidya/mdat.ingame_1:7.
       */
      if (p_macro->set_note != -1) {
        errx(1, "macro with second set note\n");
      }
      p_macro->set_note = p_macro_data[1];
      break;
    case 0x0B:
      /* Portamento. */
      break;
    case 0x0C:
      /* Vibrato. */
      break;
    case 0x0D:
      /* Add volume. */
      p_macro->volume = p_macro_data[3];
      break;
    case 0x0E:
      /* Set volume. */
      break;
    case 0x0F:
      /* Envelope. */
      if (p_macro->env_ticks != 0) {
        (void) printf("warning: multiple envelopes macro %d\n", macro);
      } else {
        p_macro->env_delta = p_macro_data[1];
        p_macro->env_ticks = p_macro_data[2];
        p_macro->env_target = p_macro_data[3];
      }
      break;
    case 0x11:
      /* Add begin. */
      break;
    case 0x12:
      /* Add length. */
      break;
    case 0x14:
      /* Wait for key up. */
      break;
    case 0x18:
      /* Sample loop. */
      had_macro_loop_declaration = 1;
      arg = get_u16be(p_macro_data + 2);
      if (arg & 1) {
        errx(1, "odd macro sample loop value");
      }
      if (arg > (p_macro->data_len * 2)) {
        /* This happens in real songs, if the macro increases the
         * length of the sample (especially in a loop), which is not
         * yet handled.
         * e.g. X-Out/mdat.ingame_2:0.
         */
        (void) printf("warning: macro sample loop too large\n");
      } else {
        /* Arg is in bytes, convert to words. */
        arg /= 2;
        p_macro->repeat_start = arg;
        p_macro->repeat_len = (p_macro->data_len - arg);
      }
      break;
    case 0x19:
      /* One shot sample. */
      had_macro_loop_declaration = 1;
      break;
    case 0x1A:
      /* Wait for DMA. */
      break;
    case 0x1D:
      /* Jump if volume greater than. */
      break;
    case 0x1F:
      /* Set previous note. */
      break;
    default:
      errx(1, "unknown macro %d command 0x%x", macro, p_macro_data[0]);
      break;
    }

    if (is_macro_stopped) {
      break;
    }

    p_macro_data += 4;
  }

  if (!had_macro_loop_declaration) {
    p_macro->repeat_start = 0;
    p_macro->repeat_len = p_macro->data_len;
  }
}

int
tfmx_read_trackstep(struct tfmx_state* p_tfmx_state) {
  uint8_t* p_mdat;
  uint8_t* p_mdat_end;
  int is_command;
  int is_ended;
  uint8_t* p_curr_trackstep = p_tfmx_state->p_curr_trackstep;

  if (p_curr_trackstep == p_tfmx_state->p_end_trackstep) {
    return 0;
  }

  p_mdat = p_tfmx_state->p_mdat;
  p_mdat_end = p_tfmx_state->p_mdat_end;

  is_ended = 0;
  is_command = 1;
  while (!is_ended && is_command) {
    uint16_t trackstep_value = get_u16be(p_curr_trackstep);
    if (trackstep_value == 0xEFFE) {
      uint16_t trackstep_command = get_u16be(p_curr_trackstep + 2);
      is_command = 1;
      switch (trackstep_command) {
      case 0x01:
        (void) printf("warning: ending on trackstep loop\n");
        is_ended = 1;
        break;
      case 0x02:
        (void) printf("warning: ignoring trackstep tempo command\n");
        break;
      default:
        errx(1, "unknown trackstep command 0x%x", trackstep_command);
        break;
      }
    } else {
      uint32_t i;
      uint8_t* p_pattern_indexes = p_tfmx_state->p_pattern_indexes;
      is_command = 0;
      /* Row of 8 pattern IDs. */
      for (i = 0; i < 8; ++i) {
        uint8_t pattern_id = p_curr_trackstep[i * 2];
        uint8_t transpose = p_curr_trackstep[(i * 2) + 1];
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
          p_tfmx_state->tracks[i].transpose = transpose;
          p_tfmx_state->tracks[i].pattern_offset = pattern_offset;
          p_tfmx_state->tracks[i].p_data = (p_mdat + pattern_offset);
        } else {
          p_tfmx_state->tracks[i].pattern_id = 0;
          p_tfmx_state->tracks[i].p_data = NULL;
        }
      }
    }

    p_curr_trackstep += 16;
  }

  p_tfmx_state->p_curr_trackstep = p_curr_trackstep;

  return !is_ended;
}

int
tfmx_read_track(struct tfmx_state* p_tfmx_state,
                struct mod_state* p_mod_state,
                uint32_t track) {
  int end_of_data;
  int is_loop_active;
  uint32_t loop_counter;
  struct tfmx_track_state* p_track = &p_tfmx_state->tracks[track];
  uint8_t* p_mdat = p_tfmx_state->p_mdat;
  uint8_t* p_mdat_end = p_tfmx_state->p_mdat_end;
  uint8_t* p_data = p_track->p_data;
  uint8_t track_transpose = p_track->transpose;

  p_mod_state->mod_row = p_mod_state->mod_row_base;
  end_of_data = 0;
  is_loop_active = 0;
  loop_counter = 0;

  while (1) {
    uint8_t note;
    uint8_t wait_ticks;
    uint32_t i;

    if ((p_data + 4) > p_mdat_end) {
      errx(1, "pattern data ran out of bounds");
    }

    wait_ticks = 0;
    note = p_data[0];

    if (note < 0xC0) {
      /* Note. */
      uint8_t actual_note;
      uint8_t macro;
      uint8_t mod_sample;
      uint8_t channel;
      uint8_t finetune;
      uint16_t amiga_period;
      uint8_t* p_mod;
      struct tfmx_macro* p_macro;

      /* From tfmxplay-1.1.7.
       * Seems to match actual periods seen with uade --scope.
       */
      static const uint16_t note_periods_tfmx[] = {
          /* C-0 to B-0. */
          1710,1614,1524,1438,1357,1281,1209,1141,1077,1017,960,908,
          /* C-1 to B-1. */
          856,810,764,720,680,642,606,571,539,509,480,454,
          /* C-2 to B-2. */
          428,404,381,360,340,320,303,286,270,254,240,227,
          /* C-3 to B-3. */
          214,202,191,180,170,160,151,143,135,127,120,113,
      };
      static const uint16_t note_periods_mod[] = {
          /* C-0 to B-0. Not defined in MOD so copied across from TFMX. */
          1710,1614,1524,1438,1357,1281,1209,1141,1077,1017,960,908,
          /* C-1 to B-1. */
          856,808,762,720,678,640,604,570,538,508,480,453,
          /* C-2 to B-2. */
          428,404,381,360,339,320,302,285,269,254,240,226,
          /* C-3 to B-3. */
          214,202,190,180,170,160,151,143,135,127,120,113,
      };

      macro = p_data[1];
      channel = (p_data[2] & 0x0F);
      finetune = p_data[3];

      if (note & 0x40) {
        errx(1, "note high bits 0x40");
      }
      if (note & 0x80) {
        /* Finetune is actually a wait command. */
        wait_ticks = (finetune + 1);
        finetune = 0;
      }

      mod_sample = p_mod_state->tfmx_macro_to_mod_sample[macro];
      if (mod_sample == 0) {
        tfmx_read_macro(p_tfmx_state, macro);

        /* Increment first because samples start at 1. */
        p_mod_state->mod_num_samples++;
        if (p_mod_state->mod_num_samples == 32) {
          errx(1, "too many MOD samples");
        }
        mod_sample = p_mod_state->mod_num_samples;
        p_mod_state->tfmx_macro_to_mod_sample[macro] = mod_sample;
        p_mod_state->mod_sample_to_tfmx_macro[mod_sample] = macro;
      }

      p_macro = &p_tfmx_state->macros[macro];
      if ((p_macro->set_note != -1) && (p_macro->add_note == -1)) {
        actual_note = p_macro->set_note;
      } else {
        actual_note = (note + track_transpose + p_macro->add_note);
      }
      actual_note &= 0x3F;
      if (actual_note >= 60) {
        errx(1, "note out of range");
      } else if (actual_note >= 48) {
        /* Notes 48 - 59 are the same as notes 36 - 47. */
        (void) printf("encountered note %d\n", actual_note);
        actual_note -= 12;
      }
      amiga_period = note_periods_mod[actual_note];

      if (channel > 3) {
        errx(1, "channel out of range");
      }
      if (finetune != 0) {
        (void) printf("warning: note finetune not zero\n");
      }

      p_mod = (p_mod_state->mod_rows + (p_mod_state->mod_row * (4 * 4)));
      p_mod += (channel * 4);

      p_mod[0] = ((mod_sample & 0xF0) | (amiga_period >> 8));
      p_mod[1] = ((uint8_t) amiga_period);
      p_mod[2] = ((mod_sample & 0x0F) << 4);
      p_mod[3] = 0;
    } else if (note < 0xF0) {
      (void) printf("warning: ignoring pattern portamento command\n");
    } else {
      /* >= 0xF0: command. */
      switch (note) {
      case 0xF0:
        /* End this piece pattern data, and next trackstep? */
        end_of_data = note;
        break;
      case 0xF1:
      {
        uint16_t pattern_dest;
        if (is_loop_active && (loop_counter == 0)) {
          /* Loop finished -- continue to the next pattern data after the
           * loop command.
           */
          is_loop_active = 0;
          break;
        }
        if (!is_loop_active) {
          is_loop_active = 1;
          loop_counter = p_data[1];
          /* Loop counter of 0 means "infinite loop". It'll integer underflow
           * below and carry on below 0.
           */
        }
        loop_counter--;
        if (loop_counter == (uint32_t) -8) {
          /* Hack: end infinite loop after 8 loops. */
          end_of_data = note;
          break;
        }
        pattern_dest = get_u16be(p_data + 2);
        p_data = p_track->p_data;
        /* This may go out of bounds. It'll be checked at the next pattern
         * fetch iteration.
         */
        p_data += (pattern_dest * 4);
        /* The loop continuation will add 4 bytes. */
        p_data -= 4;
        break;
      }
      case 0xF3:
        /* Wait ticks. */
        wait_ticks = (p_data[1] + 1);
        break;
      case 0xF4:
        /* End this piece of pattern data. */
        end_of_data = note;
        break;
      case 0xF5:
        /* Key up. */
        break;
      case 0xF6:
        /* Vibrato. */
        (void) printf("warning: ignoring pattern vibrato command\n");
        break;
      case 0xF7:
        (void) printf("warning: ignoring pattern envelope command\n");
        break;
      case 0xFA:
        (void) printf("warning: ignoring pattern fade command\n");
        break;
      default:
        errx(1, "unknown pattern command 0x%x", note);
        break;
      }
    }

    p_mod_state->mod_row += wait_ticks;

    if (p_mod_state->mod_row >= (k_mod_max_patterns * 64)) {
      errx(1, "MOD row out of bounds");
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
  uint16_t start;
  uint16_t end;

  uint32_t tfmx_trackstep_start;
  uint16_t tfmx_subsong_start[16];
  uint16_t tfmx_subsong_end[16];
  uint16_t tfmx_subsong_tempo[16];
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
    tfmx_trackstep_start = 0x800;
    tfmx_state.p_trackstep = (p_mdat + 0x800);
    tfmx_state.p_pattern_indexes = (p_mdat + 0x400);
    tfmx_state.p_macro_indexes = (p_mdat + 0x600);
  }

  num_subsongs = 0;
  for (i = 0; i < 16; ++i) {
    start = get_u16be(p_mdat + 0x100 + (i * 2));
    end = get_u16be(p_mdat + 0x140 + (i * 2));
    /* Can't bail on "start > end" because Adventures_Quik_and_Silva/mdat.ingame
     * hits it.
     */
    if ((start != 0) || (end != 0) && (end >= start)) {
      num_subsongs = (i + 1);
    }

    if (tfmx_state.p_trackstep + ((end + 1) * 16) > tfmx_state.p_mdat_end) {
      errx(1, "subsong trackstep out of range");
    }

    tfmx_subsong_start[i] = start;
    tfmx_subsong_end[i] = end;
    tfmx_subsong_tempo[i] = get_u16be(p_mdat + 0x180 + (i * 2));
  }
  if (subsong >= num_subsongs) {
    errx(1, "subsong out of range");
  }

  start = tfmx_subsong_start[subsong];
  end = tfmx_subsong_end[subsong];
  tfmx_state.p_curr_trackstep = (tfmx_state.p_trackstep + (start * 16));
  tfmx_state.p_end_trackstep = (tfmx_state.p_trackstep + (end * 16) + 16);
  tfmx_num_tracksteps = 0;

  (void) printf("Converting subsong %d start %d@0x%x end %d\n",
                subsong,
                start,
                (tfmx_trackstep_start + (start * 16)),
                end);

  while (tfmx_read_trackstep(&tfmx_state)) {
    int had_F0 = 0;
    mod_state.mod_row_base = mod_state.mod_num_rows;

    for (i = 0; i < 8; ++i) {
      int read_track_ret;
      uint8_t* p_data = tfmx_state.tracks[i].p_data;
      if (p_data == NULL) {
        continue;
      }
      read_track_ret = tfmx_read_track(&tfmx_state, &mod_state, i);
      (void) printf(
          "trackstep %d track %d id %d@0x%x trans %d ret %d end row %d\n",
          tfmx_num_tracksteps,
          i,
          tfmx_state.tracks[i].pattern_id,
          tfmx_state.tracks[i].pattern_offset,
          tfmx_state.tracks[i].transpose,
          read_track_ret,
          mod_state.mod_row);

      /* Pattern command 0xF0 sets where the current set of track patterns
       * ends. Sometimes, one of the tracks runs a little longer but ends with
       * command 0xF4. We insist on seeing command 0xF4 in one of the tracks.
       * e.g. Apidya/mdat.ingame_1:7
       */
      if (read_track_ret == 0xF0) {
        if (!had_F0) {
          had_F0 = 1;
          mod_state.mod_num_rows = mod_state.mod_row;
        }
      }
    }

    if (!had_F0) {
      errx(1, "no 0xF0 pattern command");
    }

    tfmx_num_tracksteps++;
  }

  /* Fill in volume, vibrato etc. commands. */
  for (i = 0; i < 4; ++i) {
    uint32_t row;
    uint16_t mod_command = 0;
    for (row = 0; row < mod_state.mod_num_rows; ++row) {
      uint8_t sample;
      struct tfmx_macro* p_macro;
      uint8_t* p_mod = (mod_state.mod_rows + (row * (4 * 4)));
      p_mod += (i * 4);
      sample = ((p_mod[0] & 0xF0) | (p_mod[2] >> 4));
      if (sample != 0) {
        uint8_t macro = mod_state.mod_sample_to_tfmx_macro[sample];
        struct tfmx_macro* p_macro = &tfmx_state.macros[macro];
        if ((p_macro->env_ticks == 1) && (p_macro->env_target < 32)) {
          mod_command = (0xA00 + (p_macro->env_delta & 0x0F));
        } else {
          mod_command = 0;
        }
      }
      p_mod[2] |= (mod_command >> 8);
      p_mod[3] = (mod_command & 0xFF);
    }
  }

  /* Put in a MOD tempo command to match the subsong tempo.
   * Search all 4 channels for an unused command slot.
   */
  for (i = 0; i < 4; ++i) {
    uint8_t* p_mod = (mod_state.mod_rows + (i * 4));
    if (!(p_mod[2] & 0x0F)) {
      /* No command here -- use this slot. */
      p_mod[2] |= 0xF;
      p_mod[3] = (tfmx_subsong_tempo[subsong] + 1);
      break;
    }
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
    struct tfmx_macro* p_macro = &tfmx_state.macros[tfmx_macro];

    (void) printf("    MOD sample %d is TFMX macro %d @0x%x\n",
                  i,
                  tfmx_macro,
                  p_macro->meta_offset);

    (void) memset(string, '\0', sizeof(string));
    (void) snprintf(string, sizeof(string), "%s:%d", p_smpl_file, tfmx_macro);
    (void) write(fd, string, 22);
    /* Length in words, big endian. */
    put_u16be(buf, p_macro->data_len);
    (void) write(fd, buf, 2);
    /* Finetune. */
    buf[0] = 0;
    (void) write(fd, buf, 1);
    /* Volume. TODO. */
    buf[0] = 64;
    (void) write(fd, buf, 1);
    /* Repeat start and length, both in words, big endian. */
    put_u16be(buf, p_macro->repeat_start);
    (void) write(fd, buf, 2);
    put_u16be(buf, p_macro->repeat_len);
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
        (tfmx_state.p_smpl + tfmx_state.macros[tfmx_macro].data_offset),
        (tfmx_state.macros[tfmx_macro].data_len * 2));
  }

  (void) close(fd);

  (void) free(tfmx_state.p_smpl);
  (void) free(p_mdat);

  return 0;
}
