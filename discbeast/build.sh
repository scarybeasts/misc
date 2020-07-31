#!/bin/sh
gcc -g -Wall -Werror -o hfeg2hfe hfeg2hfe.c || exit
#x86_64-w64-mingw32-gcc -g -gdwarf-2 -Wall -Werror -o hfeg2hfe.exe hfeg2hfe.c
~/Downloads/beebasm/beebasm -i discutil.asm -opt 3 -v || exit
~/Downloads/beebasm/beebasm -i discbeast.asm -do discbeast.ssd -opt 3 -v || exit
