#include <err.h>
#include <fcntl.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

int
main(int argc, const char** argv) {
  int fd;
  struct stat statbuf;
  uint32_t in_length;
  uint32_t length;
  uint32_t i;
  int8_t* p_sample;
  int8_t* p_buf;
  double* p_volumes;
  uint32_t volume_total;
  uint32_t num_volumes;
  double volume;
  double offset;

  const char* p_in_file = NULL;
  const char* p_out_file = NULL;
  const char* p_sn_file = NULL;
  uint32_t window_size = 128;
  double dyn_offset_rate = 0.5;
  uint32_t dyn_offset_max = 0;
  double dyn_factor = 1.0;
  int32_t static_offset = 0;
  double gain = 1.0;
  int sn_channel = 0;
  uint32_t post_end_pad = 0;
  uint8_t pad_byte = 0x80;
  uint32_t pre_begin_trunc = 0;
  uint32_t pre_begin_pad = 0;
  int32_t loop_start = -1;

  for (i = 1; i < argc; ++i) {
    const char* p_arg = argv[i];
    if ((i + 1) < argc) {
      const char* p_next_arg = argv[i + 1];
      if (!strcmp(p_arg, "-i")) {
        p_in_file = p_next_arg;
        ++i;
      } else if (!strcmp(p_arg, "-o")) {
        p_out_file = p_next_arg;
        ++i;
      } else if (!strcmp(p_arg, "-sn")) {
        p_sn_file = p_next_arg;
        ++i;
      } else if (!strcmp(p_arg, "-dyn_offset")) {
        dyn_offset_max = atoi(p_next_arg);
        ++i;
      } else if (!strcmp(p_arg, "-dyn_factor")) {
        dyn_factor = atof(p_next_arg);
        ++i;
      } else if (!strcmp(p_arg, "-dyn_rate")) {
        dyn_offset_rate = atof(p_next_arg);
        ++i;
      } else if (!strcmp(p_arg, "-static_offset")) {
        int32_t new_pad_byte = pad_byte;
        static_offset = atoi(p_next_arg);
        new_pad_byte -= static_offset;
        if (new_pad_byte > 255) {
          new_pad_byte = 255;
        } else if (new_pad_byte < 0) {
          new_pad_byte = 0;
        }
        pad_byte = new_pad_byte;
        ++i;
      } else if (!strcmp(p_arg, "-gain")) {
        gain = atof(p_next_arg);
        ++i;
      } else if (!strcmp(p_arg, "-snchannel")) {
        sn_channel = atoi(p_next_arg);
        ++i;
      } else if (!strcmp(p_arg, "-pre_begin_trunc")) {
        pre_begin_trunc = atoi(p_next_arg);
        ++i;
      } else if (!strcmp(p_arg, "-pre_begin_pad")) {
        pre_begin_pad = atoi(p_next_arg);
        ++i;
      } else if (!strcmp(p_arg, "-post_end_pad")) {
        post_end_pad = atoi(p_next_arg);
        ++i;
      } else if (!strcmp(p_arg, "-loop_start")) {
        loop_start = atoi(p_next_arg);
        ++i;
      }
    }
  }

  if (p_in_file == NULL) {
    errx(1, "no input filename, e.g. -i filename");
  }
  if (p_out_file == NULL) {
    errx(1, "no output filename, e.g. -o filename");
  }

  fd = open(p_in_file, O_RDONLY);
  if (fd == -1) {
    errx(1, "failed to open input file");
  }

  (void) fstat(fd, &statbuf);
  in_length = statbuf.st_size;
  length = in_length;
  length -= pre_begin_trunc;
  length += pre_begin_pad;

  p_sample = malloc(length);
  p_volumes = malloc(length * sizeof(double));

  p_buf = p_sample;
  (void) memset(p_buf, '\0', pre_begin_pad);
  p_buf += pre_begin_pad;
  (void) lseek(fd, pre_begin_trunc, SEEK_SET);
  (void) read(fd, p_buf, (in_length - pre_begin_trunc));
  (void) close(fd);

  /* Calculate a rolling average volume. */
  num_volumes = 0;
  volume_total = 0;
  for (i = 0; i < length; ++i) {
    /* Normalize a s8 sample value to absolute magnitude. */
    volume_total += abs(p_sample[i]);
    num_volumes++;
    if (num_volumes == window_size) {
      volume = ((double) volume_total / num_volumes);
      p_volumes[i - (window_size / 2)] = volume;
      /* Maintain rolling average. */
      volume_total -= abs(p_sample[i - (window_size - 1)]);
      num_volumes--;
    }
  }

  /* Copy initial and final values into the head and tail of the rolling
   * average volume list.
   */
  volume = p_volumes[window_size / 2];
  for (i = 0; i < (window_size / 2); ++i) {
    p_volumes[i] = volume;
  }
  volume = p_volumes[length - 1 - (window_size / 2)];
  for (i = (length - (window_size / 2)); i < length; ++i) {
    p_volumes[i] = volume;
  }

  /* Apply any gain and static offset, with clipping. */
  for (i = 0; i < length; ++i) {
    double sample = p_sample[i];
    sample *= gain;
    sample -= static_offset;
    if (sample > 127) {
      sample = 127;
    } else if (sample < -128) {
      sample = -128;
    }
    p_sample[i] = sample;
  }

  /* Apply a dynamic lowering offset to the sample data for parts of the sample
   * that are quieter.
   */
  offset = 0.0;
  for (i = 0; i < length; ++i) {
    int32_t sample;
    double target_delta;
    /* Calculate target offset, with quieter sections having a larger offset
     * towards the negative side of the waveform.
     */
    double target_offset = (dyn_offset_max - (p_volumes[i] * dyn_factor));
    /* Cap the target offset if we're nearing the end of the input. */
    if (i >= (length - (128 / dyn_offset_rate))) {
      target_offset = 0;
    }
    if (target_offset < 0) {
      target_offset = 0;
    }
    /* Slowly drift towards the target offset. */
    target_delta = (target_offset - offset);
    if (fabs(target_delta) < (dyn_offset_rate * 2)) {
      /* Close enough. This stops an oscillation in sections where the average
       * volume is constant.
       */
    } else if (target_offset > offset) {
      offset += dyn_offset_rate;
    } else if (target_offset < offset) {
      offset -= dyn_offset_rate;
    }

    sample = p_sample[i];
    sample -= offset;
    if (sample > 127) {
      sample = 127;
    } else if (sample < -128) {
      sample = -128;
    }
    p_sample[i] = sample;
  }

  /* Convert sample from s8 to u8. */
  for (i = 0; i < length; ++i) {
    int32_t sample = p_sample[i];
    sample += 128;
    p_sample[i] = sample;
  }

  /* Quantize the final sample according to the SN output levels, if the option
   * was selected.
   */
  if (p_sn_file != NULL) {
    /* Support single channel mapping for now. */
    uint8_t sn_map[256];
    uint8_t sn_output_levels[16];
    uint8_t sn_value;
    uint8_t sn_channel_command = 0;

    fd = open(p_sn_file, O_RDONLY);
    if (fd == -1) {
      errx(1, "failed to open SN file");
    }
    (void) read(fd, sn_map, 256);
    (void) close(fd);

    for (i = 0; i < 15; ++i) {
      double sn_level = (255.0 * pow(10.0, (-0.1 * i)));
      sn_output_levels[i] = round(sn_level);
    }
    sn_output_levels[15] = 0;

    sn_value = (sn_map[pad_byte] & 0x0f);
    if (sn_channel > 0) {
      sn_channel_command = (0x90 | ((sn_channel - 1) * 0x20));
      pad_byte = (sn_value | sn_channel_command);
    } else {
      pad_byte = sn_output_levels[sn_value];
    }

    for (i = 0; i < length; ++i) {
      uint8_t sample = p_sample[i];
      sn_value = (sn_map[sample] & 0x0f);
      if (sn_channel > 0) {
        sample = sn_value;
        sample |= sn_channel_command;
      } else {
        sample = sn_output_levels[sn_value];
      }
      p_sample[i] = sample;
    }
  }

  fd = open(p_out_file, O_WRONLY | O_CREAT | O_TRUNC, 0666);
  if (fd == -1) {
    errx(1, "failed to open output file");
  }
  (void) write(fd, p_sample, length);
  if (post_end_pad > 0) {
    /* Pad the sample.
     * First we pad to 256 bytes.
     * Then we add bytes of padding to handle read overruns due to the
     * player doing out-of-band sample wrap.
     */
    uint32_t page_pad_length = (256 - (length % 256));
    page_pad_length &= 255;
    for (i = 0; i < page_pad_length; ++i) {
      (void) write(fd, &pad_byte, 1);
    }
    for (i = 0; i < post_end_pad; ++i) {
      if (loop_start >= 0) {
        pad_byte = p_sample[loop_start];
        loop_start++;
      }
      (void) write(fd, &pad_byte, 1);
    }
  }
  (void) close(fd);

  return 0;
}
