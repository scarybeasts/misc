#!/bin/sh
./build_binaries.sh
rm -rf tmp
mkdir tmp
cd tmp
../bin/make_channel_maps -channels 1 -sn_channel 1 > sntab1.dat
../bin/make_channel_maps -channels 1 -sn_channel 2 > sntab2.dat
../bin/make_channel_maps -channels 1 -sn_channel 3 -gain 1.5 > sntab3.dat
../bin/modxtract -sample 2 -sample 11 -sample 12 -sample 13 -sample 14 \
                 -pattern 0 -pattern 1 -pattern 2 -pattern 3 -pattern 4 \
                 -pattern 5 -pattern 6 -pattern 7 \
                 ../../mods/mod.title
../bin/modpatconv -o conv.out -a adv_tables.out -l lookup_tables.out \
                  -p 80 \
                  mod.pattern.0 mod.pattern.1 mod.pattern.2 mod.pattern.2 \
                  mod.pattern.4 mod.pattern.4 mod.pattern.3 mod.pattern.3 \
                  mod.pattern.5 mod.pattern.3 mod.pattern.3 mod.pattern.4 \
                  mod.pattern.4 mod.pattern.6 mod.pattern.6 mod.pattern.7
../bin/sample_adjust -i mod.sample.13 -o sample.bass \
                     -pre_begin_trunc 4 \
                     -gain 2.0 \
                     -post_end_pad 64
../bin/sample_adjust -i mod.sample.2 -o sample.guitar \
                     -flip -gain 0.499 -static_offset 64 \
                     -no_pad_256 -post_end_pad 64
../bin/sample_adjust -i mod.sample.14 -o sample.tomtom \
                     -length 2726 -static_offset 64 -clip_max -1 \
                     -no_pad_256 -post_end_pad 64
../bin/sample_adjust -i mod.sample.12 -o sample.sdrum \
                     -length 2668 \
                     -dyn_offset 64 -dyn_rate 0.2 -dyn_taper 32 \
                     -no_pad_256 -post_end_pad 64
../bin/sample_adjust -i mod.sample.11 -o sample.bdrum \
                     -length 2130 \
                     -dyn_offset 112 -dyn_rate 0.2 -dyn_taper 64 \
                     -no_pad_256 -post_end_pad 64
~/beebasm/beebasm -i ../../beeb/p12k_4_2sep_2merge.asm \
                  -S SONG_DETAILS_FILE="../../beeb/play_lotus1_title.inc" \
                  -do ../play_lotus1_title.ssd -opt 3
