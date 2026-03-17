# Chapter 27: GPIO Configuration — `gpio.s` Part 1

## Introduction

GPIO configuration is the most complex function in our blink driver.  `GPIO_Config` must modify three separate hardware blocks — pad control, IO function select, and SIO output enable — to transform a default-state pin into a driven output.  This chapter walks through every instruction of `GPIO_Config`, showing how it configures the electrical properties, selects the SIO function, and enables the output driver.

## GPIO_Config — Full Source

```asm
.global GPIO_Config
.type GPIO_Config, @function
GPIO_Config:
  addi  sp, sp, -4                               # allocate stack frame
  sw    ra, 0(sp)                                # save return address
.GPIO_Config_Modify_Pad:
  li    t0, PADS_BANK0_BASE                      # load PADS_BANK0_BASE address
  add   t0, t0, a0                               # PADS_BANK0_BASE + PAD_OFFSET
  lw    t1, 0(t0)                                # read pad register value
  li    t2, ~(1<<7)                              # mask to clear OD bit
  and   t1, t1, t2                               # clear OD bit
  ori   t1, t1, (1<<6)                           # set IE bit
  li    t2, ~(1<<8)                              # mask to clear ISO bit
  and   t1, t1, t2                               # clear ISO bit
  sw    t1, 0(t0)                                # store pad config
.GPIO_Config_Modify_CTRL:
  li    t0, IO_BANK0_BASE                        # load IO_BANK0 base
  add   t0, t0, a1                               # IO_BANK0_BASE + CTRL_OFFSET
  lw    t1, 0(t0)                                # read CTRL register
  andi  t1, t1, ~0x1f                            # clear FUNCSEL field
  ori   t1, t1, 0x05                             # set FUNCSEL to SIO (5)
  sw    t1, 0(t0)                                # store CTRL config
.GPIO_Config_Enable_OE:
  li    t0, SIO_GPIO_OE_SET                      # load SIO GPIO_OE_SET address
  li    t1, 1                                    # bit value
  sll   t1, t1, a2                               # shift to GPIO position
  sw    t1, 0(t0)                                # enable output for GPIO
  lw    ra, 0(sp)                                # restore return address
  addi  sp, sp, 4                                # deallocate stack frame
  ret                                            # return
```

## Parameters

`GPIO_Config` takes three parameters:

| Register | Parameter | Value for GPIO16 |
|----------|-----------|-------------------|
| `a0` | PAD_OFFSET | `0x44` (`PADS_BANK0_GPIO16_OFFSET`) |
| `a1` | CTRL_OFFSET | `0x84` (`IO_BANK0_GPIO16_CTRL_OFFSET`) |
| `a2` | GPIO number | `16` |

Using offsets and a GPIO number makes the function reusable for any pin.

## Stack Frame

### Prologue

```asm
  addi  sp, sp, -4                               # allocate stack frame
  sw    ra, 0(sp)                                # save return address
```

`GPIO_Config` is called from `main` via `call GPIO_Config`.  The `call` instruction writes the return address to `ra`.  But `GPIO_Config` is itself called from `main` (which was reached via `j` from `Reset_Handler`), so we must preserve `ra` on the stack.

Although `GPIO_Config` does not itself call any functions in the current code, the stack frame follows the conservative pattern for non-leaf functions.  The 4-byte frame holds exactly one word — the saved `ra`.

```
Before:  sp → [...]
After:   sp → [saved ra]  ← sp decreased by 4
```

### Epilogue

```asm
  lw    ra, 0(sp)                                # restore return address
  addi  sp, sp, 4                                # deallocate stack frame
  ret                                            # return
```

The epilogue reverses the prologue: load `ra` from the stack, restore `sp`, and return.

## Phase 1: Pad Configuration

```asm
.GPIO_Config_Modify_Pad:
  li    t0, PADS_BANK0_BASE                      # load PADS_BANK0_BASE address
  add   t0, t0, a0                               # PADS_BANK0_BASE + PAD_OFFSET
  lw    t1, 0(t0)                                # read pad register value
```

`PADS_BANK0_BASE` + `a0` computes the GPIO-specific pad register address.  For GPIO16: `0x40038000 + 0x44 = 0x40038044`.

### Clear Output Disable (OD)

```asm
  li    t2, ~(1<<7)                              # mask to clear OD bit
  and   t1, t1, t2                               # clear OD bit
```

Bit 7 is the Output Disable flag.  When set, the pad's output driver is turned off regardless of other settings.  We clear it to allow output.

`~(1<<7)` = `0xFFFFFF7F` — all bits set except bit 7.  The `li` pseudo-instruction loads this 32-bit constant.

### Set Input Enable (IE)

```asm
  ori   t1, t1, (1<<6)                           # set IE bit
```

Bit 6 is the Input Enable flag.  Even though we are configuring an output, enabling the input allows GPIO state readback — useful for debugging.  `(1<<6) = 64`, which fits in the 12-bit signed immediate range for `ori`.

### Clear Isolation (ISO)

```asm
  li    t2, ~(1<<8)                              # mask to clear ISO bit
  and   t1, t1, t2                               # clear ISO bit
```

Bit 8 is the Isolation flag.  When set, the pad is electrically isolated from the internal logic.  This is a power-saving feature that must be cleared for normal operation.

### Write Back

```asm
  sw    t1, 0(t0)                                # store pad config
```

The modified value is written back to the pad register.

### Pad Register Bit Map

| Bit | Name | Default | Our Setting | Purpose |
|-----|------|---------|-------------|---------|
| 7 | OD | 0 | **0** (clear) | Output Disable — must be 0 for output |
| 6 | IE | 1 | **1** (set) | Input Enable — allows readback |
| 8 | ISO | 1 | **0** (clear) | Isolation — must be 0 for operation |

## Phase 2: Function Select

```asm
.GPIO_Config_Modify_CTRL:
  li    t0, IO_BANK0_BASE                        # load IO_BANK0 base
  add   t0, t0, a1                               # IO_BANK0_BASE + CTRL_OFFSET
  lw    t1, 0(t0)                                # read CTRL register
  andi  t1, t1, ~0x1f                            # clear FUNCSEL field
  ori   t1, t1, 0x05                             # set FUNCSEL to SIO (5)
  sw    t1, 0(t0)                                # store CTRL config
```

### Address Computation

`IO_BANK0_BASE` + `a1` = `0x40028000 + 0x84 = 0x40028084` for GPIO16.

### Clear FUNCSEL

```asm
  andi  t1, t1, ~0x1f                            # clear FUNCSEL field
```

Bits [4:0] of the CTRL register select which peripheral function drives the pin.  `~0x1f = 0xFFFFFFE0` clears the bottom 5 bits.

### Set SIO Function

```asm
  ori   t1, t1, 0x05                             # set FUNCSEL to SIO (5)
```

FUNCSEL value 5 selects SIO (Single-cycle IO).  This connects the pin to the SIO block, which provides fast GPIO output through dedicated set/clear registers.

### FUNCSEL Values

| Value | Function | Use Case |
|-------|----------|----------|
| 0 | JTAG | Debug |
| 1 | SPI | Serial peripheral |
| 2 | UART | Serial communication |
| 3 | I2C | Bus communication |
| 4 | PWM | Pulse width modulation |
| **5** | **SIO** | **General-purpose GPIO** |
| 7 | PIO0 | Programmable IO |
| 31 | NULL | Disabled |

## Phase 3: Enable Output

```asm
.GPIO_Config_Enable_OE:
  li    t0, SIO_GPIO_OE_SET                      # load SIO GPIO_OE_SET address
  li    t1, 1                                    # bit value
  sll   t1, t1, a2                               # shift to GPIO position
  sw    t1, 0(t0)                                # enable output for GPIO
```

### Dynamic Bit Position

```asm
  li    t1, 1                                    # bit value
  sll   t1, t1, a2                               # shift to GPIO position
```

`sll` (Shift Left Logical) shifts the value 1 left by `a2` positions.  For GPIO16: `1 << 16 = 0x00010000`.  This creates a bitmask with only the target GPIO bit set.

### SIO Atomic Write

```asm
  sw    t1, 0(t0)                                # enable output for GPIO
```

`SIO_GPIO_OE_SET` (`0xd0000038`) is an atomic set register.  Writing `0x00010000` sets bit 16 (enabling GPIO16's output driver) without affecting any other GPIO outputs.  No read-modify-write is needed — the SIO hardware handles atomicity.

### SIO vs APB

| Feature | APB (Pads, IO_BANK0) | SIO |
|---------|---------------------|-----|
| Access | Read-modify-write | Atomic set/clear |
| Speed | Multi-cycle (APB bus) | Single-cycle |
| Address | `0x4xxxxxxx` | `0xd0000000` |
| Race safety | Manual (must read first) | Hardware atomic |

## Three Configuration Blocks

```
GPIO_Config
  │
  ├── Phase 1: PADS_BANK0 (electrical)
  │     └── Clear OD, set IE, clear ISO
  │
  ├── Phase 2: IO_BANK0 (function)
  │     └── Set FUNCSEL = 5 (SIO)
  │
  └── Phase 3: SIO (output enable)
        └── Set OE bit for target GPIO
```

## Contrast with ARM GPIO_Config

| Aspect | ARM | RISC-V |
|--------|-----|--------|
| Pad config | Same registers, same bits | Same registers, same bits |
| FUNCSEL | Same register, same value (5) | Same register, same value (5) |
| Output enable | `mcrr p0` coprocessor instruction | `sw` to `SIO_GPIO_OE_SET` memory address |
| Stack frame | `push {lr}` / `pop {pc}` | `addi sp`/`sw ra` / `lw ra`/`addi sp` |

The only architectural difference is the output enable step.  On ARM, SIO is accessed via coprocessor instructions.  On RISC-V, the same SIO hardware is memory-mapped at `0xd0000000`.

## Summary

- `GPIO_Config` configures a GPIO pin in three phases: pad control, function select, output enable.
- The stack frame saves `ra` because `GPIO_Config` is called from `main`.
- Pad configuration clears OD (bit 7) and ISO (bit 8), sets IE (bit 6).
- Function select sets FUNCSEL bits [4:0] to 5 (SIO).
- Output enable uses `sll` to create a dynamic bitmask and writes it to `SIO_GPIO_OE_SET`.
- SIO atomic registers eliminate the need for read-modify-write on the output enable step.
- The function uses offsets as parameters, making it reusable for any GPIO pin.
