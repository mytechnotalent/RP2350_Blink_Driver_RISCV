/**
 * FILE: gpio.s
 *
 * DESCRIPTION:
 * RP2350 GPIO Functions (RISC-V).
 * 
 * BRIEF:
 * Provides GPIO configuration, set, and clear functions using
 * memory-mapped SIO registers.
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
 * @brief   Configure GPIO.
 *
 * @details Configures a GPIO pin's pad control, function select,
 *          and output enable via SIO.
 *
 * @param   a0 - PAD_OFFSET
 * @param   a1 - CTRL_OFFSET
 * @param   a2 - GPIO number
 * @retval  None
 */
.global GPIO_Config
.type GPIO_Config, @function
GPIO_Config:
  addi  sp, sp, -4                               # allocate stack frame
  sw    ra, 0(sp)                                # save return address
.GPIO_Config_Modify_Pad:
  li    t0, PADS_BANK0_BASE                      # load PADS_BANK0_BASE address
  add   t0, t0, a0                               # PADS_BANK0_BASE + PAD_OFFSET
  lw    t1, 0(t0)                                # read pad register value
  li    t2, ~(1<<7)                              # mask to clear OD bit
  and   t1, t1, t2                               # clear OD bit
  ori   t1, t1, (1<<6)                           # set IE bit
  li    t2, ~(1<<8)                              # mask to clear ISO bit
  and   t1, t1, t2                               # clear ISO bit
  sw    t1, 0(t0)                                # store pad config
.GPIO_Config_Modify_CTRL:
  li    t0, IO_BANK0_BASE                        # load IO_BANK0 base
  add   t0, t0, a1                               # IO_BANK0_BASE + CTRL_OFFSET
  lw    t1, 0(t0)                                # read CTRL register
  andi  t1, t1, ~0x1f                            # clear FUNCSEL field
  ori   t1, t1, 0x05                             # set FUNCSEL to SIO (5)
  sw    t1, 0(t0)                                # store CTRL config
.GPIO_Config_Enable_OE:
  li    t0, SIO_GPIO_OE_SET                      # load SIO GPIO_OE_SET address
  li    t1, 1                                    # bit value
  sll   t1, t1, a2                               # shift to GPIO position
  sw    t1, 0(t0)                                # enable output for GPIO
  lw    ra, 0(sp)                                # restore return address
  addi  sp, sp, 4                                # deallocate stack frame
  ret                                            # return

/**
 * @brief   GPIO set.
 *
 * @details Drives GPIO output high via SIO.
 *
 * @param   a0 - GPIO number
 * @retval  None
 */
.global GPIO_Set
.type GPIO_Set, @function
GPIO_Set:
  li    t0, SIO_GPIO_OUT_SET                     # load SIO GPIO_OUT_SET address
  li    t1, 1                                    # bit value
  sll   t1, t1, a0                               # shift to GPIO position
  sw    t1, 0(t0)                                # set GPIO output high
  ret                                            # return

/**
 * @brief   GPIO clear.
 *
 * @details Drives GPIO output low via SIO.
 *
 * @param   a0 - GPIO number
 * @retval  None
 */
.global GPIO_Clear
.type GPIO_Clear, @function
GPIO_Clear:
  li    t0, SIO_GPIO_OUT_CLR                     # load SIO GPIO_OUT_CLR address
  li    t1, 1                                    # bit value
  sll   t1, t1, a0                               # shift to GPIO position
  sw    t1, 0(t0)                                # set GPIO output low
  ret                                            # return
