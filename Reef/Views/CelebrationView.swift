import SwiftUI
import Vortex

/// A short confetti burst shown over the island for a celebratory moment, such
/// as the battery reaching a full charge. Purely decorative and non-interactive.
struct CelebrationView: View {
    var body: some View {
        VortexView(.confetti) {
            Rectangle()
                .fill(.white)
                .frame(width: 10, height: 10)
                .tag("square")
            Circle()
                .fill(.white)
                .frame(width: 10, height: 10)
                .tag("circle")
        }
        .allowsHitTesting(false)
    }
}
