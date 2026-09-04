import Foundation

final class QuotaRefreshPreference {
    static let key = "quotaRefreshIntervalMinutes"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var interval: QuotaRefreshInterval {
        get {
            guard let rawValue = defaults.object(forKey: Self.key) as? Int,
                  let interval = QuotaRefreshInterval(rawValue: rawValue) else {
                return .oneMinute
            }
            return interval
        }
        set {
            defaults.set(newValue.rawValue, forKey: Self.key)
        }
    }
}
