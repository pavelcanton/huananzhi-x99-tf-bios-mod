@echo off
chcp 65001 >nul
setlocal EnableExtensions
cd /d "%~dp0"

net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Запустите Enable_ReBAR_Windows.bat от имени Администратора!
    echo         Run Enable_ReBAR_Windows.bat as Administrator!
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Enable_ReBAR_Windows.ps1"
pause
