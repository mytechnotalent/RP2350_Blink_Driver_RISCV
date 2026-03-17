/**
 * FILE: delay.s
 *
 * DESCRIPTION:
 * RP2350 Delay Functions (RISC-V).
 * 
 * BRIEF:
 * Provides millisecond delay functions based on a 14.5MHz clock.
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
 * @brief   Delay_MS.
 *
 * @details Delays for a0 milliseconds. Conversion: loop_count = ms * 3600
 *          based on a 14.5MHz clock.
 *
 * @param   a0 - milliseconds
 * @retval  None
 */
.global Delay_MS
.type Delay_MS, @function
Delay_MS:
.Delay_MS_Check:
  blez  a0, .Delay_MS_Done                       # if MS is not valid, return
.Delay_MS_Setup:
  li    t0, 3600                                 # loops per MS based on 14.5MHz clock
  mul   t1, a0, t0                               # MS * 3600
.Delay_MS_Loop:
  addi  t1, t1, -1                               # decrement counter
  bnez  t1, .Delay_MS_Loop                       # branch until zero
.Delay_MS_Done:
  ret                                            # return
