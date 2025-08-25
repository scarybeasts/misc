#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* Logic to generate SN command tables for outputting a u8 linear volume
 * to various different channel setups (1 channel, 2 merged, etc.)
 *
 * Matches modprocessor.js
 */
int
main(int argc, const char** argv) {
  double sn_output[16];
  int u8_to_sn1[256];
  int u8_to_sn2[256];
  int sn1_value[256];
  int sn2_value[256];
  int sample_remap[256];
  int i;
  int j;
  int current_sn1;
  int current_sn2;
  int next_sn1;
  int next_sn2;
  int current_output;
  int next_output;
  int next_switchover;
  int fd;
  double att1;
  double att2;
  double att4;
  double att8;

  int channels = 2;
  double gain = 1.0;
  double offset = 0.0;
  int full = 0;
  int rebalance = 0;
  int is_verbose = 0;
  int sn_channel = 1;

  /* Parse command line. */
  for (i = 1; i < argc; ++i) {
    const char* p_arg = argv[i];
    if ((i + 1) < argc) {
      const char* p_next_arg = argv[i + 1];
      if (!strcmp(p_arg, "-gain")) {
        gain = atof(p_next_arg);
        ++i;
      } else if (!strcmp(p_arg, "-offset")) {
        offset = atof(p_next_arg);
        ++i;
      } else if (!strcmp(p_arg, "-channels")) {
        channels = atoi(p_next_arg);
        ++i;
      } else if (!strcmp(p_arg, "-sn_channel")) {
        sn_channel = atoi(p_next_arg);
        ++i;
      }
    }
    if (!strcmp(p_arg, "-full")) {
      full = 1;
    } else if (!strcmp(p_arg, "-rebalance")) {
      rebalance = 1;
    } else if (!strcmp(p_arg, "-v")) {
      is_verbose = 1;
    }
  }

  /* Initializations. */
  for (i = 0; i < 256; ++i) {
    u8_to_sn1[i] = -1;
    u8_to_sn2[i] = -1;
  }

  /* Calculate output levels for the log scale SN output. */
  /* Range is 0.0 to 1.0. */
  att1 = pow(10.0, -0.1);
  att2 = pow(10.0, -0.2);
  att4 = pow(10.0, -0.4);
  att8 = pow(10.0, -0.8);
  if (rebalance) {
    /* Matches the attenuators for tone 1 and tone 2 on my rickety issue 3. */
    att1 = 0.761;
    att2 = 0.590;
    att4 = 0.413;
    att8 = 0.177;
  }
  for (i = 0; i < 15; ++i) {
    double value = 1.0;
    if (i & 1) value *= att1;
    if (i & 2) value *= att2;
    if (i & 4) value *= att4;
    if (i & 8) value *= att8;
    sn_output[i] = value;
  }
  sn_output[15] = 0.0;

  /* Calculate the available output levels from merged channel output
   * combinations.
   */
  for (i = 0; i < 16; ++i) {
    for (j = 0; j < 16; ++j) {
      double output;
      uint8_t u8_output;

      if (!full) {
        if (j < i) continue;
        if (j > (i + 1)) continue;
      }

      output = sn_output[i];
      if (channels > 1) {
        output += sn_output[j];
      }

      u8_output = (uint8_t) round((output / channels) * 255.0);
      if (u8_to_sn1[u8_output] == -1) {
        if (is_verbose) {
          (void) printf("u8 level: %d\n", u8_output);
        }
        u8_to_sn1[u8_output] = i;
        u8_to_sn2[u8_output] = j;
      }
    }
  }

  /* Generate tables. */
  current_sn1 = 0xF;
  current_sn2 = 0xF;
  next_sn1 = -1;
  next_sn2 = -1;
  current_output = 0;
  next_output = -1;
  next_switchover = -1;
  for (i = 0; i < 256; ++i) {
    unsigned char val;

    if (next_output == -1) {
      for (j = (i + 1); j < 256; ++j) {
        if (u8_to_sn1[j] != -1) {
          next_output = j;
          next_switchover = round(((double) current_output + next_output) / 2);
          next_sn1 = u8_to_sn1[j];
          next_sn2 = u8_to_sn2[j];
          break;
        }
      }
    }

    if (i == next_switchover) {
      if (is_verbose) {
        /* TODO: this is printing weird results for 1 channel, although the
         * eventual lookup table looks ok.
         */
        (void) printf("switchover: %d, levels %d %d\n",
                      i,
                      next_sn1,
                      next_sn2);
      }
      current_output = next_output;
      next_output = -1;
      current_sn1 = next_sn1;
      current_sn2 = next_sn2;
    }

    val = (current_sn1 | (0x70 + (sn_channel * 0x20)));
    sn1_value[i] = val;
    val = (current_sn2 | (0x70 + ((sn_channel + 1) * 0x20)));
    sn2_value[i] = val;
  }

  /* Apply gain and offset. */
  for (i = 0; i < 256; ++i) {
    double sample_value = (i - 128);
    sample_value *= gain;
    sample_value += offset;
    sample_value = round(sample_value);
    if (sample_value < -128) {
      sample_value = -128;
    } else if (sample_value > 127) {
      sample_value = 127;
    }
    sample_value += 128;

    sample_remap[i] = sample_value;
  }

  /* Write out tables. */
  for (i = 0; i < 256; ++i) {
    unsigned char val;
    int index = sample_remap[i];
    val = sn1_value[index];
    write(1, &val, 1);
  }
  if (channels > 1) {
    for (i = 0; i < 256; ++i) {
      unsigned char val;
      int index = sample_remap[i];
      val = sn2_value[index];
      write(1, &val, 1);
    }
  }

  return 0;
}
