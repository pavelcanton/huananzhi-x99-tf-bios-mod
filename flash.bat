@echo off
chcp 65001 >nul
setlocal EnableExtensions
cd /d "%~dp0"

echo ============================================================================
echo   HUANANZHI X99-TF (GHX99015) - Universal Modded BIOS Flasher (Intel FPT)
echo ============================================================================
echo.

net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Запустите flash.bat от имени Администратора!
    echo         Run flash.bat as Administrator!
    echo.
    pause
    exit /b 1
)

if not exist "tools\fptw64.exe" (
    echo [ERROR] Не найден tools\fptw64.exe!
    pause
    exit /b 1
)

echo Выберите тир андервольта CPU ^(Xeon E5 v3; для v4 андервольт игнорируется^):
echo   [1]  0 /  0 mV   - Stock Voltage ^(чистый Turbo Boost Unlock, без андервольта^)
echo   [2] -40 / -30 mV - Mild          ^(сверхмягкий, для слабых/неудачных кристаллов^)
echo   [3] -50 / -50 mV - Balanced      ^(универсальный, рекомендуется для большинства v3^)
echo   [4] -70 / -50 mV - Performance   ^(для удачных кристаллов; ниже нагрев, выше буст^)
echo.
set /p "TCHOICE=Введите номер тира [1-4]: "

if "%TCHOICE%"=="1" goto :tier1
if "%TCHOICE%"=="2" goto :tier2
if "%TCHOICE%"=="3" goto :tier3
if "%TCHOICE%"=="4" goto :tier4
echo [ERROR] Неверный выбор тира.
pause
exit /b 1

:tier1
set "TDIR=01_UV_0_0_Stock"
set "TTAG=UV0_0"
set "TDESC=0 / 0 mV (Stock Voltage)"
goto :pick_mode

:tier2
set "TDIR=02_UV_40_30_Mild"
set "TTAG=UV40_30"
set "TDESC=-40 mV Core / -30 mV Cache"
goto :pick_mode

:tier3
set "TDIR=03_UV_50_50_Balanced"
set "TTAG=UV50_50"
set "TDESC=-50 mV Core / -50 mV Cache"
goto :pick_mode

:tier4
set "TDIR=04_UV_70_50_Perf"
set "TTAG=UV70_50"
set "TDESC=-70 mV Core / -50 mV Cache"
goto :pick_mode

:pick_mode
echo.
echo Выберите режим работы ^(память во всех вариантах в Auto, SmartFan V3 включен^):
echo   [1] Legacy CSM       ^(TPM=OFF, SecureBoot=OFF, CSM=ON,  Above4G=OFF, ReBAR=0^)
echo   [2] UEFI + SecureBoot^(TPM=OFF, SecureBoot=ON,  CSM=OFF, Above4G=ON,  ReBAR=0x20^)
echo   [3] Full UEFI+SB+TPM ^(TPM=ON,  SecureBoot=ON,  CSM=OFF, Above4G=ON,  ReBAR=0x20^)
echo.
echo ВНИМАНИЕ: В меню BIOS платы GHX99015 пункты Secure Boot и TPM скрыты,
echo           поэтому выбрать нужный режим нужно именно здесь перед прошивкой!
echo.
set /p "MCHOICE=Введите номер режима [1-3]: "

if "%MCHOICE%"=="1" goto :mode1
if "%MCHOICE%"=="2" goto :mode2
if "%MCHOICE%"=="3" goto :mode3
echo [ERROR] Неверный выбор режима.
pause
exit /b 1

:mode1
set "MTAG=1_Legacy"
set "MDESC=Legacy CSM + No SecureBoot + No TPM (ReBAR can be enabled later in UEFI OS)"
goto :check_file

:mode2
set "MTAG=2_UEFI_SB"
set "MDESC=Pure UEFI + ReBAR (0x20) + Secure Boot ON + TPM OFF"
goto :check_file

:mode3
set "MTAG=3_UEFI_SB_TPM"
set "MDESC=Pure UEFI + ReBAR (0x20) + Secure Boot ON + TPM 2.0 ON"
goto :check_file

:check_file
set "BIN_PATH=%TDIR%\%MTAG%\X99TF_GHX99015_%TTAG%_%MTAG%_8MB_FPT.bin"
if not exist "%BIN_PATH%" (
    echo [ERROR] Файл не найден: "%BIN_PATH%"
    pause
    exit /b 1
)

for %%A in ("%BIN_PATH%") do set "BIN_SIZE=%%~zA"
if not "%BIN_SIZE%"=="8388608" (
    echo [ERROR] Неверный размер файла %BIN_SIZE% байт ^(ожидалось 8388608^).
    pause
    exit /b 1
)

echo.
echo [1/4] Проверка SPI-флешки через Intel FPT...
pushd "%~dp0tools"
fptw64.exe -i
set "FPT_ERR=%errorlevel%"
popd
if not "%FPT_ERR%"=="0" (
    echo [ERROR] fptw64.exe -i завершился с ошибкой %FPT_ERR%. Прошивка отменена.
    pause
    exit /b 1
)

for /f %%T in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%T"
set "BACKUP_FULL=%~dp0backup_full_16MB_%TS%.bin"
set "BACKUP_BIOS=%~dp0backup_bios_8MB_%TS%.bin"

echo.
echo [2/4] Снятие резервной копии текущего BIOS...
echo       Пробую снять ПОЛНЫЙ 16 МБ дамп ^(FD + ME + BIOS^)...
pushd "%~dp0tools"
fptw64.exe -d "%BACKUP_FULL%"
set "FULL_ERR=%errorlevel%"
popd

if not "%FULL_ERR%"=="0" goto :try_8mb_backup
if not exist "%BACKUP_FULL%" goto :try_8mb_backup
for %%F in ("%BACKUP_FULL%") do set "FULL_SIZE=%%~zF"
if "%FULL_SIZE%"=="16777216" goto :full_backup_ok

:try_8mb_backup
if exist "%BACKUP_FULL%" del /f /q "%BACKUP_FULL%" >nul 2>&1
echo.
echo [WARN] Полный 16 МБ дамп не разрешён платой ^(или размер не 16 МБ^).
echo        Снимаю полный 8 МБ регион BIOS...
pushd "%~dp0tools"
fptw64.exe -bios -d "%BACKUP_BIOS%"
set "BAK_ERR=%errorlevel%"
popd
if not "%BAK_ERR%"=="0" (
    echo [ERROR] Не удалось снять бэкап! Прошивка отменена.
    pause
    exit /b 1
)

for %%B in ("%BACKUP_BIOS%") do set "BAK_SIZE=%%~zB"
if not "%BAK_SIZE%"=="8388608" (
    echo [ERROR] Размер бэкапа некорректный ^(%BAK_SIZE% байт^). Прошивка отменена.
    pause
    exit /b 1
)
set "BACKUP_FILE=%BACKUP_BIOS%"
set "BACKUP_DESC=Регион BIOS 8 МБ (8388608 байт)"
goto :backup_ready

:full_backup_ok
set "BACKUP_FILE=%BACKUP_FULL%"
set "BACKUP_DESC=Полный 16 МБ дамп (16777216 байт, FD + ME + BIOS)"

:backup_ready
echo.
echo [OK] Бэкап успешно создан:
echo      "%BACKUP_FILE%"
echo      Тип: %BACKUP_DESC%

echo.
echo ============================================================================
echo   ПЕРЕД ПРОШИВКОЙ ПРОВЕРЬТЕ И ПЕРЕНЕСИТЕ БЭКАП!
echo     Файл прошивки : %BIN_PATH%
echo     Андервольт    : %TDESC%
echo     Режим         : %MDESC%
echo     Ваш бэкап     : %BACKUP_FILE%
echo ============================================================================
echo   1. Перенесите/скопируйте бэкап куда удобно ^(в облако, на флешку или другой
echo      ПК^), чтобы в случае чего восстановить плату.
echo   2. НЕ выключайте ПК во время прошивки!
echo.
set /p "CONFIRM=Бэкап сохранён отдельно и вы готовы шить? Введите YES и нажмите Enter: "
if /I not "%CONFIRM%"=="YES" (
    echo Прошивка отменена пользователем. Бэкап оставлен в "%BACKUP_FILE%".
    pause
    exit /b 0
)

echo.
echo [3/4] Прошивка "%BIN_PATH%" ^(только 8 МБ BIOS-регион^)...
pushd "%~dp0tools"
fptw64.exe -bios -f "%~dp0%BIN_PATH%"
set "FL_ERR=%errorlevel%"
popd
if not "%FL_ERR%"=="0" (
    echo [ERROR] Ошибка во время прошивки! НЕ перезагружайте ПК!
    echo         Повторите прошивку, пока система запущена. Бэкап: "%BACKUP_FILE%".
    pause
    exit /b 1
)

echo.
echo [4/4] Контрольная верификация прошитого BIOS...
pushd "%~dp0tools"
fptw64.exe -bios -verify "%~dp0%BIN_PATH%"
set "VF_ERR=%errorlevel%"
popd
if not "%VF_ERR%"=="0" (
    echo [ERROR] Верификация не пройдена! НЕ перезагружайте ПК, прошейте заново!
    echo         Бэкап: "%BACKUP_FILE%".
    pause
    exit /b 1
)

echo.
echo ============================================================================
echo   ГОТОВО! Прошивка и верификация прошли на 100%%!
echo   Бэкап сохранён: "%BACKUP_FILE%"
echo   Перезагрузите ПК. Первый запуск и тренировка RAM займут ~15-30 сек.
echo ============================================================================
pause
exit /b 0
