# Автообновления Ochre — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ochre находит новую версию раз в сутки, показывает строку в панели и точку на значке и ставит обновление одним нажатием.

**Architecture:** Sparkle 2.10.0 делает проверку, скачивание, проверку подписей, замену и перезапуск. Наш `PanelUserDriver` (реализация `SPUUserDriver`) переводит вызовы Sparkle в события чистой модели `UpdateModel` из MetricsCore. `UpdateController` публикует её для панели, значка и настроек. Лента версий `appcast.xml` прикрепляется к каждому релизу на GitHub.

**Tech Stack:** Swift 6.2, SwiftPM, SwiftUI/AppKit, Sparkle 2.10.0, Swift Testing, bash.

**Spec:** `docs/superpowers/specs/2026-10-24-auto-updates-design.md`

## Global Constraints

- Ветка `feature/auto-updates`, слияние в `develop` через `--no-ff` в конце Task 7. Коммиты в стиле `feat:` / `fix:` / `docs:` / `chore:`.
- Sparkle — ровно `2.10.0` (`exact:`), продукт `Sparkle`.
- `SUFeedURL` = `https://github.com/aesarva/ochre/releases/latest/download/appcast.xml`.
- `SUEnableAutomaticChecks` = `YES`, `SUScheduledCheckInterval` = `86400`.
- Ссылка на DMG: `https://github.com/aesarva/ochre/releases/download/v<версия>/Ochre-<версия>.dmg`; «Что нового»: `https://github.com/aesarva/ochre/releases/tag/v<версия>`; `sparkle:minimumSystemVersion` = `26.0`.
- Тексты интерфейса (русские, дословно): «Доступна версия %@», «Что нового», «Установить и перезапустить», «Скачивание %@», «Установка…», «Не удалось обновить», «Повторить», «Проверка обновлений…», «Установлена последняя версия», «Проверять обновления автоматически», «Проверить сейчас», «Версия %@ (%@)»; VoiceOver: «доступно обновление».
- Цвет точки — `NSColor.controlAccentColor` / `Color.accentColor`, не цвета шкалы нагрева.
- Swift-команды запускаются с `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (у Command Line Tools нет макросов Swift Testing).
- Отладочные параметры читаются только из argument domain (`UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)`), как в `AppDelegate`.

## Review Focus

1. **Ad-hoc сборка с hardened runtime не загружает Sparkle.framework** (library validation требует общий Team ID, у ad-hoc его нет). Ожидание: `ARCHS=arm64 scripts/build-app.sh` даёт запускающееся приложение. Проверка — Task 2, Step 5.
2. **Двойное нажатие «Установить»** или нажатие после того, как Sparkle уже забрал ответ. Ожидание: ответ Sparkle вызывается ровно один раз, второе нажатие ничего не делает. Проверка — Task 3, Step 4 (замыкание обнуляется после вызова), вживую — Task 6.
3. **Панель закрыта во время скачивания.** Ожидание: установка продолжается, при открытии панели строка показывает текущий прогресс. Состояние живёт в `UpdateController`, а не во view. Проверка — Task 6, Step 4.
4. **Приложение запущено не из `/Applications`** (из смонтированного DMG или из «Загрузок» с карантином). Ожидание: строка «Не удалось обновить», без падения и без зависшего «Установка…». Проверка — Task 6, Step 6.
5. **Сервер отдаёт больше байт, чем объявлено, или не объявляет длину.** Ожидание: прогресс не выходит за 1, без длины — неопределённая полоса. Проверка — Task 1, тесты `progressIsClamped` и `unknownLengthHasNilProgress`.

---

### Task 1: Модель состояния обновлений

**Files:**
- Create: `Sources/MetricsCore/Updates/UpdateState.swift`
- Test: `Tests/MetricsCoreTests/UpdateStateTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum UpdateState: Equatable, Sendable {
      case idle, checking, upToDate
      case available(version: String, notesURL: URL?)
      case downloading(version: String, progress: Double?)
      case installing(version: String)
      case failed(message: String)
  }
  public enum UpdateEvent: Equatable, Sendable {
      case checkStarted(userInitiated: Bool)
      case found(version: String, notesURL: URL?)
      case notFound(userInitiated: Bool)
      case downloadStarted
      case expectedLength(UInt64)
      case received(UInt64)
      case installing          // распаковка, готовность и сама установка
      case error(message: String, userInitiated: Bool)
      case dismissed
  }
  public struct UpdateModel: Equatable, Sendable {
      public init()
      public private(set) var state: UpdateState   // .idle
      public mutating func apply(_ event: UpdateEvent)
      public var showsBadge: Bool                   // available, downloading, installing
  }
  ```

- [ ] **Step 1: Write the failing tests** — `@Suite struct UpdateStateTests` с хелпером `func model(_ events: UpdateEvent...) -> UpdateModel`:
  - `backgroundCheckDoesNotShowChecking`: `.checkStarted(userInitiated: false)` → `.idle`
  - `manualCheckShowsChecking`: `.checkStarted(userInitiated: true)` → `.checking`
  - `foundShowsAvailable`: `.found("1.1", url)` → `.available(version: "1.1", notesURL: url)`, `showsBadge == true`
  - `manualNotFoundIsUpToDate` / `backgroundNotFoundIsIdle`
  - `downloadProgress`: found("1.1") → downloadStarted → expectedLength(200) → received(50) → received(50) → `.downloading(version: "1.1", progress: 0.5)`
  - `progressIsClamped`: expectedLength(100), received(150) → progress `1.0`
  - `unknownLengthHasNilProgress`: downloadStarted, received(10) → `.downloading(version: "1.1", progress: nil)`
  - `installingKeepsVersion`: found("1.1") → downloadStarted → installing → `.installing(version: "1.1")`
  - `backgroundErrorIsSilent`: `.error("x", userInitiated: false)` из `.idle` → `.idle`, `showsBadge == false`
  - `manualErrorFails`: checkStarted(true) → error("x", userInitiated: true) → `.failed(message: "x")`, `showsBadge == false`
  - `downloadErrorFails`: found → downloadStarted → error("x", userInitiated: false) → `.failed(message: "x")`
  - `dismissKeepsAvailableAndFailed`: found → dismissed → `.available`; checkStarted(true) → error(true) → dismissed → `.failed`
  - `dismissClearsInProgress`: found → downloadStarted → dismissed → `.idle`
  - `newDownloadResetsCounters`: download 1 (expected 100, received 100), снова found("1.2") → downloadStarted → received(10) → progress `nil`

- [ ] **Step 2: Run, expect FAIL** — `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter UpdateStateTests` → ошибка компиляции «cannot find 'UpdateModel'».

- [ ] **Step 3: Implement `UpdateState.swift`.** В `UpdateModel` приватные `expected: UInt64?`, `received: UInt64`; `downloadStarted` их обнуляет. Версия для `downloading` и `installing` берётся из текущего состояния (`available`, `downloading`), иначе `""`. Правило ошибки: `failed`, если `userInitiated` или текущее состояние `downloading` / `installing`; иначе `idle`. `dismissed` переводит в `idle` только из `checking`, `downloading`, `installing`.

- [ ] **Step 4: Run, expect PASS** — та же команда, затем полный `swift test`: все тесты зелёные.

- [ ] **Step 5: Commit** — `feat: update state model for auto-updates`.

---

### Task 2: Sparkle в сборке, ключ EdDSA, Info.plist

**Files:**
- Modify: `Package.swift` (dependencies, цель `Ochre`)
- Modify: `scripts/build-app.sh` (после копирования Info.plist и перед финальной подписью)
- Modify: `Resources/Info.plist`

**Interfaces:**
- Produces: `import Sparkle` доступен в цели `Ochre`; `build/Ochre.app/Contents/Frameworks/Sparkle.framework` подписан; в Info.plist ключи `SUFeedURL`, `SUPublicEDKey`, `SUEnableAutomaticChecks`, `SUScheduledCheckInterval`; инструменты `generate_keys` и `sign_update` лежат в `$(find .build -type f -path '*/Sparkle/bin/sign_update' | head -1)` (путь находит Task 5).

- [ ] **Step 1: Package.swift** — `dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")]`; у `Ochre` `dependencies: ["MetricsCore", .product(name: "Sparkle", package: "Sparkle")]` и `linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]`. Run: `swift package resolve && swift build` → `Build complete!`.

- [ ] **Step 2: Ключ EdDSA** — `$(find .build -type f -path '*/Sparkle/bin/generate_keys' | head -1)`; macOS может спросить доступ к связке ключей — это делает пользователь. Вывод содержит `<key>SUPublicEDKey</key><string>…</string>`. Если ключ уже есть, `generate_keys -p` печатает публичный. Резервную копию (`generate_keys -x ~/ochre-sparkle-private.key`) пользователь переносит в надёжное место сам; в репозиторий она не попадает.

- [ ] **Step 3: Info.plist** — четыре ключа из Global Constraints, `SUPublicEDKey` из Step 2.

- [ ] **Step 4: build-app.sh**
  - После `cp Resources/Info.plist` скопировать `ditto "$BIN_DIR/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"`; если в `$BIN_DIR` его нет, `find "$BIN_DIR"/.. -name Sparkle.framework -maxdepth 3`.
  - Перед финальной подписью приложения подписать изнутри наружу с `"${SIGN_FLAGS[@]}"`:
    - `Versions/B/XPCServices/Installer.xpc`;
    - `Versions/B/XPCServices/Downloader.xpc` с `--preserve-metadata=entitlements`;
    - `Versions/B/Autoupdate`;
    - `Versions/B/Updater.app`;
    - сам `Sparkle.framework`.
  - Финальная проверка: `codesign --verify --deep --strict "$APP"`.

- [ ] **Step 5: Проверка ad-hoc сборки (Review Focus 1)** — `ARCHS=arm64 scripts/build-app.sh && open build/Ochre.app && sleep 3 && pgrep -x Ochre`. Ожидание: PID напечатан. Если процесс не жив и в `log show --last 1m --predicate 'process == "Ochre"'` есть `Library Validation`/`not valid for use in process`: для ad-hoc (`SIGN_IDENTITY="-"`) подписывать фреймворк и приложение без `--options runtime`. Developer ID-путь не меняется.

- [ ] **Step 6: Проверка Developer ID** — `scripts/build-app.sh` с найденным `SIGN_IDENTITY` (как в `release.sh`), затем `codesign --verify --deep --strict --verbose=2 build/Ochre.app` → `valid on disk`, `satisfies its Designated Requirement`; `lipo -archs build/Ochre.app/Contents/Frameworks/Sparkle.framework/Sparkle` → `x86_64 arm64`.

- [ ] **Step 7: Commit** — `chore: embed and sign Sparkle 2.10.0, updater keys in Info.plist`.

---

### Task 3: Драйвер Sparkle и контроллер обновлений

**Files:**
- Create: `Sources/Ochre/Updates/PanelUserDriver.swift`
- Create: `Sources/Ochre/Updates/UpdateController.swift`
- Modify: `Sources/Ochre/App/AppDelegate.swift` (создание контроллера и передача его в панель, значок и настройки — проводка в Task 4, здесь только создание и `start`)

**Interfaces:**
- Consumes: `UpdateModel`, `UpdateEvent` (Task 1); `import Sparkle` (Task 2).
- Produces:
  ```swift
  @MainActor @Observable final class UpdateController: NSObject, SPUUpdaterDelegate {
      init(feedOverride: String?, onShowPanel: @escaping () -> Void)
      private(set) var model: UpdateModel
      var automaticallyChecks: Bool { get set }      // прокси к updater.automaticallyChecksForUpdates
      let currentVersion: String                     // CFBundleShortVersionString
      let currentBuild: String                       // CFBundleVersion
      func start()                                   // try updater.start(); ошибка → model.apply(.error(..., userInitiated: true))
      func install()
      func checkNow()                                // и для «Повторить»
  }
  @MainActor final class PanelUserDriver: NSObject, SPUUserDriver {
      init(onEvent: @escaping (UpdateEvent) -> Void, onShowPanel: @escaping () -> Void)
      func install()                                 // вызывает сохранённый reply(.install) один раз
  }
  ```

- [ ] **Step 1: PanelUserDriver** — соответствие из спецификации §3.2.
  - Флаг `userInitiated` ставится в `showUserInitiatedUpdateCheck` и сбрасывается после `found` / `notFound` / `error`.
  - `showUpdateFound`: событие `.found(version: item.displayVersionString, notesURL: item.releaseNotesURL ?? item.infoURL)`, `reply` сохраняется в `pendingChoice`.
  - `showDownloadInitiated`, `showDownloadDidReceiveExpectedContentLength`, `showDownloadDidReceiveDataOfLength` → `.downloadStarted` / `.expectedLength` / `.received`.
  - `showDownloadDidStartExtractingUpdate`, `showExtractionReceivedProgress`, `showInstallingUpdate` → `.installing`.
  - `showReadyToInstallAndRelaunch(reply)` → `.installing`, затем сразу `reply(.install)`.
  - `showUpdateNotFoundWithError` и `showUpdaterError` → `.notFound` / `.error(message: error.localizedDescription, …)`, затем `acknowledgement()` сразу.
  - `showUpdateInstalledAndRelaunched` → `acknowledgement()`.
  - `showUpdatePermissionRequest` → `reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))`.
  - `dismissUpdateInstallation` → `.dismissed`, `pendingChoice = nil`.
  - `showUpdateInFocus` → `onShowPanel()`.
  - Методы протокола без `@MainActor` в заголовке Sparkle помечаются `nonisolated` с `MainActor.assumeIsolated` (Sparkle вызывает драйвер на главном потоке).

- [ ] **Step 2: UpdateController**
  - `SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: driver, delegate: self)`.
  - `feedURLString(for:)` возвращает `feedOverride`.
  - `install()`: если `model.state` — `.available`, вызвать `driver.install()`.
  - `checkNow()`: `updater.checkForUpdates()`.

- [ ] **Step 3: AppDelegate** — `feedOverride = defaults["UpdateFeedURL"] as? String` из argument domain. Создать контроллер до `StatusItemController` и вызвать `start()`; `onShowPanel` открывает панель через тот же код, что `OpenPopoverOnLaunch`. Хранить в `private var updateController: UpdateController?`.

- [ ] **Step 4: Проверка однократного ответа (Review Focus 2)** — в `PanelUserDriver.install()`: `guard let reply = pendingChoice else { return }; pendingChoice = nil; reply(.install)`. Сборка: `ARCHS=arm64 scripts/build-app.sh` → без ошибок и предупреждений concurrency. Запуск: `build/Ochre.app/Contents/MacOS/Ochre -UpdateFeedURL http://127.0.0.1:9/appcast.xml` живёт дольше 10 секунд (фоновая ошибка молчит).

- [ ] **Step 5: Commit** — `feat: Sparkle user driver and update controller`.

---

### Task 4: Интерфейс — строка в панели, точка на значке, настройки

**Files:**
- Modify: `Sources/MetricsCore/Presentation/MenuBarContent.swift` (`MenuBarSegment`, `segments`, `spokenLabel`)
- Modify: `Sources/Ochre/MenuBar/MenuBarRenderer.swift` (новый сегмент в `attributedTitle` и `image`)
- Modify: `Sources/Ochre/MenuBar/StatusItemController.swift` (наблюдать `updates.model`)
- Create: `Sources/Ochre/Popover/Components/UpdateRow.swift`
- Modify: `Sources/Ochre/Popover/PopoverView.swift` (строка над подвалом), `PopoverController.swift` (передача контроллера)
- Modify: `Sources/Ochre/Settings/SettingsView.swift` (`GeneralSettingsTab`), `SettingsWindowController.swift`
- Modify: `Sources/Ochre/App/AppDelegate.swift` (передать `UpdateController` в три места)
- Test: `Tests/MetricsCoreTests/PresentationTests.swift`

**Interfaces:**
- Consumes: `UpdateController` (Task 3), `UpdateModel.showsBadge` (Task 1).
- Produces:
  - `MenuBarSegment.updateDot`;
  - `MenuBarContent.segments(items:snapshot:cpuHistory:active:updateAvailable: Bool = false)`;
  - `UpdateRow(updates: UpdateController)`.

- [ ] **Step 1: Failing tests в `PresentationTests`**
  - `updateDotIsLast`: `segments(items: [.cpuPercent], snapshot: snap(), cpuHistory: [], active: [.diskSpace], updateAvailable: true).last == .updateDot`; предупреждение `⚠` стоит перед точкой.
  - `noDotByDefault`: без `updateAvailable` нет `.updateDot`.
  - `spokenLabelMentionsUpdate`: `spokenLabel(…updateAvailable: true)` заканчивается на `, доступно обновление`.

- [ ] **Step 2: Run, expect FAIL** — `swift test --filter PresentationTests`.

- [ ] **Step 3: Implement**
  - `MenuBarContent`: дописать `.updateDot` последним сегментом; `spokenLabel` добавляет «доступно обновление» для `.updateDot`.
  - `MenuBarRenderer`: точка 6×6 pt `controlAccentColor` как `NSTextAttachment`, по центру `capHeight`, с тем же пробелом-разделителем.
  - `StatusItemController`: принимает `updates: UpdateController`, читает `updates.model.showsBadge` в `observe()` и `render()`.

- [ ] **Step 4: UpdateRow** — `switch updates.model.state`:
  - `.available` — точка `Color.accentColor`, «Доступна версия 1.1», ссылка «Что нового» (`Link`, только если `notesURL != nil`), кнопка «Установить и перезапустить» (`.buttonStyle(.glassProminent)`, `.controlSize(.small)`);
  - `.downloading` — «Скачивание 1.1» и `ProgressView(value:)` или неопределённый `ProgressView()` при `nil`;
  - `.installing` — «Установка…» и маленький `ProgressView()`;
  - `.checking` — «Проверка обновлений…»;
  - `.failed` — «Не удалось обновить», `.help(message)`, кнопка «Повторить» → `checkNow()`;
  - `.idle` и `.upToDate` — `EmptyView()`.

  Шрифт 12 pt, как у подвала. В `PopoverView` строка стоит между `Divider()` и `HStack` подвала.

- [ ] **Step 5: Настройки → Общие**
  - `Toggle("Проверять обновления автоматически", isOn: $updates.automaticallyChecks)`.
  - `LabeledContent("Версия \(updates.currentVersion) (\(updates.currentBuild))")` с кнопкой «Проверить сейчас» (`disabled` при `.checking`, `.downloading`, `.installing`).
  - Под ней подпись по состоянию: «Проверка обновлений…», «Установлена последняя версия», «Доступна версия X», «Не удалось обновить: …».
  - `SettingsView` и `SettingsWindowController` получают `updates: UpdateController`.
  - `SnapshotExporter` получает контроллер, если вызывает `SettingsView`.

- [ ] **Step 6: Run** — `swift test` → все зелёные. `ARCHS=arm64 scripts/build-app.sh` → собирается. Снимок: `build/Ochre.app/Contents/MacOS/Ochre -SnapshotDir <scratch> -UpdateFeedURL http://127.0.0.1:9/x` — панель и настройки без строки обновления, настройки с версией.

- [ ] **Step 7: Commit** — `feat: update row in panel, menu bar dot and update settings`.

---

### Task 5: Лента версий в release.sh

**Files:**
- Create: `scripts/make-appcast.sh`
- Modify: `scripts/release.sh` (после `stapler staple "$DMG"` и в ветке `--unsigned` после создания DMG)

**Interfaces:**
- Consumes: `sign_update` (Task 2), `CFBundleVersion` и `CFBundleShortVersionString` из `build/Ochre.app/Contents/Info.plist`.
- Produces: `scripts/make-appcast.sh <dmg> <version> <build> > dist/appcast.xml`.

- [ ] **Step 1: make-appcast.sh**
  - `SIG_ATTRS="$("$SIGN_UPDATE" "$DMG")"` — печатает `sparkle:edSignature="…" length="…"`.
  - Вывод — RSS 2.0 с `xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"`, один `<item>`:
    - `title`: `Ochre <версия>`;
    - `pubDate` в формате RFC 822, `LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000"`;
    - `sparkle:version` (номер сборки), `sparkle:shortVersionString`, `sparkle:minimumSystemVersion` `26.0`;
    - `sparkle:releaseNotesLink`;
    - `<enclosure url="…" type="application/octet-stream" $SIG_ATTRS/>`;
    - значения URL — из Global Constraints.
  - Путь к `sign_update` ищется через `find .build -type f -path '*/Sparkle/bin/sign_update'`; если не найден — выход с ошибкой «Нет sign_update: сначала swift package resolve».

- [ ] **Step 2: release.sh** — после DMG: `scripts/make-appcast.sh "$DMG" "$VERSION" "$(PlistBuddy … CFBundleVersion)" > dist/appcast.xml`, затем `xmllint --noout dist/appcast.xml`. Финальное сообщение перечисляет оба файла для релиза.

- [ ] **Step 3: Проверка** — `scripts/release.sh 1.1.0 --unsigned`. Ожидание:
  - `xmllint` молчит;
  - `grep -c 'sparkle:edSignature' dist/appcast.xml` → `1`;
  - URL `.../download/v1.1.0/Ochre-1.1.0.dmg`;
  - `sparkle:version` равен номеру сборки из Info.plist.

- [ ] **Step 4: Commit** — `chore: generate signed appcast in release.sh`.

---

### Task 6: Сквозная проверка обновления

Без изменений в коде, если всё работает. Всё, что найдено, исправляется в задаче, которой принадлежит код, отдельным коммитом `fix:`.

- [ ] **Step 1: «Новая» сборка** — `scripts/release.sh 9.9.9 --unsigned`. Скопировать `dist/Ochre-9.9.9.dmg` и `dist/appcast.xml` в `<scratch>/feed/`, заменив в appcast базовый URL на `http://127.0.0.1:8740/`. Подпись EdDSA от URL не зависит.

- [ ] **Step 2: «Старая» сборка** — та же сборка с подменённым номером: скопировать `build/Ochre.app` в `<scratch>/old/Ochre.app`, `PlistBuddy -c "Set :CFBundleVersion 1"`, `CFBundleShortVersionString 1.0.0`, переподписать ad-hoc (`codesign --force --deep -s -`). Положить в `~/Applications/Ochre Test.app`, чтобы место было записываемым.

- [ ] **Step 3: Запуск** — `python3 -m http.server 8740` из `<scratch>/feed` (в фоне); остановить установленный Ochre; `"~/Applications/Ochre Test.app/Contents/MacOS/Ochre" -UpdateFeedURL http://127.0.0.1:8740/appcast.xml`, затем «Проверить сейчас» в настройках. Ожидание: в панели «Доступна версия 9.9.9», на значке точка (снимок через `-SnapshotDir`).

- [ ] **Step 4: Установка** — нажать «Установить и перезапустить» и закрыть панель во время скачивания (Review Focus 3). Ожидание: процесс перезапустился; `PlistBuddy -c "Print :CFBundleShortVersionString" ~/Applications/Ochre\ Test.app/Contents/Info.plist` → `9.9.9`; в логе HTTP-сервера `GET /Ochre-9.9.9.dmg 200`.

- [ ] **Step 5: Испорченная подпись** — вернуть старую сборку, заменить `sparkle:edSignature` в appcast на чужую строку той же длины. Ожидание: после «Установить» строка «Не удалось обновить», версия остаётся `1.0.0`.

- [ ] **Step 6: Запуск из DMG (Review Focus 4)** — смонтировать старую сборку в DMG через `hdiutil` и запустить оттуда. Ожидание: «Не удалось обновить» или установка в исходное место по правилам Sparkle; без падения и без вечного «Установка…».

- [ ] **Step 7: Уборка** — удалить `~/Applications/Ochre Test.app`, остановить сервер, `defaults delete com.alexsarva.Ochre SULastCheckTime` (тестовые ключи Sparkle), запустить обычный `build/Ochre.app`.

---

### Task 7: Документация

**Files:**
- Modify: `README.md`, `README.ru.md`, `CONTRIBUTING.md`

- [ ] **Step 1: README (EN и RU).**
  - **Private / «Приватное»:** «The only network request is a daily update check against GitHub; it sends no system data and can be turned off in Settings.» / «Единственный сетевой запрос — проверка обновлений на GitHub раз в сутки: никаких данных о системе, отключается в настройках».
  - **Features:** абзац «**Updates.** …» / «**Обновления.** …» — одно нажатие «Установить и перезапустить».
  - **FAQ:** «How do I update?» / «Как обновить?» — Ochre проверяет сам; версию 1.0.0 нужно один раз обновить вручную, скачав DMG.

- [ ] **Step 2: CONTRIBUTING.**
  - **One-time setup:** шаг 4 — `generate_keys` и резервная копия через `generate_keys -x`.
  - **Releasing:** шаг 4 — прикреплять `Ochre-<version>.dmg` и `appcast.xml`.
  - **Debugging:** `-UpdateFeedURL <url>`.

- [ ] **Step 3: Commit** — `docs: auto-updates in README and CONTRIBUTING`. Затем полный `swift test`, слияние `feature/auto-updates` в `develop` (`--no-ff`) и удаление ветки.
