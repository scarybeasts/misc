\\ discutil.asm
\\ Useful utilities when working with discs and buffers.

BASE = &7A00
ZP = &50

\\ A=byte to store
\\ X=number of pages
\\ (ZP+0 ZP+1)=destination buffer
ABI_STORE = (BASE + 0)
ABI_COPY = (BASE + 3)
ABI_CRC16 = (BASE + 6)
\\ A=number of bytes to add (0==256)
\\ (ZP+0 ZP+1)=4 byte CRC32 buffer
\\ (ZP+2 ZP+3)=source byte buffer
ABI_CRC32 = (BASE + 9)

ORG ZP
GUARD (ZP + 32)

.var_zp_ABI_buf_1 SKIP 2
.var_zp_ABI_buf_2 SKIP 2
.var_zp_temp SKIP 1
.var_zp_temp_2 SKIP 1
.var_zp_temp_3 SKIP 1

ORG BASE
GUARD (BASE + &0200)

.discutil_begin

    \\ base + &00, store
    JMP entry_store
    NOP:NOP:NOP
    NOP:NOP:NOP
    \\ base + &09, CRC32
    JMP entry_crc32

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


.entry_crc32
    STA var_zp_temp
  .entry_crc32_byte_loop
    LDY #0
    LDA (var_zp_ABI_buf_2),Y
    LDY #3
    EOR (var_zp_ABI_buf_1),Y
    STA (var_zp_ABI_buf_1),Y

    LDA #8
    STA var_zp_temp_2
  .entry_crc32_shift_loop
    LDY #3
    LDA (var_zp_ABI_buf_1),Y
    AND #1
    STA var_zp_temp_3

    LDY #0
    LDX #4
    CLC
  .entry_crc32_rotate_loop
    LDA (var_zp_ABI_buf_1),Y
    ROR A
    STA (var_zp_ABI_buf_1),Y
    INY
    DEX
    BNE entry_crc32_rotate_loop

    LDA var_zp_temp_3
    BEQ entry_crc32_no_eor
    LDY #0
    LDA (var_zp_ABI_buf_1),Y
    EOR #&ED
    STA (var_zp_ABI_buf_1),Y
    INY
    LDA (var_zp_ABI_buf_1),Y
    EOR #&B8
    STA (var_zp_ABI_buf_1),Y
    INY
    LDA (var_zp_ABI_buf_1),Y
    EOR #&83
    STA (var_zp_ABI_buf_1),Y
    INY
    LDA (var_zp_ABI_buf_1),Y
    EOR #&20
    STA (var_zp_ABI_buf_1),Y

  .entry_crc32_no_eor
    DEC var_zp_temp_2
    BNE entry_crc32_shift_loop

    INC var_zp_ABI_buf_2
    BNE entry_crc32_no_hi_inc
    INC var_zp_ABI_buf_2 + 1
  .entry_crc32_no_hi_inc
    DEC var_zp_temp
    BNE entry_crc32_byte_loop

    RTS


.discutil_end

SAVE "DUTLASM", discutil_begin, discutil_end
