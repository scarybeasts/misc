#include <err.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

int
main(int argc, const char* argv[]) {
  FILE* p_in_file_1;
  FILE* p_in_file_2;
  FILE* p_out_file;
  char line_buf_1[256];
  char line_buf_2[256];
  const char* p_in_file_name_1 = "scope_a.txt";
  const char* p_in_file_name_2 = "scope_b.txt";
  const char* p_out_file_name = "scope_merged.txt";

  (void) argc;
  (void) argv;

  p_in_file_1 = fopen(p_in_file_name_1, "r");
  if (p_in_file_1 == NULL) {
    errx(1, "can't open %s", p_in_file_name_1);
  }
  p_in_file_2 = fopen(p_in_file_name_2, "r");
  if (p_in_file_2 == NULL) {
    errx(1, "can't open %s", p_in_file_name_2);
  }
  p_out_file = fopen(p_out_file_name, "w");
  if (p_out_file == NULL) {
    errx(1, "can't open output %s", p_out_file_name);
  }

  while (1) {
    char* p_ret_1;
    char* p_ret_2;
    float f1 = 0.0;
    float f2 = 0.0;
    float f_merged;

    p_ret_1 = fgets(&line_buf_1[0], sizeof(line_buf_1), p_in_file_1);
    p_ret_2 = fgets(&line_buf_2[0], sizeof(line_buf_2), p_in_file_2);
    if (ferror(p_in_file_1) != 0) {
      errx(1, "file 1 read error");
    }
    if (ferror(p_in_file_2) != 0) {
      errx(1, "file 2 read error");
    }
    if ((p_ret_1 == NULL) && (p_ret_2 == NULL)) {
      break;
    } else if (p_ret_1 == NULL) {
      errx(1, "EOF on file 1");
    } else if (p_ret_2 == NULL) {
      errx(1, "EOF on file 2");
    }
    (void) sscanf(&line_buf_1[0], "%f", &f1);
    (void) sscanf(&line_buf_2[0], "%f", &f2);
    f_merged = (f1 - f2);
    if (fprintf(p_out_file, "%f\n", f_merged) <= 0) {
      errx(1, "output file write error");
    }
  }

  fclose(p_in_file_1);
  fclose(p_in_file_2);
  fclose(p_out_file);

  return 0;
}
