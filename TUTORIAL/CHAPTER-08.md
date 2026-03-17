# Chapter 8: RISC-V Immediate and Upper-Immediate Instructions

## Introduction

Before a processor can operate on data it must get that data into a register.  On a RISC-V machine, transferring constants into registers is one of the most common operations.  This chapter examines how the Hazard3 core loads immediate values, the constraints the encoding imposes, and the role of the assembler's `li` and `la` pseudo-instructions that our blink firmware relies on heavily.

## The Immediate Encoding Problem

A RISC-V instruction is 32 bits wide.  Part of those bits encode the opcode, registers, and function fields — leaving limited room for an immediate constant.  The I-type format provides only 12 bits for an immediate (range: -2048 to 2047).  Peripheral addresses like `0x40048000` are 32-bit values that cannot fit in 12 bits.

RISC-V solves this with a two-instruction sequence: `lui` loads the upper 20 bits, then `addi` fills in the lower 12 bits.

## `lui` — Load Upper Immediate

`lui` (Load Upper Immediate) places a 20-bit immediate into the upper 20 bits of the destination register, zeroing the lower 12:

```
lui   rd, imm20

rd = imm20 << 12
```

Example:

```
lui   t0, 0x40048       =>  t0 = 0x40048000
```

The result has the lower 12 bits as zero.  If the full target value has non-zero lower bits, an `addi` follows.

## `addi` — Add Immediate

`addi` adds a signed 12-bit immediate to a source register:

```
addi  rd, rs1, imm12

rd = rs1 + sign_extend(imm12)
```

When paired with `lui`:

```
lui   t0, 0x40048       =>  t0 = 0x40048000
addi  t0, t0, 0x00c     =>  t0 = 0x4004800c   (XOSC_STARTUP)
```

## The `li` Pseudo-Instruction

The assembler provides `li` (Load Immediate) to abstract the `lui`+`addi` sequence.  The programmer writes:

```asm
  li    t0, XOSC_STARTUP                         # load XOSC_STARTUP address
```

And the assembler expands it based on the value:

| Value Range | Expansion |
|-------------|-----------|
| -2048 to 2047 | `addi rd, x0, imm` (single instruction) |
| Fits in upper 20 bits (lower 12 = 0) | `lui rd, imm20` (single instruction) |
| Arbitrary 32-bit value | `lui rd, upper20` + `addi rd, rd, lower12` (two instructions) |

### Sign Extension Complication

Because `addi` sign-extends its 12-bit immediate, the assembler must adjust the upper immediate when bit 11 of the lower portion is set.  For example:

```
Target: 0x40048800
Lower 12 bits: 0x800 = -2048 (sign-extended)
Adjusted upper: 0x40049 (0x40048 + 1)
```

```
lui   t0, 0x40049       =>  t0 = 0x40049000
addi  t0, t0, -2048     =>  t0 = 0x40048800
```

The `li` pseudo-instruction handles this automatically.

## `auipc` — Add Upper Immediate to PC

`auipc` (Add Upper Immediate to PC) loads the PC plus a 20-bit upper immediate:

```
auipc  rd, imm20

rd = PC + (imm20 << 12)
```

This is used for PC-relative addressing.  The `la` and `call` pseudo-instructions use `auipc` internally.

## The `la` Pseudo-Instruction

`la` (Load Address) loads the address of a symbol:

```asm
  la    t0, Default_Trap_Handler                 # trap target
```

The assembler expands this to:

```
auipc  t0, %pcrel_hi(Default_Trap_Handler)
addi   t0, t0, %pcrel_lo(Default_Trap_Handler)
```

This creates a position-independent address computation relative to the current PC.  Our firmware uses `la` in Init_Trap_Vector to load the trap handler address into `mtvec`.

## Our Firmware's Use of Immediates

In our blink driver, constants flow into registers in several ways:

### 1. `li` for Peripheral Addresses

Used in every source file to load base addresses and register offsets:

```asm
  li    t0, XOSC_BASE                            # t0 = 0x40048000
  li    t0, RESETS_RESET                         # t0 = 0x40020000
  li    t0, SIO_GPIO_OUT_SET                     # t0 = 0xd0000018
```

### 2. `li` for Small Constants

When the value fits in 12 bits, `li` expands to a single `addi`:

```asm
  li    t1, 0x00c4                               # t1 = 196 (fits in 12 bits)
  li    a0, 500                                  # a0 = 500 (delay ms)
  li    a2, 16                                   # a2 = 16 (GPIO number)
  li    t0, 3600                                 # t0 = 3600 (loops per ms)
  li    t1, 1                                    # t1 = 1 (bit value)
```

### 3. `li` for Large Constants

For values that need `lui`+`addi`:

```asm
  li    t1, 0x00FABAA0                           # XOSC_CTRL value
```

This expands to:

```
lui   t1, 0x00FAB       =>  t1 = 0x00FAB000
addi  t1, t1, -1376     =>  t1 = 0x00FABAA0  (since 0xAA0 sign-extends)
```

### 4. `li` for Bit Masks

Used to create masks for bit manipulation:

```asm
  li    t2, ~(1<<7)                              # mask to clear OD bit
  li    t2, (1<<11)                              # ENABLE bit mask
```

## Contrast with ARM

On ARM Cortex-M33, the equivalent operation uses `ldr Rd, =value`, which places the constant in a literal pool (data area) and generates a PC-relative load.  RISC-V avoids literal pools entirely — the constant is encoded directly in the instruction stream via `lui`+`addi`.

| Feature | ARM | RISC-V |
|---------|-----|--------|
| Load 32-bit constant | `ldr Rd, =value` (literal pool) | `li rd, value` (`lui`+`addi`) |
| Data storage | Constant in memory | Constant in instruction encoding |
| Memory access | One load from flash | Zero loads (immediate in instructions) |
| Code locality | Literal pool may be far away | Instructions are sequential |

## Summary

- `lui` loads a 20-bit upper immediate, zeroing the lower 12 bits.
- `addi` fills in the lower 12 bits, with sign extension handled by the assembler.
- `li` is the primary pseudo-instruction for loading any 32-bit constant — it expands to one or two real instructions.
- `auipc` computes PC-relative addresses; `la` wraps it for loading symbol addresses.
- Our firmware relies on `li` extensively for peripheral base addresses, control values, and bit masks.
