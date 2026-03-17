# Chapter 22: The Constants File — `constants.s`

## Introduction

Every memory-mapped register address and magic number in the blink driver is defined in one place: `constants.s`.  Every other source file includes this file with `.include "constants.s"`, gaining access to all named constants.  This chapter walks through every `.equ` directive, explains what each constant represents, and shows how the constants map to hardware registers on the RP2350.

## Full Source

```asm
.equ STACK_TOP,                   0x20082000               
.equ STACK_LIMIT,                 0x2007a000             
.equ VECTOR_TABLE_BASE,           0x20000000
.equ XOSC_BASE,                   0x40048000          
.equ XOSC_CTRL,                   XOSC_BASE + 0x00       
.equ XOSC_STATUS,                 XOSC_BASE + 0x04       
.equ XOSC_STARTUP,                XOSC_BASE + 0x0c        
.equ PPB_BASE,                    0xe0000000
.equ MSTATUS_MIE,                 (1<<3)
.equ MTVEC_MODE_DIRECT,           0
.equ CLOCKS_BASE,                 0x40010000              
.equ CLK_PERI_CTRL,               CLOCKS_BASE + 0x48       
.equ RESETS_BASE,                 0x40020000               
.equ RESETS_RESET,                RESETS_BASE + 0x0        
.equ RESETS_RESET_CLEAR,          RESETS_BASE + 0x3000     
.equ RESETS_RESET_DONE,           RESETS_BASE + 0x8        
.equ IO_BANK0_BASE,               0x40028000               
.equ IO_BANK0_GPIO16_CTRL_OFFSET, 0x84                   
.equ PADS_BANK0_BASE,             0x40038000               
.equ PADS_BANK0_GPIO16_OFFSET,    0x44                    
.equ SIO_BASE,                    0xd0000000
.equ SIO_GPIO_OUT_SET,            SIO_BASE + 0x018
.equ SIO_GPIO_OUT_CLR,            SIO_BASE + 0x020
.equ SIO_GPIO_OE_SET,             SIO_BASE + 0x038
```

## How `.equ` Works

```asm
.equ XOSC_BASE, 0x40048000
```

`.equ` assigns a constant value to a name.  The assembler replaces every occurrence of `XOSC_BASE` with `0x40048000` during assembly.  No memory is allocated — `.equ` values are resolved entirely at assembly time.  This is equivalent to `#define` in C.

Expressions are also supported:

```asm
.equ XOSC_CTRL, XOSC_BASE + 0x00
```

The assembler evaluates `0x40048000 + 0x00 = 0x40048000` and substitutes that value wherever `XOSC_CTRL` appears.

## Stack Constants

```asm
.equ STACK_TOP,                   0x20082000               
.equ STACK_LIMIT,                 0x2007a000             
.equ VECTOR_TABLE_BASE,           0x20000000
```

| Constant | Value | Purpose |
|----------|-------|---------|
| `STACK_TOP` | `0x20082000` | Initial stack pointer (top of 520 KB SRAM) |
| `STACK_LIMIT` | `0x2007a000` | Stack overflow boundary (32 KB below top) |
| `VECTOR_TABLE_BASE` | `0x20000000` | Base of SRAM (not used at runtime for RISC-V) |

The stack grows downward from `STACK_TOP`.  The 32 KB between `STACK_TOP` and `STACK_LIMIT` provides ample space for our call chain, which never exceeds a few frames deep.

## XOSC Constants

```asm
.equ XOSC_BASE,                   0x40048000          
.equ XOSC_CTRL,                   XOSC_BASE + 0x00       
.equ XOSC_STATUS,                 XOSC_BASE + 0x04       
.equ XOSC_STARTUP,                XOSC_BASE + 0x0c        
```

| Constant | Value | Purpose |
|----------|-------|---------|
| `XOSC_BASE` | `0x40048000` | Crystal oscillator peripheral base |
| `XOSC_CTRL` | `0x40048000` | Control register (frequency range + enable) |
| `XOSC_STATUS` | `0x40048004` | Status register (bit 31 = stable) |
| `XOSC_STARTUP` | `0x4004800c` | Startup delay counter |

These registers live in the APB peripheral bus address space.  The XOSC hardware provides a stable 12 MHz clock from an external crystal.

## RISC-V Specific Constants

```asm
.equ PPB_BASE,                    0xe0000000
.equ MSTATUS_MIE,                 (1<<3)
.equ MTVEC_MODE_DIRECT,           0
```

| Constant | Value | Purpose |
|----------|-------|---------|
| `PPB_BASE` | `0xe0000000` | Private peripheral bus base (reserved) |
| `MSTATUS_MIE` | `0x08` | Machine interrupt enable bit in mstatus CSR |
| `MTVEC_MODE_DIRECT` | `0` | Direct mode for trap vector |

These constants relate to RISC-V privilege architecture.  `MSTATUS_MIE` and `MTVEC_MODE_DIRECT` are defined for completeness — our trap handler uses `csrw mtvec` to install the trap vector directly.

## Clock Constants

```asm
.equ CLOCKS_BASE,                 0x40010000              
.equ CLK_PERI_CTRL,               CLOCKS_BASE + 0x48       
```

| Constant | Value | Purpose |
|----------|-------|---------|
| `CLOCKS_BASE` | `0x40010000` | Clocks controller base |
| `CLK_PERI_CTRL` | `0x40010048` | Peripheral clock control register |

The peripheral clock control register selects which clock source drives peripherals.  We set it to use XOSC as the source.

## Reset Constants

```asm
.equ RESETS_BASE,                 0x40020000               
.equ RESETS_RESET,                RESETS_BASE + 0x0        
.equ RESETS_RESET_CLEAR,          RESETS_BASE + 0x3000     
.equ RESETS_RESET_DONE,           RESETS_BASE + 0x8        
```

| Constant | Value | Purpose |
|----------|-------|---------|
| `RESETS_BASE` | `0x40020000` | Reset controller base |
| `RESETS_RESET` | `0x40020000` | Reset register (1 = held in reset) |
| `RESETS_RESET_CLEAR` | `0x40023000` | Atomic clear alias for reset register |
| `RESETS_RESET_DONE` | `0x40020008` | Reset done status (1 = released) |

Each peripheral has a bit in the reset register.  To use a peripheral, we must clear its reset bit and wait for `RESET_DONE` to confirm the release.

## GPIO Constants

```asm
.equ IO_BANK0_BASE,               0x40028000               
.equ IO_BANK0_GPIO16_CTRL_OFFSET, 0x84                   
.equ PADS_BANK0_BASE,             0x40038000               
.equ PADS_BANK0_GPIO16_OFFSET,    0x44                    
```

| Constant | Value | Purpose |
|----------|-------|---------|
| `IO_BANK0_BASE` | `0x40028000` | IO Bank 0 base (function select) |
| `IO_BANK0_GPIO16_CTRL_OFFSET` | `0x84` | GPIO16 CTRL register offset |
| `PADS_BANK0_BASE` | `0x40038000` | Pads Bank 0 base (electrical config) |
| `PADS_BANK0_GPIO16_OFFSET` | `0x44` | GPIO16 pad register offset |

GPIO configuration requires two register blocks:

1. **PADS_BANK0**: Controls electrical properties (output disable, input enable, isolation)
2. **IO_BANK0**: Controls function selection (which peripheral drives the pin)

Each GPIO pin has a CTRL register in IO_BANK0 and a pad register in PADS_BANK0, both accessed through base + offset.

### Offset Calculation

For GPIO N:
- IO_BANK0 CTRL offset: `0x04 + (N * 0x08)` → GPIO16: `0x04 + (16 * 0x08) = 0x84`
- PADS_BANK0 offset: `0x04 + (N * 0x04)` → GPIO16: `0x04 + (16 * 0x04) = 0x44`

## SIO Constants

```asm
.equ SIO_BASE,                    0xd0000000
.equ SIO_GPIO_OUT_SET,            SIO_BASE + 0x018
.equ SIO_GPIO_OUT_CLR,            SIO_BASE + 0x020
.equ SIO_GPIO_OE_SET,             SIO_BASE + 0x038
```

| Constant | Value | Purpose |
|----------|-------|---------|
| `SIO_BASE` | `0xd0000000` | Single-cycle IO block base |
| `SIO_GPIO_OUT_SET` | `0xd0000018` | Atomic GPIO output set |
| `SIO_GPIO_OUT_CLR` | `0xd0000020` | Atomic GPIO output clear |
| `SIO_GPIO_OE_SET` | `0xd0000038` | Atomic GPIO output-enable set |

The SIO block provides single-cycle access to GPIO pins.  On ARM, the SIO is accessed via coprocessor instructions (`mcrr p0`).  On RISC-V, the same hardware is accessed through memory-mapped registers at `0xd0000000`.

### Atomic Set/Clear Registers

The SIO provides dedicated set and clear registers.  Writing a `1` bit to `GPIO_OUT_SET` drives that pin high.  Writing a `1` bit to `GPIO_OUT_CLR` drives it low.  Bits written as `0` are unaffected.  This eliminates the need for read-modify-write sequences and prevents race conditions.

## Address Map Overview

| Base Address | Peripheral | Used Constants |
|-------------|-----------|----------------|
| `0x10000000` | Flash (XIP) | Entry point in `image_def.s` |
| `0x20000000` | SRAM | `STACK_TOP`, `STACK_LIMIT` |
| `0x40010000` | Clocks | `CLK_PERI_CTRL` |
| `0x40020000` | Resets | `RESETS_RESET`, `RESETS_RESET_DONE` |
| `0x40028000` | IO Bank 0 | `IO_BANK0_GPIO16_CTRL_OFFSET` |
| `0x40038000` | Pads Bank 0 | `PADS_BANK0_GPIO16_OFFSET` |
| `0x40048000` | XOSC | `XOSC_CTRL`, `XOSC_STATUS`, `XOSC_STARTUP` |
| `0xd0000000` | SIO | `SIO_GPIO_OUT_SET`, `SIO_GPIO_OUT_CLR`, `SIO_GPIO_OE_SET` |

## Why One File?

Centralising all constants in a single file has three benefits:

1. **Single source of truth**: Changing a register address updates it everywhere.
2. **No duplication**: Every `.s` file includes `constants.s` rather than defining its own copies.
3. **Readable code**: `li t0, XOSC_CTRL` is self-documenting; `li t0, 0x40048000` is not.

## Summary

- `constants.s` defines every memory-mapped address and magic number used in the blink driver.
- `.equ` creates assembly-time constants with no memory cost.
- Constants are organised by peripheral: stack, XOSC, clocks, resets, GPIO (IO + pads), SIO.
- The SIO constants (`SIO_BASE` + offsets) are unique to RISC-V — ARM uses coprocessor instructions instead.
- Every other source file includes this file with `.include "constants.s"`.
