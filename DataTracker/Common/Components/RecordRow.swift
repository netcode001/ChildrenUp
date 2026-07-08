import SwiftUI

struct RecordRow: View {
    let icon: String
    let title: String
    let lines: [String]
    let timestamp: String
    let color: Color

    init(icon: String, title: String, lines: [String], timestamp: String, color: Color = Theme.primary) {
        self.icon = icon
        self.title = title
        self.lines = lines
        self.timestamp = timestamp
        self.color = color
    }

    var body: some View {
        let displayIcon = icon.isEmpty ? "doc.text.fill" : icon
        
        return HStack(spacing: 12) {
            Image(systemName: displayIcon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(color.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.bodyFont)
                    .foregroundStyle(.primary)
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(Theme.captionFont)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(timestamp)
                    .font(Theme.captionFont)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

struct RecordRow_Previews: PreviewProvider {
    static var previews: some View {
        RecordRow(
            icon: "book.fill",
            title: "学习成绩",
            lines: ["科目 语文", "分数 92分", "考试名称 期中考试"],
            timestamp: "2 小时前",
            color: Theme.primary
        )
        .previewLayout(.sizeThatFits)
    }
}