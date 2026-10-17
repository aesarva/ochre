import Foundation

/// Прирост набора накопительных счётчиков (по дискам, по интерфейсам) между опросами.
/// Каждый счётчик сравнивается только со своим прошлым значением: новое устройство даёт лишь базу,
/// пропавшее или обнулившееся не создаёт ложных скачков, а неудачное чтение (пустой набор) базу не трогает.
struct KeyedCounters<Key: Hashable & Sendable>: Sendable {
    private var last: [Key: UInt64] = [:]
    private var lastTime: TimeInterval?

    init() {}

    /// `nil` — нет базы (первый опрос, ошибка чтения, время не продвинулось).
    mutating func advance(_ counters: [Key: UInt64], at time: TimeInterval) -> (delta: UInt64, elapsed: TimeInterval)? {
        guard !counters.isEmpty else { return nil }
        defer {
            last = counters
            lastTime = time
        }
        guard let lastTime, time > lastTime else { return nil }
        var delta: UInt64 = 0
        for (key, value) in counters {
            if let old = last[key], value >= old { delta &+= value - old }
        }
        return (delta, time - lastTime)
    }
}
