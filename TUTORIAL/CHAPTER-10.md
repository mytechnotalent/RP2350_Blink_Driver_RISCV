# Chapter 10: RISC-V Memory Access — Load and Store Deep Dive

## Introduction

The Hazard3 core is a load-store architecture: arithmetic and logic operate only on registers.  To interact with the outside world — RAM, peripheral registers, the stack — the processor must explicitly load from and store to memory.  This chapter explores every memory-access instruction and addressing mode used in our blink driver.

## `lw` — Load Word

`lw` reads a 32-bit word from memory into a register:

```asm
  lw    t1, 0(t0)                                # t1 = memory[t0 + 0]
```

The syntax is `lw rd, offset(rs1)` where `offset` is a signed 12-bit immediate (-2048 to 2047) and `rs1` is the base register.

### Zero Offset

```asm
  lw    t1, 0(t0)                                # t1 = memory[t0]
```

This is the most common form in our firmware.  xosc.s, reset.s, gpio.s, and coprocessor.s all load peripheral registers this way.  We compute the full address in `t0` first, then load with zero offset.

### Non-Zero Offset

```asm
  lw    t1, 4(t0)                                # t1 = memory[t0 + 4]
```

The offset avoids a separate `addi` to adjust the address.  Our firmware uses zero offset exclusively because each peripheral register access computes the full address via `li` and `add`.

## `sw` — Store Word

`sw` writes a 32-bit word from a register to memory:

```asm
  sw    t1, 0(t0)                                # memory[t0 + 0] = t1
```

The syntax is `sw rs2, offset(rs1)`.  Store completes the read-modify-write cycle.  After modifying bits with `and`/`or`/`ori`, the result is written back:

```asm
  lw    t1, 0(t0)                                # read
  ori   t1, t1, (1<<6)                           # modify
  sw    t1, 0(t0)                                # write back
```

Every hardware register configuration in our firmware follows this pattern.

## Other Load/Store Widths

RISC-V provides loads and stores for different widths, though our firmware uses only word-width:

| Instruction | Width | Size |
|-------------|-------|------|
| `lb` / `sb` | Byte | 8 bits |
| `lbu` | Byte (unsigned) | 8 bits |
| `lh` / `sh` | Halfword | 16 bits |
| `lhu` | Halfword (unsigned) | 16 bits |
| `lw` / `sw` | Word | 32 bits |

The `u` variants (unsigned) zero-extend rather than sign-extend.  All peripheral registers on the RP2350 are 32-bit aligned, so word access is always appropriate.

## Stack Operations — Manual Push and Pop

Unlike ARM (which has dedicated `push` and `pop` instructions), RISC-V manages the stack manually with `addi`, `sw`, and `lw`:

### Saving the Return Address (Push)

```asm
  addi  sp, sp, -4                               # allocate stack frame
  sw    ra, 0(sp)                                # save return address
```

This decrements the stack pointer by 4 bytes, then stores the return address register (`ra`) at the new stack top.

### Restoring the Return Address (Pop)

```asm
  lw    ra, 0(sp)                                # restore return address
  addi  sp, sp, 4                                # deallocate stack frame
```

This loads `ra` from the stack, then increments the stack pointer back.

### Our Firmware's Stack Usage

GPIO_Config is the only function that saves registers to the stack:

```asm
GPIO_Config:
  addi  sp, sp, -4                               # allocate stack frame
  sw    ra, 0(sp)                                # save return address
  ...                                            # function body
  lw    ra, 0(sp)                                # restore return address
  addi  sp, sp, 4                                # deallocate stack frame
  ret                                            # return
```

All other functions in our firmware are leaf functions (they do not call other functions), so they use `ra` directly without saving it.

### Contrast with ARM

| Operation | ARM | RISC-V |
|-----------|-----|--------|
| Save registers | `push {r4-r12, lr}` (one instruction) | `addi sp, sp, -N` + multiple `sw` instructions |
| Restore registers | `pop {r4-r12, lr}` (one instruction) | Multiple `lw` instructions + `addi sp, sp, N` |
| Stack growth | Automatic with push/pop | Manual with addi/sw/lw |

ARM's `push`/`pop` are more compact for saving many registers.  RISC-V's explicit approach is simpler conceptually — every step is visible.

## Memory Map and Peripheral Access

Our firmware accesses these memory regions:

```
+------------------------------+
| 0x10000000  Flash (code)     |
+------------------------------+
| 0x20000000  SRAM (data)      |
+------------------------------+
| 0x40010000  CLOCKS           |
| 0x40020000  RESETS           |
| 0x40028000  IO_BANK0         |
| 0x40038000  PADS_BANK0       |
| 0x40048000  XOSC             |
+------------------------------+
| 0xD0000000  SIO              |
+------------------------------+
```

Every peripheral access follows the same steps:

1. `li` the base address into a register
2. Optionally `add` an offset
3. `lw` to read the current value
4. `and`/`or`/`ori`/`andi` to modify bits
5. `sw` to write back

## Alignment Requirements

The Hazard3 core requires word-aligned access for `lw` and `sw`:

| Access | Alignment | Size |
|--------|-----------|------|
| `lw` / `sw` (word) | 4-byte aligned | 32 bits |
| `lh` / `sh` (halfword) | 2-byte aligned | 16 bits |
| `lb` / `sb` (byte) | No alignment | 8 bits |

All peripheral registers in our firmware are at 4-byte-aligned addresses, so word access is always safe.  Misaligned word access on the Hazard3 core generates a load/store address misaligned exception.

## CSR Access

The Hazard3 core has control and status registers (CSRs) accessed via dedicated instructions:

```asm
  csrw  mtvec, t0                                # mtvec = t0
```

`csrw` (CSR Write) is a pseudo-instruction expanding to `csrrw x0, csr, rs1`.  Our firmware uses it in Init_Trap_Vector to set the machine trap vector base address.

CSR instructions are not loads/stores — they use a separate internal bus — but conceptually they are "write a register to a special location."

## Summary

- `lw` and `sw` are the primary memory access instructions, using base+offset addressing.
- The stack is managed explicitly with `addi sp`, `sw`, and `lw` — there are no dedicated push/pop instructions.
- Peripheral registers are accessed at fixed addresses using the read-modify-write pattern.
- CSR instructions (`csrw`) provide access to control and status registers like `mtvec`.
- All word accesses must be 4-byte aligned.
