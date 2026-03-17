# Chapter 6: The Fetch-Decode-Execute Cycle in Detail

## Introduction

Chapter 1 introduced the fetch-decode-execute cycle as a three-step loop.  This chapter goes deeper: we examine the pipeline, see a concrete instruction trace from our firmware, and understand how branches disrupt sequential flow.

## The Three Stages

Every instruction passes through three stages:

1. **Fetch** — the processor reads the instruction bytes from the address stored in the PC.  On the Hazard3 core, a 32-bit instruction is 4 bytes; a compressed (C-extension) instruction is 2 bytes.
2. **Decode** — the processor extracts the opcode, identifies source registers, destination register, and any immediate value from the binary encoding.
3. **Execute** — the processor performs the operation: arithmetic, memory access, branch target calculation, or CSR update.

## The Pipeline

The Hazard3 core uses a multi-stage pipeline so that while one instruction is executing, the next is being decoded, and the one after that is being fetched.  In the ideal case, one instruction completes every clock cycle:

```
Clock:  1     2     3     4     5     6
        +-----+-----+-----+-----+-----+
Instr1: | F   | D   | E   |     |     |
Instr2: |     | F   | D   | E   |     |
Instr3: |     |     | F   | D   | E   |
        +-----+-----+-----+-----+-----+
```

F = Fetch, D = Decode, E = Execute.

## A Concrete Example

Consider these three consecutive instructions from our XOSC initialization:

```asm
  li    t0, XOSC_STARTUP                         # load XOSC_STARTUP address
  li    t1, 0x00c4                               # set delay 50,000 cycles
  sw    t1, 0(t0)                                # store value into XOSC_STARTUP
```

The pipeline processes them as:

| Clock | Fetch | Decode | Execute |
|-------|-------|--------|---------|
| 1 | `li t0, ...` | — | — |
| 2 | `li t1, ...` | `li t0, ...` | — |
| 3 | `sw t1, ...` | `li t1, ...` | `li t0, ...` → t0 loaded |
| 4 | next instr | `sw t1, ...` | `li t1, ...` → t1 loaded |
| 5 | ... | next instr | `sw t1, ...` → memory write |

The sequential ordering means `t0` is ready before the `sw` needs it.

## How Branch Instructions Affect the Pipeline

When the processor encounters a branch instruction, it may not know the next PC until the execute stage.  If the branch is taken, instructions that were already fetched after the branch are incorrect and must be discarded — this is called a **pipeline flush**.

```asm
  bnez  t1, .Delay_MS_Loop                      # branch until zero
```

If `t1` is not zero, the pipeline is flushed: the instruction after `bnez` that was already fetched is discarded, and the pipeline restarts at `.Delay_MS_Loop`.  For our tight delay loop (3,600 × ms iterations), this flush happens on every iteration except the last.

## The Hazard3 Execution Model

The Hazard3 core in the RP2350 is a simple in-order pipeline.  Key characteristics:

- Instructions execute in program order — no out-of-order execution.
- Branch penalties are small (1–2 cycles for the flush).
- Memory operations on the peripheral bus may stall the pipeline while the bus transaction completes.
- The C extension (compressed instructions) allows some instructions to be only 2 bytes, improving code density.

## Clock Speed

After our firmware configures XOSC, the Hazard3 core runs at 12 MHz (the XOSC crystal frequency; PLL is not configured in this project).  Each clock cycle is approximately 83 ns.  A peripheral register write may take several cycles due to the APB bus bridge.

Our delay loop calibration (3,600 iterations per millisecond) accounts for the actual instruction throughput at XOSC speed.

## Summary

- The fetch-decode-execute cycle is pipelined: multiple instructions are in-flight simultaneously.
- Sequential instructions flow smoothly through the pipeline.
- Branches cause pipeline flushes: the processor discards incorrectly fetched instructions.
- The Hazard3 core executes in order with small branch penalties.
- At 12 MHz (XOSC), each cycle is approximately 83 ns.
