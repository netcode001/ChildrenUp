import SwiftUI

struct CardView<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let content: Content

    init(title: String, subtitle: String? = nil, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).foregroundStyle(Theme.primary) }
                Text(title).font(.headline)
                Spacer()
            }
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
            content
        }
        .padding()
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    CardView(title: "示例", subtitle: "副标题", icon: "chart.line.uptrend.xyaxis") {
        Text("内容")
    }
}
