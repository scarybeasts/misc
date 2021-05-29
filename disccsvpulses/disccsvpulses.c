#include <ctype.h>
#include <err.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static uint16_t
do_crc16(uint8_t* p_buf, uint32_t len) {
  uint32_t i;
  uint32_t j;
  uint16_t crc = 0xFFFF;

  for (i = 0; i < len; ++i) {
    uint8_t byte = p_buf[i];
    for (j = 0; j < 8; ++j) {
      int bit = (byte & 0x80);
      int bit_test = ((crc & 0x8000) ^ (bit << 8));
      crc <<= 1;
      if (bit_test) {
        crc ^= 0x1021;
      }
      byte <<= 1;
    }
  }

  return crc;
}

int
main(int argc, const char* argv[]) {
  FILE* p_in_file;
  FILE* p_out_file;
  uint32_t samples_per_bit;
  uint32_t s;
  uint32_t i;
  uint32_t i_bytes;
  int dir;
  uint8_t byte;
  uint32_t byte_samples_start;
  uint16_t crc;
  size_t write_ret;
  float prev_sample;
  uint32_t peak_width;
  uint32_t curr_peak_pos;
  uint32_t prev_peak_pos;
  uint32_t num_bits;
  uint32_t num_sector_bytes;
  uint32_t byte_start_pos;
  uint32_t byte_width;
  int32_t correction;
  char line_buf[256];
  uint8_t sector_bytes[256 + 3];
  uint32_t max_samples = 10000000;
  const char* p_filename = "sector_in.txt";
  float* p_samples = malloc(max_samples * sizeof(float));
  uint32_t* p_peaks = malloc(max_samples * sizeof(uint32_t));
  uint32_t* p_filtered_peaks = malloc(max_samples * sizeof(uint32_t));
  float weak_peak_threshold = 0.003;
  uint32_t sample_rate = 25000000;
  uint32_t num_samples = 0;
  uint32_t num_peaks = 0;
  uint32_t num_filtered_peaks = 0;
  int debug = 0;

  (void) argc;
  (void) argv;

  p_in_file = fopen(p_filename, "r");
  if (p_in_file == NULL) {
    errx(1, "can't open %s", p_filename);
  }

  i = 0;
  while (1) {
    float f = 0.0;
    char* p_ret = fgets(&line_buf[0], sizeof(line_buf), p_in_file);
    if (p_ret == NULL) {
      if (ferror(p_in_file) != 0) {
        errx(1, "file read error");
      }
      break;
    }
    if (num_samples == max_samples) {
      errx(1, "too many samples");
    }
    (void) sscanf(&line_buf[0], "%f", &f);
    p_samples[num_samples] = f;
    num_samples++;
  }

  fclose(p_in_file);

  (void) printf("Loaded %d samples\n", num_samples);

  /* TheLivingDaylights_BBCMasterDiscVersion_Source_40--BAD_DFI.dfi */
  /* scope_1.txt, t0s0. */
  /*s = 230790;
  dir = 1;*/
  /* scope_1.txt, t0s1. */
  /* s = 391131;
  dir = 1;*/
  /* Repton3_ElkTape_GameDD_40--BAD_DFI.dfi */
  /* scope_1_1.csv, 7th physical sector (T0 S6) */
  /* s = 1174921;
  dir = 1;*/
  /* track19.zip (Repton 3 Elk Tape Editor, track 19 phys sector 6). */
  /*s = 18240;
  dir = -1;*/
  /* track 24, repton 3 elk tape editor, phys sector 6). */
  /* s = 19930;
  dir = 1;
  */
  /* 400rpm r3 elk editor, t20. */
  //s = 18552;
  //dir = -1;
  /* 400rpm r3 elk editor, t21. */
  //s = 19328;
  //dir = -1;
  /* 400rpm r3 elk editor, t22. */
  //s = 17447;
  //dir = -1;
  /* 400rpm r3 elk editor, t23. */
  //s = 17640;
  //dir = -1;
  /* 400rpm r3 elk editor, t24. */
  //s = 17378;
  //dir = -1;
  /* 400rpm r3 elk editor, t28. */
  //s = 18011;
  //dir = -1;
  /* Old McDonalds Farm, track 0, logical sector 0. */
  /* TEC FB-502. */
  s = 20600;
  dir = -1;
  /* Old McDonalds Farm, track 0, logical sector 1. */
  /* TEC FB-502. */
  //s = 26500;
  //dir = -1;
  /* This corresponds to 8us with a 10MHz sample rate, 360rpm. */
  //samples_per_bit = 66;
  /* This corresponds to 8us with a 10MHz sample rate, 400rpm. */
  //samples_per_bit = 60;
  /* This corresponds to 8us with a 25MHz sample rate, 300rpm. */
  //samples_per_bit = 200;
  samples_per_bit = ((sample_rate / 5) / (3125 * 8));

  /* Pass 1: find peak centers. */
  prev_sample = p_samples[s];
  peak_width = 0;
  for (i = s; i < num_samples; ++i) {
    float sample = p_samples[i];
    if (((dir == 1) && (sample > prev_sample)) ||
        ((dir == -1) && (sample < prev_sample))) {
      /* Waveform going in current direction. Continue. */
      peak_width = 0;
    } else if (sample == prev_sample) {
      /* Peak clipped, or saddle. */
      peak_width++;
    } else {
      /* Peak found. */
      uint32_t peak_pos = (i - 1 - (peak_width / 2));
      p_peaks[num_peaks] = peak_pos;
      num_peaks++;
      dir = -dir;
      peak_width = 0;
    }
    prev_sample = sample;
  }

  (void) printf("Found %d peaks\n", num_peaks);

  /* Pass 2: filter out mini wobbles, i.e. series of peaks close together in
   * time.
   */
  for (i = 0; i < num_peaks; ++i) {
    uint32_t peak_pos = p_peaks[i];
    uint32_t j = (i + 1);
    uint32_t num_close_peaks = 0;
    prev_peak_pos = peak_pos;
    /* Look forward for any series of peaks close in time to this one. */
    while (j < num_peaks) {
      uint32_t next_peak_pos = p_peaks[j];
      if ((next_peak_pos - prev_peak_pos) >= 60) {
        break;
      }
      num_close_peaks++;
      prev_peak_pos = next_peak_pos;
      j++;
    }
    if (num_close_peaks == 0) {
      /* No nearby peaks, so accept the peak. */
      p_filtered_peaks[num_filtered_peaks] = peak_pos;
      num_filtered_peaks++;
    } else if (num_close_peaks & 1) {
      /* If it's an odd number of nearby peaks, the signal direction didn't
       * change, so nuke them all.
       */
       i += num_close_peaks;
    } else {
      /* It's an even number of nearby peaks, the signal direction changed, so
       * keep only the middle of the nearby peaks.
       */
      peak_pos = p_peaks[i + (num_close_peaks / 2)];
      p_filtered_peaks[num_filtered_peaks] = peak_pos;
      num_filtered_peaks++;
      i += num_close_peaks;
    }
  }

  (void) printf("After filtering, %d peaks left\n", num_filtered_peaks);

  /* Pass 3: resolve inter-peak timings into FM encoded 1 and 0 bits. */
  /* Standard data marker. */
  sector_bytes[0] = 0xFB;
  num_sector_bytes = 0;
  num_bits = 0;
  byte = 0;
  byte_start_pos = 0;
  byte_width = 0;
  curr_peak_pos = p_filtered_peaks[0];
  correction = 0;
  for (i = 1; i < (num_filtered_peaks - 1); ++i) {
    int bit;
    /* We consider the peaks two at a time. If one peak is a bit "off", we
     * compensate the next peak accordingly.
     * e.g. 
     */
    uint32_t next_peak_pos = p_filtered_peaks[i];
    uint32_t next_next_peak_pos = p_filtered_peaks[i + 1];
    uint32_t delta1_orig = (next_peak_pos - curr_peak_pos);
    uint32_t delta1 = (delta1_orig - correction);
    uint32_t delta2 = (next_next_peak_pos - next_peak_pos);
    uint32_t double_delta = (delta1 + delta2);

    if (num_bits == 0) {
      byte_start_pos = curr_peak_pos;
      byte_width = 0;
    }

    if (double_delta <= 280) {
      bit = 1;
    //} else if (delta1 <= 130) {
    //  bit = 1;
    //} else if (double_delta <= 270) {
    //  bit = 1;
    //} else if ((double_delta - correction) <= 270) {
    //  bit = 1;
    //} else if ((delta1 - correction) <= 124) {
    //  bit = 1;
    } else {
      bit = 0;
    }

    if (bit == 1) {
      byte_width += double_delta;
      ++i;
      curr_peak_pos = next_next_peak_pos;
      correction = (200 - double_delta);
    } else {
      byte_width += delta1;
      curr_peak_pos = next_peak_pos;
      correction = (200 - delta1);
    }
    correction /= 2;
    (void) printf("  bit: %d (deltas %d %d orig %d total %d)\n",
                  bit,
                  delta1,
                  delta2,
                  delta1_orig,
                  double_delta);
    byte <<= 1;
    byte |= bit;
    num_bits++;
    if (num_bits == 8) {
      char c = byte;
      if (!isprint(c)) {
        c = ' ';
      }
      (void) printf("byte %d: %.2X (%c) @%d width %d\n",
                    num_sector_bytes,
                    byte,
                    c,
                    byte_start_pos,
                    byte_width);
      sector_bytes[num_sector_bytes + 1] = byte;
      num_bits = 0;
      byte = 0;
      num_sector_bytes++;
      if (num_sector_bytes == 258) {
        break;
      }
    }
  }

  crc = do_crc16(&sector_bytes[0], 257);
  (void) printf("Calculated CRC16 %.4X\n", crc);

  free(p_samples);
  free(p_peaks);
  free(p_filtered_peaks);

  p_out_file = fopen("sector.bin", "w");
  if (p_out_file == NULL) {
    errx(1, "can't open output file");
  }
  write_ret = fwrite(&sector_bytes[1], 1, 256, p_out_file);
  if (write_ret != 256) {
    errx(1, "can't write output file");
  }

  fclose(p_out_file);

  return 0;
}
