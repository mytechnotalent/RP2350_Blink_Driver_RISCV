@echo off
setlocal
REM ==============================================================================
REM FILE: build.bat
REM
REM DESCRIPTION:
REM Build script for RP2350 RISC-V Blink.
REM
REM BRIEF:
REM Automates the process of assembling, linking, and generating UF2 firmware.
REM
REM AUTHOR: Kevin Thomas
REM CREATION DATE: October 5, 2025
REM UPDATE DATE: March 16, 2026
REM ==============================================================================

echo Building...

set TOOLCHAIN_PREFIX=riscv32-unknown-elf
if not "%1"=="" set TOOLCHAIN_PREFIX=%1

REM ==============================================================================
REM Auto-detect local toolchain path when not already on PATH
REM ==============================================================================
where %TOOLCHAIN_PREFIX%-as >nul 2>nul
if errorlevel 1 (
	if defined RISCV_TOOLCHAIN_BIN (
		if exist "%RISCV_TOOLCHAIN_BIN%\%TOOLCHAIN_PREFIX%-as.exe" set "PATH=%RISCV_TOOLCHAIN_BIN%;%PATH%"
	)
)

where %TOOLCHAIN_PREFIX%-as >nul 2>nul
if errorlevel 1 (
	if exist "%USERPROFILE%\OneDrive\Documents\riscv-toolchain-14\bin\%TOOLCHAIN_PREFIX%-as.exe" set "PATH=%USERPROFILE%\OneDrive\Documents\riscv-toolchain-14\bin;%PATH%"
)

where %TOOLCHAIN_PREFIX%-as >nul 2>nul
if errorlevel 1 (
	if exist "%USERPROFILE%\Documents\riscv-toolchain-14\bin\%TOOLCHAIN_PREFIX%-as.exe" set "PATH=%USERPROFILE%\Documents\riscv-toolchain-14\bin;%PATH%"
)

where %TOOLCHAIN_PREFIX%-as >nul 2>nul
if errorlevel 1 (
	echo.
	echo ERROR: %TOOLCHAIN_PREFIX%-as not found.
	echo Set RISCV_TOOLCHAIN_BIN or install toolchain under:
	echo   %USERPROFILE%\OneDrive\Documents\riscv-toolchain-14\bin
	echo   %USERPROFILE%\Documents\riscv-toolchain-14\bin
	echo.
	goto error
)

REM ==============================================================================
REM Assemble Source Files
REM ==============================================================================
%TOOLCHAIN_PREFIX%-as -g -march=rv32imac_zicsr -mabi=ilp32 vector_table.s -o vector_table.o
if errorlevel 1 goto error
%TOOLCHAIN_PREFIX%-as -g -march=rv32imac_zicsr -mabi=ilp32 reset_handler.s -o reset_handler.o
if errorlevel 1 goto error
%TOOLCHAIN_PREFIX%-as -g -march=rv32imac_zicsr -mabi=ilp32 stack.s -o stack.o
if errorlevel 1 goto error
%TOOLCHAIN_PREFIX%-as -g -march=rv32imac_zicsr -mabi=ilp32 xosc.s -o xosc.o
if errorlevel 1 goto error
%TOOLCHAIN_PREFIX%-as -g -march=rv32imac_zicsr -mabi=ilp32 reset.s -o reset.o
if errorlevel 1 goto error
%TOOLCHAIN_PREFIX%-as -g -march=rv32imac_zicsr -mabi=ilp32 coprocessor.s -o coprocessor.o
if errorlevel 1 goto error
%TOOLCHAIN_PREFIX%-as -g -march=rv32imac_zicsr -mabi=ilp32 gpio.s -o gpio.o
if errorlevel 1 goto error
%TOOLCHAIN_PREFIX%-as -g -march=rv32imac_zicsr -mabi=ilp32 delay.s -o delay.o
if errorlevel 1 goto error
%TOOLCHAIN_PREFIX%-as -g -march=rv32imac_zicsr -mabi=ilp32 main.s -o main.o
if errorlevel 1 goto error
%TOOLCHAIN_PREFIX%-as -g -march=rv32imac_zicsr -mabi=ilp32 image_def.s -o image_def.o
if errorlevel 1 goto error

REM ==============================================================================
REM Link Object Files
REM ==============================================================================
%TOOLCHAIN_PREFIX%-ld -g -T linker.ld vector_table.o reset_handler.o stack.o xosc.o reset.o coprocessor.o gpio.o delay.o main.o image_def.o -o blink.elf
if errorlevel 1 goto error

REM ==============================================================================
REM Create Raw Binary from ELF
REM ==============================================================================
%TOOLCHAIN_PREFIX%-objcopy -O binary blink.elf blink.bin
if errorlevel 1 goto error

REM ==============================================================================
REM Create UF2 Image for RP2350
REM -b 0x10000000 : base address
REM -f 0xe48bff5a : RP2350 RISC-V family ID
REM ==============================================================================
python uf2conv.py -b 0x10000000 -f 0xe48bff5a -o blink.uf2 blink.bin
if errorlevel 1 goto error

REM ==============================================================================
REM Success Message and Flashing Instructions
REM ==============================================================================
echo.
echo =================================
echo SUCCESS! Created blink.uf2
echo =================================
echo.
echo To flash via UF2:
echo   1. Hold BOOTSEL button
echo   2. Plug in USB
echo   3. Copy blink.uf2 to RP2350 drive
echo.
echo To flash via OpenOCD (debug probe):
echo   openocd -f interface/cmsis-dap.cfg -f target/rp2350.cfg -c "adapter speed 5000" -c "program blink.elf verify reset exit"
echo.
echo Optional explicit toolchain prefix:
echo   .\build.bat riscv-none-elf
echo.
goto end

REM ==============================================================================
REM Error Handling
REM ==============================================================================
:error
echo.
echo BUILD FAILED!
echo.

:end
endlocal
