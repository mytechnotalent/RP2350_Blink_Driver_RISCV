/**
 * FILE: stack.s
 *
 * DESCRIPTION:
 * RP2350 Stack Initialization (RISC-V).
 * 
 * BRIEF:
 * Provides stack pointer initialization for RISC-V startup.
 *
 * AUTHOR: Kevin Thomas
 * CREATION DATE: November 27, 2025
 * UPDATE DATE: March 16, 2026
 */


.include "constants.s"

/**
 * Initialize the .text section. 
 * The .text section contains executable code.
 */
.section .text                                   # code section
.align 2                                         # align to 4-byte boundary

/**
 * @brief   Initialize stack pointers.
 *
 * @details Sets Main and Process Stack Pointers (MSP/PSP) and their limits.
 *
 * @param   None
 * @retval  None
 */
.global Init_Stack
.type Init_Stack, @function
Init_Stack:
  li    sp, STACK_TOP                            # set SP to top of RAM stack
  ret                                            # return
