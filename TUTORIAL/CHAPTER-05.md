# Chapter 5: Load-Store Architecture — How RISC-V Accesses Memory

## Introduction

RISC-V is a **load-store architecture**: the only instructions that access memory are loads and stores.  All arithmetic and logic operates exclusively on registers.  This chapter explains the load-store model, shows the key load and store instructions used in our firmware, and demonstrates the fundamental read-modify-write pattern for hardware programming.

## Why Load-Store?

In a load-store architecture, computation never operates directly on memory.  To add 1 to a value in memory, you must:

1. **Load** the value from memory into a register.
2. **Add** 1 to the register.
3. **Store** the result back to memory.

This constraint simplifies the processor hardware and enables fast, pipelined execution.  Every RISC-V instruction either operates on registers or transfers data between registers and memory — never both in the same instruction.

## The Load Instruction: lw

The `lw` (load word) instruction reads a 32-bit value from a memory address into a register:

```asm
  lw    t1, 0(t0)                                # read 32-bit value at address in t0
```

This reads 4 bytes from the address in `t0` and places them in `t1`.  Our firmware uses this pattern to read every peripheral register:

```asm
  li    t0, RESETS_RESET                         # load RESETS->RESET address
  lw    t1, 0(t0)                                # read current RESETS->RESET value
```

## The Store Instruction: sw

The `sw` (store word) instruction writes a 32-bit value from a register to a memory address:

```asm
  sw    t1, 0(t0)                                # write t1 to address in t0
```

This writes the 4 bytes in `t1` to the address in `t0`.  In peripheral programming, this is how we configure hardware:

```asm
  sw    t1, 0(t0)                                # store value into XOSC_CTRL
```

## The Load-Modify-Store Pattern

Most hardware configuration follows a three-step pattern:

1. Load the current register value.
2. Modify specific bits (set, clear, or toggle).
3. Store the modified value back.

```asm
  li    t0, CLK_PERI_CTRL                        # load CLK_PERI_CTRL address
  lw    t1, 0(t0)                                # read CLK_PERI_CTRL value
  li    t2, (1<<11)                              # ENABLE bit mask
  or    t1, t1, t2                               # set ENABLE bit
  sw    t1, 0(t0)                                # store value into CLK_PERI_CTRL
```

This pattern guarantees we only change the bits we intend to, preserving all other bits in the register.

## Byte and Halfword Access

RISC-V also supports narrower loads and stores:

| Instruction | Width | Description |
|-------------|-------|-------------|
| `lb` / `sb` | 8 bits | Load/store byte |
| `lh` / `sh` | 16 bits | Load/store halfword |
| `lw` / `sw` | 32 bits | Load/store word |
| `lbu` | 8 bits | Load byte unsigned |
| `lhu` | 16 bits | Load halfword unsigned |

Our firmware uses only `lw`/`sw` because all RP2350 peripheral registers are 32 bits wide.  The `lb`/`lbu` variants exist for byte-oriented data processing.

## Stack Operations

RISC-V uses explicit `sw`/`lw` instructions with the stack pointer for push/pop operations:

```asm
  addi  sp, sp, -4                               # allocate stack frame
  sw    ra, 0(sp)                                # save return address
  ...
  lw    ra, 0(sp)                                # restore return address
  addi  sp, sp, 4                                # deallocate stack frame
```

This is functionally equivalent to ARM's `push`/`pop` but makes the stack pointer adjustment explicit.

## Memory Access in Our Firmware

Every hardware interaction in our firmware follows the load-store model:

| Operation | Pattern |
|-----------|---------|
| Read peripheral | `li t0, ADDR` then `lw t1, 0(t0)` |
| Write peripheral | `li t0, ADDR` then `sw t1, 0(t0)` |
| Set bits | Load, `or`, store |
| Clear bits | Load, `and` with inverted mask, store |
| Test a bit | Load, `andi`, branch |
| Push to stack | `addi sp, sp, -N` then `sw ra, 0(sp)` |
| Pop from stack | `lw ra, 0(sp)` then `addi sp, sp, N` |

## Summary

- RISC-V is a load-store architecture — only `lw`/`sw` (and variants) access memory.
- All computations happen in registers.
- The load-modify-store pattern is the foundation of all hardware configuration.
- Stack operations use explicit `sw`/`lw` with `sp` adjustments.
- Our firmware uses word-width access (`lw`/`sw`) for all peripheral registers.
