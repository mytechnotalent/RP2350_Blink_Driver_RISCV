# Chapter 26: Reset Controller — `reset.s`

## Introduction

Every peripheral on the RP2350 boots in a held-in-reset state.  Before we can configure GPIO pins, the IO_BANK0 peripheral must be released from reset and given time to initialize.  `reset.s` contains `Init_Subsystem`, which clears the IO_BANK0 reset bit and polls until the hardware confirms the release is complete.

## Full Source

```asm
.include "constants.s"

.section .text                                   # code section
.align 2                                         # align to 4-byte boundary

.global Init_Subsystem
.type Init_Subsystem, @function
Init_Subsystem:
.GPIO_Subsystem_Reset:
  li    t0, RESETS_RESET                         # load RESETS->RESET address
  lw    t1, 0(t0)                                # read RESETS->RESET value
  li    t2, (1<<6)                               # IO_BANK0 reset mask
  not   t2, t2                                   # invert mask
  and   t1, t1, t2                               # clear IO_BANK0 bit
  sw    t1, 0(t0)                                # store value into RESETS->RESET address
.GPIO_Subsystem_Reset_Wait:
  li    t0, RESETS_RESET_DONE                    # load RESETS->RESET_DONE address
  lw    t1, 0(t0)                                # read RESETS->RESET_DONE value
  andi  t1, t1, (1<<6)                           # test IO_BANK0 reset done
  beqz  t1, .GPIO_Subsystem_Reset_Wait           # wait until done
  ret                                            # return
```

## The Reset Controller

The RP2350 reset controller manages the reset state of all peripherals.  Each peripheral has a dedicated bit:

| Bit | Peripheral |
|-----|-----------|
| 0 | ADC |
| 1 | BUSCTRL |
| 2 | DMA |
| 3 | HSTX |
| 4 | I2C0 |
| 5 | I2C1 |
| **6** | **IO_BANK0** |
| 7 | IO_QSPI |
| 8 | JTAG |
| ... | ... |

At power-on, all bits in `RESETS_RESET` are set to `1`, meaning every peripheral is held in reset.  To use a peripheral, we must clear its bit.

## Phase 1: Release from Reset

### Load and Read

```asm
  li    t0, RESETS_RESET                         # load RESETS->RESET address
  lw    t1, 0(t0)                                # read RESETS->RESET value
```

`RESETS_RESET` is at `0x40020000`.  We read the current value because we only want to modify bit 6 — other peripherals should remain in reset.

### Create Inverted Mask

```asm
  li    t2, (1<<6)                               # IO_BANK0 reset mask
  not   t2, t2                                   # invert mask
```

`li t2, (1<<6)` loads `0x00000040` — a single bit set at position 6.

`not t2, t2` inverts all bits, producing `0xFFFFFFBF` — all bits set except bit 6.

This two-step pattern is necessary because RISC-V has no "bit clear" instruction equivalent to ARM's `bic`.  To clear a specific bit, we must:
1. Create a mask with that bit set
2. Invert it to get all-ones-except-that-bit
3. AND with the original value

### Clear the Bit

```asm
  and   t1, t1, t2                               # clear IO_BANK0 bit
  sw    t1, 0(t0)                                # store value into RESETS->RESET address
```

`and t1, t1, t2` clears bit 6 while preserving all other bits.

| Bit | `t1` (before) | `t2` (mask) | `t1` (after) |
|-----|---------------|-------------|--------------|
| 5 | 1 | 1 | 1 (preserved) |
| **6** | **1** | **0** | **0** (cleared) |
| 7 | 1 | 1 | 1 (preserved) |

After `sw`, the reset controller begins the IO_BANK0 release sequence.  The hardware takes time to complete this — we must poll.

## Phase 2: Wait for Completion

```asm
.GPIO_Subsystem_Reset_Wait:
  li    t0, RESETS_RESET_DONE                    # load RESETS->RESET_DONE address
  lw    t1, 0(t0)                                # read RESETS->RESET_DONE value
  andi  t1, t1, (1<<6)                           # test IO_BANK0 reset done
  beqz  t1, .GPIO_Subsystem_Reset_Wait           # wait until done
  ret                                            # return
```

### Read Status

`RESETS_RESET_DONE` is at `0x40020008`.  Each bit mirrors the corresponding `RESETS_RESET` bit, but indicates whether the release is complete (1 = done).

### Test Specific Bit

```asm
  andi  t1, t1, (1<<6)                           # test IO_BANK0 reset done
```

`andi` with `(1<<6) = 64` isolates bit 6.  The result is either `64` (bit set, done) or `0` (bit clear, still resetting).

Note that `(1<<6) = 64` fits within the 12-bit signed immediate range for `andi` (range: -2048 to 2047), so we can use the immediate form directly.

### Branch on Zero

```asm
  beqz  t1, .GPIO_Subsystem_Reset_Wait           # wait until done
```

`beqz` (branch if equal to zero) loops back if the reset is not yet complete.  When bit 6 becomes `1`, the result is non-zero and execution falls through to `ret`.

### Polling Loop Structure

```
         ┌─────────────────────┐
         │ Load RESET_DONE     │
         │ Read register       │
         │ Test bit 6          │
         │ beqz → loop back    │──── bit 6 = 0 (not done)
         └──────────┬──────────┘
                    │ bit 6 = 1 (done)
                    ▼
                  ret
```

This is the same polling pattern used in `Init_XOSC`, but here we test a specific bit rather than using the sign-bit trick.

## Register Summary

| Register | Address | Access | Purpose |
|----------|---------|--------|---------|
| `RESETS_RESET` | `0x40020000` | R/W | Peripheral reset control (1 = held) |
| `RESETS_RESET_DONE` | `0x40020008` | Read | Release status (1 = done) |
| `RESETS_RESET_CLEAR` | `0x40023000` | Write | Atomic clear alias |

### Atomic Clear Alternative

The constant `RESETS_RESET_CLEAR` (`0x40023000`) provides an atomic clear alias.  Writing `(1<<6)` to this address clears bit 6 without reading first.  Our code uses the explicit read-modify-write approach instead, which is more instructive:

```asm
# Alternative (atomic clear):
li    t0, RESETS_RESET_CLEAR
li    t1, (1<<6)
sw    t1, 0(t0)
```

Both approaches produce the same result.  The atomic alias is simpler but hides the read-modify-write mechanics we want to teach.

## The Clear-Bit Pattern

Since RISC-V lacks ARM's `bic` (bit clear) instruction, clearing a bit requires three instructions:

```asm
# ARM (one instruction):
bic   r1, r1, #(1<<6)

# RISC-V (three instructions):
li    t2, (1<<6)
not   t2, t2
and   t1, t1, t2
```

This is a common pattern in RISC-V bare-metal programming.  You will see it whenever a specific bit must be cleared in a register.

## Contrast with ARM

| Aspect | ARM | RISC-V |
|--------|-----|--------|
| Clear bit | `bic r1, r1, #(1<<6)` | `li`+`not`+`and` (3 instructions) |
| Test bit | `tst r1, #(1<<6)` | `andi t1, t1, (1<<6)` |
| Branch | `beq .wait` (flag-based) | `beqz t1, .wait` (value-based) |
| Register addresses | Identical | Identical |
| Bit positions | Identical | Identical |

The hardware is the same — the reset controller does not care which CPU is accessing it.  Only the instruction sequences differ.

## Summary

- `Init_Subsystem` releases IO_BANK0 from reset by clearing bit 6 in `RESETS_RESET`.
- The `li` → `not` → `and` pattern is the RISC-V equivalent of ARM's `bic` instruction.
- After writing the modified value, the function polls `RESETS_RESET_DONE` bit 6 until the hardware confirms the release.
- `andi` + `beqz` tests a single bit and loops while it remains zero.
- The function is a leaf function using only temporary registers.
- After this function returns, IO_BANK0 is active and GPIO pins can be configured.
