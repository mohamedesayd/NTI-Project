#!/usr/bin/env python3
"""
RISC-V Machine Code & Memory Hex Generator for SoC Simulation
=============================================================

Memory Map (BYTE addresses):
  RAM     0x0000 - 0x0FFF  (CPU & MAC access)
    Boot vector  0x0000  -> jump to main at 0x0080
    Matrix A     0x0040  (words  16-19,  4 elements)
    Matrix B     0x0080  (words  32-35,  4 elements)
    C_SW result  0x00C0  (words  48-51,  4 elements, written by CPU)
    C_HW result  0x0100  (words  64-67,  4 elements, written by MAC)
  MAC APB  0x0400 - 0x07FF
    reg[0] BASE_A  @ 0x0400  (word index into RAM)
    reg[1] BASE_B  @ 0x0404
    reg[2] BASE_C  @ 0x0408
    reg[3] M_K_N   @ 0x040C  N[11:8] K[7:4] M[3:0]
    reg[4] CTRL    @ 0x0410  bit0=start  (cleared by done_interrupt)
    reg[5] STATUS  @ 0x0414  bit0=busy
  UART     0x0800 - 0x0BFF
    TX data reg  @ 0x0800

Algorithm:
  1. Store A = [[2,3],[4,5]] and B = [[1,2],[3,4]] in RAM
  2. Compute C_SW = A*B in software, store at 0x00C0
  3. Configure MAC with A/B/C word addresses and 2x2x2 dims, start it
  4. Poll CTRL reg bit-0 until start is cleared (done_interrupt fired)
  5. Compare 4 words of C_HW vs C_SW
  6. Transmit "Test Pass\\r\\n" or "Test Fail\\r\\n" over UART
  7. Infinite loop
"""

import os

# ── Register ABI aliases ──────────────────────────────────────────────────────
ZERO=0; RA=1; SP=2; GP=3; TP=4
T0=5; T1=6; T2=7
S0=8; S1=9
A0=10; A1=11
T3=28; T4=29; T5=30; T6=31

# ── Instruction encoders ──────────────────────────────────────────────────────

def addi(rd, rs1, imm):
    """ADDI rd, rs1, imm  (I-type, funct3=000, opcode=0x13)"""
    imm12 = imm & 0xFFF
    return (imm12 << 20) | (rs1 << 15) | (0 << 12) | (rd << 7) | 0x13

def andi_inst(rd, rs1, imm):
    """ANDI rd, rs1, imm  (I-type, funct3=111, opcode=0x13)"""
    imm12 = imm & 0xFFF
    return (imm12 << 20) | (rs1 << 15) | (7 << 12) | (rd << 7) | 0x13

def lui(rd, imm20):
    """LUI rd, imm20  (U-type, opcode=0x37)"""
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | 0x37

def lw(rd, rs1, offset):
    """LW rd, offset(rs1)  (I-type, funct3=010, opcode=0x03)"""
    imm12 = offset & 0xFFF
    return (imm12 << 20) | (rs1 << 15) | (2 << 12) | (rd << 7) | 0x03

def sw(rs2, rs1, offset):
    """SW rs2, offset(rs1)  (S-type, funct3=010, opcode=0x23)"""
    imm = offset & 0xFFF
    imm11_5 = (imm >> 5) & 0x7F
    imm4_0  = imm & 0x1F
    return (imm11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (2 << 12) | (imm4_0 << 7) | 0x23

def beq(rs1, rs2, offset):
    """BEQ rs1, rs2, offset  (B-type, funct3=000, opcode=0x63)"""
    imm = offset & 0x1FFF          # 13-bit 2's-complement
    b12    = (imm >> 12) & 1
    b11    = (imm >> 11) & 1
    b10_5  = (imm >>  5) & 0x3F
    b4_1   = (imm >>  1) & 0xF
    return (b12 << 31) | (b10_5 << 25) | (rs2 << 20) | (rs1 << 15) | \
           (0 << 12) | (b4_1 << 8) | (b11 << 7) | 0x63

def bne(rs1, rs2, offset):
    """BNE rs1, rs2, offset  (B-type, funct3=001, opcode=0x63)"""
    imm = offset & 0x1FFF
    b12    = (imm >> 12) & 1
    b11    = (imm >> 11) & 1
    b10_5  = (imm >>  5) & 0x3F
    b4_1   = (imm >>  1) & 0xF
    return (b12 << 31) | (b10_5 << 25) | (rs2 << 20) | (rs1 << 15) | \
           (1 << 12) | (b4_1 << 8) | (b11 << 7) | 0x63

def jal(rd, offset):
    """JAL rd, offset  (J-type, opcode=0x6F)"""
    imm = offset & 0x1FFFFF        # 21-bit 2's-complement
    b20      = (imm >> 20) & 1
    b19_12   = (imm >> 12) & 0xFF
    b11      = (imm >> 11) & 1
    b10_1    = (imm >>  1) & 0x3FF
    return (b20 << 31) | (b10_1 << 21) | (b11 << 20) | (b19_12 << 12) | \
           (rd << 7) | 0x6F

def nop():
    return addi(ZERO, ZERO, 0)     # 0x00000013

def li(rd, imm):
    """Load immediate – returns a LIST of instructions.
       Handles all 32-bit values correctly via LUI+ADDI when needed."""
    if -2048 <= imm <= 2047:
        return [addi(rd, ZERO, imm)]
    else:
        # Split into upper 20 bits and signed lower 12 bits
        lower = imm & 0xFFF
        if lower >= 0x800:         # lower is sign-negative when used as I-imm
            upper = ((imm >> 12) + 1) & 0xFFFFF
            lower_signed = lower - 0x1000     # negative correction
        else:
            upper = (imm >> 12) & 0xFFFFF
            lower_signed = lower
        result = [lui(rd, upper)]
        if lower_signed != 0:
            result.append(addi(rd, rd, lower_signed))
        return result

# ── Convenience: emit single-instruction li (for values that fit in 12 bits) ─

def li1(rd, imm):
    """Emit single ADDI for small immediate (caller must ensure it fits)."""
    assert -2048 <= imm <= 2047, f"li1: {imm} doesn't fit in 12 bits"
    return addi(rd, ZERO, imm)

# ── Program builder ───────────────────────────────────────────────────────────

def build_program():
    """
    Returns a list of 32-bit instruction words.
    Index 0  = PC 0x000 (boot)
    Index 32 = PC 0x080 (main entry)
    """
    prog = []

    # ── Boot vector at PC=0x000 ───────────────────────────────────────────────
    # JAL x0, +0x080  →  jump to main at 0x080
    prog.append(jal(ZERO, 0x080))   # word 0

    # NOPs to pad to word 32 (byte 0x080)
    while len(prog) < 32:
        prog.append(nop())

    # ── Main entry at PC=0x080 ────────────────────────────────────────────────
    # Verify we're at word 32
    assert len(prog) == 32, f"Expected 32 words before main, got {len(prog)}"

    # ── Store Matrix A at byte 0x040 (word 16) ───────────────────────────────
    # A = [[2, 3],
    #      [4, 5]]
    prog.append(li1(T1, 0x040))        # t1 = A base (byte 0x40)
    for val, off in [(2, 0), (3, 4), (4, 8), (5, 12)]:
        prog.append(li1(T0, val))
        prog.append(sw(T0, T1, off))

    # ── Store Matrix B at byte 0x080 (word 32) ───────────────────────────────
    # B = [[1, 2],
    #      [3, 4]]
    prog.append(li1(T1, 0x080))        # t1 = B base (byte 0x80)
    for val, off in [(1, 0), (2, 4), (3, 8), (4, 12)]:
        prog.append(li1(T0, val))
        prog.append(sw(T0, T1, off))

    # ── Software: C_SW = A*B, store at byte 0x0C0 (word 48) ─────────────────
    # C_SW[0][0] = 2*1 + 3*3 = 11
    # C_SW[0][1] = 2*2 + 3*4 = 16
    # C_SW[1][0] = 4*1 + 5*3 = 19
    # C_SW[1][1] = 4*2 + 5*4 = 28
    prog.append(li1(T1, 0x0C0))        # t1 = C_SW base (byte 0xC0)
    for val, off in [(11, 0), (16, 4), (19, 8), (28, 12)]:
        prog.append(li1(T0, val))
        prog.append(sw(T0, T1, off))

    # ── Configure MAC accelerator (byte base 0x0400) ──────────────────────────
    # MAC APB byte 0x400 -> PADDR 0x100 -> cfg_reg[wirte_addr[2:0]] = cfg_reg[0]
    prog.append(li1(T1, 0x400))        # t1 = MAC APB base

    # reg[0] BASE_A = word 16 (0x10) – Matrix A word address in shared RAM
    prog.append(li1(T0, 0x10))
    prog.append(sw(T0, T1, 0))

    # reg[1] BASE_B = word 32 (0x20)
    prog.append(li1(T0, 0x20))
    prog.append(sw(T0, T1, 4))

    # reg[2] BASE_C = word 64 (0x40) – C_HW will be written here by MAC
    prog.append(li1(T0, 0x40))
    prog.append(sw(T0, T1, 8))

    # reg[3] M_K_N  = N[11:8] | K[7:4] | M[3:0] = 2x2x2 = 0x222
    prog.append(li1(T0, 0x222))
    prog.append(sw(T0, T1, 12))

    # reg[4] CTRL   = 1 (start)
    prog.append(li1(T0, 1))
    prog.append(sw(T0, T1, 16))

    # ── Poll CTRL reg until start bit is cleared (done_interrupt) ────────────
    # MAC CTRL byte address = 0x410  (fits in 12 bits: 1040 < 2048 ✓)
    prog.append(li1(T1, 0x410))        # t1 = MAC CTRL address

    # poll: (this PC is stored as poll_idx below)
    poll_idx = len(prog)               # index of first poll instruction
    prog.append(lw(T2, T1, 0))        # t2 = CTRL register
    prog.append(andi_inst(T2, T2, 1)) # t2 = t2 & 1  (start bit)
    # BNE t2, x0, back-to-poll
    bne_poll_idx = len(prog)
    prog.append(bne(T2, ZERO, 0))     # placeholder offset, patched below

    # Patch poll BNE offset
    poll_pc  = 0x080 + poll_idx * 4
    bne_poll_pc = 0x080 + bne_poll_idx * 4
    poll_offset  = poll_pc - bne_poll_pc
    prog[bne_poll_idx] = bne(T2, ZERO, poll_offset)

    # ── Compare C_HW (byte 0x100) vs C_SW (byte 0x0C0) ──────────────────────
    prog.append(li1(T1, 0x100))        # t1 = C_HW base
    prog.append(li1(T5, 0x0C0))        # t5 = C_SW base
    prog.append(li1(T6, 0))            # t6 = fail_flag = 0
    prog.append(li1(T0, 4))            # t0 = loop counter

    # compare_loop:
    cmp_loop_idx = len(prog)
    prog.append(lw(T2, T1, 0))         # t2 = C_HW[i]
    prog.append(lw(T4, T5, 0))         # t4 = C_SW[i]
    # BNE t2, t4, set_fail  (patch later)
    bne_fail_idx = len(prog)
    prog.append(bne(T2, T4, 0))        # placeholder

    prog.append(addi(T1, T1, 4))       # t1 += 4
    prog.append(addi(T5, T5, 4))       # t5 += 4
    prog.append(addi(T0, T0, -1))      # t0--
    # BNE t0, x0, compare_loop  (patch later)
    bne_loop_idx = len(prog)
    prog.append(bne(T0, ZERO, 0))      # placeholder

    # JAL x0, send_result  (patch later)
    jal_result_idx = len(prog)
    prog.append(jal(ZERO, 0))          # placeholder

    # set_fail:
    set_fail_idx = len(prog)
    prog.append(li1(T6, 1))            # fail_flag = 1

    # send_result:
    send_result_idx = len(prog)
    # BEQ t6, x0, send_pass  (patch later)
    beq_pass_idx = len(prog)
    prog.append(beq(T6, ZERO, 0))      # placeholder

    # ── send_fail block ───────────────────────────────────────────────────────
    send_fail_idx = len(prog)
    prog += li(T1, 0x800)              # t1 = UART base  (LUI+ADDI for 0x800)
    fail_chars = [0x54, 0x65, 0x73, 0x74, 0x20,   # "Test "
                  0x46, 0x61, 0x69, 0x6C,           # "Fail"
                  0x0D, 0x0A]                        # CR LF
    for ch in fail_chars:
        prog.append(li1(T0, ch))
        prog.append(sw(T0, T1, 0))

    # JAL x0, infinite_loop  (patch later)
    jal_inf_from_fail_idx = len(prog)
    prog.append(jal(ZERO, 0))          # placeholder

    # ── send_pass block ───────────────────────────────────────────────────────
    send_pass_idx = len(prog)
    prog += li(T1, 0x800)              # t1 = UART base
    pass_chars = [0x54, 0x65, 0x73, 0x74, 0x20,   # "Test "
                  0x50, 0x61, 0x73, 0x73,           # "Pass"
                  0x0D, 0x0A]                        # CR LF
    for ch in pass_chars:
        prog.append(li1(T0, ch))
        prog.append(sw(T0, T1, 0))

    # ── infinite_loop ─────────────────────────────────────────────────────────
    inf_loop_idx = len(prog)
    prog.append(jal(ZERO, 0))          # j .  (patched below to offset=0)

    # ── Patch all forward/backward branch/jump offsets ────────────────────────
    def pc(idx):
        """Byte address of instruction at prog index idx (main starts at 0x80)."""
        return 0x080 + idx * 4

    # compare_loop bne back-edge
    prog[bne_loop_idx] = bne(T0, ZERO, pc(cmp_loop_idx) - pc(bne_loop_idx))

    # bne_fail to set_fail
    prog[bne_fail_idx] = bne(T2, T4, pc(set_fail_idx) - pc(bne_fail_idx))

    # jal to send_result (skip set_fail)
    prog[jal_result_idx] = jal(ZERO, pc(send_result_idx) - pc(jal_result_idx))

    # beq to send_pass
    prog[beq_pass_idx] = beq(T6, ZERO, pc(send_pass_idx) - pc(beq_pass_idx))

    # jal from send_fail to infinite_loop
    prog[jal_inf_from_fail_idx] = jal(ZERO, pc(inf_loop_idx) - pc(jal_inf_from_fail_idx))

    # infinite loop jumps to itself (offset = 0)
    prog[inf_loop_idx] = jal(ZERO, 0)

    return prog


def create_memory_hex(output_path):
    mem  = [0] * 1024
    prog = build_program()

    assert len(prog) <= 1024, f"Program too large: {len(prog)} words"

    for i, word in enumerate(prog):
        mem[i] = word & 0xFFFFFFFF

    with open(output_path, "w") as f:
        for word in mem:
            f.write(f"{word:08x}\n")

    print(f"[generate_hex] Written {len(prog)} words to '{output_path}'")

    # ── Quick sanity check: disassemble the first few and branch targets ──────
    print(f"  word[  0] PC=0x000 : {mem[0]:08x}  (boot JAL)")
    print(f"  word[ 32] PC=0x080 : {mem[32]:08x}  (main entry)")
    print(f"  word[ 33] PC=0x084 : {mem[33]:08x}")
    print(f"  word[ 34] PC=0x088 : {mem[34]:08x}")


if __name__ == "__main__":
    hex_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "memory.hex")
    create_memory_hex(hex_path)
