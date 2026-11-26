@echo off
"%SystemRoot%\System32\chcp.com" 65001 <nul >nul
setlocal EnableExtensions DisableDelayedExpansion
set "ERRORLEVEL="
set "_ARG1=%~1"

pushd "%~dp0" >nul 2>&1
set "DIR_ERR=%errorlevel%"
if not "%DIR_ERR%"=="0" (
    echo [ERROR] Не удалось перейти в каталог скрипта!
    echo         Failed to switch to script directory!
    if not defined _ARG1 pause
    exit /b 1
)

"%SystemRoot%\System32\fltmc.exe" >nul 2>&1
set "ADM_ERR=%errorlevel%"
if not "%ADM_ERR%"=="0" (
    echo [ERROR] Запустите Enable_ReBAR_Windows.bat от имени Администратора!
    echo         Run Enable_ReBAR_Windows.bat as Administrator!
    popd >nul 2>&1
    if not defined _ARG1 pause
    exit /b 1
)

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File ".\Enable_ReBAR_Windows.ps1" %*
set "PS_ERR=%errorlevel%"
if not "%PS_ERR%"=="0" (
    echo [ERROR] Enable_ReBAR_Windows.ps1 завершился с ошибкой %PS_ERR%.
)
popd >nul 2>&1
if not defined _ARG1 pause
exit /b %PS_ERR%
