/**
 * FILE: main.s
 *
 * DESCRIPTION:
 * RP2350 Bare-Metal Blink Main Application (RISC-V).
 * 
 * BRIEF:
 * Main application entry point for RP2350 RISC-V blink driver. Contains the
 * main loop that toggles GPIO16 to blink an LED.
 *
 * AUTHOR: Kevin Thomas
 * CREATION DATE: November 2, 2025
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
 * @brief   Main application entry point.
 *
 * @details Implements the infinite blink loop.
 *
 * @param   None
 * @retval  None
 */
.global main                                     # export main
.type main, @function                            # mark as function
main:
.GPIO16_Config:
  li    a0, PADS_BANK0_GPIO16_OFFSET             # load PADS_BANK0_GPIO16_OFFSET
  li    a1, IO_BANK0_GPIO16_CTRL_OFFSET          # load IO_BANK0_GPIO16_CTRL_OFFSET
  li    a2, 16                                   # load GPIO number
  call  GPIO_Config                              # call GPIO_Config
.Loop:
  li    a0, 16                                   # load GPIO number
  call  GPIO_Set                                 # call GPIO_Set
  li    a0, 500                                  # 500ms
  call  Delay_MS                                 # call Delay_MS
  li    a0, 16                                   # load GPIO number
  call  GPIO_Clear                               # call GPIO_Clear
  li    a0, 500                                  # 500ms
  call  Delay_MS                                 # call Delay_MS
  j     .Loop                                    # loop forever
  ret                                            # return to caller

/**
 * Test data and constants.
 * The .rodata section is used for constants and static data.
 */
.section .rodata                                 # read-only data section

/**
 * Initialized global data.
 * The .data section is used for initialized global or static variables.
 */
.section .data                                   # data section

/**
 * Uninitialized global data.
 * The .bss section is used for uninitialized global or static variables.
 */
.section .bss                                    # BSS section
