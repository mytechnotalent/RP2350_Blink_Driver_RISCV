/**
 * FILE: reset_handler.s
 *
 * DESCRIPTION:
 * RP2350 Reset Handler (RISC-V).
 * 
 * BRIEF:
 * Entry point after reset. Performs initialization sequence including
 * stack setup, trap vector setup, oscillator configuration, subsystem
 * initialization, and coprocessor enable before branching to main application.
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
 * @brief   Reset handler for RP2350.
 *
 * @details Entry point after reset. Performs:
 *          - Stack initialization
 *          - Trap vector setup
 *          - XOSC and clock initialization
 *          - Subsystem initialization
 *          - Coprocessor enable (no-op on RISC-V)
 *          - Branches to main() which contains the blink loop
 *
 * @param   None
 * @retval  None
 */
.global Reset_Handler                            # export Reset_Handler symbol
.type Reset_Handler, @function
Reset_Handler:
  call  Init_Stack                               # initialize SP
  call  Init_Trap_Vector                         # install trap vector
  call  Init_XOSC                                # initialize external crystal oscillator
  call  Enable_XOSC_Peri_Clock                   # enable XOSC peripheral clock
  call  Init_Subsystem                           # initialize subsystems
  call  Enable_Coprocessor                       # no-op on RISC-V (kept for parity)
  j     main                                     # branch to main loop
.size Reset_Handler, . - Reset_Handler

.global Default_Trap_Handler
.type Default_Trap_Handler, @function
Default_Trap_Handler:
  j     Default_Trap_Handler                     # lock here on unexpected trap

.global Init_Trap_Vector
.type Init_Trap_Vector, @function
Init_Trap_Vector:
  la    t0, Default_Trap_Handler                 # trap target
  csrw  mtvec, t0                                # mtvec = trap entry
  ret                                            # return
