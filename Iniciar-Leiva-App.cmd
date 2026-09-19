@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\start-leiva-emulator.ps1"
if errorlevel 1 (
  echo.
  echo No se pudo iniciar Leiva Interna. Revisa el mensaje anterior.
  pause
)

endlocal
