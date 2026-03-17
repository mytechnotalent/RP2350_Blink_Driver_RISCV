# Chapter 16: Bitwise Operations for Hardware Programming

## Introduction

Bare-metal firmware is fundamentally about controlling hardware, and hardware is controlled by setting, clearing, and testing individual bits in memory-mapped registers.  Every peripheral on the RP2350 exposes its functionality through bit fields — groups of bits with specific meanings.  This chapter catalogs the bit manipulation patterns used throughout our blink driver and builds your fluency in reading and writing them.

## The Fundamental Operations

There are four primitive bit operations in our firmware:

| Operation | Instruction | Pattern | Effect |
|-----------|-------------|---------|--------|
| Set bit | `ori` | `ori rd, rs, (1<<N)` | Force bit N to 1 |
| Clear bit | `and` + mask | `li mask, ~(1<<N)` then `and rd, rs, mask` | Force bit N to 0 |
| Test bit | `andi` | `andi rd, rs, (1<<N)` | Isolate bit N (result 0 or non-zero) |
| Invert | `not` | `not rd, rs` | Flip all bits |

## Set a Single Bit

To set bit N without affecting other bits, OR with a mask that has only bit N set:

```asm
  ori   t1, t1, (1<<6)                           # set bit 6 (IE)
```

Truth table for OR:

```
  Original bit:  0  1  0  1
  Mask bit:      1  1  0  0
  Result:        1  1  0  1
```

Bits where the mask is 0 are unchanged.  Bits where the mask is 1 are forced to 1.

### In Our Firmware

gpio.s sets the Input Enable bit in the pad register:

```asm
  ori   t1, t1, (1<<6)                           # set IE (input enable)
```

gpio.s sets the FUNCSEL value:

```asm
  ori   t1, t1, 0x05                             # set FUNCSEL = 5 (SIO)
```

xosc.s enables the peripheral clock AUXSRC:

```asm
  ori   t1, t1, 128                              # set AUXSRC: XOSC_CLKSRC bit
```

### `or` for Larger Masks

When the mask exceeds the 12-bit immediate range of `ori`, use `or` with a register:

```asm
  li    t2, (1<<11)                              # ENABLE bit mask
  or    t1, t1, t2                               # set ENABLE bit
```

This two-instruction sequence handles any bit position.

## Clear a Single Bit

RISC-V has no `bic` (bit clear) instruction like ARM.  Instead, we create an inverted mask and AND:

```asm
  li    t2, ~(1<<7)                              # mask = 0xFFFFFF7F
  and   t1, t1, t2                               # clear OD bit 7
```

AND truth table:

```
  Original bit:  0  1  0  1
  Mask bit:      0  0  1  1
  Result:        0  0  0  1
```

Bits where the mask is 1 are unchanged.  Bits where the mask is 0 are forced to 0.

### In Our Firmware

gpio.s clears Output Disable and Isolation in the pad register:

```asm
  li    t2, ~(1<<7)                              # mask to clear OD bit
  and   t1, t1, t2                               # clear OD bit
  li    t2, ~(1<<8)                              # mask to clear ISO bit
  and   t1, t1, t2                               # clear ISO bit
```

reset.s clears the IO_BANK0 reset bit:

```asm
  li    t2, (1<<6)                               # IO_BANK0 reset mask
  not   t2, t2                                   # invert: 0xFFFFFFBF
  and   t1, t1, t2                               # clear IO_BANK0 bit
```

The `not` + `and` pattern is equivalent to ARM's `bic`.

## Clear a Multi-Bit Field

To clear several contiguous bits (a "field"), use `andi` with a mask:

```asm
  andi  t1, t1, ~0x1f                            # clear bits [4:0]
```

The mask `~0x1f` = `0xFFFFFFE0` clears the lowest 5 bits.  Since `andi` sign-extends its 12-bit immediate, the assembler encodes this as -32 (which sign-extends to 0xFFFFFFE0).

This is used in gpio.s to clear the FUNCSEL field before writing a new value:

```asm
  andi  t1, t1, ~0x1f                            # clear FUNCSEL [4:0]
  ori   t1, t1, 0x05                             # set FUNCSEL = 5 (SIO)
```

This two-step pattern — clear then set — is standard for writing a multi-bit field without affecting surrounding bits.

## Test a Bit

To check whether a bit is set, AND with a mask and branch on the result:

```asm
  andi  t1, t1, (1<<6)                           # isolate bit 6
  beqz  t1, .GPIO_Subsystem_Reset_Wait           # branch if bit is 0
```

Unlike ARM (which has `tst` that sets flags without storing a result), RISC-V `andi` stores the result in the destination register.  We then branch based on whether the result is zero.

### Polling Loops

Both hardware polling loops use `andi` + `beqz` or `bgez`:

**XOSC Stabilization (xosc.s):**

```asm
.Init_XOSC_Wait:
  li    t0, XOSC_STATUS                          # load XOSC_STATUS address
  lw    t1, 0(t0)                                # read XOSC_STATUS value
  bgez  t1, .Init_XOSC_Wait                      # bit31 clear -> still unstable
```

This exploits signed interpretation: if bit 31 is clear, the value is >= 0.

**Reset Completion (reset.s):**

```asm
.GPIO_Subsystem_Reset_Wait:
  li    t0, RESETS_RESET_DONE                    # load RESETS->RESET_DONE address
  lw    t1, 0(t0)                                # read RESETS->RESET_DONE value
  andi  t1, t1, (1<<6)                           # test IO_BANK0 reset done
  beqz  t1, .GPIO_Subsystem_Reset_Wait           # wait until done
```

## Shift Left for Dynamic Bit Position

When the bit position is in a register (not known at assembly time), use `sll`:

```asm
  li    t1, 1                                    # bit value
  sll   t1, t1, a2                               # shift to GPIO position
  sw    t1, 0(t0)                                # write to SIO register
```

If `a2` = 16, the result is `0x00010000` — a mask with only bit 16 set.  This pattern appears in GPIO_Config, GPIO_Set, and GPIO_Clear.

## Combined Patterns

### Read-Modify-Write (Single Bit)

```asm
  li    t0, CLK_PERI_CTRL                        # compute address
  lw    t1, 0(t0)                                # READ
  li    t2, (1<<11)                              # ENABLE bit mask
  or    t1, t1, t2                               # MODIFY: set bit
  sw    t1, 0(t0)                                # WRITE
```

### Read-Modify-Write (Multiple Bits)

```asm
  lw    t1, 0(t0)                                # READ
  li    t2, ~(1<<7)                              # mask for OD
  and   t1, t1, t2                               # MODIFY: clear OD
  ori   t1, t1, (1<<6)                           # MODIFY: set IE
  li    t2, ~(1<<8)                              # mask for ISO
  and   t1, t1, t2                               # MODIFY: clear ISO
  sw    t1, 0(t0)                                # WRITE
```

### Clear Field Then Set Value

```asm
  lw    t1, 0(t0)                                # READ
  andi  t1, t1, ~0x1f                            # clear field [4:0]
  ori   t1, t1, 0x05                             # set value 5
  sw    t1, 0(t0)                                # WRITE
```

## Bit Fields in Our Registers

### PADS_BANK0 Pad Register (GPIO16)

```
Bit 8: ISO  (Isolation)         — clear to 0
Bit 7: OD   (Output Disable)    — clear to 0
Bit 6: IE   (Input Enable)      — set to 1
Bit 5: DRIVE[1]                  — unchanged
Bit 4: DRIVE[0]                  — unchanged
Bit 3: PUE  (Pull-Up Enable)    — unchanged
Bit 2: PDE  (Pull-Down Enable)  — unchanged
Bit 1: SCHMITT                   — unchanged
Bit 0: SLEWFAST                  — unchanged
```

### IO_BANK0 Control Register (GPIO16)

```
Bits [4:0]: FUNCSEL — cleared to 0, then set to 5 (SIO)
```

### CLK_PERI_CTRL

```
Bit 11:    ENABLE   — set to 1
Bits [7:5]: AUXSRC  — set to 4 (XOSC), we write 128 to bit 7
```

### SIO GPIO Registers

The SIO GPIO_OE_SET, GPIO_OUT_SET, and GPIO_OUT_CLR registers use **atomic set/clear semantics**: writing a 1-bit to these registers sets or clears the corresponding GPIO output or enable bit.  No read-modify-write is needed — a single `sw` with a bit mask is sufficient.

## Contrast with ARM

| Operation | ARM | RISC-V |
|-----------|-----|--------|
| Set bit | `orr r, r, #(1<<N)` | `ori r, r, (1<<N)` or `or r, r, mask` |
| Clear bit | `bic r, r, #(1<<N)` | `li mask, ~(1<<N)` + `and r, r, mask` |
| Test bit | `tst r, #(1<<N)` + `beq` | `andi r, r, (1<<N)` + `beqz` |
| Clear field | `bic r, r, #0x1f` | `andi r, r, ~0x1f` |

ARM's `bic` instruction clears bits in one instruction.  RISC-V requires two instructions (`li` mask + `and`), but the pattern is still straightforward.

## Summary

- `ori rd, rs, (1<<N)` sets bit N: the fundamental enable operation.
- `li mask, ~(1<<N)` + `and rd, rs, mask` clears bit N: the fundamental disable operation.
- `andi rd, rs, (1<<N)` tests bit N: used in all polling loops.
- Multi-bit fields are written with a clear-then-set pattern: `andi` with the field mask, then `ori` with the value.
- The read-modify-write pattern (li → lw → modify → sw) preserves bits we do not intend to change.
- SIO set/clear registers use atomic semantics — no read-modify-write needed.
