# Visual Redesign («Карта кристалла» на Liquid Glass) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Перевести интерфейс StatusApp на Liquid Glass (macOS 26+) с фирменной картой кристалла в панели и мини-кристаллом в строке меню; цвет в интерфейсе означает только нагрев.

**Architecture:** Чистая логика представления (шкала нагрева, раскладка мини-кристалла, полоски GPU, сегменты строки меню) — в `MetricsCore/Presentation` под тестами. SwiftUI/AppKit-слой (`StatusApp`) получает новые компоненты (`DieMapView`, `GlassTabBar`, `MetricRow`, `MirroredChart`, `StackedBar`) и переработанные вкладки. Сборщики данных не меняются, кроме чтения числа ядер GPU.

**Tech Stack:** Swift 6.4 (language mode 6), SwiftPM, SwiftUI Liquid Glass API (macOS 26: `glassEffect`, `GlassEffectContainer`), Swift Charts, AppKit, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-10-15-visual-redesign-design.md` (базовая: `docs/superpowers/specs/2026-10-15-status-app-design.md`)

## Global Constraints

- Все swift-команды: `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer && …` (xcode-select указывает на CLT).
- `platforms: [.macOS(.v26)]`, `LSMinimumSystemVersion 26.0`; никаких `#available`-веток и имитаций стекла материалами.
- Цвет = нагрев: единственные хроматические цвета — `#FFC46B` (Янтарь), `#FF8A5C` (Угли), `#FF5A4E` (Жар); всё остальное — системные `primary`/`secondary`/стекло. Никаких цветов «на метрику».
- Шрифты только системные: SF Pro, SF Pro Rounded (`.rounded`) для крупных чисел; все цифры `monospacedDigit()`. Без капслока в подписях.
- Анимация только в ответ на изменение данных: `.easeInOut(duration: 0.6)`; при `accessibilityReduceMotion` — без анимации.
- Панель шириной 340 pt.
- Строки интерфейса — на русском. Недоступное значение — `—`; строка/секция метрики без данных скрывается.
- Ресурсы при закрытой панели: CPU < 1 %, phys_footprint < 50 МБ (замер ≥ 60 с).
- Swift 6 mode, сборка без предупреждений, `swift test` зелёный.
- Визуальная проверка — PNG через `open build/StatusApp.app --args -SnapshotDir <dir>` (рендерит все вкладки, строку меню и настройки); смотреть их инструментом Read.

## Review Focus

1. **Чип с одним кластером или неизвестной топологией** (fallback «CPU», Intel/виртуалка) → карта кристалла и мини-кристалл рисуют один кластер, не пустоту и не падают. Тест: Task 2 (`singleClusterFallback`, `zeroCores`).
2. **Очень большие чипы** (M2/M3 Ultra, 24 ядра и больше) → мини-кристалл не выше 3 рядов. Тест: Task 2 (`ultraFitsThreeRows`).
3. **Нет данных CPU в первом тике** (CPU-сборщик возвращает nil на первом вызове) → строка меню не пустая. Тест: Task 3 (`miniDieWithoutCPUFallsBackToEmptyGrid`) + рендерер рисует значок-заглушку для пустой сетки.
4. **Загрузка вне 0…100** (процесс 142 %, шумные значения < 0) → шкала нагрева не выходит за палитру. Тест: Task 1 (`clampsOutOfRange`).
5. **Сохранённые настройки со старым `icon`** → продолжают работать и теперь показывают мини-кристалл. Тест: Task 3 (`storedIconItemRendersMiniDie`).

---

### Task 1: Платформа macOS 26 и шкала нагрева

**Files:**
- Modify: `Package.swift` (`.macOS(.v26)`), `Resources/Info.plist` (`LSMinimumSystemVersion` → `26.0`)
- Create: `Sources/MetricsCore/Presentation/HeatScale.swift`
- Test: `Tests/MetricsCoreTests/HeatScaleTests.swift`

**Interfaces:**
- Produces:
  - `public enum HeatColor: Equatable, Sendable { case cold; case rgb(red: Double, green: Double, blue: Double) }` (компоненты 0…1)
  - `public enum HeatLevel: Int, Sendable, Comparable { case neutral, amber, ember, hot; public var color: HeatColor }` (`neutral` → `.cold`; amber/ember/hot → точные hex)
  - `public enum HeatScale { public static func color(forLoad: Double) -> HeatColor; public static func temperatureLevel(_ celsius: Double) -> HeatLevel; public static let amber, ember, hot: HeatColor }`
  - Правило `color(forLoad:)`: вход обрезается до 0…100; `< 20` → `.cold`; 20…60 — линейная интерполяция Янтарь→Угли; 60…90 — Угли→Жар; `≥ 90` → Жар.
  - Правило `temperatureLevel`: `< 60` neutral, `60..<80` amber, `80..<95` ember, `≥ 95` hot.

- [ ] **Step 1: Поднять платформу** — правки `Package.swift`, `Info.plist`; `swift build` → `Build complete!` без предупреждений (если API, помеченные устаревшими в macOS 26, дают предупреждения — заменить)
- [ ] **Step 2: Написать падающие тесты**

```swift
import Testing
@testable import MetricsCore

@Suite struct HeatScaleTests {
    func rgb(_ c: HeatColor) -> (Double, Double, Double)? { if case let .rgb(r, g, b) = c { (r, g, b) } else { nil } }
    @Test func coldBelow20() {
        #expect(HeatScale.color(forLoad: 0) == .cold)
        #expect(HeatScale.color(forLoad: 19.9) == .cold)
    }
    @Test func anchors() {
        #expect(HeatScale.color(forLoad: 20) == HeatScale.amber)
        #expect(HeatScale.color(forLoad: 60) == HeatScale.ember)
        #expect(HeatScale.color(forLoad: 90) == HeatScale.hot)
        #expect(HeatScale.color(forLoad: 100) == HeatScale.hot)
        #expect(HeatScale.amber == .rgb(red: 255/255, green: 196/255, blue: 107/255))
        #expect(HeatScale.ember == .rgb(red: 255/255, green: 138/255, blue: 92/255))
        #expect(HeatScale.hot == .rgb(red: 255/255, green: 90/255, blue: 78/255))
    }
    @Test func interpolatesMidpoint() throws {
        let (r, g, b) = try #require(rgb(HeatScale.color(forLoad: 40)))
        #expect(abs(r - 1) < 1e-9); #expect(abs(g - 167/255) < 1e-9); #expect(abs(b - 99.5/255) < 1e-9)
    }
    @Test func clampsOutOfRange() {
        #expect(HeatScale.color(forLoad: 142) == HeatScale.hot)
        #expect(HeatScale.color(forLoad: -5) == .cold)
        #expect(HeatScale.color(forLoad: .nan) == .cold)
    }
    @Test func temperatureLevels() {
        #expect(HeatScale.temperatureLevel(59.9) == .neutral)
        #expect(HeatScale.temperatureLevel(60) == .amber)
        #expect(HeatScale.temperatureLevel(80) == .ember)
        #expect(HeatScale.temperatureLevel(95) == .hot)
        #expect(HeatLevel.neutral.color == .cold); #expect(HeatLevel.hot.color == HeatScale.hot)
    }
}
```

- [ ] **Step 3: Запустить — убедиться, что падает** (`swift test --filter HeatScaleTests`, «cannot find 'HeatScale'»)
- [ ] **Step 4: Реализовать `HeatScale.swift`** (NaN → `.cold`)
- [ ] **Step 5: Запустить все тесты** — `swift test`, всё зелёное
- [ ] **Step 6: Commit** — `feat: macOS 26 baseline and heat scale`

---

### Task 2: Раскладка мини-кристалла, полоски GPU, число ядер GPU

**Files:**
- Create: `Sources/MetricsCore/Presentation/MiniDieLayout.swift`, `Sources/MetricsCore/Presentation/GPUBars.swift`
- Modify: `Sources/MetricsCore/Model/GPUStats.swift`, `Sources/MetricsCore/Collectors/GPUCollector.swift`
- Test: `Tests/MetricsCoreTests/MiniDieLayoutTests.swift`, `Tests/MetricsCoreTests/GPUBarsTests.swift`

**Interfaces:**
- Consumes: `CPUStats { totalPercent, clusters: [ClusterLoad{level,name,percent}], cores: [CoreLoad{index,level,percent}] }`
- Produces:
  - `public struct MiniDieCell: Equatable, Sendable { public let row: Int; public let column: Int; public let load: Double }`
  - `public enum MiniDieLayout { public static let maxRows = 3; public static func columns(clusterSizes: [Int]) -> Int; public static func cells(_ cpu: CPUStats) -> [MiniDieCell] }`
    - `columns`: наименьшее `c ≥ 1`, при котором `Σ ceil(size/c) ≤ 3`; при > 3 кластерах — наименьшее `c`, при котором `ceil(Σsize / c) ≤ 3`; пустой вход или сумма 0 → 1.
    - `cells`: кластеры по возрастанию `level` (level 0 первым), ядра внутри — по `index`; каждый кластер с новой строки (если кластеров ≤ 3), иначе все ядра подряд; `load` = `CoreLoad.percent`.
  - `GPUStats` получает `public let coreCount: Int?` (публичный init `init(utilizationPercent:coreCount:)`); `GPUCollector` читает `gpu-core-count` (максимум по сервисам `IOAccelerator`; нет — nil). Чистая часть: `static func parse(_ services: [[String: Any]]) -> GPUStats?`.
  - `public enum GPUBars { public static let defaultCount = 16; public static func litCount(utilization: Double, total: Int) -> Int }` — `total ≤ 0` → 0; utilization обрезается 0…100; `round(u/100 × total)`, но минимум 1 при `u > 0`.

- [ ] **Step 1: Написать падающие тесты**

```swift
@Suite struct MiniDieLayoutTests {
    func cpu(_ sizes: [Int]) -> CPUStats {
        var cores: [CoreLoad] = []; var i = 0
        // CPU нумерует ядра от старшего level к младшему (см. CoreTopology); здесь порядок не важен для раскладки
        for (level, size) in sizes.enumerated().reversed() { for _ in 0..<size { cores.append(CoreLoad(index: i, level: level, percent: Double(i))); i += 1 } }
        return CPUStats(totalPercent: 0, clusters: sizes.indices.map { ClusterLoad(level: $0, name: "L\($0)", percent: 0) }, cores: cores)
    }
    @Test func columnsForKnownChips() {
        #expect(MiniDieLayout.columns(clusterSizes: [6, 12]) == 6)   // M5 Pro
        #expect(MiniDieLayout.columns(clusterSizes: [4, 4]) == 4)    // M1
        #expect(MiniDieLayout.columns(clusterSizes: [12, 4]) == 6)   // M3 Max
    }
    @Test func ultraFitsThreeRows() {
        #expect(MiniDieLayout.columns(clusterSizes: [16, 8]) == 8)
        #expect(Set(MiniDieLayout.cells(cpu([16, 8])).map(\.row)).count <= 3)
    }
    @Test func m5ProCells() {
        let cells = MiniDieLayout.cells(cpu([6, 12]))
        #expect(cells.count == 18)
        #expect(cells.filter { $0.row == 0 }.count == 6)
        #expect(cells.filter { $0.row == 1 }.count == 6); #expect(cells.filter { $0.row == 2 }.count == 6)
        #expect(cells.allSatisfy { $0.column < 6 })
    }
    @Test func singleClusterFallback() {
        let cells = MiniDieLayout.cells(cpu([10]))
        #expect(cells.count == 10); #expect(MiniDieLayout.columns(clusterSizes: [10]) == 4)
    }
    @Test func manyClustersDoNotSplitRows() {
        #expect(MiniDieLayout.columns(clusterSizes: [2, 2, 2, 2]) == 3)
        #expect(Set(MiniDieLayout.cells(cpu([2, 2, 2, 2])).map(\.row)).count == 3)
    }
    @Test func zeroCores() {
        #expect(MiniDieLayout.columns(clusterSizes: []) == 1)
        #expect(MiniDieLayout.cells(CPUStats(totalPercent: 0, clusters: [], cores: [])).isEmpty)
    }
}

@Suite struct GPUBarsTests {
    @Test func litCount() {
        #expect(GPUBars.litCount(utilization: 0, total: 20) == 0)
        #expect(GPUBars.litCount(utilization: 1, total: 20) == 1)
        #expect(GPUBars.litCount(utilization: 50, total: 20) == 10)
        #expect(GPUBars.litCount(utilization: 100, total: 20) == 20)
        #expect(GPUBars.litCount(utilization: 140, total: 20) == 20)
        #expect(GPUBars.litCount(utilization: 50, total: 0) == 0)
    }
    @Test func parsesCoreCount() {
        let s = GPUCollector.parse([["PerformanceStatistics": ["Device Utilization %": 8], "gpu-core-count": 20]])
        #expect(s == GPUStats(utilizationPercent: 8, coreCount: 20))
        #expect(GPUCollector.parse([["PerformanceStatistics": ["Device Utilization %": 8]]])?.coreCount == nil)
    }
}
```

- [ ] **Step 2: Запустить — убедиться, что падает** (`swift test --filter "MiniDieLayoutTests|GPUBarsTests"`)
- [ ] **Step 3: Реализовать `MiniDieLayout`, `GPUBars`, `GPUStats.coreCount`, `GPUCollector.parse`** (существующие вызовы `GPUStats(utilizationPercent:)` в тестах/коде обновить)
- [ ] **Step 4: Запустить все тесты** — всё зелёное
- [ ] **Step 5: Commit** — `feat: mini die layout, GPU bars and GPU core count`

---

### Task 3: Мини-кристалл в строке меню

**Files:**
- Modify: `Sources/MetricsCore/Presentation/MenuBarContent.swift`, `Sources/MetricsCore/Settings/AppSettings.swift` (значение по умолчанию `menuBarItems = [.icon, .temperature]`)
- Modify: `Sources/StatusApp/MenuBar/MenuBarRenderer.swift`
- Modify: `Tests/MetricsCoreTests/PresentationTests.swift`, `Tests/MetricsCoreTests/AppSettingsTests.swift` (ожидания по умолчанию)

**Interfaces:**
- Consumes: `MiniDieLayout.cells`, `HeatScale.color(forLoad:)`
- Produces:
  - `MenuBarSegment.icon` заменяется на `case miniDie([MiniDieCell])`; `.icon` в `MenuBarItem` остаётся (сырое значение `"icon"`), в `MenuBarContent` порождает `.miniDie(snapshot?.cpu.map(MiniDieLayout.cells) ?? [])`. Пустой `items` → `[.miniDie(...)]`.
  - Рендер: `.miniDie(cells)` → `NSImage` (ячейка 4×4 pt, промежуток 1.5 pt, скругление 1 pt); холодная ячейка — `NSColor.labelColor.withAlphaComponent(0.35)`, нагретая — RGB шкалы; рисовать в drawing handler (динамический `labelColor`). Пустой массив → прежний template-символ `cpu` (SF Symbol) как заглушка.

- [ ] **Step 1: Обновить/написать падающие тесты**

```swift
    @Test func storedIconItemRendersMiniDie() {
        var s = Snapshot(uptime: 0)
        s.cpu = CPUStats(totalPercent: 10, clusters: [ClusterLoad(level: 0, name: "Super", percent: 10)],
                         cores: [CoreLoad(index: 0, level: 0, percent: 10), CoreLoad(index: 1, level: 0, percent: 80)])
        let segs = MenuBarContent.segments(items: [.icon], snapshot: s, cpuHistory: [], active: [])
        // 2 ядра, 1 кластер: наименьшее c с ≤ 3 рядами — c = 1, т.е. столбик
        #expect(segs == [.miniDie([MiniDieCell(row: 0, column: 0, load: 10), MiniDieCell(row: 1, column: 0, load: 80)])])
    }
    @Test func miniDieWithoutCPUFallsBackToEmptyGrid() {
        #expect(MenuBarContent.segments(items: [], snapshot: nil, cpuHistory: [], active: []) == [.miniDie([])])
    }
```
Заменить в существующих тестах ожидания `.icon` на `.miniDie([])` (там, где снапшота нет); в `AppSettingsTests` — значение по умолчанию `[.icon, .temperature]`.

- [ ] **Step 2: Запустить — убедиться, что падает** (`swift test --filter "PresentationTests|AppSettingsTests"`)
- [ ] **Step 3: Реализовать изменения `MenuBarContent`, `AppSettings`, `MenuBarRenderer`**
- [ ] **Step 4: Запустить все тесты; собрать `.app`; снять снимок** — `scripts/build-app.sh && pkill -x StatusApp; open build/StatusApp.app --args -SnapshotDir <scratchpad>/r3; sleep 12; pkill -x StatusApp` → посмотреть `menubar.png`: сетка 3×6 точек + температура
- [ ] **Step 5: Commit** — `feat: mini die in the menu bar`

---

### Task 4: Каркас панели на стекле, карта кристалла, «Обзор»

**Files:**
- Create: `Sources/StatusApp/Popover/Components/GlassTabBar.swift`, `Sources/StatusApp/Popover/Components/DieMapView.swift`, `Sources/StatusApp/Popover/Components/MetricRow.swift`, `Sources/StatusApp/Popover/Components/HeatColor+SwiftUI.swift`
- Modify: `Sources/StatusApp/Popover/PopoverView.swift`, `Sources/StatusApp/Popover/PopoverController.swift` (ширина 340), `Sources/StatusApp/Popover/Tabs/OverviewTab.swift`, `Sources/StatusApp/Popover/Components/SparklineView.swift` (монохром)
- Delete: `Sources/StatusApp/Popover/Components/TileView.swift` (больше не используется)

**Interfaces:**
- Consumes: `HeatScale`, `HeatColor`, `GPUBars`, `MetricsStore` (`latest`, `history`, `activeAlerts`), `Series`, `PopoverTab`
- Produces:
  - `extension HeatColor { var swiftUIColor: Color }` — `.cold` → `Color.primary.opacity(0.12)`
  - `struct GlassTabBar: View { init(selection: Binding<PopoverTab>) }` — стеклянная капсула (`glassEffect(.regular, in: .capsule)` или `.buttonStyle(.glass)` у сегментов); видимые сегменты: overview «Обзор», cpu «CPU», memory «Память», network «Сеть», disk «Диск»; кнопка-`Menu` «Ещё» с пунктами «Сенсоры», «Процессы»; при выбранной вкладке из «Ещё» кнопка подсвечена
  - `struct DieMapView: View { enum Size { case compact, large }; init(cpu: CPUStats?, gpu: GPUStats?, cpuCelsius: Double?, size: Size, onTap: (() -> Void)? = nil) }` — в `GlassEffectContainer` с `glassEffect(.regular, in: .rect(cornerRadius: 16))`; кластеры level 0 первым, заголовок кластера = `ClusterLoad.name`, у первого кластера справа `Format.celsius(cpuCelsius)`; ячейки: высота compact 22 pt (level 0) / 16 pt (прочие), large 28 pt c процентом внутри; цвет `HeatScale.color(forLoad:)`; `.help("Ядро \(index) · \(cluster) · \(Format.percent(load))")`; ряд GPU: `gpu.coreCount ?? GPUBars.defaultCount` полосок высотой 9 pt, первые `GPUBars.litCount(...)` — цвет шкалы по загрузке GPU, остальные `.cold`; справа `Format.percent(gpu.utilizationPercent)`; нет `gpu` → ряд скрыт; анимация цвета `.easeInOut(duration: 0.6)` если не `accessibilityReduceMotion`
  - `struct MetricRow: View { init(title: String, value: String, points: [HistoryPoint], highlighted: Bool) }` — название secondary, `SparklineView` монохром (primary) шириной ~90 pt, значение primary; `highlighted` → значение и линия цвета `HeatScale.hot`
  - `OverviewTab`: линза (`DieMapView(size: .compact, onTap:)` → переключает на `.cpu`), строки «Процессор» (`Format.percent`), «Память» (`used / total` через `Format.bytes`), «Сеть» (`↓… ↑…` через `Format.rate`), «Диск» (свободно на системном томе + « своб.»), топ-3 процессов (имя, `Format.percent(cpu)`, `Format.bytes(mem)`), футер «Настройки» / «Выход»; подсветка по `activeAlerts` как раньше

- [ ] **Step 1: Реализовать компоненты и «Обзор»**
- [ ] **Step 2: Сборка без предупреждений, тесты зелёные**
- [ ] **Step 3: Снимки** — `-SnapshotDir <scratchpad>/r4`; посмотреть `tab-overview.png`. Если стекло/`Menu` в ImageRenderer отображаются заглушками — отметить в отчёте (финальную проверку делает пользователь). Проверить: два кластера Super (6 крупных) и Performance (12 мелких), 20 полосок GPU, 4 строки метрик, 3 процесса
- [ ] **Step 4: Commit** — `feat: glass popover, die map and overview`

---

### Task 5: Вкладки CPU, Память, Сеть, Диск

**Files:**
- Create: `Sources/StatusApp/Popover/Components/MirroredChart.swift`, `Sources/StatusApp/Popover/Components/StackedBar.swift`
- Modify: `Sources/StatusApp/Popover/Components/HistoryChart.swift`, `Sources/StatusApp/Popover/Tabs/CPUTab.swift`, `MemoryTab.swift`, `NetworkTab.swift`, `DiskTab.swift`

**Interfaces:**
- Consumes: `DieMapView(size: .large)`, `HeatScale`, `Series`, `HistoryPoint`, `Format`
- Produces:
  - `HistoryChart` — монохром: `LineMark` primary + `AreaMark` с вертикальным градиентом primary 25 %→0 %, без сетки, ось Y справа только 0 / середина / максимум мелким шрифтом, высота 70 pt; параметр `highlighted: Bool` → цвет `HeatScale.hot`
  - `struct MirroredChart: View { init(up: [HistoryPoint], down: [HistoryPoint], upLabel: String, downLabel: String, format: (Double) -> String) }` — `up` областью вверх от нуля, `down` — вниз (значения со знаком минус), общая ось X по времени, подписи пиков (`format(max)`) у верхнего и нижнего краёв; монохром
  - `struct StackedBar: View { init(segments: [(label: String, value: Double)], total: Double) }` — высота 10 pt, скругление 5, сегменты `Color.primary` с прозрачностью 1.0 / 0.7 / 0.45 / 0.25, подписи под полосой: «Приложения 9.8 ГБ» и т.д.
  - CPU: `DieMapView(size: .large)`, затем `HistoryChart` «Всего» и по кластеру (заголовок — имя кластера + текущий %)
  - Память: `StackedBar` (Приложения / Wired / Сжатая / Кэш, total = memory.total), строка «Давление» (Нормальное — primary, Повышенное — `HeatScale.amber`, Критическое — `HeatScale.hot`), `HistoryChart(.memoryUsed)`, строка «Swap»
  - Сеть: `MirroredChart(up: .networkDown, down: .networkUp, upLabel: "Приём", downLabel: "Отдача", format: Format.rate)`, строки «Интерфейс», «Всего с запуска»
  - Диск: по тому — имя, тонкая полоса заполнения (высота 4 pt; цвет `HeatScale.hot`, если свободно < 10 %, иначе primary 45 %), «свободно X из Y»; `MirroredChart(up: .diskRead, down: .diskWrite, upLabel: "Чтение", downLabel: "Запись", format: Format.rate)`

- [ ] **Step 1: Реализовать компоненты и вкладки**
- [ ] **Step 2: Сборка без предупреждений, тесты зелёные**
- [ ] **Step 3: Снимки** — `-SnapshotDir <scratchpad>/r5`; посмотреть `tab-cpu.png`, `tab-memory.png`, `tab-network.png`, `tab-disk.png`, описать в отчёте
- [ ] **Step 4: Commit** — `feat: redesigned CPU, memory, network and disk tabs`

---

### Task 6: Сенсоры, Процессы, настройки, финальная проверка

**Files:**
- Modify: `Sources/StatusApp/Popover/Tabs/SensorsTab.swift`, `Sources/StatusApp/Popover/Tabs/ProcessesTab.swift`, `Sources/StatusApp/Popover/Components/ProcessListView.swift`
- Modify: `Sources/StatusApp/Settings/SettingsView.swift`, `Sources/StatusApp/Settings/SettingsWindowController.swift`
- Modify: `Sources/StatusApp/App/SnapshotExporter.swift` (если нужно для новых вкладок «Ещё»)
- Modify: `README.md` (macOS 26+, мини-кристалл)

**Interfaces:**
- Consumes: `HeatScale.temperatureLevel`, `HeatLevel.color`, `HeatScale.color(forLoad:)`, `MenuBarRenderer.attributedTitle`, `MenuBarContent.segments`
- Produces:
  - Сенсоры: значение каждой температуры (и строка «CPU … макс/сред.») окрашено `HeatScale.temperatureLevel(t).color` (`neutral` → primary)
  - Процессы / `ProcessListView`: под или за строкой — полоска доли шириной `min(cpu, 100)/100` ширины строки, высота 3 pt, цвет `HeatScale.color(forLoad: cpu)` (`.cold` → primary 12 %)
  - Настройки: `.formStyle(.grouped)`; во вкладке «Строка меню» сверху секция «Предпросмотр» — `NSViewRepresentable`/`Image(nsImage:)` из `MenuBarRenderer.attributedTitle(MenuBarContent.segments(...текущие настройки, store.latest...))`; подпись пункта `.icon` — «Мини-кристалл»; окно подстраивает высоту под содержимое вкладки (`NSHostingController.sizingOptions = .preferredContentSize` или эквивалент), без пустого места
- [ ] **Step 1: Реализовать**
- [ ] **Step 2: Сборка без предупреждений, тесты зелёные**
- [ ] **Step 3: Финальные снимки** — `-SnapshotDir <scratchpad>/r6`: все вкладки, `menubar.png`, `settings-*.png`; описать каждый
- [ ] **Step 4: Ресурсы** — без `-SnapshotDir`, панель закрыта, ≥ 60 с: CPU (дельта `ps -o time=`) < 1 %, phys_footprint (`footprint $(pgrep -x StatusApp)` или `vmmap --summary`) < 50 МБ; затем `pkill -x StatusApp`
- [ ] **Step 5: Commit** — `feat: heat-tinted sensors and processes, glass settings with live preview`
