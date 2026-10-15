import Foundation

/// Переносит настройки со старого идентификатора приложения: UserDefaults привязаны к bundle id,
/// и без переноса смена идентификатора сбросила бы настройки пользователя.
public enum SettingsMigration {
    /// Идентификатор, под которым приложение жило до подписи Developer ID.
    public static let legacyBundleIdentifier = "local.statusapp.StatusApp"

    /// Копирует значение `key` из `legacy` в `current`, только если в `current` его ещё нет.
    /// Возвращает `true`, если что-то скопировано.
    @discardableResult
    public static func migrate(key: String, from legacy: UserDefaults, to current: UserDefaults) -> Bool {
        guard current.object(forKey: key) == nil, let value = legacy.object(forKey: key) else { return false }
        current.set(value, forKey: key)
        return true
    }
}
