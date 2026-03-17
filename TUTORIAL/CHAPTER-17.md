# Chapter 17: Memory-Mapped I/O

## Introduction

On the RP2350, every peripheral — the oscillator, the reset controller, the GPIO pads, the clock system, and the SIO block — is controlled by reading and writing specific memory addresses.  There are no special I/O instructions; the same `lw` and `sw` instructions that access RAM also access peripheral registers.  This is **memory-mapped I/O**, and it is the foundation of all bare-metal programming.  This chapter examines how our firmware uses memory-mapped I/O to configure peripherals and drive GPIO.

## The Memory Map

The RP2350's address space is divided into regions, each mapped to different hardware:

```
+-------------------------------+
| 0x00000000 - 0x0FFFFFFF       |  Boot ROM
+-------------------------------+
| 0x10000000 - 0x11FFFFFF       |  External Flash (XIP)
+-------------------------------+
| 0x20000000 - 0x2007FFFF       |  SRAM (512 KB)
+-------------------------------+
| 0x40000000 - 0x4FFFFFFF       |  APB Peripherals
|   0x40010000  CLOCKS          |
|   0x40020000  RESETS          |
|   0x40028000  IO_BANK0        |
|   0x40038000  PADS_BANK0      |
|   0x40048000  XOSC            |
+-------------------------------+
| 0xD0000000 - 0xDFFFFFFF       |  SIO (Single-cycle IO)
+-------------------------------+
| 0xE0000000 - 0xE00FFFFF       |  PPB (Private Peripheral Bus)
+-------------------------------+
```

Our firmware accesses six peripheral blocks, all through simple `lw`/`sw` operations.

## The Access Pattern

Every peripheral register access follows the same pattern:

```asm
  li    t0, REGISTER_ADDRESS                     # step 1: load address
  lw    t1, 0(t0)                                # step 2: read current value
  ...                                            # step 3: modify bits
  sw    t1, 0(t0)                                # step 4: write back
```

This is the read-modify-write pattern from Chapter 16, applied to hardware registers.

## Peripheral Blocks in Our Firmware

### XOSC (0x40048000)

The crystal oscillator provides a stable clock.  Three registers are accessed:

```asm
  li    t0, XOSC_STARTUP                         # 0x4004800C
  li    t1, 0x00c4                               # startup delay
  sw    t1, 0(t0)                                # write-only: set delay

  li    t0, XOSC_CTRL                            # 0x40048000
  li    t1, 0x00FABAA0                           # control value
  sw    t1, 0(t0)                                # write-only: enable XOSC

  li    t0, XOSC_STATUS                          # 0x40048004
  lw    t1, 0(t0)                                # read-only: poll status
  bgez  t1, .Init_XOSC_Wait                      # check bit 31
```

Note: XOSC_STARTUP and XOSC_CTRL are written directly (no read-modify-write) because we set the entire register value.  XOSC_STATUS is read-only.

### CLOCKS (0x40010000)

The clock controller distributes clocks to peripherals:

```asm
  li    t0, CLK_PERI_CTRL                        # 0x40010048
  lw    t1, 0(t0)                                # read current value
  li    t2, (1<<11)                              # ENABLE bit
  or    t1, t1, t2                               # set ENABLE
  ori   t1, t1, 128                              # set AUXSRC = XOSC
  sw    t1, 0(t0)                                # write back
```

This is a read-modify-write because we must preserve other bits in CLK_PERI_CTRL.

### RESETS (0x40020000)

The reset controller holds peripherals in reset until released:

```asm
  li    t0, RESETS_RESET                         # 0x40020000
  lw    t1, 0(t0)                                # read current reset state
  li    t2, (1<<6)                               # IO_BANK0 mask
  not   t2, t2                                   # invert mask
  and   t1, t1, t2                               # clear bit 6
  sw    t1, 0(t0)                                # release IO_BANK0
```

Then poll RESETS_RESET_DONE:

```asm
  li    t0, RESETS_RESET_DONE                    # 0x40020008
  lw    t1, 0(t0)                                # read done status
  andi  t1, t1, (1<<6)                           # test IO_BANK0
  beqz  t1, .GPIO_Subsystem_Reset_Wait           # loop if not done
```

### PADS_BANK0 (0x40038000)

Pad registers control the electrical characteristics of each GPIO pin:

```asm
  li    t0, PADS_BANK0_BASE                      # 0x40038000
  add   t0, t0, a0                               # + pad offset (0x44 for GPIO16)
  lw    t1, 0(t0)                                # read pad config
  li    t2, ~(1<<7)                              # clear OD
  and   t1, t1, t2                               # modify
  ori   t1, t1, (1<<6)                           # set IE
  li    t2, ~(1<<8)                              # clear ISO
  and   t1, t1, t2                               # modify
  sw    t1, 0(t0)                                # write back
```

### IO_BANK0 (0x40028000)

IO control registers select which internal peripheral drives each pin:

```asm
  li    t0, IO_BANK0_BASE                        # 0x40028000
  add   t0, t0, a1                               # + ctrl offset (0x84 for GPIO16)
  lw    t1, 0(t0)                                # read CTRL register
  andi  t1, t1, ~0x1f                            # clear FUNCSEL
  ori   t1, t1, 0x05                             # set SIO (5)
  sw    t1, 0(t0)                                # write back
```

### SIO (0xD0000000)

The Single-cycle IO block provides fast access to GPIO outputs.  Unlike other peripherals, SIO uses **atomic set/clear registers** — writing to GPIO_OUT_SET sets bits, writing to GPIO_OUT_CLR clears bits.  No read-modify-write is needed:

```asm
  li    t0, SIO_GPIO_OE_SET                      # 0xD0000038
  li    t1, 1                                    # bit value
  sll   t1, t1, a2                               # shift to GPIO position
  sw    t1, 0(t0)                                # enable output (write-only)

  li    t0, SIO_GPIO_OUT_SET                     # 0xD0000018
  li    t1, 1                                    # bit value
  sll   t1, t1, a0                               # shift to GPIO position
  sw    t1, 0(t0)                                # set output high (write-only)

  li    t0, SIO_GPIO_OUT_CLR                     # 0xD0000020
  li    t1, 1                                    # bit value
  sll   t1, t1, a0                               # shift to GPIO position
  sw    t1, 0(t0)                                # set output low (write-only)
```

The SIO approach is simpler and faster than read-modify-write because the hardware handles the atomic set/clear operation.

## SIO vs. APB Peripherals

| Feature | APB Peripherals | SIO |
|---------|----------------|-----|
| Address range | 0x4xxx_xxxx | 0xD000_0000 |
| Access method | Read-modify-write | Atomic set/clear registers |
| Bus | APB (multi-cycle) | Dedicated single-cycle bus |
| Operations | Read/write any register | Set/clear/toggle specific bits |
| Speed | Slower (bus arbitration) | Fastest (single cycle) |

On ARM, SIO is accessed via coprocessor instructions (`mcrr p0`).  On RISC-V, SIO is memory-mapped — the same `sw` instruction accesses both APB and SIO registers, but the hardware routes SIO accesses through a faster bus.

## Why Memory-Mapped I/O?

The alternative to memory-mapped I/O is separate I/O instructions (as on x86 with `in`/`out`).  Memory-mapped I/O has significant advantages:

1. **No special instructions needed** — `lw`/`sw` work for everything
2. **Uniform programming model** — same tools, same patterns for memory and I/O
3. **Full address space** — peripherals get their own address ranges
4. **C compatible** — pointer dereferences map directly to register accesses

## CSR Access: A Special Case

The Hazard3 core's control and status registers (CSRs) are **not** memory-mapped.  They use dedicated instructions:

```asm
  csrw  mtvec, t0                                # write to machine trap vector CSR
```

CSRs exist inside the processor core itself, not on any bus.  The `csrrw`/`csrrs`/`csrrc` instruction family provides atomic read-modify-write access to these internal registers.

Our firmware accesses only one CSR: `mtvec` (the machine trap vector base address), set during Init_Trap_Vector.

## Summary

- Every peripheral on the RP2350 is accessed through memory-mapped registers using `lw`/`sw`.
- APB peripherals (XOSC, CLOCKS, RESETS, PADS, IO_BANK0) use read-modify-write at `0x4xxx_xxxx`.
- SIO GPIO registers at `0xD000_0000` use atomic set/clear — no read-modify-write needed.
- The access pattern is always: load address → read (if needed) → modify bits → write.
- CSRs are the exception: they use dedicated `csrw`/`csrr` instructions, not memory-mapped access.
- Memory-mapped I/O means the same `lw`/`sw` instructions control both data and hardware.
