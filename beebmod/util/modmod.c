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
  k_merge = 1,
  k_move = 2,
};

int
main(int argc, const char** argv) {
  int fd;
  struct stat statbuf;
  size_t length;
  uint8_t* p_buf;

  uint8_t commands[256];
  uint8_t arg1s[256];
  uint8_t arg2s[256];
  uint32_t num_commands;
  const char* p_mod_filename;

  uint32_t arg;
  uint8_t* p_data;
  uint32_t num_patterns;
  uint32_t pattern;
  uint32_t command;
  uint32_t sequence;

  num_commands = 0;
  p_mod_filename = NULL;
  for (arg = 1; arg < argc; ++arg) {
    const char* p_command = argv[arg];
    uint8_t arg1 = 0;
    uint8_t arg2 = 0;
    int max_args = 0;
    if ((arg + 1) < argc) {
      max_args = 1;
      arg1 = atoi(argv[arg + 1]);
    }
    if ((arg + 2) < argc) {
      max_args = 2;
      arg2 = atoi(argv[arg + 2]);
    }
    if ((max_args >= 2) && !strcmp(p_command, "-merge")) {
      commands[num_commands] = k_merge;
      arg1s[num_commands] = arg1;
      arg2s[num_commands] = arg2;
      num_commands++;
      arg += 2;
    } else if ((max_args >= 2) && !strcmp(p_command, "-move")) {
      commands[num_commands] = k_move;
      arg1s[num_commands] = arg1;
      arg2s[num_commands] = arg2;
      num_commands++;
      arg += 2;
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
      for (command = 0; command < num_commands; ++command) {
        int32_t from_note;
        int32_t to_note;
        uint8_t* p_from = (p_data + (arg1s[command] * 4));
        uint8_t* p_to = (p_data + (arg2s[command] * 4));
        from_note = (((p_from[0] & 0x0F) << 8) | p_from[1]);
        to_note = (((p_to[0] & 0x0F) << 8) | p_to[1]);
        switch (commands[command]) {
        case k_merge:
          if ((from_note != 0) && (to_note == 0)) {
            (void) memcpy(p_to, p_from, 4);
          }
          break;
        case k_move:
          (void) memcpy(p_to, p_from, 4);
          (void) memset(p_from, '\0', 4);
          break;
        default:
          break;
        }
      }
      p_data += 16;
    }
  }

  fd = open(p_mod_filename, O_WRONLY | O_CREAT | O_TRUNC, 0600);
  if (fd == -1) {
    errx(1, "failed to open output file");
  }
  (void) write(fd, p_buf, length);
  (void) close(fd);

  free(p_buf);

  return 0;
}
