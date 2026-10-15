public enum SMCDecoder {
    /// Декодирует значение SMC по четырёхсимвольному типу. Неизвестный тип или нехватка байт → `nil`.
    static func decode(type: String, bytes: [UInt8]) -> Double? {
        func bigEndian(_ n: Int) -> UInt64? {
            guard bytes.count >= n else { return nil }
            return bytes.prefix(n).reduce(0) { ($0 << 8) | UInt64($1) }
        }
        switch type {
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            let bits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            return Double(Float(bitPattern: bits))
        case "ui8 ": return bigEndian(1).map { Double($0) }
        case "ui16": return bigEndian(2).map { Double($0) }
        case "ui32": return bigEndian(4).map { Double($0) }
        case "fpe2": return bigEndian(2).map { Double($0) / 4 }
        case "sp78": return bigEndian(2).map { Double(Int16(truncatingIfNeeded: $0)) / 256 }
        default: return nil
        }
    }
}
