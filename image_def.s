/**
 * FILE: image_def.s
 *
 * DESCRIPTION:
 * RP2350 IMAGE_DEF Block.
 * 
 * BRIEF:
 * A minimum amount of metadata (a valid IMAGE_DEF block) must be embedded in any
 * binary for the bootrom to recognise it as a valid program image, as opposed to,
 * for example, blank flash contents or a disconnected flash device. This must
 * appear within the first 4 kB of a flash image, or anywhere in a RAM or OTP image.
 * Unlike RP2040, there is no requirement for flash binaries to have a checksummed
 * "boot2" flash setup function at flash address 0. The RP2350 bootrom performs a
 * simple best‑effort XIP setup during flash scanning, and a flash‑resident program
 * can continue executing in this state, or can choose to reconfigure the QSPI
 * interface at a later time for best performance.
 *
 * AUTHOR: Kevin Thomas
 * CREATION DATE: October 5, 2025
 * UPDATE DATE: March 16, 2026
 */

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
