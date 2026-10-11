import Foundation

enum WidgetFace: String, Codable, CaseIterable, Sendable {
    case quota
    case settings
}

enum WidgetPresentationFamily: String, Codable, CaseIterable, Sendable {
    case small
    case medium
}

/// Widget-local presentation state. This is intentionally not app settings state.
enum WidgetPresentationStore {
    private static let keyPrefix = "widgetFace"

    static func face(
        for family: WidgetPresentationFamily,
        defaults: UserDefaults = .standard
    ) -> WidgetFace {
        guard let rawValue = defaults.string(forKey: key(for: family)),
              let face = WidgetFace(rawValue: rawValue) else {
            return .quota
        }
        return face
    }

    static func setFace(
        _ face: WidgetFace,
        for family: WidgetPresentationFamily,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(face.rawValue, forKey: key(for: family))
    }

    private static func key(for family: WidgetPresentationFamily) -> String {
        "\(keyPrefix).\(family.rawValue)"
    }
}
