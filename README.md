<img src="https://github.com/mytechnotalent/RP2350_Blink_Driver_RISCV/blob/main/RP2350_Blink_Driver_RISCV.png?raw=true">

## FREE Embedded Hacking Course [HERE](https://github.com/mytechnotalent/Embedded-Hacking)
### VIDEO PROMO [HERE](https://www.youtube.com/watch?v=aD7X9sXirF8)

<br>

# RP2350 Blink Driver RISC-V
An RP2350 Blink driver written entirely in RISC-V Assembler.

<br>

# Install RISC-V Toolchain (Windows / RP2350 Hazard3)
Official Raspberry Pi guidance for RP2350 RISC-V points to pico-sdk-tools prebuilt releases.

## Official References
- RP2350 RISC-V quick start in pico-sdk: [HERE](https://github.com/raspberrypi/pico-sdk#risc-v-support-on-rp2350)
- Tool downloads (official): [HERE](https://github.com/raspberrypi/pico-sdk-tools/releases/tag/v2.0.0-5)

## Install (PowerShell)
```powershell
$url = "https://github.com/raspberrypi/pico-sdk-tools/releases/download/v2.0.0-5/riscv-toolchain-14-x64-win.zip"
$zipPath = "$env:TEMP\riscv-toolchain-14-x64-win.zip"
$dest = "$HOME\riscv-toolchain-14"

Invoke-WebRequest -Uri $url -OutFile $zipPath
New-Item -ItemType Directory -Path $dest -Force | Out-Null
Expand-Archive -LiteralPath $zipPath -DestinationPath $dest -Force
Get-ChildItem -Path $dest | Select-Object Name
```

## Add Toolchain To User PATH (PowerShell)
```powershell
$toolBin = "$HOME\riscv-toolchain-14\bin"
$currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentUserPath -notlike "*$toolBin*") {
  [Environment]::SetEnvironmentVariable("Path", "$currentUserPath;$toolBin", "User")
}
```

Close and reopen your terminal after updating PATH.

## Verify Toolchain
```powershell
riscv32-unknown-elf-as --version
riscv32-unknown-elf-ld --version
riscv32-unknown-elf-objcopy --version
```

## Build This Project
```powershell
.\build.bat
```

If your toolchain uses a different prefix, pass it explicitly:
```powershell
.\build.bat riscv-none-elf
```

## LED Wiring (Pico 2 Target)
- GP16 (Pin 21) → 330 Ω resistor → LED anode
- LED cathode → GND (Pin 23)

<br>

# Hardware
## Raspberry Pi Pico 2 w/ Header [BUY](https://www.pishop.us/product/raspberry-pi-pico-2-with-header)
## USB A-Male to USB Micro-B Cable [BUY](https://www.pishop.us/product/usb-a-male-to-usb-micro-b-cable-6-inches)
## Raspberry Pi Pico Debug Probe [BUY](https://www.pishop.us/product/raspberry-pi-debug-probe)
## Complete Component Kit for Raspberry Pi [BUY](https://www.pishop.us/product/complete-component-kit-for-raspberry-pi)
## 10pc 25v 1000uF Capacitor [BUY](https://www.amazon.com/Cionyce-Capacitor-Electrolytic-CapacitorsMicrowave/dp/B0B63CCQ2N?th=1)
### 10% PiShop DISCOUNT CODE - KVPE_HS320548_10PC

<br>

# Build
```
.\build.bat
```

## Optional Toolchain Prefix Override
```
.\build.bat riscv-none-elf
```

<br>

# Clean
```
.\clean.bat
```

<br>

# Tutorial

A comprehensive 30-chapter technical book teaching RP2350 RISC-V assembly from absolute scratch.  Every line of assembler is explained.

## Foundations

### [Chapter 1: What Is a Computer?](TUTORIAL/CHAPTER-01.md)
- [Introduction](TUTORIAL/CHAPTER-01.md#introduction)
- [The Fetch-Decode-Execute Cycle](TUTORIAL/CHAPTER-01.md#the-fetch-decode-execute-cycle)
- [The Three Core Components](TUTORIAL/CHAPTER-01.md#the-three-core-components)
- [Microcontroller vs Desktop Computer](TUTORIAL/CHAPTER-01.md#microcontroller-vs-desktop-computer)
- [What Is RP2350?](TUTORIAL/CHAPTER-01.md#what-is-rp2350)
- [What Is RISC-V?](TUTORIAL/CHAPTER-01.md#what-is-risc-v)
- [Why Assembly Language?](TUTORIAL/CHAPTER-01.md#why-assembly-language)
- [What We Are Building](TUTORIAL/CHAPTER-01.md#what-we-are-building)
- [Summary](TUTORIAL/CHAPTER-01.md#summary)

### [Chapter 2: Number Systems — Binary, Hexadecimal, and Decimal](TUTORIAL/CHAPTER-02.md)
- [Introduction](TUTORIAL/CHAPTER-02.md#introduction)
- [Decimal — Base 10](TUTORIAL/CHAPTER-02.md#decimal--base-10)
- [Binary — Base 2](TUTORIAL/CHAPTER-02.md#binary--base-2)
- [Hexadecimal — Base 16](TUTORIAL/CHAPTER-02.md#hexadecimal--base-16)
- [The 0x Prefix](TUTORIAL/CHAPTER-02.md#the-0x-prefix)
- [Bit Numbering](TUTORIAL/CHAPTER-02.md#bit-numbering)
- [Common Bit Patterns in Our Firmware](TUTORIAL/CHAPTER-02.md#common-bit-patterns-in-our-firmware)
- [Two's Complement — Signed Numbers](TUTORIAL/CHAPTER-02.md#twos-complement--signed-numbers)
- [Data Sizes on RISC-V Hazard3](TUTORIAL/CHAPTER-02.md#data-sizes-on-risc-v-hazard3)
- [Summary](TUTORIAL/CHAPTER-02.md#summary)

### [Chapter 3: Memory — Addresses, Bytes, Words, and Endianness](TUTORIAL/CHAPTER-03.md)
- [Introduction](TUTORIAL/CHAPTER-03.md#introduction)
- [The Address Space](TUTORIAL/CHAPTER-03.md#the-address-space)
- [Bytes, Halfwords, and Words](TUTORIAL/CHAPTER-03.md#bytes-halfwords-and-words)
- [Alignment](TUTORIAL/CHAPTER-03.md#alignment)
- [Little-Endian Byte Order](TUTORIAL/CHAPTER-03.md#little-endian-byte-order)
- [Memory-Mapped Registers](TUTORIAL/CHAPTER-03.md#memory-mapped-registers)
- [The Stack](TUTORIAL/CHAPTER-03.md#the-stack)
- [Flash Memory (XIP)](TUTORIAL/CHAPTER-03.md#flash-memory-xip)
- [SRAM](TUTORIAL/CHAPTER-03.md#sram)
- [CSR Access](TUTORIAL/CHAPTER-03.md#csr-access)
- [Summary](TUTORIAL/CHAPTER-03.md#summary)

### [Chapter 4: What Is a Register?](TUTORIAL/CHAPTER-04.md)
- [Introduction](TUTORIAL/CHAPTER-04.md#introduction)
- [The RISC-V Register File](TUTORIAL/CHAPTER-04.md#the-risc-v-register-file)
- [Register x0: The Hardwired Zero](TUTORIAL/CHAPTER-04.md#register-x0-the-hardwired-zero)
- [ABI Register Names](TUTORIAL/CHAPTER-04.md#abi-register-names)
- [Control and Status Registers](TUTORIAL/CHAPTER-04.md#control-and-status-registers)
- [Visualizing Registers](TUTORIAL/CHAPTER-04.md#visualizing-registers)
- [Summary](TUTORIAL/CHAPTER-04.md#summary)

### [Chapter 5: Load-Store Architecture — How RISC-V Accesses Memory](TUTORIAL/CHAPTER-05.md)
- [Introduction](TUTORIAL/CHAPTER-05.md#introduction)
- [The Load-Store Principle](TUTORIAL/CHAPTER-05.md#the-load-store-principle)
- [Why Load-Store?](TUTORIAL/CHAPTER-05.md#why-load-store)
- [RISC-V Load Instructions](TUTORIAL/CHAPTER-05.md#risc-v-load-instructions)
- [RISC-V Store Instructions](TUTORIAL/CHAPTER-05.md#risc-v-store-instructions)
- [Base + Offset Addressing](TUTORIAL/CHAPTER-05.md#base--offset-addressing)
- [The Memory Bus](TUTORIAL/CHAPTER-05.md#the-memory-bus)
- [Summary](TUTORIAL/CHAPTER-05.md#summary)

### [Chapter 6: The Fetch-Decode-Execute Cycle in Detail](TUTORIAL/CHAPTER-06.md)
- [Introduction](TUTORIAL/CHAPTER-06.md#introduction)
- [The Cycle Step by Step](TUTORIAL/CHAPTER-06.md#the-cycle-step-by-step)
- [Pipeline Concept](TUTORIAL/CHAPTER-06.md#pipeline-concept)
- [Tracing Through Our Firmware](TUTORIAL/CHAPTER-06.md#tracing-through-our-firmware)
- [The Program Counter is Everything](TUTORIAL/CHAPTER-06.md#the-program-counter-is-everything)
- [Summary](TUTORIAL/CHAPTER-06.md#summary)

## RISC-V Instruction Set

### [Chapter 7: RISC-V Hazard3 ISA Overview](TUTORIAL/CHAPTER-07.md)
- [Introduction](TUTORIAL/CHAPTER-07.md#introduction)
- [The RISC-V Design Philosophy](TUTORIAL/CHAPTER-07.md#the-risc-v-design-philosophy)
- [Our ISA String: rv32imac_zicsr](TUTORIAL/CHAPTER-07.md#our-isa-string-rv32imac_zicsr)
- [Instruction Encoding Formats](TUTORIAL/CHAPTER-07.md#instruction-encoding-formats)
- [Complete Instruction Table](TUTORIAL/CHAPTER-07.md#complete-instruction-table)
- [How This Maps to Our Firmware](TUTORIAL/CHAPTER-07.md#how-this-maps-to-our-firmware)
- [Summary](TUTORIAL/CHAPTER-07.md#summary)

### [Chapter 8: Immediate and Upper-Immediate Instructions](TUTORIAL/CHAPTER-08.md)
- [Introduction](TUTORIAL/CHAPTER-08.md#introduction)
- [What Is an Immediate?](TUTORIAL/CHAPTER-08.md#what-is-an-immediate)
- [I-Type Immediates (12-bit Signed)](TUTORIAL/CHAPTER-08.md#i-type-immediates-12-bit-signed)
- [U-Type Instructions: LUI and AUIPC](TUTORIAL/CHAPTER-08.md#u-type-instructions-lui-and-auipc)
- [Building 32-bit Constants: LUI + ADDI](TUTORIAL/CHAPTER-08.md#building-32-bit-constants-lui--addi)
- [The LI Pseudo-Instruction](TUTORIAL/CHAPTER-08.md#the-li-pseudo-instruction)
- [The LA Pseudo-Instruction](TUTORIAL/CHAPTER-08.md#the-la-pseudo-instruction)
- [Summary](TUTORIAL/CHAPTER-08.md#summary)

### [Chapter 9: Arithmetic and Logic Instructions](TUTORIAL/CHAPTER-09.md)
- [Introduction](TUTORIAL/CHAPTER-09.md#introduction)
- [R-Type Format](TUTORIAL/CHAPTER-09.md#r-type-format)
- [Addition and Subtraction](TUTORIAL/CHAPTER-09.md#addition-and-subtraction)
- [Logical Operations](TUTORIAL/CHAPTER-09.md#logical-operations)
- [Shift Operations](TUTORIAL/CHAPTER-09.md#shift-operations)
- [MUL from M Extension](TUTORIAL/CHAPTER-09.md#mul-from-m-extension)
- [No Condition Flags](TUTORIAL/CHAPTER-09.md#no-condition-flags)
- [Read-Modify-Write Pattern](TUTORIAL/CHAPTER-09.md#read-modify-write-pattern)
- [Summary](TUTORIAL/CHAPTER-09.md#summary)

### [Chapter 10: Memory Access — Load and Store Deep Dive](TUTORIAL/CHAPTER-10.md)
- [Introduction](TUTORIAL/CHAPTER-10.md#introduction)
- [Load Instruction Family](TUTORIAL/CHAPTER-10.md#load-instruction-family)
- [Store Instruction Family](TUTORIAL/CHAPTER-10.md#store-instruction-family)
- [Why Our Firmware Uses Only LW and SW](TUTORIAL/CHAPTER-10.md#why-our-firmware-uses-only-lw-and-sw)
- [Stack Operations](TUTORIAL/CHAPTER-10.md#stack-operations)
- [CSR Access Instructions](TUTORIAL/CHAPTER-10.md#csr-access-instructions)
- [Complete Memory Access Map](TUTORIAL/CHAPTER-10.md#complete-memory-access-map)
- [Summary](TUTORIAL/CHAPTER-10.md#summary)

### [Chapter 11: Branch Instructions](TUTORIAL/CHAPTER-11.md)
- [Introduction](TUTORIAL/CHAPTER-11.md#introduction)
- [How Branches Work](TUTORIAL/CHAPTER-11.md#how-branches-work)
- [B-Type Encoding](TUTORIAL/CHAPTER-11.md#b-type-encoding)
- [The Six Branch Instructions](TUTORIAL/CHAPTER-11.md#the-six-branch-instructions)
- [Branches in Our Firmware](TUTORIAL/CHAPTER-11.md#branches-in-our-firmware)
- [No Flags Register](TUTORIAL/CHAPTER-11.md#no-flags-register)
- [Summary](TUTORIAL/CHAPTER-11.md#summary)

### [Chapter 12: Jumps, Calls, and Returns](TUTORIAL/CHAPTER-12.md)
- [Introduction](TUTORIAL/CHAPTER-12.md#introduction)
- [JAL: Jump and Link](TUTORIAL/CHAPTER-12.md#jal-jump-and-link)
- [JALR: Jump and Link Register](TUTORIAL/CHAPTER-12.md#jalr-jump-and-link-register)
- [CALL Pseudo-Instruction](TUTORIAL/CHAPTER-12.md#call-pseudo-instruction)
- [RET Pseudo-Instruction](TUTORIAL/CHAPTER-12.md#ret-pseudo-instruction)
- [The Complete Call Chain](TUTORIAL/CHAPTER-12.md#the-complete-call-chain)
- [Nested Calls and the Stack](TUTORIAL/CHAPTER-12.md#nested-calls-and-the-stack)
- [Summary](TUTORIAL/CHAPTER-12.md#summary)

## Assembly Programming

### [Chapter 13: Pseudo-Instructions — What the Assembler Does For You](TUTORIAL/CHAPTER-13.md)
- [Introduction](TUTORIAL/CHAPTER-13.md#introduction)
- [What Is a Pseudo-Instruction?](TUTORIAL/CHAPTER-13.md#what-is-a-pseudo-instruction)
- [Complete Pseudo-Instruction Reference](TUTORIAL/CHAPTER-13.md#complete-pseudo-instruction-reference)
- [Why Pseudo-Instructions Matter](TUTORIAL/CHAPTER-13.md#why-pseudo-instructions-matter)
- [Summary](TUTORIAL/CHAPTER-13.md#summary)

### [Chapter 14: Assembler Directives — Controlling the Assembly Process](TUTORIAL/CHAPTER-14.md)
- [Introduction](TUTORIAL/CHAPTER-14.md#introduction)
- [Sections](TUTORIAL/CHAPTER-14.md#sections)
- [Symbol Visibility](TUTORIAL/CHAPTER-14.md#symbol-visibility)
- [Alignment](TUTORIAL/CHAPTER-14.md#alignment)
- [Data Embedding](TUTORIAL/CHAPTER-14.md#data-embedding)
- [Constant Definitions](TUTORIAL/CHAPTER-14.md#constant-definitions)
- [File Inclusion](TUTORIAL/CHAPTER-14.md#file-inclusion)
- [Labels](TUTORIAL/CHAPTER-14.md#labels)
- [Summary](TUTORIAL/CHAPTER-14.md#summary)

### [Chapter 15: The Calling Convention and Stack Frames](TUTORIAL/CHAPTER-15.md)
- [Introduction](TUTORIAL/CHAPTER-15.md#introduction)
- [The RISC-V ilp32 Calling Convention](TUTORIAL/CHAPTER-15.md#the-risc-v-ilp32-calling-convention)
- [The Stack](TUTORIAL/CHAPTER-15.md#the-stack)
- [Stack Frame Layout](TUTORIAL/CHAPTER-15.md#stack-frame-layout)
- [Function Types in Our Firmware](TUTORIAL/CHAPTER-15.md#function-types-in-our-firmware)
- [Caller-Saved in Action](TUTORIAL/CHAPTER-15.md#caller-saved-in-action)
- [Summary](TUTORIAL/CHAPTER-15.md#summary)

### [Chapter 16: Bitwise Operations for Hardware Programming](TUTORIAL/CHAPTER-16.md)
- [Introduction](TUTORIAL/CHAPTER-16.md#introduction)
- [Bit Numbering](TUTORIAL/CHAPTER-16.md#bit-numbering)
- [The Four Fundamental Bit Operations](TUTORIAL/CHAPTER-16.md#the-four-fundamental-bit-operations)
- [The Read-Modify-Write Pattern](TUTORIAL/CHAPTER-16.md#the-read-modify-write-pattern)
- [Bit Testing](TUTORIAL/CHAPTER-16.md#bit-testing)
- [SIO Atomic Registers](TUTORIAL/CHAPTER-16.md#sio-atomic-registers)
- [Summary](TUTORIAL/CHAPTER-16.md#summary)

### [Chapter 17: Memory-Mapped I/O — Controlling Hardware Through Addresses](TUTORIAL/CHAPTER-17.md)
- [Introduction](TUTORIAL/CHAPTER-17.md#introduction)
- [The Principle](TUTORIAL/CHAPTER-17.md#the-principle)
- [RP2350 Address Space Map](TUTORIAL/CHAPTER-17.md#rp2350-address-space-map)
- [Peripheral Register Access Patterns](TUTORIAL/CHAPTER-17.md#peripheral-register-access-patterns)
- [APB vs SIO](TUTORIAL/CHAPTER-17.md#apb-vs-sio)
- [Summary](TUTORIAL/CHAPTER-17.md#summary)

## Hardware Concepts

### [Chapter 18: The RP2350 — Architecture and Hardware](TUTORIAL/CHAPTER-18.md)
- [Introduction](TUTORIAL/CHAPTER-18.md#introduction)
- [RP2350 Block Diagram](TUTORIAL/CHAPTER-18.md#rp2350-block-diagram)
- [The Hazard3 RISC-V Core](TUTORIAL/CHAPTER-18.md#the-hazard3-risc-v-core)
- [Memory System](TUTORIAL/CHAPTER-18.md#memory-system)
- [Clock Infrastructure](TUTORIAL/CHAPTER-18.md#clock-infrastructure)
- [Reset Infrastructure](TUTORIAL/CHAPTER-18.md#reset-infrastructure)
- [GPIO System](TUTORIAL/CHAPTER-18.md#gpio-system)
- [Boot Sequence](TUTORIAL/CHAPTER-18.md#boot-sequence)
- [Summary](TUTORIAL/CHAPTER-18.md#summary)

## Build System

### [Chapter 19: The Linker Script — Placing Code in Memory](TUTORIAL/CHAPTER-19.md)
- [Introduction](TUTORIAL/CHAPTER-19.md#introduction)
- [Full Source: linker.ld](TUTORIAL/CHAPTER-19.md#full-source-linkerld)
- [Line-by-Line Walkthrough](TUTORIAL/CHAPTER-19.md#line-by-line-walkthrough)
- [Memory Layout After Linking](TUTORIAL/CHAPTER-19.md#memory-layout-after-linking)
- [Summary](TUTORIAL/CHAPTER-19.md#summary)

### [Chapter 20: The Build Pipeline — From Assembly to Flashable Binary](TUTORIAL/CHAPTER-20.md)
- [Introduction](TUTORIAL/CHAPTER-20.md#introduction)
- [The Build Pipeline](TUTORIAL/CHAPTER-20.md#the-build-pipeline)
- [Toolchain Auto-Detection](TUTORIAL/CHAPTER-20.md#toolchain-auto-detection)
- [Stage 1: Assembly](TUTORIAL/CHAPTER-20.md#stage-1-assembly)
- [Stage 2: Linking](TUTORIAL/CHAPTER-20.md#stage-2-linking)
- [Stage 3: Binary Extraction](TUTORIAL/CHAPTER-20.md#stage-3-binary-extraction)
- [Stage 4: UF2 Conversion](TUTORIAL/CHAPTER-20.md#stage-4-uf2-conversion)
- [Error Handling](TUTORIAL/CHAPTER-20.md#error-handling)
- [Flashing the Firmware](TUTORIAL/CHAPTER-20.md#flashing-the-firmware)
- [The Clean Script](TUTORIAL/CHAPTER-20.md#the-clean-script)
- [Summary](TUTORIAL/CHAPTER-20.md#summary)

## Source Code Walkthroughs

### [Chapter 21: Boot Metadata — `image_def.s`](TUTORIAL/CHAPTER-21.md)
- [Introduction](TUTORIAL/CHAPTER-21.md#introduction)
- [Full Source](TUTORIAL/CHAPTER-21.md#full-source)
- [Section Placement](TUTORIAL/CHAPTER-21.md#section-placement)
- [Start Marker](TUTORIAL/CHAPTER-21.md#start-marker)
- [Image Type Item](TUTORIAL/CHAPTER-21.md#image-type-item)
- [Entry Point Item](TUTORIAL/CHAPTER-21.md#entry-point-item)
- [Last-Item Marker](TUTORIAL/CHAPTER-21.md#last-item-marker)
- [Memory Layout](TUTORIAL/CHAPTER-21.md#memory-layout)
- [Summary](TUTORIAL/CHAPTER-21.md#summary)

### [Chapter 22: The Constants File — `constants.s`](TUTORIAL/CHAPTER-22.md)
- [Introduction](TUTORIAL/CHAPTER-22.md#introduction)
- [Full Source](TUTORIAL/CHAPTER-22.md#full-source)
- [How `.equ` Works](TUTORIAL/CHAPTER-22.md#how-equ-works)
- [Stack Constants](TUTORIAL/CHAPTER-22.md#stack-constants)
- [XOSC Constants](TUTORIAL/CHAPTER-22.md#xosc-constants)
- [GPIO Constants](TUTORIAL/CHAPTER-22.md#gpio-constants)
- [SIO Constants](TUTORIAL/CHAPTER-22.md#sio-constants)
- [Summary](TUTORIAL/CHAPTER-22.md#summary)

### [Chapter 23: Stack and Vector Table — `stack.s` and `vector_table.s`](TUTORIAL/CHAPTER-23.md)
- [Introduction](TUTORIAL/CHAPTER-23.md#introduction)
- [`stack.s` — Full Source](TUTORIAL/CHAPTER-23.md#stacks--full-source)
- [Stack Initialization — Line by Line](TUTORIAL/CHAPTER-23.md#stack-initialization--line-by-line)
- [`vector_table.s` — Full Source](TUTORIAL/CHAPTER-23.md#vector_tables--full-source)
- [Vector Table — Line by Line](TUTORIAL/CHAPTER-23.md#vector-table--line-by-line)
- [Contrast with ARM](TUTORIAL/CHAPTER-23.md#contrast-with-arm)
- [Summary](TUTORIAL/CHAPTER-23.md#summary)

### [Chapter 24: Boot Sequence — `reset_handler.s`](TUTORIAL/CHAPTER-24.md)
- [Introduction](TUTORIAL/CHAPTER-24.md#introduction)
- [Full Source](TUTORIAL/CHAPTER-24.md#full-source)
- [The Boot Call Chain](TUTORIAL/CHAPTER-24.md#the-boot-call-chain)
- [Reset_Handler — Line by Line](TUTORIAL/CHAPTER-24.md#reset_handler--line-by-line)
- [Default_Trap_Handler](TUTORIAL/CHAPTER-24.md#default_trap_handler)
- [Init_Trap_Vector](TUTORIAL/CHAPTER-24.md#init_trap_vector)
- [Complete Boot Timeline](TUTORIAL/CHAPTER-24.md#complete-boot-timeline)
- [Summary](TUTORIAL/CHAPTER-24.md#summary)

### [Chapter 25: Oscillator Initialization — `xosc.s`](TUTORIAL/CHAPTER-25.md)
- [Introduction](TUTORIAL/CHAPTER-25.md#introduction)
- [Full Source](TUTORIAL/CHAPTER-25.md#full-source)
- [Init_XOSC — Line by Line](TUTORIAL/CHAPTER-25.md#init_xosc--line-by-line)
- [Enable_XOSC_Peri_Clock — Line by Line](TUTORIAL/CHAPTER-25.md#enable_xosc_peri_clock--line-by-line)
- [Contrast with ARM](TUTORIAL/CHAPTER-25.md#contrast-with-arm)
- [Summary](TUTORIAL/CHAPTER-25.md#summary)

### [Chapter 26: Reset Controller — `reset.s`](TUTORIAL/CHAPTER-26.md)
- [Introduction](TUTORIAL/CHAPTER-26.md#introduction)
- [Full Source](TUTORIAL/CHAPTER-26.md#full-source)
- [Phase 1: Release from Reset](TUTORIAL/CHAPTER-26.md#phase-1-release-from-reset)
- [Phase 2: Wait for Completion](TUTORIAL/CHAPTER-26.md#phase-2-wait-for-completion)
- [The Clear-Bit Pattern](TUTORIAL/CHAPTER-26.md#the-clear-bit-pattern)
- [Summary](TUTORIAL/CHAPTER-26.md#summary)

### [Chapter 27: GPIO Configuration — `gpio.s` Part 1](TUTORIAL/CHAPTER-27.md)
- [Introduction](TUTORIAL/CHAPTER-27.md#introduction)
- [GPIO_Config — Full Source](TUTORIAL/CHAPTER-27.md#gpio_config--full-source)
- [Parameters](TUTORIAL/CHAPTER-27.md#parameters)
- [Stack Frame](TUTORIAL/CHAPTER-27.md#stack-frame)
- [Phase 1: Pad Configuration](TUTORIAL/CHAPTER-27.md#phase-1-pad-configuration)
- [Phase 2: Function Select](TUTORIAL/CHAPTER-27.md#phase-2-function-select)
- [Phase 3: Enable Output](TUTORIAL/CHAPTER-27.md#phase-3-enable-output)
- [Summary](TUTORIAL/CHAPTER-27.md#summary)

### [Chapter 28: GPIO Set/Clear, Delay, and Coprocessor — `gpio.s` Part 2, `delay.s`, `coprocessor.s`](TUTORIAL/CHAPTER-28.md)
- [Introduction](TUTORIAL/CHAPTER-28.md#introduction)
- [GPIO_Set — Full Source](TUTORIAL/CHAPTER-28.md#gpio_set--full-source)
- [GPIO_Clear — Full Source](TUTORIAL/CHAPTER-28.md#gpio_clear--full-source)
- [delay.s — Full Source](TUTORIAL/CHAPTER-28.md#delays--full-source)
- [coprocessor.s — Full Source](TUTORIAL/CHAPTER-28.md#coprocessors--full-source)
- [Summary](TUTORIAL/CHAPTER-28.md#summary)

### [Chapter 29: Application Entry Point — `main.s`](TUTORIAL/CHAPTER-29.md)
- [Introduction](TUTORIAL/CHAPTER-29.md#introduction)
- [Full Source](TUTORIAL/CHAPTER-29.md#full-source)
- [GPIO16 Configuration](TUTORIAL/CHAPTER-29.md#gpio16-configuration)
- [The Blink Loop](TUTORIAL/CHAPTER-29.md#the-blink-loop)
- [Call Graph](TUTORIAL/CHAPTER-29.md#call-graph)
- [Summary](TUTORIAL/CHAPTER-29.md#summary)

## Integration

### [Chapter 30: Full Integration — Build, Flash, Wire, and Test](TUTORIAL/CHAPTER-30.md)
- [Introduction](TUTORIAL/CHAPTER-30.md#introduction)
- [The Complete Source Tree](TUTORIAL/CHAPTER-30.md#the-complete-source-tree)
- [The Complete Execution Path](TUTORIAL/CHAPTER-30.md#the-complete-execution-path)
- [Memory Map After Linking](TUTORIAL/CHAPTER-30.md#memory-map-after-linking)
- [Hardware Wiring](TUTORIAL/CHAPTER-30.md#hardware-wiring)
- [Building the Firmware](TUTORIAL/CHAPTER-30.md#building-the-firmware)
- [Flashing the Firmware](TUTORIAL/CHAPTER-30.md#flashing-the-firmware)
- [Verification](TUTORIAL/CHAPTER-30.md#verification)
- [Summary](TUTORIAL/CHAPTER-30.md#summary)

<br>

# main.s Code
```
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
```

<br>

# License
[Apache License 2.0](https://github.com/mytechnotalent/RP2350_Blink_Driver_RISCV/blob/main/LICENSE)
