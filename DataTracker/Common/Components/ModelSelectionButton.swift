import SwiftUI

struct ModelSelectionButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // 图标
                ZStack {
                    Circle()
                        .fill(isSelected ? AnyShapeStyle(Theme.primaryGradient) : AnyShapeStyle(Theme.surfaceElevated))
                        .frame(width: 56, height: 56)
                        .shadow(
                            color: isSelected ? Theme.shadowColor.opacity(0.3) : Theme.shadowColor,
                            radius: isSelected ? 6 : Theme.shadowRadius,
                            x: 0,
                            y: isSelected ? 3 : Theme.shadowOffset.height
                        )
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : Theme.primary)
                }
                
                // 标题
                Text(title)
                    .font(Theme.captionFont)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .fill(isSelected ? Theme.primary.opacity(0.05) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .stroke(isSelected ? Theme.primary.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(Theme.springAnimation, value: isSelected)
    }
}

#Preview {
    HStack(spacing: 12) {
        ModelSelectionButton(title: "学习成绩", icon: "book.fill", isSelected: true) {}
        ModelSelectionButton(title: "体重记录", icon: "scalemass", isSelected: false) {}
        ModelSelectionButton(title: "习惯打卡", icon: "checkmark.circle", isSelected: false) {}
    }
    .padding()
}