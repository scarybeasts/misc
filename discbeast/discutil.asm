\\ discutil.asm
\\ Useful utilities when working with discs and buffers.

BASE = &7A00
ZP = &50

\\ A=byte to store
\\ X=number of pages
\\ (ZP+0 ZP+1)=destination buffer
ABI_STORE = (BASE + 0)

ORG ZP
GUARD (ZP + 32)

.var_zp_ABI_buf_1 SKIP2

ORG BASE
GUARD (BASE + &0200)

.discutil_begin

    \\ base + &00, store
    JMP entry_store

.entry_store
    LDY #0
  .store_loop
    STA (var_zp_ABI_buf_1),Y
    INC var_zp_ABI_buf_1
    BNE store_loop
    INC var_zp_ABI_buf_1 + 1
    DEX
    BNE store_loop
    RTS

.discutil_end

SAVE "DUTLASM", discutil_begin, discutil_end
