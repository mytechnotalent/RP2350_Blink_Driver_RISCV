# Chapter 13: RISC-V Pseudo-Instructions

## Introduction

Pseudo-instructions are convenience mnemonics that the assembler translates into one or more real machine instructions.  They make assembly code more readable without adding new hardware features.  RISC-V relies heavily on pseudo-instructions because the base ISA is deliberately minimal — many common patterns require specific register choices or instruction combinations that pseudo-instructions abstract away.  This chapter catalogs every pseudo-instruction used in our blink driver.

## `li` — Load Immediate

```asm
  li    t0, XOSC_STARTUP                         # load XOSC_STARTUP address
```

`li` loads an arbitrary 32-bit constant into a register.  The assembler chooses the shortest expansion:

| Value Range | Expansion | Instructions |
|-------------|-----------|-------------|
| -2048 to 2047 | `addi rd, x0, imm` | 1 |
| Upper 20 bits only (lower 12 = 0) | `lui rd, imm20` | 1 |
| Arbitrary 32-bit | `lui rd, upper20` + `addi rd, rd, lower12` | 2 |

Examples from our firmware:

```asm
  li    a2, 16                                   # addi a2, x0, 16
  li    t0, 3600                                 # lui t0, 1 + addi t0, t0, -496
  li    t0, XOSC_BASE                            # lui t0, 0x40048 + addi t0, t0, 0
  li    t1, 0x00FABAA0                           # lui t1, upper + addi t1, t1, lower
```

`li` is the most frequently used pseudo-instruction in our firmware — it appears in every source file.

## `la` — Load Address

```asm
  la    t0, Default_Trap_Handler                 # trap target
```

`la` loads the address of a symbol using PC-relative addressing.  It expands to:

```
auipc  t0, %pcrel_hi(Default_Trap_Handler)
addi   t0, t0, %pcrel_lo(Default_Trap_Handler)
```

Unlike `li`, which encodes an absolute value, `la` computes the address relative to the current PC.  Our firmware uses `la` in Init_Trap_Vector to load the trap handler address.

## `call` — Function Call

```asm
  call  GPIO_Config                              # call GPIO_Config
```

`call` performs a function call by saving the return address in `ra` and jumping to the target.  It expands to:

```
auipc  ra, %pcrel_hi(GPIO_Config)
jalr   ra, %pcrel_lo(GPIO_Config)(ra)
```

For nearby targets (within ±1 MB), the assembler may optimize to a single `jal ra, offset`.

Every function invocation in our firmware uses `call`:

| Caller | Target | File |
|--------|--------|------|
| Reset_Handler | Init_Stack | reset_handler.s |
| Reset_Handler | Init_Trap_Vector | reset_handler.s |
| Reset_Handler | Init_XOSC | reset_handler.s |
| Reset_Handler | Enable_XOSC_Peri_Clock | reset_handler.s |
| Reset_Handler | Init_Subsystem | reset_handler.s |
| Reset_Handler | Enable_Coprocessor | reset_handler.s |
| main | GPIO_Config | main.s |
| main | GPIO_Set | main.s |
| main | GPIO_Clear | main.s |
| main | Delay_MS | main.s |

## `ret` — Return from Function

```asm
  ret                                            # return to caller
```

`ret` returns to the caller by jumping to the address in `ra`.  It expands to:

```
jalr  x0, 0(ra)
```

Writing to `x0` discards the link — this is a pure jump, not a call.  Every function in our firmware ends with `ret`.

## `j` — Unconditional Jump

```asm
  j     .Loop                                    # loop forever
```

`j` performs an unconditional jump without saving a return address.  It expands to:

```
jal  x0, offset
```

Our firmware uses `j` in three places:

1. `j .Loop` in main.s — the infinite blink loop
2. `j main` in reset_handler.s — entering main (no return needed)
3. `j Default_Trap_Handler` — infinite loop in the trap handler

## `not` — Bitwise NOT

```asm
  not   t2, t2                                   # t2 = ~t2
```

`not` inverts all bits of a register.  It expands to:

```
xori  t2, t2, -1
```

Since -1 in two's complement is `0xFFFFFFFF`, XOR with -1 flips every bit.

In reset.s, `not` creates a clear mask:

```asm
  li    t2, (1<<6)                               # IO_BANK0 reset mask
  not   t2, t2                                   # invert: 0xFFFFFFBF
  and   t1, t1, t2                               # clear IO_BANK0 bit
```

## Branch Pseudo-Instructions

### `beqz` — Branch if Zero

```asm
  beqz  t1, .GPIO_Subsystem_Reset_Wait           # loop if bit not set
```

Expands to `beq t1, x0, label`.

### `bnez` — Branch if Not Zero

```asm
  bnez  t1, .Delay_MS_Loop                       # loop until counter reaches 0
```

Expands to `bne t1, x0, label`.

### `bgez` — Branch if Greater or Equal to Zero

```asm
  bgez  t1, .Init_XOSC_Wait                      # loop if bit 31 is clear
```

Expands to `bge t1, x0, label`.

### `blez` — Branch if Less or Equal to Zero

```asm
  blez  a0, .Delay_MS_Done                       # if ms <= 0, skip
```

Expands to `bge x0, a0, label`.  Note the operand swap: the base instruction tests `x0 >= a0`, which is equivalent to `a0 <= 0`.

## CSR Pseudo-Instructions

### `csrw` — Write CSR

```asm
  csrw  mtvec, t0                                # mtvec = t0
```

Expands to `csrrw x0, mtvec, t0`.  The `csrrw` instruction atomically swaps the CSR value with the register, but by writing to `x0` the old value is discarded — making this a pure write.

Our firmware uses `csrw` once, in Init_Trap_Vector, to set the machine trap vector.

## Complete Pseudo-Instruction Reference

| Pseudo-instruction | Expansion | Used In |
|--------------------|-----------|---------|
| `li rd, imm` | `lui`+`addi` or `addi` | All files |
| `la rd, symbol` | `auipc`+`addi` | reset_handler.s |
| `call label` | `auipc ra`+`jalr ra` | reset_handler.s, main.s |
| `ret` | `jalr x0, 0(ra)` | All functions |
| `j label` | `jal x0, offset` | main.s, reset_handler.s |
| `not rd, rs` | `xori rd, rs, -1` | reset.s |
| `beqz rs, label` | `beq rs, x0, label` | reset.s |
| `bnez rs, label` | `bne rs, x0, label` | delay.s |
| `bgez rs, label` | `bge rs, x0, label` | xosc.s |
| `blez rs, label` | `bge x0, rs, label` | delay.s |
| `csrw csr, rs` | `csrrw x0, csr, rs` | reset_handler.s |

## Why Pseudo-Instructions Matter

Without pseudo-instructions, the programmer would need to write:

```
lui   t0, %hi(0x40048000)
addi  t0, t0, %lo(0x40048000)
```

instead of:

```asm
  li    t0, XOSC_BASE                            # load XOSC base address
```

And:

```
auipc ra, %pcrel_hi(GPIO_Set)
jalr  ra, %pcrel_lo(GPIO_Set)(ra)
```

instead of:

```asm
  call  GPIO_Set                                 # call GPIO_Set
```

Pseudo-instructions keep the source readable while the assembler generates optimal machine code.

## Summary

- `li` and `la` load constants and addresses — the most common pseudo-instructions.
- `call` and `ret` implement function call and return using `ra`.
- `j` provides unconditional jumps without saving a return address.
- `not` inverts all bits via XOR with -1.
- Branch pseudo-instructions (`beqz`, `bnez`, `bgez`, `blez`) compare against `x0`.
- `csrw` writes control/status registers.
- Pseudo-instructions make RISC-V assembly readable while expanding to optimal base instructions.
