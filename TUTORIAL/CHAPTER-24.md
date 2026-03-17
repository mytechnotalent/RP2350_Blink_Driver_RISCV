# Chapter 24: Boot Sequence — `reset_handler.s`

## Introduction

`reset_handler.s` is the first code that runs after the boot ROM transfers control to our firmware.  It orchestrates the entire hardware bring-up sequence: stack setup, trap vector installation, oscillator init, clock enable, subsystem release, and finally the jump to `main`.  This chapter walks through every instruction and explains the design decisions that shape the boot sequence.

## Full Source

```asm
.include "constants.s"

.section .text                                   # code section
.align 2                                         # align to 4-byte boundary

.global Reset_Handler                            # export Reset_Handler symbol
.type Reset_Handler, @function
Reset_Handler:
  call  Init_Stack                               # initialize SP
  call  Init_Trap_Vector                         # install trap vector
  call  Init_XOSC                                # initialize external crystal oscillator
  call  Enable_XOSC_Peri_Clock                   # enable XOSC peripheral clock
  call  Init_Subsystem                           # initialize subsystems
  call  Enable_Coprocessor                       # no-op on RISC-V (kept for parity)
  j     main                                     # branch to main loop
.size Reset_Handler, . - Reset_Handler

.global Default_Trap_Handler
.type Default_Trap_Handler, @function
Default_Trap_Handler:
  j     Default_Trap_Handler                     # lock here on unexpected trap

.global Init_Trap_Vector
.type Init_Trap_Vector, @function
Init_Trap_Vector:
  la    t0, Default_Trap_Handler                 # trap target
  csrw  mtvec, t0                                # mtvec = trap entry
  ret                                            # return
```

## The Boot Call Chain

```
Reset_Handler
  ├── call Init_Stack          → stack.s
  ├── call Init_Trap_Vector    → reset_handler.s (below)
  ├── call Init_XOSC           → xosc.s
  ├── call Enable_XOSC_Peri_Clock → xosc.s
  ├── call Init_Subsystem      → reset.s
  ├── call Enable_Coprocessor  → coprocessor.s (no-op)
  └── j    main                → main.s
```

Each `call` pushes the return address onto the link register (`ra`), executes the function, and returns via `ret` (which is `jalr x0, ra, 0`).  Because `Reset_Handler` itself is the entry point — never called from another function — it never needs to save `ra`.

## Reset_Handler — Line by Line

### Function Declaration

```asm
.global Reset_Handler                            # export Reset_Handler symbol
.type Reset_Handler, @function
```

`.global` makes `Reset_Handler` visible to the linker.  The `image_def.s` file references this symbol as the entry point, and the linker resolves it to an absolute flash address.

### Step 1: Stack Initialization

```asm
  call  Init_Stack                               # initialize SP
```

This must be first.  Every subsequent `call` uses the stack (the `call` pseudo-instruction itself writes to `ra`, and functions that save `ra` need a valid `sp`).  `Init_Stack` loads `sp` with `STACK_TOP` (`0x20082000`).

### Step 2: Trap Vector Setup

```asm
  call  Init_Trap_Vector                         # install trap vector
```

Installs our trap handler in the `mtvec` CSR.  This must happen early — if any subsequent initialization triggers an unexpected exception (illegal instruction, misaligned access), the trap handler catches it instead of executing from an undefined address.

### Step 3: Crystal Oscillator

```asm
  call  Init_XOSC                                # initialize external crystal oscillator
```

Configures the external 12 MHz crystal oscillator.  After this call, the XOSC is stable and running.

### Step 4: Peripheral Clock

```asm
  call  Enable_XOSC_Peri_Clock                   # enable XOSC peripheral clock
```

Routes the XOSC output to the peripheral clock, which drives the APB bus and all peripherals we will configure.

### Step 5: Subsystem Release

```asm
  call  Init_Subsystem                           # initialize subsystems
```

Releases IO_BANK0 from reset.  GPIO pins cannot be configured until their peripheral is released.

### Step 6: Coprocessor (No-Op)

```asm
  call  Enable_Coprocessor                       # no-op on RISC-V (kept for parity)
```

On ARM, this enables coprocessor 0 access via CPACR.  On RISC-V, there is no coprocessor — SIO access uses memory-mapped registers.  The function is a single `ret` instruction, kept for project structure parity with the ARM variant.

### Step 7: Jump to Main

```asm
  j     main                                     # branch to main loop
```

`j main` is a `jal x0, offset` — an unconditional jump that discards the return address (writes to `x0`, the zero register).  This is intentional: `main` contains an infinite loop and never returns.  Using `j` instead of `call` makes this explicit and avoids pushing an unnecessary return address.

### Size Directive

```asm
.size Reset_Handler, . - Reset_Handler
```

This tells the linker and debugger the exact byte size of `Reset_Handler`.  The `.` (current position) minus the label gives the function's length.

## Why This Order?

The call sequence follows a strict dependency chain:

| Step | Function | Depends On |
|------|----------|------------|
| 1 | `Init_Stack` | Nothing (first thing) |
| 2 | `Init_Trap_Vector` | Stack (for `ret`) |
| 3 | `Init_XOSC` | Stack, trap handler |
| 4 | `Enable_XOSC_Peri_Clock` | XOSC running |
| 5 | `Init_Subsystem` | Peripheral clock |
| 6 | `Enable_Coprocessor` | (no dependency, kept for parity) |
| 7 | `j main` | All init complete |

Swapping any two steps would either crash (no stack), lose exceptions (no trap handler), or fail silently (clock not running when peripheral needs it).

## Default_Trap_Handler

```asm
.global Default_Trap_Handler
.type Default_Trap_Handler, @function
Default_Trap_Handler:
  j     Default_Trap_Handler                     # lock here on unexpected trap
```

This is an infinite loop — if any trap fires (illegal instruction, misaligned access, unhandled interrupt), the CPU locks here.  This is a deliberate design choice for bare-metal debugging: the program halts at a known address rather than executing random code.

In a debugger, if you see the program counter stuck at `Default_Trap_Handler`, you know an unexpected exception occurred.  You can then examine the `mcause` CSR to determine which trap fired.

## Init_Trap_Vector

```asm
.global Init_Trap_Vector
.type Init_Trap_Vector, @function
Init_Trap_Vector:
  la    t0, Default_Trap_Handler                 # trap target
  csrw  mtvec, t0                                # mtvec = trap entry
  ret                                            # return
```

### `la t0, Default_Trap_Handler`

The `la` pseudo-instruction loads the absolute address of `Default_Trap_Handler` into `t0`.  The assembler expands this to `auipc`/`addi` to handle the full 32-bit address.

### `csrw mtvec, t0`

`csrw` (CSR Write) writes `t0` into the `mtvec` (Machine Trap Vector) CSR.  After this instruction, any trap routes the CPU to `Default_Trap_Handler`.

The `mtvec` register has two mode bits at positions [1:0]:

| Mode | Value | Behaviour |
|------|-------|-----------|
| Direct | `0` | All traps go to one address |
| Vectored | `1` | Exceptions go to base, interrupts to base + 4*cause |

Since our handler address is 4-byte aligned (guaranteed by `.align 2`), the low bits are `00`, selecting direct mode.  All traps route to the same handler.

### Contrast with ARM

On ARM Cortex-M33, the vector table is a hardware structure.  The CPU reads the address at `vector_table[exception_number]` and jumps there.  There is no need for an `Init_Trap_Vector` call — the hardware reads the table automatically.

On RISC-V, the `mtvec` CSR must be explicitly programmed.  Without `Init_Trap_Vector`, `mtvec` holds whatever the boot ROM left there.

## Complete Boot Timeline

```
Power-on
  │
  ├── Boot ROM scans flash → finds IMAGE_DEF at 0x10000000
  ├── Reads entry point (Reset_Handler) and stack (STACK_TOP)
  ├── Sets sp = 0x20082000, pc = Reset_Handler
  │
  └── Reset_Handler executes:
        ├── Init_Stack         → sp = 0x20082000 (re-affirmed)
        ├── Init_Trap_Vector   → mtvec = Default_Trap_Handler
        ├── Init_XOSC          → XOSC stable at 12 MHz
        ├── Enable_XOSC_Peri_Clock → peripheral clock = XOSC
        ├── Init_Subsystem     → IO_BANK0 released from reset
        ├── Enable_Coprocessor → (no-op)
        └── j main             → LED blink loop begins
```

## Summary

- `Reset_Handler` is the entry point called by the boot ROM after reading the IMAGE_DEF block.
- It executes seven steps in a strict dependency order: stack → trap vector → XOSC → clock → subsystem → coprocessor → main.
- `Default_Trap_Handler` is an infinite loop that catches any unexpected trap at a known address.
- `Init_Trap_Vector` programs the `mtvec` CSR to route all traps to `Default_Trap_Handler`.
- The final `j main` uses an unconditional jump (not `call`) because `main` never returns.
- The `.size` directive records the function length for debugger use.
