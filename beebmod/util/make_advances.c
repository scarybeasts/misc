#include <math.h>
#include <unistd.h>

int
main(int argc, const char** argv) {
  int i;
  int advances[32];

  int periods[] = {
      /* C-1 to B-1. */
      856,808,762,720,678,640,604,570,538,508,480,453,
      /* C-2 to B-2. */
      428,404,381,360,339,320,302,285,269,254,240,226,
      /* C-3 to B-3. */
      214,202,190,180,170,160,151,143,135,127,120,113,
  };
  /* Based on the PAL Amiga clock.
   * Middle C, C-2, plays at this constant divided by the period 428, which
   * all comes out as 8287.14Hz.
   */
  double amiga_clocks = (28375160.0 / 8.0);
  /* Divide by 128 cycles is 15.6kHz.
   * Divide by 192 cycles is 10.4kHz.
   */
  double beeb_freq = (2000000.0 / 128.0);

  advances[0] = 0;
  for (i = 1; i < 32; ++i) {
    double period = periods[i - 1];
    double freq = (amiga_clocks / period);
    double advance_double = ((freq * 256.0) / beeb_freq);
    double advance = round(advance_double);
    advances[i] = advance;
  }

  for (i = 0; i < 32; ++i) {
    unsigned char hi;
    unsigned char lo;
    int advance = advances[i];
    hi = (advance >> 8);
    lo = (advance & 0xFF);
    write(1, &hi, 1);
    write(1, &lo, 1);
  }

  return 0;
}
