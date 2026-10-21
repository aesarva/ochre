import Foundation

/// То, что миграции нужно от хранилища настроек: в тестах вместо UserDefaults — словарь в памяти,
/// чтобы прогон не оставлял домены в ~/Library/Preferences.
public protocol SettingsStorage {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: SettingsStorage {}

/// Переносит настройки со старого идентификатора приложения: UserDefaults привязаны к bundle id,
/// и без переноса смена идентификатора сбросила бы настройки пользователя.
public enum SettingsMigration {
    /// Прежние идентификаторы приложения, от новых к старым: до переименования в Ochre
    /// и до подписи Developer ID.
    public static let legacyBundleIdentifiers = ["com.alexsarva.StatusApp", "local.statusapp.StatusApp"]

    /// Копирует значение `key` из `legacy` в `current`, только если в `current` его ещё нет.
    /// Возвращает `true`, если что-то скопировано.
    @discardableResult
    public static func migrate(key: String, from legacy: some SettingsStorage, to current: some SettingsStorage) -> Bool {
        guard current.object(forKey: key) == nil, let value = legacy.object(forKey: key) else { return false }
        current.set(value, forKey: key)
        return true
    }

    /// Берёт значение из первого (самого нового) старого хранилища, где оно есть.
    @discardableResult
    public static func migrate(key: String, fromFirstOf legacies: [any SettingsStorage], to current: some SettingsStorage) -> Bool {
        legacies.contains { migrate(key: key, from: $0, to: current) }
    }
}
