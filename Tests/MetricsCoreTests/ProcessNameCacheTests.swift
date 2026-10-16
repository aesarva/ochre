import Testing
@testable import MetricsCore

@Suite struct ProcessNameCacheTests {
    @Test func resolvesOncePerProcessLifetime() {
        var cache = ProcessNameCache()
        var calls = 0
        let resolve: (Int32) -> String = { calls += 1; return "name\($0)" }
        #expect(cache.name(pid: 7, startTime: 100, resolve: resolve) == "name7")
        #expect(cache.name(pid: 7, startTime: 100, resolve: resolve) == "name7")
        #expect(calls == 1)
    }
    @Test func reusedPidWithNewStartTimeResolvesAgain() {
        var cache = ProcessNameCache()
        var calls = 0
        _ = cache.name(pid: 7, startTime: 100) { _ in calls += 1; return "old" }
        #expect(cache.name(pid: 7, startTime: 200) { _ in calls += 1; return "new" } == "new")
        #expect(calls == 2)
    }
    @Test func pruneDropsExitedProcesses() {
        var cache = ProcessNameCache()
        _ = cache.name(pid: 1, startTime: 1) { _ in "a" }
        _ = cache.name(pid: 2, startTime: 1) { _ in "b" }
        cache.prune(keeping: [2])
        #expect(cache.count == 1)
    }
}
