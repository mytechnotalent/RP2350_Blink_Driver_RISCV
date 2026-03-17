# Chapter 9: RISC-V Arithmetic and Logic Instructions

## Introduction

Arithmetic and logic instructions form the computational core of any processor.  On the Hazard3 core, these instructions operate exclusively on registers — never directly on memory — consistent with the load-store philosophy.  Our blink driver uses arithmetic for delay timing and address calculation, and logic for bit manipulation of hardware registers.  This chapter examines every arithmetic and logic instruction that appears in our firmware.

## Arithmetic Instructions

### `add` — Addition

```asm
  add   t0, t0, a0                               # t0 = t0 + a0
```

`add` is an R-type instruction that adds two source registers and stores the result in the destination.  In gpio.s, it computes the pad register address:

```asm
  li    t0, PADS_BANK0_BASE                      # t0 = 0x40038000
  add   t0, t0, a0                               # t0 = base + PAD_OFFSET
```

This is how GPIO_Config reaches the pad control register for GPIO16.

### `addi` — Add Immediate

```asm
  addi  t1, t1, -1                               # t1 = t1 - 1
```

`addi` adds a signed 12-bit immediate to a register.  It is one of the most versatile instructions in RISC-V because subtraction is just addition with a negative immediate.  There is no separate `sub immediate` instruction.

In delay.s, `addi` decrements the loop counter:

```asm
.Delay_MS_Loop:
  addi  t1, t1, -1                               # decrement counter
  bnez  t1, .Delay_MS_Loop                       # branch until zero
```

In gpio.s, `addi` adjusts the stack pointer:

```asm
  addi  sp, sp, -4                               # allocate stack frame
  addi  sp, sp, 4                                # deallocate stack frame
```

### `mul` — Multiplication

```asm
  mul   t1, a0, t0                               # t1 = a0 * t0
```

`mul` is an R-type instruction from the M extension.  In delay.s, it computes the total number of loop iterations:

```asm
  li    t0, 3600                                 # loops per millisecond
  mul   t1, a0, t0                               # total = ms * 3600
```

At 12 MHz XOSC clock (approximately 14.5 MHz with internal tolerances), 3,600 inner iterations approximate one millisecond.

## Logic Instructions

### `and` — Bitwise AND

```asm
  and   t1, t1, t2                               # t1 = t1 & t2
```

`and` is an R-type instruction that performs bitwise AND.  In gpio.s, it clears specific bits using a precomputed mask:

```asm
  li    t2, ~(1<<7)                              # mask = 0xFFFFFF7F
  and   t1, t1, t2                               # clear OD bit 7
```

And in reset.s, it clears the IO_BANK0 reset bit:

```asm
  li    t2, (1<<6)                               # IO_BANK0 reset mask
  not   t2, t2                                   # invert: 0xFFFFFFBF
  and   t1, t1, t2                               # clear IO_BANK0 bit
```

### `andi` — AND Immediate

```asm
  andi  t1, t1, (1<<6)                           # t1 = t1 & 0x40
```

`andi` performs bitwise AND with a sign-extended 12-bit immediate.  In reset.s, it tests whether IO_BANK0 reset is done:

```asm
  andi  t1, t1, (1<<6)                           # test IO_BANK0 reset done
  beqz  t1, .GPIO_Subsystem_Reset_Wait           # wait until done
```

In gpio.s, it clears the FUNCSEL field:

```asm
  andi  t1, t1, ~0x1f                            # clear FUNCSEL [4:0]
```

Here `~0x1f` = `0xFFFFFFE0`, but since `andi` sign-extends a 12-bit immediate, the assembler encodes this as -32 (which sign-extends to 0xFFFFFFE0).

### `or` — Bitwise OR

```asm
  or    t1, t1, t2                               # t1 = t1 | t2
```

`or` is an R-type instruction that sets bits.  In xosc.s, it enables the peripheral clock:

```asm
  li    t2, (1<<11)                              # ENABLE bit mask
  or    t1, t1, t2                               # set ENABLE bit
```

### `ori` — OR Immediate

```asm
  ori   t1, t1, (1<<6)                           # set bit 6
```

`ori` performs bitwise OR with a sign-extended 12-bit immediate.  In gpio.s, it sets the input enable bit:

```asm
  ori   t1, t1, (1<<6)                           # set IE bit
```

And sets the FUNCSEL value:

```asm
  ori   t1, t1, 0x05                             # set FUNCSEL = 5 (SIO)
```

In xosc.s, it sets the AUXSRC bits:

```asm
  ori   t1, t1, 128                              # set AUXSRC: XOSC_CLKSRC bit
```

### `not` — Bitwise NOT (Pseudo-Instruction)

```asm
  not   t2, t2                                   # t2 = ~t2
```

`not` inverts all bits.  It is a pseudo-instruction that expands to `xori rd, rs1, -1`:

```
not   t2, t2   =>   xori  t2, t2, -1
```

Since -1 in two's complement is 0xFFFFFFFF, XOR with -1 inverts every bit.  In reset.s, it creates a clear mask:

```asm
  li    t2, (1<<6)                               # IO_BANK0 reset mask
  not   t2, t2                                   # invert: 0xFFFFFFBF
  and   t1, t1, t2                               # clear IO_BANK0 bit
```

### `sll` — Shift Left Logical

```asm
  sll   t1, t1, a2                               # t1 = t1 << a2
```

`sll` shifts the source register left by the number of positions in the second source register.  In gpio.s, it creates a single-bit mask at the GPIO position:

```asm
  li    t1, 1                                    # bit value
  sll   t1, t1, a2                               # shift to GPIO position
```

If `a2` = 16, the result is `0x00010000` — a mask with only bit 16 set.  This is used for GPIO_OE_SET, GPIO_OUT_SET, and GPIO_OUT_CLR operations.

## No Condition Flags

Unlike ARM (which uses the APSR with N, Z, C, V flags), RISC-V has **no condition flags register**.  Branches compare registers directly:

| ARM Pattern | RISC-V Pattern |
|-------------|----------------|
| `subs r5, r5, #1` then `bne .Loop` | `addi t1, t1, -1` then `bnez t1, .Loop` |
| `tst r1, #mask` then `beq .Wait` | `andi t1, t1, mask` then `beqz t1, .Wait` |
| `cmp r0, #0` then `ble .Done` | `blez a0, .Done` |

This simplifies the hardware — no flag register to update, no dependency chains through flags — but means every comparison must name its operand registers.

## Read-Modify-Write Pattern

Hardware register manipulation follows a consistent pattern throughout our firmware:

```asm
  li    t0, PADS_BANK0_BASE                      # compute address
  add   t0, t0, a0                               # add offset
  lw    t1, 0(t0)                                # READ current value
  li    t2, ~(1<<7)                              # create mask
  and   t1, t1, t2                               # MODIFY: clear bit
  ori   t1, t1, (1<<6)                           # MODIFY: set bit
  sw    t1, 0(t0)                                # WRITE back
```

This pattern appears in gpio.s (pad configuration, CTRL register), xosc.s (clock enable), and reset.s (subsystem reset).  It preserves all bits we do not intend to change.

## Summary

- Arithmetic instructions (`add`, `addi`, `mul`) handle addressing, delay loops, and stack adjustment.
- Logic instructions (`and`, `andi`, `or`, `ori`, `not`, `sll`) manipulate individual bits in hardware registers.
- RISC-V has no condition flags — branches compare register values directly.
- The read-modify-write pattern (li → lw → and/or → sw) is the fundamental hardware register manipulation idiom.
