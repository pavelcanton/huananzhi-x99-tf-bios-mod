@echo off
"%SystemRoot%\System32\chcp.com" 65001 >nul
setlocal EnableExtensions DisableDelayedExpansion
set "ERRORLEVEL="
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "SYS_DRIVE=%SystemDrive%"
if not defined SYS_DRIVE set "SYS_DRIVE=C:"

pushd "%~dp0" >nul 2>&1
set "DIR_ERR=%errorlevel%"
if not "%DIR_ERR%"=="0" (
    echo [ERROR] Не удалось перейти в каталог скрипта!
    pause
    exit /b 1
)
set "WORK_DIR=%CD%"

echo ============================================================================
echo   HUANANZHI X99-TF (GHX99015) - Modded BIOS v2.1 Flasher (Intel FPT)
echo ============================================================================
echo.

"%SystemRoot%\System32\fltmc.exe" >nul 2>&1
set "ADM_ERR=%errorlevel%"
if not "%ADM_ERR%"=="0" (
    echo [ERROR] Запустите flash.bat от имени Администратора!
    echo         Run flash.bat as Administrator!
    echo.
    goto :exit_fail
)

if not exist "tools\fptw64.exe" (
    echo [ERROR] Не найден tools\fptw64.exe!
    goto :exit_fail
)

:: Safety check #1: Strict SMBIOS board & BIOS check (rejects incompatible X99-TF-Q / X99-TF_Q / X99-TF Q / X99-TF8 / X99-TF GAMING!)
set "BOARD_CHK="
for /f "usebackq delims=" %%S in (`call "%PS_EXE%" -NoProfile -InputFormat None -Command "$errs=@(); $bb=$null; $bi=$null; try { $bb=Get-CimInstance Win32_BaseBoard -ErrorAction Stop } catch { $errs += ('BaseBoard: ' + $_.Exception.Message) }; try { $bi=Get-CimInstance Win32_BIOS -ErrorAction Stop } catch { $errs += ('BIOS: ' + $_.Exception.Message) }; $txt=(($bb.Manufacturer+' '+$bb.Product+' '+$bi.SMBIOSBIOSVersion+' '+$bi.Name) -replace '\s+',' ').Trim(); $bad=($txt -match '(?<![A-Za-z0-9])X99-TF(?:[-_][A-Za-z0-9]|[A-Za-z0-9])') -or ($txt -match '(?<![A-Za-z0-9])X99-TF\s+(?:Q|GAMING)(?![A-Za-z0-9])'); $ok=(-not $bad) -and (($txt -match '(?<![A-Za-z0-9])X99-TF(?![A-Za-z0-9_-])') -or ($txt -match '(?<![A-Za-z0-9])GHX9901[45](?![A-Za-z0-9])')); $re='[\r\n\x22\x25\x26\x21\x28\x29\x3C\x3E\x5E\x7C]'; if ($ok) { 'OK' } elseif ($txt -and $errs.Count -gt 0) { 'MISMATCH: ' + ($txt -replace $re,'_').Trim() + ' [WMI: ' + (($errs -join '; ') -replace $re,'_').Trim() + ']' } elseif ($txt) { 'MISMATCH: ' + ($txt -replace $re,'_').Trim() } elseif ($errs.Count -gt 0) { 'WMI_ERROR: ' + (($errs -join '; ') -replace $re,'_').Trim() } else { 'UNKNOWN (empty SMBIOS)' }" 2^>nul`) do set "BOARD_CHK=%%S"
if not defined BOARD_CHK set "BOARD_CHK=UNKNOWN (PowerShell/WMI unavailable)"
setlocal EnableDelayedExpansion
if "!BOARD_CHK!"=="OK" (
    endlocal
    goto :check_bitlocker
)
endlocal
echo [WARN] Плата по SMBIOS не распознана как HUANANZHI X99-TF ^(GHX99014/GHX99015^)!
call :safe_echo "       Обнаружено: " BOARD_CHK
echo        Прошивка чужой платы ^(например X99-TF-Q / X99-TF8 / X99-TF GAMING^) приведёт к кирпичу!
set "FORCE_BRD="
set /p "FORCE_BRD=Вы на 100%% уверены, что это X99-TF? Введите X99TF для продолжения: "
setlocal EnableDelayedExpansion
if /I not "!FORCE_BRD!"=="X99TF" (
    endlocal
    echo Прошивка отменена ради безопасности.
    goto :exit_fail
)
endlocal
echo.

:check_bitlocker
:: Safety check #2: BitLocker protection check on %SystemDrive% (fails-safe to UNKNOWN, NEVER OFF!)
set "BL_STATE=UNKNOWN"
for /f "usebackq delims=" %%L in (`call "%PS_EXE%" -NoProfile -InputFormat None -Command "try { $d=if($env:SYS_DRIVE){$env:SYS_DRIVE}else{'C:'}; $res=$null; if(Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue){ try { $v=Get-BitLockerVolume -MountPoint $d -ErrorAction Stop; if($null -ne $v){ $res=if($v.ProtectionStatus -eq 'On' -or $v.ProtectionStatus -eq 1){'ON'}else{'OFF'} } } catch { $res=$null } }; if($null -eq $res){ $w=Get-CimInstance -Namespace 'root\CIMV2\Security\MicrosoftVolumeEncryption' -ClassName Win32_EncryptableVolume -Filter ('DriveLetter=' + [char]39 + $d.Replace([char]39,'') + [char]39) -ErrorAction Stop; if($null -ne $w){ $res=if($w.ProtectionStatus -eq 1){'ON'}else{'OFF'} } }; if($res){$res}else{'UNKNOWN'} } catch {'UNKNOWN'}" 2^>nul`) do set "BL_STATE=%%L"
if not defined BL_STATE set "BL_STATE=UNKNOWN"
if /I "%BL_STATE%"=="ON" (
    call :safe_echo "[WARN] На системном диске включён BitLocker: " SYS_DRIVE
    echo        Перед прошивкой BIOS/UEFI/TPM приостановите BitLocker или сохраните
    echo        ключ восстановления, иначе Windows запросит Recovery Key после ребута!
    echo.
) else if /I not "%BL_STATE%"=="OFF" (
    call :safe_echo "[WARN] Не удалось определить статус BitLocker на диске: " SYS_DRIVE
    call :safe_echo "       Статус проверки: " BL_STATE
    echo        Убедитесь вручную, что BitLocker выключен или ключ восстановления сохранён!
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
set "PCHOICE="
set /p "PCHOICE=Введите номер профиля [1-2]: "

setlocal EnableDelayedExpansion
if "!PCHOICE!"=="1" (
    endlocal
    goto :prof1
)
if "!PCHOICE!"=="2" (
    endlocal
    goto :prof2
)
endlocal
echo [ERROR] Неверный выбор профиля.
goto :exit_fail

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
set "MCHOICE="
set /p "MCHOICE=Введите номер режима [1-3]: "

setlocal EnableDelayedExpansion
if "!MCHOICE!"=="1" (
    endlocal
    goto :mode1
)
if "!MCHOICE!"=="2" (
    endlocal
    goto :mode2
)
if "!MCHOICE!"=="3" (
    endlocal
    goto :mode3
)
endlocal
echo [ERROR] Неверный выбор режима.
goto :exit_fail

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
:: Safety check #3: Warn if flashing Pure UEFI build when UEFI boot mode is NOT confirmed (Legacy or Unknown)
set "LEGACY_WARN=0"
if not "%IS_UEFI_MODE%"=="1" goto :check_bin
set "FW_TYPE=Unknown"
for /f "usebackq delims=" %%F in (`call "%PS_EXE%" -NoProfile -InputFormat None -Command "$m='Unknown'; try { $q=[char]34; Add-Type -MemberDefinition ('[DllImport('+$q+'kernel32.dll'+$q+',SetLastError=true)] public static extern bool GetFirmwareType(out uint t);') -Name FwChk -Namespace X99 -ErrorAction Stop; [uint32]$n=0; if([X99.FwChk]::GetFirmwareType([ref]$n)){ if($n -eq 2){$m='UEFI'} elseif($n -eq 1){$m='Legacy'} } } catch {}; if($m -eq 'Unknown' -and $env:firmware_type){ if($env:firmware_type -eq 'UEFI'){$m='UEFI'} elseif($env:firmware_type -eq 'Legacy'){$m='Legacy'} }; if($m -eq 'Unknown' -and (Test-Path -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State')){$m='UEFI'}; $m" 2^>nul`) do set "FW_TYPE=%%F"
if not defined FW_TYPE set "FW_TYPE=Unknown"
if /I not "%FW_TYPE%"=="UEFI" (
    set "LEGACY_WARN=1"
    echo.
    call :safe_echo "[WARN] Режим загрузки текущей Windows НЕ подтверждён как UEFI: FW_TYPE=" FW_TYPE
    echo        После прошивки %MTAG% ^(CSM=OFF^) MBR-диск в Legacy-режиме не загрузится
    echo        без mbr2gpt или временного включения CSM Support в BIOS!
)

:check_bin
set "BIN_PATH=%PDIR%\%MTAG%\X99TF_GHX99015_%PTAG%_%MTAG%_8MB_FPT.bin"
set "BIN_REL_POSIX=%PDIR%/%MTAG%/X99TF_GHX99015_%PTAG%_%MTAG%_8MB_FPT.bin"
if not exist "%BIN_PATH%" (
    call :safe_echo "[ERROR] Файл не найден: " BIN_PATH
    goto :exit_fail
)

set "BIN_SIZE="
for %%A in ("%BIN_PATH%") do set "BIN_SIZE=%%~zA"
if not "%BIN_SIZE%"=="8388608" (
    echo [ERROR] Неверный размер файла %BIN_SIZE% байт ^(ожидалось 8388608^).
    goto :exit_fail
)

:: Safety check #4: Strict SHA-256 verification against SHA256SUMS.txt (bracket/special-char safe via env vars)
set "SHA_WARN=0"
if not exist "SHA256SUMS.txt" goto :no_sha_file
call :verify_sha256
if not "%SHA_CHK%"=="OK" (
    call :safe_echo "[ERROR] Контрольная сумма SHA-256 не совпадает с SHA256SUMS.txt: " BIN_PATH
    echo         Статус проверки: %SHA_CHK%. Файл повреждён! Прошивка отменена.
    goto :exit_fail
)
echo [OK] SHA-256 прошивки подтверждён по SHA256SUMS.txt.
goto :step1_fpt

:no_sha_file
echo.
echo [WARN] Файл SHA256SUMS.txt отсутствует! Контрольная сумма SHA-256 НЕ проверена!
echo        Нельзя гарантировать целостность файла прошивки без SHA256SUMS.txt!
set "SKIP_SHA="
set /p "SKIP_SHA=Продолжить БЕЗ проверки SHA-256? Введите SKIPSHA для продолжения: "
setlocal EnableDelayedExpansion
if /I not "!SKIP_SHA!"=="SKIPSHA" (
    endlocal
    echo Прошивка отменена ради безопасности.
    goto :exit_fail
)
endlocal
set "SHA_WARN=1"

:step1_fpt
echo.
echo [1/4] Проверка SPI-флешки через Intel FPT...
pushd tools >nul 2>&1
set "DIR_ERR=%errorlevel%"
if not "%DIR_ERR%"=="0" (
    echo [ERROR] Не удалось перейти в каталог tools!
    goto :exit_fail
)
fptw64.exe -i
set "FPT_ERR=%errorlevel%"
popd
if not "%FPT_ERR%"=="0" (
    echo [ERROR] fptw64.exe -i завершился с ошибкой %FPT_ERR%. Прошивка отменена.
    goto :exit_fail
)

set "TS="
for /f "usebackq delims=" %%T in (`call "%PS_EXE%" -NoProfile -InputFormat None -Command "Get-Date -Format yyyyMMdd_HHmmss" 2^>nul`) do set "TS=%%T"
if not defined TS set "TS=manual_%RANDOM%_%RANDOM%"
set "BACKUP_FULL_REL=backup_full_16MB_%TS%.bin"
set "BACKUP_BIOS_REL=backup_bios_8MB_%TS%.bin"
set "BACKUP_FULL=%WORK_DIR%\%BACKUP_FULL_REL%"
set "BACKUP_BIOS=%WORK_DIR%\%BACKUP_BIOS_REL%"

echo.
echo [2/4] Снятие резервной копии текущего BIOS...
echo       Пробую снять ПОЛНЫЙ 16 МБ дамп ^(FD + ME + BIOS^)...
pushd tools >nul 2>&1
set "DIR_ERR=%errorlevel%"
if not "%DIR_ERR%"=="0" (
    echo [ERROR] Не удалось перейти в каталог tools!
    goto :exit_fail
)
fptw64.exe -d "..\%BACKUP_FULL_REL%"
set "FULL_ERR=%errorlevel%"
popd

if not "%FULL_ERR%"=="0" goto :try_8mb_backup
if not exist "%BACKUP_FULL_REL%" goto :try_8mb_backup
set "FULL_SIZE="
for %%F in ("%BACKUP_FULL_REL%") do set "FULL_SIZE=%%~zF"
if "%FULL_SIZE%"=="16777216" goto :full_backup_ok

:try_8mb_backup
if exist "%BACKUP_FULL_REL%" del /f /q "%BACKUP_FULL_REL%" >nul 2>&1
echo.
echo [WARN] Полный 16 МБ дамп не разрешён платой ^(или размер не 16 МБ^).
echo        Снимаю полный 8 МБ регион BIOS...
pushd tools >nul 2>&1
set "DIR_ERR=%errorlevel%"
if not "%DIR_ERR%"=="0" (
    echo [ERROR] Не удалось перейти в каталог tools!
    goto :exit_fail
)
fptw64.exe -bios -d "..\%BACKUP_BIOS_REL%"
set "BAK_ERR=%errorlevel%"
popd
if not "%BAK_ERR%"=="0" (
    if exist "%BACKUP_BIOS_REL%" del /f /q "%BACKUP_BIOS_REL%" >nul 2>&1
    echo [ERROR] Не удалось снять бэкап ^(код %BAK_ERR%^)! Прошивка отменена.
    goto :exit_fail
)

set "BAK_SIZE="
for %%B in ("%BACKUP_BIOS_REL%") do set "BAK_SIZE=%%~zB"
if not "%BAK_SIZE%"=="8388608" (
    if exist "%BACKUP_BIOS_REL%" del /f /q "%BACKUP_BIOS_REL%" >nul 2>&1
    echo [ERROR] Размер бэкапа некорректный ^(%BAK_SIZE% байт^). Битый файл удалён. Прошивка отменена.
    goto :exit_fail
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
call :safe_echo "     " BACKUP_FILE
call :safe_echo "     Тип: " BACKUP_DESC

echo.
echo ============================================================================
echo   ПЕРЕД ПРОШИВКОЙ ПРОВЕРЬТЕ И ПЕРЕНЕСИТЕ БЭКАП!
call :safe_echo "     Файл прошивки : " BIN_PATH
call :safe_echo "     Профиль       : " PDESC
call :safe_echo "     Режим         : " MDESC
call :safe_echo "     Ваш бэкап     : " BACKUP_FILE
echo ============================================================================
echo   1. Перенесите/скопируйте бэкап куда удобно ^(в облако, на флешку или другой
echo      ПК^), чтобы в случае чего восстановить плату.
echo   2. НЕ выключайте ПК во время прошивки!
if /I "%BL_STATE%"=="ON" (
    echo.
    call :safe_echo "[WARN] АКТИВЕН BITLOCKER на диске: " SYS_DRIVE
    echo        Приостановите BitLocker или сохраните Recovery Key ДО прошивки!
) else if /I not "%BL_STATE%"=="OFF" (
    echo.
    call :safe_echo "[WARN] СТАТУС BITLOCKER НЕ ОПРЕДЕЛЁН: BL_STATE=" BL_STATE
    echo        Убедитесь вручную, что BitLocker выключен или Recovery Key сохранён!
)
if "%LEGACY_WARN%"=="1" (
    echo.
    call :safe_echo "[WARN] РЕЖИМ ЗАГРУЗКИ WINDOWS НЕ ПОДТВЕРЖДЁН КАК UEFI: FW_TYPE=" FW_TYPE
    echo        ВЫБРАН %MTAG% ^(CSM=OFF^)! MBR-диск не загрузится без mbr2gpt или включения CSM!
)
if "%SHA_WARN%"=="1" (
    echo.
    echo [WARN] Проверка SHA-256 была ПРОПУЩЕНА ^(отсутствует SHA256SUMS.txt^)!
)
echo.
set "CONFIRM="
set /p "CONFIRM=Бэкап сохранён отдельно и вы готовы шить? Введите YES и нажмите Enter: "
setlocal EnableDelayedExpansion
if /I not "!CONFIRM!"=="YES" (
    endlocal
    echo Прошивка отменена пользователем. Бэкап оставлен в:
    call :safe_echo "  " BACKUP_FILE
    goto :exit_ok
)
endlocal

:: Close TOCTOU window: re-verify size and SHA-256 immediately before flashing
if not exist "%BIN_PATH%" (
    call :safe_echo "[ERROR] Файл прошивки исчез перед записью: " BIN_PATH
    goto :exit_fail
)
set "BIN_SIZE="
for %%A in ("%BIN_PATH%") do set "BIN_SIZE=%%~zA"
if not "%BIN_SIZE%"=="8388608" (
    echo [ERROR] Размер файла прошивки изменился ^(%BIN_SIZE% байт, ожидалось 8388608^)! Прошивка отменена.
    goto :exit_fail
)
if "%SHA_WARN%"=="1" goto :step3_flash
call :verify_sha256
if not "%SHA_CHK%"=="OK" (
    call :safe_echo "[ERROR] Повторная проверка SHA-256 перед прошивкой НЕ пройдена: " BIN_PATH
    echo         Статус проверки: %SHA_CHK%. Прошивка отменена!
    goto :exit_fail
)
echo [OK] Повторная проверка SHA-256 перед записью пройдена.

:step3_flash

echo.
call :safe_echo "[3/4] Прошивка (только 8 МБ BIOS-регион): " BIN_PATH
pushd tools >nul 2>&1
set "DIR_ERR=%errorlevel%"
if not "%DIR_ERR%"=="0" (
    echo [ERROR] Не удалось перейти в каталог tools!
    goto :exit_fail
)
fptw64.exe -bios -f "..\%BIN_PATH%"
set "FL_ERR=%errorlevel%"
popd
if not "%FL_ERR%"=="0" (
    echo [ERROR] Ошибка во время прошивки ^(код %FL_ERR%^)! НЕ перезагружайте ПК!
    echo         Повторите прошивку, пока система запущена. Бэкап:
    call :safe_echo "         " BACKUP_FILE
    goto :exit_fail
)

echo.
echo [4/4] Контрольная верификация прошитого BIOS...
pushd tools >nul 2>&1
set "DIR_ERR=%errorlevel%"
if not "%DIR_ERR%"=="0" (
    echo [ERROR] Не удалось перейти в каталог tools!
    goto :exit_fail
)
fptw64.exe -bios -verify "..\%BIN_PATH%"
set "VF_ERR=%errorlevel%"
popd
if not "%VF_ERR%"=="0" (
    echo [ERROR] Верификация не пройдена ^(код %VF_ERR%^)! НЕ перезагружайте ПК, прошейте заново!
    echo         Бэкап:
    call :safe_echo "         " BACKUP_FILE
    goto :exit_fail
)

echo.
echo ============================================================================
echo   ГОТОВО! Прошивка и верификация прошли на 100%%!
call :safe_echo "  Бэкап сохранён: " BACKUP_FILE
echo   Перезагрузите ПК. Первый запуск и тренировка RAM займут ~15-30 сек.
echo   Подсказка: если меняете андервольт/тайминги в BIOS и нет старта -
echo   сброс CMOS ^(JCMOS^) всегда безопасно вернёт профиль Safe Stock.
echo ============================================================================
goto :exit_ok

:verify_sha256
set "SHA_CHK=ERR"
for /f "usebackq delims=" %%H in (`call "%PS_EXE%" -NoProfile -InputFormat None -Command "try { $dir=$env:WORK_DIR; $rel=$env:BIN_REL_POSIX; $bin=[IO.Path]::Combine($dir,$env:BIN_PATH); $sf=[IO.Path]::Combine($dir,'SHA256SUMS.txt'); $exp=$null; foreach($l in [IO.File]::ReadAllLines($sf)){ if($l -match '^([0-9a-fA-F]{64})\s+\*(.+)$' -and $Matches[2] -ceq $rel){ $exp=$Matches[1].ToLowerInvariant(); break } }; if(-not $exp){ 'MISSING' } else { $sha=[Security.Cryptography.SHA256]::Create(); try { $fs=[IO.File]::OpenRead($bin); try { $ah=[BitConverter]::ToString($sha.ComputeHash($fs)).Replace('-','').ToLowerInvariant() } finally { $fs.Dispose() } } finally { $sha.Dispose() }; if($exp -ceq $ah){ 'OK' } else { 'BAD' } } } catch { 'ERR' }" 2^>nul`) do set "SHA_CHK=%%H"
if not defined SHA_CHK set "SHA_CHK=ERR"
exit /b 0

:safe_echo
setlocal EnableDelayedExpansion
set "_pfx=%~1"
set "_val=!%~2!"
echo(!_pfx!!_val!
endlocal
exit /b 0

:exit_ok
popd >nul 2>&1
pause
exit /b 0

:exit_fail
popd >nul 2>&1
pause
exit /b 1
