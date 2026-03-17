# Chapter 15: Calling Convention and Stack Frames

## Introduction

When one function calls another, both must agree on where arguments go, which registers are preserved, and how the stack is managed.  These rules form the **calling convention**.  RISC-V defines a standard calling convention in its ABI specification, and our blink driver follows it precisely.  This chapter examines how arguments are passed, how functions save and restore state, and how the stack frame is structured.

## The RISC-V Calling Convention

### Register Roles

| Register | ABI Name | Role | Saver |
|----------|----------|------|-------|
| x0 | zero | Hardwired zero | — |
| x1 | ra | Return address | Caller |
| x2 | sp | Stack pointer | Callee |
| x3 | gp | Global pointer | — |
| x4 | tp | Thread pointer | — |
| x5–x7 | t0–t2 | Temporaries | Caller |
| x8 | s0/fp | Saved register / frame pointer | Callee |
| x9 | s1 | Saved register | Callee |
| x10–x11 | a0–a1 | Arguments / return values | Caller |
| x12–x17 | a2–a7 | Arguments | Caller |
| x18–x27 | s2–s11 | Saved registers | Callee |
| x28–x31 | t3–t6 | Temporaries | Caller |

### Key Rules

1. **Arguments** are passed in `a0`–`a7` (up to 8 registers).  Our functions use `a0`–`a2`.
2. **Return values** are placed in `a0`–`a1`.
3. **Caller-saved** registers (`t0`–`t6`, `a0`–`a7`, `ra`) may be overwritten by the callee.  The caller must save them if needed after the call.
4. **Callee-saved** registers (`s0`–`s11`, `sp`) must be preserved by the callee.  If a function modifies them, it must save and restore them.
5. **The stack pointer** (`sp`) must be restored to its original value before returning.

## Parameter Passing in Our Firmware

### GPIO_Config: Three Parameters

```asm
  li    a0, PADS_BANK0_GPIO16_OFFSET             # a0 = pad offset
  li    a1, IO_BANK0_GPIO16_CTRL_OFFSET          # a1 = ctrl offset
  li    a2, 16                                   # a2 = GPIO number
  call  GPIO_Config                              # call
```

The callee receives `a0` = 0x44, `a1` = 0x84, `a2` = 16 — no memory access needed.

### GPIO_Set / GPIO_Clear: One Parameter

```asm
  li    a0, 16                                   # a0 = GPIO number
  call  GPIO_Set                                 # call
```

### Delay_MS: One Parameter

```asm
  li    a0, 500                                  # a0 = milliseconds
  call  Delay_MS                                 # call
```

## Leaf Functions

A leaf function calls no other functions.  Since `ra` is never overwritten, there is no need to save it:

```asm
Init_Stack:
  li    sp, STACK_TOP                            # set SP to top of RAM stack
  ret                                            # return (ra preserved)
```

```asm
GPIO_Set:
  li    t0, SIO_GPIO_OUT_SET                     # load SIO GPIO_OUT_SET address
  li    t1, 1                                    # bit value
  sll   t1, t1, a0                               # shift to GPIO position
  sw    t1, 0(t0)                                # set GPIO output high
  ret                                            # return
```

These functions use only `t0`–`t2` and `a0`–`a2` (caller-saved), so they have no callee-save obligations.

Leaf functions in our firmware:

| Function | File | Registers Used |
|----------|------|---------------|
| Init_Stack | stack.s | sp |
| Init_Trap_Vector | reset_handler.s | t0 |
| Init_XOSC | xosc.s | t0, t1 |
| Enable_XOSC_Peri_Clock | xosc.s | t0, t1, t2 |
| Init_Subsystem | reset.s | t0, t1, t2 |
| Enable_Coprocessor | coprocessor.s | (none) |
| GPIO_Set | gpio.s | t0, t1, a0 |
| GPIO_Clear | gpio.s | t0, t1, a0 |
| Delay_MS | delay.s | t0, t1, a0 |

## Non-Leaf Functions

A non-leaf function calls other functions and must save `ra`:

```asm
GPIO_Config:
  addi  sp, sp, -4                               # allocate stack frame
  sw    ra, 0(sp)                                # save return address
  ...                                            # function body
  lw    ra, 0(sp)                                # restore return address
  addi  sp, sp, 4                                # deallocate stack frame
  ret                                            # return to caller
```

GPIO_Config is treated as a non-leaf because it is called from main and preserves the ability to call sub-functions.

## The Stack Frame

### Allocation

```asm
  addi  sp, sp, -4                               # sp = sp - 4
```

The stack grows downward (toward lower addresses).  Subtracting from `sp` allocates space.

### Save

```asm
  sw    ra, 0(sp)                                # memory[sp] = ra
```

The return address is stored at the top of the new frame.

### Restore

```asm
  lw    ra, 0(sp)                                # ra = memory[sp]
```

The return address is loaded back.

### Deallocation

```asm
  addi  sp, sp, 4                                # sp = sp + 4
```

The frame is removed by adding back the same amount.

### Stack Layout

```
High addresses (STACK_TOP = 0x20082000)
+------------------+
|                  |
+------------------+
| ra               |  SP + 0   <-- SP (after frame allocation)
+------------------+
Low addresses
```

For a larger frame saving multiple registers:

```
+------------------+
| ra               |  SP + 8
| s0               |  SP + 4
| s1               |  SP + 0   <-- SP
+------------------+
```

Our firmware only needs a 4-byte frame (just `ra`), keeping the stack usage minimal.

## The main Function

`main` is effectively a non-leaf function (it calls GPIO_Config, GPIO_Set, GPIO_Clear, Delay_MS), but it never returns — it contains an infinite loop:

```asm
main:
.GPIO16_Config:
  li    a0, PADS_BANK0_GPIO16_OFFSET             # load pad offset
  li    a1, IO_BANK0_GPIO16_CTRL_OFFSET          # load ctrl offset
  li    a2, 16                                   # load GPIO number
  call  GPIO_Config                              # configure GPIO16
.Loop:
  li    a0, 16                                   # GPIO number
  call  GPIO_Set                                 # LED on
  li    a0, 500                                  # 500ms
  call  Delay_MS                                 # wait
  li    a0, 16                                   # GPIO number
  call  GPIO_Clear                               # LED off
  li    a0, 500                                  # 500ms
  call  Delay_MS                                 # wait
  j     .Loop                                    # repeat forever
```

Since the `j .Loop` ensures main never reaches `ret`, there is no need to save `ra` — it would never be restored.

## Reset_Handler: The Root

Reset_Handler is the root of the call chain.  It uses `call` for initialization functions and `j` for main:

```asm
Reset_Handler:
  call  Init_Stack                               # leaf
  call  Init_Trap_Vector                         # leaf
  call  Init_XOSC                                # leaf
  call  Enable_XOSC_Peri_Clock                   # leaf
  call  Init_Subsystem                           # leaf
  call  Enable_Coprocessor                       # leaf
  j     main                                     # never returns
```

Each `call` overwrites `ra`.  This is safe because Reset_Handler calls them sequentially and never needs to return — there is no caller above Reset_Handler.

## Contrast with ARM

| Feature | ARM | RISC-V |
|---------|-----|--------|
| Save/restore | `push {r4-r12, lr}` / `pop {r4-r12, lr}` | `addi sp` + `sw` / `lw` + `addi sp` |
| Arguments | r0–r3 | a0–a7 |
| Return address | lr (r14) | ra (x1) |
| Callee-saved | r4–r11 | s0–s11 |
| Stack alignment | 8-byte (AAPCS) | 16-byte (RISC-V ABI, relaxed for embedded) |

ARM's `push`/`pop` save multiple registers in one instruction.  RISC-V requires explicit `sw`/`lw` for each register — more verbose but conceptually simpler.

## Summary

- Arguments pass in `a0`–`a7`; return values in `a0`–`a1`.
- Leaf functions (no calls) need not save `ra`.
- Non-leaf functions save `ra` to the stack with `sw ra, 0(sp)` and restore with `lw ra, 0(sp)`.
- The stack grows downward; `addi sp, sp, -N` allocates, `addi sp, sp, N` deallocates.
- Temporary registers (`t0`–`t6`) are caller-saved — free to use without saving.
- Saved registers (`s0`–`s11`) are callee-saved — must be preserved if used.
