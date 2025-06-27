#include <err.h>
#include <fcntl.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

/* Not yet used in code. Adding here for documenation. */
/* The structure of the sample records in the RJP file. */
struct rjp_sample {
  /* Offset in SMP file in bytes. Offsets start at byte 4, after the header. */
  uint32_t base_offset;
  /* Offset in SMP file in bytes. Used to modulate pitch of sample. */
  uint32_t modulation_offset;
  uint32_t unknown1;
  /* Offset to a 6(?) byte envelope descriptor in the second RJP chunk. */
  uint16_t envelope_offset;
  /* 0 to 64. */
  uint16_t volume;
  /* Offset from base for the start, in words. Often 0. */
  uint16_t start_offset;
  /* Length from base + offset, in words. */
  uint16_t length;
  /* Offset from base for the repeat, in words. */
  uint16_t repeat_offset;
  /* In words. */
  uint16_t repeat_length;
  /* Could be a start offset to apply to the modulation base? */
  uint16_t unknown2;
  /* In words. */
  uint16_t modulation_length;
  uint32_t unknown3;
};

struct mod_sample {
  struct rjp_sample rjp;
  uint8_t* p_data;
  uint32_t byte_len;
  uint16_t repeat_start_words;
  uint16_t repeat_len_words;
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
main(int argc, const char* argv[]) {
  const char* p_rjp_file;
  const char* p_smp_file;
  uint32_t subsong;
  uint64_t rjp_len;
  uint64_t smp_len;
  uint64_t smp_offset;
  uint8_t* p_rjp;
  uint8_t* p_smp;
  int fd;
  struct stat statbuf;
  uint8_t* p_buf;
  uint8_t* p_sample_data_base;
  uint64_t remain;
  uint64_t num_chunks;
  uint8_t* p_chunks[8];
  uint64_t chunk_lengths[8];
  uint64_t chunk_offsets[8];
  uint8_t* p_sample_chunk;
  uint32_t num_samples;
  struct mod_sample* p_samples;
  uint8_t* p_sample_envelope_chunk;
  uint32_t sample_envelope_data_size;
  uint8_t* p_subsongs_chunk;
  uint32_t num_subsongs;
  uint8_t* p_sequence_indexes_chunk;
  uint32_t num_sequence_indexes;
  uint8_t* p_pattern_ids_chunk;
  uint32_t num_pattern_ids;
  uint8_t* p_pattern_indexes_chunk;
  uint32_t num_pattern_indexes;
  uint8_t* p_pattern_data_chunk;
  uint32_t pattern_data_size;
  uint32_t i;
  char string[32];

  static const int k_mod_max_patterns = 64;
  uint8_t mod_patterns[(64 * 4 * 4) * k_mod_max_patterns];
  uint8_t mod_rjp_to_mod_sample_mapping[256];
  uint8_t mod_mod_to_rjp_sample_mapping[32];
  uint32_t mod_pattern;
  uint32_t mod_row;
  uint8_t mod_num_samples;
  int32_t mod_num_patterns;
  uint8_t mod_byte_127 = 127;

  (void) memset(mod_patterns, '\0', sizeof(mod_patterns));
  (void) memset(mod_rjp_to_mod_sample_mapping,
                '\0',
                sizeof(mod_rjp_to_mod_sample_mapping));
  (void) memset(mod_mod_to_rjp_sample_mapping,
                '\0',
                sizeof(mod_mod_to_rjp_sample_mapping));

  p_rjp_file = argv[1];
  p_smp_file = argv[2];
  subsong = atoi(argv[3]);

  fd = open(p_rjp_file, O_RDONLY);
  if (fd == -1) { 
    errx(1, "cannot open rjp file");
  }
  (void) fstat(fd, &statbuf);
  rjp_len = statbuf.st_size;
  p_rjp = malloc(rjp_len);
  (void) read(fd, p_rjp, rjp_len);
  (void) close(fd);

  fd = open(p_smp_file, O_RDONLY);
  if (fd == -1) { 
    errx(1, "cannot open smp file");
  }
  (void) fstat(fd, &statbuf);
  smp_len = statbuf.st_size;
  p_smp = malloc(smp_len);
  (void) read(fd, p_smp, smp_len);
  (void) close(fd);

  p_buf = p_rjp;
  remain = rjp_len;

  if (remain < 8) {
    errx(1, "rjp file too small");
  }
  if (memcmp(p_rjp, "RJP0SMOD", 8) &&
      memcmp(p_rjp, "RJP1SMOD", 8) &&
      memcmp(p_rjp, "RJP2SMOD", 8) &&
      memcmp(p_rjp, "RJP3SMOD", 8)) {
    errx(1, "rjp file bad magic");
  }
  if ((smp_len >= 4) && !memcmp(p_smp, "RJP1", 4)) {
    smp_offset = 4;
  } else if ((smp_len >= 12) && !memcmp((p_smp + 8), "RJP0", 4)) {
    /* The offset the player uses (in uade) still seems to be 4, even though
     * this means a sample starting at offset 2 (as per rjp.menu) has RJP0
     * stamped at the beginning.
     */
    smp_offset = 4;
  } else {
    errx(1, "smp file bad magic");
  }

  p_sample_data_base = (p_smp + smp_offset);
  smp_len -= smp_offset;

  p_buf += 8;
  remain -= 8;

  num_chunks = 0;
  while (1) {
    uint32_t chunk_len;

    if (remain == 0) {
      break;
    }
    if (num_chunks == 8) {
      errx(1, "too many chunks");
    }

    if (remain < 4) {
      errx(1, "missing chunk length");
    }
    chunk_len = get_u32be(p_buf);
    p_buf += 4;
    remain -= 4;
    if (chunk_len > remain) {
      errx(1, "chunk too big for file");
    }
    (void) printf("chunk @0x%x, length %d\n", (int) (p_buf - p_rjp), chunk_len);
    p_chunks[num_chunks] = p_buf;
    chunk_lengths[num_chunks] = chunk_len;
    chunk_offsets[num_chunks] = (p_buf - p_rjp);
    num_chunks++;
    p_buf += chunk_len;
    remain -= chunk_len;
  }

  if (num_chunks < 7) {
    errx(1, "too few chunks");
  }

  /* Second chunk includes at least sample envelope data. */
  p_sample_envelope_chunk = p_chunks[1];
  sample_envelope_data_size = chunk_lengths[1];

  /* First chunk is samples. */
  if ((chunk_lengths[0] % 32) != 0) {
    errx(1, "sample chunk size not aligned");
  }
  p_sample_chunk = p_chunks[0];
  num_samples = (chunk_lengths[0] / 32);
  (void) printf("num samples: %d\n", num_samples);

  p_samples = calloc(num_samples, sizeof(struct mod_sample));

  for (i = 0; i < num_samples; ++i) {
    char sample_filename[32];
    int has_repeat;
    struct mod_sample* p_sample = (p_samples + i);
    uint8_t* p_rjp_sample = (p_sample_chunk + (i * 32));

    p_sample->rjp.base_offset = get_u32be(p_rjp_sample);
    p_sample->rjp.start_offset = get_u16be(p_rjp_sample + 16);
    p_sample->rjp.length = get_u16be(p_rjp_sample + 18);
    p_sample->rjp.repeat_offset = get_u16be(p_rjp_sample + 20);
    p_sample->rjp.repeat_length = get_u16be(p_rjp_sample + 22);
    p_sample->rjp.envelope_offset = get_u16be(p_rjp_sample + 12);
    p_sample->rjp.volume = get_u16be(p_rjp_sample + 14);

    /* (void) printf("sample %d, start %d length %d\n",
                  i,
                  sample_start,
                  sample_length); */
    if ((p_sample->rjp.base_offset +
         (p_sample->rjp.start_offset * 2) +
         (p_sample->rjp.length * 2)) > smp_len) {
      errx(1, "sample out of bounds");
    }
    if ((p_sample->rjp.base_offset +
         (p_sample->rjp.repeat_offset * 2) +
         (p_sample->rjp.repeat_length * 2)) > smp_len) {
      errx(1, "sample repeat out of bounds");
    }
    if ((p_sample->rjp.envelope_offset + 6) > sample_envelope_data_size) {
      errx(1, "sample envelope data out of bounds");
    }

    p_sample->p_data = (p_sample_data_base + p_sample->rjp.base_offset);
    p_sample->byte_len = (p_sample->rjp.length * 2);
    p_sample->repeat_start_words = p_sample->rjp.repeat_offset;
    p_sample->repeat_len_words = p_sample->rjp.repeat_length;

    has_repeat = 0;
    if ((p_sample->rjp.repeat_offset != 0) ||
        (p_sample->rjp.repeat_length > 1)) {
      has_repeat = 1;
    }
    if (p_sample->rjp.start_offset > 0) {
      if (has_repeat &&
          (p_sample->rjp.start_offset > p_sample->rjp.repeat_offset)) {
        (void) printf("warning: sample %d start is after repeat\n", i);
      } else {
        /* Adjust MOD sample to account for RJP start offset. */
        p_sample->p_data += (p_sample->rjp.start_offset * 2);
        if (has_repeat) {
          p_sample->repeat_start_words -= p_sample->rjp.start_offset;
        }
      }
    }

    (void) snprintf(sample_filename, sizeof(sample_filename), "rjpsmp%d", i);
    /* fd = open(sample_filename, O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (fd == -1) {
      errx(1, "cannot create sample file");
    }
    (void) write(fd, (p_samples_base + sample_start), sample_length);
    (void) close(fd); */
  }

  /* Third chunk is subsongs. */
  if ((chunk_lengths[2] % 4) != 0) {
    errx(1, "subsongs chunk size not aligned");
  }
  p_subsongs_chunk = p_chunks[2];
  num_subsongs = (chunk_lengths[2] / 4);
  (void) printf("num subsongs: %d\n", num_subsongs);
  if (subsong >= num_subsongs) {
    errx(1, "requested subsong out of range");
  }
  /* Fourth chunck is sequence indexes. */
  if ((chunk_lengths[3] % 4) != 0) {
    errx(1, "sequence indexes chunk size not aligned");
  }
  p_sequence_indexes_chunk = p_chunks[3];
  num_sequence_indexes = (chunk_lengths[3] / 4);
  (void) printf("num sequence indexes: %d\n", num_sequence_indexes);
  /* Sixth chunk is pattern ids. */
  p_pattern_ids_chunk = p_chunks[5];
  num_pattern_ids = chunk_lengths[5];
  (void) printf("num pattern ids: %d\n", num_pattern_ids);
  /* Fifth chunk is pattern indexes into actual pattern data. */
  if ((chunk_lengths[4] % 4) != 0) {
    errx(1, "pattern indexes chunk size not aligned");
  }
  p_pattern_indexes_chunk = p_chunks[4];
  num_pattern_indexes = (chunk_lengths[4] / 4);
  /* Seventh chunk is pattern data. */
  p_pattern_data_chunk = p_chunks[6];
  pattern_data_size = chunk_lengths[6];

  mod_num_samples = 0;
  mod_num_patterns = -1;

  for (i = 0; i < 4; ++i) {
    uint32_t sequence_start_index;
    uint32_t sequence_index;
    uint8_t channel_volume;
    uint8_t envelope_start;
    uint8_t envelope_end;
    uint8_t envelope_ticks;
    uint8_t rjp_speed;
    uint8_t mod_speed;
    uint8_t channel_sequence_id = p_subsongs_chunk[(subsong * 4) + i];
    if (channel_sequence_id >= num_sequence_indexes) {
      errx(1, "channel sequence id out of range");
    }
    sequence_start_index =
        get_u32be(p_sequence_indexes_chunk + (channel_sequence_id * 4));
    (void) printf("channel %d sequence id 0x%x -> index 0x%x\n",
                  (i + 1),
                  channel_sequence_id,
                  sequence_start_index);
    if (sequence_start_index >= num_pattern_ids) {
      errx(1, "sequence index out of range");
    }
    (void) printf("    ");

    /* Reset MOD output position for each channel. */
    mod_pattern = 0;
    mod_row = 0;

    /* Reset RJP state. */
    rjp_speed = 6;
    mod_speed = 6;
    channel_volume = 0;
    envelope_start = 0;
    envelope_end = 0;
    envelope_ticks = 0;

    sequence_index = sequence_start_index;

    while (1) {
      uint32_t pattern_data_index;
      int32_t rjp_duration;
      int32_t rjp_sample;
      uint8_t pattern_id = p_pattern_ids_chunk[sequence_index];
      if (pattern_id == 0) {
        if (i == 0) {
          /* For now, use the end of the first channel as the indication of
           * song length.
           * Other channels pattern lists will loop until they emit the same
           * amount of data as the first channel.
           */
          mod_num_patterns = mod_pattern;
          if (mod_row > 0) {
            mod_num_patterns++;
          }
          break;
        } else {
          /* Wrap sequence id list. */
          sequence_index = sequence_start_index;
          pattern_id = p_pattern_ids_chunk[sequence_index];
        }
      }
      if (pattern_id >= num_pattern_indexes) {
        errx(1, "pattern id out of range");
      }
      pattern_data_index =
          get_u32be(p_pattern_indexes_chunk + (pattern_id * 4));
      (void) printf(", 0x%x -> 0x%x @0x%x",
                    pattern_id,
                    pattern_data_index,
                    (int) (chunk_offsets[6] + pattern_data_index));
      if (pattern_data_index >= pattern_data_size) {
        errx(1, "pattern data index out of range");
      }

      /* Iterate the RJP pattern data and convert to MOD. */
      rjp_duration = -1;
      rjp_sample = -1;
      while (1) {
        uint8_t pattern_byte = p_pattern_data_chunk[pattern_data_index];
        int do_output_advance = 0;
        uint16_t amiga_period = 0;
        uint8_t mod_sample = 0;
        uint16_t mod_command = 0;

        if (pattern_byte >= 0x80) {
          /* Command byte. */
          switch (pattern_byte) {
          case 0x80:
            /* End run of pattern data.
             * Many songs use 0x83 0xFF (set duration 0xFF) instead.
             * First seen: Ruff'n'Tumble, rjp.loader, subsong 1.
             */
            rjp_duration = 0xFF;
            break;
          case 0x81:
            /* Fade out. */
            if (channel_volume > 0) {
              channel_volume--;
              mod_command = (0xC00 | channel_volume);
            }
            do_output_advance = 1;
            break;
          case 0x82:
            /* Set speed.
             * Seems to be in units of 50Hz ticks per duration.
             * RJP channels appear to be fully independent, including speed,
             * which is not how MOD files work.
             * At least one of the Chaos Engine songs has a completely blank
             * 4th channel that has a conflicting set speed command.
             * To reconcile, for now, only accept set speed commands on the
             * first channel.
             */
            pattern_data_index++;
            if (pattern_data_index == pattern_data_size) {
              errx(1, "pattern data ran out of range");
            }
            if (i == 0) {
              rjp_speed = p_pattern_data_chunk[pattern_data_index];
            }
            break;
          case 0x83:
            /* Set note duration. */
            pattern_data_index++;
            if (pattern_data_index == pattern_data_size) {
              errx(1, "pattern data ran out of range");
            }
            rjp_duration = p_pattern_data_chunk[pattern_data_index];
            break;
          case 0x84:
            /* Set sample. */
            pattern_data_index++;
            if (pattern_data_index == pattern_data_size) {
              errx(1, "pattern data ran out of range");
            }
            rjp_sample = p_pattern_data_chunk[pattern_data_index];
            if (rjp_sample >= num_samples) {
              errx(1, "sample number out of range");
            }
            break;
          case 0x87:
            /* Not sure if this command does anything specifc other than
             * consume time.
             */
            do_output_advance = 1;
            break;
          default:
            errx(1, "unknown pattern command 0x%x", pattern_byte);
            break;
          }
        } else {
          uint8_t* p_rjp_sample;
          uint32_t rjp_sample_envelope;
          static const uint16_t period_mapping[] = {
              /* B-1 to C-1, descending. */
              453, 480, 508, 538, 570, 604, 640, 678, 720, 762, 808, 856,
              /* B-2 to C-2, descending. */
              226, 240, 254, 269, 285, 302, 320, 339, 360, 381, 404, 428,
              /* B-3 to C-3, descending. */
              113, 120, 127, 135, 143, 151, 160, 170, 180, 190, 202, 214,
          };
          /* Note byte. */
          if (pattern_byte & 1) {
            errx(1, "note bit 0 set");
          }
          pattern_byte >>= 1;
          if (pattern_byte > 35) {
            errx(1, "note is out of range");
          }
          amiga_period = period_mapping[pattern_byte];
          if (rjp_duration == -1) {
            errx(1, "duration not set");
          }
          if (rjp_sample == -1) {
            errx(1, "sample not set");
          }
          if (mod_rjp_to_mod_sample_mapping[rjp_sample] == 0) {
            (void) printf(" (RJP sample %d)", rjp_sample);
            if (mod_num_samples == 31) {
              errx(1, "too many MOD samples");
            }
            /* Mod samples start at 1, so increment first. */
            mod_num_samples++;
            mod_rjp_to_mod_sample_mapping[rjp_sample] = mod_num_samples;
            mod_mod_to_rjp_sample_mapping[mod_num_samples] = rjp_sample;
          }
          mod_sample = mod_rjp_to_mod_sample_mapping[rjp_sample];

          /* Set channel volume from played sample. */
          p_rjp_sample = (p_sample_chunk + (rjp_sample * 32));
          channel_volume = p_rjp_sample[15];

          /* Set up for a volume envelope if the sample has one. */
          rjp_sample_envelope = get_u16be(p_rjp_sample + 12);
          if (rjp_sample_envelope > 0) {
            uint8_t* p_envelope =
                (p_sample_envelope_chunk + rjp_sample_envelope);
            /* Envelope appears to be something like 6 bytes:
             * Start volume (0-0x40, all as percentage of declared volume)
             * First target volume (0-0x40)
             * Ticks to target
             * Second target volume (0-0x40)
             * Ticks to target
             * (unknown?) Ticks to release?
             */
            envelope_start = p_envelope[0];
            envelope_end = p_envelope[1];
            envelope_ticks = p_envelope[2];
          } else {
            envelope_start = 0;
            envelope_end = 0;
            envelope_ticks = 0;
          }

          do_output_advance = 1;
        }
        if (rjp_duration == 0xFF) {
          /* Duration 0xFF ends run of pattern data. */
          break;
        }

        if (do_output_advance) {
          uint32_t output_tick;
          uint16_t volume_command = 0;
          uint8_t channel_volume_delta = 0;

          if (mod_speed != rjp_speed) {
            mod_speed = rjp_speed;
            mod_command = (0xF00 | mod_speed);
          }

          /* Calculate slope on any volume slide. */
          if (envelope_ticks > 0) {
            double volume_slope;
            /* Envelope ticks are 50Hz ticks. This is different from song ticks,
             * which are some multiple of 50Hz depending on the song speed.
             */
            volume_slope = (channel_volume * (envelope_start / 64.0));
            volume_slope -= (channel_volume * (envelope_end / 64.0));
            volume_slope /= envelope_ticks;
            if (volume_slope < 0) {
              //errx(1, "volume slide up not handled");
            }
            if (volume_slope >= 0.50) {
              uint32_t volume_slope_rounded = (uint32_t) round(volume_slope);
              /* Sharper slope: have to use volume slide. */
              volume_command = (0xA00 | volume_slope_rounded);
              channel_volume_delta = volume_slope_rounded;
              channel_volume_delta *= (rjp_speed - 1);
            } else if (volume_slope > 0) {
              uint32_t volume_slope_rounded =
                  (uint32_t) round(volume_slope * rjp_speed);
              volume_command = 0xC00;
              channel_volume_delta = volume_slope_rounded;
            }
          }

          for (output_tick = 0; output_tick < rjp_duration; ++output_tick) {
            uint8_t* p_mod;

            if (mod_pattern == k_mod_max_patterns) {
              errx(1, "exceeded max MOD patterns");
            }

            /* Write single MOD cell (value for one channel on one row). */
            p_mod = mod_patterns;
            p_mod += (((mod_pattern * 64) + mod_row) * 4 * 4);
            p_mod += (i * 4);

            /* If we have a non-volume command, that takes precedence for the
             * first song time.
             * This will happen if there's a song speed command.
             */
            if ((mod_command == 0) && (volume_command > 0)) {
              mod_command = volume_command;
	      if (volume_command == 0xC00) {
                mod_command |= channel_volume;
              }
            }

            p_mod[0] = ((mod_sample & 0xF0) | (amiga_period >> 8));
            p_mod[1] = ((uint8_t) amiga_period);
            p_mod[2] = (((mod_sample & 0x0F) << 4) | (mod_command >> 8));
            p_mod[3] = (mod_command & 0xFF);

            /* Only output the note once. */
            mod_sample = 0;
            amiga_period = 0;
            mod_command = 0;

            if (channel_volume_delta > channel_volume) {
              channel_volume = 0;
            } else {
              channel_volume -= channel_volume_delta;
            }

            mod_row++;
            if (mod_row == 64) {
              mod_row = 0;
              mod_pattern++;
            }
          }
          /* For channels other than the first, end when we fill the same
           * amount of data as the first channel.
           */
          if (mod_num_patterns != -1) {
            if (mod_pattern == mod_num_patterns) {
              break;
            }
          }
        }

        pattern_data_index++;
        if (pattern_data_index == pattern_data_size) {
          errx(1, "pattern data ran out of range");
        }
      }
      /* End of iteration for one piece of pattern data. */

      /* Poor control flow, 2nd break for same condition.... */
      if (mod_pattern == mod_num_patterns) {
        break;
      }

      sequence_index++;
      if (sequence_index == num_pattern_ids) {
        errx(1, "sequence ran out of range");
      }
    }
    (void) printf("\n");

    /* End of channel. */
  }

  (void) printf("Writing MOD: %d patterns, %d samples\n",
                mod_num_patterns,
                mod_num_samples);
  fd = open("out.mod", O_WRONLY | O_CREAT | O_TRUNC, 0600);
  if (fd == -1) {
    errx(1, "cannot open output file");
  }

  /* MOD name, 20 characters, NULL padded. */
  (void) memset(string, '\0', sizeof(string));
  (void) snprintf(string, sizeof(string), "%s:%d", p_rjp_file, subsong);
  (void) write(fd, string, 20);
  /* MOD samples. */
  for (i = 1; i <= mod_num_samples; ++i) {
    uint8_t buf[4];
    uint8_t rjp_sample = mod_mod_to_rjp_sample_mapping[i];
    uint8_t* p_rjp_sample = (p_sample_chunk + (rjp_sample * 32));
    struct mod_sample* p_sample = (p_samples + rjp_sample);

    (void) printf("    MOD sample %d is RJP sample %d @0x%x\n",
                  i,
                  rjp_sample,
                  (int) (chunk_offsets[0] + (rjp_sample * 32)));

    (void) memset(string, '\0', sizeof(string));
    (void) snprintf(string, sizeof(string), "%s:%d", p_smp_file, rjp_sample);
    (void) write(fd, string, 22);
    /* Length in words, big endian. */
    put_u16be(buf, (p_sample->byte_len / 2));
    (void) write(fd, buf, 2);
    /* Finetune. */
    buf[0] = 0;
    (void) write(fd, buf, 1);
    /* Volume (copy from RJP). */
    buf[0] = p_sample->rjp.volume;
    (void) write(fd, buf, 1);
    /* Repeat start and length, both in words, big endian. */
    put_u16be(buf, p_sample->repeat_start_words);
    (void) write(fd, buf, 2);
    put_u16be(buf, p_sample->repeat_len_words);
    (void) write(fd, buf, 2);
  }
  (void) memset(string, '\0', sizeof(string));
  for (i = (mod_num_samples + 1); i <= 31; ++i) {
    (void) write(fd, string, 30);
  }
  /* MOD song length, and byte that's always set to 127. */
  (void) write(fd, &mod_num_patterns, 1);
  (void) write(fd, &mod_byte_127, 1);
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
  (void) write(fd, mod_patterns, (mod_num_patterns * 64 * 4 * 4));
  /* MOD sample data. */
  for (i = 1; i <= mod_num_samples; ++i) {
    uint8_t rjp_sample = mod_mod_to_rjp_sample_mapping[i];
    struct mod_sample* p_sample = (p_samples + rjp_sample);
    (void) write(fd, p_sample->p_data, p_sample->byte_len);
  }

  (void) close(fd);

  (void) free(p_samples);
  (void) free(p_smp);
  (void) free(p_rjp);

  return 0;
}
