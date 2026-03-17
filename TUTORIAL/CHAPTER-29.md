# Chapter 29: Application Entry Point — `main.s`

## Introduction

`main.s` is where all the initialization work pays off.  It configures GPIO16 as an output and enters an infinite loop that blinks an LED — on for 500 ms, off for 500 ms, forever.  This chapter walks through every instruction, shows how the function calls connect to the modules we built in previous chapters, and explains the section layout.

## Full Source

```asm
.include "constants.s"

.section .text                                   # code section
.align 2                                         # align to 4-byte boundary

.global main                                     # export main
.type main, @function                            # mark as function
main:
.GPIO16_Config:
  li    a0, PADS_BANK0_GPIO16_OFFSET             # load PADS_BANK0_GPIO16_OFFSET
  li    a1, IO_BANK0_GPIO16_CTRL_OFFSET          # load IO_BANK0_GPIO16_CTRL_OFFSET
  li    a2, 16                                   # load GPIO number
  call  GPIO_Config                              # call GPIO_Config
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
  ret                                            # return to caller

.section .rodata                                 # read-only data section

.section .data                                   # data section

.section .bss                                    # BSS section
```

## Function Declaration

```asm
.global main                                     # export main
.type main, @function                            # mark as function
```

`.global main` exports the symbol so the linker can resolve the `j main` in `reset_handler.s`.  `.type main, @function` marks it for the debugger and linker.

## GPIO16 Configuration

```asm
.GPIO16_Config:
  li    a0, PADS_BANK0_GPIO16_OFFSET             # load PADS_BANK0_GPIO16_OFFSET
  li    a1, IO_BANK0_GPIO16_CTRL_OFFSET          # load IO_BANK0_GPIO16_CTRL_OFFSET
  li    a2, 16                                   # load GPIO number
  call  GPIO_Config                              # call GPIO_Config
```

This runs once at startup, before the blink loop begins.

### Parameter Setup

| Register | Value | Constant | Meaning |
|----------|-------|----------|---------|
| `a0` | `0x44` | `PADS_BANK0_GPIO16_OFFSET` | Pad register offset for GPIO16 |
| `a1` | `0x84` | `IO_BANK0_GPIO16_CTRL_OFFSET` | CTRL register offset for GPIO16 |
| `a2` | `16` | (literal) | GPIO pin number |

The RISC-V calling convention passes the first eight arguments in `a0`–`a7`.  `GPIO_Config` expects pad offset in `a0`, CTRL offset in `a1`, and GPIO number in `a2`.

### The `call` Instruction

```asm
  call  GPIO_Config                              # call GPIO_Config
```

`call` is a pseudo-instruction that expands to `auipc ra, offset[31:12]` / `jalr ra, ra, offset[11:0]`.  It stores the return address in `ra` and jumps to `GPIO_Config`.  When `GPIO_Config` executes `ret`, control returns to the next instruction after the `call`.

### What GPIO_Config Does

For GPIO16, `GPIO_Config`:
1. Configures the pad at `PADS_BANK0_BASE + 0x44`: clears OD and ISO, sets IE
2. Sets FUNCSEL to 5 (SIO) at `IO_BANK0_BASE + 0x84`
3. Enables output via `SIO_GPIO_OE_SET` with bit 16

After this call, GPIO16 is a fully configured output pin.

## The Blink Loop

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

### Step 1: LED On

```asm
  li    a0, 16                                   # load GPIO number
  call  GPIO_Set                                 # call GPIO_Set
```

Loads `16` into `a0` (the GPIO number) and calls `GPIO_Set`, which writes `(1<<16)` to `SIO_GPIO_OUT_SET`, driving GPIO16 high.  Current flows through the LED and resistor to ground — the LED turns on.

### Step 2: Wait 500ms

```asm
  li    a0, 500                                  # 500ms
  call  Delay_MS                                 # call Delay_MS
```

Loads `500` into `a0` (milliseconds) and calls `Delay_MS`.  The function spins for `500 × 3600 = 1,800,000` loop iterations, consuming approximately 500 ms.

### Step 3: LED Off

```asm
  li    a0, 16                                   # load GPIO number
  call  GPIO_Clear                               # call GPIO_Clear
```

Calls `GPIO_Clear`, which writes `(1<<16)` to `SIO_GPIO_OUT_CLR`, driving GPIO16 low.  No current flows through the LED — it turns off.

### Step 4: Wait 500ms Again

```asm
  li    a0, 500                                  # 500ms
  call  Delay_MS                                 # call Delay_MS
```

Another 500 ms delay with the LED off.

### Step 5: Repeat

```asm
  j     .Loop                                    # loop forever
```

`j .Loop` is an unconditional jump back to the start of the cycle.  The LED blinks at 1 Hz (500 ms on + 500 ms off = 1000 ms period).

### Unreachable `ret`

```asm
  ret                                            # return to caller
```

This `ret` is never executed — the `j .Loop` above it always jumps back.  It exists as defensive coding, satisfying the convention that every function has a `ret`.

## Why `a0` Is Reloaded Each Time

Each `call` to `GPIO_Set`, `Delay_MS`, or `GPIO_Clear` is allowed to overwrite `a0` — it is a caller-saved register.  Even though `GPIO_Set` does not modify `a0`, the calling convention does not guarantee this.  We explicitly reload `a0` before every call to ensure correctness.

## Blink Timing Diagram

```
     ┌────────┐        ┌────────┐        ┌────────
     │  HIGH  │        │  HIGH  │        │  HIGH
─────┘        └────────┘        └────────┘
     |←500ms→| |←500ms→|←500ms→| |←500ms→|
     |←── 1000ms ──→|←── 1000ms ──→|
```

The LED toggles every 500 ms, producing a 1 Hz blink with a 50% duty cycle.

## Section Declarations

```asm
.section .rodata                                 # read-only data section
.section .data                                   # data section
.section .bss                                    # BSS section
```

These empty section declarations exist as placeholders.  They ensure the linker recognises that these standard sections exist, even though the blink driver does not use them:

| Section | Purpose | Contents |
|---------|---------|----------|
| `.rodata` | Read-only constants | Empty (no strings or tables) |
| `.data` | Initialised global variables | Empty (no globals) |
| `.bss` | Uninitialised global variables | Empty (no globals) |

In a more complex program, these sections would hold strings, lookup tables, and global state.

## Call Graph

```
main
  ├── GPIO_Config(0x44, 0x84, 16)  → gpio.s
  │     ├── PADS_BANK0 config
  │     ├── IO_BANK0 FUNCSEL
  │     └── SIO_GPIO_OE_SET
  │
  └── .Loop (infinite):
        ├── GPIO_Set(16)   → gpio.s → SIO_GPIO_OUT_SET
        ├── Delay_MS(500)  → delay.s → spin loop
        ├── GPIO_Clear(16) → gpio.s → SIO_GPIO_OUT_CLR
        ├── Delay_MS(500)  → delay.s → spin loop
        └── j .Loop
```

## Why `main` Does Not Save `ra`

`main` is reached via `j main` (not `call main`) from `Reset_Handler`.  The `j` instruction writes to `x0` (zero register), discarding the return address.  There is no valid return address to save.  `main` runs forever — it never returns.

## Contrast with ARM

| Aspect | ARM | RISC-V |
|--------|-----|--------|
| GPIO set | `GPIO_Set` (via `mcrr p0`) | `GPIO_Set` (via `sw` to SIO) |
| GPIO clear | `GPIO_Clear` (via `mcrr p0`) | `GPIO_Clear` (via `sw` to SIO) |
| Call convention | `bl GPIO_Set` | `call GPIO_Set` |
| Parameter register | `r0` | `a0` |
| Infinite loop | `b .Loop` | `j .Loop` |
| Register reload | Same pattern | Same pattern |

The structure is identical — only the instruction mnemonics and register names differ.

## Summary

- `main` configures GPIO16 once, then enters an infinite blink loop.
- The loop alternates between `GPIO_Set`(high) and `GPIO_Clear`(low) with 500 ms delays.
- `a0` is reloaded before every `call` because the calling convention allows callees to modify it.
- `j .Loop` creates the infinite loop — `main` never returns.
- The `.rodata`, `.data`, and `.bss` section declarations are placeholders for standard sections.
- The 1 Hz blink (500 ms on, 500 ms off) is visible confirmation that all ten source files work together correctly.
