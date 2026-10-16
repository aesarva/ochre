import Foundation

/// Как часто опрашивать датчики.
public enum SamplingCadence {
    /// При закрытой панели — интервал из настроек; при открытой — не реже раза в 2 с
    /// (или чаще, если в настройках выбран интервал меньше).
    public static func interval(popoverOpen: Bool, setting: Double) -> Double {
        popoverOpen ? min(setting, 2) : setting
    }
}
