# Chapter 14: Assembler Directives

## Introduction

Assembler directives are commands to the assembler itself — they do not produce machine instructions.  Instead, they control how the assembler organizes code, allocates data, defines symbols, and structures the output object file.  Our blink driver relies on directives to set up sections, export symbols, align data, and include shared constants.  This chapter catalogs every directive used in our firmware and explains its purpose.

## Section Directives

### `.section`

```asm
.section .text                                   # code section
.section .rodata                                 # read-only data section
.section .data                                   # data section
.section .bss                                    # BSS section
```

`.section` places subsequent code or data into a named section.  Sections can have flags:

```asm
.section .vectors, "ax"                          # vector table section
.section .picobin_block, "a"                     # allocatable, non-executable
```

| Flag | Meaning |
|------|---------|
| `a` | Allocatable (occupies memory) |
| `x` | Executable |
| `w` | Writable |

Our firmware uses several sections:

| Section | Purpose | Used In |
|---------|---------|---------|
| `.text` | Executable code | All .s files |
| `.rodata` | Read-only constants | main.s |
| `.data` | Initialized variables | main.s |
| `.bss` | Uninitialized variables | main.s |
| `.picobin_block` | Boot image metadata | image_def.s |
| `.vectors` | Vector table | vector_table.s |

### `.align`

```asm
.align 2                                         # align to 4-byte boundary
```

`.align N` pads with zeros until the current address is a multiple of 2^N bytes.  `.align 2` means 4-byte alignment (2^2 = 4).

Every source file uses `.align 2` after the `.section .text` directive to ensure instructions start on a word boundary.  In vector_table.s:

```asm
.section .vectors, "ax"                          # vector table section
.align 2                                         # 4-byte aligned
```

The vector table must be aligned because the hardware reads it as 32-bit words.

## Symbol Directives

### `.global`

```asm
.global GPIO_Config                              # export symbol
.global GPIO_Set                                 # export symbol
.global GPIO_Clear                               # export symbol
```

`.global` makes a symbol visible to the linker.  Without it, the symbol exists only within that assembly file.  Every function called from another file must be exported:

| Symbol | Defined In | Called From |
|--------|-----------|------------|
| `Reset_Handler` | reset_handler.s | vector_table.s, image_def.s |
| `Default_Trap_Handler` | reset_handler.s | vector_table.s |
| `Init_Trap_Vector` | reset_handler.s | (internal) |
| `Init_Stack` | stack.s | reset_handler.s |
| `Init_XOSC` | xosc.s | reset_handler.s |
| `Enable_XOSC_Peri_Clock` | xosc.s | reset_handler.s |
| `Init_Subsystem` | reset.s | reset_handler.s |
| `Enable_Coprocessor` | coprocessor.s | reset_handler.s |
| `main` | main.s | reset_handler.s |
| `GPIO_Config` | gpio.s | main.s |
| `GPIO_Set` | gpio.s | main.s |
| `GPIO_Clear` | gpio.s | main.s |
| `Delay_MS` | delay.s | main.s |

### `.type`

```asm
.type GPIO_Config, @function                     # mark as function symbol
```

`.type` tells the linker that the symbol is a function (not data).  On RISC-V, the syntax uses `@function` (not ARM's `%function`).  This metadata helps debuggers and disassemblers display the code correctly.

### `.size`

```asm
.size Reset_Handler, . - Reset_Handler           # record function size
```

`.size` records the function's byte size in the symbol table.  The expression `. - Reset_Handler` calculates the distance from the current position to the function's start.  Our firmware uses this for Reset_Handler.

### `.equ`

```asm
.equ STACK_TOP, 0x20082000                       # define constant
.equ XOSC_BASE, 0x40048000                       # define constant
```

`.equ` defines a named constant.  It produces no code or data — the symbol is replaced by its value wherever it appears.  Our constants.s file is entirely `.equ` directives:

```asm
.equ IO_BANK0_BASE, 0x40028000                   # GPIO control base
.equ PADS_BANK0_BASE, 0x40038000                 # GPIO pad base
.equ SIO_BASE, 0xd0000000                        # SIO GPIO base
.equ SIO_GPIO_OUT_SET, SIO_BASE + 0x018          # GPIO output set
.equ SIO_GPIO_OUT_CLR, SIO_BASE + 0x020          # GPIO output clear
.equ SIO_GPIO_OE_SET, SIO_BASE + 0x038           # GPIO output enable set
```

## Data Directives

### `.word`

```asm
.word Reset_Handler                              # emit 32-bit value
.word STACK_TOP                                  # emit 32-bit value
```

`.word` emits a 32-bit value into the current section.  The vector table uses `.word` to store handler addresses and the PICOBIN block uses it for the entry point:

```asm
_vectors:
  .word Reset_Handler                            # reset handler address
  .word Default_Trap_Handler                     # default trap handler
```

Note: Unlike ARM, RISC-V vector entries do not need a +1 Thumb bit.  RISC-V addresses are used directly.

### `.byte`

```asm
.byte 0x42                                       # emit 8-bit value
```

Used in image_def.s for byte-level fields in the PICOBIN block structure.

### `.hword`

```asm
.hword 0x1101                                    # emit 16-bit value
```

Used in image_def.s for the image type field: `0x1101` = EXE + RISCV + RP2350.

## Include Directive

### `.include`

```asm
.include "constants.s"                           # include shared constants
```

`.include` textually inserts another file at the current position.  Every source file includes constants.s to access shared `.equ` definitions.  This is the RISC-V equivalent of C's `#include` — the file is pasted in verbatim.

## Labels

Labels assign names to addresses.  A label is any identifier followed by a colon:

```asm
main:                                            # function entry point
GPIO_Config:                                     # function entry point
.Loop:                                           # local branch target
.Delay_MS_Loop:                                  # local loop target
```

### Global vs. Local Labels

**Global labels** are visible across all object files after linking (when paired with `.global`):

```asm
.global main                                     # visible to linker
main:                                            # address recorded globally
```

**Local labels** (prefixed with `.`) are file-private — invisible outside the object file:

```asm
.Loop:                                           # local to this file
  li    a0, 16
  call  GPIO_Set
  ...
  j     .Loop                                    # branch within file
```

## The Symbol Table

The assembler creates a symbol table in each object file.  Each entry contains:

| Field | Description |
|-------|-------------|
| Name | The label string |
| Value | Address or constant value |
| Section | Which section contains it |
| Binding | Local or global |
| Type | Function, object, or notype |

The linker merges symbol tables from all object files, resolves cross-file references, and patches instructions with final addresses.

## Cross-File Resolution

When main.s references `GPIO_Set`:

```asm
  call  GPIO_Set                                 # reference to external symbol
```

The assembler creates a relocation entry.  The linker reads both main.o and gpio.o, finds `GPIO_Set` in gpio.o's symbol table, computes the final address, and patches the `auipc`+`jalr` sequence with the correct offsets.

## Contrast with ARM

| Feature | ARM | RISC-V |
|---------|-----|--------|
| Instruction set directive | `.syntax unified` + `.thumb` | None needed |
| Function marker | `.thumb_func` | `.type name, @function` |
| Function type syntax | `%function` | `@function` |
| Vector table addresses | Need +1 Thumb bit | Direct addresses |
| Comment character in code | `//` | `#` |

RISC-V requires fewer directives because the ISA does not have Thumb/ARM mode switching.

## Summary

- `.section` organizes code and data into named regions for the linker.
- `.align 2` ensures 4-byte alignment for instructions and data.
- `.global` and `.type` control symbol visibility and metadata.
- `.equ` defines named constants without emitting code.
- `.word`, `.byte`, and `.hword` emit raw data values.
- `.include` shares constants across all source files.
- Labels name addresses; global labels are linker-visible, local labels are file-private.
