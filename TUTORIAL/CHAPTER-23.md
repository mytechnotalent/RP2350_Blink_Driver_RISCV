# Chapter 23: Stack and Vector Table — `stack.s` and `vector_table.s`

## Introduction

Two small files establish the foundation that every other function depends on: `stack.s` gives us a working stack, and `vector_table.s` provides the vector section that the linker script expects.  Together they ensure that `call`/`ret` work correctly and that the boot image has the proper layout.

## `stack.s` — Full Source

```asm
.include "constants.s"

.section .text                                   # code section
.align 2                                         # align to 4-byte boundary

.global Init_Stack
.type Init_Stack, @function
Init_Stack:
  li    sp, STACK_TOP                            # set SP to top of RAM stack
  ret                                            # return
```

## Stack Initialization — Line by Line

### Section and Alignment

```asm
.section .text                                   # code section
.align 2                                         # align to 4-byte boundary
```

The function lives in `.text` (executable code in flash).  `.align 2` ensures the first instruction starts on a 4-byte boundary, which is required for standard (non-compressed) RISC-V instructions.

### Function Declaration

```asm
.global Init_Stack
.type Init_Stack, @function
```

`.global` exports the symbol so other files can `call Init_Stack`.  `.type @function` marks it as a function for the linker and debugger.

### Loading the Stack Pointer

```asm
Init_Stack:
  li    sp, STACK_TOP                            # set SP to top of RAM stack
  ret                                            # return
```

`li sp, STACK_TOP` is a pseudo-instruction that loads the immediate value `0x20082000` into register `sp` (x2).  The assembler expands this to `lui`/`addi` as needed to construct the full 32-bit value.

`STACK_TOP` (`0x20082000`) is the highest address in the 520 KB SRAM region.  The stack grows downward — each `addi sp, sp, -N` moves the pointer toward `STACK_LIMIT` (`0x2007a000`), giving us 32 KB of stack space.

### Why a Function?

On RISC-V, the bootloader loads the stack pointer from the IMAGE_DEF block before jumping to `Reset_Handler`.  The explicit `Init_Stack` call in `Reset_Handler` re-establishes it to a known state, matching the ARM project structure and ensuring the stack is deterministically set regardless of bootloader behaviour.

## `vector_table.s` — Full Source

```asm
.include "constants.s"

.section .vectors, "ax"                          # vector table section
.align 2                                         # align to 4-byte boundary

.global _vectors                                 # export _vectors symbol
_vectors:
  .word Reset_Handler                            # reset handler address placeholder
  .word Default_Trap_Handler                     # default trap handler placeholder
```

## Vector Table — Line by Line

### Section Declaration

```asm
.section .vectors, "ax"                          # vector table section
.align 2                                         # align to 4-byte boundary
```

The `"ax"` flags mean allocatable and executable.  The linker script places this section after the IMAGE_DEF block with 128-byte alignment:

```ld
.vectors ALIGN(128) :
{
  KEEP(*(.vectors))
} > FLASH :text
```

The `ASSERT` in the linker script verifies the vector table stays within the first 4 KB of flash.

### Vector Entries

```asm
.global _vectors                                 # export _vectors symbol
_vectors:
  .word Reset_Handler                            # reset handler address placeholder
  .word Default_Trap_Handler                     # default trap handler placeholder
```

Each `.word` emits a 4-byte value — the absolute address of a handler function, resolved by the linker.

| Offset | Entry | Purpose |
|--------|-------|---------|
| `+0x00` | `Reset_Handler` | Entry point after reset |
| `+0x04` | `Default_Trap_Handler` | Fallback for unhandled traps |

### RISC-V Trap Handling vs ARM Vectors

On ARM Cortex-M33, the vector table is hardware-indexed — the CPU reads the vector at `(exception_number * 4)` and jumps there automatically.  The vector table must contain entries for every possible exception.

On RISC-V, trap handling works differently.  The `mtvec` CSR holds the address of a single trap handler.  All traps — whether from exceptions, interrupts, or illegal instructions — vector to that one address.  Our vector table section exists primarily for linker layout compatibility; the actual trap dispatch is controlled by `csrw mtvec` in `Init_Trap_Vector`.

The two `.word` entries serve as documentation and provide symbols that other code can reference.

## How They Work Together

During boot, the execution sequence is:

```
Boot ROM reads IMAGE_DEF → Loads SP from STACK_TOP → Jumps to Reset_Handler
  │
  └── Reset_Handler calls Init_Stack
        │
        └── li sp, STACK_TOP    ← sp is now guaranteed set
              ret
```

After `Init_Stack` returns, the stack is ready.  Every subsequent `call` instruction pushes `ra` (return address) to the stack, and every `ret` pops it back.

## Memory Layout

```
0x10000000          IMAGE_DEF block (image_def.s)
0x10000080          Vector table (vector_table.s, 128-byte aligned)
  +0x00             Reset_Handler address
  +0x04             Default_Trap_Handler address
0x10000088          .text section starts (Init_Stack, etc.)
```

The `.vectors` section occupies just 8 bytes but is aligned to 128 bytes as required by the linker script assertion.

## Contrast with ARM

| Aspect | ARM | RISC-V |
|--------|-----|--------|
| Stack init | `ldr sp, =_estack` | `li sp, STACK_TOP` |
| Vector table | ~16+ entries (NMI, HardFault, etc.) | 2 entries (compatibility) |
| Trap dispatch | Hardware vector table lookup | `mtvec` CSR → single handler |
| Vector section | `.isr_vector` | `.vectors` |
| Alignment | Required by hardware | Required by linker assertion |

## Summary

- `Init_Stack` loads the stack pointer with `STACK_TOP` (`0x20082000`) using the `li` pseudo-instruction.
- The stack grows downward with 32 KB of space before reaching `STACK_LIMIT`.
- `vector_table.s` defines a `.vectors` section with two entries: `Reset_Handler` and `Default_Trap_Handler`.
- On RISC-V, the actual trap vector is set via `csrw mtvec`, not by hardware vector table lookup.
- The linker script aligns `.vectors` to 128 bytes and asserts it stays within the first 4 KB of flash.
- Both files are minimal but essential — without them, the stack would be uninitialised and the linker layout would be incomplete.
