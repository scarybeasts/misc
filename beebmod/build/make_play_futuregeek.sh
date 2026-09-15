#!/bin/sh
./build_binaries.sh
rm -rf tmp
mkdir tmp
cd tmp
../bin/make_channel_maps -channels 1 > sntab1d.dat
cp ../../mods/mod.futuregeek ./convert.mod
../bin/modmod -chan_clear 3 ./convert.mod
../bin/modxtract -sample 2 -sample 4 -sample 6 -sample 7 \
                 -pattern 1 -pattern 2 -pattern 3 -pattern 4 -pattern 5 \
                 -pattern 7 \
                 ./convert.mod
../bin/modpatconv -o conv.out -a adv_tables.out -l lookup_tables.out -128 \
                  mod.pattern.1 mod.pattern.2 mod.pattern.3 mod.pattern.4 \
                  mod.pattern.5 mod.pattern.5 mod.pattern.7
../bin/sample_adjust -i mod.sample.2 -o sample.sdrum \
                     -sn sntab1d.dat -snchannel 1 \
                     -static_offset 128 \
                     -pre_begin_pad 140 \
                     -post_end_pad 64
../bin/sample_adjust -i mod.sample.4 -o sample.synth \
                     -sn sntab1d.dat -snchannel 1 \
                     -pre_begin_pad 46 \
                     -post_end_pad 64
../bin/sample_adjust -i mod.sample.6 -o sample.bdrum \
                     -sn sntab1d.dat -snchannel 1 \
                     -static_offset 80 \
                     -pre_begin_pad 136 \
                     -post_end_pad 64
../bin/sample_adjust -i mod.sample.7 -o sample.bass \
                     -sn sntab1d.dat -snchannel 1 \
                     -static_offset 96 \
                     -pre_begin_pad 140 \
                     -post_end_pad 64
~/beebasm/beebasm -i ../../beeb/p15k_3sep_v2.asm \
                  -S SONG_DETAILS_FILE="../../beeb/play_futuregeek.inc" \
                  -do ../play_futuregeek.ssd -opt 3
