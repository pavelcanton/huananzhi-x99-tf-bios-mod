@echo off
"%SystemRoot%\System32\chcp.com" 65001 <nul >nul
setlocal EnableExtensions DisableDelayedExpansion
set "ERRORLEVEL="

set "HAS_ARGS=0"
set "REBAR_ACTION="
set "ARG_BAD=0"

set "_TMPDIR=%TEMP%"
if not exist "%_TMPDIR%\" set "_TMPDIR=%TMP%"
if not exist "%_TMPDIR%\" set "_TMPDIR=%LOCALAPPDATA%\Temp"
if not exist "%_TMPDIR%\" set "_TMPDIR=%SystemRoot%\Temp"
set "_ARGTMP=%_TMPDIR%\x99tf_rebar_%RANDOM%_%RANDOM%.tmp"
set "PROMPT=$_"
> "%_ARGTMP%" (
    echo on
    for %%# in (1) do rem #%*#
    @echo off
)
set "_RAW="
if not exist "%_ARGTMP%" (
    set "HAS_ARGS=1"
    set "ARG_BAD=1"
    goto :args_checked
)
for /f "usebackq delims=" %%L in ("%_ARGTMP%") do set "_RAW=%%L"
del /f /q "%_ARGTMP%" >nul 2>&1

setlocal EnableDelayedExpansion
set "_S=!_RAW!"
if not defined _S (
    endlocal & set "HAS_ARGS=1" & set "ARG_BAD=1"
    goto :args_checked
)
if /I "!_S:~0,5!"=="rem #" set "_S=!_S:~5!"
:trim_after_hash
if defined _S if "!_S:~-1!"==" " (
    set "_S=!_S:~0,-1!"
    goto :trim_after_hash
)
if defined _S if "!_S:~-1!"=="#" set "_S=!_S:~0,-1!"
:trim_lead_space
if defined _S if "!_S:~0,1!"==" " (
    set "_S=!_S:~1!"
    goto :trim_lead_space
)
:trim_tail_space
if defined _S if "!_S:~-1!"==" " (
    set "_S=!_S:~0,-1!"
    goto :trim_tail_space
)
if not defined _S (
    endlocal & set "HAS_ARGS=0" & set "REBAR_ACTION=" & set "ARG_BAD=0"
    goto :args_checked
)
:collapse_spaces
set "_PREV=!_S!"
set "_S=!_S:  = !"
if not "!_S!"=="!_PREV!" goto :collapse_spaces

if not "!_S:'=!"=="!_S!" (
    endlocal & set "HAS_ARGS=1" & set "REBAR_ACTION=" & set "ARG_BAD=1"
    goto :args_checked
)
set "_Q=!_S:"='!"
for %%A in (Enable Disable Status) do (
    if /I "!_Q!"=="-Action %%A" (
        endlocal & set "HAS_ARGS=1" & set "REBAR_ACTION=%%A" & set "ARG_BAD=0"
        goto :args_checked
    )
    if /I "!_Q!"=="-Action '%%A'" (
        endlocal & set "HAS_ARGS=1" & set "REBAR_ACTION=%%A" & set "ARG_BAD=0"
        goto :args_checked
    )
    if /I "!_Q!"=="'-Action' %%A" (
        endlocal & set "HAS_ARGS=1" & set "REBAR_ACTION=%%A" & set "ARG_BAD=0"
        goto :args_checked
    )
    if /I "!_Q!"=="'-Action' '%%A'" (
        endlocal & set "HAS_ARGS=1" & set "REBAR_ACTION=%%A" & set "ARG_BAD=0"
        goto :args_checked
    )
    if /I "!_Q!"=="-Action:%%A" (
        endlocal & set "HAS_ARGS=1" & set "REBAR_ACTION=%%A" & set "ARG_BAD=0"
        goto :args_checked
    )
    if /I "!_Q!"=="'-Action:%%A'" (
        endlocal & set "HAS_ARGS=1" & set "REBAR_ACTION=%%A" & set "ARG_BAD=0"
        goto :args_checked
    )
    if /I "!_Q!"=="-Action:'%%A'" (
        endlocal & set "HAS_ARGS=1" & set "REBAR_ACTION=%%A" & set "ARG_BAD=0"
        goto :args_checked
    )
    if /I "!_Q!"=="%%A" (
        endlocal & set "HAS_ARGS=1" & set "REBAR_ACTION=%%A" & set "ARG_BAD=0"
        goto :args_checked
    )
    if /I "!_Q!"=="'%%A'" (
        endlocal & set "HAS_ARGS=1" & set "REBAR_ACTION=%%A" & set "ARG_BAD=0"
        goto :args_checked
    )
)
endlocal & set "HAS_ARGS=1" & set "REBAR_ACTION=" & set "ARG_BAD=1"

:args_checked
if "%ARG_BAD%"=="1" (
    echo [ERROR] Недопустимые аргументы командной строки!
    echo         Invalid command-line arguments. Usage: Enable_ReBAR_Windows.bat [-Action Enable^|Disable^|Status]
    exit /b 1
)

pushd "%~dp0" >nul 2>&1
set "DIR_ERR=%errorlevel%"
if not "%DIR_ERR%"=="0" (
    echo [ERROR] Не удалось перейти в каталог скрипта!
    echo         Failed to switch to script directory!
    if "%HAS_ARGS%"=="0" pause
    exit /b 1
)

"%SystemRoot%\System32\fltmc.exe" >nul 2>&1
set "ADM_ERR=%errorlevel%"
if not "%ADM_ERR%"=="0" (
    echo [ERROR] Запустите Enable_ReBAR_Windows.bat от имени Администратора!
    echo         Run Enable_ReBAR_Windows.bat as Administrator!
    popd >nul 2>&1
    if "%HAS_ARGS%"=="0" pause
    exit /b 1
)

if defined REBAR_ACTION (
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File ".\Enable_ReBAR_Windows.ps1" -Action %REBAR_ACTION%
) else (
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File ".\Enable_ReBAR_Windows.ps1"
)
set "PS_ERR=%errorlevel%"
if not "%PS_ERR%"=="0" (
    echo [ERROR] Enable_ReBAR_Windows.ps1 завершился с ошибкой %PS_ERR%.
)
popd >nul 2>&1
if "%HAS_ARGS%"=="0" pause
exit /b %PS_ERR%
