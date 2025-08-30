#!/bin/sh
./build_binaries.sh
rm -rf tmp
mkdir tmp
cd tmp
../bin/make_channel_maps -channels 1 > sntab1d.dat
../bin/modxtract -sample 1 -sample 2 -sample 3 \
                 -pattern 0 -pattern 1 -pattern 2 -pattern 3 \
                 -pattern 4 -pattern 5 -pattern 6 -pattern 7 \
                 -pattern 8 -pattern 9 -pattern 10 -pattern 11 \
                 -pattern 12 -pattern 13 -pattern 14 -pattern 15 \
                 -pattern 16 -pattern 17 \
                 ../../mods/blade_of_destiny.mod
../bin/modpatconv -o conv.out -a adv_tables.out -l lookup_tables.out \
                  mod.pattern.0 mod.pattern.1 mod.pattern.2 mod.pattern.3 \
                  mod.pattern.4 mod.pattern.5 mod.pattern.6 mod.pattern.7 \
                  mod.pattern.8 mod.pattern.9 mod.pattern.10 mod.pattern.11 \
                  mod.pattern.12 mod.pattern.13 mod.pattern.14 mod.pattern.15 \
                  mod.pattern.16 mod.pattern.17
../bin/sample_adjust -i mod.sample.1 -o sample.choir \
                     -gain 1.2 -static_offset 96 \
                     -sn sntab1d.dat -snchannel 1 \
                     -post_end_pad 64 -loop_start 24
../bin/sample_adjust -i mod.sample.2 -o sample.guitar -pre_begin_pad 6 \
                     -static_offset 96 \
                     -sn sntab1d.dat -snchannel 2 \
                     -post_end_pad 64 -loop_start $((3682 + 6))
../bin/sample_adjust -i mod.sample.3 -o sample.flute -pre_begin_trunc 2 \
                     -static_offset 80 \
                     -sn sntab1d.dat -snchannel 3 \
                     -post_end_pad 64 -loop_start $((4922 - 2))
~/beebasm/beebasm -i ../../beeb/p15k_3sep.asm \
                  -S SONG_DETAILS_FILE="../../beeb/play_blade.inc" \
                  -do ../play_blade.ssd -opt 3
