/* Simple utility to manipulate MOD files. */

/* Warning -- utility is not robust to errors. */

#include <err.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <sys/stat.h>

enum {
  k_chan_merge = 1,
  k_chan_move = 2,
  k_instr_set = 3,
  k_fix_notes = 4,
  k_chan_clear = 5,
  k_transpose_instr = 6,
};

static const int periods[] = {
    856,808,762,720,678,640,604,570,538,508,480,453,
    428,404,381,360,339,320,302,285,269,254,240,226,
    214,202,190,180,170,160,151,143,135,127,120,113,
    0,
};

static int period_to_note[1024];

int
main(int argc, const char** argv) {
  int fd;
  struct stat statbuf;
  size_t length;
  uint8_t* p_buf;

  uint8_t commands[256];
  int32_t arg1s[256];
  int32_t arg2s[256];
  uint32_t num_commands;
  const char* p_mod_filename;

  uint32_t i;
  uint32_t arg;
  uint8_t* p_data;
  uint32_t num_patterns;
  uint32_t pattern;
  uint32_t command;
  uint32_t sequence;

  for (i = 0; i < 1024; ++i) {
    period_to_note[i] = -1;
  }
  i = 0;
  while (periods[i] != 0) {
    uint32_t period = periods[i];
    period_to_note[period] = i;
    ++i;
  }

  num_commands = 0;
  p_mod_filename = NULL;
  for (arg = 1; arg < argc; ++arg) {
    const char* p_command = argv[arg];
    int32_t arg1 = 0;
    int32_t arg2 = 0;
    int max_args = 0;
    if ((arg + 1) < argc) {
      max_args = 1;
      arg1 = atoi(argv[arg + 1]);
    }
    if ((arg + 2) < argc) {
      max_args = 2;
      arg2 = atoi(argv[arg + 2]);
    }
    if ((max_args >= 2) && !strcmp(p_command, "-chan_merge")) {
      commands[num_commands] = k_chan_merge;
      arg1s[num_commands] = arg1;
      arg2s[num_commands] = arg2;
      num_commands++;
      arg += 2;
    } else if ((max_args >= 2) && !strcmp(p_command, "-chan_move")) {
      commands[num_commands] = k_chan_move;
      arg1s[num_commands] = arg1;
      arg2s[num_commands] = arg2;
      num_commands++;
      arg += 2;
    } else if ((max_args >= 2) && !strcmp(p_command, "-instr_set")) {
      commands[num_commands] = k_instr_set;
      arg1s[num_commands] = arg1;
      arg2s[num_commands] = arg2;
      num_commands++;
      arg += 2;
    } else if ((max_args >= 2) && !strcmp(p_command, "-transpose_instr")) {
      commands[num_commands] = k_transpose_instr;
      arg1s[num_commands] = arg1;
      arg2s[num_commands] = arg2;
      num_commands++;
      arg += 2;
    } else if ((max_args >= 1) && !strcmp(p_command, "-chan_clear")) {
      commands[num_commands] = k_chan_clear;
      arg1s[num_commands] = arg1;
      num_commands++;
      arg += 1;
    } else if (!strcmp(p_command, "-fix_notes")) {
      commands[num_commands] = k_fix_notes;
      num_commands++;
    } else {
      p_mod_filename = argv[arg];
    }
  }

  fd = open(p_mod_filename, O_RDONLY);
  if (fd == -1) {
    errx(1, "failed to open input file");
  }
  (void) fstat(fd, &statbuf);
  length = statbuf.st_size;

  p_buf = malloc(length);
  (void) read(fd, p_buf, length);
  (void) close(fd);

  p_data = (p_buf + 1080);
  if (memcmp(p_data, "M.K.", 4)) {
    errx(1, "not a 31 sample MOD file");
  }

  p_data = (p_buf + 952);
  num_patterns = 0;
  for (sequence = 0; sequence < 128; ++sequence) {
    int pattern_number = p_data[sequence];
    if (pattern_number > num_patterns) {
      num_patterns = pattern_number;
    }
  }
  num_patterns++;

  (void) printf("MOD file has %d patterns\n", num_patterns);

  for (pattern = 0; pattern < num_patterns; ++pattern) {
    uint32_t row;
    p_data = (p_buf + 1084);
    p_data += (pattern * 64 * 4 * 4);
    for (row = 0; row < 64; ++row) {
      uint32_t channel;
      for (channel = 0; channel < 4; ++channel) {
        for (command = 0; command < num_commands; ++command) {
          switch (commands[command]) {
          case k_chan_merge:
          {
            uint8_t* p_from = (p_data + (arg1s[command] * 4));
            uint8_t* p_to = (p_data + (arg2s[command] * 4));
            int32_t from_note = (((p_from[0] & 0x0F) << 8) | p_from[1]);
            int32_t to_note = (((p_to[0] & 0x0F) << 8) | p_to[1]);
            if (channel != 0) {
              break;
            }
            if ((from_note != 0) && (to_note == 0)) {
              (void) memcpy(p_to, p_from, 4);
            }
            break;
          }
          case k_chan_move:
          {
            uint8_t* p_from = (p_data + (arg1s[command] * 4));
            uint8_t* p_to = (p_data + (arg2s[command] * 4));
            if (channel != 0) {
              break;
            }
            (void) memcpy(p_to, p_from, 4);
            (void) memset(p_from, '\0', 4);
            break;
          }
          case k_instr_set:
          {
            uint8_t* p_note = (p_data + (channel * 4));
            uint8_t instr = ((p_note[0] & 0xF0) | (p_note[2] >> 4));
            if (instr == arg1s[command]) {
              instr = arg2s[command];
              p_note[0] = ((p_note[0] & 0x0F) | (instr & 0xF0));
              p_note[2] = ((p_note[2] & 0x0F) | (instr << 4));
            }
            break;
          }
          case k_fix_notes:
          {
            uint8_t* p_note = (p_data + (channel * 4));
            uint16_t period;
            uint16_t upper_period;
            uint16_t lower_period;
            uint16_t upper_delta;
            uint16_t lower_delta;
            period = ((p_note[0] & 0x0F) << 8);
            period |= p_note[1];
            if (period == 0) {
              break;
            }
            if (period_to_note[period] != -1) {
              break;
            }
            upper_period = period;
            lower_period = period;
            /* No bounds checking ;-) */
            while (period_to_note[upper_period] == -1) {
              upper_period++;
            }
            while (period_to_note[lower_period] == -1) {
              lower_period--;
            }
            upper_delta = (upper_period - period);
            lower_delta = (period - lower_period);
            period = upper_period;
            if (lower_delta < upper_delta) {
              period = lower_period;
            }
            p_note[0] = ((p_note[0] & 0xF0) | (period >> 8));
            p_note[1] = (period & 0xFF);
            break;
          }
          case k_chan_clear:
          {
            uint8_t* p_to = (p_data + (arg1s[command] * 4));
            if (channel != 0) {
              break;
            }
            (void) memset(p_to, '\0', 4);
            break;
          }
          case k_transpose_instr:
          {
            uint16_t period;
            uint8_t period_index;
            uint16_t new_period;
            uint8_t* p_note = (p_data + (channel * 4));
            uint8_t instr = ((p_note[0] & 0xF0) | (p_note[2] >> 4));
            period = ((p_note[0] & 0x0F) << 8);
            period |= p_note[1];
            if (instr != arg1s[command]) {
              break;
            }
            if (period == 0) {
              break;
            }
            period_index = period_to_note[period];
            if (period_index == 0) {
              break;
            }
            new_period = (periods[period_index + arg2s[command]]);
            p_note[0] = ((p_note[0] & 0xF0) | (new_period >> 8));
            p_note[1] = (new_period & 0xFF);
            break;
          }
          default:
            break;
          }
        } /* Command iteration. */
      } /* Channel iteration. */
      p_data += 16;
    } /* Row iteration. */
  } /* Pattern iteration. */

  fd = open(p_mod_filename, O_WRONLY | O_CREAT | O_TRUNC, 0600);
  if (fd == -1) {
    errx(1, "failed to open output file");
  }
  (void) write(fd, p_buf, length);
  (void) close(fd);

  free(p_buf);

  return 0;
}
