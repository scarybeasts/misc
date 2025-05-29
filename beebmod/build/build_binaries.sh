#!/bin/sh
rm -f modxtract modpatconv sample_adjust make_channel_maps
gcc -g ../util/modxtract.c -o modxtract
gcc -g ../util/modpatconv.c -o modpatconv -lm
gcc -g ../util/sample_adjust.c -o sample_adjust -lm
gcc -g ../util/make_channel_maps.c -o make_channel_maps -lm
