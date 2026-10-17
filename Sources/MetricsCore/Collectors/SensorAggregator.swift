import Foundation


public enum SensorAggregator {
    /// Датчики кристалла CPU: по ним считается температура в строке меню и для оповещения.
    static func isCPU(_ name: String) -> Bool {
        ["tdie", "pACC", "eACC"].contains { name.contains($0) }
    }

    /// Правдоподобная температура; часть HID-датчиков всегда отдаёт мусор вроде −9201°.
    static func isPlausible(_ celsius: Double) -> Bool {
        celsius > 0 && celsius < 150
    }

    /// Отбрасывает мусорные значения, объединяет одноимённые датчики (максимум),
    /// сортирует по имени и вычисляет сводные CPU/GPU температуры.
    static func aggregate(_ raw: [TemperatureReading]) -> (readings: [TemperatureReading], cpu: Double?, gpu: Double?) {
        var byName: [String: Double] = [:]
        for r in raw where isPlausible(r.celsius) {
            byName[r.name] = Swift.max(byName[r.name] ?? r.celsius, r.celsius)
        }
        let readings = byName.map { TemperatureReading(name: $0.key, celsius: $0.value) }
            .sorted { $0.name < $1.name }
        let cpu = readings.filter { isCPU($0.name) }.map(\.celsius).max()
        let gpu = readings.filter { $0.name.contains("GPU") }.map(\.celsius).max()
        return (readings, cpu, gpu)
    }
}

/// Когда перечитывать температуры: не чаще `maxAge`, но сразу, если нужен полный набор, а прошлое чтение было кратким.
struct TemperatureReadState {
    private var readAt: TimeInterval = -.infinity
    private var wasFull = false

    func needsRead(now: TimeInterval, maxAge: TimeInterval, full: Bool) -> Bool {
        now - readAt >= maxAge || (full && !wasFull)
    }

    mutating func didRead(at time: TimeInterval, full: Bool) {
        readAt = time
        wasFull = full
    }
}
