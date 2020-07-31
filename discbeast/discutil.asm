\\ discutil.asm
\\ Useful utilities when working with discs and buffers.

BASE = &7A00
ZP = &50

\\ A=byte to store
\\ (ZP+0 ZP+1)=destination buffer
\\ (ZP+3 ZP+4)=length, negated
ABI_STORE = (BASE + 0)
\\ (ZP+0 ZP+1)=destination buffer
\\ (ZP+2 ZP+3)=destination buffer
\\ (ZP+3 ZP+4)=length, negated
ABI_COPY = (BASE + 3)
\\ X=CRC16 hi byte
\\ Y=CRC16 lo byte
\\ (ZP+2 ZP+3)=source byte buffer
\\ (ZP+4 ZP+5)=length, negated
ABI_CRC16 = (BASE + 6)
\\ (ZP+0 ZP+1)=4 byte CRC32 buffer, big endian
\\ (ZP+2 ZP+3)=source byte buffer
\\ (ZP+4 ZP+5)=length, negated
ABI_CRC32 = (BASE + 9)
\\ (ZP+0 ZP+1)=source buffer 1
\\ (ZP+2 ZP+3)=source buffer 2
\\ (ZP+3 ZP+4)=length, negated
ABI_CMP = (BASE + 12)

ORG ZP
GUARD (ZP + 16)

.var_zp_ABI_buf_1 SKIP 2
.var_zp_ABI_buf_2 SKIP 2
.var_zp_ABI_length SKIP 2
.var_zp_temp SKIP 1
.var_zp_temp_2 SKIP 1
.var_zp_temp_3 SKIP 1
.var_zp_temp_4 SKIP 1
.var_zp_temp_5 SKIP 1

ORG BASE
GUARD (BASE + &0200)

.discutil_begin

    \\ base + 0, store
    JMP entry_store
    \\ base + 3, copy
    JMP entry_copy
    \\ base + 6, CRC16
    JMP entry_crc16
    \\ base + 9, CRC32
    JMP entry_crc32
    \\ base + 12, CRC32
    JMP entry_cmp

.entry_store
    TAY
    LDA var_zp_ABI_length
    ORA var_zp_ABI_length + 1
    BEQ entry_store_done
    TYA
    LDY #0
  .entry_store_loop
    STA (var_zp_ABI_buf_1),Y
    INC var_zp_ABI_buf_1
    BNE entry_store_no_inc_hi_1
    INC var_zp_ABI_buf_1 + 1
  .entry_store_no_inc_hi_1
    INC var_zp_ABI_length
    BNE entry_store_loop
    INC var_zp_ABI_length + 1
    BNE entry_store_loop
  .entry_store_done
    RTS

.entry_copy
    LDA var_zp_ABI_length
    ORA var_zp_ABI_length + 1
    BEQ entry_copy_done
    LDY #0
  .entry_copy_loop
    LDA (var_zp_ABI_buf_2),Y
    STA (var_zp_ABI_buf_1),Y
    INC var_zp_ABI_buf_2
    BNE entry_copy_no_inc_hi_1
    INC var_zp_ABI_buf_2 + 1
  .entry_copy_no_inc_hi_1
    INC var_zp_ABI_buf_1
    BNE entry_copy_no_inc_hi_2
    INC var_zp_ABI_buf_1 + 1
  .entry_copy_no_inc_hi_2
    INC var_zp_ABI_length
    BNE entry_copy_loop
    INC var_zp_ABI_length + 1
    BNE entry_copy_loop
  .entry_copy_done
    RTS

.entry_crc16
    STX var_zp_temp_2
    STY var_zp_temp_3
    LDA var_zp_ABI_length
    BNE entry_crc16_not_zero
    LDA var_zp_ABI_length + 1
    BEQ entry_crc16_done
  .entry_crc16_not_zero
    LDY #0
  .entry_crc16_byte_loop
    LDA (var_zp_ABI_buf_2),Y
    STA var_zp_temp_4
    LDX #8
  .entry_crc16_bit_loop
    LDA var_zp_temp_4
    EOR var_zp_temp_2
    STA var_zp_temp_5
    CLC
    ROL var_zp_temp_3
    ROL var_zp_temp_2
    LDA var_zp_temp_5
    BPL entry_crc16_no_eor
    LDA var_zp_temp_2
    EOR #&10
    STA var_zp_temp_2
    LDA var_zp_temp_3
    EOR #&21
    STA var_zp_temp_3
  .entry_crc16_no_eor
    ASL var_zp_temp_4
    DEX
    BNE entry_crc16_bit_loop

    INC var_zp_ABI_buf_2
    BNE entry_crc16_no_hi_inc
    INC var_zp_ABI_buf_2 + 1
  .entry_crc16_no_hi_inc
    INC var_zp_ABI_length
    BNE entry_crc16_byte_loop
    INC var_zp_ABI_length + 1
    BEQ entry_crc16_done
    JMP entry_crc16_byte_loop
  .entry_crc16_done
    LDX var_zp_temp_2
    LDY var_zp_temp_3
    RTS

.entry_crc32
    LDA var_zp_ABI_length
    BNE entry_crc32_not_zero
    LDA var_zp_ABI_length + 1
    BEQ entry_crc32_done
  .entry_crc32_not_zero
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
    INC var_zp_ABI_length
    BNE entry_crc32_byte_loop
    INC var_zp_ABI_length + 1
    BEQ entry_crc32_done
    JMP entry_crc32_byte_loop
  .entry_crc32_done
    RTS

.entry_cmp
    LDA var_zp_ABI_length
    ORA var_zp_ABI_length + 1
    BEQ entry_cmp_done
    LDY #0
  .entry_cmp_loop
    LDA (var_zp_ABI_buf_1),Y
    CMP (var_zp_ABI_buf_2),Y
    BNE entry_cmp_not_equal
    INC var_zp_ABI_buf_1
    BNE entry_cmp_no_inc_hi_1
    INC var_zp_ABI_buf_1 + 1
  .entry_cmp_no_inc_hi_1
    INC var_zp_ABI_buf_2
    BNE entry_cmp_no_inc_hi_2
    INC var_zp_ABI_buf_2 + 1
  .entry_cmp_no_inc_hi_2
    INC var_zp_ABI_length
    BNE entry_cmp_loop
    INC var_zp_ABI_length + 1
    BNE entry_cmp_loop
  .entry_cmp_done
    LDA #0
    RTS
  .entry_cmp_not_equal
    LDA #1
    RTS


.discutil_end

SAVE "DUTLASM", discutil_begin, discutil_end
