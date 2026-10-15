import Foundation

/// Monotonic time source (CLOCK_MONOTONIC, keeps counting across sleep).
public enum MonotonicClock {
    public static func now() -> TimeInterval {
        Double(clock_gettime_nsec_np(CLOCK_MONOTONIC)) / 1e9
    }
}
