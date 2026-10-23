# Ochre — автообновления

Дата: 2026-10-24
Статус: дизайн согласован, ожидает ревью спецификации
Ветка: `feature/auto-updates`

## 1. Цель

Ochre сам узнаёт о новой версии, показывает это в панели и на значке в строке меню и ставит её одним нажатием: скачивание, замена приложения, перезапуск.

Критерии успеха:
- Через сутки после публикации релиза запущенная копия показывает строку «Доступна версия X» и точку на значке.
- Одно нажатие «Установить и перезапустить» приводит к запущенной новой версии без окон Sparkle и без второго клика.
- Обновление, не подписанное нашим ключом EdDSA или не подписанное Developer ID, не устанавливается.
- Цели по ресурсам при закрытой панели не меняются: проверка — один HTTP-запрос раз в сутки.

Не цели: дельта-обновления, бета-канал, кнопка «Пропустить версию», показ списка изменений внутри приложения, обновление установленной 1.0.0 (в ней нет обновлятеля; её пользователи один раз скачивают новую версию вручную).

## 2. Подход

Sparkle 2 (ровно 2.10.0) со своим интерфейсом: реализация протокола `SPUUserDriver`. Sparkle отвечает за проверку ленты, скачивание, проверку подписей (EdDSA и Apple code signing), замену бандла и перезапуск. Ochre отвечает только за показ состояния и за ответы на запросы Sparkle.

Отклонены: стандартный интерфейс Sparkle (отдельное окно и два клика) и собственный обновлятель без Sparkle (замена запущенного приложения, App Translocation, `/Applications` без прав записи и откат пришлось бы решать самим).

## 3. Компоненты

| Файл | Ответственность |
| --- | --- |
| `Sources/MetricsCore/Updates/UpdateState.swift` | Чистая модель состояния и переходов, без зависимости от Sparkle. Покрыта тестами. |
| `Sources/Ochre/Updates/PanelUserDriver.swift` | `SPUUserDriver`: переводит вызовы Sparkle в события `UpdateState`, хранит ответные замыкания Sparkle. |
| `Sources/Ochre/Updates/UpdateController.swift` | `@MainActor @Observable`: владеет `SPUUpdater` и драйвером, публикует `state`, методы `install()`, `checkNow()`, `retry()`, свойство `automaticallyChecks`. |
| `Sources/Ochre/Popover/Components/UpdateRow.swift` | Строка в подвале панели над «Настройки / Выход». |
| `MenuBarRenderer` / `StatusItemController` | Точка на значке, пока есть неустановленное обновление. |
| `SettingsView` (раздел «Общие») | Версия, переключатель «Проверять обновления автоматически», кнопка «Проверить сейчас» с подписью результата. |

### 3.1 `UpdateState`

```swift
public enum UpdateState: Equatable, Sendable {
    case idle
    case checking                                   // только при ручной проверке
    case upToDate                                   // только после ручной проверки
    case available(version: String, notesURL: URL?)
    case downloading(version: String, progress: Double?)   // nil — длина неизвестна
    case installing(version: String)
    case failed(message: String)
}
```

События (`UpdateEvent`) и функция `UpdateState.reduce(_:_:) -> UpdateState`:
- `checkStarted(userInitiated:)` → `checking` при ручной проверке, иначе состояние не меняется;
- `found(version:notesURL:)` → `available`;
- `notFound(userInitiated:)` → `upToDate` при ручной, иначе `idle`;
- `downloadStarted`, `expectedLength(UInt64)`, `received(UInt64)` → `downloading` с долей `received / expected`, ограниченной 0…1; без известной длины доля `nil`;
- `extracting`, `readyToInstall`, `installing` → `installing`;
- `error(message:userInitiated:)` → `failed` при ручной проверке или во время скачивания и установки; при фоновой проверке → `idle`;
- `dismissed` → `idle` из `checking`, `downloading` и `installing`; `available`, `failed` и `upToDate` сохраняются (Sparkle вызывает `dismissUpdateInstallation` сразу после подтверждения ошибки, и строка «Не удалось обновить» не должна пропасть).

Счётчики байтов хранятся рядом с состоянием (`UpdateProgress`), чтобы `reduce` оставался чистым.

### 3.2 Поведение драйвера

- `showUpdatePermissionRequest` не вызывается: в Info.plist `SUEnableAutomaticChecks = YES`. Если всё же вызван, отвечаем «проверять автоматически, без профиля системы».
- `showUpdateFound(appcastItem:state:reply:)`: сохраняем `reply`, состояние `available`. Ссылка «Что нового» — `appcastItem.releaseNotesURL` (страница релиза на GitHub). Если обновление уже скачано ранее (`state.stage != .notDownloaded`), нажатие «Установить» сразу ведёт к установке.
- `install()` вызывает сохранённый `reply(.install)`.
- `showReadyToInstallAndRelaunch(reply)` сразу отвечает `.install` — второго клика нет.
- `showInstallingUpdate(applicationTerminated:retryTerminatingApplication:)` → `installing`.
- `showUpdateInstalledAndRelaunched(_:acknowledgement:)` → сразу `acknowledgement()`.
- `showUserInitiatedUpdateCheck(cancellation:)` → `checking`.
- `showUpdateNotFoundWithError` / `showUpdaterError` → события `notFound` / `error`, затем `acknowledgement()` сразу; показ результата — наша забота.
- `dismissUpdateInstallation` → событие `dismissed`; сохранённые замыкания обнуляются.
- `showUpdateInFocus` открывает панель.

### 3.3 Интерфейс

- Строка в панели:
  - `available` — «● Доступна версия 1.1 · Что нового · [Установить и перезапустить]»;
  - `downloading` — «Скачивание 1.1» и полоса прогресса (неопределённая, если доля `nil`);
  - `installing` — «Установка…»;
  - `failed` — «Не удалось обновить» и «Повторить»;
  - `checking` — «Проверка обновлений…» (бывает только после ручной проверки или «Повторить»);
  - `upToDate` в панели не показывается, только в настройках.
- Точка на значке и в строке панели — системный акцентный цвет (`NSColor.controlAccentColor`), а не охра: по принципу «цвет = нагрев» хроматические цвета интерфейса означают только нагрузку. Точка есть в состояниях `available`, `downloading`, `installing`. В `failed` точки нет: ошибка ручной проверки не означает, что обновление существует.
- Озвучка VoiceOver значка дополняется фразой «доступно обновление».

## 4. Сборка и подпись

- `Package.swift`: `.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")`, продукт `Sparkle` в зависимостях цели `Ochre`, `linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]`.
- `build-app.sh`:
  - копирует `Sparkle.framework` из каталога сборки в `Contents/Frameworks` через `ditto`;
  - подписывает изнутри наружу: `XPCServices/Installer.xpc`, `XPCServices/Downloader.xpc` (с `--preserve-metadata=entitlements`), `Autoupdate`, `Updater.app`, сам фреймворк, затем приложение;
  - у каждого шага `--options runtime`, у Developer ID ещё и `--timestamp`;
  - в конце `codesign --verify --deep --strict`.
- `Info.plist`:
  - `SUFeedURL` = `https://github.com/aesarva/ochre/releases/latest/download/appcast.xml`;
  - `SUPublicEDKey`;
  - `SUEnableAutomaticChecks` = `YES`;
  - `SUScheduledCheckInterval` = `86400`.
- Номер сборки (`CFBundleVersion`) — по-прежнему число коммитов. Sparkle сравнивает по нему, поэтому релиз всегда собирается из `main`.
- Отладка: параметр запуска `-UpdateFeedURL <url>` через `SPUUpdaterDelegate.feedURLString(for:)`, только из argument domain, как остальные отладочные параметры.

## 5. Ключи и релиз

Однократно:
1. `.build/artifacts/sparkle/Sparkle/bin/generate_keys` создаёт пару EdDSA. Приватный ключ сохраняется в связке ключей, публичный — в Info.plist.
2. `generate_keys -x <файл>` — резервная копия приватного ключа вне Mac. Без неё после потери ключа установленные копии не примут новые обновления.

`release.sh` после нотаризации и скрепления DMG:
1. `sign_update dist/Ochre-<версия>.dmg` выдаёт `sparkle:edSignature` и `length`.
2. Генерирует `dist/appcast.xml` с одним элементом:
   - `sparkle:version` (номер сборки), `sparkle:shortVersionString`, `pubDate`;
   - `sparkle:minimumSystemVersion` = `26.0`;
   - `sparkle:releaseNotesLink` = `https://github.com/aesarva/ochre/releases/tag/v<версия>`;
   - `enclosure` с `url` = `https://github.com/aesarva/ochre/releases/download/v<версия>/Ochre-<версия>.dmg`, подписью и длиной.

К релизу на GitHub прикрепляются оба файла. Лента и DMG становятся доступны одновременно в момент публикации.

## 6. Ошибки

- Нет сети или GitHub недоступен при фоновой проверке — молча, следующая попытка по расписанию.
- Ошибка при ручной проверке, скачивании или установке — `failed` с текстом ошибки Sparkle и кнопкой «Повторить» (`checkNow()`).
- Неверная подпись EdDSA или Developer ID — Sparkle отказывает в установке, показ как выше.
- Приложение запущено не из `/Applications` или из образа DMG — Sparkle сам обрабатывает App Translocation и права; если установка невозможна, это ошибка `failed`.

## 7. Тесты и проверка

- `Tests/MetricsCoreTests/UpdateStateTests.swift`: переходы из §3.1, включая фоновую ошибку → `idle`, ручную → `failed`, прогресс с неизвестной длиной и ограничение доли единицей.
- Сквозная проверка вживую до первого релиза:
  1. Старая сборка (номер N) и новая (N+1) с подписанным DMG и appcast раздаются с `127.0.0.1`.
  2. Старая запускается с `-UpdateFeedURL`.
  3. Проверяется: строка и точка появились, «Установить» скачивает и перезапускает, у запущенной копии номер сборки N+1.
  4. Негативный случай: DMG с испорченной подписью отклоняется, строка показывает «Не удалось обновить».

## 8. Документация

- **README (EN/RU):**
  - «Приватное» — единственный сетевой запрос — проверка обновлений на GitHub раз в сутки, без данных о системе, отключается в настройках;
  - пункт об обновлениях в «Возможностях»;
  - в FAQ — вопрос «Как обновить?» (1.0.0 обновляется вручную один раз).
- **CONTRIBUTING:**
  - создание ключа и резервная копия;
  - два файла в релизе;
  - параметр `-UpdateFeedURL`.
