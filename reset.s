/**
 * FILE: reset.s
 *
 * DESCRIPTION:
 * RP2350 Reset Controller Functions (RISC-V).
 * 
 * BRIEF:
 * Provides functions to initialize subsystems by clearing their
 * reset bits in the Reset controller.
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
 * @brief   Init subsystem.
 *
 * @details Initiates the various subsystems by clearing their reset bits.
 *
 * @param   None
 * @retval  None
 */
.global Init_Subsystem
.type Init_Subsystem, @function
Init_Subsystem:
.GPIO_Subsystem_Reset:
  li    t0, RESETS_RESET                         # load RESETS->RESET address
  lw    t1, 0(t0)                                # read RESETS->RESET value
  li    t2, (1<<6)                               # IO_BANK0 reset mask
  not   t2, t2                                   # invert mask
  and   t1, t1, t2                               # clear IO_BANK0 bit
  sw    t1, 0(t0)                                # store value into RESETS->RESET address
.GPIO_Subsystem_Reset_Wait:
  li    t0, RESETS_RESET_DONE                    # load RESETS->RESET_DONE address
  lw    t1, 0(t0)                                # read RESETS->RESET_DONE value
  andi  t1, t1, (1<<6)                           # test IO_BANK0 reset done
  beqz  t1, .GPIO_Subsystem_Reset_Wait           # wait until done
  ret                                            # return
