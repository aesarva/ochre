import Foundation

/// Renders metric values for display. An unavailable value (`nil`) renders as "—".
public enum Format {
    private static let missing = "—"
    private static let byteUnits = ["КБ", "МБ", "ГБ", "ТБ"]
    private static let compactUnits = ["K", "M", "G"]

    public static func percent(_ value: Double?) -> String {
        guard let value, value.isFinite else { return missing }
        return String(format: "%.0f%%", value)
    }

    /// Целое число без единиц — например, процент внутри ячейки ядра.
    public static func integer(_ value: Double?) -> String {
        guard let value, value.isFinite else { return missing }
        return String(format: "%.0f", value)
    }

    public static func celsius(_ value: Double?) -> String {
        guard let value, value.isFinite else { return missing }
        return String(format: "%.0f°", value)
    }

    public static func bytes(_ value: UInt64?) -> String {
        guard let value else { return missing }
        return sizeText(Double(value))
    }

    public static func rate(_ bytesPerSecond: Double?) -> String {
        guard let bytesPerSecond, bytesPerSecond.isFinite else { return missing }
        return sizeText(bytesPerSecond) + "/с"
    }

    /// Short form for the menu bar: K/M/G without a space; anything under 1 KB shows as "0K".
    public static func compactRate(_ bytesPerSecond: Double?) -> String {
        guard let bytesPerSecond, bytesPerSecond.isFinite else { return missing }
        guard bytesPerSecond >= 1024 else { return "0K" }
        let (value, index) = scale(bytesPerSecond, maxIndex: compactUnits.count - 1)
        return number(value) + compactUnits[index]
    }

    public static func watts(_ value: Double?) -> String {
        guard let value, value.isFinite else { return missing }
        return String(format: "%.1f Вт", value)
    }

    public static func rpm(_ value: Double?) -> String {
        guard let value, value.isFinite else { return missing }
        return String(format: "%.0f об/мин", value)
    }

    /// Bytes below 1 KB as an integer with "Б"; larger values scaled by 1024 to the largest fitting unit.
    private static func sizeText(_ bytes: Double) -> String {
        guard bytes >= 1024 else { return String(format: "%.0f Б", bytes) }
        let (value, index) = scale(bytes, maxIndex: byteUnits.count - 1)
        return number(value) + " " + byteUnits[index]
    }

    /// Scales a value of at least 1024 down by 1024 steps (at most `maxIndex + 1`), returning the value and the
    /// index into the unit list where index 0 is the first unit above bytes. Bumps to the next unit when
    /// rounding would otherwise print "1024".
    private static func scale(_ value: Double, maxIndex: Int) -> (value: Double, index: Int) {
        var scaled = value / 1024
        var index = 0
        while index < maxIndex && scaled >= 1024 {
            scaled /= 1024
            index += 1
        }
        if index < maxIndex && scaled >= 1023.5 {
            scaled /= 1024
            index += 1
        }
        return (scaled, index)
    }

    /// One decimal below 100, integer otherwise.
    private static func number(_ value: Double) -> String {
        value < 99.95 ? String(format: "%.1f", value) : String(format: "%.0f", value)
    }
}
