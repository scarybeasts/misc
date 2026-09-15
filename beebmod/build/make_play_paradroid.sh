#!/bin/sh
./build_binaries.sh
rm -rf tmp
mkdir tmp
cd tmp
../bin/make_channel_maps -channels 1 > sntab1d.dat
../bin/modxtract -sample 1 -sample 2 -sample 3 -sample 4 -sample 5 -sample 6 \
                 -sample 7 \
                 -pattern 0 -pattern 6 -pattern 7 -pattern 8 \
                 -pattern 10 -pattern 11 -pattern 12 -pattern 13 \
                 ../../mods/paradroid90_16.mod
../bin/modpatconv -o conv.out -a adv_tables.out -l lookup_tables.out \
                  mod.pattern.0 mod.pattern.6 mod.pattern.7 mod.pattern.8 \
                  mod.pattern.13 mod.pattern.10 mod.pattern.11 mod.pattern.12 \
                  mod.pattern.13
../bin/sample_adjust -i mod.sample.1 -o sample.bdrum \
                     -length 2564 -pre_begin_trunc 6 \
                     -dyn_offset 96 -dyn_taper 0 \
                     -sn sntab1d.dat -snchannel 1 \
                     -post_end_pad 64
../bin/sample_adjust -i mod.sample.2 -o sample.sdrum \
                     -length 1592 -pre_begin_trunc 82 \
                     -sn sntab1d.dat -snchannel 1 \
                     -post_end_pad 64
../bin/sample_adjust -i mod.sample.3 -o sample.shaker \
                     -length 328 -pre_begin_trunc 164 \
                     -static_offset 96 \
                     -sn sntab1d.dat -snchannel 1 \
                     -post_end_pad 64
../bin/sample_adjust -i mod.sample.4 -o sample.bass128 \
                     -pre_begin_pad 128 \
                     -sn sntab1d.dat -snchannel 1 \
                     -post_end_pad 64 -loop_start $((0 + 128))
../bin/sample_adjust -i mod.sample.5 -o sample.bright \
                     -length 2768 \
                     -sn sntab1d.dat -snchannel 1 \
                     -static_offset 108 \
                     -post_end_pad 64
../bin/sample_adjust -i mod.sample.6 -o sample.tri32 \
                     -pre_begin_pad 224 \
                     -sn sntab1d.dat -snchannel 1 \
                     -post_end_pad 64 -loop_start $((0 + 224))
../bin/sample_adjust -i mod.sample.7 -o sample.guitar \
                     -sn sntab1d.dat -snchannel 1 \
                     -post_end_pad 64
~/beebasm/beebasm -i ../../beeb/p15k_3sep_v2.asm \
                  -S SONG_DETAILS_FILE="../../beeb/play_paradroid.inc" \
                  -do ../play_paradroid.ssd -opt 3
