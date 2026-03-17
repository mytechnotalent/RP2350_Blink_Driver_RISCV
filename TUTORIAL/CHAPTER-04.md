# Chapter 4: What Is a Register?

## Introduction

Registers are the fastest storage locations in the processor.  Every computation passes through them: loading data from memory into a register, operating on it, and storing the result back.  This chapter maps out every register in the Hazard3 RISC-V core and shows exactly how our blink firmware uses them.

## The RISC-V RV32 Register File

The RISC-V base integer ISA defines 32 general-purpose registers, each 32 bits wide:

| Register | ABI Name | Purpose |
|----------|----------|---------|
| x0 | zero | Hardwired to 0 — reads always return 0, writes are ignored |
| x1 | ra | Return address — saved by `call`, used by `ret` |
| x2 | sp | Stack pointer — points to top of stack |
| x3 | gp | Global pointer (unused in our firmware) |
| x4 | tp | Thread pointer (unused in our firmware) |
| x5–x7 | t0–t2 | Temporary registers — caller-saved |
| x8 | s0/fp | Saved register / frame pointer — callee-saved |
| x9 | s1 | Saved register — callee-saved |
| x10–x11 | a0–a1 | Function arguments and return values |
| x12–x17 | a2–a7 | Function arguments |
| x18–x27 | s2–s11 | Saved registers — callee-saved |
| x28–x31 | t3–t6 | Temporary registers — caller-saved |

## Registers t0–t2, t3–t6: Temporaries

The temporary registers are **caller-saved**: a called function may freely overwrite them.  Our firmware uses `t0`, `t1`, and `t2` extensively for loading addresses, reading peripheral values, and computing bit masks:

```asm
  li    t0, XOSC_STARTUP                         # load address into t0
  li    t1, 0x00c4                               # load value into t1
  sw    t1, 0(t0)                                # store t1 at address in t0
```

## Registers a0–a7: Arguments

The `a0`–`a7` registers pass arguments to functions and return values.  In our firmware, `a0` carries the GPIO number or delay value:

```asm
  li    a0, 16                                   # load GPIO number
  call  GPIO_Set                                 # call GPIO_Set(16)
```

## Registers s0–s11: Saved

The saved registers are **callee-saved**: if a function uses them, it must save them on the stack first and restore them before returning.  Our blink firmware primarily uses temporary and argument registers, so the saved registers are not heavily used.

## Register x0 (zero): The Zero Register

The `x0` register always reads as zero.  This is a fundamental RISC-V feature that eliminates the need for special zero-clearing instructions:

```asm
  sw    zero, 0(t0)                              # store 0 to address in t0
```

## Register x1 (ra): Return Address

When `call` (which is `jal ra, offset`) executes, the address of the next instruction is saved in `ra`.  The `ret` pseudo-instruction (`jalr zero, ra, 0`) jumps back to that saved address:

```asm
  call  GPIO_Config                              # ra = return address
  ...
  ret                                            # jump to address in ra
```

## Register x2 (sp): Stack Pointer

The stack pointer tracks the top of the call stack.  Our Init_Stack function sets it to the top of the SRAM stack region:

```asm
  li    sp, STACK_TOP                            # set SP to top of RAM stack
```

Functions that need to save `ra` (non-leaf functions) adjust `sp` to create a stack frame.

## The Program Counter (PC)

The PC is not part of the general register file — it is a special register that holds the address of the current instruction.  It advances by 4 after each 32-bit instruction (or by 2 for compressed instructions).  Branch and jump instructions modify the PC directly.

## Control and Status Registers (CSRs)

RISC-V defines a separate set of **CSRs** for machine-mode control. Our firmware uses:

| CSR | Name | Purpose |
|-----|------|---------|
| mtvec | Machine Trap Vector | Holds the address of the trap handler |
| mstatus | Machine Status | Controls global interrupt enable |

The `csrw` instruction writes a CSR:

```asm
  csrw  mtvec, t0                               # set trap vector to t0
```

## Register Usage in Our Firmware

| Register | How Our Firmware Uses It |
|----------|------------------------|
| t0 | Base address for peripheral registers |
| t1 | Value read from / written to peripheral |
| t2 | Bit masks for set/clear/test operations |
| a0 | GPIO number, delay milliseconds, pad offset |
| a1 | CTRL offset argument |
| a2 | GPIO number for GPIO_Config |
| sp | Stack pointer (set to STACK_TOP) |
| ra | Return address for function calls |

## Summary

- RISC-V has 32 general-purpose registers (x0–x31), each 32 bits wide.
- x0 is hardwired to zero; writes are silently discarded.
- ra (x1) holds the return address; sp (x2) holds the stack pointer.
- Temporary registers (t0–t6) are caller-saved; saved registers (s0–s11) are callee-saved.
- Arguments pass through a0–a7; return values come back in a0–a1.
- CSRs (mtvec, mstatus) control machine-mode behavior.
- Our firmware primarily uses t0–t2, a0–a2, sp, and ra.
