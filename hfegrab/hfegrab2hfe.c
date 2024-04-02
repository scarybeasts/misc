#include <assert.h>
#include <err.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static uint8_t s_blank_buf[256];
static uint8_t s_data_bytes[3125];
static uint8_t s_clock_bytes[3125];
static uint32_t s_track_data_index;

static void
add(uint8_t data, uint8_t clocks) {
  if (s_track_data_index == 3125) {
    errx(1, "too many bytes added");
  }
  s_data_bytes[s_track_data_index] = data;
  s_clock_bytes[s_track_data_index] = clocks;
  s_track_data_index++;
}

static void
addn(uint32_t n, uint8_t data, uint8_t clocks) {
  uint32_t i;
  for (i = 0; i < n; ++i) {
    add(data, clocks);
  }
}

static void
addcopy(uint32_t n, uint8_t* p_src) {
  uint32_t i;
  for (i = 0; i < n; ++i) {
    add(p_src[i], 0xff);
  }
}

static uint32_t
get16(uint8_t* p_buf) {
  uint32_t ret = p_buf[0];
  ret += (p_buf[1] * 256);
  return ret;
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
hfe_encode(uint8_t* p_buf, uint8_t data, uint8_t clocks) {
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
do_crc_16(uint16_t* p_crc, uint8_t byte) {
  uint32_t i;
  uint16_t crc = *p_crc;

  for (i = 0; i < 8; ++i) {
    int bit = (byte & 0x80);
    int bit_test = ((crc & 0x8000) ^ (bit << 8));
    crc <<= 1;
    if (bit_test) {
      crc ^= 0x1021;
    }
    byte <<= 1;
  }

  *p_crc = crc;
}

static void
do_crc_32(uint32_t* p_crc, uint8_t byte) {
  uint32_t i;
  uint32_t crc = *p_crc;

  crc = (crc ^ byte);
  for (i = 0; i < 8; ++i) {
    int do_eor = (crc & 1);
    crc = (crc >> 1);
    if (do_eor) {
      crc ^= 0xEDB88320;
    }
  }

  *p_crc = crc;
}

int
main(int argc, const char* argv[]) {
  FILE* file_out;
  uint8_t header[512];
  uint8_t offsets[512];
  size_t ret;
  uint32_t i;
  uint32_t full_track_sector_data_crc;

  uint32_t track = 0;
  uint32_t full_disc_sector_data_crc = 0xffffffff;
  int flag_is_verbose = 0;
  int flag_is_very_verbose = 0;

  for (i = 0; i < argc; ++i) {
    const char* p_arg;
    if (i == 0) {
      continue;
    }
    p_arg = argv[i];
    if (!strcmp(p_arg, "-v")) {
      flag_is_verbose = 1;
    } else if (!strcmp(p_arg, "-vv")) {
      flag_is_verbose = 1;
      flag_is_very_verbose = 1;
    }
  }

  file_out = fopen("out.hfe", "w+");
  if (file_out == NULL) {
    errx(1, "couldn't open output file");
  }

  (void) memset(header, '\xFF', sizeof(header));
  (void) memset(offsets, '\0', sizeof(offsets));

  (void) strcpy(header, "HXCHFEV3");
  /* Revision 0. */
  header[8] = 0;
  /* Single sided. */
  header[10] = 1;
  /* IBM FM, 250kbit, (unused) RPM. */
  header[11] = 2;
  header[12] = 0xFA;
  header[13] = 0;
  header[14] = 0;
  header[15] = 0;
  /* Mode: Shuggart DD. Unused. 1==512 LUT offset. */
  header[16] = 7;
  header[17] = 0xFF;
  header[18] = 1;
  header[19] = 0;

  while (1) {
    char file_name[256];
    uint8_t in_buf[16384];
    uint8_t out_buf[16384];
    uint8_t* p_in_track;
    uint32_t i;
    uint32_t j; 
    uint32_t first_byte_time;
    uint32_t gap1_ffs;
    uint32_t chunk_length;
    uint32_t chunk_left;
    uint32_t in_buf_index;
    uint32_t out_buf_index;
    uint32_t sector_index;
    uint8_t data;
    uint8_t clocks;
    uint32_t hfe_file_offset;
    uint16_t crc;
    uint32_t num_sector_headers;

    FILE* file_in = NULL;
    int in_state_sector_data = 0;
    int in_state_sector_header = 0;
    int in_state_seeking_sector_header = 0;
    int in_state_seeking_sector_data = 0;
    int in_state_crc = 0;
    int last_one = 0;

    if ((track % 4) == 0) {
      (void) snprintf(file_name, sizeof(file_name), "TRKS%d", (track / 4));
      file_in = fopen(file_name, "r");
      if (file_in == NULL) {
        last_one = 1;
      } else {
        ret = fread(in_buf, sizeof(in_buf), 1, file_in);
        if (ret != 1) {
          errx(1, "couldn't read input file %s", file_name);
        }
        (void) fclose(file_in);
      }
    }

    p_in_track = (in_buf + (4096 * (track % 4)));
    if (p_in_track[0] != 1) {
      last_one = 1;
    }

    /* Don't include the overread track in the checksum because it contains
     * variable data such as duplication date.
     */
    if (track == 0) {
      /* Track 0 will be included after we go around the loop again. */
    } else if (!last_one || ((track != 41) && (track != 81))) {
      do_crc_32(&full_disc_sector_data_crc,
                (full_track_sector_data_crc & 0xff));
      do_crc_32(&full_disc_sector_data_crc,
                ((full_track_sector_data_crc >> 8) & 0xff));
      do_crc_32(&full_disc_sector_data_crc,
                ((full_track_sector_data_crc >> 16) & 0xff));
      do_crc_32(&full_disc_sector_data_crc, (full_track_sector_data_crc >> 24));
    }

    if (last_one) {
      break;
    }

    full_track_sector_data_crc = 0xffffffff;

    (void) memset(s_data_bytes, '\0', sizeof(s_data_bytes));
    (void) memset(s_clock_bytes, '\0', sizeof(s_clock_bytes));

    if (p_in_track[1] != 0) {
      if (p_in_track[1] == 0x18) {
        (void) printf("Track %d is unformatted\n", track);
      } else {
        (void) printf("WARNING: Track %d read sectors error %.2X\n",
                      track,
                      p_in_track[1]);
      }
      goto track_write;
    }

    /* Sector header bytes are fed in to the CRC32 first. */
    for (i = 0; i < 32; ++i) {
      uint16_t sector_time = get16(&p_in_track[0x90 + (i * 2)]);
      if (sector_time < 3125) {
        errx(1, "first sector too soon");
      }
      if ((sector_time >= 6122) && (sector_time < 6240)) {
        errx(1, "sector too late in track");
      }
      if (sector_time >= 6122) {
        break;
      }
      for (j = 0; j < 4; ++j) {
        do_crc_32(&full_track_sector_data_crc, p_in_track[0x10 + (i * 4) + j]);
      }
    }
    num_sector_headers = i;

    if (flag_is_very_verbose) {
      (void) printf("Track 0 %d sectors, sector headers CRCinv %.8X\n",
                    num_sector_headers,
                    full_track_sector_data_crc);
    }

    s_track_data_index = 0;
    first_byte_time = get16(&p_in_track[0xd0]);

    if (first_byte_time >= 256) {
      errx(1, "first byte unusually slow");
    }
    if (first_byte_time < 36) {
      errx(1, "first byte unusually fast");
    }
    /* Build a sane GAP1 and first sector GAP2.
     * Note that 32 is the correct correction, but we use 36 to compensate
     * for the 8271's slow response to "read drive status". This is needed for
     * some Sherston Software titles which use an 80-byte overrread past the
     * last sector.
     */
    gap1_ffs = (first_byte_time - 36);
    addn(gap1_ffs, 0xff, 0xff);
    addn(6, 0, 0xff);
    if (flag_is_very_verbose) {
      (void) printf("Track %d sector first sector header at %d\n",
                    track,
                    (gap1_ffs + 6));
    }
    /* Sector header. */
    add(0xfe, 0xc7);
    addcopy(4, (p_in_track + 0x10));
    /* Sector header CRC, have to calculate it. */
    crc = 0xffff;
    do_crc_16(&crc, 0xfe);
    for (i = 0; i < 4; ++i) {
      data = p_in_track[0x10 + i];
      do_crc_16(&crc, data);
    }
    add((crc >> 8), 0xff);
    add((crc & 0xff), 0xff);
    /* Gap 2. */
    addn(11, 0xff, 0xff);
    addn(6, 0x00, 0xff);
    /* Sector data is either deleted or not. */
    if (p_in_track[2] & 0x20) {
      data = 0xf8;
    } else {
      data = 0xfb;
    }
    add(data, 0xc7);
    crc = 0xffff;
    do_crc_16(&crc, data);
    do_crc_32(&full_track_sector_data_crc, data);
    /* Now we can copy from the captured data, fixing up clock bytes as we
     * think we hit sector headers!
     */
    in_buf_index = 0;
    sector_index = 0;
    chunk_length = 0xffff;
    in_state_sector_data = 1;
    
    while (s_track_data_index < 3125) {
      if (chunk_length == 0xffff) {
        uint32_t delta = get16(&p_in_track[0x90 + ((sector_index + 1) * 2)]);
        delta -= get16(&p_in_track[0x90 + (sector_index  * 2)]);
        chunk_length = 2048;
        if (delta < 2048) {
          chunk_length = 1024;
        }
        if (delta < 1024) {
          chunk_length = 512;
        }
        if (delta < 512) {
          chunk_length = 256;
        }
        if (delta < 256) {
          chunk_length = 128;
        }
        chunk_left = chunk_length;
      }

      data = p_in_track[256 + in_buf_index];
      if ((in_state_sector_header || in_state_sector_data) && !in_state_crc) {
        do_crc_16(&crc, data);
        if (in_state_sector_data) {
          do_crc_32(&full_track_sector_data_crc, data);
        }
      }
      clocks = 0xff;

      i = (in_buf_index / 8);
      j = (in_buf_index % 8);
      if (p_in_track[0xe00 + i] & (0x80 >> j)) {
        const char* p_severity = "info";
        if (in_state_sector_header || in_state_sector_data) {
          p_severity = "WARNING";
        }
        (void) printf("%s: inconsistent data read, track %d pos %d\n",
                      p_severity,
                      track,
                      in_buf_index);
      }

      if (chunk_left > 0) {
        chunk_left--;
        if (chunk_left == 0) {
          assert(in_state_sector_header || in_state_sector_data);
          if (!in_state_crc) {
            in_state_crc = 1;
            chunk_left = 2;
          } else {
            uint16_t stored_crc = p_in_track[256 + in_buf_index - 1];
            stored_crc <<= 8;
            stored_crc |= p_in_track[256 + in_buf_index];
            if (stored_crc != crc) {
              const char* p_where = "data";
              if (in_state_sector_header) {
                p_where = "HEADER";
              }
              (void) printf("warning: %s CRC mismatch %.4X exp %.4X physical "
                            "track %d sector %d length %d\n",
                            p_where,
                            crc,
                            stored_crc,
                            track,
                            sector_index,
                            chunk_length);
            }
            if (in_state_sector_header) {
              in_state_sector_header = 0;
              in_state_seeking_sector_data = 1;
            } else {
              assert(in_state_sector_data);
              in_state_sector_data = 0;
              in_state_seeking_sector_header = 1;
              if (flag_is_very_verbose) {
                (void) printf("sector CRCinv %.8X\n",
                              full_track_sector_data_crc);
              }
              sector_index++;
            }
            in_state_crc = 0;
          }
        }
      } else {
        int is_two_zeros = 0;
        if (p_in_track[256 + in_buf_index - 1] == 0 &&
            (p_in_track[256 + in_buf_index - 2] == 0)) {
          is_two_zeros = 1;
        }
    
        if (in_state_seeking_sector_header && (data == 0xfe) && is_two_zeros) {
          clocks = 0xc7;
          crc = 0xffff;
          do_crc_16(&crc, 0xfe);
          chunk_length = 4;
          chunk_left = 4;
          in_state_seeking_sector_header = 0;
          in_state_sector_header = 1;
        } else if (in_state_seeking_sector_data &&
                   ((data == 0xf8) || (data == 0xfb)) &&
                   is_two_zeros) {
          clocks = 0xc7;
          crc = 0xffff;
          do_crc_16(&crc, data);
          do_crc_32(&full_track_sector_data_crc, data);
          chunk_length = 0xffff;
          in_state_seeking_sector_data = 0;
          in_state_sector_data = 1;
        }
      }

      in_buf_index++;
      add(data, clocks);
    }

    if (num_sector_headers != sector_index) {
      errx(1,
           "sector count mismatch: track %d parsed %d expected %d",
           track,
           sector_index,
           num_sector_headers);
    }

    if (sector_index != 10) {
      (void) printf("Track %d sectors %d\n", track, sector_index);
    }

  track_write:
    /* Write HFE bytes to file. */
    (void) memset(out_buf, '\0', sizeof(out_buf));
    out_buf[0]= flip(0xf1);
    out_buf[1]= flip(0xf2);
    out_buf[2]= flip(72);
    out_buf_index = 3;
    for (i = 0; i < 3125; ++i) {
      data = s_data_bytes[i];
      clocks = s_clock_bytes[i];
      hfe_encode(&out_buf[out_buf_index], data, clocks);
      out_buf_index += 4;
    }

    hfe_file_offset = (1024 + (track * 0x6200));
    ret = fseek(file_out, hfe_file_offset, SEEK_SET);
    if (ret != 0) {
      errx(1, "fseek failed");
    }
    for (i = 0; i < 49; ++i) {
      /* Data on the disc lower side. */
      ret = fwrite((out_buf + (i * 256)), 256, 1, file_out);
      if (ret != 1) {
        errx(1, "fwrite failed");
      }
      /* Blank on the upper side. */
      ret = fwrite(s_blank_buf, 256, 1, file_out);
      if (ret != 1) {
        errx(1, "fwrite failed");
      }
    }

    /* Update track file offset metadata. */
    hfe_file_offset /= 512;
    offsets[track * 4] = (hfe_file_offset & 0xff);
    offsets[(track * 4) + 1] = (hfe_file_offset >> 8);
    /* 0x61ae is 25006 == (12500 + 3) * 2. */
    offsets[(track * 4) + 2] = 0xae;
    offsets[(track * 4) + 3] = 0x61;

    full_track_sector_data_crc = ~full_track_sector_data_crc;
    if (flag_is_verbose) {
      (void) printf("Track %d sector data CRC32 %.8X\n",
                    track,
                    full_track_sector_data_crc);
    }

    track++;
  }

  full_disc_sector_data_crc = ~full_disc_sector_data_crc;
  (void) printf("Full disc sector data CRC32 %.8X\n",
                full_disc_sector_data_crc);
  (void) printf("Writing %d tracks to HFE\n", track);

  /* Update track counter in header struct. */
  header[9] = track;

  ret = fseek(file_out, 0, SEEK_SET);
  if (ret != 0) {
    errx(1, "fseek failed");
  }
  /* Write header. */
  ret = fwrite(header, sizeof(header), 1, file_out);
  if (ret != 1) {
    errx(1, "fwrite failed");
  }
  /* Write offsets metadata chunk. */
  ret = fwrite(offsets, sizeof(offsets), 1, file_out);
  if (ret != 1) {
    errx(1, "fwrite failed");
  }

  (void) fclose(file_out);

  return 0;
}
