# Chapter 12: RISC-V Jumps, Calls, and Returns

## Introduction

Structured software is built from functions that call other functions.  RISC-V implements calls with `jal`/`jalr` (jump and link / jump and link register) and returns with `ret`.  When functions are nested — a caller invokes a callee that invokes yet another callee — the return address register must be saved to the stack.  This chapter examines how calls, returns, and the stack frame work together in our blink driver.

## The Return Address Register

When `jal` or `jalr` executes, the processor stores the address of the next instruction in the destination register.  By convention, this is `ra` (x1):

```
Before call:
  PC = 0x10000100   (call GPIO_Set instruction)
  ra = (previous)

After call:
  PC = GPIO_Set     (target address)
  ra = 0x10000108   (return address, next instruction)
```

The callee returns by executing `ret`, which loads `ra` back into PC.

## `jal` — Jump and Link

```
jal   rd, offset
```

`jal` stores PC+4 in `rd` and jumps to PC+offset.  The J-type encoding provides a 21-bit signed offset (±1 MB range).

When `rd` is `ra` (x1), this is a function call.  When `rd` is `x0`, the return address is discarded — this becomes an unconditional jump (`j`).

## `jalr` — Jump and Link Register

```
jalr  rd, offset(rs1)
```

`jalr` stores PC+4 in `rd` and jumps to rs1+offset.  This enables indirect jumps and calls to addresses computed at runtime.

## The `call` Pseudo-Instruction

The assembler provides `call` to abstract the details.  The programmer writes:

```asm
  call  GPIO_Config                              # call GPIO_Config
```

The assembler expands this to:

```
auipc  ra, %pcrel_hi(GPIO_Config)
jalr   ra, %pcrel_lo(GPIO_Config)(ra)
```

The `auipc` loads the upper portion of the PC-relative offset into `ra`, and `jalr` adds the lower portion and jumps.  The net effect: `ra` = return address, PC = GPIO_Config.

For nearby targets, the assembler may optimize to a single `jal ra, offset` if the target is within ±1 MB.

## The `ret` Pseudo-Instruction

`ret` is a pseudo-instruction for returning from a function:

```asm
  ret                                            # return to caller
```

It expands to:

```
jalr  x0, 0(ra)
```

This jumps to the address in `ra` and discards the link (writes to `x0`).  Execution resumes at the instruction after the original `call`.

## Leaf Functions vs. Non-Leaf Functions

A **leaf function** does not call any other function.  It can use `ra` directly without saving it:

```asm
Init_Stack:
  li    sp, STACK_TOP                            # set SP to top of RAM stack
  ret                                            # return (ra preserved)
```

Init_Stack is a leaf — it contains no `call` instruction, so `ra` remains valid throughout.

A **non-leaf function** calls other functions, which overwrites `ra`.  It must save `ra` on entry and restore it on exit:

```asm
GPIO_Config:
  addi  sp, sp, -4                               # allocate stack frame
  sw    ra, 0(sp)                                # save return address
  ...                                            # function body (no calls here,
  ...                                            #   but structure supports them)
  lw    ra, 0(sp)                                # restore return address
  addi  sp, sp, 4                                # deallocate stack frame
  ret                                            # return to caller
```

GPIO_Config saves `ra` because it is called from `main` (which needs `ra` preserved for its own return path, though main never actually returns).

## The Call Chain

Our blink driver has this call hierarchy:

```
Reset_Handler
  +-- Init_Stack          (leaf)
  +-- Init_Trap_Vector    (leaf)
  +-- Init_XOSC           (leaf)
  +-- Enable_XOSC_Peri_Clock  (leaf)
  +-- Init_Subsystem      (leaf)
  +-- Enable_Coprocessor  (leaf)
  +-- main                (non-leaf, never returns)
        +-- GPIO_Config   (saves ra)
        +-- GPIO_Set      (leaf)
        +-- Delay_MS      (leaf)
        +-- GPIO_Clear    (leaf)
```

Reset_Handler uses `call` to invoke each initialization function and then `j main` (jump, not call) because main never returns.

## The Stack Frame

When GPIO_Config executes `addi sp, sp, -4` and `sw ra, 0(sp)`, the stack looks like:

```
High addresses (STACK_TOP = 0x20082000)
+------------------+
|                  |
+------------------+
| ra               |  SP + 0   <-- SP after push
+------------------+
Low addresses
```

When the function returns, `lw ra, 0(sp)` and `addi sp, sp, 4` restore `ra` and advance SP back.

### Larger Stack Frames

If a function needs to save multiple registers (e.g., `ra`, `s0`, `s1`):

```asm
  addi  sp, sp, -12                              # allocate 12 bytes
  sw    ra, 8(sp)                                # save ra
  sw    s0, 4(sp)                                # save s0
  sw    s1, 0(sp)                                # save s1
  ...
  lw    s1, 0(sp)                                # restore s1
  lw    s0, 4(sp)                                # restore s0
  lw    ra, 8(sp)                                # restore ra
  addi  sp, sp, 12                               # deallocate
  ret                                            # return
```

Our firmware only needs to save `ra` (4 bytes), keeping the frame minimal.

## The RISC-V Calling Convention

Our firmware follows the RISC-V standard calling convention:

| Register | ABI Name | Role | Caller/Callee Saved |
|----------|----------|------|-------------------|
| x0 | zero | Hardwired zero | — |
| x1 | ra | Return address | Caller-saved |
| x2 | sp | Stack pointer | Callee-saved |
| x5–x7 | t0–t2 | Temporaries | Caller-saved |
| x10–x11 | a0–a1 | Arguments / return values | Caller-saved |
| x12–x17 | a2–a7 | Arguments | Caller-saved |
| x8–x9 | s0–s1 | Saved registers | Callee-saved |
| x18–x27 | s2–s11 | Saved registers | Callee-saved |
| x28–x31 | t3–t6 | Temporaries | Caller-saved |

Our functions demonstrate this convention:

- `main` passes GPIO number in `a0` and delay milliseconds in `a0`
- `GPIO_Config` receives pad offset (`a0`), ctrl offset (`a1`), GPIO number (`a2`)
- `GPIO_Set` and `GPIO_Clear` receive GPIO number in `a0`
- `Delay_MS` receives milliseconds in `a0`

Temporary registers `t0`–`t2` are used for scratch computation within each function.

## Parameter Passing Example

When main calls GPIO_Config:

```asm
  li    a0, PADS_BANK0_GPIO16_OFFSET             # a0 = pad offset
  li    a1, IO_BANK0_GPIO16_CTRL_OFFSET          # a1 = ctrl offset
  li    a2, 16                                   # a2 = GPIO number
  call  GPIO_Config                              # call
```

The callee receives these in `a0`, `a1`, `a2` with no additional mechanism needed.

When main calls GPIO_Set:

```asm
  li    a0, 16                                   # a0 = GPIO number
  call  GPIO_Set                                 # call
```

## Reset_Handler: A Special Case

Reset_Handler never returns.  It calls initialization functions with `call` and then jumps to main with `j` (not `call`):

```asm
Reset_Handler:
  call  Init_Stack                               # returns via ret
  call  Init_Trap_Vector                         # returns via ret
  call  Init_XOSC                                # returns via ret
  call  Enable_XOSC_Peri_Clock                   # returns via ret
  call  Init_Subsystem                           # returns via ret
  call  Enable_Coprocessor                       # returns via ret
  j     main                                     # never returns
```

Using `j` instead of `call` means `ra` still holds the return address from the last `call` — but since main contains an infinite loop, this is irrelevant.  The system never returns past main.

## Contrast with ARM

| Feature | ARM | RISC-V |
|---------|-----|--------|
| Call | `bl label` | `call label` (`auipc`+`jalr`) |
| Return | `bx lr` | `ret` (`jalr x0, 0(ra)`) |
| Return address register | `lr` (r14) | `ra` (x1) |
| Save registers | `push {r4-r12, lr}` | `addi sp` + multiple `sw` |
| Restore registers | `pop {r4-r12, lr}` | Multiple `lw` + `addi sp` |
| Argument registers | r0–r3 | a0–a7 |
| Callee-saved | r4–r11 | s0–s11 |

## Summary

- `call` saves the return address in `ra` and jumps to the target function.
- `ret` returns to the caller by jumping to the address in `ra`.
- Non-leaf functions save `ra` with `sw ra, 0(sp)` and restore it with `lw ra, 0(sp)`.
- The stack grows downward; each function creates a frame for its saved registers.
- The RISC-V calling convention uses `a0`–`a7` for arguments and `s0`–`s11` as callee-saved.
- Reset_Handler uses `j main` (not `call`) because the system never returns.
