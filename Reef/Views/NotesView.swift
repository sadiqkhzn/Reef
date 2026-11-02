import SwiftUI

/// The notes pane: a single always-saved monospaced scratchpad.
struct NotesView: View {
    @ObservedObject var model: NotesModel
    var accent: Color
    var headerHeight: CGFloat
    var notchWidth: CGFloat
    /// Leave the open island (back to home).
    var onClose: () -> Void

    @FocusState private var focused: Bool

    private var topInset: CGFloat {
        notchWidth > 0 ? headerHeight : ReefTheme.Spacing.s
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topInset)
            ZStack(alignment: .topLeading) {
                if model.text.isEmpty {
                    Text("Jot something…")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(ReefTheme.Ink.tertiary)
                        .padding(.horizontal, ReefTheme.Spacing.s + 4)
                        .padding(.vertical, ReefTheme.Spacing.s + 2)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $model.text)
                    .focused($focused)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(ReefTheme.Ink.primary)
                    .scrollContentBackground(.hidden)
                    .padding(ReefTheme.Spacing.s)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: ReefTheme.Radius.card, style: .continuous)
                    .fill(Color.black.opacity(0.22)))
            .overlay(
                RoundedRectangle(cornerRadius: ReefTheme.Radius.card, style: .continuous)
                    .strokeBorder(.white.opacity(0.07), lineWidth: 0.5))
            .padding(.horizontal, ReefTheme.Spacing.s)
            .padding(.bottom, 12)
        }
        .onAppear { focused = true }
    }
}
