# Chapter 19: The Linker Script — Placing Code in Memory

## Introduction

The linker script is the blueprint that transforms a collection of object files into a single binary that the RP2350 can execute.  It defines where code lives in flash, where the stack resides in RAM, and what order sections appear in.  Without a correct linker script, the boot ROM cannot find the PICOBIN block, the vector table might be misaligned, and the processor would never reach our code.  This chapter walks through every line of our linker.ld.

## Entry Point

```ld
ENTRY(Reset_Handler)
```

This tells the linker and any toolchain utilities (debuggers, flash tools) that `Reset_Handler` is the program's entry point.  On RISC-V, the boot ROM reads the PICOBIN block to find the entry point, but `ENTRY` provides metadata for the toolchain.

## Memory Constants

```ld
__XIP_BASE   = 0x10000000;
__XIP_SIZE   = 32M;

__SRAM_BASE  = 0x20000000;
__SRAM_SIZE  = 512K;
__STACK_SIZE = 32K;
```

These define the physical memory layout of the RP2350:

| Symbol | Value | Description |
|--------|-------|-------------|
| `__XIP_BASE` | `0x10000000` | Flash start (XIP = Execute In Place) |
| `__XIP_SIZE` | 32 MB | Flash capacity |
| `__SRAM_BASE` | `0x20000000` | SRAM start |
| `__SRAM_SIZE` | 512 KB | SRAM capacity |
| `__STACK_SIZE` | 32 KB | Stack reservation |

## Memory Regions

```ld
MEMORY
{
  RAM   (rwx) : ORIGIN = __SRAM_BASE, LENGTH = __SRAM_SIZE
  FLASH (rx)  : ORIGIN = __XIP_BASE,  LENGTH = __XIP_SIZE
}
```

The `MEMORY` block defines two regions:

- **FLASH**: read and execute only — holds all code and constants
- **RAM**: read, write, and execute — holds stack and data

The linker uses these to validate that sections fit within their assigned regions and to compute absolute addresses.

## Program Headers

```ld
PHDRS
{
  text PT_LOAD FLAGS(5);                         /* RX */
}
```

Program headers describe loadable segments for tools that program the flash.  `FLAGS(5)` means Read (4) + Execute (1).  Our firmware has a single loadable segment containing all flash content.

## Section Placement

### `.embedded_block` — PICOBIN Metadata

```ld
  . = ORIGIN(FLASH);

  .embedded_block :
  {
    KEEP(*(.embedded_block))
    KEEP(*(.picobin_block))
  } > FLASH :text
```

The location counter (`.`) starts at flash origin (`0x10000000`).  The `.embedded_block` section is placed first.  `KEEP` prevents the linker from discarding this section during garbage collection, even though no code references it directly — the boot ROM reads it by position.

This section contains the PICOBIN block from image_def.s, which the boot ROM uses to:
1. Identify the image as valid firmware
2. Determine the architecture (RISC-V, from `0x1101`)
3. Find the entry point (`Reset_Handler`)
4. Read the initial stack pointer value

### `.vectors` — Vector Table

```ld
  .vectors ALIGN(128) :
  {
    KEEP(*(.vectors))
  } > FLASH :text

  ASSERT(((ADDR(.vectors) - ORIGIN(FLASH)) < 0x1000),
         "Vector table must be in first 4KB of flash")
```

`ALIGN(128)` ensures the vector table starts on a 128-byte boundary.  On RISC-V, `mtvec` requires the trap vector to be aligned to at least 4 bytes (direct mode) or a power-of-two boundary (vectored mode).  The 128-byte alignment provides compatibility with both modes.

The `ASSERT` verifies the vector table is within the first 4 KB of flash — a boot ROM requirement.

### `.text` — Code and Read-Only Data

```ld
  .text :
  {
    . = ALIGN(4);
    *(.text*)
    *(.rodata*)
  } > FLASH :text
```

All executable code and read-only data are merged into the `.text` output section in flash.  The wildcard `*(.text*)` matches `.text`, `.text.main`, `.text.GPIO_Config`, etc.

`. = ALIGN(4)` ensures the section starts on a 4-byte boundary for proper instruction alignment.

### Stack Symbols

```ld
  __StackTop   = ORIGIN(RAM) + LENGTH(RAM);
  __StackLimit = __StackTop - __STACK_SIZE;
  __stack      = __StackTop;
```

These linker symbols define the stack boundaries:

| Symbol | Value | Description |
|--------|-------|-------------|
| `__StackTop` | `0x20080000` | Top of SRAM = top of stack |
| `__StackLimit` | `0x20078000` | 32 KB below top |
| `__stack` | `0x20080000` | Alias for stack top |

Note: Our firmware uses `.equ` constants in constants.s (`STACK_TOP = 0x20082000`, `STACK_LIMIT = 0x2007a000`) rather than these linker symbols.  Both approaches are valid.

### `.stack` Section

```ld
  .stack (NOLOAD) : { . = ALIGN(8); } > RAM

  PROVIDE(__Vectors = ADDR(.vectors));
```

`NOLOAD` means this section occupies address space in RAM but has no content in the flash image.  The stack is runtime-only — it does not need initialization from flash.

`PROVIDE(__Vectors = ADDR(.vectors))` exports the vector table address for any code that might need it.

## The Resulting Memory Layout

```
Flash (0x10000000):
+-----------------------------+ 0x10000000
| .embedded_block (PICOBIN)   |  ~24 bytes
+-----------------------------+
| (padding to 128-byte align) |
+-----------------------------+ 0x10000080
| .vectors (handler addresses)|  8 bytes (2 words)
+-----------------------------+ 0x10000088
| .text (all code + rodata)   |
|                             |  ~1 KB
+-----------------------------+

RAM (0x20000000):
+-----------------------------+ 0x20000000
| (available RAM)             |
+-----------------------------+
| .stack (32 KB)              |
+-----------------------------+ 0x20080000
```

## Why Each Section Matters

| Section | What Happens If Missing |
|---------|------------------------|
| `.embedded_block` | Boot ROM cannot find PICOBIN — image rejected |
| `.vectors` | No trap handler addresses — faults cause lockup |
| `.text` | No executable code — nothing to run |
| `.stack` | No stack space — first function call corrupts memory |

## Summary

- `ENTRY(Reset_Handler)` identifies the program entry point for toolchain utilities.
- `MEMORY` defines flash at `0x10000000` (32 MB) and RAM at `0x20000000` (512 KB).
- `.embedded_block` must be first in flash for the boot ROM to find the PICOBIN block.
- `.vectors` is aligned to 128 bytes and must be within the first 4 KB of flash.
- `.text` contains all executable code and read-only data.
- Stack symbols define a 32 KB stack at the top of SRAM with `NOLOAD` (no flash content).
- The linker script is the bridge between the assembler's relative addresses and the processor's absolute memory map.
