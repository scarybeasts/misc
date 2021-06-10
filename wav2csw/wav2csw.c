#include <err.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int
main(int argc, const char* argv[]) {
  FILE* f_in;
  FILE* f_out;
  uint8_t* p_in_buf;
  uint8_t* p_out_buf;
  uint32_t max_len = (32 * 1024 * 1024);
  uint32_t in_len_full;
  uint32_t in_index;
  uint32_t out_index;
  int dir;
  uint8_t prev;
  uint32_t half_len;
  uint32_t prev_half_len;
  size_t write_ret;

  f_in = fopen("in.wav", "r");
  if (f_in == NULL) {
    errx(1, "fopen in.wav failed");
  }
  p_in_buf = malloc(max_len);
  if (p_in_buf == NULL) {
    errx(1, "malloc failed");
  }
  p_out_buf = malloc(max_len);
  if (p_out_buf == NULL) {
    errx(1, "malloc failed");
  }
  in_len_full = fread(p_in_buf, 1, max_len, f_in);
  if (in_len_full < 44) {
    errx(1, "WAV file too short");
  }
  if (fclose(f_in) != 0) {
    errx(1, "fclose failed");
  }

  /* Check WAV. */
  if (memcmp(&p_in_buf[0], "RIFF", 4)) {
    errx(1, "WAV not RIFF");
  }
  if (memcmp(&p_in_buf[8], "WAVE", 4)) {
    errx(1, "RIFF not WAVE");
  }
  /* Ignore RIFF length, just use file length. */
  if (memcmp(&p_in_buf[12], "fmt ", 4)) {
    errx(1, "fmt chunk not first");
  }
  if (memcmp(&p_in_buf[16], "\x10\x00\x00\x00", 4)) {
    errx(1, "fmt chunk size not 16");
  }
  if (memcmp(&p_in_buf[20], "\x01\x00", 2)) {
    errx(1, "fmt not u8");
  }
  if (memcmp(&p_in_buf[22], "\x01\x00", 2)) {
    errx(1, "fmt not mono");
  }
  if (memcmp(&p_in_buf[24], "\x44\xAC\x00\x00\x44\xAC\x00\x00", 8)) {
    errx(1, "fmt not 44.1kHz");
  }
  if (memcmp(&p_in_buf[32], "\x01\x00", 2)) {
    errx(1, "fmt not blockalign 1");
  }
  if (memcmp(&p_in_buf[34], "\x08\x00", 2)) {
    errx(1, "fmt bits not 8");
  }
  if (memcmp(&p_in_buf[36], "data", 4)) {
    errx(1, "data chunk not second");
  }
  /* Ignore data length, just use file length. */
  in_index = 44;

  /* Set up CSW header. */
  (void) memset(&p_out_buf[0], '\0', 0x34);
  (void) memcpy(&p_out_buf[0], "Compressed Square Wave", 22);
  p_out_buf[0x16] = 0x1A;
  p_out_buf[0x17] = 0x02;
  p_out_buf[0x19] = 0x44;
  p_out_buf[0x1A] = 0xAC;
  p_out_buf[0x21] = 0x01;
  (void) memcpy(&p_out_buf[0x24], "wav2csw", 7);
  out_index = 0x34;

  dir = 1;
  prev = 0x80;
  prev_half_len = 1;
  half_len = 1;
  while (in_index < in_len_full) {
    uint8_t curr = p_in_buf[in_index];
    if (((dir == 1) && (curr >= prev)) || ((dir == -1) && (curr <= prev))) {
      half_len++;
      prev = curr;
      in_index++;
      continue;
    }

    /* Dumb but effective half len fixups. */
/*
    if (prev_half_len < 16) {
      if ((half_len == 13) || (half_len == 14)) {
        half_len = 12;
      }
    }
    if ((half_len == 5) || (half_len == 6)) {
      half_len = 7;
    }
*/
//    if ((half_len != 1) && (half_len != 2)) {
      if (out_index < max_len) {
        p_out_buf[out_index++] = half_len;
      }
      prev_half_len = half_len;
//    }
    half_len = 1;
    dir = -dir;
    prev = curr;
    in_index++;
  }

  f_out = fopen("in.wav.csw", "wb");
  if (f_out == NULL) {
    errx(1, "fopen in.wav.csw failed");
  }

  write_ret = fwrite(&p_out_buf[0], 1, out_index, f_out);
  if (write_ret != out_index) {
    errx(1, "fwrite failed");
  }

  if (fclose(f_out) != 0) {
    errx(1, "fclose failed");
  }

  free(p_in_buf);
  free(p_out_buf);

  return 0;
}
