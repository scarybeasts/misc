#!/bin/sh
gcc -o merge_u4_to_dsd merge_u4_to_dsd.c || exit
gcc -o u8_to_bbc u8_to_bbc.c -lm || exit

ffmpeg -y -i input.mp3 -f u8 -ac 1 -ar 6500 input.u8
./u8_to_bbc


~/Downloads/beebasm/beebasm -i ../quicdisc/quicdisc.asm -v || exit
~/Downloads/beebasm/beebasm -i sampstream.asm -do sampstream.dsd \
    -opt 3 -v || exit

./merge_u4_to_dsd
