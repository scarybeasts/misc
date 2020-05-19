#!/bin/sh
gcc -g -o hfegrab2hfe hfegrab2hfe.c
~/Downloads/beebasm/beebasm -i hfegrab.asm -do hfegrab.ssd -opt 3 -v
