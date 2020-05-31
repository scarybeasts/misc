#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static double k_bbc_volume_factor = -0.1;
static int k_flip = 0;

static int s_haircut = 32;
static int s_exp_scale = 1;

static uint8_t s_u8_to_bbc4[256];
static uint8_t s_bbc_volumes[16];


static void
build_volume_table() {
  int32_t i;
  uint8_t bbc_vol;
  uint8_t next_vol_change;

  for (i = 0; i < 16; ++i) {
    double volume = (1.0 * pow(10.0, (k_bbc_volume_factor * i)));
    uint8_t u8_val = (255 * volume);
    s_bbc_volumes[i] = u8_val;
  }
  s_bbc_volumes[15] = 0;

  bbc_vol = 0;
  if (s_exp_scale) {
    next_vol_change = ((s_bbc_volumes[0] + s_bbc_volumes[1]) / 2);
  } else {
    next_vol_change = 0xf8;
  }

  for (i = 255; i >= 0; --i) {
    s_u8_to_bbc4[i] = bbc_vol;
    if ((i == next_vol_change) && (bbc_vol < 15)) {
      bbc_vol++;
      if (bbc_vol < 15) {
        if (s_exp_scale) {
          next_vol_change =
              ((s_bbc_volumes[bbc_vol] + s_bbc_volumes[(bbc_vol + 1)]) / 2);
        } else {
          next_vol_change -= 0x10;
        }
      }
    }
  }

  for (i = 0; i < 256; ++i) {
printf("%d: %d\n", i, s_u8_to_bbc4[i]);
  }
}

static uint8_t
byte_haircut(uint8_t byte, int haircut) {
  double max = (0xFF - (haircut * 2));

  if (byte < haircut) {
    byte = haircut;
  }
  if (byte > (0xFF - haircut)) {
    byte = (0xFF - haircut);
  }

  byte -= haircut;

  byte = ((byte / max) * 255);

  return byte;
}

int
main(int argc, const char* argv[]) {
  uint8_t* p_in_buf;
  uint8_t* p_out_buf;
  FILE* file_in;
  FILE* file_out;
  size_t len;
  size_t i;

  for (i = 0; i < argc; ++i) {
    const char* p_arg = argv[i];
    const char* p_next_arg = NULL;
    if (i != (argc - 1)) {
      p_next_arg = argv[i + 1];
    }
    if (!strcmp(p_arg, "-l")) {
      s_exp_scale = 0;
    } else if (!strcmp(p_arg, "-h") && (p_next_arg != NULL)) {
      s_haircut = atoi(p_next_arg);
      ++i;
    }
  }

  build_volume_table();

  /* Yes, yes, lack of error checking! */
  file_in = fopen("input.u8", "r");
  fseek(file_in, 0, SEEK_END);
  len = ftell(file_in);
  fseek(file_in, 0, SEEK_SET);

  p_in_buf = malloc(len);
  fread(p_in_buf, len, 1, file_in);
  fclose(file_in);

  p_out_buf = malloc(len / 2);

  for (i = 0; i < len; i += 2) {
    uint8_t val1;
    uint8_t val2;
    uint8_t merged;
    uint8_t byte1 = p_in_buf[i];
    uint8_t byte2 = p_in_buf[i + 1];
    if (s_haircut) {
      byte1 = byte_haircut(byte1, s_haircut);
      byte2 = byte_haircut(byte2, s_haircut);
    }
    val1 = s_u8_to_bbc4[byte1];
    val2 = s_u8_to_bbc4[byte2];
    if (k_flip) {
      val1 ^= 0xF;
      val2 ^= 0xF;
    }
    merged = ((val1 << 4) | val2);

    p_out_buf[i / 2] = merged;
  }

  file_out = fopen("output.u4", "w");
  fwrite(p_out_buf, (len / 2), 1, file_out);
  fclose(file_out);

  return 0;
}
