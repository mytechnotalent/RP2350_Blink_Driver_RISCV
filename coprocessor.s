/**
 * FILE: coprocessor.s
 *
 * DESCRIPTION:
 * RP2350 Coprocessor Access Functions (RISC-V).
 * 
 * BRIEF:
 * Provides compatibility stubs for the ARM coprocessor setup API.
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
 * @brief   Enable coprocessor access.
 *
 * @details Grants full access to coprocessor 0 via CPACR.
 *
 * @param   None
 * @retval  None
 */
.global Enable_Coprocessor
.type Enable_Coprocessor , @function
Enable_Coprocessor:
  ret                                            # no-op for RISC-V build
