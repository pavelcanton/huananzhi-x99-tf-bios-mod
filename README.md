# Huananzhi X99-TF — модифицированный BIOS (GHX99015, 25.05.2020)

Набор готовых прошивок для **HUANANZHI X99-TF** на базе сборки от [Koshak1013](https://github.com/Koshak1013/HuananzhiX99_BIOS_mods) (`GHX99015`, 25.05.2020): анлок Turbo Boost для Xeon E5 v3, андервольт, расшитые лимиты питания, ReBAR, Secure Boot, TPM 2.0 и тихая кривая вентилятора. 4 тира андервольта × 3 режима = 12 сборок.

*English summary is at the bottom.*

> [!TIP]
> **Скачать всё одним архивом:** [страница Releases](../../releases/latest) → файл `X99TF_GHX99015_BIOS_Pack_v1.1.zip`. Или берите отдельные файлы прямо из папок ниже.

> [!CAUTION]
> **Только для HUANANZHI X99-TF (`GHX99014` / `GHX99015`).** Не шейте на другие платы X99 (Machinist, Kllisre, Qiyida, Jingsha, другие модели Huananzhi и т.д.): у них другие Flash Descriptor, разводка памяти, Super I/O, GPIO и линии PCIe — высокий риск «кирпича» с восстановлением только программатором.
>
> **Лимиты питания расшиты: `PL1 = 200 W`, `PL2 = 250 W`, `IccMax = 160 A`.** На 10–18-ядерных Xeon под долгой нагрузкой это сильно греет VRM платы. Обеспечьте обдув VRM или снизьте лимиты (см. [Настройки в BIOS](#настройки-в-bios)).

---

## Что внутри (во всех 12 сборках)

| | |
| :--- | :--- |
| **База** | `GHX99015` от 25.05.2020 — доработка на базе [Koshak1013/HuananzhiX99_BIOS_mods](https://github.com/Koshak1013/HuananzhiX99_BIOS_mods) (`Huananzhi X99-TF / 2020-05-25`, `kot_v011`). Если у вас уже стоит эта версия или стоковая `GHX99014`/`GHX99015` — прошивка встанет без сюрпризов. |
| **Xeon E5 v3** | Микрокод `306F2` удалён + `ser8989_S3TurboHack` → Turbo Boost Unlock на все ядра + выбранный андервольт. |
| **Xeon E5 v4** | Микрокод `406F1` rev `0xB000040` сохранён, v4 работают штатно (анлок и андервольт на v4 не действуют — ограничение Intel). |
| **Питание** | Сняты зажимы RAPL в `PpmInitialize`; `PL1 = 200 W`, `PL2 = 250 W`, `Tau = 56 s`, `IccMax = 160 A`, все ядра активны. |
| **Память** | `Auto` — безопасный старт на любой памяти. Ручные тайминги `12-12-12-28-12-200` предзаполнены, но выключены (`DIMM profile = Disabled`). Потолок DDR4 на этой платформе — **2133 МГц**. |
| **Вентилятор CPU** | `60°C → 20%`, `66°C → 40%`, `72°C → 60%`, `75°C → 80%`, `78°C → 100%`. |
| **Прочее** | Без писка при старте; чистый NVRAM без чужих привязок; настройки продублированы в `StdDefaults` (переживают сброс CMOS). |

---

## Какую сборку выбрать

Структура: **`<тир андервольта>/<режим>/`**, в каждой папке два файла:
* `*_8MB_FPT.bin` — для прошивки из Windows через `flash.bat`;
* `*_16MB_CH341A.bin` — полный образ для программатора (Flash Descriptor + чистый Intel ME `9.1.37.1002` + BIOS).

**1. Тир андервольта (только Xeon E5 v3)**

| Папка | Core / Cache | Для кого |
| :--- | :---: | :--- |
| `01_UV_0_0_Stock` | 0 / 0 mV | Только анлок, без андервольта. Максимальная стабильность, подходит и для v4 |
| `02_UV_40_30_Mild` | −40 / −30 mV | Мягкий, для неудачных кристаллов |
| `03_UV_50_50_Balanced` | −50 / −50 mV | **Рекомендуемый** для большинства v3 |
| `04_UV_70_50_Perf` | −70 / −50 mV | Для удачных кристаллов (проверено на E5-2678 v3) |

**2. Режим работы**

| Подпапка | Загрузка | Above 4G / ReBAR | Secure Boot | TPM 2.0 | Для чего |
| :--- | :---: | :---: | :---: | :---: | :--- |
| `1_Legacy` | CSM вкл. | выкл. | выкл. | выкл. | Windows на MBR, старые видеокарты без UEFI GOP |
| `2_UEFI_SB` | чистый UEFI | вкл. | вкл. | выкл. | Windows 10/11 на GPT, без модуля TPM |
| `3_UEFI_SB_TPM` | чистый UEFI | вкл. | вкл. | вкл. | Windows 11 с аппаратным TPM 2.0, античиты (Vanguard, FACEIT) |

> [!IMPORTANT]
> Пунктов Secure Boot и TPM в меню этого BIOS **нет** — режим выбирается только самой прошивкой.

---

## Как прошить

### Из Windows — `flash.bat` (рекомендуется)
1. Запустите **`flash.bat`** от имени администратора, выберите тир (1–4) и режим (1–3).
2. Скрипт снимет бэкап: сначала пробует полный 16 МБ дамп, если плата не даёт — 8 МБ регион BIOS. Файл `backup_*.bin` появится рядом со скриптом.
3. **Скопируйте бэкап в облако / на флешку / на другой ПК**, затем введите `YES`.
4. Скрипт прошьёт **только 8 МБ регион BIOS** (Flash Descriptor и ME платы не трогаются) и проверит запись.
5. Перезагрузитесь. Первый старт с тренировкой памяти — 15–30 секунд.

### Программатором CH341A
Записывайте `*_16MB_CH341A.bin` на всю микросхему (W25Q128 / MX25L128), предварительно сняв с неё полный дамп. **Не шейте 16 МБ файл из Windows.**

---

## После прошивки

**Анлок на v3: отключите загрузку микрокода в Windows.** Иначе Windows сама загрузит микрокод `306F2` и анлок пропадёт. Выберите удобный вариант (запуск от администратора):

Командная строка (`cmd` от администратора):
```bat
takeown /f C:\Windows\System32\mcupdate_GenuineIntel.dll
icacls C:\Windows\System32\mcupdate_GenuineIntel.dll /grant *S-1-5-32-544:F
ren C:\Windows\System32\mcupdate_GenuineIntel.dll mcupdate_GenuineIntel.dll.bak
```

PowerShell (ПКМ по «Пуск» → *Windows PowerShell (администратор)* / *Терминал (администратор)*):
```powershell
takeown /f "C:\Windows\System32\mcupdate_GenuineIntel.dll"
icacls "C:\Windows\System32\mcupdate_GenuineIntel.dll" /grant "*S-1-5-32-544:F"
Rename-Item "C:\Windows\System32\mcupdate_GenuineIntel.dll" "mcupdate_GenuineIntel.dll.bak"
```

Перезагрузитесь. Крупные обновления Windows могут вернуть файл — тогда повторите. В Linux не загружайте `intel-ucode` (или добавьте параметр ядра `dis_ucode_ldr`). Учтите: без свежего микрокода часть защит от уязвимостей CPU (Spectre и др.) неактивна.
* **Как проверить анлок:** откройте **HWiNFO64** или **CPU-Z** (вкладка *Bench → Stress CPU*) — под нагрузкой на все ядра частота должна подниматься выше паспортного all-core Turbo Boost (до максимума для 1 ядра или упора в лимит мощности).

**Windows на MBR, а нужен UEFI-режим.** С `2_UEFI_SB`/`3_UEFI_SB_TPM` плата не загрузит MBR-диск. Сначала узнайте номер системного диска `N` и стиль разделов (`MBR` или `GPT`):

PowerShell (покажет только системный диск с `C:` — цифра в колонке **`Number`** и есть ваш `N`, а **`PartitionStyle`** покажет, нужен ли переход с `MBR`):
```powershell
Get-Partition -DriveLetter C | Get-Disk
```
Или через окно Windows (`Win + R` → `diskmgmt.msc`): найдите строку с диском `(C:)`, цифра слева («Диск 0» / «Диск 1») — это `N` (*ПКМ по «Диск N» → Свойства → Тома → Стиль разделов*).

Сохраните важные файлы и запустите конвертацию в `cmd` или PowerShell **от администратора** (подставьте ваш номер вместо `0`, сначала проверка без записи, затем сама конвертация):
```bat
mbr2gpt /validate /disk:0 /allowFullOS
mbr2gpt /convert /disk:0 /allowFullOS
```
Если не хочется конвертировать — прошейте `1_Legacy`.

**ReBAR.** На видеокартах без поддержки Resizable BAR (GTX 10/16, RTX 20) драйвер `ReBarDxe` просто пропускает карту. Если прошили `1_Legacy`, а потом перешли на GPT/UEFI: в BIOS поставьте `CSM Support = Disabled`, `Above 4G Decoding = Enabled`, затем запустите **`Enable_ReBAR_Windows.bat`** от администратора.
* **Как проверить ReBAR:** откройте **GPU-Z** → строка **`Resizable BAR`** на главной вкладке должна показывать **`Enabled`** (по клику на `Enabled` откроются детали по BIOS и диапазонам BAR). На NVIDIA также видно в *Панели управления NVIDIA → Справка → Информация о системе → Изменяемый размер BAR: Да*.

**Ключи Secure Boot (2011 + 2023).** В `2_UEFI_SB` и `3_UEFI_SB_TPM` вшиты оба поколения ключей Microsoft — **2011** (`KEK CA 2011`, `UEFI CA 2011`, `Windows Production PCA 2011`) и актуальные **2023** (`KEK 2K CA 2023`, `Windows UEFI CA 2023`, `Microsoft UEFI CA 2023`, `Microsoft Option ROM UEFI CA 2023`), плюс `AMI Test PK` и `dbx`. Фабричные дефолты внутри прошивки тоже обновлены и переживают сброс CMOS.
* Проверить наличие ключей **2023** после загрузки можно в PowerShell **от администратора** (везде должно быть `True`):
  ```powershell
  Confirm-SecureBootUEFI
  [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI -Name KEK).Bytes) -match 'KEK 2K CA 2023'
  [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI -Name db).Bytes) -match 'Windows UEFI CA 2023'
  [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI -Name db).Bytes) -match 'Microsoft UEFI CA 2023'
  [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI -Name db).Bytes) -match 'Option ROM UEFI CA 2023'
  ```

---

## Настройки в BIOS

Доступно в меню (проверено по разметке меню этой прошивки):

| Что | Где | Примечание |
| :--- | :--- | :--- |
| **PL1 / PL2 / Tau** | `IntelRCSetup → Advanced Power Management Configuration → SOCKET RAPL Config` | `Long Dur Pwr Limit` = PL1, `Short Dur Pwr Limit` = PL2, `Long Dur Time Window` = Tau |
| Число ядер | `IntelRCSetup → Processor Configuration → Per-Socket Configuration → CPU Socket 0 Configuration → Cores Enabled` | `0` = все |
| Частота памяти | `IntelRCSetup → Memory Configuration → Memory Frequency` | реальный потолок DDR4 — 2133 |
| Тайминги и напряжение памяти | `IntelRCSetup → Memory Configuration → Memory Timings & Voltage Override` | поставьте `DIMM profile = MANUAL` — откроются тайминги, `Command Timing`, `Memory Voltage` |
| Round Trip Latency | `IntelRCSetup → Memory Configuration → Memory Training` | `Auto` / `Enable` / `Disable` |
| Кривая вентилятора CPU | `Advanced → Hardware Monitor` | точки `T1–T5`, `PWM1–PWM4` |
| Above 4G Decoding | `Advanced → PCI Subsystem Settings` | |
| CSM | `Advanced → CSM Configuration → CSM Support` | при `Enabled` появятся `Video`, `Storage` и др. |
| MMIO High Size | `IntelRCSetup → Common RefCode Configuration` | по умолчанию `256G` |

> [!WARNING]
> **Не переключайте `Power Technology` в `Custom`** — оставьте `Energy Efficient`. У автора после `Custom` перестала загружаться Windows, а для изменения лимитов этот режим не нужен.

Ещё про память и питание:
* Предзаполненные тайминги `12-12-12-28-12-200` проверены на DDR4 **Atermiter (чипы Micron)**. На другой памяти поправьте их **до** сохранения (`F10`), иначе может понадобиться сброс CMOS.
* `Turbo Pwr Limit Lock = Disable`, поэтому PL1/PL2 можно менять и из Windows, например через ThrottleStop (вкладка TPL).
* На 14–18-ядерных Xeon в пункте **`Cores Enabled`** (путь в таблице выше) можно протестировать частоты и при желании урезать число активных ядер — например, на 18-ядерном CPU выставить `12` (`24` потока, как сделал автор на своём E5-2696 v3):
  * **Плюсы:** меньше потребление и нагрев CPU/VRM, выше и стабильнее частота Turbo Boost на оставшихся ядрах в играх и смешанной нагрузке.
  * **Минусы:** пропорционально ниже производительность в задачах, нагружающих все 100% потоков (рендер, кодирование видео, тяжёлая компиляция).
* Андервольт сам по себе снижает ток и нагрев VRM без потери частот.

**Нет в меню** (меняется только выбором сборки или из Windows): андервольт, Secure Boot, TPM, ReBAR (`Enable_ReBAR_Windows.bat`), `IccMax`, управление вентилятором `CFAN1`.

---

## Модуль TPM 2.0

* Проверен модуль **TPM-LPC-X2, 10 pin (Infineon SLB9665)** — [пример на Ozon](https://www.ozon.ru/product/modul-bezopasnosti-tpm-2-0-tpm-lpc-x2-10-rin-2-sht-2288449791/). Работает со сборками `3_UEFI_SB_TPM`.
* Разъём на плате подписан **`JLPC1`** или **`DEBUG1`** (зависит от ревизии) — это одна и та же 10-контактная колодка.
* **Ставьте и перетыкайте модуль только на обесточенном ПК** (выключить, тумблер БП в `0`, зажать кнопку питания на пару секунд). Ставить можно до или после прошивки.
* **Сверьте ключ (пустой контакт) и Pin 1** на плате и на модуле. У сторонних модулей ключ часто не совпадает — не вставляйте силой, при необходимости перепиновайте колодку.
* **Проверка в Windows:**
  * **Оснастки Windows:** `Win + R` → `tpm.msc` (в окне «Управление TPM» должно быть «Модуль TPM готов к использованию», версия `2.0`, производитель `IFX`); для Secure Boot — `Win + R` → `msinfo32` (строка «Состояние безопасной загрузки: Вкл.»).
  * **PowerShell от администратора** (ПКМ по «Пуск» → *Windows PowerShell (администратор)*) — `Get-Tpm` проверит готовность TPM (все 4 поля = `True`), `Confirm-SecureBootUEFI` проверит Secure Boot (`True` для `2_UEFI_SB` и `3_UEFI_SB_TPM`):
    ```powershell
    Get-Tpm | Select-Object TpmPresent, TpmReady, TpmEnabled, TpmActivated
    Confirm-SecureBootUEFI
    ```
  * **Командная строка (`cmd` от администратора)** (если в вашей Windows есть `wmic`; ожидается `SpecVersion = 2.0...` и оба флага `TRUE`):
    ```bat
    wmic /namespace:\\root\cimv2\security\microsofttpm path win32_tpm get SpecVersion, IsEnabled_InitialValue, IsActivated_InitialValue
    ```
  * Если модуля не видно — обесточьте ПК, проверьте посадку/распиновку и убедитесь, что прошита именно `3_UEFI_SB_TPM`.

---

## Если что-то пошло не так

| Проблема | Причина | Решение |
| :--- | :--- | :--- |
| После `2_UEFI_SB`/`3_UEFI_SB_TPM` BIOS не видит загрузочный диск | Windows стоит на MBR-диске | Зайдите в `Advanced → CSM Configuration → CSM Support = Enabled`, сохраните (`F10`), загрузите Windows, сделайте `mbr2gpt` и выключите `CSM` обратно |
| Чёрный экран после ручных таймингов ОЗУ в `MANUAL` | Переразгон памяти | Полностью обесточьте ПК и сбросьте CMOS перемычкой `JCMOS` (или снимите батарейку на 1–2 мин) — настройки прошивки сохранятся, ОЗУ вернётся в `Auto` |
| Синие экраны или зависания на Xeon E5 v3 | Нехватка напряжения при андервольте | Прошейте тир на шаг мягче: `04` → `03` → `02` → `01_UV_0_0_Stock` |
| Чёрный экран на старой видеокарте в UEFI-режиме | Видеокарта без UEFI GOP | Перейдите на `1_Legacy` (или на другой карте временно включите `CSM Support`) |
| Загрузочная флешка (Ventoy, Strelec) выдаёт `Security Violation` | Сторонний `.efi` не подписан ключами MS/AMI | В MokManager выберите `Enroll hash from disk` и укажите `.efi`-файл с флешки, либо используйте `1_Legacy` |

---

## Контрольные суммы

SHA-256 всех 24 образов — в [`SHA256SUMS.txt`](SHA256SUMS.txt). Проверка в PowerShell:
```powershell
Get-FileHash .\03_UV_50_50_Balanced\2_UEFI_SB\*.bin -Algorithm SHA256
```

---

## English summary

* **Download everything at once:** [Releases](../../releases/latest) → `X99TF_GHX99015_BIOS_Pack_v1.1.zip`, or grab individual files from the folders.
* **For HUANANZHI X99-TF (`GHX99014` / `GHX99015`) only.** Do not flash onto any other X99 board — high risk of a brick that needs a CH341A programmer to recover.
* Base: `GHX99015` (05/25/2020), extended mod based on [Koshak1013/HuananzhiX99_BIOS_mods](https://github.com/Koshak1013/HuananzhiX99_BIOS_mods) (`Huananzhi X99-TF / 2020-05-25`, `kot_v011`). Xeon E5 v3: `306F2` microcode removed + `ser8989_S3TurboHack` all-core turbo unlock with undervolt; E5 v4 microcode `406F1` rev `0xB000040` kept.
* **Power limits unlocked** (`PL1 200 W`, `PL2 250 W`, `Tau 56 s`, `IccMax 160 A`) — keep the VRM cooled. Lower PL1/PL2 in `IntelRCSetup → Advanced Power Management Configuration → SOCKET RAPL Config`. On 14–18-core Xeons you can also cap `Cores Enabled` (e.g. `12` on an 18-core CPU for cooler VRM and steadier gaming boost, trading away full multi-thread render throughput). **Do not set `Power Technology` to `Custom`.**
* Folders: `<undervolt tier>/<mode>/`. Tiers: `0/0`, `−40/−30`, `−50/−50` (recommended), `−70/−50` mV. Modes: `1_Legacy` (CSM), `2_UEFI_SB` (UEFI + ReBAR + Secure Boot), `3_UEFI_SB_TPM` (+ TPM 2.0). UEFI builds include both **2011 and 2023 Microsoft Secure Boot certificates** (`KEK 2K CA 2023`, `Windows UEFI CA 2023`, `Microsoft UEFI CA 2023`, `Microsoft Option ROM UEFI CA 2023`) pre-enrolled in NVRAM and factory defaults (`KEKDefault`/`dbDefault`). Secure Boot and TPM are not in the BIOS menu — choose the mode at flash time.
* Flash with `flash.bat` (as admin): it backs up first (full 16 MB if allowed, otherwise the 8 MB BIOS region), waits for you to copy the backup, then writes **only the 8 MB BIOS region** and verifies it. `*_16MB_CH341A.bin` files are for an external programmer only.
* **v3 unlock:** rename `C:\Windows\System32\mcupdate_GenuineIntel.dll` so Windows does not reload the `306F2` microcode (verify all-core boost under load in HWiNFO64/CPU-Z).
* **MBR → GPT / ReBAR / TPM checks:** find your OS disk `N` via `Get-Partition -DriveLetter C | Get-Disk` before running `mbr2gpt /validate /disk:N /allowFullOS` and `/convert`. Verify ReBAR in GPU-Z (`Resizable BAR: Enabled`). TPM-LPC-X2 10-pin (Infineon SLB9665) works on `JLPC1` / `DEBUG1` (seat only when unplugged, verify key pin / Pin 1; check via `tpm.msc` or admin PowerShell `Get-Tpm` & `Confirm-SecureBootUEFI`).
* **Troubleshooting:** if UEFI builds show no boot drive, your OS is MBR (temporarily enable `CSM Support`, run `mbr2gpt`, then disable CSM). Clear CMOS (`JCMOS`) if manual RAM timings fail to POST.
* DDR4 tops out at 2133 MHz on this platform; preset manual timings `12-12-12-28-12-200` (tested on Atermiter DDR4 with Micron chips) are disabled by default.

---

## Лицензия / License

Автор сборки — **pavelcanton**. Скрипты и документация — **MIT** (см. [`LICENSE`](LICENSE)). Модули BIOS, Intel ME, микрокоды и Intel FPT (`tools/`) принадлежат своим правообладателям. Всё предоставляется «как есть», прошивка — на ваш страх и риск.

*Built by pavelcanton. Scripts and docs are MIT-licensed. Firmware modules, Intel ME, microcode and Intel FPT belong to their respective owners. Provided as is; flash at your own risk.*
