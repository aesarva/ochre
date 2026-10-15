import Foundation
import Darwin
import SystemConfiguration

/// Chooses which interface's counters represent "the network".
public enum InterfaceSelector {
    /// The primary interface if present; otherwise the sum of all `en*` interfaces (name `nil`);
    /// `nil` when there is neither.
    static func select(_ counters: [String: InterfaceCounters],
                       primary: String?) -> (name: String?, counters: InterfaceCounters)? {
        if let primary, let c = counters[primary] { return (primary, c) }
        let en = counters.filter { $0.key.hasPrefix("en") }.map(\.value)
        guard !en.isEmpty else { return nil }
        return (nil, InterfaceCounters(rx: en.reduce(0) { $0 &+ $1.rx },
                                       tx: en.reduce(0) { $0 &+ $1.tx }))
    }
}

/// Reads network throughput of the primary interface and accumulates session totals.
public struct NetworkCollector {
    private var downRate = CounterRate()
    private var upRate = CounterRate()
    private var lastName: String??          // .none = no baseline yet
    private var lastCounters: InterfaceCounters?
    private var totalDown: UInt64 = 0
    private var totalUp: UInt64 = 0

    public init() {}

    public mutating func sample(now: TimeInterval) -> NetworkStats? {
        guard let all = Self.readCounters(),
              let sel = InterfaceSelector.select(all, primary: Self.primaryInterface()) else { return nil }

        // A different interface selection is treated as a counter reset.
        let switched = lastName != nil && lastName! != sel.name
        if switched {
            downRate = CounterRate()
            upRate = CounterRate()
        } else if let last = lastCounters {
            if sel.counters.rx > last.rx { totalDown &+= sel.counters.rx - last.rx }
            if sel.counters.tx > last.tx { totalUp &+= sel.counters.tx - last.tx }
        }
        lastName = .some(sel.name)
        lastCounters = sel.counters

        return NetworkStats(interface: sel.name,
                            downPerSecond: downRate.update(sel.counters.rx, at: now),
                            upPerSecond: upRate.update(sel.counters.tx, at: now),
                            totalDown: totalDown, totalUp: totalUp)
    }

    static func primaryInterface() -> String? {
        guard let store = SCDynamicStoreCreate(nil, "local.statusapp" as CFString, nil, nil),
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
