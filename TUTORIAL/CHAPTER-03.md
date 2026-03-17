# Chapter 3: Memory — Addresses, Bytes, Words, and Endianness

## Introduction

Memory is where our firmware lives and where the RP2350 stores the data it operates on.  This chapter explains how memory is organized, how addresses work, what endianness means, and how the RP2350's address map divides 4 GB of address space among flash, SRAM, and peripherals.

## The Address Space

The RISC-V Hazard3 core in the RP2350 has a 32-bit address bus, giving it a 4 GB address space (0x00000000 to 0xFFFFFFFF).  Every byte in this space has a unique numeric address.  Not all addresses correspond to physical memory — many ranges are unimplemented and will generate a bus fault if accessed.

The RP2350 maps different resources to different address ranges:

| Range | Size | Resource |
|-------|------|----------|
| 0x00000000–0x0FFFFFFF | 256 MB | Internal ROM (boot ROM) |
| 0x10000000–0x11FFFFFF | 32 MB | External flash (XIP) |
| 0x20000000–0x2007FFFF | 512 KB | SRAM |
| 0x40000000–0x4FFFFFFF | 256 MB | APB peripherals |
| 0xD0000000–0xD00FFFFF | 1 MB | SIO (Single-cycle I/O) |
| 0xE0000000–0xE00FFFFF | 1 MB | PPB (Private Peripheral Bus) |

Our firmware executes from flash (0x10000000) and uses SRAM (0x20000000) for the stack.

## Bytes, Halfwords, and Words

| Unit | Size | Aligned Address |
|------|------|----------------|
| Byte | 8 bits | Any address |
| Halfword | 16 bits | Multiple of 2 |
| Word | 32 bits | Multiple of 4 |

All RP2350 peripheral registers are 32 bits wide and must be accessed as words at word-aligned addresses.

## Alignment

Alignment means a data item's address is a multiple of its size.  A word at address 0x40028084 is word-aligned because 0x40028084 is divisible by 4.  Unaligned access on RISC-V may cause a load/store address misaligned exception.

## Little-Endian Byte Order

The RP2350 stores multi-byte values in **little-endian** order: the least significant byte occupies the lowest address.

The 32-bit value 0x12345678 stored at address 0x20000000:

```
Address:   0x20000000  0x20000001  0x20000002  0x20000003
Content:      0x78        0x56        0x34        0x12
              (LSB)                               (MSB)
```

This is important when examining raw memory dumps during debugging.

## Memory-Mapped Registers

The RP2350 does not use separate I/O instructions.  Instead, hardware peripherals appear as memory addresses.  Writing to address 0x40048000 does not store a value in RAM — it configures the crystal oscillator's control register.

```asm
  li    t0, 0x40048000                           # XOSC_CTRL address
  li    t1, 0x00FABAA0                           # frequency range value
  sw    t1, 0(t0)                                # configure XOSC
```

This is called **memory-mapped I/O** and is the mechanism behind every hardware configuration in our firmware.

## The Stack

The stack is a region of SRAM used for saving return addresses and temporary data.  It grows **downward** — from high addresses to low addresses.  On RISC-V, the stack pointer is register `sp` (x2).

Our firmware sets the stack pointer to 0x20082000 (top of a 32 KB stack region):

```asm
  li    sp, STACK_TOP                            # set SP to top of RAM stack
```

When a `call` instruction executes, the return address is saved in `ra` (x1).  Functions that call other functions save `ra` on the stack.

## Flash Memory (XIP)

Our firmware is stored in external flash memory starting at address 0x10000000.  The RP2350 supports **Execute-In-Place (XIP)**, meaning the processor fetches instructions directly from flash through a cache — no need to copy the program to SRAM first.

The first 4 KB of flash must contain the IMAGE_DEF metadata block so the boot ROM can recognize and launch our firmware.

## SRAM

The RP2350 has 520 KB of on-chip SRAM starting at 0x20000000.  We use a 32 KB region at the top of the first 512 KB for our stack.  For this blink driver, SRAM is used only for the stack — all code executes from flash.

## Reading the Address Map

When you see an address in our firmware, you can immediately identify what it accesses:

| Address | What It Is |
|---------|------------|
| 0x10000000 | Start of flash — IMAGE_DEF block goes here |
| 0x20082000 | Stack top (top of SRAM + 8 KB offset) |
| 0x40010048 | CLK_PERI_CTRL — peripheral clock control |
| 0x40020000 | RESETS_RESET — reset controller |
| 0x40028000 | IO_BANK0 — GPIO function select |
| 0x40038000 | PADS_BANK0 — GPIO pad control |
| 0x40048000 | XOSC — crystal oscillator |
| 0xD0000000 | SIO — single-cycle I/O for GPIO |

Every address in our constants.s file maps to a specific hardware function.

## Summary

- The RP2350 has a 32-bit address space (4 GB) divided among flash, SRAM, and peripherals.
- All peripheral registers are memory-mapped — accessed with normal load/store instructions.
- Data is stored in little-endian byte order.
- The stack lives in SRAM and grows downward from STACK_TOP (0x20082000).
- Flash supports execute-in-place; our code runs directly from 0x10000000.
- Each address range identifies the hardware resource being accessed.
