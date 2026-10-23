import Foundation

/// Что панель, значок и настройки показывают об обновлении.
public enum UpdateState: Equatable, Sendable {
    case idle
    /// Только при ручной проверке: фоновая идёт молча.
    case checking
    /// Только после ручной проверки.
    case upToDate
    case available(version: String, notesURL: URL?)
    /// `progress` — доля 0…1; `nil`, пока сервер не назвал размер.
    case downloading(version: String, progress: Double?)
    case installing(version: String)
    case failed(message: String)
    /// Ochre запущен из образа DMG или из временной папки: Sparkle отсюда не обновляет.
    case needsMove
}

/// События обновлятеля (Sparkle), переведённые в наши термины.
public enum UpdateEvent: Equatable, Sendable {
    case checkStarted(userInitiated: Bool)
    case found(version: String, notesURL: URL?)
    case notFound(userInitiated: Bool)
    case downloadStarted
    case expectedLength(UInt64)
    case received(UInt64)
    /// Распаковка, готовность к установке и сама установка — для пользователя это один шаг.
    case installing
    case error(message: String, userInitiated: Bool)
    /// Sparkle отказался работать из-за расположения приложения (образ DMG, App Translocation).
    case locationUnsupported
    /// Sparkle закрыл сессию обновления.
    case dismissed
}

/// Состояние обновления и счётчики скачивания. Чистая модель: Sparkle только поставляет события.
public struct UpdateModel: Equatable, Sendable {
    public private(set) var state: UpdateState = .idle
    private var expected: UInt64?
    private var received: UInt64 = 0

    public init() {}

    /// Точка на значке: обновление есть и ещё не установлено. Ошибка ручной проверки не значит, что оно есть.
    public var showsBadge: Bool {
        switch state {
        case .available, .downloading, .installing: true
        default: false
        }
    }

    public mutating func apply(_ event: UpdateEvent) {
        switch event {
        case .checkStarted(let userInitiated):
            if userInitiated { state = .checking }
        case .found(let version, let notesURL):
            state = .available(version: version, notesURL: notesURL)
        case .notFound(let userInitiated):
            state = userInitiated ? .upToDate : .idle
        case .downloadStarted:
            expected = nil
            received = 0
            state = .downloading(version: version, progress: nil)
        case .expectedLength(let length):
            expected = length
            state = .downloading(version: version, progress: progress)
        case .received(let length):
            received &+= length
            state = .downloading(version: version, progress: progress)
        case .installing:
            state = .installing(version: version)
        case .error(let message, let userInitiated):
            state = userInitiated || isInstalling ? .failed(message: message) : .idle
        case .locationUnsupported:
            state = .needsMove
        case .dismissed:
            switch state {
            case .checking, .downloading, .installing: state = .idle
            default: break
            }
        }
    }

    private var version: String {
        switch state {
        case .available(let version, _), .downloading(let version, _), .installing(let version): version
        default: ""
        }
    }

    private var progress: Double? {
        guard let expected, expected > 0 else { return nil }
        return min(1, Double(received) / Double(expected))
    }

    private var isInstalling: Bool {
        switch state {
        case .downloading, .installing: true
        default: false
        }
    }
}
