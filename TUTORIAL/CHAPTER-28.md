# Chapter 28: GPIO Set/Clear, Delay, and Coprocessor — `gpio.s` Part 2, `delay.s`, `coprocessor.s`

## Introduction

With GPIO configuration complete, we need three more building blocks: functions to drive the pin high and low, a timing function to control blink speed, and a compatibility stub for the coprocessor module.  This chapter covers `GPIO_Set`, `GPIO_Clear` (the remaining functions in `gpio.s`), all of `delay.s`, and `coprocessor.s`.

## GPIO_Set — Full Source

```asm
.global GPIO_Set
.type GPIO_Set, @function
GPIO_Set:
  li    t0, SIO_GPIO_OUT_SET                     # load SIO GPIO_OUT_SET address
  li    t1, 1                                    # bit value
  sll   t1, t1, a0                               # shift to GPIO position
  sw    t1, 0(t0)                                # set GPIO output high
  ret                                            # return
```

### How It Works

`GPIO_Set` drives a GPIO pin high using the SIO atomic set register.

**Step 1: Load register address**
```asm
  li    t0, SIO_GPIO_OUT_SET                     # load SIO GPIO_OUT_SET address
```
`SIO_GPIO_OUT_SET` is at `0xd0000018`.  Writing a 1-bit to this register drives the corresponding GPIO output high.

**Step 2: Create bitmask**
```asm
  li    t1, 1                                    # bit value
  sll   t1, t1, a0                               # shift to GPIO position
```
`a0` contains the GPIO number (16 for our LED).  `sll` shifts the value 1 left by 16 positions: `1 << 16 = 0x00010000`.

**Step 3: Atomic write**
```asm
  sw    t1, 0(t0)                                # set GPIO output high
  ret                                            # return
```
Writing `0x00010000` to `SIO_GPIO_OUT_SET` drives GPIO16 high.  Bits written as 0 have no effect — other pins are unaffected.

### No Read-Modify-Write Needed

The SIO_GPIO_OUT_SET register is write-only and atomic.  Unlike APB registers, we do not need to read the current state first.  The hardware OR's our written bits with the existing GPIO output state.

## GPIO_Clear — Full Source

```asm
.global GPIO_Clear
.type GPIO_Clear, @function
GPIO_Clear:
  li    t0, SIO_GPIO_OUT_CLR                     # load SIO GPIO_OUT_CLR address
  li    t1, 1                                    # bit value
  sll   t1, t1, a0                               # shift to GPIO position
  sw    t1, 0(t0)                                # set GPIO output low
  ret                                            # return
```

### How It Works

`GPIO_Clear` is the mirror of `GPIO_Set`.  The only difference is the target register:

| Function | Register | Address | Effect |
|----------|----------|---------|--------|
| `GPIO_Set` | `SIO_GPIO_OUT_SET` | `0xd0000018` | Drives pin high |
| `GPIO_Clear` | `SIO_GPIO_OUT_CLR` | `0xd0000020` | Drives pin low |

Writing `0x00010000` to `SIO_GPIO_OUT_CLR` clears GPIO16's output, driving the pin low.

### ARM Comparison

On ARM, both `GPIO_Set` and `GPIO_Clear` use `mcrr p0` coprocessor instructions to access the SIO block.  On RISC-V, the same SIO hardware is accessed through memory-mapped store instructions — conceptually simpler but functionally identical.

## delay.s — Full Source

```asm
.include "constants.s"

.section .text                                   # code section
.align 2                                         # align to 4-byte boundary

.global Delay_MS
.type Delay_MS, @function
Delay_MS:
.Delay_MS_Check:
  blez  a0, .Delay_MS_Done                       # if MS is not valid, return
.Delay_MS_Setup:
  li    t0, 3600                                 # loops per MS based on 14.5MHz clock
  mul   t1, a0, t0                               # MS * 3600
.Delay_MS_Loop:
  addi  t1, t1, -1                               # decrement counter
  bnez  t1, .Delay_MS_Loop                       # branch until zero
.Delay_MS_Done:
  ret                                            # return
```

### Parameter Validation

```asm
.Delay_MS_Check:
  blez  a0, .Delay_MS_Done                       # if MS is not valid, return
```

`blez` (Branch if Less than or Equal to Zero) checks for invalid input.  If `a0` is zero or negative, the function returns immediately.  This prevents the `mul` from producing a zero or negative count, which would cause the loop to run for billions of iterations (since `bnez` tests for non-zero, and decrementing from zero wraps to `0xFFFFFFFF`).

### Delay Calculation

```asm
.Delay_MS_Setup:
  li    t0, 3600                                 # loops per MS based on 14.5MHz clock
  mul   t1, a0, t0                               # MS * 3600
```

The constant `3600` is calibrated for the XOSC-derived clock speed.  After `Init_XOSC`, the CPU runs at approximately 14.5 MHz from the ring oscillator (the XOSC provides a reference but the system clock is still the ring oscillator at this point).

Each loop iteration takes approximately 4 cycles (the `addi` and `bnez` instructions plus pipeline effects).  So 3600 iterations × ~4 cycles ≈ 14,400 cycles ≈ 1 ms at 14.5 MHz.

`mul t1, a0, t0` multiplies the millisecond count by the per-millisecond loop count.  For `a0 = 500` (our blink half-period): `500 × 3600 = 1,800,000` iterations.

The `mul` instruction is available because our `-march=rv32imac_zicsr` target includes the M (multiply/divide) extension.

### Countdown Loop

```asm
.Delay_MS_Loop:
  addi  t1, t1, -1                               # decrement counter
  bnez  t1, .Delay_MS_Loop                       # branch until zero
.Delay_MS_Done:
  ret                                            # return
```

This is the tightest possible loop — two instructions:

1. `addi t1, t1, -1` — subtract 1 from counter
2. `bnez t1, .Delay_MS_Loop` — branch back if not zero

When `t1` reaches zero, `bnez` falls through to `ret`.

### Timing Accuracy

The delay is approximate.  Factors that affect accuracy:

| Factor | Effect |
|--------|--------|
| Clock speed variation | Ring oscillator is ±10% |
| Pipeline effects | Branch prediction affects cycle count |
| Function call overhead | `call`/`ret` adds a few cycles |
| Interrupts | None in our system (not enabled) |

For LED blinking, approximate timing is perfectly acceptable.  A precise timer peripheral would be needed for exact timing.

### Contrast with ARM Delay

| Aspect | ARM | RISC-V |
|--------|-----|--------|
| Loop constant | 2400 | 3600 |
| Multiply | `mul r1, r0, r2` | `mul t1, a0, t0` |
| Decrement | `subs r1, r1, #1` | `addi t1, t1, -1` |
| Branch | `bne .loop` (flag-based) | `bnez t1, .loop` (value-based) |
| Guard | Same (`cmp`/`ble`) | `blez a0, .done` |

The different loop constant (3600 vs 2400) reflects the different clock speeds and instruction timings between the ARM and RISC-V cores.

## coprocessor.s — Full Source

```asm
.include "constants.s"

.section .text                                   # code section
.align 2                                         # align to 4-byte boundary

.global Enable_Coprocessor
.type Enable_Coprocessor , @function
Enable_Coprocessor:
  ret                                            # no-op for RISC-V build
```

### Why a No-Op?

On ARM Cortex-M33, coprocessor 0 access must be explicitly enabled by writing to the CPACR (Coprocessor Access Control Register).  Without this, any `mcrr p0` instruction (used for SIO access) triggers a UsageFault.

On RISC-V, there is no coprocessor.  The SIO block is accessed through memory-mapped registers at `0xd0000000` — standard `lw`/`sw` instructions that require no special privilege setup.

The function exists as a compatibility stub so that `reset_handler.s` can maintain the same call sequence as the ARM variant.  It is a single `ret` instruction — zero overhead.

## All GPIO Functions Summary

| Function | Parameters | Register | Action |
|----------|-----------|----------|--------|
| `GPIO_Config` | a0=pad, a1=ctrl, a2=pin | PADS + IO_BANK0 + SIO_OE_SET | Full pin setup |
| `GPIO_Set` | a0=pin number | SIO_GPIO_OUT_SET | Drive high |
| `GPIO_Clear` | a0=pin number | SIO_GPIO_OUT_CLR | Drive low |

## SIO Register Map

```
SIO_BASE (0xd0000000)
  │
  ├── +0x018  GPIO_OUT_SET     GPIO_Set writes here
  ├── +0x020  GPIO_OUT_CLR     GPIO_Clear writes here
  └── +0x038  GPIO_OE_SET      GPIO_Config writes here
```

All three SIO registers are atomic — writing a 1-bit affects only that GPIO, and 0-bits are ignored.

## Summary

- `GPIO_Set` and `GPIO_Clear` are symmetric functions that drive a pin high or low through SIO atomic registers.
- Both use `sll` to create a dynamic bitmask from the GPIO number parameter.
- `Delay_MS` provides an approximate millisecond delay calibrated for ~14.5 MHz operation.
- `blez` guards against zero or negative input to prevent counter wraparound.
- `mul` (M extension) computes the total loop count in a single instruction.
- The countdown loop is two instructions: `addi` + `bnez`, the tightest possible.
- `Enable_Coprocessor` is a single `ret` — a no-op stub for ARM compatibility.
- On RISC-V, SIO access uses memory-mapped stores instead of coprocessor instructions.
