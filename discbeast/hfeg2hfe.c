#include <assert.h>
#include <err.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int s_is_verbose;

static const int k_max_num_tracks = 82;
/* Each block is 512 bytes, 256 per side. */
static const int k_hfe_blocks_per_track = 50;
/* NOTE: cannot be increased without re-evaluating k_hfe_blocks_per_track. */
static const int k_max_track_length = 3190;

static const int k_standard_track_length = 3125;

static uint16_t
get16(uint8_t* p_buf) {
  uint16_t ret = p_buf[0];
  ret |= (p_buf[1] << 8);
  return ret;
}

static void
put16(uint8_t* p_buf, uint16_t val) {
  p_buf[0] = val;
  p_buf[1] = (val >> 8);
}

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

static void
hfe_convert_to_bits(uint8_t* p_buf, uint8_t data, uint8_t clocks) {
  uint8_t b0 = 0;
  uint8_t b1 = 0;
  uint8_t b2 = 0;
  uint8_t b3 = 0;

  if (data & 0x80) b0 |= 0x08;
  if (data & 0x40) b0 |= 0x80;
  if (data & 0x20) b1 |= 0x08;
  if (data & 0x10) b1 |= 0x80;
  if (data & 0x08) b2 |= 0x08;
  if (data & 0x04) b2 |= 0x80;
  if (data & 0x02) b3 |= 0x08;
  if (data & 0x01) b3 |= 0x80;
  if (clocks & 0x80) b0 |= 0x02;
  if (clocks & 0x40) b0 |= 0x20;
  if (clocks & 0x20) b1 |= 0x02;
  if (clocks & 0x10) b1 |= 0x20;
  if (clocks & 0x08) b2 |= 0x02;
  if (clocks & 0x04) b2 |= 0x20;
  if (clocks & 0x02) b3 |= 0x02;
  if (clocks & 0x01) b3 |= 0x20;

  p_buf[0] = b0;
  p_buf[1] = b1;
  p_buf[2] = b2;
  p_buf[3] = b3;
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

static void
do_crc16(uint16_t* p_crc, uint8_t* p_buf, uint32_t len) {
  uint32_t i;
  uint32_t j;
  uint16_t crc = *p_crc;

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

  *p_crc = crc;
}

static void
do_crc32(uint32_t* p_crc, uint8_t* p_buf, uint32_t len) {
  uint32_t i;
  uint32_t j;
  uint32_t crc = *p_crc;

  for (i = 0; i < len; ++i) {
    uint8_t byte = p_buf[i];
    crc = (crc ^ byte);
    for (j = 0; j < 8; ++j) {
      int do_eor = (crc & 1);
      crc = (crc >> 1);
      if (do_eor) {
        crc ^= 0xEDB88320;
      }
    }
  }
  *p_crc = crc;
}

static uint32_t
load_trks_files(uint8_t* p_buf, const char* p_path_prefix) {
  char path[256];
  FILE* f;
  uint32_t i;
  size_t fread_ret;
  int ret;

  uint32_t num_tracks = 0;

  for (i = 0; i <= 80; i += 2) {
    if (!(i & 1)) {
      (void) snprintf(path, sizeof(path), "%s/TRKS%d", p_path_prefix, i);
      f = fopen(path, "r");
      if (f == NULL) {
        (void) snprintf(path, sizeof(path), "%s/$.TRKS%d", p_path_prefix, i);
        f = fopen(path, "r");
        if (f == NULL) {
          return num_tracks;
        }
      }
      fread_ret = fread(p_buf, 8192, 1, f);
      ret = fclose(f);
      if (ret != 0) {
        errx(1, "fclose failed");
      }
      if (fread_ret != 1) {
        errx(1, "incorrect TRKS file size");
      }
      if (p_buf[0] == 0) {
        errx(1, "empty TRKS file");
      }
      num_tracks++;
      if (p_buf[4096] == 0) {
        return num_tracks;
      }
      num_tracks++;
      p_buf += 8192;
    }
  }
}

static void
fixup_marker(uint8_t* p_track_data, uint32_t pos) {
  uint32_t i;

  if (pos < 6) {
    errx(1, "marker too early");
  }
  p_track_data[pos] |= 0xF0;
  if ((p_track_data[pos - 1] != 0) ||
      (p_track_data[pos - 2] != 0)) {
    for (i = 0; i < 6; ++i) {
      p_track_data[pos - 1 - i] = 0;
    }
  }
}

static void
convert_tracks(uint8_t* p_hfe_buf,
               uint32_t* p_track_lengths,
               int is_second_side,
               uint8_t* p_trks_buf,
               int do_expand,
               uint32_t num_tracks) {
  uint32_t i;
  uint32_t expand_factor;

  uint32_t disc_crc32 = 0xFFFFFFFF;

  expand_factor = 1;
  if (do_expand) {
    assert((num_tracks * 2) <= k_max_num_tracks);
    expand_factor = 2;
  }

  for (i = 0; i < num_tracks; ++i) {
    uint8_t is_marker[k_max_track_length];
    uint32_t num_sectors;
    uint32_t track_length;
    uint32_t j;
    uint32_t hfe_track_pos;
    uint8_t clocks;
    uint8_t data;

    uint32_t track_crc32 = 0xFFFFFFFF;
    uint8_t* p_in_track = (p_trks_buf + (i * 4096));
    uint8_t* p_out_track = p_hfe_buf;
    p_out_track += 1024;
    p_out_track += (i * expand_factor * k_hfe_blocks_per_track * 512);
    if (is_second_side) {
      p_out_track += 256;
    }

    if (p_in_track[1] != i) {
      errx(1, "mismatched track number");
    }
    num_sectors = p_in_track[5];
    if (num_sectors > 32) {
      errx(1, "excessive number of sectors");
    }
    track_length = get16(p_in_track + 6);
    /* The track length may not have been stored, depending on controller chip
     * and whether the track is formatted or not.
     */
    if (track_length == 0) {
      track_length = k_standard_track_length;
    }
    if ((track_length < 3000) || (track_length > 3190)) {
      errx(1, "bad track length");
    }

    p_track_lengths[i] = track_length;

    /* Build a list of where the markers are and check CRCs. */
    (void) memset(is_marker, '\0', sizeof(is_marker));
    for (j = 0; j < num_sectors; ++j) {
      uint32_t k;
      uint16_t pos;
      uint16_t crc16_calc;
      uint16_t crc16_disc;
      uint32_t length;
      int is_data_crc_error;

      /* Sector header. */
      pos = get16(p_in_track + 0x100 + (j * 2));
      if (is_marker[pos]) {
        errx(1, "overlapping marker");
      }
      is_marker[pos] = 1;
      data = p_in_track[0x200 + pos];
      if ((data != 0xFE) && (data != 0xCE)) {
        errx(1, "bad header marker byte 0x%.2X", data);
      }
      fixup_marker(&p_in_track[0x200], pos);
      crc16_calc = 0xFFFF;
      do_crc16(&crc16_calc, (p_in_track + 0x200 + pos), 5);
      crc16_disc = ((p_in_track[0x200 + pos + 5]) << 8);
      crc16_disc |= p_in_track[0x200 + pos + 6];
      if (crc16_calc != crc16_disc) {
        (void) printf("Header CRC error, physical track / sector %d / %d\n",
                      i,
                      j);
      }

      /* Sector data. */
      pos = get16(p_in_track + 0x140 + (j * 2));
      if (is_marker[pos]) {
        errx(1, "overlapping marker");
      }
      is_marker[pos] = 1;
      data = p_in_track[0x200 + pos];
      if ((data != 0xF8) &&
          (data != 0xC8) &&
          (data != 0xFB) &&
          (data != 0xCB)) {
        errx(1, "bad data marker byte 0x%.2X", data);
      }
      fixup_marker(&p_in_track[0x200], pos);
      length = (p_in_track[0xe0 + j] & 7);
      if (length > 4) {
        errx(1, "bad real sector length");
      }
      length = (128 << length);
      crc16_calc = 0xFFFF;
      do_crc16(&crc16_calc, (p_in_track + 0x200 + pos), (length + 1));
      crc16_disc = ((p_in_track[0x200 + pos + length + 1]) << 8);
      crc16_disc |= p_in_track[0x200 + pos + length + 2];
      is_data_crc_error = (crc16_calc != crc16_disc);
      if (is_data_crc_error) {
        (void) printf("Data CRC error, physical track / sector %d / %d\n",
                      i,
                      j);
      } else {
        uint8_t logical_track = p_in_track[0x20 + (j * 4)];
        /* 8271 has problems with logical track 0 not on physical track 0 so
         * don't include in CRC32.
         */
        if ((i != 0) && (logical_track == 0)) {
          /* Ignore. */
        } else if (logical_track == 0xFF) {
          /* Ignore. */
        } else {
          do_crc32(&track_crc32, (p_in_track + 0x200 + pos), (length + 1));
        }
      }
    }

    /* Update disc CRC32. */
    track_crc32 = ~track_crc32;
    if (s_is_verbose) {
      (void) printf("Track %d sectors %d length %d CRC32 %X\n",
                    i,
                    num_sectors,
                    track_length,
                    track_crc32);
    }
    do_crc32(&disc_crc32, (uint8_t*) &track_crc32, 4);

    /* Per-track HFEv3 opcode set up. */
    hfe_track_pos = 0;
    /* Index. */
    hfe_add(p_out_track, &hfe_track_pos, flip(0xF1));
    /* Set bitrate to 250kbit. */
    hfe_add(p_out_track, &hfe_track_pos, flip(0xF2));
    hfe_add(p_out_track, &hfe_track_pos, flip(72));

    /* Copy over the data and calculated clocks into the HFE. */
    for (j = 0; j < track_length; ++j) {
      uint8_t hfe_bits[4];

      clocks = 0xFF;
      data = p_in_track[0x200 + j];
      if (is_marker[j]) {
        clocks = 0xC7;
      }
      hfe_convert_to_bits(hfe_bits, data, clocks);
      hfe_add(p_out_track, &hfe_track_pos, hfe_bits[0]);
      hfe_add(p_out_track, &hfe_track_pos, hfe_bits[1]);
      hfe_add(p_out_track, &hfe_track_pos, hfe_bits[2]);
      hfe_add(p_out_track, &hfe_track_pos, hfe_bits[3]);
    }
  }
  disc_crc32 = ~disc_crc32;
  (void) printf("Disc CRC32: %X\n", disc_crc32);
}

int
main(int argc, const char* argv[]) {
  FILE* f;
  uint32_t i;
  uint8_t trks_buf_drv0[k_max_num_tracks * 4096];
  uint8_t trks_buf_drv2[k_max_num_tracks * 4096];
  uint32_t track_lengths_drv0[k_max_num_tracks];
  uint32_t track_lengths_drv2[k_max_num_tracks];
  uint8_t hfe_buf[(k_max_num_tracks * k_hfe_blocks_per_track * 512) + 1024];
  size_t fwrite_ret;
  int ret;
  uint32_t hfe_length;
  uint32_t num_tracks;
  uint32_t num_sides;

  int do_expand_drv0 = 0;
  int do_expand_drv2 = 0;
  uint32_t num_tracks_drv0 = 0;
  uint32_t num_tracks_drv2 = 0;
  const char* p_capture_chip = NULL;

  for (i = 0; i < (uint32_t) argc; ++i) {
    if (!strcmp(argv[i], "-v")) {
      s_is_verbose = 1;
    }
  }

  (void) memset(trks_buf_drv0, '\0', sizeof(trks_buf_drv0));
  (void) memset(trks_buf_drv2, '\0', sizeof(trks_buf_drv2));
  (void) memset(track_lengths_drv0, '\0', sizeof(track_lengths_drv0));
  (void) memset(track_lengths_drv2, '\0', sizeof(track_lengths_drv2));
  (void) memset(hfe_buf, '\0', sizeof(hfe_buf));

  num_tracks_drv0 = load_trks_files(trks_buf_drv0, "drv0");
  if (num_tracks_drv0) {
    num_tracks_drv2 = load_trks_files(trks_buf_drv2, "drv2");
  } else {
    num_tracks_drv0 = load_trks_files(trks_buf_drv0, ".");
  }

  num_tracks = num_tracks_drv0;
  if (num_tracks_drv2 > num_tracks) {
    num_tracks = num_tracks_drv2;
  }
  (void) printf("Tracks: %d\n", num_tracks);
  if (num_tracks == 0) {
    errx(1, "no tracks");
  }

  if (num_tracks_drv2 > 0) {
    num_sides = 2;
    (void) printf("Double sided\n");
    if ((num_tracks_drv0 <= (k_max_num_tracks / 2)) &&
        (num_tracks_drv2 >= 80)) {
      do_expand_drv0 = 1;
    }
  } else {
    num_sides = 1;
    (void) printf("Single sided\n");
  }

  if (trks_buf_drv0[0] == 1) {
    p_capture_chip = "8271";
  } else if (trks_buf_drv0[0] == 2) {
    p_capture_chip = "1770";
  } else {
    errx(1, "unknown capture chip");
  }
  (void) printf("Captured with: %s\n", p_capture_chip);
  (void) printf("Drive speed: %d\n", get16(&trks_buf_drv0[2]));

  convert_tracks(hfe_buf,
                 track_lengths_drv0,
                 0,
                 trks_buf_drv0,
                 do_expand_drv0,
                 num_tracks_drv0);
  if (num_tracks_drv2 > 0) {
    convert_tracks(hfe_buf,
                   track_lengths_drv2,
                   1,
                   trks_buf_drv2,
                   do_expand_drv2,
                   num_tracks_drv2);
  }

  /* Write HFE track position metadata. */
  for (i = 0; i < num_tracks; ++i) {
    uint32_t track_length = track_lengths_drv0[i];
    if (track_lengths_drv2[i] > track_length) {
      track_length = track_lengths_drv2[i];
    }
    put16((hfe_buf + 512 + (i * 4)), (2 + (i * k_hfe_blocks_per_track)));
    put16((hfe_buf + 512 + (i * 4) + 2), ((track_length * 8) + 6));
  }

  /* Write HFEv3 header. */
  (void) memset(hfe_buf, '\xff', 512);
  (void) strcpy(hfe_buf, "HXCHFEV3");
  /* Revision 0. */
  hfe_buf[8] = 0;
  /* Number of tracks. */
  hfe_buf[9] = num_tracks;
  /* 1 or 2 sides. */
  hfe_buf[10] = num_sides;
  /* IBM FM encoding. */
  hfe_buf[11] = 2;
  /* 250kbit. */
  hfe_buf[12] = 0xFA;
  hfe_buf[13] = 0;
  /* 300rpm. */
  hfe_buf[14] = 0x2C;
  hfe_buf[15] = 0x1;
  /* Shugart interface. */
  hfe_buf[16] = 7;
  /* 1 == 512 byte LUT offset. */
  hfe_buf[18] = 1;
  hfe_buf[19] = 0;

  f = fopen("out.hfe", "w");
  if (f == NULL) {
    errx(1, "couldn't open output file");
  }
  hfe_length = ((num_tracks * k_hfe_blocks_per_track * 512) + 1024);
  fwrite_ret = fwrite(hfe_buf, hfe_length, 1, f);
  if (fwrite_ret != 1) {
    errx(1, "fwrite failed");
  }
  ret = fclose(f);
  if (ret != 0) {
    errx(1, "fclose failed");
  }

  exit(0);
}
