import SwiftUI

struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    
    init(icon: String = "plus", action: @escaping () -> Void) {
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(Theme.primaryGradient)
                        .shadow(color: Theme.shadowColor, radius: Theme.shadowRadius, x: Theme.shadowOffset.width, y: Theme.shadowOffset.height)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    FloatingActionButton {}
}