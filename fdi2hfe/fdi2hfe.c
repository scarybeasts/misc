#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "fdi2raw.h"

/* Each block is 512 bytes, 256 per side. */
static const uint32_t k_hfe_dd_blocks_per_track = 50;
/* NOTE: cannot be increased without re-evaluating k_hfe_dd_blocks_per_track. */
static const uint32_t k_hfe_dd_max_track_length = 3190;

static uint8_t
flip(uint8_t val) {
  uint8_t ret = 0;

  if (val & 0x80) ret |= 0x01;
  if (val & 0x40) ret |= 0x02;
  if (val & 0x20) ret |= 0x04;
  if (val & 0x10) ret |= 0x08;
  if (val & 0x08) ret |= 0x10;
  if (val & 0x04) ret |= 0x20;
  if (val & 0x02) ret |= 0x40;
  if (val & 0x01) ret |= 0x80;

  return ret;
}

static uint16_t
hfe_convert_fm_to_hfe(uint8_t val) {
  uint16_t ret = 0;
  if (val & 0x80) ret |= 0x0200;
  if (val & 0x40) ret |= 0x0800;
  if (val & 0x20) ret |= 0x2000;
  if (val & 0x10) ret |= 0x8000;
  if (val & 0x08) ret |= 0x0002;
  if (val & 0x04) ret |= 0x0008;
  if (val & 0x02) ret |= 0x0020;
  if (val & 0x01) ret |= 0x0080;
  return ret;
}

static void
hfe_add(uint8_t* p_hfe_buf, uint32_t* p_hfe_track_pos, uint8_t byte) {
  uint32_t hfe_track_pos = *p_hfe_track_pos;
  p_hfe_buf[hfe_track_pos] = byte;
  hfe_track_pos++;
  if ((hfe_track_pos % 256) == 0) {
    hfe_track_pos += 256;
  }
  *p_hfe_track_pos = hfe_track_pos;
}

int
main(int argc, const char* argv[]) {
  uint32_t i;
  FILE* f_in;
  FILE* f_out;
  FDI* p_fdi;
  int ret;
  uint32_t num_heads;
  uint32_t num_tracks;
  uint32_t num_actual_tracks;
  uint16_t pulses_buf[65536];
  uint16_t timing_buf[65536];
  uint32_t track_lengths[81];
  int i_track;
  uint8_t* p_hfe_buf;
  uint32_t hfe_length;
  size_t fwrite_ret;
  uint32_t hfe_buf_size;

  uint32_t mfm_multiplier = 1;
  uint32_t hd_multiplier = 1;
  const char* p_filename = "test.fdi";
  int is_mfm = 0;
  int is_double_sided = 0;
  int is_hd = 0;
  uint32_t max_track_length = k_hfe_dd_max_track_length;
  uint32_t blocks_per_track = k_hfe_dd_blocks_per_track;

  for (i = 0; i < argc; ++i) {
    if (!strcmp(argv[i], "-mfm")) {
      is_mfm = 1;
    } else if (!strcmp(argv[i], "-ds")) {
      is_double_sided = 1;
    } else if (!strcmp(argv[i], "-hd")) {
      is_hd = 1;
    }
  }

  hfe_buf_size = (81 * k_hfe_dd_blocks_per_track * 512);
  if (is_mfm) {
    mfm_multiplier = 2;
    max_track_length *= mfm_multiplier;
  }
  if (is_hd) {
    hd_multiplier = 2;
    max_track_length *= hd_multiplier;
    blocks_per_track *= hd_multiplier;
  }
  hfe_buf_size = (81 * blocks_per_track * 512);
  hfe_buf_size += 1024;

  f_in = fopen(p_filename, "rb");

  if (f_in == NULL) {
    errx(1, "couldn't open %s", p_filename);
  }

  p_hfe_buf = malloc(hfe_buf_size);
  (void) memset(p_hfe_buf, '\0', hfe_buf_size);

  (void) memset(track_lengths, '\0', sizeof(track_lengths));

  p_fdi = fdi2raw_header(f_in);
  if (p_fdi == NULL) {
    errx(1, "couldn't parse FDI header");
  }
  num_heads = fdi2raw_get_last_head(p_fdi);
  if (num_heads != 1) {
    errx(1, "number of heads is not 1: %d", num_heads);
  }
  num_tracks = fdi2raw_get_last_track(p_fdi);
  num_actual_tracks = num_tracks;
  if (is_double_sided) {
    num_actual_tracks /= 2;
  }
  (void) printf("Heads, tracks: %d, %d\n", num_heads, num_tracks);
  if (num_actual_tracks > 81) {
    errx(1, "too many tracks %d (max 81)", num_actual_tracks);
  }

  for (i_track = 0; i_track < num_tracks; ++i_track) {
    int i_fm;
    uint8_t* p_out_buf;

    int track_length = -1;
    int index_offset = -1;
    int multi_rev = -1;
    uint32_t hfe_track_pos = 0;
    uint32_t actual_track = i_track;
    int actual_head = 0;

    if (is_double_sided) {
      actual_track = (i_track / 2);
      actual_head = (i_track & 1);
    }

    ret = fdi2raw_loadtrack(p_fdi,
                            &pulses_buf[0],
                            &timing_buf[0],
                            i_track,
                            &track_length,
                            &index_offset,
                            &multi_rev,
                            is_mfm);
    track_length = (track_length / 16);
    (void) printf("Track %d ret %d length %d index %d multi %d\n",
                  i_track,
                  ret,
                  track_length,
                  index_offset,
                  multi_rev);
    if (ret != 1) {
      track_length = (3125 * mfm_multiplier * hd_multiplier);
      if (track_length > track_lengths[actual_track]) {
        track_lengths[actual_track] = track_length;
      }
      continue;
    }
    if (track_length > max_track_length) {
      (void) printf("track too long, truncating (max %d)\n", max_track_length);
      track_length = max_track_length;
    }
    if (track_length > track_lengths[actual_track]) {
      track_lengths[actual_track] = track_length;
    }

    p_out_buf = (p_hfe_buf + 1024);
    p_out_buf += (actual_track * blocks_per_track * 512);
    if (actual_head == 1) {
      p_out_buf += 256;
    }
    /* Index and 250kbit or 500kbit bit rate. */
    hfe_add(p_out_buf, &hfe_track_pos, flip(0xF1));
    hfe_add(p_out_buf, &hfe_track_pos, flip(0xF2));
    if (is_hd) {
      hfe_add(p_out_buf, &hfe_track_pos, flip(72));
    } else {
      hfe_add(p_out_buf, &hfe_track_pos, flip(72));
    }

    for (i_fm = 0; i_fm < track_length; ++i_fm) {
      uint16_t pulses_val = pulses_buf[i_fm];
      if (is_mfm) {
        uint8_t hfe_byte;
        hfe_byte = (pulses_val >> 8);
        hfe_add(p_out_buf, &hfe_track_pos, flip(hfe_byte));
        hfe_byte = (pulses_val & 0xff);
        hfe_add(p_out_buf, &hfe_track_pos, flip(hfe_byte));
      } else {
        uint16_t hfe_val;
        hfe_val = hfe_convert_fm_to_hfe(pulses_val >> 8);
        hfe_add(p_out_buf, &hfe_track_pos, (hfe_val >> 8));
        hfe_add(p_out_buf, &hfe_track_pos, (hfe_val & 0xff));
        hfe_val = hfe_convert_fm_to_hfe(pulses_val & 0xff);
        hfe_add(p_out_buf, &hfe_track_pos, (hfe_val >> 8));
        hfe_add(p_out_buf, &hfe_track_pos, (hfe_val & 0xff));
      }
    }
  }

  if (num_tracks > 41) {
    num_tracks = 81;
  } else {
    num_tracks = 41;
  }

  for (i_track = 0; i_track < num_actual_tracks; ++i_track) {
    if (track_lengths[i_track] == 0) {
      track_lengths[i_track] = (3125 * mfm_multiplier);
    }
  }

  /* HFEv3 header. */
  (void) memset(p_hfe_buf, '\xff', 512);
  (void) strcpy((char*) p_hfe_buf, "HXCHFEV3");
  /* Revision 0. */
  p_hfe_buf[8] = 0;
  /* Number of tracks. */
  p_hfe_buf[9] = num_actual_tracks;
  /* 1 or 2 sides. */
  p_hfe_buf[10] = (is_double_sided + 1);
  /* IBM MFM or FM encoding. */
  if (is_mfm) {
    p_hfe_buf[11] = 0;
  } else {
    p_hfe_buf[11] = 2;
  }
  /* 250kbit or 500kbit. */
  if (is_hd) {
    p_hfe_buf[12] = 0xF4;
    p_hfe_buf[13] = 0x01;
  } else {
    p_hfe_buf[12] = 0xFA;
    p_hfe_buf[13] = 0;
  }
  /* 300rpm or 360rpm. */
  if (is_hd) {
    p_hfe_buf[14] = 0x68;
    p_hfe_buf[15] = 0x01;
  } else {
    p_hfe_buf[14] = 0x2C;
    p_hfe_buf[15] = 0x01;
  }
  /* Shugart interface. */
  if (is_hd) {
    p_hfe_buf[16] = 1;
  } else {
    p_hfe_buf[16] = 7;
  }
  /* 1 == 512 byte LUT offset. */
  p_hfe_buf[18] = 1;
  p_hfe_buf[19] = 0;

  /* HFE track offset metadata. */
  for (i_track = 0; i_track < num_actual_tracks; ++i_track) {
    uint8_t* p_metadata = (p_hfe_buf + 512 + (i_track * 4));
    uint32_t meta_offset = (2 + (i_track * blocks_per_track));
    uint32_t meta_len = ((track_lengths[i_track] * (8 / mfm_multiplier)) + 6);

    p_metadata[0] = meta_offset;
    p_metadata[1] = (meta_offset >> 8);
    p_metadata[2] = meta_len;
    p_metadata[3] = (meta_len >> 8);
  }

  f_out = fopen("out.hfe", "wb");
  if (f_out == NULL) {
    errx(1, "couldn't open output file");
  }
  hfe_length = ((num_tracks * blocks_per_track * 512) + 1024);
  fwrite_ret = fwrite(p_hfe_buf, hfe_length, 1, f_out);
  if (fwrite_ret != 1) {
    errx(1, "fwrite failed");
  }
  ret = fclose(f_out);
  if (ret != 0) {
    errx(1, "fclose failed");
  }

  free(p_hfe_buf);
  fdi2raw_header_free(p_fdi);
  ret = fclose(f_in);
  if (ret != 0) {
    errx(1, "fclose failed");
  }

  exit(0);
}
