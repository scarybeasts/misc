#!/bin/sh
./build_binaries.sh
rm -rf tmp
mkdir tmp
cd tmp
../bin/make_channel_maps -channels 1 > sntab1d.dat
../bin/modxtract -sample 1 -sample 2 -sample 3 -sample 4 -sample 5 -sample 6 \
                 -pattern 0 -pattern 1 -pattern 2 -pattern 3 -pattern 4 \
                 ../../mods/chaos_engine_4_11.mod
../bin/modpatconv -o conv.out -a adv_tables.out -l lookup_tables.out \
                  mod.pattern.4 mod.pattern.0 mod.pattern.1 mod.pattern.2 \
                  mod.pattern.3
../bin/sample_adjust -i mod.sample.1 -o sample.bass -pre_begin_pad 70 \
                     -gain 2.0 \
                     -sn sntab1d.dat -snchannel 3 \
                     -post_end_pad 64 -loop_start $((1240 + 70))
../bin/sample_adjust -i mod.sample.2 -o sample.guitar -pre_begin_pad 52 \
                     -gain 1.5 -static_offset 96 \
                     -sn sntab1d.dat -snchannel 2 \
                     -post_end_pad 64 -loop_start $((2632 + 52))
../bin/sample_adjust -i mod.sample.3 -o sample.bdrum \
                     -static_offset 96 \
                     -sn sntab1d.dat -snchannel 1 \
                     -post_end_pad 64
../bin/sample_adjust -i mod.sample.4 -o sample.hihat1 \
                     -static_offset 96 \
                     -sn sntab1d.dat -snchannel 1 \
                     -post_end_pad 64
../bin/sample_adjust -i mod.sample.5 -o sample.hihat2 \
                     -static_offset 96 \
                     -sn sntab1d.dat -snchannel 1 \
                     -post_end_pad 64
../bin/sample_adjust -i mod.sample.6 -o sample.sdrum \
                     -static_offset 96 \
                     -sn sntab1d.dat -snchannel 1 \
                     -post_end_pad 64
~/beebasm/beebasm -i ../../beeb/p15k_3sep.asm \
                  -S SONG_DETAILS_FILE="../../beeb/play_chaos_1.inc" \
                  -do ../play_chaos_1.ssd -opt 3
