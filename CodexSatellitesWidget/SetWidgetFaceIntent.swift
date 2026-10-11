import AppIntents

extension WidgetFace: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Widget Face"

    static var caseDisplayRepresentations: [WidgetFace: DisplayRepresentation] = [
        .quota: "Quota",
        .settings: "Settings"
    ]
}

extension WidgetPresentationFamily: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Widget Family"

    static var caseDisplayRepresentations: [WidgetPresentationFamily: DisplayRepresentation] = [
        .small: "Small",
        .medium: "Medium"
    ]
}

struct SetWidgetFaceIntent: AppIntent {
    static var title: LocalizedStringResource { "Change Widget Face" }
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Family")
    var family: WidgetPresentationFamily

    @Parameter(title: "Face")
    var face: WidgetFace

    init() {
        family = .small
        face = .quota
    }

    init(family: WidgetPresentationFamily, face: WidgetFace) {
        self.family = family
        self.face = face
    }

    func perform() async throws -> some IntentResult {
        WidgetPresentationStore.setFace(face, for: family)
        return .result()
    }
}
