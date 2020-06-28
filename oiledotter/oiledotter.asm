\\ oiledotter.asm
\\ A tool to directly drive the wires to a disc drive.

BASE = &7000
ZP = &70

ORG BASE
GUARD (BASE + 1024)

.oiledotter_begin
.oiledotter_end

SAVE "OOASM", oiledotter_begin, oiledotter_end
PUTTEXT "boot.txt", "!BOOT", 0
PUTBASIC "oiledotter.bas", "OOTTER"
