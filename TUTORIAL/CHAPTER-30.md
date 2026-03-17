# Chapter 30: Full Integration — Build, Flash, Wire, and Test

## Introduction

Every piece is in place.  Ten assembly source files, a linker script, and a build script combine to produce a firmware image that makes an LED blink on the RP2350.  This final chapter brings everything together: we trace the complete execution path from power-on to blinking LED, build the firmware, wire the hardware, flash the chip, and verify that it works.

## The Complete Source Tree

```
RP2350_Blink_Driver_RISCV/
├── constants.s          Ch 22  — All memory-mapped addresses
├── image_def.s          Ch 21  — PICOBIN boot metadata (RISC-V)
├── vector_table.s       Ch 23  — Vector table section
├── stack.s              Ch 23  — Stack pointer initialization
├── reset_handler.s      Ch 24  — Boot sequence orchestrator
├── xosc.s               Ch 25  — Crystal oscillator init + clock enable
├── reset.s              Ch 26  — Peripheral reset release
├── gpio.s               Ch 27-28 — GPIO config, set, clear (SIO)
├── delay.s              Ch 28  — Millisecond delay loop
├── coprocessor.s        Ch 28  — No-op compatibility stub
├── main.s               Ch 29  — Application entry, blink loop
├── linker.ld            Ch 19  — Memory layout and section placement
├── build.bat            Ch 20  — Build pipeline script
├── clean.bat            Ch 20  — Build artifact cleanup
├── uf2conv.py                  — UF2 conversion utility
└── uf2families.json            — UF2 family ID database
```

## The Complete Execution Path

### Phase 1: Boot ROM

```
Power-on / Reset
  │
  └── RP2350 boot ROM starts
        ├── Scans first 4 KB of flash
        ├── Finds PICOBIN_BLOCK_MARKER_START (0xffffded3)
        ├── Reads image type: 0x1101 → RISC-V + RP2350 + EXE
        ├── Reads entry point: Reset_Handler address
        ├── Reads stack: STACK_TOP (0x20082000)
        ├── Sets sp = 0x20082000
        └── Sets pc = Reset_Handler
```

### Phase 2: Hardware Initialization

```
Reset_Handler (reset_handler.s)
  │
  ├── call Init_Stack (stack.s)
  │     └── li sp, 0x20082000
  │
  ├── call Init_Trap_Vector (reset_handler.s)
  │     ├── la t0, Default_Trap_Handler
  │     └── csrw mtvec, t0
  │
  ├── call Init_XOSC (xosc.s)
  │     ├── XOSC_STARTUP = 0x00c4
  │     ├── XOSC_CTRL = 0x00FABAA0 (enable, 1-15MHz)
  │     └── Poll XOSC_STATUS bit31 via bgez
  │
  ├── call Enable_XOSC_Peri_Clock (xosc.s)
  │     ├── Set ENABLE bit (bit 11)
  │     └── Set AUXSRC = XOSC (bit 7)
  │
  ├── call Init_Subsystem (reset.s)
  │     ├── Clear IO_BANK0 reset (bit 6)
  │     └── Poll RESETS_RESET_DONE bit 6
  │
  ├── call Enable_Coprocessor (coprocessor.s)
  │     └── ret (no-op on RISC-V)
  │
  └── j main
```

### Phase 3: Application

```
main (main.s)
  │
  ├── GPIO16_Config:
  │     └── call GPIO_Config(0x44, 0x84, 16)
  │           ├── PADS: clear OD, set IE, clear ISO
  │           ├── CTRL: FUNCSEL = 5 (SIO)
  │           └── SIO_GPIO_OE_SET: bit 16
  │
  └── .Loop (infinite):
        ├── GPIO_Set(16)   → SIO_GPIO_OUT_SET bit 16 → LED ON
        ├── Delay_MS(500)  → 1,800,000 loop iterations
        ├── GPIO_Clear(16) → SIO_GPIO_OUT_CLR bit 16 → LED OFF
        ├── Delay_MS(500)  → 1,800,000 loop iterations
        └── j .Loop
```

## Memory Map After Linking

```
Flash (0x10000000):
  0x10000000  IMAGE_DEF block (image_def.s)
  0x10000080  Vector table (vector_table.s, 128-byte aligned)
  0x10000088+ .text (all functions merged)
              - Reset_Handler, Default_Trap_Handler, Init_Trap_Vector
              - Init_Stack
              - Init_XOSC, Enable_XOSC_Peri_Clock
              - Init_Subsystem
              - Enable_Coprocessor
              - GPIO_Config, GPIO_Set, GPIO_Clear
              - Delay_MS
              - main

RAM (0x20000000):
  0x2007a000  Stack limit (bottom of 32 KB stack)
  0x20082000  Stack top (sp starts here, grows down)
```

## Hardware Wiring

### Components Needed

| Component | Specification |
|-----------|---------------|
| Raspberry Pi Pico 2 | RP2350-based board |
| LED | Standard 3mm or 5mm, any colour |
| Resistor | 330Ω (or 220Ω–1kΩ) |
| Breadboard | Standard size |
| Jumper wires | Male-to-male |

### Wiring Diagram

```
Pico 2 GPIO16 (Pin 21) ──── Resistor (330Ω) ──── LED (+) ──── LED (-) ──── GND (Pin 23)
```

### Pin Reference

| Pico 2 Pin | Function | Connection |
|------------|----------|------------|
| Pin 21 | GPIO16 | Resistor → LED anode |
| Pin 23 | GND | LED cathode |

The resistor limits current to approximately `(3.3V - 2V) / 330Ω ≈ 4 mA`, safely within the LED and GPIO ratings.  The LED's longer leg is the anode (+), shorter is cathode (−).

## Building the Firmware

### Prerequisites

1. **RISC-V Toolchain**: Download from [pico-sdk-tools](https://github.com/raspberrypi/pico-sdk-tools/releases) — get `riscv-toolchain-14-*-x86_64-w64-mingw32.zip`
2. **Python**: Required for `uf2conv.py`
3. Extract the toolchain to `%USERPROFILE%\Documents\riscv-toolchain-14\`

### Build

Open a terminal in the project directory and run:

```
build.bat
```

The build produces:

| File | Purpose |
|------|---------|
| `*.o` | Object files (one per source file) |
| `blink.elf` | Linked executable with debug info |
| `blink.bin` | Raw binary for flash |
| `blink.uf2` | Flashable firmware image |

### Clean

```
clean.bat
```

Removes all build artifacts (`.o`, `.elf`, `.bin`, `.uf2`).

## Flashing the Firmware

### Method 1: UF2 (USB Mass Storage)

1. Hold the **BOOTSEL** button on the Pico 2
2. Connect the USB cable while holding BOOTSEL
3. Release BOOTSEL — the Pico 2 appears as a USB drive
4. Copy `blink.uf2` to the drive
5. The Pico 2 automatically resets and starts blinking

### Method 2: OpenOCD (Debug Probe)

```
openocd -f interface/cmsis-dap.cfg -f target/rp2350.cfg ^
  -c "adapter speed 5000" ^
  -c "program blink.elf verify reset exit"
```

This requires a CMSIS-DAP compatible debug probe connected via SWD.

### Method 3: Picotool

```
picotool load blink.uf2 -f
```

Picotool communicates with the Pico 2 over USB without requiring BOOTSEL mode.

## Verification

After flashing, the LED connected to GPIO16 should blink:

- **ON** for 500 ms
- **OFF** for 500 ms
- **Repeat** indefinitely

If the LED does not blink:

| Symptom | Possible Cause | Fix |
|---------|---------------|-----|
| No blinking, LED dark | Wrong GPIO pin | Check wiring: GPIO16 is Pin 21 |
| No blinking, LED dark | LED reversed | Swap LED orientation |
| No blinking, LED dim | Missing resistor | Add 330Ω resistor |
| No blinking, LED steady | Wrong firmware | Rebuild and re-flash |
| Bootloader not appearing | Board not in BOOTSEL | Hold BOOTSEL before connecting USB |

## Hardware Register Access Summary

| Peripheral | Base Address | Access Method | Function |
|-----------|-------------|---------------|----------|
| XOSC | `0x40048000` | APB (R/M/W) | Crystal oscillator |
| Clocks | `0x40010000` | APB (R/M/W) | Clock routing |
| Resets | `0x40020000` | APB (R/M/W) | Peripheral reset control |
| IO Bank 0 | `0x40028000` | APB (R/M/W) | GPIO function select |
| Pads Bank 0 | `0x40038000` | APB (R/M/W) | GPIO pad config |
| SIO | `0xd0000000` | Mem-mapped (atomic) | GPIO output + enable |

## Instruction Census

The entire blink driver uses a small subset of the RV32IMAC instruction set:

| Category | Instructions Used |
|----------|------------------|
| Load/Store | `li`, `la`, `lw`, `sw` |
| Arithmetic | `add`, `addi`, `mul` |
| Logic | `and`, `andi`, `or`, `ori`, `not` |
| Shift | `sll` |
| Branch | `beqz`, `bnez`, `bgez`, `blez` |
| Jump | `j`, `call`, `ret` |
| System | `csrw` |

That is 19 instructions (including pseudo-instructions) to drive real hardware.

## What You Have Built

Starting from first principles — what a computer is, how numbers are represented, what registers do — you have built a complete bare-metal RISC-V firmware that:

1. Boots from the RP2350's PICOBIN metadata
2. Initialises the crystal oscillator for a stable clock
3. Releases GPIO hardware from reset
4. Configures a pin as a SIO-driven output
5. Toggles that pin in an infinite loop to blink an LED

Every byte in the firmware is accounted for.  There is no operating system, no runtime library, no hidden code.  You wrote every instruction, and you understand what each one does.

## Summary

- The complete blink driver consists of 10 assembly files, a linker script, and a build script.
- The boot sequence flows: IMAGE_DEF → Reset_Handler → Init_Stack → Init_Trap_Vector → Init_XOSC → Enable_XOSC_Peri_Clock → Init_Subsystem → Enable_Coprocessor → main.
- GPIO16 is configured through three hardware blocks: PADS_BANK0, IO_BANK0, and SIO.
- The blink loop uses GPIO_Set, Delay_MS, GPIO_Clear, Delay_MS in an infinite cycle.
- The firmware is built with `build.bat` and flashed via UF2, OpenOCD, or picotool.
- A blinking LED at 1 Hz confirms that every component — from metadata to main loop — works correctly.
