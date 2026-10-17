import Darwin

/// Send right to the host port. Every `mach_host_self()` call adds a user reference that nobody
/// releases, so the collectors take the port once.
enum MachHost {
    static let port: mach_port_t = mach_host_self()
}
