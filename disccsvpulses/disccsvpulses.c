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
  uint32_t num_samples;
  uint32_t samples_per_bit;
  uint32_t s;
  uint32_t i;
  uint32_t i_bytes;
  int dir;
  uint8_t byte;
  uint32_t byte_samples_start;
  uint16_t crc;
  size_t write_ret;
  char line_buf[256];
  uint8_t sector_bytes[256 + 3];
  uint32_t max_samples = 2000000;
  const char* p_filename = "scope_1_1.txt";
  float* p_samples = malloc(max_samples * sizeof(float));
  float weak_peak_threshold = 0.035;
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

  /* TheLivingDaylights_BBCMasterDiscVersion_Source_40--BAD_DFI.dfi */
  /* scope_1.txt, t0s0. */
  /*s = 230790;
  dir = 1;*/
  /* scope_1.txt, t0s1. */
  /* s = 391131;
  dir = 1;*/
  /* Repton3_ElkTape_GameDD_40--BAD_DFI.dfi */
  /* scope_1_1.csv, 7th physical sector (T0 S6) */
  s = 1174921;
  dir = 1;
  /* This corresponds to 8us with a 10MHz sample rate, 360rpm. */
  samples_per_bit = 66;

  byte = 0;
  byte_samples_start = 0;
  /* Standard data marker. */
  sector_bytes[0] = 0xFB;
  i_bytes = 1;
  for (i = 0; i < ((256 + 2) * 8); ++i) {
    if ((i & 7) == 0) {
      byte_samples_start = s;
      byte = 0;
    }
    uint32_t j;
    uint32_t scan_start;
    uint32_t scan_end;
    int bit;
    float curr_v = p_samples[s];
    float full_v = p_samples[s + samples_per_bit];
    float half_v = p_samples[s + (samples_per_bit / 2)];

    if (debug) {
      (void) printf("half/full after peak @%d: %f %f\n", s, half_v, full_v);
    }

    /* Decide if there was 1 peak or 2 in this time slice. */
    bit = -1;
    if (dir == 1) {
      if (half_v < curr_v) {
        (void) printf("upwards went down!\n");
      }
      if (full_v >= half_v) {
        bit = 0;
      } else {
        float half_delta = (half_v - full_v);
        bit = 1;
        if (half_delta < weak_peak_threshold) {
          (void) printf("weak middle peak\n");
          bit = 0;
        }
      }
    } else {
      if (half_v > curr_v) {
        (void) printf("downwards went up!\n");
      }
      if (full_v <= half_v) {
        bit = 0;
      } else {
        bit = 1;
        float half_delta = (full_v - half_v);
        if (half_delta < weak_peak_threshold) {
          (void) printf("weak middle peak\n");
          bit = 0;
        }
      }
    }
    if (bit == 0) {
      dir = -dir;
    }

    /* Advance. */
    s += samples_per_bit;
    /* Resync to any nearby larger maximum. */
    scan_start = (s - 8);
    scan_end = (s + 8);
    for (j = scan_start; j <= scan_end; ++j) {
      int is_better_peak = 0;
      float check_v = p_samples[j];
      if (dir == -1) {
        if (check_v > full_v) {
          is_better_peak = 1;
        }
      } else {
        if (check_v < full_v) {
          is_better_peak = 1;
        }
      }
      if (is_better_peak) {
        full_v = check_v;
        s = j;
      }
    }

    /* Build a byte from the bits. */
    byte <<= 1;
    byte |= bit;
    if ((i & 7) == 7) {
      char c = byte;
      if ((c < 32) || (c >= 127)) {
        c = ' ';
      }
      (void) printf("byte: %.2X (%c) @%d\n", byte, c, byte_samples_start);
      sector_bytes[i_bytes] = byte;
      i_bytes++;
    }
  }

  crc = do_crc16(&sector_bytes[0], 257);
  (void) printf("calculated CRC16 %.4X\n", crc);

  free(p_samples);

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
