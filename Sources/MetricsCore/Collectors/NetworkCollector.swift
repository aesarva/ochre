import Foundation
import Darwin
import SystemConfiguration

/// Chooses which interfaces' counters represent "the network".
public enum InterfaceSelector {
    /// The primary interface if present; otherwise every `en*` interface (name `nil`);
    /// `nil` when there is neither.
    static func select(_ counters: [String: InterfaceCounters],
                       primary: String?) -> (name: String?, counters: [String: InterfaceCounters])? {
        if let primary, let c = counters[primary] { return (primary, [primary: c]) }
        let en = counters.filter { $0.key.hasPrefix("en") }
        guard !en.isEmpty else { return nil }
        return (nil, en)
    }
}

/// Reads network throughput of the primary interface and accumulates session totals.
/// Counters are compared per interface, so switching the primary interface or a new `en*`
/// interface with traffic already on its counters never shows up as a burst.
public struct NetworkCollector {
    private var down = KeyedCounters<String>()
    private var up = KeyedCounters<String>()
    private var totalDown: UInt64 = 0
    private var totalUp: UInt64 = 0

    public init() {}

    public mutating func sample(now: TimeInterval) -> NetworkStats? {
        guard let all = Self.readCounters(),
              let sel = InterfaceSelector.select(all, primary: Self.primaryInterface()) else { return nil }
        let d = down.advance(sel.counters.mapValues(\.rx), at: now)
        let u = up.advance(sel.counters.mapValues(\.tx), at: now)
        totalDown &+= d?.delta ?? 0
        totalUp &+= u?.delta ?? 0
        return NetworkStats(interface: sel.name,
                            downPerSecond: d.map { Double($0.delta) / $0.elapsed },
                            upPerSecond: u.map { Double($0.delta) / $0.elapsed },
                            totalDown: totalDown, totalUp: totalUp)
    }

    static func primaryInterface() -> String? {
        guard let store = SCDynamicStoreCreate(nil, "com.alexsarva.Ochre" as CFString, nil, nil),
              let dict = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any]
        else { return nil }
        return dict["PrimaryInterface"] as? String
    }

    static func readCounters() -> [String: InterfaceCounters]? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &length, nil, 0) == 0, length > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, UInt32(mib.count), &buffer, &length, nil, 0) == 0 else { return nil }

        var result: [String: InterfaceCounters] = [:]
        buffer.withUnsafeBytes { raw in
            var offset = 0
            while offset + MemoryLayout<if_msghdr>.size <= length {
                let hdr = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                let msgLen = Int(hdr.ifm_msglen)
                guard msgLen > 0, offset + msgLen <= length else { break }
                if Int32(hdr.ifm_type) == RTM_IFINFO2,
                   msgLen >= MemoryLayout<if_msghdr2>.size {
                    let h2 = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    var nameBuf = [UInt8](repeating: 0, count: Int(IF_NAMESIZE) + 1)
                    let named = nameBuf.withUnsafeMutableBytes { if_indextoname(UInt32(h2.ifm_index), $0.baseAddress!.assumingMemoryBound(to: CChar.self)) != nil }
                    if named, let end = nameBuf.firstIndex(of: 0) {
                        result[String(decoding: nameBuf[..<end], as: UTF8.self)] = InterfaceCounters(
                            rx: h2.ifm_data.ifi_ibytes, tx: h2.ifm_data.ifi_obytes)
                    }
                }
                offset += msgLen
            }
        }
        return result
    }
}
