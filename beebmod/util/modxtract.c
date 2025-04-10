#include <err.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

/* Simple utility to extract raw sample bytes. */

/* Warning -- this utility is not robust to errors. */

int
main(int argc, const char** argv) {
  int fd;
  struct stat statbuf;
  unsigned char* p_buf;
  unsigned char* p_data;
  int i;
  int offset;
  int sample_data_offset;
  int sample_length;
  int num_patterns;
  int num_samples;

  int extract_sample[32];
  int extract_pattern[256];

  const char* p_mod_file = NULL;

  if (argc < 2) {
    errx(1, "no filename");
  }

  memset(extract_sample, '\0', sizeof(extract_sample));
  memset(extract_pattern, '\0', sizeof(extract_pattern));

  for (i = 1; i < argc; ++i) {
    int value;
    const char* p_command = argv[i];
    if ((i + 1) < argc) {
      value = atoi(argv[i + 1]);
      if (!strcmp(p_command, "-sample")) {
        extract_sample[value] = 1;
        ++i;
      } else if (!strcmp(p_command, "-pattern")) {
        extract_pattern[value] = 1;
        ++i;
      }
    } else {
      p_mod_file = argv[i];
    }
  }

  fd = open(p_mod_file, O_RDONLY);
  if (fd == -1) {
    errx(1, "failed to open input file");
  }
  fstat(fd, &statbuf);

  p_buf = malloc(statbuf.st_size);

  read(fd, p_buf, statbuf.st_size);
  close(fd);

  p_data = (p_buf + 1080);
  num_samples = 15;
  if (!memcmp(p_data, "M.K.", 4) ||
      !memcmp(p_data, "M!K!", 4) ||
      !memcmp(p_data, "FLT4", 4)) {
    num_samples = 31;
  }

  /* Offset to number of positions. */
  offset = (20 + (num_samples * 30));
  /* Offset to list of pattern numbers. */
  offset += 2;
  num_patterns = 0;
  for (i = 0; i < 128; ++i) {
    int pattern_number = p_buf[offset + i];
    if (pattern_number > num_patterns) {
      num_patterns = pattern_number;
    }
  }
  num_patterns++;

  offset = (offset + 128 + 4);

  for (i = 0; i < num_patterns; ++i) {
    char filename[256];
    if (!extract_pattern[i]) {
      continue;
    }
    snprintf(filename, sizeof(filename), "mod.pattern.%d", i);
    fd = open(filename, O_CREAT | O_TRUNC | O_WRONLY, 0666);
    write(fd, (p_buf + offset + (i * 64 * 4 * 4)), (64 * 4 * 4));
    close(fd);
  }

  sample_data_offset = offset;
  sample_data_offset += (num_patterns * (64 * 4 * 4));

  offset = 20;
  for (i = 1; i < (num_samples + 1); ++i) {
    sample_length = (p_buf[offset + 22] << 8);
    sample_length += p_buf[offset + 23];
    sample_length *= 2;

    if (extract_sample[i]) {
      char filename[256];
      snprintf(filename, sizeof(filename), "mod.sample.%d", i);
      fd = open(filename, O_CREAT | O_TRUNC | O_WRONLY, 0666);
      write(fd, (p_buf + sample_data_offset), sample_length);
      close(fd);
    }

    sample_data_offset += sample_length;
    offset += 30;
  }

  return 0;
}
