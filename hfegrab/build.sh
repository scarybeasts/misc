#!/bin/sh
~/Downloads/beebasm/beebasm -i hfegrab.asm -do hfegrab.ssd -opt 3 -v
gcc -g -o hfegrab2hfe hfegrab2hfe.c
