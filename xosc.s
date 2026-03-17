/**
 * FILE: xosc.s
 *
 * DESCRIPTION:
 * RP2350 External Crystal Oscillator (XOSC) Functions (RISC-V).
 * 
 * BRIEF:
 * Provides functions to initialize the external crystal oscillator
 * and enable the XOSC peripheral clock.
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
 * @brief   Init XOSC and wait until it is ready.
 *
 * @details Configures and initializes the external crystal oscillator (XOSC).
 *          Waits for the XOSC to become stable before returning.
 *
 * @param   None
 * @retval  None
 */
.global Init_XOSC
.type Init_XOSC, @function
Init_XOSC:
  li    t0, XOSC_STARTUP                         # load XOSC_STARTUP address
  li    t1, 0x00c4                               # set delay 50,000 cycles
  sw    t1, 0(t0)                                # store value into XOSC_STARTUP
  li    t0, XOSC_CTRL                            # load XOSC_CTRL address
  li    t1, 0x00FABAA0                           # set 1_15MHz, freq range, actual 14.5MHz
  sw    t1, 0(t0)                                # store value into XOSC_CTRL
.Init_XOSC_Wait:
  li    t0, XOSC_STATUS                          # load XOSC_STATUS address
  lw    t1, 0(t0)                                # read XOSC_STATUS value
  bgez  t1, .Init_XOSC_Wait                      # bit31 clear -> still unstable
  ret                                            # return

/**
 * @brief   Enable XOSC peripheral clock.
 *
 * @details Sets the peripheral clock to use XOSC as its AUXSRC.
 *
 * @param   None
 * @retval  None
 */
.global Enable_XOSC_Peri_Clock
.type Enable_XOSC_Peri_Clock, @function
Enable_XOSC_Peri_Clock:
  li    t0, CLK_PERI_CTRL                        # load CLK_PERI_CTRL address
  lw    t1, 0(t0)                                # read CLK_PERI_CTRL value
  li    t2, (1<<11)                              # ENABLE bit mask
  or    t1, t1, t2                               # set ENABLE bit
  ori   t1, t1, 128                              # set AUXSRC: XOSC_CLKSRC bit
  sw    t1, 0(t0)                                # store value into CLK_PERI_CTRL
  ret                                            # return
