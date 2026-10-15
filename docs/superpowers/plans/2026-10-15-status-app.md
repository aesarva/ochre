# StatusApp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Нативное приложение для строки меню macOS: CPU (по кластерам и ядрам), память, температуры, вентиляторы, GPU, сеть, диск, батарея, процессы — с графиками за 10 минут и уведомлениями при превышении порогов.

**Architecture:** SwiftPM-пакет. `CPrivateAPI` (C) — объявления приватных IOKit-функций и чтение SMC. `MetricsCore` — сборщики и вся чистая логика (расчёты, история, оповещения, настройки, что показывать) — покрыто тестами. `StatusApp` — тонкий слой AppKit (`NSStatusItem`, `NSPopover`) + SwiftUI + Swift Charts.

**Tech Stack:** Swift 6.4 (language mode 6), SwiftPM, AppKit, SwiftUI, Swift Charts, IOKit, SystemConfiguration, ServiceManagement, UserNotifications, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-10-15-status-app-design.md`

## Global Constraints

- Требуется Xcode, активированный через `xcode-select` (в одних CLT не работает ни Swift Testing, ни XCTest — проверено).
- `// swift-tools-version: 6.0`, `platforms: [.macOS(.v14)]`, Swift language mode 6. Сторонних зависимостей нет.
- Bundle id `local.statusapp.StatusApp`; `os.Logger` subsystem `local.statusapp`; `LSUIElement = YES`.
- Все строки интерфейса и уведомлений — на русском. Числа форматируются через `String(format:)` (десятичная точка), размеры — по основанию 1024 с единицами `Б`, `КБ`, `МБ`, `ГБ`, `ТБ`.
- Любой сбой API в сборщике → `nil`, без `throw`/`fatalError`/force-unwrap наружу. Недоступное значение в UI — `—`.
- Время для скоростей и оповещений — `MonotonicClock.now()` (CLOCK_MONOTONIC, учитывает сон).
- Интервал обновления: 1 / 2 / 5 с, по умолчанию 2; при открытой панели — 1 с, и только тогда опрашиваются процессы.
- Тесты: `swift test`; фильтр по сьюту — `swift test --filter <SuiteName>`.

## Review Focus

1. **Нет батареи / нет вентиляторов / нет датчика GPU** (iMac, MacBook Air, этот M5 без GPU-датчика) → плитка/строка скрыта или `—`, никогда не «0 об/мин» и не «0°». Тесты: Task 7 (`aggregateWithoutGPUSensors`, `noFansWhenFNumZero`), Task 10 (`hidesTilesWithoutData`).
2. **Сон/пробуждение и длинные паузы между замерами** → нет всплеска скоростей и нет мгновенного уведомления сразу после пробуждения. Тесты: Task 3 (`longGapGivesAverageRate`), Task 9 (`gapResetsSustainedTimer`).
3. **Сброс счётчиков** (переподключение интерфейса, повторно использованный pid) → `nil` на один тик, а не гигантское значение. Тесты: Task 3 (`counterDecreaseGivesNil`), Task 8 (`pidReuseGivesNil`).
4. **Повреждённые или старые настройки в UserDefaults** → значения по умолчанию для отсутствующих/битых полей, без падения. Тесты: Task 10 (`garbageDecodesToDefault`, `partialDecodeKeepsKnownFields`, `invalidIntervalFallsBackTo2`).
5. **Открытие/закрытие панели меняет интервал 1 с ↔ 2 с** → история графиков непрерывна, не сбрасывается. Тест: Task 11 (`historySurvivesIntervalChange`).

---

### Task 1: Каркас пакета, `RingBuffer`, `MonotonicClock`

**Files:**
- Create: `Package.swift`
- Create: `Sources/MetricsCore/Util/RingBuffer.swift`
- Create: `Sources/MetricsCore/Util/MonotonicClock.swift`
- Test: `Tests/MetricsCoreTests/RingBufferTests.swift`

**Interfaces:**
- Produces:
  - `public struct RingBuffer<Element: Sendable>: Sendable` — `init(capacity: Int)` (capacity > 0), `var capacity: Int`, `var count: Int`, `mutating func append(_: Element)`, `var elements: [Element]` (от старых к новым), `var last: Element?`
  - `public enum MonotonicClock { static func now() -> TimeInterval }` — `clock_gettime_nsec_np(CLOCK_MONOTONIC) / 1e9`

- [ ] **Step 0: Проверить окружение**

Run: `xcode-select -p`
Expected: `/Applications/Xcode.app/Contents/Developer`. Если иначе — остановиться и попросить пользователя выполнить `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.

- [ ] **Step 1: Создать `Package.swift`** — пакет `StatusApp`, пока только `.target(name: "MetricsCore", linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("SystemConfiguration")])` и `.testTarget(name: "MetricsCoreTests", dependencies: ["MetricsCore"])`. Остальные таргеты добавляют Task 7 и Task 12.

- [ ] **Step 2: Написать падающие тесты**

```swift
import Testing
@testable import MetricsCore

@Suite struct RingBufferTests {
    @Test func appendsInOrder() {
        var b = RingBuffer<Int>(capacity: 3)
        b.append(1); b.append(2)
        #expect(b.elements == [1, 2]); #expect(b.count == 2); #expect(b.last == 2)
    }
    @Test func overwritesOldest() {
        var b = RingBuffer<Int>(capacity: 3)
        for i in 1...5 { b.append(i) }
        #expect(b.elements == [3, 4, 5]); #expect(b.count == 3)
    }
    @Test func emptyHasNoLast() {
        #expect(RingBuffer<Int>(capacity: 2).last == nil)
    }
    @Test func monotonicClockAdvances() {
        let a = MonotonicClock.now(); let b = MonotonicClock.now()
        #expect(b >= a); #expect(a > 0)
    }
}
```

- [ ] **Step 3: Запустить — убедиться, что падает**

Run: `swift test --filter RingBufferTests`
Expected: ошибка компиляции «cannot find 'RingBuffer' in scope».

- [ ] **Step 4: Реализовать `RingBuffer` и `MonotonicClock`**

- [ ] **Step 5: Запустить тесты**

Run: `swift test --filter RingBufferTests`
Expected: 4 tests passed.

- [ ] **Step 6: Commit** — `git add Package.swift Sources Tests && git commit -m "feat: package skeleton, RingBuffer, MonotonicClock"`

---

### Task 2: Форматтеры

**Files:**
- Create: `Sources/MetricsCore/Util/Format.swift`
- Test: `Tests/MetricsCoreTests/FormatTests.swift`

**Interfaces:**
- Produces: `public enum Format` со статическими функциями (все принимают optional, `nil` → `"—"`):
  - `percent(_: Double?) -> String` — округление до целого, без ограничения сверху
  - `celsius(_: Double?) -> String`
  - `bytes(_: UInt64?) -> String` — основание 1024; одна десятичная при значении < 100, иначе целое; байты всегда целые
  - `rate(_ bytesPerSecond: Double?) -> String` — `bytes` + `/с`
  - `compactRate(_ bytesPerSecond: Double?) -> String` — для строки меню: `K`/`M`/`G`, < 1 КБ → `0K`
  - `watts(_: Double?) -> String`, `rpm(_: Double?) -> String`

- [ ] **Step 1: Написать падающие тесты**

```swift
@Suite struct FormatTests {
    @Test func percent() {
        #expect(Format.percent(23.4) == "23%")
        #expect(Format.percent(142.3) == "142%")
        #expect(Format.percent(nil) == "—")
    }
    @Test func celsius() { #expect(Format.celsius(57.6) == "58°") }
    @Test func bytes() {
        #expect(Format.bytes(0) == "0 Б")
        #expect(Format.bytes(512) == "512 Б")
        #expect(Format.bytes(1536) == "1.5 КБ")
        #expect(Format.bytes(UInt64(14.2 * 1_073_741_824)) == "14.2 ГБ")
        #expect(Format.bytes(212 * 1_073_741_824) == "212 ГБ")
    }
    @Test func rates() {
        #expect(Format.rate(2.4 * 1_048_576) == "2.4 МБ/с")
        #expect(Format.compactRate(2.4 * 1_048_576) == "2.4M")
        #expect(Format.compactRate(120 * 1024) == "120K")
        #expect(Format.compactRate(300) == "0K")
        #expect(Format.compactRate(nil) == "—")
    }
    @Test func wattsAndRpm() {
        #expect(Format.watts(14.63) == "14.6 Вт")
        #expect(Format.rpm(2315) == "2315 об/мин")
    }
}
```

- [ ] **Step 2: Запустить — убедиться, что падает** (`swift test --filter FormatTests`, ошибка компиляции)
- [ ] **Step 3: Реализовать `Format`**
- [ ] **Step 4: Запустить тесты** — Expected: 5 tests passed
- [ ] **Step 5: Commit** — `feat: value formatters`

---

### Task 3: Расчёт скоростей, загрузки CPU и топологии ядер

**Files:**
- Create: `Sources/MetricsCore/Util/CounterRate.swift`
- Create: `Sources/MetricsCore/Util/CPULoad.swift` (`CPUTicks`, `CPULoad`)
- Create: `Sources/MetricsCore/Util/CoreTopology.swift` (`PerfLevel`, `CoreTopology`)
- Test: `Tests/MetricsCoreTests/CalculationTests.swift`

**Interfaces:**
- Produces:
  - `public struct CounterRate: Sendable` — `init()`, `mutating func update(_ counter: UInt64, at time: TimeInterval) -> Double?` (единиц/с; `nil` на первом вызове, при `elapsed <= 0` и при уменьшении счётчика; в любом случае запоминает новый счётчик как базу)
  - `public struct CPUTicks: Sendable, Equatable { public var user, system, idle, nice: UInt64; public init(user:system:idle:nice:) }`
  - `public enum CPULoad` — `static func percent(from: CPUTicks, to: CPUTicks) -> Double?` (`(Δuser+Δsystem+Δnice)/Δtotal*100`; `nil` если Δtotal == 0 или любой счётчик уменьшился); `static func percent(from: [CPUTicks], to: [CPUTicks]) -> Double?` (по сумме тиков; `nil` при разной длине)
  - `public struct PerfLevel: Sendable, Equatable { public let index: Int; public let name: String; public let coreCount: Int }`
  - `public enum CoreTopology { static func levelForEachCore(levels: [PerfLevel], totalCores: Int) -> [Int] }` — логические CPU раздаются от старшего `index` к младшему; если сумма `coreCount` ≠ `totalCores` или `levels` пусто → все `0`

- [ ] **Step 1: Написать падающие тесты**

```swift
@Suite struct CalculationTests {
    @Test func firstUpdateIsNil() {
        var r = CounterRate()
        #expect(r.update(1000, at: 10) == nil)
        #expect(r.update(3000, at: 12) == 1000)
    }
    @Test func counterDecreaseGivesNil() {
        var r = CounterRate()
        _ = r.update(5000, at: 0)
        #expect(r.update(100, at: 1) == nil)      // сброс интерфейса
        #expect(r.update(1100, at: 2) == 1000)    // новая база
    }
    @Test func longGapGivesAverageRate() {
        var r = CounterRate()
        _ = r.update(0, at: 0)
        #expect(r.update(28_800, at: 28_800) == 1) // 8 часов сна
    }
    @Test func cpuPercent() {
        let a = CPUTicks(user: 100, system: 50, idle: 800, nice: 50)
        let b = CPUTicks(user: 200, system: 100, idle: 1100, nice: 100)
        #expect(CPULoad.percent(from: a, to: b) == 40)
        #expect(CPULoad.percent(from: a, to: a) == nil)
        let idle0 = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
        let idle1 = CPUTicks(user: 0, system: 0, idle: 500, nice: 0)
        #expect(CPULoad.percent(from: [a, idle0], to: [b, idle1]) == 20)   // 200 busy / 1000 total
    }
    @Test func topologySuperPerformance() {   // Mac17,9: cpu0…11 → level 1, cpu12…17 → level 0
        let levels = [PerfLevel(index: 0, name: "Super", coreCount: 6),
                      PerfLevel(index: 1, name: "Performance", coreCount: 12)]
        #expect(CoreTopology.levelForEachCore(levels: levels, totalCores: 18)
                == Array(repeating: 1, count: 12) + Array(repeating: 0, count: 6))
    }
    @Test func topologyM1() {
        let levels = [PerfLevel(index: 0, name: "Performance", coreCount: 4),
                      PerfLevel(index: 1, name: "Efficiency", coreCount: 4)]
        #expect(CoreTopology.levelForEachCore(levels: levels, totalCores: 8) == [1, 1, 1, 1, 0, 0, 0, 0])
    }
    @Test func topologyMismatchFallsBackToZero() {
        #expect(CoreTopology.levelForEachCore(levels: [], totalCores: 3) == [0, 0, 0])
    }
}
```

- [ ] **Step 2: Запустить — убедиться, что падает** (`swift test --filter CalculationTests`)
- [ ] **Step 3: Реализовать `CounterRate`, `CPUTicks`, `CPULoad`, `PerfLevel`, `CoreTopology`**
- [ ] **Step 4: Запустить тесты** — Expected: 7 tests passed
- [ ] **Step 5: Commit** — `feat: rate, CPU load and core topology calculations`

---

### Task 4: Сборщики CPU и памяти

**Files:**
- Create: `Sources/MetricsCore/Util/Sysctl.swift`
- Create: `Sources/MetricsCore/Model/CPUStats.swift`, `Sources/MetricsCore/Model/MemoryStats.swift`
- Create: `Sources/MetricsCore/Collectors/CPUCollector.swift`, `Sources/MetricsCore/Collectors/MemoryCollector.swift`
- Test: `Tests/MetricsCoreTests/CollectorSmokeTests.swift` (этот файл дополняют Task 5–8)

**Interfaces:**
- Consumes: `CPUTicks`, `CPULoad`, `PerfLevel`, `CoreTopology` (Task 3)
- Produces:
  - `enum Sysctl` (internal) — `static func int(_ name: String) -> Int?`, `static func string(_ name: String) -> String?`, `static func swapUsage() -> (used: UInt64, total: UInt64)?`
  - `public struct ClusterLoad: Sendable, Equatable { public let level: Int; public let name: String; public let percent: Double }`
  - `public struct CoreLoad: Sendable, Equatable { public let index: Int; public let level: Int; public let percent: Double }`
  - `public struct CPUStats: Sendable, Equatable { public let totalPercent: Double; public let clusters: [ClusterLoad] /* level 0 первым */; public let cores: [CoreLoad] }`
  - `public struct CPUCollector { public init(); public mutating func sample() -> CPUStats? }` — первый вызов `nil`
  - `public enum MemoryPressure: Int, Sendable { case normal = 1, warning = 2, critical = 4 }`
  - `public struct MemoryStats: Sendable, Equatable { public let total, used, app, wired, compressed, cached, swapUsed, swapTotal: UInt64; public let pressure: MemoryPressure?; public var usedPercent: Double { get } }` (+ memberwise `public init`)
  - `public struct MemoryCollector { public init(); public func sample() -> MemoryStats? }`

- [ ] **Step 1: Написать падающие smoke-тесты**

```swift
@Suite struct CollectorSmokeTests {
    @Test func cpu() async throws {
        var c = CPUCollector()
        #expect(c.sample() == nil)
        try await Task.sleep(for: .milliseconds(300))
        let s = try #require(c.sample())
        #expect((0...100).contains(s.totalPercent))
        #expect(s.cores.count == Sysctl.int("hw.ncpu"))
        #expect(s.clusters.count == (Sysctl.int("hw.nperflevels") ?? 1))
        #expect(s.clusters.allSatisfy { !$0.name.isEmpty })
    }
    @Test func memory() throws {
        let m = try #require(MemoryCollector().sample())
        #expect(m.total == UInt64(Sysctl.int("hw.memsize") ?? 0))
        #expect(m.used > 0 && m.used <= m.total)
        #expect(m.pressure != nil)
    }
}
```

- [ ] **Step 2: Запустить — убедиться, что падает** (`swift test --filter CollectorSmokeTests`)
- [ ] **Step 3: Реализовать `Sysctl`, `CPUCollector`, `MemoryCollector`**

CPU: `host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, …)` → `[CPUTicks]` (освободить массив через `vm_deallocate`); уровни — `hw.nperflevels`, `hw.perflevel{N}.name`, `hw.perflevel{N}.logicalcpu`; кластер = `CPULoad.percent` по ядрам своего уровня. Без `hw.nperflevels` — один кластер `level 0`, имя `"CPU"`.
Память: `host_statistics64(HOST_VM_INFO64)`, страница — `vm_kernel_page_size`; `app = (internal_page_count − purgeable_count)·page`, `wired = wire_count·page`, `compressed = compressor_page_count·page`, `cached = (external_page_count + purgeable_count)·page`, `used = app + wired + compressed`; `total = hw.memsize`; давление — `kern.memorystatus_vm_pressure_level` через `MemoryPressure(rawValue:)`; swap — `vm.swapusage` (`xsw_usage`).

- [ ] **Step 4: Запустить тесты** — Expected: 2 tests passed
- [ ] **Step 5: Commit** — `feat: CPU and memory collectors`

---

### Task 5: Сборщики сети и диска

**Files:**
- Create: `Sources/MetricsCore/Util/IORegistry.swift`
- Create: `Sources/MetricsCore/Model/NetworkStats.swift`, `Sources/MetricsCore/Model/DiskStats.swift`
- Create: `Sources/MetricsCore/Collectors/NetworkCollector.swift` (включая `InterfaceSelector`), `Sources/MetricsCore/Collectors/DiskCollector.swift`
- Test: `Tests/MetricsCoreTests/InterfaceSelectorTests.swift`, дополнить `CollectorSmokeTests.swift`

**Interfaces:**
- Consumes: `CounterRate` (Task 3)
- Produces:
  - `enum IORegistry` (internal) — `static func properties(ofClass: String) -> [[String: Any]]` (все сервисы класса, `IORegistryEntryCreateCFProperties`)
  - `public struct InterfaceCounters: Sendable, Equatable { public let rx: UInt64; public let tx: UInt64 }`
  - `public enum InterfaceSelector { static func select(_ counters: [String: InterfaceCounters], primary: String?) -> (name: String?, counters: InterfaceCounters)? }` — `primary` есть в словаре → он; иначе сумма по именам с префиксом `en` (имя `nil`); нет `en*` → `nil`
  - `public struct NetworkStats: Sendable, Equatable { public let interface: String?; public let downPerSecond: Double?; public let upPerSecond: Double?; public let totalDown: UInt64; public let totalUp: UInt64 }` — totals = сумма положительных дельт с момента создания сборщика
  - `public struct NetworkCollector { public init(); public mutating func sample(now: TimeInterval) -> NetworkStats? }` — счётчики из `sysctl([CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0])` → `if_msghdr2.ifm_data.ifi_ibytes/ifi_obytes`; primary — `SCDynamicStoreCopyValue(… "State:/Network/Global/IPv4")["PrimaryInterface"]`
  - `public struct VolumeInfo: Sendable, Equatable { public let name: String; public let path: String; public let total: UInt64; public let available: UInt64 }`
  - `public struct DiskStats: Sendable, Equatable { public let readPerSecond: Double?; public let writePerSecond: Double?; public let volumes: [VolumeInfo]; public let systemVolumeAvailable: UInt64? }`
  - `public struct DiskCollector { public init(); public mutating func sample(now: TimeInterval) -> DiskStats? }` — сумма `Statistics["Bytes (Read)"/"Bytes (Write)"]` по `IOBlockStorageDriver`; тома — `FileManager.mountedVolumeURLs(includingResourceValuesForKeys:options: .skipHiddenVolumes)`, только `volumeIsLocal`, свободное — `volumeAvailableCapacityForImportantUsage`; системный том — `/`

- [ ] **Step 1: Написать падающие тесты**

```swift
@Suite struct InterfaceSelectorTests {
    let c: [String: InterfaceCounters] = [
        "en0": .init(rx: 100, tx: 10), "en1": .init(rx: 5, tx: 1), "utun3": .init(rx: 90, tx: 9)]
    @Test func picksPrimary() throws {
        let r = try #require(InterfaceSelector.select(c, primary: "en0"))
        #expect(r.name == "en0"); #expect(r.counters == .init(rx: 100, tx: 10))
    }
    @Test func sumsEnWhenNoPrimary() throws {
        let r = try #require(InterfaceSelector.select(c, primary: nil))
        #expect(r.name == nil); #expect(r.counters == .init(rx: 105, tx: 11))
    }
    @Test func nilWithoutEthernet() {
        #expect(InterfaceSelector.select(["lo0": .init(rx: 1, tx: 1)], primary: "utun9") == nil)
    }
}
```
Дополнить `CollectorSmokeTests`:
```swift
    @Test func network() async throws {
        var n = NetworkCollector()
        _ = n.sample(now: MonotonicClock.now())
        try await Task.sleep(for: .milliseconds(300))
        let s = try #require(n.sample(now: MonotonicClock.now()))
        #expect((s.downPerSecond ?? 0) >= 0 && (s.upPerSecond ?? 0) >= 0)
    }
    @Test func disk() throws {
        var d = DiskCollector()
        let s = try #require(d.sample(now: MonotonicClock.now()))
        #expect(s.readPerSecond == nil)          // первый замер
        #expect(s.volumes.contains { $0.path == "/" })
        #expect((s.systemVolumeAvailable ?? 0) > 0)
    }
```

- [ ] **Step 2: Запустить — убедиться, что падает** (`swift test --filter "InterfaceSelectorTests|CollectorSmokeTests"`)
- [ ] **Step 3: Реализовать `IORegistry`, `InterfaceSelector`, `NetworkCollector`, `DiskCollector`**
- [ ] **Step 4: Запустить тесты** — Expected: все тесты обоих сьютов passed
- [ ] **Step 5: Commit** — `feat: network and disk collectors`

---

### Task 6: Сборщики батареи и GPU

**Files:**
- Create: `Sources/MetricsCore/Model/BatteryStats.swift`, `Sources/MetricsCore/Model/GPUStats.swift`
- Create: `Sources/MetricsCore/Collectors/BatteryCollector.swift`, `Sources/MetricsCore/Collectors/GPUCollector.swift`
- Test: `Tests/MetricsCoreTests/BatteryParseTests.swift`, дополнить `CollectorSmokeTests.swift`

**Interfaces:**
- Consumes: `IORegistry` (Task 5)
- Produces:
  - `public struct BatteryStats: Sendable, Equatable { public let percent: Double; public let isCharging: Bool; public let onExternalPower: Bool; public let cycleCount: Int?; public let healthPercent: Double?; public let powerWatts: Double? }`
  - `extension BatteryStats { static func parse(_ props: [String: Any]) -> BatteryStats? }` — ключи `AppleSmartBattery`: `CurrentCapacity`, `MaxCapacity` (percent = Current/Max·100), `IsCharging`, `ExternalConnected`, `CycleCount`; здоровье = `BatteryData.FullChargeCapacity` (или `AppleRawMaxCapacity`, если есть) / `BatteryData.DesignCapacity` (или `DesignCapacity`)·100, не больше 100; мощность = `|Voltage(мВ) · InstantAmperage(мА)| / 1e6`, где `InstantAmperage` читается как `NSNumber.int64Value` (в реестре хранится как беззнаковое). Нет `CurrentCapacity`/`MaxCapacity` → `nil`.
  - `public struct BatteryCollector { public init(); public func sample() -> BatteryStats? }` — первый сервис `AppleSmartBattery` → `parse`; нет сервиса → `nil`
  - `public struct GPUStats: Sendable, Equatable { public let utilizationPercent: Double }`
  - `public struct GPUCollector { public init(); public func sample() -> GPUStats? }` — максимум `PerformanceStatistics["Device Utilization %"]` по сервисам `IOAccelerator`

- [ ] **Step 1: Написать падающие тесты** (фикстура — реальные значения с этой машины)

```swift
@Suite struct BatteryParseTests {
    let props: [String: Any] = [
        "CurrentCapacity": 100, "MaxCapacity": 100, "IsCharging": false, "ExternalConnected": true,
        "CycleCount": 5, "Voltage": 13166,
        "InstantAmperage": NSNumber(value: UInt64(18_446_744_073_709_551_379)),   // −237 мА
        "BatteryData": ["FullChargeCapacity": 6256, "DesignCapacity": 6249]]
    @Test func parsesRealSample() throws {
        let b = try #require(BatteryStats.parse(props))
        #expect(b.percent == 100); #expect(b.cycleCount == 5); #expect(b.onExternalPower)
        #expect(b.healthPercent == 100)
        #expect(abs((b.powerWatts ?? 0) - 3.12) < 0.01)
    }
    @Test func nilWithoutCapacity() { #expect(BatteryStats.parse(["Voltage": 1]) == nil) }
}
```
Дополнить `CollectorSmokeTests`:
```swift
    @Test func gpu() {
        if let g = GPUCollector().sample() { #expect((0...100).contains(g.utilizationPercent)) }
    }
    @Test func battery() {
        if let b = BatteryCollector().sample() { #expect((0...100).contains(b.percent)) }
    }
```

- [ ] **Step 2: Запустить — убедиться, что падает** (`swift test --filter BatteryParseTests`)
- [ ] **Step 3: Реализовать `BatteryStats.parse`, `BatteryCollector`, `GPUCollector`**
- [ ] **Step 4: Запустить тесты** — `swift test --filter "BatteryParseTests|CollectorSmokeTests"`, все passed
- [ ] **Step 5: Commit** — `feat: battery and GPU collectors`

---

### Task 7: Приватные API, датчики температуры, вентиляторы, мощность

**Files:**
- Create: `Sources/CPrivateAPI/include/CPrivateAPI.h`, `Sources/CPrivateAPI/shim.c`
- Modify: `Package.swift` — `.target(name: "CPrivateAPI", linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("CoreFoundation")])`, `MetricsCore` зависит от `CPrivateAPI`
- Create: `Sources/MetricsCore/Model/SensorStats.swift`
- Create: `Sources/MetricsCore/Collectors/SensorAggregator.swift`, `Sources/MetricsCore/Collectors/SMCDecoder.swift`, `Sources/MetricsCore/Collectors/SensorCollector.swift`
- Test: `Tests/MetricsCoreTests/SensorTests.swift`, дополнить `CollectorSmokeTests.swift`

**Interfaces:**
- Produces (C, `CPrivateAPI.h`):
  - объявления `IOHIDEventSystemClientCreate`, `IOHIDEventSystemClientSetMatching`, `IOHIDEventSystemClientCopyServices`, `IOHIDServiceClientCopyProperty`, `IOHIDServiceClientCopyEvent`, `IOHIDEventGetFloatValue` и opaque-типов — ровно как в проверочной программе из брейнсторма (тип события температуры `15`, поле `15 << 16`, matching `PrimaryUsagePage = 0xff00`, `PrimaryUsage = 5`, имя датчика — свойство `Product`)
  - `int smc_open(uint32_t *conn)`, `void smc_close(uint32_t conn)`, `int smc_read(uint32_t conn, const char key[4], char out_type[5], uint8_t out_bytes[32], uint32_t *out_size)` — 0 при успехе. Реализация в `shim.c`: `AppleSMC`, `IOConnectCallStructMethod` селектор `2`, сначала `data8 = 9` (key info), затем `data8 = 5` (read bytes); структура `SMCKeyData` — 80 байт (`key`, `vers`, `pLimitData`, `keyInfo{dataSize, dataType, dataAttributes}`, `result`, `status`, `data8`, `data32`, `bytes[32]`)
- Produces (Swift):
  - `public struct TemperatureReading: Sendable, Equatable { public let name: String; public let celsius: Double }`
  - `public struct FanReading: Sendable, Equatable { public let index: Int; public let rpm: Double }`
  - `public struct SensorStats: Sendable, Equatable { public let temperatures: [TemperatureReading]; public let cpuCelsius: Double?; public let gpuCelsius: Double?; public let fans: [FanReading]; public let systemPowerWatts: Double? }`
  - `public enum SensorAggregator { static func aggregate(_ raw: [TemperatureReading]) -> (readings: [TemperatureReading], cpu: Double?, gpu: Double?) }` — отбросить вне `(0, 150)`; одинаковые имена → максимум; сортировка по имени; CPU — максимум по именам, содержащим `tdie`, `pACC`, `eACC`; GPU — содержащим `GPU`
  - `public enum SMCDecoder { static func decode(type: String, bytes: [UInt8]) -> Double? }` — `"flt "` (Float32 little-endian), `"ui8 "`, `"ui16"`, `"ui32"` (big-endian), `"fpe2"` (UInt16 BE / 4), `"sp78"` (Int16 BE / 256); неизвестный тип или мало байт → `nil`
  - `public final class SensorCollector { public init(); public func sample() -> SensorStats? }` — HID-клиент и SMC-соединение открываются в `init`, закрываются в `deinit`; вентиляторы — `FNum`, затем `F{i}Ac` для `i < FNum`; мощность — `PSTR`; если нет ни температур, ни вентиляторов, ни мощности → `nil`

- [ ] **Step 1: Написать падающие тесты** (данные — реальные с этой машины)

```swift
@Suite struct SensorTests {
    @Test func dropsGarbageAndDedupes() {
        let r = SensorAggregator.aggregate([
            .init(name: "PMU tdie1", celsius: 44.8), .init(name: "PMU tdie1", celsius: 45.4),
            .init(name: "PMU tdie2", celsius: 43.7), .init(name: "PMU tdev1", celsius: -9201.1),
            .init(name: "NAND CH0 temp", celsius: 37), .init(name: "als-temp", celsius: -1)])
        #expect(r.readings.map(\.name) == ["NAND CH0 temp", "PMU tdie1", "PMU tdie2"])
        #expect(r.readings[1].celsius == 45.4)
        #expect(r.cpu == 45.4)
    }
    @Test func aggregateWithoutGPUSensors() {
        #expect(SensorAggregator.aggregate([.init(name: "PMU tdie1", celsius: 50)]).gpu == nil)
        #expect(SensorAggregator.aggregate([.init(name: "GPU MTR Temp Sensor1", celsius: 61)]).gpu == 61)
    }
    @Test func smcDecode() {
        #expect(SMCDecoder.decode(type: "flt ", bytes: [0x00, 0xb0, 0x10, 0x45]) == 2315)
        #expect(SMCDecoder.decode(type: "ui8 ", bytes: [0x02]) == 2)
        #expect(SMCDecoder.decode(type: "fpe2", bytes: [0x24, 0x10]) == 2308)
        #expect(SMCDecoder.decode(type: "sp78", bytes: [0x2d, 0x80]) == 45.5)
        #expect(SMCDecoder.decode(type: "flt ", bytes: [0x00]) == nil)
        #expect(SMCDecoder.decode(type: "zzzz", bytes: [1, 2, 3, 4]) == nil)
    }
    @Test func noFansWhenFNumZero() {
        #expect(SensorCollector.fans(count: 0, read: { _ in 1000 }).isEmpty)
        #expect(SensorCollector.fans(count: 2, read: { $0 == 0 ? 2315 : nil }) == [.init(index: 0, rpm: 2315)])
    }
}
```
Для последнего теста `SensorCollector` получает `static func fans(count: Int, read: (Int) -> Double?) -> [FanReading]` — чистая часть сборки списка вентиляторов (пропускает `nil`).

Дополнить `CollectorSmokeTests`:
```swift
    @Test func sensors() throws {
        let s = try #require(SensorCollector().sample())
        if let cpu = s.cpuCelsius { #expect((10...120).contains(cpu)) }
        #expect(s.temperatures.allSatisfy { $0.celsius > 0 && $0.celsius < 150 })
    }
```

- [ ] **Step 2: Запустить — убедиться, что падает** (`swift test --filter SensorTests`)
- [ ] **Step 3: Реализовать C-таргет, `SensorAggregator`, `SMCDecoder`, `SensorCollector`**
- [ ] **Step 4: Запустить тесты** — `swift test --filter "SensorTests|CollectorSmokeTests"`, все passed; на этой машине smoke-тест должен дать `cpuCelsius` ≈ 40–60 и 2 вентилятора
- [ ] **Step 5: Commit** — `feat: temperature sensors, fans and system power via HID/SMC`

---

### Task 8: Процессы

**Files:**
- Create: `Sources/MetricsCore/Model/ProcessRow.swift`
- Create: `Sources/MetricsCore/Collectors/ProcessCPUTracker.swift`, `Sources/MetricsCore/Collectors/ProcessCollector.swift`
- Test: `Tests/MetricsCoreTests/ProcessCPUTrackerTests.swift`, дополнить `CollectorSmokeTests.swift`

**Interfaces:**
- Produces:
  - `public struct ProcessRow: Sendable, Equatable, Identifiable { public let pid: Int32; public let name: String; public let cpuPercent: Double?; public let memoryBytes: UInt64; public var id: Int32 { pid } }`
  - `public struct ProcessCPUSample: Sendable { public let pid: Int32; public let startTime: UInt64; public let cpuTimeNanos: UInt64 }`
  - `public struct ProcessCPUTracker: Sendable { public init(); public mutating func update(_ samples: [ProcessCPUSample], at time: TimeInterval) -> [Int32: Double] }` — % = Δнс / (Δt·1e9)·100 (может быть > 100); новый pid, другой `startTime` у того же pid или уменьшение времени → нет записи в результате; исчезнувшие pid забываются
  - `public struct ProcessCollector { public init(); public mutating func sample(now: TimeInterval) -> [ProcessRow]? }` — `proc_listallpids`; для каждого `proc_pid_rusage(pid, RUSAGE_INFO_V4)`: время = `(ri_user_time + ri_system_time)` · `mach_timebase_info` → нс, `startTime = ri_proc_start_abstime`, память = `ri_phys_footprint`; имя — последний компонент `proc_pidpath`, иначе `proc_name`; процессы, для которых вызов не удался, пропускаются; результат отсортирован по `cpuPercent ?? 0` по убыванию, затем по памяти

- [ ] **Step 1: Написать падающие тесты**

```swift
@Suite struct ProcessCPUTrackerTests {
    @Test func computesPercent() {
        var t = ProcessCPUTracker()
        #expect(t.update([.init(pid: 1, startTime: 7, cpuTimeNanos: 0)], at: 0).isEmpty)
        #expect(t.update([.init(pid: 1, startTime: 7, cpuTimeNanos: 1_500_000_000)], at: 1) == [1: 150])
    }
    @Test func pidReuseGivesNil() {
        var t = ProcessCPUTracker()
        _ = t.update([.init(pid: 1, startTime: 7, cpuTimeNanos: 5_000_000_000)], at: 0)
        #expect(t.update([.init(pid: 1, startTime: 9, cpuTimeNanos: 100)], at: 1)[1] == nil)
        #expect(t.update([.init(pid: 1, startTime: 9, cpuTimeNanos: 500_000_100)], at: 2) == [1: 50])
    }
    @Test func forgetsExitedProcesses() {
        var t = ProcessCPUTracker()
        _ = t.update([.init(pid: 1, startTime: 1, cpuTimeNanos: 0)], at: 0)
        _ = t.update([], at: 1)
        #expect(t.update([.init(pid: 1, startTime: 1, cpuTimeNanos: 10)], at: 2).isEmpty)
    }
}
```
Дополнить `CollectorSmokeTests`:
```swift
    @Test func processes() async throws {
        var p = ProcessCollector()
        _ = p.sample(now: MonotonicClock.now())
        try await Task.sleep(for: .milliseconds(300))
        let rows = try #require(p.sample(now: MonotonicClock.now()))
        #expect(rows.count > 10)
        #expect(rows.contains { $0.pid == getpid() })
        #expect(rows.allSatisfy { !$0.name.isEmpty })
    }
```

- [ ] **Step 2: Запустить — убедиться, что падает** (`swift test --filter ProcessCPUTrackerTests`)
- [ ] **Step 3: Реализовать `ProcessRow`, `ProcessCPUTracker`, `ProcessCollector`**
- [ ] **Step 4: Запустить тесты** — `swift test --filter "ProcessCPUTrackerTests|CollectorSmokeTests"`, все passed
- [ ] **Step 5: Commit** — `feat: process collector with per-process CPU tracking`

---

### Task 9: `Snapshot` и `AlertEngine`

**Files:**
- Create: `Sources/MetricsCore/Model/Snapshot.swift`
- Create: `Sources/MetricsCore/Alerts/AlertConfig.swift` (`AlertKind`, `AlertRuleConfig`, `AlertConfig`, `AlertEvent`)
- Create: `Sources/MetricsCore/Alerts/AlertEngine.swift`
- Test: `Tests/MetricsCoreTests/AlertEngineTests.swift`

**Interfaces:**
- Consumes: все `*Stats` и `ProcessRow` (Task 4–8)
- Produces:
  - `public struct Snapshot: Sendable { public var uptime: TimeInterval; public var cpu: CPUStats?; public var memory: MemoryStats?; public var sensors: SensorStats?; public var gpu: GPUStats?; public var network: NetworkStats?; public var disk: DiskStats?; public var battery: BatteryStats?; public var processes: [ProcessRow]? }` — `public init(uptime:)` с остальными полями `nil`
  - `public enum AlertKind: String, CaseIterable, Codable, Sendable { case cpuTemperature, cpuLoad, memoryPressure, diskSpace }`
  - `public struct AlertRuleConfig: Codable, Sendable, Equatable { public var enabled: Bool; public var threshold: Double; public var duration: TimeInterval }`
  - `public struct AlertConfig: Codable, Sendable, Equatable { public var rules: [AlertKind: AlertRuleConfig]; public static let `default`: AlertConfig; public func rule(_: AlertKind) -> AlertRuleConfig }` — `rule` берёт значение из `rules`, иначе из `.default`. Значения по умолчанию: `cpuTemperature (true, 95 °C, 30 с)`, `cpuLoad (true, 90 %, 60 с)`, `memoryPressure (true, threshold не используется = 0, 0 с)`, `diskSpace (true, 10 — ГиБ, 0 с)`
  - `public struct AlertEvent: Sendable, Equatable { public let kind: AlertKind; public let title: String; public let body: String }`
  - `public struct AlertEngine: Sendable { public init(cooldown: TimeInterval = 600, maxGap: TimeInterval = 15); public mutating func evaluate(_ snapshot: Snapshot, config: AlertConfig, now: TimeInterval) -> (active: Set<AlertKind>, events: [AlertEvent]) }`

Условия: `cpuTemperature` — `sensors?.cpuCelsius > threshold`; `cpuLoad` — `cpu?.totalPercent > threshold`; `memoryPressure` — `memory?.pressure == .critical`; `diskSpace` — `disk?.systemVolumeAvailable < threshold · 1024³`. Значение `nil` → условие ложно. Правило активно, если условие непрерывно истинно ≥ `duration`. Если между текущим и предыдущим вызовом `evaluate` прошло > `maxGap`, отсчёт «с какого момента истинно» начинается заново с `now`. Событие — при переходе в активное состояние и затем не чаще `cooldown`, пока активно. Выключенное правило никогда не активно.

Тексты событий (точно):
| kind | title | body |
|---|---|---|
| cpuTemperature | `Перегрев CPU` | `Температура CPU %.0f °C дольше %.0f с` (значение, duration) |
| cpuLoad | `Высокая нагрузка CPU` | `Загрузка CPU %.0f %% дольше %.0f с` |
| memoryPressure | `Критическое давление памяти` | `Закройте лишние приложения` |
| diskSpace | `Мало места на диске` | `Свободно {Format.bytes} на системном томе` |

- [ ] **Step 1: Написать падающие тесты**

```swift
@Suite struct AlertEngineTests {
    func cpu(_ p: Double, at t: TimeInterval) -> Snapshot {
        var s = Snapshot(uptime: t)
        s.cpu = CPUStats(totalPercent: p, clusters: [], cores: []); return s
    }
    @Test func sustainedLoadFiresOnceThenCooldown() {
        var e = AlertEngine(); let cfg = AlertConfig.default
        for t in stride(from: 0.0, to: 60, by: 2) {
            let r = e.evaluate(cpu(95, at: t), config: cfg, now: t)
            #expect(r.active.isEmpty); #expect(r.events.isEmpty)
        }
        let fired = e.evaluate(cpu(95, at: 60), config: cfg, now: 60)
        #expect(fired.active == [.cpuLoad]); #expect(fired.events.map(\.kind) == [.cpuLoad])
        #expect(fired.events[0].title == "Высокая нагрузка CPU")
        var t = 62.0
        while t < 660 { #expect(e.evaluate(cpu(95, at: t), config: cfg, now: t).events.isEmpty); t += 2 }
        #expect(e.evaluate(cpu(95, at: 660), config: cfg, now: 660).events.count == 1)
    }
    @Test func dropBelowThresholdResets() {
        var e = AlertEngine(); let cfg = AlertConfig.default
        _ = e.evaluate(cpu(95, at: 0), config: cfg, now: 0)
        _ = e.evaluate(cpu(50, at: 10), config: cfg, now: 10)
        for t in stride(from: 12.0, through: 70, by: 2) { _ = e.evaluate(cpu(95, at: t), config: cfg, now: t) }
        #expect(e.evaluate(cpu(95, at: 71), config: cfg, now: 71).active.isEmpty)   // 12…71 < 60 с
    }
    @Test func nilValueResets() {
        var e = AlertEngine(); let cfg = AlertConfig.default
        for t in stride(from: 0.0, to: 50, by: 2) { _ = e.evaluate(cpu(95, at: t), config: cfg, now: t) }
        _ = e.evaluate(Snapshot(uptime: 50), config: cfg, now: 50)
        #expect(e.evaluate(cpu(95, at: 62), config: cfg, now: 62).active.isEmpty)
    }
    @Test func gapResetsSustainedTimer() {
        var e = AlertEngine(); let cfg = AlertConfig.default
        _ = e.evaluate(cpu(95, at: 0), config: cfg, now: 0)
        #expect(e.evaluate(cpu(95, at: 100), config: cfg, now: 100).active.isEmpty)   // сон 100 с
    }
    @Test func disabledRuleNeverFires() {
        var cfg = AlertConfig.default; cfg.rules[.cpuLoad]?.enabled = false
        var e = AlertEngine()
        for t in stride(from: 0.0, through: 120, by: 2) {
            #expect(e.evaluate(cpu(99, at: t), config: cfg, now: t).active.isEmpty)
        }
    }
    @Test func immediateRules() {
        var s = Snapshot(uptime: 0)
        s.memory = MemoryStats(total: 1, used: 1, app: 1, wired: 0, compressed: 0, cached: 0,
                               swapUsed: 0, swapTotal: 0, pressure: .critical)
        s.disk = DiskStats(readPerSecond: nil, writePerSecond: nil, volumes: [],
                           systemVolumeAvailable: 5 * 1_073_741_824)
        var e = AlertEngine()
        let r = e.evaluate(s, config: .default, now: 0)
        #expect(r.active == [.memoryPressure, .diskSpace]); #expect(r.events.count == 2)
    }
}
```

- [ ] **Step 2: Запустить — убедиться, что падает** (`swift test --filter AlertEngineTests`)
- [ ] **Step 3: Реализовать `Snapshot`, `AlertConfig` и связанные типы, `AlertEngine`**
- [ ] **Step 4: Запустить тесты** — Expected: 6 tests passed
- [ ] **Step 5: Commit** — `feat: snapshot model and alert engine`

---

### Task 10: Настройки, содержимое строки меню, видимость плиток

**Files:**
- Create: `Sources/MetricsCore/Settings/AppSettings.swift`
- Create: `Sources/MetricsCore/Presentation/MenuBarContent.swift`, `Sources/MetricsCore/Presentation/OverviewTile.swift`
- Test: `Tests/MetricsCoreTests/AppSettingsTests.swift`, `Tests/MetricsCoreTests/PresentationTests.swift`

**Interfaces:**
- Consumes: `AlertConfig`, `AlertKind`, `Snapshot`, `Format`
- Produces:
  - `public enum MenuBarItem: String, CaseIterable, Codable, Sendable { case icon, cpuGraph, cpuPercent, memoryPercent, temperature, network }` — порядок кейсов = порядок в строке меню
  - `public struct AppSettings: Codable, Sendable, Equatable { public var refreshInterval: Double /*2*/; public var menuBarItems: Set<MenuBarItem> /*[.cpuPercent, .temperature]*/; public var alerts: AlertConfig /*.default*/; public static let `default`; public static let allowedIntervals: [Double] = [1, 2, 5]; public static func decode(_ data: Data?) -> AppSettings; public func encoded() -> Data }` — собственный `init(from:)` с `decodeIfPresent` для каждого поля; интервал вне `allowedIntervals` → 2; `nil`/мусор → `.default`
  - `public enum MenuBarSegment: Equatable, Sendable { case icon; case cpuGraph([Double]); case text(String, highlighted: Bool) }`
  - `public enum MenuBarContent { static func segments(items: Set<MenuBarItem>, snapshot: Snapshot?, cpuHistory: [Double], active: Set<AlertKind>) -> [MenuBarSegment] }` — тексты: `CPU 23%`, `RAM 59%`, `58°`, `↓2.4M ↑120K` (через `Format`); подсветка: `cpuPercent` ← `cpuLoad`, `memoryPercent` ← `memoryPressure`, `temperature` ← `cpuTemperature`; `cpuGraph` — последние 10 значений `cpuHistory`; пустой `items` → `[.icon]`; если активно правило, у которого нет видимого подсвеченного сегмента (например `diskSpace`), в конец добавляется `.text("⚠", highlighted: true)`
  - `public enum OverviewTile: CaseIterable, Sendable { case cpu, memory, temperature, gpu, network, disk, battery; static func visible(in snapshot: Snapshot?) -> [OverviewTile] }` — `nil` снапшот → все, кроме `battery`; иначе плитка видна, если есть её данные (`temperature` — если `sensors?.cpuCelsius != nil`)

- [ ] **Step 1: Написать падающие тесты**

```swift
@Suite struct AppSettingsTests {
    @Test func roundTrip() {
        var s = AppSettings.default; s.refreshInterval = 5; s.menuBarItems = [.icon, .network]
        #expect(AppSettings.decode(s.encoded()) == s)
    }
    @Test func garbageDecodesToDefault() {
        #expect(AppSettings.decode(nil) == .default)
        #expect(AppSettings.decode(Data("{oops".utf8)) == .default)
    }
    @Test func partialDecodeKeepsKnownFields() {
        let s = AppSettings.decode(Data(#"{"refreshInterval":5}"#.utf8))
        #expect(s.refreshInterval == 5); #expect(s.menuBarItems == [.cpuPercent, .temperature])
        #expect(s.alerts == .default)
    }
    @Test func invalidIntervalFallsBackTo2() {
        #expect(AppSettings.decode(Data(#"{"refreshInterval":0.01}"#.utf8)).refreshInterval == 2)
    }
}

@Suite struct PresentationTests {
    func snap() -> Snapshot {
        var s = Snapshot(uptime: 0)
        s.cpu = CPUStats(totalPercent: 23.4, clusters: [], cores: [])
        s.sensors = SensorStats(temperatures: [], cpuCelsius: 91.2, gpuCelsius: nil, fans: [], systemPowerWatts: nil)
        return s
    }
    @Test func defaultSegmentsWithHighlight() {
        let segs = MenuBarContent.segments(items: [.cpuPercent, .temperature], snapshot: snap(),
                                           cpuHistory: [], active: [.cpuTemperature])
        #expect(segs == [.text("CPU 23%", highlighted: false), .text("91°", highlighted: true)])
    }
    @Test func emptyItemsShowIcon() {
        #expect(MenuBarContent.segments(items: [], snapshot: nil, cpuHistory: [], active: []) == [.icon])
    }
    @Test func missingValuesShowDash() {
        #expect(MenuBarContent.segments(items: [.memoryPercent], snapshot: snap(), cpuHistory: [], active: [])
                == [.text("RAM —", highlighted: false)])
    }
    @Test func hiddenAlertAddsWarning() {
        let segs = MenuBarContent.segments(items: [.cpuPercent], snapshot: snap(), cpuHistory: [], active: [.diskSpace])
        #expect(segs.last == .text("⚠", highlighted: true))
    }
    @Test func graphUsesLastTen() {
        let segs = MenuBarContent.segments(items: [.cpuGraph], snapshot: nil,
                                           cpuHistory: (1...15).map(Double.init), active: [])
        #expect(segs == [.cpuGraph((6...15).map(Double.init))])
    }
    @Test func hidesTilesWithoutData() {
        var s = snap(); s.sensors = nil
        #expect(OverviewTile.visible(in: s) == [.cpu])
        #expect(OverviewTile.visible(in: nil) == [.cpu, .memory, .temperature, .gpu, .network, .disk])
    }
}
```

- [ ] **Step 2: Запустить — убедиться, что падает** (`swift test --filter "AppSettingsTests|PresentationTests"`)
- [ ] **Step 3: Реализовать `AppSettings`, `MenuBarContent`, `OverviewTile`**
- [ ] **Step 4: Запустить тесты** — Expected: 10 tests passed
- [ ] **Step 5: Commit** — `feat: settings model, menu bar content and tile visibility`

---

### Task 11: История метрик и `Sampler`

**Files:**
- Create: `Sources/MetricsCore/Sampling/MetricsHistory.swift`, `Sources/MetricsCore/Sampling/Sampler.swift`
- Test: `Tests/MetricsCoreTests/MetricsHistoryTests.swift`, дополнить `CollectorSmokeTests.swift`

**Interfaces:**
- Consumes: `RingBuffer`, `MonotonicClock`, `Snapshot`, все сборщики
- Produces:
  - `public struct HistoryPoint: Sendable, Equatable { public let t: TimeInterval; public let value: Double }`
  - `public enum Series: Hashable, Sendable { case cpuTotal, cluster(Int), core(Int), memoryUsed, cpuTemperature, gpu, networkDown, networkUp, diskRead, diskWrite }`
  - `public struct MetricsHistory: Sendable { public init(window: TimeInterval = 600, capacity: Int = 600); public mutating func record(_: Snapshot); public func points(_: Series, now: TimeInterval) -> [HistoryPoint] }` — точка с `t = snapshot.uptime`; `nil`-значение не записывается; `points` возвращает только `t >= now − window`; `cluster(level)`, `core(index)` берутся из `CPUStats`; `memoryUsed` = `usedPercent`
  - `public actor Sampler { public init(); public func sample(includeProcesses: Bool) -> Snapshot }` — владеет всеми сборщиками (включая `SensorCollector`), `uptime = MonotonicClock.now()`; процессы — только при `includeProcesses`. Логирование (спец. §6): `Logger(subsystem: "local.statusapp", category: "sampler")`; когда сборщик впервые вернул `nil` после успеха (или с самого старта) — одна запись `notice` «<имя> недоступен»; повтор только после следующего успешного чтения. Сборщики, которые законно возвращают `nil` на первом тике (CPU, сеть, диск, процессы), в этот момент не логируются

- [ ] **Step 1: Написать падающие тесты**

```swift
@Suite struct MetricsHistoryTests {
    func s(_ t: TimeInterval, cpu: Double?) -> Snapshot {
        var x = Snapshot(uptime: t)
        if let cpu { x.cpu = CPUStats(totalPercent: cpu, clusters: [ClusterLoad(level: 0, name: "Super", percent: cpu)], cores: []) }
        return x
    }
    @Test func recordsAndTrimsByTime() {
        var h = MetricsHistory(window: 10, capacity: 100)
        for t in 0...20 { h.record(s(Double(t), cpu: Double(t))) }
        #expect(h.points(.cpuTotal, now: 20).map(\.value) == (10...20).map(Double.init))
        #expect(h.points(.cluster(0), now: 20).count == 11)
    }
    @Test func skipsNil() {
        var h = MetricsHistory()
        h.record(s(0, cpu: 5)); h.record(s(1, cpu: nil))
        #expect(h.points(.cpuTotal, now: 1) == [HistoryPoint(t: 0, value: 5)])
    }
    @Test func historySurvivesIntervalChange() {
        var h = MetricsHistory()
        for t in stride(from: 0.0, to: 300, by: 2) { h.record(s(t, cpu: 1)) }    // 2 с
        for t in stride(from: 300.0, to: 360, by: 1) { h.record(s(t, cpu: 2)) }  // панель открыта, 1 с
        for t in stride(from: 360.0, to: 400, by: 2) { h.record(s(t, cpu: 3)) }  // снова 2 с
        let p = h.points(.cpuTotal, now: 398)
        #expect(p.first?.t == 0); #expect(p.count == 150 + 60 + 20)
    }
}
```
Дополнить `CollectorSmokeTests`:
```swift
    @Test func sampler() async throws {
        let s = Sampler()
        _ = await s.sample(includeProcesses: true)
        try await Task.sleep(for: .milliseconds(300))
        let snap = await s.sample(includeProcesses: true)
        #expect(snap.cpu != nil); #expect(snap.memory != nil); #expect(snap.processes != nil)
        #expect(await s.sample(includeProcesses: false).processes == nil)
    }
```

- [ ] **Step 2: Запустить — убедиться, что падает** (`swift test --filter MetricsHistoryTests`)
- [ ] **Step 3: Реализовать `MetricsHistory`, `Sampler`**
- [ ] **Step 4: Запустить все тесты** — `swift test`, все passed
- [ ] **Step 5: Commit** — `feat: time-based metrics history and sampler actor`

---

### Task 12: Оболочка приложения, строка меню, сборка `.app`

**Files:**
- Modify: `Package.swift` — `.executableTarget(name: "StatusApp", dependencies: ["MetricsCore"])`
- Create: `Resources/Info.plist` — `CFBundleExecutable StatusApp`, `CFBundleIdentifier local.statusapp.StatusApp`, `CFBundleName StatusApp`, `CFBundlePackageType APPL`, `CFBundleShortVersionString 0.1`, `CFBundleVersion 1`, `LSMinimumSystemVersion 14.0`, `LSUIElement true`
- Create: `scripts/build-app.sh` (исполняемый)
- Create: `Sources/StatusApp/App/main.swift`, `Sources/StatusApp/App/AppDelegate.swift`
- Create: `Sources/StatusApp/Settings/SettingsStore.swift`
- Create: `Sources/StatusApp/Sampling/MetricsStore.swift`
- Create: `Sources/StatusApp/MenuBar/StatusItemController.swift`, `Sources/StatusApp/MenuBar/MenuBarRenderer.swift`
- Create: `Sources/StatusApp/Popover/PopoverController.swift` (пока с заглушкой `Text("StatusApp")`)

**Interfaces:**
- Consumes: `Sampler`, `MetricsHistory`, `AlertEngine`, `AppSettings`, `MenuBarContent`, `MenuBarSegment`
- Produces:
  - `@MainActor @Observable final class SettingsStore { var settings: AppSettings /* didSet → UserDefaults "settings.v1" = encoded() */; init(defaults: UserDefaults = .standard) /* AppSettings.decode */ }`
  - `@MainActor @Observable final class MetricsStore { private(set) var latest: Snapshot?; private(set) var history: MetricsHistory; private(set) var activeAlerts: Set<AlertKind>; var isPopoverOpen: Bool /* didSet: перезапуск цикла, чтобы сразу перейти на 1 с */; var onAlertEvents: (([AlertEvent]) -> Void)?; init(settings: SettingsStore); func start() }` — цикл: `Task { while !Task.isCancelled { let snap = await sampler.sample(includeProcesses: isPopoverOpen); latest = snap; history.record(snap); (activeAlerts, events) = engine.evaluate(snap, config: settings.settings.alerts, now: snap.uptime); onAlertEvents?(events) где events не пусты; try? await Task.sleep(for: .seconds(isPopoverOpen ? 1 : settings.settings.refreshInterval)) } }`
  - `enum MenuBarRenderer { @MainActor static func attributedTitle(_ segments: [MenuBarSegment]) -> NSAttributedString }` — шрифт `NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)`, разделитель — два пробела; подсвеченный текст — `NSColor.systemRed`; `.icon` — `NSTextAttachment` с template-символом `gauge.medium`; `.cpuGraph` — `NSTextAttachment` с `NSImage` 34×14 pt: 10 столбиков шириной 3 pt, высота пропорциональна значению 0…100, цвет `labelColor`
  - `@MainActor final class StatusItemController { init(store: MetricsStore, settings: SettingsStore, onClick: @escaping (NSStatusBarButton) -> Void) }` — `NSStatusItem(variableLength)`; перерисовка через `withObservationTracking` по `store.latest`, `store.activeAlerts`, `settings.settings.menuBarItems` с повторной подпиской в `onChange` (через `Task { @MainActor in … }`)
  - `@MainActor final class PopoverController { init(store: MetricsStore); func toggle(relativeTo: NSStatusBarButton) }` — `NSPopover`, `behavior = .transient`; `NSPopoverDelegate` выставляет `store.isPopoverOpen`
  - `AppDelegate` создаёт `SettingsStore` → `MetricsStore` → `PopoverController` → `StatusItemController`, вызывает `store.start()`; `main.swift`: `NSApplication.shared`, `setActivationPolicy(.accessory)`, делегат, `run()`

`scripts/build-app.sh`: `set -euo pipefail`; `swift build -c release`; пересоздать `build/StatusApp.app/Contents/{MacOS,Resources}`; скопировать `.build/release/StatusApp` и `Resources/Info.plist`; `codesign --force --sign - build/StatusApp.app`; напечатать путь.

- [ ] **Step 1: Создать файлы выше**
- [ ] **Step 2: Собрать** — Run: `swift build 2>&1 | tail -3` — Expected: `Build complete!` без ошибок; `swift test` по-прежнему зелёный
- [ ] **Step 3: Собрать `.app`** — Run: `scripts/build-app.sh && codesign -dv build/StatusApp.app 2>&1 | grep Identifier` — Expected: `Identifier=local.statusapp.StatusApp`
- [ ] **Step 4: Проверить вживую** — Run: `pkill -x StatusApp; open build/StatusApp.app; sleep 5; screencapture -x -R 0,0,3000,40 /tmp/statusapp-menubar.png` (путь — в scratchpad сессии). Посмотреть снимок: в строке меню `CPU N%  NN°`, значения обновляются (повторный снимок через 4 с отличается). Проверить потребление: `ps -o rss=,%cpu= -p $(pgrep -x StatusApp)` — RSS < 50 000 КБ. Клик по элементу открывает заглушку панели.
- [ ] **Step 5: Commit** — `feat: menu bar app shell, status item rendering, app bundle script`

---

### Task 13: Панель — каркас вкладок и «Обзор»

**Files:**
- Create: `Sources/StatusApp/Popover/PopoverView.swift` (`PopoverTab`, переключатель, футер)
- Create: `Sources/StatusApp/Popover/Components/SparklineView.swift`, `Sources/StatusApp/Popover/Components/HistoryChart.swift`, `Sources/StatusApp/Popover/Components/TileView.swift`, `Sources/StatusApp/Popover/Components/ProcessListView.swift`
- Create: `Sources/StatusApp/Popover/Tabs/OverviewTab.swift`
- Modify: `Sources/StatusApp/Popover/PopoverController.swift` — контент `NSHostingController(rootView: PopoverView(...))`, ширина 360 pt
- Modify: `Sources/StatusApp/App/AppDelegate.swift` — отладочные аргументы запуска

**Interfaces:**
- Consumes: `MetricsStore`, `OverviewTile`, `Series`, `HistoryPoint`, `Format`, `ProcessRow`
- Produces:
  - `enum PopoverTab: String, CaseIterable { case overview, cpu, memory, network, disk, sensors, processes }` — SF Symbols: `square.grid.2x2`, `cpu`, `memorychip`, `network`, `internaldrive`, `thermometer.medium`, `list.bullet`; подсказки (`.help`): `Обзор`, `CPU`, `Память`, `Сеть`, `Диск`, `Сенсоры`, `Процессы`
  - `struct PopoverView: View { init(store: MetricsStore, initialTab: PopoverTab, onOpenSettings: @escaping () -> Void) }` — `Picker(.segmented)` с иконками; футер `⚙ Настройки` (вызывает `onOpenSettings`) и `Выход` (`NSApp.terminate(nil)`)
  - `struct SparklineView: View { init(points: [HistoryPoint], color: Color, yDomain: ClosedRange<Double>? = nil) }` — `Chart` с `LineMark`, без осей, высота 20 pt
  - `struct HistoryChart: View { init(title: String, points: [HistoryPoint], color: Color, yDomain: ClosedRange<Double>?, valueLabel: (Double) -> String) }` — `AreaMark` + `LineMark`, ось Y с подписями через `valueLabel`, высота 80 pt
  - `struct TileView: View { init(title: String, value: String, highlighted: Bool, points: [HistoryPoint], color: Color) }` — подсвеченная плитка: значение `.red`
  - `struct ProcessListView: View { init(rows: [ProcessRow], limit: Int) }` — имя, `Format.percent(cpu)`, `Format.bytes(memory)`
  - `OverviewTab`: плитки по `OverviewTile.visible(in: store.latest)`, сетка 2 колонки, батарея — на всю ширину строкой `78% · 92% здоровья · 14.6 Вт`; подсветка: cpu ← `cpuLoad`, memory ← `memoryPressure`, temperature ← `cpuTemperature`, disk ← `diskSpace`; цвета серий: CPU `.blue`, память `.purple`, температура `.red`, GPU `.orange`, сеть `.cyan`, диск `.green`; ниже «Топ процессов» — `ProcessListView(limit: 5)`
  - Отладочные аргументы (UserDefaults argument domain): `-OpenPopoverOnLaunch YES` открывает панель через 1 с после запуска, `-PopoverTab <rawValue>` — стартовая вкладка

- [ ] **Step 1: Реализовать файлы выше** (вкладки кроме «Обзора» пока — `Text("Скоро")`)
- [ ] **Step 2: Собрать** — `swift build` → `Build complete!`
- [ ] **Step 3: Проверить вживую** — `scripts/build-app.sh && pkill -x StatusApp; open build/StatusApp.app --args -OpenPopoverOnLaunch YES; sleep 8; screencapture -x <scratchpad>/overview.png`. На снимке: 6 плиток с мини-графиками (после нескольких секунд), плитка батареи, «Топ процессов» с 5 строками, футер. Температура ≈ 40–60°.
- [ ] **Step 4: Commit** — `feat: popover with overview tab`

---

### Task 14: Вкладки с деталями

**Files:**
- Create: `Sources/StatusApp/Popover/Tabs/CPUTab.swift`, `MemoryTab.swift`, `NetworkTab.swift`, `DiskTab.swift`, `SensorsTab.swift`, `ProcessesTab.swift` (все в `Sources/StatusApp/Popover/Tabs/`)
- Modify: `Sources/StatusApp/Popover/PopoverView.swift` — заменить заглушки

**Interfaces:**
- Consumes: `HistoryChart`, `ProcessListView`, `MetricsStore`, `Series`, `Format`
- Содержимое (по спецификации §4.2):
  - **CPU:** `HistoryChart` общей загрузки (0…100); по `HistoryChart` на каждый кластер с заголовком = `ClusterLoad.name`; столбики `BarMark` по `cores`, цвет по `level`
  - **Память:** `HistoryChart(.memoryUsed, 0…100)`; строки «Приложения / Wired / Сжатая / Кэш» (`Format.bytes`), «Давление» (`Нормальное`/`Повышенное`/`Критическое`, критическое — красным), «Swap» `used / total`
  - **Сеть:** `HistoryChart` для `.networkDown` и `.networkUp` (подписи `Format.rate`); «Интерфейс» (`interface ?? "en*"`), «Всего с запуска ↓/↑»
  - **Диск:** `HistoryChart` для `.diskRead` и `.diskWrite`; по тому — имя, `ProgressView(value: total − available, total: total)`, «свободно X из Y»
  - **Сенсоры:** секция «Температуры» — все `temperatures` (`Format.celsius`); «Вентиляторы» — только если не пусто (`Format.rpm`); «GPU» — `Format.percent`; «Мощность системы» — `Format.watts`; «Батарея» — только если `battery != nil`: заряд, циклы, здоровье, мощность, «Заряжается»/«От сети»/«От батареи»
  - **Процессы:** `Picker(.segmented)` «CPU / Память», `ProcessListView(limit: 50)` в `ScrollView` высотой ≤ 360 pt; сортировка по памяти — по `memoryBytes` по убыванию

- [ ] **Step 1: Реализовать вкладки**
- [ ] **Step 2: Собрать** — `swift build` → `Build complete!`
- [ ] **Step 3: Проверить каждую вкладку** — для каждого `tab` из `cpu memory network disk sensors processes`: `pkill -x StatusApp; open build/StatusApp.app --args -OpenPopoverOnLaunch YES -PopoverTab $tab; sleep 8; screencapture -x <scratchpad>/tab-$tab.png`. Ожидается: на CPU — 2 кластера «Super» и «Performance» и 18 столбиков; на «Сенсорах» — 2 вентилятора и батарея; нигде нет «0°»/«0 об/мин» вместо `—`.
- [ ] **Step 4: Commit** — `feat: detail tabs`

---

### Task 15: Окно настроек и автозапуск

**Files:**
- Create: `Sources/StatusApp/Settings/SettingsView.swift`, `Sources/StatusApp/Settings/SettingsWindowController.swift`, `Sources/StatusApp/Settings/LaunchAtLogin.swift`
- Modify: `Sources/StatusApp/App/AppDelegate.swift` — `onOpenSettings` показывает окно

**Interfaces:**
- Consumes: `SettingsStore`, `AppSettings`, `MenuBarItem`, `AlertKind`, `AlertRuleConfig`
- Produces:
  - `@MainActor enum LaunchAtLogin { static var isEnabled: Bool { get }; static func set(_ enabled: Bool) throws }` — `SMAppService.mainApp` (`status == .enabled`, `register()`/`unregister()`)
  - `@MainActor final class SettingsWindowController { init(settings: SettingsStore); func show() }` — одно окно `NSWindow` (title `Настройки StatusApp`) с `NSHostingController(SettingsView)`; перед показом `NSApp.activate()`; повторный вызов выводит существующее окно вперёд
  - `SettingsView` — `TabView` из трёх вкладок:
    - **Общие:** `Picker` интервала `1 с / 2 с / 5 с` (только `AppSettings.allowedIntervals`); `Toggle("Запускать при входе")` → `LaunchAtLogin.set`; ошибка — текст под переключателем `Не удалось изменить автозапуск: <описание>`
    - **Строка меню:** `Toggle` на каждый `MenuBarItem` с подписями `Иконка`, `Мини-график CPU`, `Загрузка CPU`, `Память`, `Температура`, `Сеть`
    - **Оповещения:** на каждый `AlertKind` — `Toggle` + поле порога (`Stepper`): температура 60…110 °C шаг 1, загрузка 50…100 % шаг 5, место 1…100 ГиБ шаг 1, давление — без порога; длительность (`Stepper`) 0…600 с шаг 10 для температуры и загрузки
  - Все изменения пишутся в `settings.settings` сразу

- [ ] **Step 1: Реализовать файлы выше**
- [ ] **Step 2: Собрать** — `swift build` → `Build complete!`
- [ ] **Step 3: Проверить вживую** — из `/Applications` (скопировать `build/StatusApp.app`): открыть панель → «Настройки»; включить «Мини-график CPU» и «Сеть» — строка меню меняется сразу; перезапустить приложение — выбор сохранился (`defaults read local.statusapp.StatusApp settings.v1` не пусто); включить автозапуск — `launchctl print gui/$(id -u) | grep -i statusapp` находит сервис, затем выключить.
- [ ] **Step 4: Commit** — `feat: settings window and launch at login`

---

### Task 16: Уведомления и финальная проверка

**Files:**
- Create: `Sources/StatusApp/Notifications/AlertNotifier.swift` (`protocol AlertNotifier`, `UserNotificationNotifier`)
- Modify: `Sources/StatusApp/App/AppDelegate.swift` — `store.onAlertEvents = { events in events.forEach(notifier.notify) }`
- Create: `README.md` — 10–15 строк: требования (Xcode), `swift test`, `scripts/build-app.sh`, установка в `/Applications`, отладочные аргументы, известные ограничения (приватные API, процессы root)

**Interfaces:**
- Consumes: `AlertEvent`, `MetricsStore.onAlertEvents`
- Produces:
  - `@MainActor protocol AlertNotifier { func notify(_ event: AlertEvent) }`
  - `@MainActor final class UserNotificationNotifier: AlertNotifier` — при первом `notify` запрашивает `requestAuthorization(options: [.alert, .sound])`; запрос `UNNotificationRequest(identifier: "\(event.kind.rawValue)-\(UUID())", content: title/body, trigger: nil)`; отказ в разрешении или ошибка — один `Logger.warning`, без падения

- [ ] **Step 1: Реализовать notifier и подключить**
- [ ] **Step 2: Собрать и прогнать все тесты** — `swift test && scripts/build-app.sh` — все тесты passed, `.app` собран
- [ ] **Step 3: Проверить оповещение** — в настройках временно поставить порог загрузки 50 %, длительность 0 с; нагрузить CPU (`yes > /dev/null &` × 18, затем `killall yes`). Ожидается: системное уведомление «Высокая нагрузка CPU», `CPU N%` в строке меню красный, плитка CPU красная; после `killall yes` подсветка гаснет; повторного уведомления в течение 10 минут нет. Вернуть порог 90 % / 60 с.
- [ ] **Step 4: Проверить потребление ресурсов** — после 2 минут работы с закрытой панелью: `ps -o rss=,%cpu= -p $(pgrep -x StatusApp)` — RSS < 50 000 КБ, %CPU < 1.
- [ ] **Step 5: Commit** — `feat: user notifications for alerts; README`
