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
