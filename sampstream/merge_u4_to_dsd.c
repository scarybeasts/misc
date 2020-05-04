#include <stdint.h>
#include <stdio.h>

size_t
get_dsd_pos(int track, int side) {
  size_t ret = (track * 2560 * 2);
  if (side) {
    ret += 2560;
  }
  return ret;
}

int
main(int argc, const char* argv[]) {
  FILE* file_in;
  FILE* file_out;
  uint8_t track_buf[2560];
  int i;

  file_in = fopen("output.u4", "r");
  file_out = fopen("sampstream.dsd", "r+");

  /* Drive 0. */
  for (i = 1; i < 80; ++i) {
    size_t pos = get_dsd_pos(i, 0);
    fread(track_buf, sizeof(track_buf), 1, file_in);
    fseek(file_out, pos, SEEK_SET);
    fwrite(track_buf, sizeof(track_buf), 1, file_out);
  }

  /* Drive 2. */
  for (i = 79; i >= 0; --i) {
    size_t pos = get_dsd_pos(i, 1);
    fread(track_buf, sizeof(track_buf), 1, file_in);
    fseek(file_out, pos, SEEK_SET);
    fwrite(track_buf, sizeof(track_buf), 1, file_out);
  }

  fclose(file_in);
  fclose(file_out);

  return 0;
}
