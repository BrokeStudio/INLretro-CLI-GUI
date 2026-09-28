@echo off
setlocal

echo Set the BL/RUN switch to BL.
pause

set "FIRMWARE=%~dp0..\firmware\avr_kazzo.hex"
if not exist "%FIRMWARE%" set "FIRMWARE=%~dp0..\build_avr\avr_kazzo.hex"
if not exist "%FIRMWARE%" (
    echo Error: avr_kazzo.hex was not found.
    pause
    exit /b 1
)

"%~dp0commandline\bootloadHID.exe" -r "%FIRMWARE%"

echo You can now set the BL/RUN switch to RUN.
pause
