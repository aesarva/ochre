import IOKit

/// Thin helper over IOKit registry queries.
enum IORegistry {
    /// Properties of every service of the given class. Any failure yields an empty array.
    /// With `keys`, only those properties are copied: the full dictionary of `IOAccelerator`
    /// costs ~0.8 ms, a single property ~0.015 ms.
    static func properties(ofClass className: String, keys: [String]? = nil) -> [[String: Any]] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(className), &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var result: [[String: Any]] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            if let keys {
                var dict: [String: Any] = [:]
                for key in keys {
                    if let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                        .takeRetainedValue() {
                        dict[key] = value
                    }
                }
                result.append(dict)
            } else {
                var unmanaged: Unmanaged<CFMutableDictionary>?
                guard IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                      let dict = unmanaged?.takeRetainedValue() as? [String: Any] else { continue }
                result.append(dict)
            }
        }
        return result
    }
}
