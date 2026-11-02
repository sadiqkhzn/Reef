import SwiftUI

/// A single persisted scratchpad for the Notes pane.
@MainActor
final class NotesModel: ObservableObject {
    @Published var text: String {
        didSet { UserDefaults.standard.set(text, forKey: key) }
    }

    private let key = "notes.scratchpad"

    init() {
        text = UserDefaults.standard.string(forKey: key) ?? ""
    }
}
