\\ viatest: VIA T2 behaviour in the shift mode the beebmod players use
\\ (ACR &10: shift out, free running at T2's rate), on both VIAs, with the
\\ results on a MODE 7 screen (one page per VIA). Runs on a Model B or a
\\ Master 128: NMOS opcodes only, and every instruction in a timed sequence
\\ takes the same cycles on both CPUs. See NOTES.md.
\\
\\ Timing: VIA accesses are stretched to the 1MHz clock (5 or 6 cycles for an
\\ abs access, by phase). A stretched access ends in phase, so two accesses
\\ an even number of CPU cycles apart (start to start) are both 5-cycle and
\\ exactly that many half-microseconds apart. Every timed sequence below
\\ keeps its VIA accesses an even number of cycles apart, so after the
\\ first access everything is deterministic, whatever the machine.
\\
\\ Samplers: 32 unrolled reads of one register into &70-&8F, every 4us
\\ (LDA abs + STA zp: 8 cycles) or every 8us (plus 4 NOPs). A sampler is
\\ entered with JSR straight after a test's last VIA write; its JMP
\\ (self-modified) first runs 0-3 NOPs, so four runs at phases 0-3 give a
\\ 1us-resolution sequence (sample i of phase m is at 4i + m us).

oswrch = &FFEE
osrdch = &FFE0
osbyte = &FFF4

zbuf = &70              \\ &70-&8F: sampler buffer (32 bytes)
cp = &50                \\ sampler address (set_phase)
dp = &52                \\ copy destination
rp = &54                \\ analysis source
rp2 = &56
phase = &58
lval = &59
mism = &5A
per = &5B
ffpos = &5C
nch = &5D
nbad = &5E
wrap = &5F
sp = &60
spbad = &61
nvals = &62
tmp = &63
tmp2 = &64
okall = &65
vbase = &66             \\ VIA base low byte (&40 or &60)
page = &67
first = &68
shrow = &69             \\ show_hi's row and letter
shlet = &6A
pd_tmp = &6B
gmin = &6C              \\ E's high-byte cascade: fewest and most samples
gmax = &6D              \\ between successive changes
eff = &6E               \\ E's first FF (us after its first sample)
vals = &30              \\ &30-&3F: values for display (up to 16)

\\ Results per VIA: offsets into a 1K block.
RA = 0          \\ A: T2C-L, 1us resolution, 128 bytes
RB = 128        \\ B: T2C-H every 8us, players' order, 32
RC = 160        \\ C: T2C-H every 8us, shift mode first, 32
RP = 192        \\ P: T2C-H every 8us, from pulse counting, 32
RD = 224        \\ D: T2C-L 1us after a latch change, 128
RD0 = 352       \\ D0: same with the latch rewritten unchanged, 128
RE = 480        \\ E: T2C-L 1us after a T2C-H write, 128
REH = 608       \\ E: T2C-H every 4us after the write, 32
RFI = 640       \\ F: IFR every 8us, 32
RFH = 672       \\ F: T2C-H every 8us (same timing), 32
RG = 704        \\ G: SR every 8us, 32
RH = 736        \\ H: T2C-H every 4us, latch 2, 4 phases, 128
RS = 864        \\ S: T2C-L 1us after an SR write (as D0, latch 20), 128
RSAVE = 992     \\ saved ACR, IER (2)
RES_SIZE = 1024

SYS = &FE40
USR = &FE60

ORG &1900
GUARD &7C00

.start
  LDA #0
  LDX #1
  JSR osbyte              \\ OSBYTE 0: X = OS version
  STX osver
  SEI
  LDA SYS + &B
  STA res_sys + RSAVE
  LDA SYS + &E
  STA res_sys + RSAVE + 1
  LDA USR + &B
  STA res_usr + RSAVE
  LDA USR + &E
  STA res_usr + RSAVE + 1
  JSR tests_sys
  JSR tests_usr
  \\ Restore both VIAs for the OS: ACR, interrupt flags, IER. The tests
  \\ leave T1 in one-shot mode (ACR bit 6 clear), where it times out once
  \\ and then stays disarmed until T1C-H is written, so the OS's 100Hz T1
  \\ (and its keyboard scanning) is re-armed from its own latch.
  LDA res_sys + RSAVE
  STA SYS + &B
  LDA SYS + 7             \\ T1L-H
  STA SYS + 5             \\ T1C-H: counter = latch, re-armed
  LDA #&7F
  STA SYS + &D
  STA SYS + &E
  LDA res_sys + RSAVE + 1
  ORA #&80
  STA SYS + &E
  LDA res_usr + RSAVE
  STA USR + &B
  LDA #&7F
  STA USR + &D
  STA USR + &E
  LDA res_usr + RSAVE + 1
  ORA #&80
  STA USR + &E
  CLI
  LDA #0
  STA page
.show
  JSR show_page
  JSR osrdch
  LDA page
  EOR #1
  STA page
  JMP show

.osver
  EQUB 0

\\ ============================================================== samplers
\\ Entered with JSR. The JMP's operand selects how many of the three NOPs
\\ run first (set_phase).
MACRO SAMPLER4 reg
  JMP P% + 6
  NOP
  NOP
  NOP
  FOR i, 0, 31
    LDA reg
    STA zbuf + i
  NEXT
  RTS
ENDMACRO

MACRO SAMPLER8 reg
  JMP P% + 6
  NOP
  NOP
  NOP
  FOR i, 0, 31
    LDA reg
    STA zbuf + i
    NOP
    NOP
    NOP
    NOP
  NEXT
  RTS
ENDMACRO

.s_sys_lo4
  SAMPLER4 SYS + 8
.s_sys_hi4
  SAMPLER4 SYS + 9
.s_sys_hi8
  SAMPLER8 SYS + 9
.s_sys_ifr8
  SAMPLER8 SYS + &D
.s_sys_sr8
  SAMPLER8 SYS + &A
.s_usr_lo4
  SAMPLER4 USR + 8
.s_usr_hi4
  SAMPLER4 USR + 9
.s_usr_hi8
  SAMPLER8 USR + 9
.s_usr_ifr8
  SAMPLER8 USR + &D
.s_usr_sr8
  SAMPLER8 USR + &A

\\ The sampler at (cp) runs `phase` NOPs before its first read: its JMP goes
\\ to cp + 6 - phase.
.set_phase
  LDA #6
  SEC
  SBC phase
  CLC
  ADC cp
  LDY #1
  STA (cp),Y
  LDA cp + 1
  ADC #0
  INY
  STA (cp),Y
  RTS

\\ Copy the 32 samples to (dp) + 4i + phase (interleaved) or (dp) + i.
.copy4
  LDY phase
  LDX #0
.copy4_loop
  LDA zbuf,X
  STA (dp),Y
  INY
  INY
  INY
  INY
  INX
  CPX #32
  BNE copy4_loop
  RTS
.copy1
  LDY #0
.copy1_loop
  LDA zbuf,Y
  STA (dp),Y
  INY
  CPY #32
  BNE copy1_loop
  RTS

\\ ================================================================ tests
\\ Each run: set the sampler's phase, then (timed) the VIA setup, ending
\\ with the run's last VIA write straight before JSR sampler.
MACRO SETUP_RUN smp, m
  LDA #LO(smp)
  STA cp
  LDA #HI(smp)
  STA cp + 1
  LDA #m
  STA phase
  JSR set_phase
ENDMACRO
\\ The pause before the event in D, D0 and E: 20 NOPs (40 cycles), with no
\\ branch (a loop's timing would depend on where each copy sits).
MACRO WAIT_NOPS
  FOR i, 1, 20
    NOP
  NEXT
ENDMACRO
MACRO DEST d
  LDA #LO(d)
  STA dp
  LDA #HI(d)
  STA dp + 1
ENDMACRO

MACRO VIA_TESTS via, res, s_lo4, s_hi4, s_hi8, s_ifr8, s_sr8
  \\ ---- A: T2C-L at 1us resolution. Players' order: latch 5, T2C-H, ACR
  \\ &10, SR. A standard 6522 counts 5..0, FF, 5.. (period 7us), so any 16
  \\ samples show two reloads. (ACR goes to &10 about 3us after the T2C-H
  \\ write, before the one-shot count FF05 can underflow at 6us.)
  FOR m, 0, 3
    SETUP_RUN s_lo4, m
    LDA #0
    STA via + &B
    LDA #5
    STA via + 8
    LDA #&FF
    STA via + 9
    LDA #&10
    STA via + &B
    STA via + &A
    JSR s_lo4
    DEST res + RA
    JSR copy4
  NEXT
  \\ ---- B: T2C-H every 8us. Players' order: latch 30, T2C-H = 2, ACR &10,
  \\ SR. Expected: 2, 1, 0, FF, FE.. one step per 32us.
  SETUP_RUN s_hi8, 0
  LDA #0
  STA via + &B
  LDA #30
  STA via + 8
  LDA #2
  STA via + 9
  LDA #&10
  STA via + &B
  STA via + &A
  JSR s_hi8
  DEST res + RB
  JSR copy1
  \\ ---- C: as B, but shift mode first (T2 already running), then the latch
  \\ and T2C-H written in shift mode.
  SETUP_RUN s_hi8, 0
  LDA #0
  STA via + &B
  LDA #30
  STA via + 8
  LDA #&FF
  STA via + 9
  LDA #&10
  STA via + &B
  STA via + &A
  LDA #30
  STA via + 8
  LDA #2
  STA via + 9
  JSR s_hi8
  DEST res + RC
  JSR copy1
  \\ ---- P: as B, but from T2 pulse counting (ACR &60, the OS's system VIA
  \\ setting: T2 loaded but frozen), then ACR &10.
  SETUP_RUN s_hi8, 0
  LDA #&60
  STA via + &B
  LDA #30
  STA via + 8
  LDA #2
  STA via + 9
  LDA #&10
  STA via + &B
  STA via + &A
  JSR s_hi8
  DEST res + RP
  JSR copy1
  \\ ---- D: latch 20 running in shift mode; then the latch is changed to 6.
  \\ Expected: the count in progress carries on undisturbed; from its
  \\ reload on, 6..0, FF (period 8us). D0: the same with the latch
  \\ rewritten as 20 (no change), the baseline for E.
  FOR m, 0, 3
    SETUP_RUN s_lo4, m
    LDA #0
    STA via + &B
    LDA #20
    STA via + 8
    LDA #&FF
    STA via + 9
    LDA #&10
    STA via + &B
    STA via + &A
    WAIT_NOPS
    LDA #6
    STA via + 8
    JSR s_lo4
    DEST res + RD
    JSR copy4
  NEXT
  FOR m, 0, 3
    SETUP_RUN s_lo4, m
    LDA #0
    STA via + &B
    LDA #20
    STA via + 8
    LDA #&FF
    STA via + 9
    LDA #&10
    STA via + &B
    STA via + &A
    WAIT_NOPS
    LDA #20
    STA via + 8
    JSR s_lo4
    DEST res + RD0
    JSR copy4
  NEXT
  \\ ---- E: as D0, but T2C-H = &80 written instead (the players' rebase).
  \\ Expected (as the players' rate model assumes): T2C-H reads &80 at
  \\ once, and the low counter restarts from the latch at the write.
  FOR m, 0, 3
    SETUP_RUN s_lo4, m
    LDA #0
    STA via + &B
    LDA #20
    STA via + 8
    LDA #&FF
    STA via + 9
    LDA #&10
    STA via + &B
    STA via + &A
    WAIT_NOPS
    LDA #&80
    STA via + 9
    JSR s_lo4
    DEST res + RE
    JSR copy4
  NEXT
  SETUP_RUN s_hi4, 0
  LDA #0
  STA via + &B
  LDA #20
  STA via + 8
  LDA #&FF
  STA via + 9
  LDA #&10
  STA via + &B
  STA via + &A
  WAIT_NOPS
  LDA #&80
  STA via + 9
  JSR s_hi4
  DEST res + REH
  JSR copy1
  \\ ---- S: as D0, but an SR write (&55) instead of the latch rewrite. The
  \\ players write SR once at init: the count should carry on as in D0.
  FOR m, 0, 3
    SETUP_RUN s_lo4, m
    LDA #0
    STA via + &B
    LDA #20
    STA via + 8
    LDA #&FF
    STA via + 9
    LDA #&10
    STA via + &B
    STA via + &A
    WAIT_NOPS
    LDA #&55
    STA via + &A
    JSR s_lo4
    DEST res + RS
    JSR copy4
  NEXT
  \\ ---- F: the T2 interrupt flag (IFR bit 5) in shift mode: latch 14
  \\ (16us), T2C-H = 2; T2, CB1 and SR flags cleared; IFR every 8us, then
  \\ T2C-H the same way (an identical run).
  SETUP_RUN s_ifr8, 0
  LDA #0
  STA via + &B
  LDA #14
  STA via + 8
  LDA #2
  STA via + 9
  LDA #&10
  STA via + &B
  STA via + &A
  LDA #&34
  STA via + &D
  JSR s_ifr8
  DEST res + RFI
  JSR copy1
  SETUP_RUN s_hi8, 0
  LDA #0
  STA via + &B
  LDA #14
  STA via + 8
  LDA #2
  STA via + 9
  LDA #&10
  STA via + &B
  STA via + &A
  LDA #&34
  STA via + &D
  JSR s_hi8
  DEST res + RFH
  JSR copy1
  \\ ---- G: the shift register in mode &10: latch 4 (one bit every 2 x 6us),
  \\ SR = &81; SR every 8us. A standard 6522 recirculates: &81, &03, &06..
  SETUP_RUN s_sr8, 0
  LDA #0
  STA via + &B
  LDA #4
  STA via + 8
  LDA #&FF
  STA via + 9
  LDA #&10
  STA via + &B
  LDA #&81
  STA via + &A
  JSR s_sr8
  DEST res + RG
  JSR copy1
  \\ ---- H: T2C-H read consistency: latch 2 (4us), read every 4us at all
  \\ four phases: each read should be exactly one below the one before.
  \\ The four phases put the read at each microsecond of the reload cycle.
  \\ (Shift mode first with latch 20, then latch 2 and T2C-H = &FF, as the
  \\ players start a note: with latch 2 set before ACR, the low byte would
  \\ underflow in one-shot mode first and shift mode would start at &FF.)
  FOR m, 0, 3
    SETUP_RUN s_hi4, m
    LDA #0
    STA via + &B
    LDA #20
    STA via + 8
    LDA #&FF
    STA via + 9
    LDA #&10
    STA via + &B
    STA via + &A
    LDA #2
    STA via + 8
    LDA #&FF
    STA via + 9
    JSR s_hi4
    DEST res + RH
    JSR copy4
  NEXT
  \\ Leave the VIA quiet: ACR 0 (the caller restores the OS's values).
  LDA #0
  STA via + &B
  RTS
ENDMACRO

.tests_sys
  VIA_TESTS SYS, res_sys, s_sys_lo4, s_sys_hi4, s_sys_hi8, s_sys_ifr8, s_sys_sr8
.tests_usr
  VIA_TESTS USR, res_usr, s_usr_lo4, s_usr_hi4, s_usr_hi8, s_usr_ifr8, s_usr_sr8

\\ ============================================================== analysis
\\ lowseq: (rp) = 128 T2C-L values 1us apart; lval = the latch reloads use.
\\ mism = steps that aren't v-1 (or FF -> latch); per = us between the
\\ first two FFs (0 if fewer); ffpos = index of the first FF (&FF if none).
.lowseq
  LDA #0
  STA mism
  STA per
  LDA #&FF
  STA ffpos
  LDY #0
.ls_loop
  LDA (rp),Y
  CMP #&FF
  BNE ls_notff
  LDX ffpos
  CPX #&FF
  BNE ls_second
  STY ffpos
  JMP ls_next
.ls_second
  LDX per
  BNE ls_next
  TYA
  SEC
  SBC ffpos
  STA per
  JMP ls_next
.ls_notff
.ls_next
  \\ expected next value
  LDA (rp),Y
  CMP #&FF
  BNE ls_dec
  LDA lval
  JMP ls_cmp
.ls_dec
  SEC
  SBC #1
.ls_cmp
  INY
  CPY #128
  BEQ ls_done
  CMP (rp),Y
  BEQ ls_loop
  INC mism
  JMP ls_loop
.ls_done
  RTS

\\ hiseq: (rp) = 32 T2C-H values. nch = changes; nbad = changes that
\\ aren't -1; wrap = 1 if 00 -> FF seen; first = index of the first change;
\\ sp = samples between the first two changes; spbad = later spacings that
\\ differ; vals = the starting value and each new one (up to 8).
.hiseq
  LDA #0
  STA nch
  STA nbad
  STA wrap
  STA sp
  STA spbad
  LDA #&FF
  STA first
  STA tmp2                \\ index of the last change
  LDY #0
  LDA (rp),Y
  STA vals
  LDA #1
  STA nvals
.hs_loop
  LDA (rp),Y
  STA tmp
  INY
  CPY #32
  BEQ hs_done
  LDA (rp),Y
  CMP tmp
  BEQ hs_loop
  \\ a change
  INC nch
  LDX nvals
  CPX #8
  BCS hs_novals
  STA vals,X
  INC nvals
.hs_novals
  CLC
  ADC #1
  CMP tmp
  BEQ hs_step_ok
  INC nbad
.hs_step_ok
  LDA tmp
  BNE hs_nowrap
  LDA (rp),Y
  CMP #&FF
  BNE hs_nowrap
  LDA #1
  STA wrap
.hs_nowrap
  LDA first
  CMP #&FF
  BNE hs_later
  STY first
  STY tmp2
  JMP hs_loop
.hs_later
  TYA
  SEC
  SBC tmp2
  STY tmp2
  LDX sp
  BNE hs_cmpsp
  STA sp
  JMP hs_loop
.hs_cmpsp
  CMP sp
  BEQ hs_loop
  INC spbad
  JMP hs_loop
.hs_done
  RTS

\\ hverdict: A = 0 if the hiseq results are as a standard 6522 with a
\\ 32us period at 8us sampling (spacing 4), else 1.
.hverdict
  LDA nch
  CMP #6
  BCC hv_bad
  LDA nbad
  BNE hv_bad
  LDA wrap
  BEQ hv_bad
  LDA sp
  CMP #4
  BNE hv_bad
  LDA spbad
  BNE hv_bad
  LDA #0
  RTS
.hv_bad
  LDA #1
  RTS

\\ gaps: (rp) = 32 samples. gmin, gmax = the fewest and most samples
\\ between successive changes (&FF and 0 with fewer than two changes).
.gaps
  LDA #&FF
  STA gmin
  STA tmp2                \\ index of the last change (&FF: none yet)
  LDA #0
  STA gmax
  LDY #0
.gp_loop
  LDA (rp),Y
  STA tmp
  INY
  CPY #32
  BEQ gp_done
  LDA (rp),Y
  CMP tmp
  BEQ gp_loop
  LDA tmp2
  CMP #&FF
  BEQ gp_first
  TYA
  SEC
  SBC tmp2
  CMP gmin
  BCS gp_nomin
  STA gmin
.gp_nomin
  CMP gmax
  BCC gp_first
  STA gmax
.gp_first
  STY tmp2
  JMP gp_loop
.gp_done
  RTS

\\ ================================================================ display
.show_page
  LDA #22
  JSR oswrch
  LDA #7
  JSR oswrch
  \\ cursor off
  LDX #0
.cur_off
  LDA cur_off_vdu,X
  JSR oswrch
  INX
  CPX #10
  BNE cur_off
  LDA #0
  STA okall
  LDA page
  BNE show_usr
  LDA #LO(res_sys)
  STA rp
  LDA #HI(res_sys)
  STA rp + 1
  LDA #&40
  STA vbase
  JMP show_body
.show_usr
  LDA #LO(res_usr)
  STA rp
  LDA #HI(res_usr)
  STA rp + 1
  LDA #&60
  STA vbase
.show_body
  \\ keep the block's base in rp2
  LDA rp
  STA rp2
  LDA rp + 1
  STA rp2 + 1
  \\ ---- header
  LDY #0
  JSR goto_row
  JSR print_inline
  EQUS &86, "VIA T2 TEST v2 OS", 0
  LDA osver
  JSR print_hex
  JSR print_inline
  EQUS " ", &83, 0
  LDA page
  BNE hdr_usr
  JSR print_inline
  EQUS "SYSTEM VIA", 0
  JMP hdr_2
.hdr_usr
  JSR print_inline
  EQUS "USER VIA", 0
.hdr_2
  LDY #1
  JSR goto_row
  JSR print_inline
  EQUS &87, "OS had ACR ", 0
  LDA #RSAVE DIV 32
  JSR set_rp
  LDY #0
  LDA (rp),Y
  JSR print_hex
  JSR print_inline
  EQUS " IER ", 0
  LDY #1
  LDA (rp),Y
  JSR print_hex

  \\ ---- A
  LDA #RA DIV 32
  JSR set_rp
  LDA #5
  STA lval
  JSR lowseq
  LDY #3
  JSR goto_row
  JSR print_inline
  EQUS &86, "A lo", &87, 0
  LDY #0
  LDX #16
  JSR print_seq
  LDY #4
  JSR goto_row
  JSR print_inline
  EQUS &87, " period ", 0
  LDA per
  JSR print_dec
  JSR print_inline
  EQUS "us (7) bad ", 0
  LDA mism
  JSR print_dec
  LDA per
  CMP #7
  BNE a_bad
  LDA mism
  BNE a_bad
  LDA #0
  BEQ a_v
.a_bad
  LDA #1
.a_v
  JSR print_verdict

  \\ ---- B, C, P
  LDA #RB DIV 32
  LDX #5
  LDY #'B'
  JSR show_hi
  LDA #RC DIV 32
  LDX #7
  LDY #'C'
  JSR show_hi
  LDA #RP DIV 32
  LDX #9
  LDY #'P'
  JSR show_hi

  \\ ---- D: after the latch change (6); D0 baseline
  LDA #RD DIV 32
  JSR set_rp
  LDA #6
  STA lval
  JSR lowseq
  LDY #11
  JSR goto_row
  JSR print_inline
  EQUS &86, "D lo", &87, 0
  LDY #0
  LDX #16
  JSR print_seq
  LDY #12
  JSR goto_row
  JSR print_inline
  EQUS &87, " new per ", 0
  LDA per
  JSR print_dec
  JSR print_inline
  EQUS "us (8) bad ", 0
  LDA mism
  JSR print_dec
  LDA per
  CMP #8
  BNE d_bad
  LDA mism
  BNE d_bad
  LDA #0
  BEQ d_v
.d_bad
  LDA #1
.d_v
  JSR print_verdict

  \\ ---- E: after the T2C-H write (&80), against D0 (no write)
  \\ Row 13: 16 values of T2C-L from 3 before the first FF (the reload).
  LDA #RE DIV 32
  JSR set_rp
  LDA #20
  STA lval
  JSR lowseq
  LDA ffpos
  STA eff
  LDY #13
  JSR goto_row
  JSR print_inline
  EQUS &86, "E lo", &87, 0
  LDY #0
  LDA eff
  CMP #&FF
  BEQ e_from
  CMP #3
  BCC e_from
  SBC #3
  CMP #113                \\ (stay within the 128 samples)
  BCC e_from_y
  LDA #112
.e_from_y
  TAY
.e_from
  LDX #16
  JSR print_seq
  \\ Row 14: the period and steps after the write (reloads to 20).
  LDY #14
  JSR goto_row
  JSR print_inline
  EQUS &87, " per ", 0
  LDA per
  JSR print_dec
  JSR print_inline
  EQUS "us (22) bad ", 0
  LDA mism
  JSR print_dec
  JSR print_inline
  EQUS " FF at ", 0
  LDA eff
  CMP #&FF
  BEQ e_noff
  JSR print_dec
  JSR print_inline
  EQUS "us", 0
  JMP e_per_v
.e_noff
  JSR print_inline
  EQUS "none", 0
.e_per_v
  LDA per
  CMP #22
  BNE e_per_bad
  LDA mism
  BNE e_per_bad
  LDA #0
  BEQ e_per_pv
.e_per_bad
  LDA #1
.e_per_pv
  JSR print_verdict
  \\ Row 15: the write restarts the low counter: E's first values differ
  \\ from D0's (the same moment without the write).
  LDY #15
  JSR goto_row
  JSR print_inline
  EQUS &87, " restart ", 0
  LDY #0
  LDX #4
  JSR print_seq
  JSR print_inline
  EQUS " was ", 0
  LDA #RD0 DIV 32
  JSR set_rp
  LDY #0
  LDX #4
  JSR print_seq
  LDY #0
  LDA (rp),Y
  STA tmp
  LDA #RE DIV 32
  JSR set_rp
  LDY #0
  LDA (rp),Y
  CMP tmp
  BEQ e_rs_bad
  LDA #0
  BEQ e_rs_pv
.e_rs_bad
  LDA #1
.e_rs_pv
  JSR print_verdict
  \\ Row 16: T2C-H every 4us after the write: its first read and each new
  \\ value. Row 17: changes, bad changes (not -1), when the first came,
  \\ the gaps between them. A standard 6522: 80 first, all -1, the first
  \\ change at the low byte's first FF (to the 4us sampling), then every
  \\ 22us (5 or 6 samples).
  LDA #REH DIV 32
  JSR set_rp
  JSR hiseq
  JSR gaps
  LDY #16
  JSR goto_row
  JSR print_inline
  EQUS &86, "E hi", &87, 0
  LDX #0
.e_vals
  LDA vals,X
  JSR print_sp_hex
  INX
  CPX nvals
  BNE e_vals
  LDY #17
  JSR goto_row
  JSR print_inline
  EQUS &87, " chg ", 0
  LDA nch
  JSR print_dec
  JSR print_inline
  EQUS " bad ", 0
  LDA nbad
  JSR print_dec
  JSR print_inline
  EQUS " at ", 0
  LDA first
  CMP #&FF
  BEQ e_nofirst
  ASL A
  ASL A
  JSR print_dec
  JSR print_inline
  EQUS "us", 0
  JMP e_gaps
.e_nofirst
  JSR print_inline
  EQUS "--", 0
.e_gaps
  JSR print_inline
  EQUS " gaps ", 0
  LDA gmin
  CMP #&FF
  BEQ e_nogaps
  ASL A
  ASL A
  JSR print_dec
  LDA #'-'
  JSR oswrch
  LDA gmax
  ASL A
  ASL A
  JSR print_dec
  JMP e_hi_v
.e_nogaps
  JSR print_inline
  EQUS "--", 0
.e_hi_v
  \\ verdict: first read 80, at least 4 changes, all -1, the first within
  \\ 0-4us after the low byte's first FF, every gap 5 or 6 samples
  LDY #0
  LDA (rp),Y
  CMP #&80
  BNE e_hi_bad
  LDA nch
  CMP #4
  BCC e_hi_bad
  LDA nbad
  BNE e_hi_bad
  LDA eff
  CMP #&FF
  BEQ e_hi_bad
  LDA first
  CMP #&FF
  BEQ e_hi_bad
  ASL A
  ASL A
  SEC
  SBC eff
  BCC e_hi_bad            \\ (the change before the FF)
  CMP #5
  BCS e_hi_bad
  LDA gmin
  CMP #5
  BCC e_hi_bad
  LDA gmax
  CMP #7
  BCS e_hi_bad
  LDA #0
  BEQ e_hi_pv
.e_hi_bad
  LDA #1
.e_hi_pv
  JSR print_verdict

  \\ ---- S: after the SR write, against D0
  LDA #RS DIV 32
  JSR set_rp
  LDY #18
  JSR goto_row
  JSR print_inline
  EQUS &86, "S sr", &87, 0
  LDY #0
  LDX #8
  JSR print_seq
  JSR print_inline
  EQUS " was ", 0
  LDA #RD0 DIV 32
  JSR set_rp
  LDY #0
  LDX #4
  JSR print_seq
  \\ verdict: the first 32 values (32us) as D0
  LDA #0
  STA nbad
  LDY #0
.s_cmp
  LDA #RS DIV 32
  JSR set_rp
  LDA (rp),Y
  STA tmp
  LDA #RD0 DIV 32
  JSR set_rp
  LDA (rp),Y
  CMP tmp
  BEQ s_same
  INC nbad
.s_same
  INY
  CPY #32
  BNE s_cmp
  LDA nbad
  JSR print_verdict

  \\ ---- F: IFR (8 values, every 32us) and where bit 5 first sets
  LDA #RFI DIV 32
  JSR set_rp
  LDY #19
  JSR goto_row
  JSR print_inline
  EQUS &86, "F ifr", &87, 0
  LDY #0
.f_vals
  LDA (rp),Y
  STY tmp2
  JSR print_sp_hex
  LDA tmp2
  CLC
  ADC #4
  TAY
  CPY #32
  BCC f_vals
  LDY #20
  JSR goto_row
  JSR print_inline
  EQUS &87, " T2 flag ", 0
  LDY #0
.f_find
  LDA (rp),Y
  AND #&20
  BNE f_found
  INY
  CPY #32
  BNE f_find
  JSR print_inline
  EQUS "never", 0
  JMP f_more
.f_found
  STY tmp2
  JSR print_inline
  EQUS "at hi ", 0
  LDA #RFH DIV 32
  JSR set_rp
  LDY tmp2
  BEQ f_first
  DEY
  LDA (rp),Y
  JSR print_hex
  INY
  JMP f_arrow
.f_first
  JSR print_inline
  EQUS "--", 0
  LDY #0
.f_arrow
  LDA #'>'
  JSR oswrch
  LDA (rp),Y
  JSR print_hex
  LDA #RFI DIV 32
  JSR set_rp
.f_more
  \\ CB1 (bit 4) and SR (bit 2) flags seen at all
  LDA #0
  STA tmp
  LDY #31
.f_or
  LDA (rp),Y
  ORA tmp
  STA tmp
  DEY
  BPL f_or
  JSR print_inline
  EQUS " cb1 ", 0
  LDA tmp
  AND #&10
  JSR print_yn
  JSR print_inline
  EQUS " sr ", 0
  LDA tmp
  AND #&04
  JSR print_yn

  \\ ---- G: SR values as they change
  LDA #RG DIV 32
  JSR set_rp
  LDY #21
  JSR goto_row
  JSR print_inline
  EQUS &86, "G sr", &87, 0
  LDY #0
  LDA (rp),Y
  STA tmp
  JSR print_sp_hex
  LDA #1
  STA nvals
  LDY #1
.g_loop
  LDA (rp),Y
  CMP tmp
  BEQ g_same
  STA tmp
  STY tmp2
  JSR print_sp_hex
  LDY tmp2
  INC nvals
  LDA nvals
  CMP #11
  BCS g_end
.g_same
  INY
  CPY #32
  BNE g_loop
.g_end

  \\ ---- H: T2C-H read glitches per phase
  LDA #RH DIV 32
  JSR set_rp
  LDY #22
  JSR goto_row
  JSR print_inline
  EQUS &86, "H hi reads", &87, "glitches", 0
  LDA #0
  STA tmp2                \\ total
  LDX #0
.h_phase
  STX phase
  LDA #0
  STA nbad
  TXA
  TAY
.h_loop
  LDA (rp),Y
  SEC
  SBC #1
  STA tmp
  TYA
  CLC
  ADC #4
  TAY
  CPY #128
  BCS h_end
  LDA (rp),Y
  CMP tmp
  BEQ h_loop
  INC nbad
  JMP h_loop
.h_end
  LDA #' '
  JSR oswrch
  LDA nbad
  JSR print_dec
  CLC
  ADC tmp2
  STA tmp2
  LDX phase
  INX
  CPX #4
  BNE h_phase
  LDA tmp2
  BEQ h_ok
  LDA #1
.h_ok
  JSR print_verdict

  \\ ---- footer
  LDY #24
  JSR goto_row
  LDA okall
  BNE foot_diff
  JSR print_inline
  EQUS &82, "all ok", &87, "SPACE: other VIA", 0
  RTS
.foot_diff
  JSR print_inline
  EQUS &81, "DIFFERS (see red)", &87, "SPACE: other VIA", 0
  RTS

\\ show_hi: A = result offset, X = screen row, Y = letter.
.show_hi
  STX shrow
  STY shlet
  JSR set_rp
  JSR hiseq
  LDY shrow
  JSR goto_row
  LDA #&86
  JSR oswrch
  LDA shlet
  JSR oswrch
  JSR print_inline
  EQUS " hi", &87, 0
  LDX #0
.sh_vals
  LDA vals,X
  JSR print_sp_hex
  INX
  CPX nvals
  BNE sh_vals
  LDY shrow
  INY
  JSR goto_row
  JSR print_inline
  EQUS &87, " chg ", 0
  LDA nch
  JSR print_dec
  JSR print_inline
  EQUS " bad ", 0
  LDA nbad
  JSR print_dec
  JSR print_inline
  EQUS " per ", 0
  LDA sp
  ASL A
  ASL A
  ASL A
  JSR print_dec
  JSR print_inline
  EQUS "us wrap ", 0
  LDA wrap
  EOR #1
  JSR print_yn_inv
  JSR hverdict
  JMP print_verdict

\\ set_rp: rp = rp2 + 32 x A (A = a result offset / 32). Uses X.
.set_rp
  STA rp
  LDA #0
  STA rp + 1
  LDX #5
.srp_shift
  ASL rp
  ROL rp + 1
  DEX
  BNE srp_shift
  LDA rp
  CLC
  ADC rp2
  STA rp
  LDA rp + 1
  ADC rp2 + 1
  STA rp + 1
  RTS

\\ ================================================================ helpers
\\ goto_row: VDU 31, 0, Y
.goto_row
  LDA #31
  JSR oswrch
  LDA #0
  JSR oswrch
  TYA
  JMP oswrch

\\ print_inline: prints the zero-terminated string after the JSR.
.print_inline
  PLA
  STA pi_ptr + 1
  PLA
  STA pi_ptr + 2
.pi_loop
  INC pi_ptr + 1
  BNE pi_load
  INC pi_ptr + 2
.pi_load
.pi_ptr
  LDA &FFFF
  BEQ pi_end
  JSR oswrch
  JMP pi_loop
.pi_end
  LDA pi_ptr + 2
  PHA
  LDA pi_ptr + 1
  PHA
  RTS

.print_hex
  PHA
  LSR A
  LSR A
  LSR A
  LSR A
  JSR print_nib
  PLA
  PHA
  AND #&0F
  JSR print_nib
  PLA
  RTS
.print_nib
  CMP #10
  BCC pn_digit
  ADC #6
.pn_digit
  ADC #'0'
  JMP oswrch

.print_sp_hex
  PHA
  LDA #' '
  JSR oswrch
  PLA
  JMP print_hex

\\ print_seq: X values from (rp) + Y, as hex without spaces.
.print_seq
  STX tmp
.ps_loop
  LDA (rp),Y
  JSR print_hex
  INY
  DEC tmp
  BNE ps_loop
  RTS

\\ print_dec: A (0-255) in decimal, no leading zeros. Preserves A.
.print_dec
  PHA
  STA pd_tmp
  LDX #0
  CMP #100
  BCC pd_tens
  LDA #'0'
  STA pd_buf
.pd_h
  LDA pd_tmp
  CMP #100
  BCC pd_h_done
  SBC #100
  STA pd_tmp
  INC pd_buf
  JMP pd_h
.pd_h_done
  LDA pd_buf
  JSR oswrch
  LDX #1
.pd_tens
  LDA #'0'
  STA pd_buf
.pd_t
  LDA pd_tmp
  CMP #10
  BCC pd_t_done
  SBC #10
  STA pd_tmp
  INC pd_buf
  JMP pd_t
.pd_t_done
  LDA pd_buf
  CPX #1
  BEQ pd_t_print
  CMP #'0'
  BEQ pd_units
.pd_t_print
  JSR oswrch
.pd_units
  LDA pd_tmp
  CLC
  ADC #'0'
  JSR oswrch
  PLA
  RTS
.pd_buf
  EQUB 0

\\ print_yn: "y" if A <> 0, else "n". print_yn_inv: the opposite.
.print_yn
  BEQ pyn_n
.pyn_y
  LDA #'y'
  JMP oswrch
.pyn_n
  LDA #'n'
  JMP oswrch
.print_yn_inv
  BEQ pyn_y
  BNE pyn_n

\\ print_verdict: A = 0: green "ok"; else red "DIFF" (and remember it).
.print_verdict
  BNE pv_bad
  JSR print_inline
  EQUS &82, "ok", 0
  RTS
.pv_bad
  LDA #1
  STA okall
  JSR print_inline
  EQUS &81, "DIFF", 0
  RTS

.cur_off_vdu
  EQUB 23, 1, 0, 0, 0, 0, 0, 0, 0, 0

\\ ================================================================ results
ALIGN 256
.res_sys
  SKIP RES_SIZE
.res_usr
  SKIP RES_SIZE
.end

SAVE "VIATEST", start, end, start
PUTTEXT "boot.txt", "!BOOT", 0
