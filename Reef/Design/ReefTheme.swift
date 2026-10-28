import SwiftUI

/// Design tokens shared by every Reef surface.
///
/// Values live here rather than inline so the island, its live activities, the
/// HUDs, and the settings window all read as one system. Sizes follow a 4 pt
/// grid; radii are concentric, so a card inside the open island uses the
/// island radius minus the padding between them.
enum ReefTheme {

    /// Spacing on a 4 pt grid.
    enum Spacing {
        static let hairline: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    /// Corner radii.
    enum Radius {
        /// The open island body.
        static let island: CGFloat = 26
        /// Padding between the island edge and the cards inside it.
        static let islandInset: CGFloat = 10
        /// Cards inside the open island, concentric with the island corner.
        static let card: CGFloat = island - islandInset
        /// Small controls such as chips and the selected tab pill.
        static let control: CGFloat = 9
    }

    /// Type ramp. Everything uses the rounded design so numbers and labels
    /// feel at home next to the soft silhouette.
    enum Typography {
        static let display = Font.system(size: 34, weight: .semibold, design: .rounded)
        static let title = Font.system(size: 15, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 13, weight: .medium, design: .rounded)
        static let caption = Font.system(size: 11, weight: .medium, design: .rounded)
        /// Numbers shown inside the collapsed wings.
        static let wing = Font.system(size: 12, weight: .semibold, design: .rounded)
    }

    /// Foreground colors on the island. The island is always dark, so these
    /// are fixed rather than adapting to the system appearance.
    enum Ink {
        static let primary = Color.white
        static let secondary = Color.white.opacity(0.62)
        static let tertiary = Color.white.opacity(0.38)
        /// Fill behind cards and controls inside the island.
        static let fill = Color.white.opacity(0.07)
        /// Fill for a pressed or selected control.
        static let fillStrong = Color.white.opacity(0.14)
        /// Hairline separating cards from the island body.
        static let stroke = Color.white.opacity(0.10)
    }

    /// Status colors. These keep their meaning regardless of the chosen accent.
    enum Status {
        static let charging = Color(red: 0.36, green: 0.89, blue: 0.47)
        static let warning = Color(red: 1.0, green: 0.80, blue: 0.24)
        static let critical = Color(red: 1.0, green: 0.36, blue: 0.33)
    }
}
