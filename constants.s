/**
 * FILE: constants.s
 *
 * DESCRIPTION:
 * RP2350 Memory Addresses and Constants (RISC-V).
 * 
 * BRIEF:
 * Defines all memory-mapped register addresses and constants used
 * throughout the RP2350 RISC-V blink driver.
 *
 * AUTHOR: Kevin Thomas
 * CREATION DATE: November 2, 2025
 * UPDATE DATE: March 16, 2026
 */


/**
 * Memory addresses and constants.
 */
.equ STACK_TOP,                   0x20082000               
.equ STACK_LIMIT,                 0x2007a000             
.equ VECTOR_TABLE_BASE,           0x20000000
.equ XOSC_BASE,                   0x40048000          
.equ XOSC_CTRL,                   XOSC_BASE + 0x00       
.equ XOSC_STATUS,                 XOSC_BASE + 0x04       
.equ XOSC_STARTUP,                XOSC_BASE + 0x0c        
.equ PPB_BASE,                    0xe0000000
.equ MSTATUS_MIE,                 (1<<3)
.equ MTVEC_MODE_DIRECT,           0
.equ CLOCKS_BASE,                 0x40010000              
.equ CLK_PERI_CTRL,               CLOCKS_BASE + 0x48       
.equ RESETS_BASE,                 0x40020000               
.equ RESETS_RESET,                RESETS_BASE + 0x0        
.equ RESETS_RESET_CLEAR,          RESETS_BASE + 0x3000     
.equ RESETS_RESET_DONE,           RESETS_BASE + 0x8        
.equ IO_BANK0_BASE,               0x40028000               
.equ IO_BANK0_GPIO16_CTRL_OFFSET, 0x84                   
.equ PADS_BANK0_BASE,             0x40038000               
.equ PADS_BANK0_GPIO16_OFFSET,    0x44                    
.equ SIO_BASE,                    0xd0000000
.equ SIO_GPIO_OUT_SET,            SIO_BASE + 0x018
.equ SIO_GPIO_OUT_CLR,            SIO_BASE + 0x020
.equ SIO_GPIO_OE_SET,             SIO_BASE + 0x038
