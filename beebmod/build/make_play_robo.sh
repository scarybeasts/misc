#!/bin/sh
./build_binaries.sh
rm -f mod.pattern.* mod.sample.* sample.*
rm -f sntab1d.dat tables.out conv.out play_robo.ssd
./make_channel_maps -channels 1 > sntab1d.dat
./modxtract -sample 1 -sample 2 -sample 3 -sample 4 \
            -pattern 0 -pattern 1 -pattern 2 -pattern 3 -pattern 4 \
            ../mods/mod.roboingame
./modpatconv -o conv.out -t tables.out \
             mod.pattern.0 mod.pattern.1 mod.pattern.2 mod.pattern.3 \
             mod.pattern.4
./sample_adjust -i mod.sample.1 -o sample.sdrum \
                -sn sntab1d.dat -snchannel 1 -pad -dyn_offset 112
./sample_adjust -i mod.sample.2 -o sample.bdrum \
                -sn sntab1d.dat -snchannel 1 -pad
./sample_adjust -i mod.sample.3 -o sample.bass \
                -sn sntab1d.dat -snchannel 2 -pad -dyn_offset 112
./sample_adjust -i mod.sample.4 -o sample.hdrum \
                -sn sntab1d.dat -snchannel 3 -pad -static_offset 128
~/beebasm/beebasm -i ../beeb/p15k_3sep.asm -do play_robo.ssd
