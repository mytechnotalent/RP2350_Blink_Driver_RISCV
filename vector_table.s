/**
 * FILE: vector_table.s
 *
 * DESCRIPTION:
 * RP2350 Vector Table Placeholder (RISC-V).
 * 
 * BRIEF:
 * Defines a compatibility vector section so the linker layout remains
 * identical to the ARM project structure.
 *
 * AUTHOR: Kevin Thomas
 * CREATION DATE: November 27, 2025
 * UPDATE DATE: March 16, 2026
 */


.include "constants.s"

/**
 * Initialize the .vectors section. The .vectors section contains vector
 * table and Reset_Handler.
 */
.section .vectors, "ax"                          # vector table section
.align 2                                         # align to 4-byte boundary

/**
 * Vector table section.
 */
.global _vectors                                 # export _vectors symbol
_vectors:
  .word Reset_Handler                            # reset handler address placeholder
  .word Default_Trap_Handler                     # default trap handler placeholder
