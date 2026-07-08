import SwiftUI

struct GlassCard<Content: View>: View {
    var content: Content
    var padding: CGFloat
    
    init(padding: CGFloat = Theme.padding, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    // Base dark layer
                    Theme.surface.opacity(0.6)
                    
                    // Gradient overlay for depth
                    Theme.surfaceGradient.opacity(0.3)
                    
                    // Glass border
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .shadow(color: Theme.shadowColor, radius: Theme.shadowRadius, x: Theme.shadowOffset.width, y: Theme.shadowOffset.height)
            )
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        GlassCard {
            Text("Glass Card Preview")
                .foregroundColor(Theme.textPrimary)
        }
    }
}
