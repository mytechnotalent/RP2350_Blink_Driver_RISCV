# Chapter 20: The Build Pipeline — From Assembly to Flashable Binary

## Introduction

Our build system transforms human-readable assembly source files into a UF2 firmware image that the RP2350 can execute.  The process has four stages: assemble, link, extract binary, and convert to UF2.  This chapter walks through every command in build.bat and clean.bat, explaining what each tool does, what flags control, and how the output of one stage feeds the next.

## The Build Pipeline

```
Source Files (.s)
      |
      v
  [riscv32-unknown-elf-as]    Stage 1: Assemble
      |
      v
Object Files (.o)
      |
      v
  [riscv32-unknown-elf-ld]    Stage 2: Link
      |
      v
  blink.elf
      |
      v
  [riscv32-unknown-elf-objcopy] Stage 3: Extract binary
      |
      v
  blink.bin
      |
      v
  [python uf2conv.py]          Stage 4: Convert to UF2
      |
      v
  blink.uf2
```

## Toolchain Auto-Detection

build.bat begins by locating the RISC-V toolchain:

```bat
set TOOLCHAIN_PREFIX=riscv32-unknown-elf
```

It then searches in order:
1. System PATH
2. `%RISCV_TOOLCHAIN_BIN%` environment variable
3. `%USERPROFILE%\OneDrive\Documents\riscv-toolchain-14\bin`
4. `%USERPROFILE%\Documents\riscv-toolchain-14\bin`

If no toolchain is found, the build fails with instructions on where to install it.

## Stage 1: Assembly

Each source file is assembled independently:

```bat
riscv32-unknown-elf-as -g -march=rv32imac_zicsr -mabi=ilp32 vector_table.s -o vector_table.o
riscv32-unknown-elf-as -g -march=rv32imac_zicsr -mabi=ilp32 reset_handler.s -o reset_handler.o
riscv32-unknown-elf-as -g -march=rv32imac_zicsr -mabi=ilp32 stack.s -o stack.o
riscv32-unknown-elf-as -g -march=rv32imac_zicsr -mabi=ilp32 xosc.s -o xosc.o
riscv32-unknown-elf-as -g -march=rv32imac_zicsr -mabi=ilp32 reset.s -o reset.o
riscv32-unknown-elf-as -g -march=rv32imac_zicsr -mabi=ilp32 coprocessor.s -o coprocessor.o
riscv32-unknown-elf-as -g -march=rv32imac_zicsr -mabi=ilp32 gpio.s -o gpio.o
riscv32-unknown-elf-as -g -march=rv32imac_zicsr -mabi=ilp32 delay.s -o delay.o
riscv32-unknown-elf-as -g -march=rv32imac_zicsr -mabi=ilp32 main.s -o main.o
riscv32-unknown-elf-as -g -march=rv32imac_zicsr -mabi=ilp32 image_def.s -o image_def.o
```

### Assembler Flags

| Flag | Meaning |
|------|---------|
| `-g` | Generate debug information (DWARF) |
| `-march=rv32imac_zicsr` | Target RV32I + M + A + C + Zicsr extensions |
| `-mabi=ilp32` | Use ILP32 ABI (32-bit int, long, pointer) |

Each `.s` file produces a corresponding `.o` (object) file containing:

- Machine code with unresolved relocations
- A symbol table (local and global symbols)
- Section headers (.text, .data, .bss, etc.)
- Debug information (source line mappings)

### Assembler Flag Details

**`-march=rv32imac_zicsr`** specifies the exact instruction set:

| Component | Meaning |
|-----------|---------|
| `rv32i` | Base 32-bit integer instructions |
| `m` | Multiply/divide (mul, div, rem) |
| `a` | Atomic operations |
| `c` | Compressed (16-bit) instructions |
| `_zicsr` | CSR read/write instructions |

**`-mabi=ilp32`** specifies the calling convention:

| ABI | int | long | pointer |
|-----|-----|------|---------|
| ilp32 | 32-bit | 32-bit | 32-bit |

### Ten Source Files

| Source File | Purpose |
|-------------|---------|
| vector_table.s | Vector table (handler address placeholders) |
| reset_handler.s | Boot sequence calling all init functions |
| stack.s | Stack pointer initialization |
| xosc.s | Crystal oscillator init and clock enable |
| reset.s | Peripheral reset release |
| coprocessor.s | No-op compatibility stub |
| gpio.s | GPIO pad config, set, clear via SIO |
| delay.s | Millisecond delay function |
| main.s | Application entry point and blink loop |
| image_def.s | PICOBIN boot metadata (RISC-V) |

## Stage 2: Linking

```bat
riscv32-unknown-elf-ld -g -T linker.ld ^
  vector_table.o reset_handler.o stack.o xosc.o reset.o ^
  coprocessor.o gpio.o delay.o main.o image_def.o ^
  -o blink.elf
```

### Linker Flags

| Flag | Meaning |
|------|---------|
| `-g` | Preserve debug information |
| `-T linker.ld` | Use our linker script for memory layout |
| `-o blink.elf` | Output filename |

The linker:

1. Reads all ten object files
2. Merges matching sections (all `.text` sections combine into one)
3. Assigns absolute addresses according to linker.ld
4. Resolves all symbol references (e.g., `call GPIO_Set` gets patched with the correct offset)
5. Produces an ELF (Executable and Linkable Format) file

### ELF File Contents

The ELF file contains:

- All machine code at final addresses
- Section headers describing memory layout
- Symbol table with resolved addresses
- Debug information mapping code to source lines

The ELF is used by debuggers (GDB + OpenOCD) for source-level debugging.

## Stage 3: Binary Extraction

```bat
riscv32-unknown-elf-objcopy -O binary blink.elf blink.bin
```

`objcopy` strips all ELF metadata and produces a raw binary — the exact bytes that will be written to flash starting at `0x10000000`.  This file contains no headers, no symbol table, no debug info — just machine code and data.

## Stage 4: UF2 Conversion

```bat
python uf2conv.py -b 0x10000000 -f 0xe48bff5a -o blink.uf2 blink.bin
```

### UF2 Flags

| Flag | Meaning |
|------|---------|
| `-b 0x10000000` | Base address (flash start) |
| `-f 0xe48bff5a` | RP2350 RISC-V family ID |
| `-o blink.uf2` | Output filename |

UF2 (USB Flashing Format) wraps the binary in a format that the RP2350's USB bootloader understands.  Each 512-byte UF2 block contains:

- Magic numbers for identification
- Target address for that block's data
- Up to 256 bytes of payload
- Family ID to prevent flashing the wrong chip

### Family ID

The family ID `0xe48bff5a` identifies the target as RP2350 RISC-V.  The ARM family ID is `0xe48bff59` (one different).  If you flash a RISC-V UF2 to an ARM-configured boot, or vice versa, the bootloader rejects it.

## Error Handling

Every command in build.bat is followed by:

```bat
if errorlevel 1 goto error
```

If any stage fails (syntax error, undefined symbol, missing file), the build stops immediately with an error message.  This prevents cascading failures where a later stage operates on corrupt or missing input.

## Flashing the Firmware

build.bat prints instructions for two flashing methods:

### UF2 (USB Mass Storage)

1. Hold BOOTSEL button on the Pico 2
2. Connect USB cable
3. Copy blink.uf2 to the RP2350 drive

The RP2350 appears as a USB mass storage device.  Copying the UF2 file triggers the bootloader to write the firmware to flash and reset.

### OpenOCD (Debug Probe)

```bat
openocd -f interface/cmsis-dap.cfg -f target/rp2350.cfg ^
  -c "adapter speed 5000" ^
  -c "program blink.elf verify reset exit"
```

This uses a debug probe (Raspberry Pi Debug Probe or compatible CMSIS-DAP adapter) to:
1. Connect to the RP2350 via SWD
2. Program the ELF file to flash
3. Verify the written data
4. Reset the chip to start execution

## The Clean Script

```bat
del *.o *.elf *.bin *.uf2 2>nul
```

clean.bat removes all build artifacts, returning the directory to source-only state.  The `2>nul` suppresses errors if files don't exist.

## Contrast with ARM Build

| Aspect | ARM | RISC-V |
|--------|-----|--------|
| Assembler | `arm-none-eabi-as` | `riscv32-unknown-elf-as` |
| CPU flag | `-mcpu=cortex-m33 -mthumb` | `-march=rv32imac_zicsr -mabi=ilp32` |
| Linker | `arm-none-eabi-ld` | `riscv32-unknown-elf-ld` |
| Objcopy | `arm-none-eabi-objcopy` | `riscv32-unknown-elf-objcopy` |
| Family ID | `0xe48bff59` | `0xe48bff5a` |
| Output name | `blink.elf` / `blink.uf2` | `blink.elf` / `blink.uf2` |

The pipeline structure is identical — only the tool prefix, architecture flags, and family ID differ.

## Summary

- The build pipeline has four stages: assemble → link → extract binary → convert to UF2.
- `-march=rv32imac_zicsr -mabi=ilp32` configures the assembler for our specific RISC-V core.
- The linker merges ten object files using linker.ld to produce blink.elf.
- `objcopy` strips ELF metadata to produce a raw binary.
- `uf2conv.py` wraps the binary with the RISC-V family ID `0xe48bff5a`.
- Error handling stops the build immediately on any failure.
- Firmware can be flashed via UF2 (USB) or OpenOCD (debug probe).
