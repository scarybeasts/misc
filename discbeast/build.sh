#!/bin/sh
~/Downloads/beebasm/beebasm -i discutil.asm -opt 3 -v || exit
~/Downloads/beebasm/beebasm -i discbeast.asm -do discbeast.ssd -opt 3 -v || exit
