#!/bin/sh
rm -rf bin
mkdir bin
gcc -g ../util/modxtract.c -o bin/modxtract
gcc -g ../util/modpatconv.c -o bin/modpatconv -lm
gcc -g ../util/sample_adjust.c -o bin/sample_adjust -lm
gcc -g ../util/make_channel_maps.c -o bin/make_channel_maps -lm
gcc -g ../util/modmod.c -o bin/modmod
