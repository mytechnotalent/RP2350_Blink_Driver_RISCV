# Chapter 11: RISC-V Branch Instructions

## Introduction

Branch instructions alter the flow of execution.  Without branches, the processor would execute instructions sequentially from the reset vector to the end of flash — never looping, never calling a function, never making a decision.  Our blink driver relies on branches for its infinite blink loop, hardware polling, delay counting, and input validation.  This chapter covers every branch instruction in our firmware.

## Unconditional Branches

### `j` — Jump

```asm
  j     .Loop                                    # jump to .Loop forever
```

`j` is a pseudo-instruction that expands to `jal x0, offset`.  By writing to `x0` (the hardwired zero register), the return address is discarded — making this a pure unconditional jump.

In our main.s, the infinite blink loop uses `j`:

```asm
.Loop:
  li    a0, 16                                   # load GPIO number
  call  GPIO_Set                                 # call GPIO_Set
  li    a0, 500                                  # 500ms
  call  Delay_MS                                 # call Delay_MS
  li    a0, 16                                   # load GPIO number
  call  GPIO_Clear                               # call GPIO_Clear
  li    a0, 500                                  # 500ms
  call  Delay_MS                                 # call Delay_MS
  j     .Loop                                    # loop forever
```

The `j .Loop` at the end creates an infinite cycle — the LED blinks until power is removed.

### `j` in Reset_Handler

Reset_Handler uses `j` to branch to main:

```asm
  j     main                                     # branch to main loop
```

This is `j` (not `call`) because main never returns — there is no need to save a return address.

### `j` in Default_Trap_Handler

The trap handler uses `j` to create an infinite loop:

```asm
Default_Trap_Handler:
  j     Default_Trap_Handler                     # lock here on unexpected trap
```

If an unexpected exception occurs, the processor enters this infinite loop rather than executing unpredictable code.

## Conditional Branches

RISC-V conditional branches compare two registers directly — there is no condition flags register.  The processor evaluates the condition and either takes the branch (changing PC) or falls through to the next instruction.

### `beqz` — Branch if Equal to Zero

```asm
  beqz  t1, .GPIO_Subsystem_Reset_Wait           # loop if bit not set
```

`beqz rs1, label` is a pseudo-instruction that expands to `beq rs1, x0, label`.  It branches if the register equals zero.

In reset.s, this polls the RESETS_RESET_DONE register:

```asm
.GPIO_Subsystem_Reset_Wait:
  li    t0, RESETS_RESET_DONE                    # load RESETS->RESET_DONE address
  lw    t1, 0(t0)                                # read RESETS->RESET_DONE value
  andi  t1, t1, (1<<6)                           # test IO_BANK0 reset done
  beqz  t1, .GPIO_Subsystem_Reset_Wait           # wait until done
```

The `andi` isolates bit 6.  If that bit is zero, the result is zero, and `beqz` loops back.  When IO_BANK0 reset completes, bit 6 is set, `andi` produces a non-zero result, and `beqz` falls through.

### `bnez` — Branch if Not Equal to Zero

```asm
  bnez  t1, .Delay_MS_Loop                       # loop until counter reaches 0
```

`bnez rs1, label` is a pseudo-instruction expanding to `bne rs1, x0, label`.  It branches if the register is non-zero.

The delay loop uses this:

```asm
.Delay_MS_Loop:
  addi  t1, t1, -1                               # decrement counter
  bnez  t1, .Delay_MS_Loop                       # branch until zero
```

When `t1` reaches zero, `bnez` falls through, and the delay is complete.

### `bgez` — Branch if Greater or Equal to Zero

```asm
  bgez  t1, .Init_XOSC_Wait                      # loop if bit 31 is clear
```

`bgez rs1, label` is a pseudo-instruction expanding to `bge rs1, x0, label`.  It branches if the register is >= 0 (when interpreted as a signed integer, meaning bit 31 is clear).

In xosc.s, this polls the XOSC_STATUS register:

```asm
.Init_XOSC_Wait:
  li    t0, XOSC_STATUS                          # load XOSC_STATUS address
  lw    t1, 0(t0)                                # read XOSC_STATUS value
  bgez  t1, .Init_XOSC_Wait                      # bit31 clear -> still unstable
```

The STABLE bit is bit 31.  When bit 31 is clear, the 32-bit value interpreted as signed is >= 0, so `bgez` loops.  When XOSC becomes stable, bit 31 is set, making the value negative (signed), so `bgez` falls through.

This is an elegant trick: testing the sign bit of a register is equivalent to testing the most significant bit — no mask or shift needed.

### `blez` — Branch if Less or Equal to Zero

```asm
  blez  a0, .Delay_MS_Done                       # if ms <= 0, skip
```

`blez rs1, label` is a pseudo-instruction expanding to `bge x0, rs1, label`.  It branches if the register is <= 0.

In delay.s, it validates the input parameter:

```asm
  blez  a0, .Delay_MS_Done                       # if MS is not valid, return
```

This guards against zero or negative delay values that would produce incorrect behavior.

## Base Branch Instructions

The pseudo-instructions above expand to these base instructions:

| Base Instruction | Meaning | Pseudo-Instructions Using It |
|------------------|---------|------------------------------|
| `beq rs1, rs2, offset` | Branch if rs1 == rs2 | `beqz rs1, label` (rs2 = x0) |
| `bne rs1, rs2, offset` | Branch if rs1 != rs2 | `bnez rs1, label` (rs2 = x0) |
| `bge rs1, rs2, offset` | Branch if rs1 >= rs2 (signed) | `bgez rs1, label` (rs2 = x0), `blez rs2, label` (rs1 = x0) |
| `blt rs1, rs2, offset` | Branch if rs1 < rs2 (signed) | `bltz rs1, label` (rs2 = x0) |
| `bgeu rs1, rs2, offset` | Branch if rs1 >= rs2 (unsigned) | — |
| `bltu rs1, rs2, offset` | Branch if rs1 < rs2 (unsigned) | — |

All use B-type encoding with a 13-bit signed offset (range: ±4 KB from the branch instruction).

## Branch Encoding and Range

| Instruction | Encoding | Range |
|-------------|----------|-------|
| `beq`/`bne`/`bge`/`blt` | B-type (32-bit) | ±4 KB |
| `c.beqz`/`c.bnez` | Compressed (16-bit) | ±256 bytes |
| `jal` | J-type (32-bit) | ±1 MB |
| `c.j` | Compressed (16-bit) | ±2 KB |

If a branch target is beyond ±4 KB, the assembler must use an indirect technique (load address + `jalr`).  Our firmware is small enough that all branches are within range.

## Polling Loops

Our firmware contains two hardware-polling loops:

**XOSC Stabilization (xosc.s):**

```
  lw → bgez → lw → bgez → ... → lw (bit set) → fall through
```

**Reset Completion (reset.s):**

```
  lw → andi → beqz → lw → andi → beqz → ... → (bit set) → fall through
```

Both poll a status register bit until hardware signals readiness.  This is "busy waiting" — appropriate for bare-metal firmware where no operating system scheduler exists.

## Contrast with ARM

| Feature | ARM | RISC-V |
|---------|-----|--------|
| Condition mechanism | APSR flags (N,Z,C,V) | Direct register comparison |
| Flag-setting | `subs`, `tst`, `cmp` set flags | No flags — branches compare directly |
| Unconditional jump | `b label` | `j label` (pseudo for `jal x0, label`) |
| Function call | `bl label` | `call label` (pseudo for `auipc`+`jalr`) |
| Return | `bx lr` | `ret` (pseudo for `jalr x0, 0(ra)`) |

## Summary

- `j` provides unconditional jumps: our infinite blink loop and Reset_Handler → main transition.
- `beqz` and `bnez` branch based on zero/non-zero register comparison — used for polling and delay loops.
- `bgez` exploits the sign bit to test bit 31 of XOSC_STATUS.
- `blez` validates delay input by testing if ms <= 0.
- RISC-V branches compare registers directly — there are no condition flags.
- All pseudo-branch instructions expand to base B-type instructions comparing against `x0`.
