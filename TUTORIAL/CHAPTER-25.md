# Chapter 25: Oscillator Initialization — `xosc.s`

## Introduction

The RP2350 boots from an internal ring oscillator that is fast but imprecise.  For reliable peripheral operation, we switch to the external 12 MHz crystal oscillator (XOSC).  `xosc.s` contains two functions: `Init_XOSC` configures and waits for the crystal to stabilize, and `Enable_XOSC_Peri_Clock` routes the stable clock to the peripheral bus.  This chapter dissects every instruction.

## Full Source

```asm
.include "constants.s"

.section .text                                   # code section
.align 2                                         # align to 4-byte boundary

.global Init_XOSC
.type Init_XOSC, @function
Init_XOSC:
  li    t0, XOSC_STARTUP                         # load XOSC_STARTUP address
  li    t1, 0x00c4                               # set delay 50,000 cycles
  sw    t1, 0(t0)                                # store value into XOSC_STARTUP
  li    t0, XOSC_CTRL                            # load XOSC_CTRL address
  li    t1, 0x00FABAA0                           # set 1_15MHz, freq range, actual 14.5MHz
  sw    t1, 0(t0)                                # store value into XOSC_CTRL
.Init_XOSC_Wait:
  li    t0, XOSC_STATUS                          # load XOSC_STATUS address
  lw    t1, 0(t0)                                # read XOSC_STATUS value
  bgez  t1, .Init_XOSC_Wait                      # bit31 clear -> still unstable
  ret                                            # return

.global Enable_XOSC_Peri_Clock
.type Enable_XOSC_Peri_Clock, @function
Enable_XOSC_Peri_Clock:
  li    t0, CLK_PERI_CTRL                        # load CLK_PERI_CTRL address
  lw    t1, 0(t0)                                # read CLK_PERI_CTRL value
  li    t2, (1<<11)                              # ENABLE bit mask
  or    t1, t1, t2                               # set ENABLE bit
  ori   t1, t1, 128                              # set AUXSRC: XOSC_CLKSRC bit
  sw    t1, 0(t0)                                # store value into CLK_PERI_CTRL
  ret                                            # return
```

## Init_XOSC — Line by Line

### Step 1: Set Startup Delay

```asm
  li    t0, XOSC_STARTUP                         # load XOSC_STARTUP address
  li    t1, 0x00c4                               # set delay 50,000 cycles
  sw    t1, 0(t0)                                # store value into XOSC_STARTUP
```

`XOSC_STARTUP` is at `0x4004800c`.  The value `0x00c4` (196 decimal) programs the startup delay counter.  The crystal needs time to begin oscillating at a stable frequency — this register tells the hardware how many reference clock cycles to wait before declaring the oscillator stable.

The delay value relates to the internal ring oscillator frequency.  `0x00c4` provides approximately 50,000 cycles of settling time, sufficient for the 12 MHz crystal on the Pico 2 board.

**Instruction pattern**: `li` loads the address into `t0`, then `sw` writes the value through the pointer.  This is the standard RISC-V store pattern — every memory-mapped register write follows `li address` → `li value` → `sw value, 0(address)`.

### Step 2: Configure and Enable XOSC

```asm
  li    t0, XOSC_CTRL                            # load XOSC_CTRL address
  li    t1, 0x00FABAA0                           # set 1_15MHz, freq range, actual 14.5MHz
  sw    t1, 0(t0)                                # store value into XOSC_CTRL
```

`XOSC_CTRL` is at `0x40048000`.  The value `0x00FABAA0` encodes two fields:

| Field | Bits | Value | Meaning |
|-------|------|-------|---------|
| FREQ_RANGE | [11:0] | `0xAA0` | 1–15 MHz crystal range |
| ENABLE | [23:12] | `0xFAB` | Magic enable value |

The RP2350 requires these exact magic values — writing any other pattern to the ENABLE field does not activate the oscillator.  The FREQ_RANGE confirms our crystal is in the 1–15 MHz band (our crystal is 12 MHz).

### Step 3: Wait for Stability

```asm
.Init_XOSC_Wait:
  li    t0, XOSC_STATUS                          # load XOSC_STATUS address
  lw    t1, 0(t0)                                # read XOSC_STATUS value
  bgez  t1, .Init_XOSC_Wait                      # bit31 clear -> still unstable
  ret                                            # return
```

`XOSC_STATUS` is at `0x40048004`.  Bit 31 is the STABLE flag.

**The `bgez` trick**: `bgez t1, .Init_XOSC_Wait` branches if `t1 ≥ 0` (signed).  In two's complement, bit 31 is the sign bit:

| Bit 31 | Signed interpretation | XOSC state | `bgez` result |
|--------|----------------------|------------|---------------|
| 0 | Non-negative (≥ 0) | Unstable | Branch (keep waiting) |
| 1 | Negative (< 0) | Stable | Fall through (done) |

This is more efficient than loading a mask and testing with `and`/`beqz`.  A single conditional branch replaces two instructions.

### Register Usage

`Init_XOSC` uses only `t0` and `t1` — both are caller-saved temporary registers.  It does not touch `sp` or save `ra` because it is a leaf function (calls no other functions).

## Enable_XOSC_Peri_Clock — Line by Line

### Step 1: Read Current Value

```asm
  li    t0, CLK_PERI_CTRL                        # load CLK_PERI_CTRL address
  lw    t1, 0(t0)                                # read CLK_PERI_CTRL value
```

`CLK_PERI_CTRL` is at `0x40010048`.  We read the current value first because we need to modify specific bits without disturbing others.

### Step 2: Set ENABLE Bit

```asm
  li    t2, (1<<11)                              # ENABLE bit mask
  or    t1, t1, t2                               # set ENABLE bit
```

Bit 11 is the clock ENABLE bit.  `or` sets it to 1 without affecting any other bits.  We use `li` + `or` instead of `ori` because the immediate `(1<<11) = 2048` exceeds the 12-bit signed range of `ori` (-2048 to 2047).

### Step 3: Set Clock Source

```asm
  ori   t1, t1, 128                              # set AUXSRC: XOSC_CLKSRC bit
```

Bits [7:5] of `CLK_PERI_CTRL` select the auxiliary clock source.  The value 128 (`0x80`, bit 7) selects XOSC as the source.  Since 128 fits in the 12-bit signed immediate range, we can use `ori` directly.

### Step 4: Write Back

```asm
  sw    t1, 0(t0)                                # store value into CLK_PERI_CTRL
  ret                                            # return
```

The modified value is written back to `CLK_PERI_CTRL`.  After this function returns, all peripherals on the APB bus are clocked from the stable 12 MHz crystal.

### Read-Modify-Write Pattern

This function demonstrates the standard read-modify-write pattern for APB registers on RISC-V:

```
li    t0, REGISTER_ADDRESS
lw    t1, 0(t0)          # READ
or/and/ori t1, ...       # MODIFY
sw    t1, 0(t0)          # WRITE
```

Unlike the SIO block (which has atomic set/clear registers), APB peripherals require this three-step sequence.

## Register Map

### XOSC Registers Used

| Register | Address | Bits Modified | Purpose |
|----------|---------|---------------|---------|
| `XOSC_STARTUP` | `0x4004800c` | [15:0] | Startup delay counter |
| `XOSC_CTRL` | `0x40048000` | [23:0] | Enable + frequency range |
| `XOSC_STATUS` | `0x40048004` | [31] (read) | Stable flag |

### Clock Registers Used

| Register | Address | Bits Modified | Purpose |
|----------|---------|---------------|---------|
| `CLK_PERI_CTRL` | `0x40010048` | [11], [7] | Enable + AUXSRC |

## Timing

The `Init_XOSC_Wait` loop spins for approximately 50,000 ring oscillator cycles.  At the ~150 MHz ring oscillator default, this is roughly 0.3 ms.  The loop body is four instructions (three loads and a branch), so it executes roughly 12,500 iterations before the STABLE bit sets.

## Contrast with ARM

| Aspect | ARM | RISC-V |
|--------|-----|--------|
| Register access | Same addresses | Same addresses |
| Stability check | `tst` + flag-based branch | `bgez` (sign-bit trick) |
| Read-modify-write | `ldr`/`orr`/`str` | `lw`/`or`/`sw` |
| Immediate limit | Flexible barrel shifter | 12-bit signed |
| Large immediates | `orr` with rotation | `li` + `or` |

The hardware registers are identical — only the instruction sequences differ.

## Summary

- `Init_XOSC` programs the startup delay, enables the crystal with magic values, and polls `XOSC_STATUS` bit 31.
- `bgez` provides an efficient single-instruction test of the sign bit to detect the STABLE flag.
- `Enable_XOSC_Peri_Clock` uses a read-modify-write sequence to enable the peripheral clock with XOSC as its source.
- `or` is used for bit 11 (exceeds `ori` range), while `ori` handles bit 7 (fits in 12-bit immediate).
- After both functions complete, the APB bus and all peripherals are clocked at 12 MHz from the crystal.
- Both functions are leaf functions using only temporary registers (`t0`, `t1`, `t2`).
