#!/bin/sh
./build_binaries.sh
rm -rf tmp
mkdir tmp
cd tmp
../bin/make_channel_maps -channels 1 > sntab1d.dat
../bin/modxtract -sample 1 -sample 2 -sample 3 -sample 4 \
                 -pattern 0 -pattern 1 -pattern 2 -pattern 3 -pattern 4 \
                 ../../mods/mod.roboingame
../bin/modpatconv -o conv.out -t tables.out \
                  mod.pattern.0 mod.pattern.1 mod.pattern.2 mod.pattern.3 \
                  mod.pattern.4
../bin/sample_adjust -i mod.sample.1 -o sample.sdrum \
                     -sn sntab1d.dat -snchannel 1 -pad -dyn_offset 112
../bin/sample_adjust -i mod.sample.2 -o sample.bdrum \
                     -sn sntab1d.dat -snchannel 1 -pad
../bin/sample_adjust -i mod.sample.3 -o sample.bass \
                     -sn sntab1d.dat -snchannel 2 -pad -dyn_offset 112
../bin/sample_adjust -i mod.sample.4 -o sample.hdrum \
                     -sn sntab1d.dat -snchannel 3 -pad -static_offset 128
~/beebasm/beebasm -i ../../beeb/p15k_3sep.asm -do ../play_robo.ssd
