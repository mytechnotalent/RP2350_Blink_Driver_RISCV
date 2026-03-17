# Chapter 7: RISC-V Hazard3 ISA Overview

## Introduction

The instruction set architecture (ISA) defines every operation the processor can perform.  The Hazard3 core in the RP2350 implements the **RV32IMAC_Zicsr** architecture — a 32-bit RISC-V base integer ISA augmented with integer multiply/divide, atomic operations, compressed instructions, and control/status register access.  This chapter surveys the ISA at a high level and identifies every instruction our blink driver uses.

## The RISC-V Design Philosophy

RISC-V follows an exceptionally clean RISC (Reduced Instruction Set Computer) philosophy:

- **Fixed-width instructions** — base instructions are always 32 bits (4 bytes)
- **Load-store architecture** — only `lw`/`sw` family instructions access memory
- **Large register file** — 32 general-purpose integer registers (x0–x31)
- **Simple addressing modes** — base register + 12-bit signed immediate
- **No condition flags** — branches compare registers directly
- **Modular extensions** — functionality added via lettered extensions (M, A, C, Zicsr)

## The RV32IMAC_Zicsr Extensions

The Hazard3 core supports these extensions:

| Extension | Name | Purpose |
|-----------|------|---------|
| I | Base Integer | Core instruction set: arithmetic, logic, loads, stores, branches |
| M | Multiply/Divide | `mul`, `div`, `rem` and their variants |
| A | Atomic | Atomic memory operations (not used in our firmware) |
| C | Compressed | 16-bit encodings for common instructions |
| Zicsr | CSR Access | `csrr`, `csrw`, `csrrw` for control/status registers |

## Instruction Encoding Formats

RV32I defines six base instruction formats.  Every 32-bit instruction uses one of these:

| Format | Fields | Used For |
|--------|--------|----------|
| R-type | funct7, rs2, rs1, funct3, rd, opcode | Register-register operations: `add`, `sub`, `and`, `or`, `sll`, `mul` |
| I-type | imm[11:0], rs1, funct3, rd, opcode | Immediates and loads: `addi`, `ori`, `andi`, `lw`, `jalr` |
| S-type | imm[11:5], rs2, rs1, funct3, imm[4:0], opcode | Stores: `sw` |
| B-type | imm[12\|10:5], rs2, rs1, funct3, imm[4:1\|11], opcode | Branches: `beq`, `bne`, `bge`, `blt` |
| U-type | imm[31:12], rd, opcode | Upper immediates: `lui`, `auipc` |
| J-type | imm[20\|10:1\|11\|19:12], rd, opcode | Jumps: `jal` |

```
R-type:  [funct7 ][rs2  ][rs1  ][f3 ][rd   ][opcode ]
         31    25 24  20 19  15 14 12 11   7 6      0

I-type:  [imm[11:0]      ][rs1  ][f3 ][rd   ][opcode ]
         31            20 19  15 14 12 11   7 6      0

S-type:  [imm[11:5]  ][rs2  ][rs1  ][f3 ][imm[4:0] ][opcode ]
         31        25 24  20 19  15 14 12 11       7 6      0
```

## The C Extension (Compressed Instructions)

The C extension provides 16-bit (2-byte) encodings for the most common operations.  The assembler chooses compressed encodings automatically when possible:

| 32-bit Instruction | 16-bit Equivalent | Condition |
|--------------------|--------------------|-----------|
| `addi rd, rd, imm` | `c.addi rd, imm` | imm fits in 6 bits |
| `lw rd, off(rs1)` | `c.lw rd, off(rs1)` | Registers in x8–x15, offset aligned |
| `sw rs2, off(rs1)` | `c.sw rs2, off(rs1)` | Registers in x8–x15, offset aligned |
| `jal x1, offset` | `c.jal offset` | Offset fits in 12 bits (RV32 only) |
| `jalr x0, 0(x1)` | `c.jr x1` | Always |
| `add rd, x0, rs2` | `c.mv rd, rs2` | Always |
| `addi x2, x2, imm` | `c.addi16sp imm` | Stack pointer adjustment |

Compressed instructions improve code density — the same logic fits in less flash.  The programmer writes standard instructions; the assembler compresses them transparently.

## Instructions Used in Our Firmware

Here is the complete list of instructions appearing in our blink driver:

| Instruction | Format | Description |
|-------------|--------|-------------|
| `li rd, imm` | Pseudo | Load immediate (expands to `lui`+`addi` or just `addi`) |
| `la rd, symbol` | Pseudo | Load address (expands to `auipc`+`addi`) |
| `lw rd, off(rs1)` | I-type | Load word from memory |
| `sw rs2, off(rs1)` | S-type | Store word to memory |
| `add rd, rs1, rs2` | R-type | Add two registers |
| `addi rd, rs1, imm` | I-type | Add register and immediate |
| `mul rd, rs1, rs2` | R-type (M) | Multiply two registers |
| `and rd, rs1, rs2` | R-type | Bitwise AND |
| `andi rd, rs1, imm` | I-type | Bitwise AND with immediate |
| `or rd, rs1, rs2` | R-type | Bitwise OR |
| `ori rd, rs1, imm` | I-type | Bitwise OR with immediate |
| `not rd, rs1` | Pseudo | Bitwise NOT (expands to `xori rd, rs1, -1`) |
| `sll rd, rs1, rs2` | R-type | Shift left logical |
| `beqz rs1, label` | Pseudo | Branch if equal to zero (expands to `beq rs1, x0, label`) |
| `bnez rs1, label` | Pseudo | Branch if not zero (expands to `bne rs1, x0, label`) |
| `bgez rs1, label` | Pseudo | Branch if >= zero (expands to `bge rs1, x0, label`) |
| `blez rs1, label` | Pseudo | Branch if <= zero (expands to `ble rs1, x0, label`) |
| `j label` | Pseudo | Unconditional jump (expands to `jal x0, label`) |
| `jal rd, label` | J-type | Jump and link |
| `jalr rd, off(rs1)` | I-type | Jump and link register |
| `call label` | Pseudo | Call function (expands to `auipc ra, …` + `jalr ra, …`) |
| `ret` | Pseudo | Return (expands to `jalr x0, 0(x1)`) |
| `csrw csr, rs1` | Pseudo | Write CSR (expands to `csrrw x0, csr, rs1`) |

## Summary

- The Hazard3 core implements RV32IMAC_Zicsr: base integer, multiply, atomics, compressed, and CSR access.
- All base instructions are 32 bits, with six encoding formats (R, I, S, B, U, J).
- The C extension provides automatic 16-bit compression for common instructions.
- Our blink driver uses approximately 22 distinct instructions (including pseudo-instructions) to achieve full GPIO control from bare metal.
