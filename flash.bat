@echo off
chcp 65001 >nul
setlocal EnableExtensions
cd /d "%~dp0"

echo ============================================================================
echo   HUANANZHI X99-TF (GHX99015) - Modded BIOS v2.1 Flasher (Intel FPT)
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

:: Safety check #1: SMBIOS board & BIOS sanity check (prevents flashing on wrong X99 board!)
set "BOARD_CHK="
for /f "usebackq delims=" %%S in (`powershell -NoProfile -Command "$bb=Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue; $bi=Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue; $txt=($bb.Manufacturer+' '+$bb.Product+' '+$bi.SMBIOSBIOSVersion+' '+$bi.Name).Trim(); if ($txt -like '*X99-TF*' -or $txt -like '*GHX99014*' -or $txt -like '*GHX99015*') { 'OK' } elseif ($txt) { 'MISMATCH: ' + $txt } else { 'UNKNOWN' }"`) do set "BOARD_CHK=%%S"
if "%BOARD_CHK%"=="OK" goto :check_bitlocker
echo [WARN] Плата по SMBIOS не распознана как HUANANZHI X99-TF ^(GHX99014/GHX99015^)!
echo        Обнаружено: %BOARD_CHK%
echo        Прошивка чужой платы приведёт к кирпичу!
set "FORCE_BRD="
set /p "FORCE_BRD=Вы на 100%% уверены, что это X99-TF? Введите X99TF для продолжения: "
if /I not "%FORCE_BRD%"=="X99TF" (
    echo Прошивка отменена ради безопасности.
    pause
    exit /b 1
)
echo.

:check_bitlocker
:: Safety check #2: BitLocker protection warning
set "BL_STATE=OFF"
for /f "usebackq delims=" %%L in (`powershell -NoProfile -Command "$v=Get-BitLockerVolume -MountPoint 'C:' -ErrorAction SilentlyContinue; if ($v -and $v.ProtectionStatus -eq 'On') { 'ON' } else { 'OFF' }"`) do set "BL_STATE=%%L"
if "%BL_STATE%"=="ON" (
    echo [WARN] На диске C: включён BitLocker! Перед прошивкой BIOS/UEFI/TPM
    echo        приостановите BitLocker или сохраните ключ восстановления, иначе
    echo        Windows запросит Recovery Key после перезагрузки!
    echo.
)

echo Выберите стартовый профиль ^(в v2.1 андервольт, Ring, ядра, ОЗУ и лимиты
echo можно в любой момент менять прямо в меню BIOS с сохранением по F10^):
echo.
echo   [1] Safe Stock      - 0/0 mV, динамический Ring, C-States ON, IMC Auto
echo                         ^(максимальная стабильность; лучший выбор для Xeon v4^)
echo   [2] Performance OC  - -50/-40 mV, лок Ring на макс., C-States OFF, тюнинг IMC
echo                         ^(РЕКОМЕНДУЕТСЯ для Xeon E5 v3; ОЗУ и tREFI в Auto;
echo                          сброс CMOS всегда откатывает профиль в Safe Stock!^)
echo.
set /p "PCHOICE=Введите номер профиля [1-2]: "

if "%PCHOICE%"=="1" goto :prof1
if "%PCHOICE%"=="2" goto :prof2
echo [ERROR] Неверный выбор профиля.
pause
exit /b 1

:prof1
set "PDIR=01_Safe_Stock"
set "PTAG=SafeStock"
set "PDESC=Safe Stock (0/0 mV, Dynamic Ring, C-States ON, IMC/RAM Auto, All Cores)"
goto :pick_mode

:prof2
set "PDIR=02_Performance_OC"
set "PTAG=PerfOC"
set "PDESC=Performance OC (-50/-40 mV, Ring Lock, C-States OFF, Safe IMC Tweaks, RAM Auto, All Cores)"
goto :pick_mode

:pick_mode
echo.
echo Выберите режим загрузки ^(память в Auto, SmartFan V3 + S3 Fix включен^):
echo   [1] Legacy CSM          ^(TPM=OFF, SecureBoot=OFF, CSM=ON,  Above4G=OFF, ReBAR=0^)
echo   [2] UEFI + Secure Boot  ^(TPM=OFF, SecureBoot=ON,  CSM=OFF, Above4G=ON,  ReBAR=0x20^)
echo   [3] Full UEFI+SB+TPM2.0 ^(TPM=ON,  SecureBoot=ON,  CSM=OFF, Above4G=ON,  ReBAR=0x20^)
echo.
echo ВНИМАНИЕ: Пункты Secure Boot и TPM в меню BIOS скрыты - выбирайте нужный
echo           режим здесь. В UEFI-сборках вшиты ключи MS 2011+2023, dbx (443)
echo           и чистый Community PK ^(уязвимость PKfail устранена^).
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
set "IS_UEFI_MODE=0"
goto :check_file

:mode2
set "MTAG=2_UEFI_SB"
set "MDESC=Pure UEFI + ReBAR (0x20) + Secure Boot ON (2011+2023, no PKfail) + TPM OFF"
set "IS_UEFI_MODE=1"
goto :check_file

:mode3
set "MTAG=3_UEFI_SB_TPM"
set "MDESC=Pure UEFI + ReBAR (0x20) + Secure Boot ON (2011+2023, no PKfail) + TPM 2.0 ON"
set "IS_UEFI_MODE=1"
goto :check_file

:check_file
:: Safety check #3: Warn if flashing Pure UEFI build while Windows is booted in Legacy MBR mode
if not "%IS_UEFI_MODE%"=="1" goto :check_bin
set "FW_TYPE="
for /f "usebackq delims=" %%F in (`powershell -NoProfile -Command "if ($env:firmware_type) { $env:firmware_type } elseif (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State') { 'UEFI' } else { 'Legacy' }"`) do set "FW_TYPE=%%F"
if /I "%FW_TYPE%"=="Legacy" (
    echo.
    echo [WARN] Текущая Windows загружена в режиме Legacy BIOS/MBR ^(firmware_type=Legacy^)!
    echo        После прошивки %MTAG% ^(CSM=OFF^) MBR-диск не загрузится без mbr2gpt
    echo        или временного включения CSM Support в BIOS!
)

:check_bin
set "BIN_PATH=%PDIR%\%MTAG%\X99TF_GHX99015_%PTAG%_%MTAG%_8MB_FPT.bin"
set "BIN_REL_POSIX=%PDIR%/%MTAG%/X99TF_GHX99015_%PTAG%_%MTAG%_8MB_FPT.bin"
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

:: Safety check #4: Verify SHA-256 against SHA256SUMS.txt if present
if not exist "SHA256SUMS.txt" goto :step1_fpt
set "SHA_CHK=ERR"
for /f "usebackq delims=" %%H in (`powershell -NoProfile -Command "$rel='%BIN_REL_POSIX%'; $exp=$null; foreach ($l in Get-Content 'SHA256SUMS.txt') { $t=$l.Trim(); if ($t.EndsWith('*'+$rel) -or $t.EndsWith(' '+$rel)) { $exp=($t -split '\s+')[0].ToLower(); break } }; if (-not $exp) { 'MISSING' } else { $ah=(Get-FileHash '%BIN_PATH%' -Algorithm SHA256).Hash.ToLower(); if ($exp -eq $ah) { 'OK' } else { 'BAD' } }"`) do set "SHA_CHK=%%H"
if not "%SHA_CHK%"=="OK" (
    echo [ERROR] Контрольная сумма SHA-256 файла "%BIN_PATH%" не совпадает с SHA256SUMS.txt ^(%SHA_CHK%^)!
    echo         Файл повреждён! Прошивка отменена.
    pause
    exit /b 1
)
echo [OK] SHA-256 прошивки подтверждён по SHA256SUMS.txt.

:step1_fpt

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
set "BACKUP_FULL_REL=backup_full_16MB_%TS%.bin"
set "BACKUP_BIOS_REL=backup_bios_8MB_%TS%.bin"
set "BACKUP_FULL=%~dp0%BACKUP_FULL_REL%"
set "BACKUP_BIOS=%~dp0%BACKUP_BIOS_REL%"

echo.
echo [2/4] Снятие резервной копии текущего BIOS...
echo       Пробую снять ПОЛНЫЙ 16 МБ дамп ^(FD + ME + BIOS^)...
pushd "%~dp0tools"
fptw64.exe -d "..\%BACKUP_FULL_REL%"
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
fptw64.exe -bios -d "..\%BACKUP_BIOS_REL%"
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
echo     Профиль       : %PDESC%
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
fptw64.exe -bios -f "..\%BIN_PATH%"
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
fptw64.exe -bios -verify "..\%BIN_PATH%"
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
echo   Подсказка: если меняете андервольт/тайминги в BIOS и нет старта -
echo   сброс CMOS ^(JCMOS^) всегда безопасно вернёт профиль Safe Stock.
echo ============================================================================
pause
exit /b 0
