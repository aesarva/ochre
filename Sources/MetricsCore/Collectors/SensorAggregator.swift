public enum SensorAggregator {
    /// Отбрасывает мусорные значения, объединяет одноимённые датчики (максимум),
    /// сортирует по имени и вычисляет сводные CPU/GPU температуры.
    static func aggregate(_ raw: [TemperatureReading]) -> (readings: [TemperatureReading], cpu: Double?, gpu: Double?) {
        var byName: [String: Double] = [:]
        for r in raw where r.celsius > 0 && r.celsius < 150 {
            byName[r.name] = Swift.max(byName[r.name] ?? r.celsius, r.celsius)
        }
        let readings = byName.map { TemperatureReading(name: $0.key, celsius: $0.value) }
            .sorted { $0.name < $1.name }
        let cpu = readings.filter { r in ["tdie", "pACC", "eACC"].contains { r.name.contains($0) } }
            .map(\.celsius).max()
        let gpu = readings.filter { $0.name.contains("GPU") }.map(\.celsius).max()
        return (readings, cpu, gpu)
    }
}
