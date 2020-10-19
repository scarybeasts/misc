#!/bin/sh
~/Downloads/beebasm/beebasm -i test.asm -do test.ssd -opt 3 -title 8271 -v \
    || exit
