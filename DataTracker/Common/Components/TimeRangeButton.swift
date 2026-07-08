import SwiftUI

struct TimeRangeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.captionFont)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(isSelected ? .white : Theme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            Theme.primaryGradient
                        } else {
                            Theme.surface
                        }
                    }
                )
                .clipShape(Capsule())
                .shadow(
                    color: isSelected ? Theme.shadowColor.opacity(0.3) : Theme.shadowColor,
                    radius: isSelected ? 6 : Theme.shadowRadius,
                    x: 0,
                    y: isSelected ? 2 : Theme.shadowOffset.height
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(Theme.springAnimation, value: isSelected)
    }
}

#Preview {
    HStack(spacing: 12) {
        TimeRangeButton(title: "今日", isSelected: false) {}
        TimeRangeButton(title: "本周", isSelected: true) {}
        TimeRangeButton(title: "本月", isSelected: false) {}
    }
    .padding()
}