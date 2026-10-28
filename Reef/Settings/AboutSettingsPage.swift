import SwiftUI

/// Version, a short description, and links.
struct AboutSettingsPage: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: ReefTheme.Spacing.m) {
            Image(systemName: "water.waves")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AccentChoice.lagoon.color,
                                    Color(red: 0.15, green: 0.30, blue: 0.70),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing)))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

            Text("Reef")
                .font(.title.weight(.semibold))
            Text(version)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("A calm widget that lives at the top of your Mac's screen.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Link("Source on GitHub", destination: URL(string: "https://github.com/sadiqkhzn/Reef")!)
                .padding(.top, ReefTheme.Spacing.s)

            Text("MIT License")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("About")
    }
}
