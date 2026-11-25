# Huananzhi X99-TF — модифицированный BIOS v2.1 (GHX99015, 25.05.2020)

Пакет готовых прошивок **v2.1** для **HUANANZHI X99-TF** на базе сборки [Koshak1013](https://github.com/Koshak1013/HuananzhiX99_BIOS_mods) (`GHX99015`, 25.05.2020): анлок Turbo Boost для Xeon E5 v3, **живой андервольт и лок Ring/Uncore прямо в меню BIOS с реальным сохранением по `F10`**, 25 разблокированных подменю, расшитые лимиты питания, ReBAR, чистый Secure Boot **2011 + 2023 без уязвимости `PKfail` + 443 отзыва `dbx`**, TPM 2.0, работающий `Intel VT-x` и исправленный SmartFan V3 (с поддержкой S3-сна).

Вместо 4 жёстких тиров андервольта из v1.1 теперь достаточно **2 профилей × 3 режима = 6 сборок** — все параметры разгона и тайминги ОЗУ можно настраивать в моменте в BIOS Setup, а сброс CMOS гарантированно возвращает безопасный `Safe Stock`.

*English summary is at the bottom.*

> [!TIP]
> **Скачать всё одним архивом:** [страница Releases](../../releases/latest) → файл `X99TF_GHX99015_BIOS_Pack_v2.1.zip`. Или берите отдельные файлы прямо из папок ниже.

> [!CAUTION]
> **Только для HUANANZHI X99-TF (`GHX99014` / `GHX99015`).** Не шейте на другие платы X99 (Machinist, Kllisre, Qiyida, Jingsha, другие модели Huananzhi и т.д.): у них другие Flash Descriptor, разводка памяти, Super I/O, GPIO и линии PCIe — высокий риск «кирпича» с восстановлением только программатором.
>
> **Лимиты питания расшиты: `PL1 = 200 W`, `PL2 = 250 W`, `Tau = 56 s`.** На 10–18-ядерных Xeon под долгой нагрузкой это сильно греет VRM платы. Обеспечьте обдув VRM или снизьте лимиты прямо в BIOS (см. [Гайд по тюнингу в BIOS](#гайд-по-разгону-и-тюнингу-в-bios)).

---

## Что нового в v2.0 / v2.1

> [!IMPORTANT]
> **Исправления v2.1 (обязательно к обновлению с v2.0):**
> * Исправлен `GUID_STD_DEFAULTS` (`4599D26F-...`) в таблице NVRAM: в `v2.0` при первом старте `02_Performance_OC` срабатывал Bank Swap со сбросом 23 настроек в `01_Safe_Stock` — теперь **`02_Performance_OC` (`−50/−40 mV`, лок Ring, C-States OFF, IMC) гарантированно применяется с первого холодного старта**!
> * Возвращён `MSR Lock Control = Enable` (`0x0075 = 1`): исправлен **аппаратный `Intel VT-x`** (в `v2.0` виртуализация отключалась в Диспетчере задач) и восстановлен `MSR 0xE2` CFG Lock.
> * В `flash.bat` используются короткие относительные пути — устранён `Error 200` Intel FPT на длинных путях (>127 символов) и папках с кириллицей/пробелами.

| Область | Что сделано и проверено на живом железе |
| :--- | :--- |
| **Реальное сохранение настроек (`F10`)** | Исправлен критический баг `NvramDxe` / `NvramSmm` (`0x70 → 0x72`, проверка размера 114-байтной структуры `Setup`). Ранее при каждом ребуте срабатывал `ResetToDefaults + BankSwap`, сносивший правки из BIOS. Теперь любые настройки сохраняются постоянно. |
| **Живой андервольт и лок Ring (`NalexOverclock V4.2`)** | Вместо вшитого `ser8989_S3TurboHack` используется доработанный `NalexOverclock` (DXE + PEI): анлок Turbo Boost + настройка Core/CLR/SA оффсетов и **аппаратный лок Ring/Uncore (`MSR 0x620` пишется строго после `MSR 0x150`, плюс запись в S3 BootScript)** без просадок до 1200 МГц и после выхода из сна. На Xeon v3 параметр `CLR Max OC Ratio = 30` автоматически ограничивается заводским потолком конкретного CPU; на Xeon v4 модуль безопасно пропускается. |
| **Secure Boot без `PKfail` (CVE-2024-8105) + `dbx` 2026** | Скомпрометированный `DO NOT TRUST - AMI Test PK` полностью вычищен (из `PK`, `PKDefault` и дубликата `dbtDefault`). Вшит чистый 2048-бит RSA **`HUANANZHI X99-TF Community Platform Key`** (`2026–2056`, **приватный ключ безвозвратно уничтожен сразу после подписи**), актуальные сертификаты Microsoft **2011 + 2023** (`KEK`/`db`), официальная база отзывов Microsoft **`dbx` от марта 2026 (443 SHA-256 хэша)** и нативные 43-байтные AMI ExtHeaders. |
| **SmartFan V3 + S3 Fix (`F217C2E9`)** | Устранён скрытый баг принудительных **100% оборотов при 70°C**: патч `F217C2E9` исправляет запись `T5` (`78°C`) в регистр `CRITICAL_TEMP` (`0x35`) вместо `0x3A` и сохраняет кривую вентилятора (`60→20%`, `66→40%`, `72→60%`, `75→80%`, `78→100%`) после сна S3. |
| **25 открытых меню и фиксы платформы** | `Power Technology = Custom` по умолчанию (открыты `CPU P/C/T State` и `C1E`, убрана ловушка сброса `PwrMgtCustConfig`); `Pkg Clmp Lim1/2 = Between P1/P0` (нет просадок до 1200 МГц под RAPL); исправлены указатели `_FIT_` на микрокоды (`306F1`/`406F1 rev B000040`/`406F0`, без `306F2`); включён датчик температуры чипсета C612 (`PCH Thermal`); `Timeout = 3s`; `XHCI Idle L1 = Disabled`; `PCIe Relaxed Ordering / Extended Tag = Enabled`; `DMI/PCIe ASPM = Disabled`; `ACPI T-States = Disabled`. |
| **Безопасный Clear CMOS откат** | В **обеих** ветках (`01_Safe_Stock` и `02_Performance_OC`) фабричные `StdDefaults` 100% идентичны ультра-стабильному `01_Safe_Stock` (`0/0 mV`, динамический Ring, C-States ON, ОЗУ в Auto, все ядра). Любой переразгон сбрасывается перемычкой `JCMOS` без программатора. |

---

## Какую сборку выбрать

Структура: **`<профиль>/<режим>/`**, в каждой папке два файла:
* `*_8MB_FPT.bin` — для прошивки из Windows через `flash.bat`;
* `*_16MB_CH341A.bin` — полный образ для программатора (чистый стоковый Flash Descriptor + Intel ME `9.1.37.1002` + BIOS).

### 1. Стартовый профиль

| Папка | Что активно сразу после прошивки | Для кого |
| :--- | :--- | :--- |
| **`01_Safe_Stock`** | Анлок Turbo Boost, `0 / 0 mV`, динамический Ring (`CLR = 0`), C-States ON, контроллер памяти и ОЗУ в `Auto`, все ядра активны | Максимальная стабильность «из коробки», **лучший выбор для Xeon E5 v4** или если хотите крутить всё вручную с нуля |
| **`02_Performance_OC`** | Анлок Turbo Boost, универсальный безопасный андервольт **`−50 mV Core / −40 mV Ring`**, **лок Ring на максимум CPU** (`CLR = 30`, авто-ограничение под модель v3), C-States OFF (`C0/C1`, `C1E/C3/C6` выкл.), безопасный тюнинг IMC (`Early Snoop`, `Open Page`, `Turnaround Opt`, `CKE/OppSR/Scrub/ALPM` выкл.), **ОЗУ и `tREFI` в `Auto`**, все ядра активны | **Рекомендуется для большинства Xeon E5 v3.** Мгновенный прирост отзывчивости и снижение задержек на любой памяти DDR4; сброс CMOS всегда вернёт `Safe Stock` |

> [!NOTE]
> Оба профиля собраны на **идентичном** коде BIOS (`FV0` / `FV1` / `StdDefaults` совпадают байт-в-байт). В любой момент вы можете перенастроить андервольт, Ring, ядра, C-States или тайминги ОЗУ прямо в BIOS Setup без перепрошивки.

### 2. Режим загрузки

| Подпапка | Загрузка | Above 4G / ReBAR | Secure Boot (2011+2023) | TPM 2.0 | Для чего |
| :--- | :---: | :---: | :---: | :---: | :--- |
| `1_Legacy` | CSM вкл. | выкл. | выкл. | выкл. | Windows на MBR, старые видеокарты без UEFI GOP |
| `2_UEFI_SB` | чистый UEFI | вкл. | вкл. | выкл. | Windows 10/11 на GPT, без модуля TPM |
| `3_UEFI_SB_TPM` | чистый UEFI | вкл. | вкл. | вкл. | Windows 11 с аппаратным TPM 2.0, античиты (Vanguard, FACEIT) |

> [!IMPORTANT]
> Пунктов Secure Boot и TPM в меню этого BIOS **нет** — нужный режим выбирается при прошивке.

---

## Как прошить

### Из Windows — `flash.bat` (рекомендуется)
1. Запустите **`flash.bat`** от имени администратора, выберите профиль (`1–2`) и режим (`1–3`).
2. Скрипт снимет бэкап: сначала пробует полный 16 МБ дамп, если плата не даёт — 8 МБ регион BIOS. Файл `backup_*.bin` появится рядом со скриптом.
3. **Скопируйте бэкап в облако / на флешку / на другой ПК**, затем введите `YES`.
4. Скрипт прошьёт **только 8 МБ регион BIOS** (Flash Descriptor и Intel ME вашей платы не трогаются) и выполнит полную верификацию.
5. Сделайте **полное выключение ПК на 10 секунд → включение** (холодный старт). Первая тренировка памяти займёт ~15–30 секунд.

### Программатором CH341A
Записывайте `*_16MB_CH341A.bin` на всю микросхему (`W25Q128` / `MX25L128`), предварительно сняв с неё полный 16 МБ дамп. **Не шейте 16 МБ файл из Windows.**

---

## После прошивки

### 1. Анлок Turbo Boost на Xeon E5 v3 (отключение микрокода в Windows)
Если оставить штатный файл, Windows сама загрузит микрокод `306F2` и анлок пропадёт. Выполните от администратора:

**PowerShell (администратор):**
```powershell
takeown /f "C:\Windows\System32\mcupdate_GenuineIntel.dll"
icacls "C:\Windows\System32\mcupdate_GenuineIntel.dll" /grant "*S-1-5-32-544:F"
Rename-Item "C:\Windows\System32\mcupdate_GenuineIntel.dll" "mcupdate_GenuineIntel.dll.bak"
```

**Или `cmd` (администратор):**
```bat
takeown /f C:\Windows\System32\mcupdate_GenuineIntel.dll
icacls C:\Windows\System32\mcupdate_GenuineIntel.dll /grant *S-1-5-32-544:F
ren C:\Windows\System32\mcupdate_GenuineIntel.dll mcupdate_GenuineIntel.dll.bak
```

Перезагрузитесь. Крупные обновления Windows могут вернуть файл — тогда повторите. В Linux не загружайте `intel-ucode` (или добавьте `dis_ucode_ldr`).
* **Проверка анлока:** откройте **HWiNFO64** или **CPU-Z** (*Bench → Stress CPU*) — частота под нагрузкой на все ядра должна выходить на максимальный all-core Turbo Boost (до упора в `PL1`/`PL2`), а в `02_Performance_OC` вкладка `Memory → LLC/Ring` должна держаться ровно на максимальной частоте Ring без падений до `1200 МГц`.
* **Заметка про WSL2 / античиты с микрокодом `0x00`:** в BIOS включены `VT-x`, `VT-d`, `DMAR`. При использовании микрокода `0x00` держите в Windows выключенной «Целостность памяти» (VBS / HVCI); если нужны и FACEIT/Vanguard, и WSL2/Docker — удобно сделать два пункта загрузки через `bcdedit` (`hypervisorlaunchtype off` / `auto`).

### 2. Переход с MBR на GPT (если нужен UEFI-режим)
С `2_UEFI_SB`/`3_UEFI_SB_TPM` плата не загрузит MBR-диск. Узнайте номер системного диска `N` и стиль разделов (`MBR` или `GPT`) в PowerShell:
```powershell
Get-Partition -DriveLetter C | Get-Disk
```
Сохраните важные файлы и сконвертируйте диск из `cmd` / PowerShell **от администратора** (подставьте ваш номер вместо `0`):
```bat
mbr2gpt /validate /disk:0 /allowFullOS
mbr2gpt /convert /disk:0 /allowFullOS
```
Если не хотите конвертировать — шейте `1_Legacy`.

### 3. Resizable BAR (ReBAR)
В `2_UEFI_SB` и `3_UEFI_SB_TPM` ReBAR уже включён (`ReBarState = 0x20`). На видеокартах без поддержки ReBAR (GTX 10/16, RTX 20) драйвер `ReBarDxe` просто пропускает карту. Если вы прошили `1_Legacy`, а позже перешли на GPT/UEFI: в BIOS поставьте `CSM Support = Disabled`, `Above 4G Decoding = Enabled`, затем запустите **`Enable_ReBAR_Windows.bat`** от администратора.
* **Проверка:** **GPU-Z** → `Resizable BAR: Enabled` (или *Панель управления NVIDIA → Информация о системе → Изменяемый размер BAR: Да*).

### 4. Проверка Secure Boot (2011 + 2023, отсутствие `PKfail`, 443 отзыва `dbx`)
Запустите в PowerShell **от администратора** (для `2_UEFI_SB` и `3_UEFI_SB_TPM`):
```powershell
Confirm-SecureBootUEFI
$pk  = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI -Name PK).Bytes)
$kek = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI -Name KEK).Bytes)
$db  = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI -Name db).Bytes)
[PSCustomObject]@{
  Community_PK   = ($pk -match 'HUANANZHI X99-TF Community Platform Key')
  AMI_Test_PK    = ($pk -match 'DO NOT TRUST|AMI Test PK')   # должно быть False!
  KEK_2023       = ($kek -match 'KEK 2K CA 2023')
  Win_UEFI_2023  = ($db -match 'Windows UEFI CA 2023')
  MS_UEFI_2023   = ($db -match 'Microsoft UEFI CA 2023')
  OptROM_2023    = ($db -match 'Option ROM UEFI CA 2023')
  DBX_Bytes      = (Get-SecureBootUEFI -Name dbx).Bytes.Length  # 21292 (443 SHA-256)
}
```
Ожидаемый результат: `Confirm-SecureBootUEFI = True`, `AMI_Test_PK = False`, все флаги `*_2023 = True`, `Community_PK = True`, `DBX_Bytes = 21292`.

---

## Гайд по разгону и тюнингу в BIOS

В **v2.1** все ключевые меню открыты, `Power Technology = Custom` уже безопасно активирован, а правки сохраняются по `F10`. Нажмите **`Del`** при старте (задержка `Timeout = 3 сек`).

### Карта основных параметров для повышения производительности

| Параметр | Путь в меню BIOS | Безопасный тюнинг / рекомендация |
| :--- | :--- | :--- |
| **Андервольт CPU (Core)** *(v3)* | `IntelRCSetup → OverClocking Feature → Processor` | `Core Voltage Offset Prefix = -`, начните с `50` (`−50 мВ`). Удачные кристаллы берут `60–75 мВ` (шаг по `5–10 мВ` + тест в OCCT/Prime95/играх). Снижает нагрев VRM и поднимает частоты буста. |
| **Лок и андервольт Ring / Uncore** *(v3)* | `IntelRCSetup → OverClocking Feature → CLR/Ring` | **`CLR Max OC Ratio`**: `30` = аппаратный лок Ring на максимум вашего CPU (в `02_Performance_OC` уже стоит; авто-ограничивается потолком модели, например `27x` на 2678 v3, `30x` на 2696 v3), `0` = динамика `12x..Max`. **`CLR Voltage Offset`**: `-40` (удачные держат `-45..-55 мВ`). Даёт резкое снижение задержек L3/ОЗУ! |
| **Ограничение ядер** *(опционально)* | `IntelRCSetup → Processor Configuration → Per-Socket Configuration → CPU Socket 0 Configuration → Cores Enabled` | `0` = все ядра. На 14–18-ядерных Xeon для игр можно выставить `10–12` ядер: ниже нагрев CPU/VRM и выше/стабильнее частота Turbo Boost (в тяжёлом рендере 100% потоков производительность пропорционально снизится). |
| **Лимиты мощности PL1 / PL2 / Tau** | `IntelRCSetup → Advanced Power Management Configuration → SOCKET RAPL Config` | По умолчанию `200 W / 250 W / 56 s`, `Pkg Clmp Lim1/2 = Between P1/P0`. Если VRM греется — снизьте `Long Dur Pwr Limit` (`PL1`) до `130–160 W`. Также `Turbo Pwr Limit Lock = Disable` (можно менять из Windows в ThrottleStop). |
| **C-States / задержка пробуждения** | `IntelRCSetup → Advanced Power Management Configuration → CPU C State Control` | Для минимальных задержек и стабильного андервольта: `Package C State limit = C0/C1`, `C3 = Disable`, `C6 = Disable`, **`Enhanced Halt State (C1E) = Disable`** (в `02_Performance_OC` уже настроено). Для экономии электричества в простое верните `Auto/Enable`. |
| **Режим снупинга (L3 / IMC)** | `IntelRCSetup → QPI Configuration → QPI General Configuration` | `COD Enable = Disable`, **`Early Snoop = Enable`** (ускоряет доступ к памяти на многоядерных Xeon; в `02_Performance_OC` уже включено). |
| **Частота, тайминги и `tREFI` ОЗУ** | `IntelRCSetup → Memory Configuration → Memory Frequency` и `Memory Timings & Voltage Override` | Потолок DDR4 на Xeon E5 v3 — **2133 МГц** (`2133` или `Auto`; на Xeon E5 v4 поддерживается до **2400 МГц**). Для ручной настройки поставьте `DIMM profile = MANUAL`: откроются первичные тайминги, `Command Timing` (`1N`/`2N`), `Memory Voltage` и **`Refresh Rate (tREFI)`**. Увеличение `tREFI` до **`32760`** (при хорошем обдуве модулей) заметно снижает задержку ОЗУ. Предзаполненные `12-12-12-28-12-200` проверены на чипах **Micron (Atermiter/Samsung ECC)** — на других планках (Hynix/китайский ноунейм) сначала ослабьте до `14-14-14-32-260` и проверяйте в TestMem5! |
| **Ускорение контроллера памяти (IMC)** | `IntelRCSetup → Memory Configuration` | `Page Policy = Open`; `Memory Training → Turnaround Time Optimization = Enable`; `Memory Thermal → Memory Power Savings Mode = User Defined` → `CKE Throttling = Off`, `Opportunistic SR = Disabled`, `MDLL Off = Disabled`; `Memory RAS Configuration` → `Patrol/Demand Scrub = Disable` (всё это уже активно в `02_Performance_OC`). |
| **PCIe / Above 4G** | `Advanced → PCI Subsystem Settings` | `Above 4G Decoding` (`Enabled` для UEFI/ReBAR), `PCI Express Settings`: `Relaxed Ordering = Enabled`, `Extended Tag = Enabled`. |
| **Защита от перегрева (PROCHOT#)** | `IntelRCSetup → Advanced Power Management Configuration → CPU Thermal Management` | Держите `Bi-directional PROCHOT# = Enabled` (защита VRM). |
| **Кривая вентилятора CPU** | `Advanced → Hardware Monitor` | Точки `T1–T5`, `PWM1–PWM4`. В v2.1 `T5` (`78°C`) корректно задаёт порог 100% оборотов и переживает сон S3. |

> [!TIP]
> **Пошаговый план тюнинга после прошивки `02_Performance_OC`:**
> 1. Загрузитесь и проверьте стабильность базовых `−50 / −40 мВ` + лока Ring (10–15 мин OCCT / игры).
> 2. По желанию аккуратно подберите андервольт глубже (например `−60 / −45 мВ` или `−65 / −45 мВ`) — если поймали BSOD, ослабьте на `5–10 мВ`.
> 3. Займитесь памятью: сначала при желании задайте `Memory Frequency = 2133`, затем переключите `DIMM profile = MANUAL` — **сразу проверьте предзаполненные тайминги `12-12-12-28-200` (под чипы Micron) и на планках Hynix / обычной DDR4 ослабьте их (например `14-14-14-32-260`) ДО сохранения `F10`!** Уже внутри открывшегося режима `MANUAL` выставьте `Refresh Rate (tREFI) = 32760`, подберите тайминги (`12-12-12-28-200-1N` или `13/14-...`) и проверьте стабильность в **TestMem5 (Anta777)**.
> 4. Если после правки таймингов/вольтажа ПК не стартует — **не паникуйте**: обесточьте ПК и замкните `JCMOS` на 10 секунд, BIOS чисто откатится на `01_Safe_Stock`!

> [!WARNING]
> **Что НЕ рекомендуется менять без понимания:**
> * **`UFS (Uncore Frequency Scaling)`** — оставьте **`Enabled`** (`0`). Его отключение на Haswell-EP ломает работу `MSR 0x620` и заметно роняет пропускную способность ОЗУ.
> * **`Energy Efficient Turbo = Enable`** и **`Energy Performance BIAS = 7`** — оптимальны для стабильного буста без залипаний частоты на 1200 МГц.
> * **`Fast Boot = Disabled`** — гарантирует корректную инициализацию USB/PCIe/ReBAR.
> * **`Current Config` (`Program PP0_CURT_CFG_CTRL_MSR`)** — оставьте `0` (не занижайте заводской лимит тока CPU).
> * **`MSR Lock Control`** (`Processor Configuration`) — оставьте **`Enable`** (`1`), иначе отключится аппаратная виртуализация `Intel VT-x` (`MSR 0x3A`).
> * **`Power Technology`** — в v1.1 его нельзя было менять на `Custom`; **в v2.0+ этот баг полностью исправлен**, режим `Custom` стоит по умолчанию и работает стабильно.

### Реальный ориентир производительности (живой тест v2.1 / V4.4)
Конфигурация стенда: **Xeon E5-2696 v3 (`12C/24T`, `−65 / −45 мВ`, Ring `3000 МГц` lock)** + **4×8 ГБ ECC DDR4-2133 (`12-12-12-28-200-1T`, `tREFI=32760`)** + **RTX 5070 Ti (ReBAR 16 ГБ)**:
* **AIDA64 Cache & Memory:** `Read 65 977 МБ/с` | `Write 47 503 МБ/с` | `Copy 57 373 МБ/с` | `Memory Latency 75.9 нс` | `L3 Latency 27.1 нс` | `North Bridge / Ring 3000.0 МГц` (без просадок).
* **Снижение реальной задержки ОЗУ (256 МБ pointer-chase):** с `110.4 нс` (до тюнинга) до **`95.2 нс` (`−15.2 нс`)**.

**Нет в меню BIOS** (задаётся выбором режима при прошивке или из Windows): Secure Boot, TPM 2.0, ReBAR (`Enable_ReBAR_Windows.bat`), управление разъёмом `CFAN1`.

---

## Модуль TPM 2.0

* Проверен модуль **TPM-LPC-X2, 10 pin (Infineon SLB9665)** — [пример на Ozon](https://www.ozon.ru/product/modul-bezopasnosti-tpm-2-0-tpm-lpc-x2-10-rin-2-sht-2288449791/). Работает со сборками `3_UEFI_SB_TPM`.
* Разъём на плате подписан **`JLPC1`** или **`DEBUG1`** (зависит от ревизии) — это одна и та же 10-контактная колодка.
* **Ставьте и перетыкайте модуль только на обесточенном ПК** (выключить, тумблер БП в `0`, зажать кнопку питания на пару секунд).
* **Сверьте ключ (пустой контакт) и Pin 1** на плате и на модуле — не вставляйте силой.
* **Проверка в Windows:** `Win + R` → `tpm.msc` (должно быть «Модуль TPM готов к использованию», версия `2.0`, `IFX`), либо в PowerShell от администратора:
  ```powershell
  Get-Tpm | Select-Object TpmPresent, TpmReady, TpmEnabled, TpmActivated, TpmOwned
  Confirm-SecureBootUEFI
  ```

---

## Если что-то пошло не так

| Проблема | Причина | Решение |
| :--- | :--- | :--- |
| После `2_UEFI_SB`/`3_UEFI_SB_TPM` BIOS не видит загрузочный диск | Windows стоит на MBR-диске | Зайдите в `Advanced → CSM Configuration → CSM Support = Enabled`, сохраните (`F10`), загрузите Windows, сделайте `mbr2gpt` и выключите `CSM` обратно |
| Чёрный экран после ручного андервольта / таймингов ОЗУ в BIOS | Переразгон CPU или памяти | Полностью обесточьте ПК и сбросьте CMOS перемычкой `JCMOS` (или снимите батарейку на 1–2 мин) — BIOS безопасно откатится в `01_Safe_Stock` (`0/0 mV`, ОЗУ `Auto`) с сохранением режима UEFI/SB/TPM! |
| Синие экраны / зависания на `02_Performance_OC` (Xeon E5 v3) | Неудачный кристалл не держит `−50 / −40 мВ` или лок Ring | Зайдите в `IntelRCSetup → OverClocking Feature` и ослабьте оффсеты (например `−30 / −20 мВ` или `0 / 0`) или поставьте `CLR Max OC Ratio = 0` → `F10`. Перепрошивать BIOS больше не нужно! |
| Чёрный экран на старой видеокарте в UEFI-режиме | Видеокарта без UEFI GOP | Перейдите на `1_Legacy` (или с другой видеокартой временно включите `CSM Support`) |
| Загрузочная флешка (Ventoy, Strelec) выдаёт `Security Violation` | Сторонний `.efi` не подписан ключами MS | В MokManager выберите `Enroll hash from disk` и укажите `.efi`-файл с флешки, либо используйте `1_Legacy` |

---

## Контрольные суммы и прозрачность ключа Secure Boot

* SHA-256 всех **12 образов** — в [`SHA256SUMS.txt`](SHA256SUMS.txt). Проверка в PowerShell:
  ```powershell
  Get-FileHash .\02_Performance_OC\3_UEFI_SB_TPM\*.bin -Algorithm SHA256
  ```
* Отпечаток публичного сертификата **`HUANANZHI X99-TF Community Platform Key`** (`PK`, `2026–2056`):
  * SHA-256 (DER): `6b61f6bcc8a80e71098442fab01c1ec598ccc45393ab64eb0a7637363f7b8522`
  * Приватный ключ сгенерирован одноразово при сборке релиза и **безвозвратно перезаписан нулями и удалён** сразу после подписи `PKDefault` — он не хранится ни в репозитории, ни у автора (полная защита от `PKfail`).

---

## English summary

* **Download all builds as one archive:** [Releases](../../releases/latest) → `X99TF_GHX99015_BIOS_Pack_v2.1.zip`, or grab individual files from the folders.
* **For HUANANZHI X99-TF (`GHX99014` / `GHX99015`) only.** Do not flash onto any other X99 motherboard.
* **What's new in v2.1 (over v2.0):**
  * **Fixed `StdDefaults` NVRAM GUID (`4599D26F-...`)**: prevents the first-boot NVRAM Bank Swap that silently reset `02_Performance_OC` back to `01_Safe_Stock` in `v2.0`; all 23 `PerfOC` settings (`−50/−40 mV`, Ring lock, C-States OFF, IMC tweaks) now apply on cold boot #1.
  * **Fixed Intel VT-x (`MSR Lock Control = Enable`)**: locks `IA32_FEATURE_CONTROL` (`MSR 0x3A[0]`) and `MSR 0xE2[15]` so hardware virtualization works out of the box.
  * **Fixed `flash.bat` long/non-ASCII paths**: uses short relative paths for Intel FPT (eliminates `Error 200` on paths >127 chars or with spaces/Cyrillic).
* **Core v2.x features (live-verified on hardware):**
  * **Real `F10` NVRAM persistence fixed (`NvramDxe`/`NvramSmm` `0x70 → 0x72`):** BIOS settings no longer reset to defaults on every reboot!
  * **Live BIOS undervolt & Ring/Uncore lock (`NalexOverclock V4.2` DXE+PEI):** adjust Core/CLR/SA offsets and hardware `MSR 0x620` Ring lock (`CLR Max OC Ratio = 30` auto-clamps to each Xeon v3's safe max, `0` = dynamic; skipped on v4) directly in BIOS Setup with full S3 BootScript support — no more reflashing just to change undervolt tiers!
  * **`PKfail` (CVE-2024-8105) eliminated + March 2026 `dbx`:** compromised `AMI Test PK` completely purged from `PK`, `PKDefault`, and `dbtDefault`; replaced with a clean 2048-bit **`HUANANZHI X99-TF Community Platform Key`** (`2026–2056`, ephemeral private key shredded immediately after signing), Microsoft **2011 + 2023** `KEK`/`db` CAs, official March 2026 Microsoft **`dbx` (443 SHA-256 revocations)**, and clean native 43-byte AMI AuthVar ExtHeaders.
  * **Platform bugfixes & 25 unlocked menus:** SmartFan V3 `70°C → 78°C` `CRITICAL_TEMP` + S3 fix (`F217C2E9`), `Power Technology = Custom` fixed & enabled by default (un-grays `CPU P/C/T State` & `C1E`), RAPL below-P1 clamp fixed (`Pkg Clmp Lim1/2 = 0`), `_FIT_` microcode pointers fixed (`306F2` removed for v3 unlock, `406F1 rev 0xB000040` kept for v4), C612 PCH Thermal sensor enabled, `Timeout = 3s`, `XHCI Idle L1 = Disabled`, `PCIe Relaxed Ordering / Extended Tag = Enabled`, `ASPM = Disabled`.
* **Clean 2 × 3 matrix (6 builds / 12 binaries):**
  * Profiles: **`01_Safe_Stock`** (`0/0 mV`, dynamic Ring, C-States ON, IMC/RAM Auto, All Cores — best for v4 / cautious start) and **`02_Performance_OC`** (`−50/−40 mV`, auto-clamped Ring lock, C-States OFF, safe universal IMC tweaks, **RAM & `tREFI` Auto**, All Cores — recommended for Xeon v3). **Clear CMOS (`JCMOS`) always rolls back to `01_Safe_Stock` in every build.**
  * Modes: `1_Legacy` (CSM), `2_UEFI_SB` (Pure UEFI + ReBAR + Secure Boot), `3_UEFI_SB_TPM` (+ TPM 2.0 for `TPM-LPC-X2` / Infineon SLB9665 on `JLPC1`/`DEBUG1`). Secure Boot and TPM remain hidden in BIOS menus, so pick the mode at flash time.
* **Flashing:** run `flash.bat` as Administrator (auto-backs up 16 MB or 8 MB, flashes **only the 8 MB BIOS region**, and verifies). `*_16MB_CH341A.bin` files (clean stock FD + ME `9.1.37.1002`) are for external SPI programmers only.
* **Post-flash:** rename `C:\Windows\System32\mcupdate_GenuineIntel.dll` for Xeon v3 unlock; convert MBR → GPT via `mbr2gpt` if switching to UEFI; tune deeper undervolt, `Cores Enabled`, `PL1/PL2` (`200W/250W` default — keep VRM cooled!), `tREFI = 32760`, and manual DDR4-2133 timings right inside BIOS Setup (`F10`).

---

## Лицензия / License

Автор сборки — **pavelcanton**. Скрипты и документация — **MIT** (см. [`LICENSE`](LICENSE)). Модули BIOS, Intel ME, микрокоды и Intel FPT (`tools/`) принадлежат своим правообладателям. Всё предоставляется «как есть», прошивка — на ваш страх и риск.

*Built by pavelcanton. Scripts and docs are MIT-licensed. Firmware modules, Intel ME, microcode and Intel FPT belong to their respective owners. Provided as is; flash at your own risk.*
