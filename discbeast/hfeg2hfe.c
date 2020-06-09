#include <err.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int s_is_verbose;

static const int k_max_num_tracks = 81;
/* Each block is 512 bytes, 256 per side. */
static const int k_hfe_blocks_per_track = 50;
/* NOTE: cannot be increased without re-evaluating k_hfe_blocks_per_track. */
static const int k_max_track_length = 3190;

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
load_trks_files(uint8_t* p_buf) {
  char path[16];
  FILE* f;
  uint32_t i;
  size_t fread_ret;
  int ret;

  uint32_t num_tracks = 0;

  for (i = 0; i <= 80; i += 2) {
    if (!(i & 1)) {
      (void) snprintf(path, sizeof(path), "TRKS%d", i);
      f = fopen(path, "r");
      if (f == NULL) {
        return num_tracks;
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
convert_tracks(uint8_t* p_hfe_buf, uint8_t* p_trks_buf, uint32_t num_tracks) {
  uint32_t i;
  uint32_t disc_crc32 = 0xFFFFFFFF;

  for (i = 0; i < num_tracks; ++i) {
    uint8_t is_marker[k_max_track_length];
    uint32_t num_sectors;
    uint32_t track_length;
    uint32_t j;
    uint32_t hfe_track_pos;

    uint32_t track_crc32 = 0xFFFFFFFF;
    uint8_t* p_in_track = (p_trks_buf + (i * 4096));
    uint8_t* p_out_track = p_hfe_buf;
    p_out_track += 1024;
    p_out_track += (i * k_hfe_blocks_per_track * 512);

    if (p_in_track[1] != i) {
      errx(1, "mismatched track number");
    }
    num_sectors = p_in_track[5];
    if (num_sectors > 32) {
      errx(1, "excessive number of sectors");
    }
    track_length = get16(p_in_track + 6);
    if ((track_length < 3000) || (track_length > 3190)) {
      errx(1, "bad track length");
    }

    /* Write HFE track position and length metadata. */
    put16((p_hfe_buf + 512 + (i * 4)), (2 + (i * k_hfe_blocks_per_track)));
    put16((p_hfe_buf + 512 + (i * 4) + 2), ((track_length * 8) + 6));

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
      crc16_calc = 0xFFFF;
      do_crc16(&crc16_calc, (p_in_track + 0x200 + pos), 5);
      crc16_disc = ((p_in_track[0x200 + pos + 5]) << 8);
      crc16_disc |= p_in_track[0x200 + pos + 6];
      if (crc16_calc != crc16_disc) {
        printf("Header CRC error, physical track / sector %d / %d\n", i, j);
      }

      /* Sector data. */
      pos = get16(p_in_track + 0x140 + (j * 2));
      if (is_marker[pos]) {
        errx(1, "overlapping marker");
      }
      is_marker[pos] = 1;
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
        do_crc32(&track_crc32, (p_in_track + 0x200 + pos), (length + 1));
      }
    }

    /* Update disc CRC32. */
    track_crc32 = ~track_crc32;
    if (s_is_verbose) {
      (void) printf("Track %d CRC32 %X\n", i, track_crc32);
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

      uint8_t clocks = 0xFF;
      uint8_t data = p_in_track[0x200 + j];
      if (is_marker[j]) {
        if ((data != 0xFE) && (data != 0xF8) && (data != 0xFB)) {
          errx(1, "bad marker byte");
        }
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
  uint8_t trks_buf[k_max_num_tracks * 4096];
  uint8_t hfe_buf[(k_max_num_tracks * k_hfe_blocks_per_track * 512) + 1024];
  uint32_t num_tracks;
  size_t fwrite_ret;
  int ret;
  uint32_t hfe_length;

  const char* p_capture_chip = NULL;

  for (i = 0; i < (uint32_t) argc; ++i) {
    if (!strcmp(argv[i], "-v")) {
      s_is_verbose = 1;
    }
  }

  (void) memset(trks_buf, '\0', sizeof(trks_buf));
  (void) memset(hfe_buf, '\0', sizeof(hfe_buf));
  num_tracks = load_trks_files(trks_buf);

  (void) printf("Tracks: %d\n", num_tracks);
  if (num_tracks == 0) {
    errx(1, "no tracks");
  }

  if (trks_buf[0] == 1) {
    p_capture_chip = "8271";
  } else if (trks_buf[0] == 2) {
    p_capture_chip = "1770";
  } else {
    errx(1, "unknown capture chip");
  }
  (void) printf("Captured with: %s\n", p_capture_chip);
  (void) printf("Drive speed: %d\n", get16(&trks_buf[2]));

  convert_tracks(hfe_buf, trks_buf, num_tracks);

  /* Write HFEv3 header. */
  (void) memset(hfe_buf, '\xff', 512);
  (void) strcpy(hfe_buf, "HXCHFEV3");
  /* Revision 0. */
  hfe_buf[8] = 0;
  /* Number of tracks. */
  hfe_buf[9] = num_tracks;
  /* 1 side. */
  hfe_buf[10] = 1;
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
