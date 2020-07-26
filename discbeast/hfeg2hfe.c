#include <assert.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int s_is_verbose;
static int s_is_no_check_beeb_crc;
static int s_is_double_step;

static const uint32_t k_max_num_tracks = 82;
/* Each block is 512 bytes, 256 per side. */
static const uint32_t k_hfe_blocks_per_track = 50;
/* NOTE: cannot be increased without re-evaluating k_hfe_blocks_per_track. */
static const uint32_t k_max_track_length = 3190;

static const uint32_t k_standard_track_length = 3125;

static void
bail(const char* p_msg, ...) {
  va_list args;
  char msg[256];

  va_start(args, p_msg);
  msg[0] = '\0';
  (void) vsnprintf(msg, sizeof(msg), p_msg, args);
  va_end(args);

  (void) fprintf(stderr, "BAILING: %s\n", msg);

  exit(1);
  /* Not reached. */
}

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
      f = fopen(path, "rb");
      if (f == NULL) {
        (void) snprintf(path, sizeof(path), "%s/$.TRKS%d", p_path_prefix, i);
        f = fopen(path, "rb");
        if (f == NULL) {
          return num_tracks;
        }
      }
      fread_ret = fread(p_buf, 8192, 1, f);
      ret = fclose(f);
      if (ret != 0) {
        bail("fclose failed");
      }
      if (fread_ret != 1) {
        bail("incorrect TRKS file size");
      }
      if (p_buf[0] == 0) {
        bail("empty TRKS file");
      }
      num_tracks++;
      if (p_buf[4096] == 0) {
        return num_tracks;
      }
      num_tracks++;
      p_buf += 8192;
    }
  }

  return num_tracks;
}

static int
fixup_marker(uint8_t* p_track_data, uint32_t pos) {
  uint32_t i;
  int did_fixup = 0;

  if (pos < 6) {
    bail("marker too early");
  }
  if ((p_track_data[pos] & 0xF0) != 0xF0) {
    p_track_data[pos] |= 0xF0;
    did_fixup = 1;
  }
  if ((p_track_data[pos - 1] != 0) ||
      (p_track_data[pos - 2] != 0)) {
    for (i = 0; i < 6; ++i) {
      p_track_data[pos - 1 - i] = 0;
    }
    did_fixup = 1;
  }

  return did_fixup;
}

static void
convert_tracks(uint8_t* p_hfe_buf,
               uint32_t* p_track_lengths,
               int is_second_side,
               uint8_t* p_trks_buf,
               int do_expand,
               int do_double_step,
               uint32_t num_tracks) {
  uint32_t i;
  uint32_t expand_factor;
  uint32_t shrink_factor;
  uint32_t beeb_crc32;
  uint32_t step_count;

  uint32_t disc_crc32 = 0xFFFFFFFF;
  uint32_t disc_crc32_double_step = 0xFFFFFFFF;
  uint8_t* p_in_track = NULL;
  uint8_t* p_first_sector_data = NULL;
  uint8_t* p_t0_s0_data = NULL;
  uint8_t* p_t0_s1_data = NULL;

  expand_factor = 1;
  if (do_expand) {
    assert((num_tracks * 2) <= k_max_num_tracks);
    expand_factor = 2;
  }
  shrink_factor = 1;
  if (do_double_step) {
    shrink_factor = 2;
  }

  for (i = 0; i < num_tracks; ++i) {
    uint8_t is_marker[k_max_track_length];
    uint8_t is_weak[k_max_track_length];
    uint32_t num_sectors;
    uint32_t track_length;
    uint32_t j;
    uint32_t hfe_track_pos;
    uint8_t clocks;
    uint8_t data;
    uint8_t* p_out_track;

    uint32_t track_crc32 = 0xFFFFFFFF;
    uint32_t track_fixups = 0;
    int is_odd_track = (i & 1);

    p_in_track = (p_trks_buf + (i * 4096));
    p_out_track = p_hfe_buf;
    p_out_track += 1024;
    p_out_track += (i *
                    expand_factor /
                    shrink_factor *
                    (k_hfe_blocks_per_track * 512));
    if (is_second_side) {
      p_out_track += 256;
    }

    if (p_in_track[1] != i) {
      bail("mismatched track number");
    }
    num_sectors = p_in_track[5];
    if (num_sectors > 32) {
      bail("excessive number of sectors");
    }
    track_length = get16(p_in_track + 6);
    /* The track length may not have been stored, depending on controller chip
     * and whether the track is formatted or not.
     */
    if ((track_length == 0) || (p_in_track[4] == 0x18)) {
      track_length = k_standard_track_length;
    }
    if ((track_length < 3000) || (track_length > 3190)) {
      bail("bad track length");
    }

    /* Build a list of where the markers are and check CRCs / weak bits. */
    (void) memset(is_marker, '\0', sizeof(is_marker));
    (void) memset(is_weak, '\0', sizeof(is_weak));
    p_first_sector_data = NULL;
    for (j = 0; j < num_sectors; ++j) {
      uint16_t pos;
      uint16_t crc16_calc;
      uint16_t crc16_disc;
      uint32_t length;
      int is_data_crc_error;
      uint8_t logical_track;
      uint8_t logical_sector;

      /* Sector header. */
      pos = get16(p_in_track + 0x100 + (j * 2));
      if (is_marker[pos]) {
        bail("overlapping marker");
      }
      is_marker[pos] = 1;
      data = p_in_track[0x200 + pos];
      if ((data != 0xFE) && (data != 0xCE)) {
        bail("bad header marker byte 0x%.2X", data);
      }
      track_fixups += fixup_marker(&p_in_track[0x200], pos);
      crc16_calc = 0xFFFF;
      do_crc16(&crc16_calc, (p_in_track + 0x200 + pos), 5);
      crc16_disc = ((p_in_track[0x200 + pos + 5]) << 8);
      crc16_disc |= p_in_track[0x200 + pos + 6];
      if (crc16_calc != crc16_disc) {
        (void) printf("Header CRC error, physical track / sector %d / %d\n",
                      i,
                      j);
      }
      logical_track = p_in_track[0x200 + pos + 1];
      logical_sector = p_in_track[0x200 + pos + 3];

      /* Sector data. */
      pos = get16(p_in_track + 0x140 + (j * 2));
      if (is_marker[pos]) {
        bail("overlapping marker");
      }
      is_marker[pos] = 1;
      data = p_in_track[0x200 + pos];
      if ((data != 0xF8) &&
          (data != 0xC8) &&
          (data != 0xFB) &&
          (data != 0xCB)) {
        bail("bad data marker byte 0x%.2X", data);
      }
      track_fixups += fixup_marker(&p_in_track[0x200], pos);
      length = (p_in_track[0xe0 + j] & 7);
      if (length > 4) {
        bail("bad real sector length");
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
      if (j == 0) {
        p_first_sector_data = (p_in_track + 0x200 + pos + 1);
      }
      if ((i == 0) && (logical_track == 0)) {
        if (logical_sector == 0) {
          p_t0_s0_data = (p_in_track + 0x200 + pos + 1);
        } else if (logical_sector == 1) {
          p_t0_s1_data = (p_in_track + 0x200 + pos + 1);
        }
      }

      /* Weak bits. */
      if (p_in_track[0xE0 + j] & 0x20) {
        uint32_t k;
        uint32_t weak_index = get16(p_in_track + 0xf00 + (j * 2));
        (void) printf("Weak bits index %d, physical track / sector %d / %d\n",
                      weak_index,
                      i,
                      j);
        for (k = weak_index; k < length; ++k) {
          is_weak[pos + 1 + k] = 1;
        }
      }
    }

    /* Update disc CRC32. */
    track_crc32 = ~track_crc32;
    beeb_crc32 = p_in_track[12];
    beeb_crc32 += (p_in_track[13] << 8);
    beeb_crc32 += (p_in_track[14] << 16);
    beeb_crc32 += (p_in_track[15] << 24);
    if (!s_is_no_check_beeb_crc && (beeb_crc32 != track_crc32)) {
      bail("beeb track CRC32 %.4X doesn't match %.4X", beeb_crc32, track_crc32);
    }
    if (s_is_verbose) {
      (void) printf("Track %d sectors %d length %d fixups %d CRC32 %.8X\n",
                    i,
                    num_sectors,
                    track_length,
                    track_fixups,
                    track_crc32);
    }
    do_crc32(&disc_crc32, (uint8_t*) &track_crc32, 4);
    if (!is_odd_track) {
      do_crc32(&disc_crc32_double_step, (uint8_t*) &track_crc32, 4);
    }

    if (!do_double_step || !is_odd_track) {
      p_track_lengths[i / shrink_factor] = track_length;

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

        if (is_weak[j]) {
          uint32_t k;
          for (k = 0; k < 4; ++k) {
            hfe_add(p_out_track, &hfe_track_pos, flip(0xF4));
          }
        } else {
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
    }
  }

  if ((p_t0_s0_data != NULL) && (p_t0_s1_data != NULL)) {
    char dfs_title[13];
    dfs_title[12] = '\0';
    (void) memcpy(dfs_title, p_t0_s0_data, 8);
    (void) memcpy((dfs_title + 8), p_t0_s1_data, 4);
    (void) printf("Disc DFS title: %s\n", dfs_title);
    for (i = 0; i < 12; ++i) {
      char c = dfs_title[i];
      if (c == '\0') {
        break;
      }
      if (!isprint(c)) {
        dfs_title[i] = '?';
      }
    }
    (void) printf("Disc DFS title (printable): %s\n", dfs_title);
    (void) printf("Disc DFS cycle number: %.2X\n", p_t0_s1_data[4]);
  }
  if ((p_first_sector_data != NULL) &&
      ((num_tracks == 41) || (num_tracks == 81)) &&
      !memcmp(p_first_sector_data, "\x01\x02\x03\x04\x05", 5)) {
    (void) printf("Disc birthday (YY/MM/DD): %.2X/%.2X/%.2X\n",
                  p_first_sector_data[14],
                  p_first_sector_data[15],
                  p_first_sector_data[16]);
    (void) printf("Disc extra info: %s\n", (p_first_sector_data + 23));
  }

  disc_crc32 = ~disc_crc32;
  disc_crc32_double_step = ~disc_crc32_double_step;
  beeb_crc32 = p_in_track[28];
  beeb_crc32 += (p_in_track[29] << 8);
  beeb_crc32 += (p_in_track[30] << 16);
  beeb_crc32 += (p_in_track[31] << 24);
  if (!s_is_no_check_beeb_crc && (beeb_crc32 != disc_crc32)) {
    bail("beeb disc CRC32 %.4X doesn't match %.4X", beeb_crc32, disc_crc32);
  }
  (void) printf("Disc CRC32: %.8X\n", disc_crc32);
  if (num_tracks > 41) {
    (void) printf("Disc CRC32 (40 track): %.8X\n", disc_crc32_double_step);
  }
}

int
main(int argc, const char* argv[]) {
  FILE* f;
  uint32_t i;
  uint8_t trks_buf_drv0[k_max_num_tracks * 4096];
  uint8_t trks_buf_drv2[k_max_num_tracks * 4096];
  uint32_t track_lengths_drv0[k_max_num_tracks];
  uint32_t track_lengths_drv2[k_max_num_tracks];
  uint8_t* p_hfe_buf;
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
  uint32_t hfe_buf_size = ((k_max_num_tracks * k_hfe_blocks_per_track * 512) +
                           1024);

  p_hfe_buf = malloc(hfe_buf_size);

  for (i = 1; i < (uint32_t) argc; ++i) {
    if (!strcmp(argv[i], "-v")) {
      s_is_verbose = 1;
    } else if (!strcmp(argv[i], "-n")) {
      s_is_no_check_beeb_crc = 1;
    } else if (!strcmp(argv[i], "-d")) {
      s_is_double_step = 1;
    } else if (!strcmp(argv[i], "-h") ||
               !strcmp(argv[i], "-help") ||
               !strcmp(argv[i], "--help")) {
      (void) printf("Usage: hfeg2hfe [-v] [-n] [-h]\n");
      (void) printf("The TRKS files should be in the current directory.\n");
      (void) printf("(Or use drv0 and drv2 subdirectories for dual sides.)\n");
      (void) printf("  -h    Show this help text.\n");
      (void) printf("  -v    Verbose output.\n");
      (void) printf("  -n    Don't cross-check CRC32s (for old TRKS files).\n");
      (void) printf("  -d    Skip odd numbered tracks.\n");
      exit(0);
    } else {
      (void) printf("Unknown option: %s\n", argv[i]);
      exit(1);
    }
  }

  (void) memset(trks_buf_drv0, '\0', sizeof(trks_buf_drv0));
  (void) memset(trks_buf_drv2, '\0', sizeof(trks_buf_drv2));
  (void) memset(track_lengths_drv0, '\0', sizeof(track_lengths_drv0));
  (void) memset(track_lengths_drv2, '\0', sizeof(track_lengths_drv2));
  (void) memset(p_hfe_buf, '\0', hfe_buf_size);

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
  (void) printf("HFE Grab version: %d\n", trks_buf_drv0[0x10]);
  (void) printf("Tracks: %d\n", num_tracks);
  if (num_tracks == 0) {
    bail("no tracks");
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
    bail("unknown capture chip");
  }
  (void) printf("Captured with: %s\n", p_capture_chip);
  (void) printf("Drive speed: %d\n", get16(&trks_buf_drv0[2]));

  convert_tracks(p_hfe_buf,
                 track_lengths_drv0,
                 0,
                 trks_buf_drv0,
                 do_expand_drv0,
                 s_is_double_step,
                 num_tracks_drv0);
  if (num_tracks_drv2 > 0) {
    convert_tracks(p_hfe_buf,
                   track_lengths_drv2,
                   1,
                   trks_buf_drv2,
                   do_expand_drv2,
                   s_is_double_step,
                   num_tracks_drv2);
  }

  if (s_is_double_step) {
    if (num_tracks & 1) {
      num_tracks++;
    }
    num_tracks /= 2;
  }

  /* Write HFE track position metadata. */
  for (i = 0; i < num_tracks; ++i) {
    uint32_t track_length = track_lengths_drv0[i];
    if (track_lengths_drv2[i] > track_length) {
      track_length = track_lengths_drv2[i];
    }
    put16((p_hfe_buf + 512 + (i * 4)), (2 + (i * k_hfe_blocks_per_track)));
    put16((p_hfe_buf + 512 + (i * 4) + 2), ((track_length * 8) + 6));
  }

  /* Write HFEv3 header. */
  (void) memset(p_hfe_buf, '\xff', 512);
  (void) strcpy((char*) p_hfe_buf, "HXCHFEV3");
  /* Revision 0. */
  p_hfe_buf[8] = 0;
  /* Number of tracks. */
  p_hfe_buf[9] = num_tracks;
  /* 1 or 2 sides. */
  p_hfe_buf[10] = num_sides;
  /* IBM FM encoding. */
  p_hfe_buf[11] = 2;
  /* 250kbit. */
  p_hfe_buf[12] = 0xFA;
  p_hfe_buf[13] = 0;
  /* 300rpm. */
  p_hfe_buf[14] = 0x2C;
  p_hfe_buf[15] = 0x1;
  /* Shugart interface. */
  p_hfe_buf[16] = 7;
  /* 1 == 512 byte LUT offset. */
  p_hfe_buf[18] = 1;
  p_hfe_buf[19] = 0;

  f = fopen("out.hfe", "wb");
  if (f == NULL) {
    bail("couldn't open output file");
  }
  hfe_length = ((num_tracks * k_hfe_blocks_per_track * 512) + 1024);
  fwrite_ret = fwrite(p_hfe_buf, hfe_length, 1, f);
  if (fwrite_ret != 1) {
    bail("fwrite failed");
  }
  ret = fclose(f);
  if (ret != 0) {
    bail("fclose failed");
  }

  free(p_hfe_buf);

  exit(0);
}
