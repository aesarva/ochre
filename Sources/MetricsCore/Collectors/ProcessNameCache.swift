import Foundation

/// Имена процессов по (PID, время старта): имя не меняется за жизнь процесса, а PID может
/// достаться новому — поэтому ключом служит и время старта. Экономит `proc_pidpath` на каждом опросе.
public struct ProcessNameCache {
    private var names: [Int32: (start: UInt64, name: String)] = [:]

    public init() {}

    public var count: Int { names.count }

    public mutating func name(pid: Int32, startTime: UInt64, resolve: (Int32) -> String) -> String {
        if let cached = names[pid], cached.start == startTime { return cached.name }
        let name = resolve(pid)
        names[pid] = (startTime, name)
        return name
    }

    /// Убирает завершившиеся процессы.
    public mutating func prune(keeping live: Set<Int32>) {
        names = names.filter { live.contains($0.key) }
    }
}
