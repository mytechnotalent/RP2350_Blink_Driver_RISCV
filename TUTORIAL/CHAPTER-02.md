# Chapter 2: Number Systems — Binary, Hexadecimal, and Decimal

## Introduction

Every value in our firmware — addresses, register contents, bit masks, constants — is stored as a pattern of ones and zeros.  This chapter teaches the three number systems you will encounter on every page of this tutorial: decimal, binary, and hexadecimal.  You will learn to convert between them, understand bit numbering, and recognize the specific constants used in our blink driver.

## Decimal — Base 10

Decimal is the number system humans use every day.  It has ten digits: 0 through 9.  Each position represents a power of 10:

```
  4   2   3
  |   |   |
  |   |   +-- 3 × 10^0 = 3
  |   +------ 2 × 10^1 = 20
  +---------- 4 × 10^2 = 400
                         ----
                          423
```

Decimal appears in our firmware for delay values, GPIO pin numbers, and loop counts.

## Binary — Base 2

Binary has two digits: 0 and 1.  Each digit is called a **bit**.  Each position represents a power of 2:

```
  1   1   0   1
  |   |   |   |
  |   |   |   +-- 1 × 2^0 = 1
  |   |   +------ 0 × 2^1 = 0
  |   +---------- 1 × 2^2 = 4
  +-------------- 1 × 2^3 = 8
                             --
                             13 (decimal)
```

The processor operates entirely in binary.  Every register is 32 bits wide — 32 individual ones and zeros.

In GNU assembly, binary literals use the `0b` prefix:

```asm
  .hword 0x1101                                  # EXE + RISCV + RP2350
```

## Hexadecimal — Base 16

Hexadecimal (hex) has sixteen digits: 0–9 and A–F (where A=10, B=11, C=12, D=13, E=14, F=15).  Each hex digit represents exactly four bits:

| Hex | Binary | Decimal |
|-----|--------|---------|
| 0 | 0000 | 0 |
| 1 | 0001 | 1 |
| 2 | 0010 | 2 |
| 3 | 0011 | 3 |
| 4 | 0100 | 4 |
| 5 | 0101 | 5 |
| 6 | 0110 | 6 |
| 7 | 0111 | 7 |
| 8 | 1000 | 8 |
| 9 | 1001 | 9 |
| A | 1010 | 10 |
| B | 1011 | 11 |
| C | 1100 | 12 |
| D | 1101 | 13 |
| E | 1110 | 14 |
| F | 1111 | 15 |

This makes hex the preferred notation for memory addresses and register values because each hex digit maps directly to four bits.

## The 0x Prefix

In assembly and C, hexadecimal numbers are written with a `0x` prefix:

```
0x40028000 = 0100 0000 0000 0010 1000 0000 0000 0000 (binary)
```

Every memory-mapped address in our firmware is written in hex:

```asm
  .equ XOSC_BASE,  0x40048000                    # crystal oscillator base
  .equ RESETS_BASE, 0x40020000                   # reset controller base
```

## Bit Numbering

Bits in a 32-bit register are numbered 0 (least significant, rightmost) to 31 (most significant, leftmost):

```
Bit:  31 30 29 28 ... 3  2  1  0
       |  |  |  |      |  |  |  |
MSB ---+  |  |  |      |  |  |  +--- LSB
          |  |  |      |  |  |
          v  v  v      v  v  v
```

When we write `(1<<6)`, we mean a 32-bit value with only bit 6 set:

```
0000 0000 0000 0000 0000 0000 0100 0000 = 0x00000040
```

This notation appears throughout our firmware for setting and clearing individual hardware control bits.

## Common Bit Patterns in Our Firmware

| Pattern | Hex | Binary (relevant bits) | Used For |
|---------|-----|----------------------|----------|
| `1<<6` | 0x00000040 | bit 6 set | IO_BANK0 reset bit |
| `1<<7` | 0x00000080 | bit 7 set | OD (output disable) pad bit |
| `1<<8` | 0x00000100 | bit 8 set | ISO (isolation) pad bit |
| `1<<11` | 0x00000800 | bit 11 set | CLK_PERI enable bit |
| `1<<31` | 0x80000000 | bit 31 set | XOSC STABLE status bit |
| `0x1f` | 0x0000001F | bits 4:0 set | FUNCSEL mask (5 bits) |
| `0x05` | 0x00000005 | bits 2,0 set | FUNCSEL = SIO (GPIO function) |

## Two's Complement — Signed Numbers

RISC-V uses **two's complement** for signed integers.  In a 32-bit register:

- Bit 31 is the sign bit: 0 = positive, 1 = negative.
- To negate a number: invert all bits and add 1.

| Decimal | Binary (8-bit example) |
|---------|----------------------|
| +5 | 0000 0101 |
| -5 | 1111 1011 |
| +127 | 0111 1111 |
| -128 | 1000 0000 |

The `bgez` instruction in our XOSC polling loop depends on two's complement: when bit 31 (the STABLE bit) is set, the signed interpretation is negative, so `bgez` (branch if greater than or equal to zero) does not branch — meaning "stable."

## Data Sizes on RISC-V RV32

| Name | Size | RISC-V Load/Store |
|------|------|-------------------|
| Byte | 8 bits | `lb` / `sb` |
| Halfword | 16 bits | `lh` / `sh` |
| Word | 32 bits | `lw` / `sw` |

Our firmware uses word (32-bit) access for all peripheral registers because the RP2350's memory-mapped registers are 32 bits wide.

## Summary

- Decimal, binary, and hexadecimal are the three number systems used in firmware programming.
- Every hex digit maps to exactly four bits.
- Bit numbering starts at 0 (LSB) and increases leftward to 31 (MSB).
- The shift expression `(1<<n)` creates a mask with only bit *n* set.
- Two's complement represents signed numbers; bit 31 is the sign bit.
- RISC-V uses word (32-bit), halfword (16-bit), and byte (8-bit) data sizes.
