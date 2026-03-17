# Chapter 21: Boot Metadata — `image_def.s`

## Introduction

Before the RP2350 will execute any code, the boot ROM must find a valid IMAGE_DEF block in the first 4 KB of flash.  This block tells the bootloader what kind of image it is loading — the CPU architecture, the entry point, and the initial stack pointer.  Without it, the chip sees blank or unrecognised flash and refuses to boot.  In this chapter we walk through every byte of `image_def.s`.

## Full Source

```asm
.include "constants.s"

.section .picobin_block, "a"                     # place IMAGE_DEF block in flash
.align  2
embedded_block:
.word  0xffffded3                                # PICOBIN_BLOCK_MARKER_START
.byte  0x42                                      # PICOBIN_BLOCK_ITEM_1BS_IMAGE_TYPE
.byte  0x1                                       # item is 1 word in size
.hword 0x1101                                    # EXE + RISCV + RP2350

.byte  0x44                                      # PICOBIN_BLOCK_ITEM_1BS_ENTRY_POINT
.byte  0x3                                       # 3 words to next item
.byte  0x0                                       # pad
.byte  0x0                                       # pad
.word  Reset_Handler                             # RISC-V reset entry point
.word  STACK_TOP                                 # initial stack pointer value

.byte  0xff                                      # PICOBIN_BLOCK_ITEM_2BS_LAST
.hword (embedded_block_end - embedded_block - 16) / 4
.byte  0x0                                       # pad
.word  0x0                                       # relative pointer to next block (0 = loop to self)
.word  0xab123579                                # PICOBIN_BLOCK_MARKER_END
embedded_block_end:
```

## Section Placement

```asm
.section .picobin_block, "a"                     # place IMAGE_DEF block in flash
.align  2
```

The `.section .picobin_block, "a"` directive creates a named section with the allocatable (`"a"`) flag.  The linker script places this section first in flash:

```ld
.embedded_block :
{
  KEEP(*(.embedded_block))
  KEEP(*(.picobin_block))
} > FLASH :text
```

`KEEP` ensures the linker never discards this section, even though no code references it — the boot ROM reads it by scanning raw flash bytes.

`.align 2` pads to a 4-byte boundary, ensuring that `.word` directives that follow are naturally aligned.

## Start Marker

```asm
embedded_block:
.word  0xffffded3                                # PICOBIN_BLOCK_MARKER_START
```

The boot ROM scans the first 4 KB of flash for this magic number.  When it finds `0xffffded3`, it begins parsing the block.  The label `embedded_block` records the start address for the size calculation that appears later.

## Image Type Item

```asm
.byte  0x42                                      # PICOBIN_BLOCK_ITEM_1BS_IMAGE_TYPE
.byte  0x1                                       # item is 1 word in size
.hword 0x1101                                    # EXE + RISCV + RP2350
```

### Item Tag: `0x42`

PICOBIN items use a tag byte to identify their type.  `0x42` means "image type, one-byte size."

### Size: `0x01`

The size byte says "1 word of payload follows."  That word is the `.hword 0x1101` (padded to fit the item structure).

### Image Type Word: `0x1101`

This halfword encodes three flags:

| Bit field | Value | Meaning |
|-----------|-------|---------|
| EXE | `0x0001` | This is an executable image |
| CPU | `0x0100` | Target CPU is RISC-V |
| Chip | `0x1000` | Target chip is RP2350 |

Combined: `0x1000 | 0x0100 | 0x0001 = 0x1101`.

The ARM equivalent uses `0x1001` — the CPU field is `0x0000` for ARM.  This single halfword is what makes the bootloader launch the Hazard3 RISC-V core instead of the Cortex-M33.

## Entry Point Item

```asm
.byte  0x44                                      # PICOBIN_BLOCK_ITEM_1BS_ENTRY_POINT
.byte  0x3                                       # 3 words to next item
.byte  0x0                                       # pad
.byte  0x0                                       # pad
.word  Reset_Handler                             # RISC-V reset entry point
.word  STACK_TOP                                 # initial stack pointer value
```

### Item Tag: `0x44`

`0x44` identifies the entry-point item.

### Size: `0x03`

Three words of payload follow (including the two padding bytes that round out the first word).

### Padding Bytes

The two `0x0` bytes fill the remainder of the first word after the tag and size bytes.  PICOBIN items are word-aligned, so every item's payload starts on a 4-byte boundary.

### `Reset_Handler`

```asm
.word  Reset_Handler                             # RISC-V reset entry point
```

The assembler emits a relocation for the `Reset_Handler` symbol.  The linker resolves this to the absolute address of `Reset_Handler` in flash.  On reset, the bootloader loads the program counter with this address.

### `STACK_TOP`

```asm
.word  STACK_TOP                                 # initial stack pointer value
```

`STACK_TOP` is defined in `constants.s` as `0x20082000`.  The bootloader loads the stack pointer with this value before jumping to the entry point.  This gives us 32 KB of stack space (down to `0x2007a000`).

## Last-Item Marker

```asm
.byte  0xff                                      # PICOBIN_BLOCK_ITEM_2BS_LAST
.hword (embedded_block_end - embedded_block - 16) / 4
.byte  0x0                                       # pad
.word  0x0                                       # relative pointer to next block (0 = loop to self)
.word  0xab123579                                # PICOBIN_BLOCK_MARKER_END
embedded_block_end:
```

### Tag: `0xff`

The "last item" tag signals the end of the item list inside this block.

### Block Size

```asm
.hword (embedded_block_end - embedded_block - 16) / 4
```

The assembler computes this at assembly time.  It measures the block's total size (minus the 16-byte header/footer overhead), expressed in words.  The boot ROM uses this to verify block integrity.

### Next-Block Pointer

```asm
.word  0x0                                       # relative pointer to next block (0 = loop to self)
```

A value of zero means "this is the only block" — there is no chain to another IMAGE_DEF.

### End Marker

```asm
.word  0xab123579                                # PICOBIN_BLOCK_MARKER_END
```

The boot ROM verifies that this end marker follows the last item.  If `0xab123579` is not where expected, the block is rejected as corrupt.

## Memory Layout

After linking, the IMAGE_DEF block occupies the very first bytes of flash:

```
0x10000000  PICOBIN_BLOCK_MARKER_START  (0xffffded3)
0x10000004  Image-type item             (0x42, 0x01, 0x1101)
0x10000008  Entry-point item            (0x44, 0x03, pad, pad)
0x1000000c  Reset_Handler address
0x10000010  STACK_TOP value
0x10000014  Last-item + size + pad
0x10000018  Next-block pointer          (0x00000000)
0x1000001c  PICOBIN_BLOCK_MARKER_END    (0xab123579)
```

The `.vectors` section follows at the next 128-byte aligned address.

## ARM vs RISC-V Comparison

| Field | ARM | RISC-V |
|-------|-----|--------|
| Image type | `0x1001` | `0x1101` |
| CPU flag | `0x0000` (ARM) | `0x0100` (RISC-V) |
| Entry point | ARM `Reset_Handler` | RISC-V `Reset_Handler` |
| Stack | Same (`STACK_TOP`) | Same (`STACK_TOP`) |
| Block structure | Identical | Identical |

The only byte that differs between ARM and RISC-V boots is the CPU flag in the image-type halfword.

## Summary

- `image_def.s` provides the mandatory PICOBIN metadata that the RP2350 boot ROM requires.
- The start marker `0xffffded3` triggers block parsing during flash scan.
- `0x1101` selects RISC-V + RP2350 + executable image.
- The entry point and stack pointer tell the bootloader where to begin execution.
- The end marker `0xab123579` validates block integrity.
- The linker script places this block at the very start of flash with `KEEP`.
