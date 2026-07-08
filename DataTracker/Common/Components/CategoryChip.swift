import SwiftUI

struct CategoryChip: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    init(title: String, icon: String, color: Color = Theme.primary, action: @escaping () -> Void = {}) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(color.gradient)
                            .shadow(color: Theme.shadowColor, radius: Theme.shadowRadius, x: Theme.shadowOffset.width, y: Theme.shadowOffset.height)
                    )
                
                Text(title)
                    .font(Theme.captionFont)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CategoryChip_Previews: PreviewProvider {
    static var previews: some View {
        CategoryChip(title: "成绩", icon: "book.fill", color: Theme.primary)
            .frame(width: 80)
            .previewLayout(.sizeThatFits)
    }
}