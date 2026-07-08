import Foundation

struct MockRepository {
    static let items: [TrackerItem] = [
        TrackerItem(
            id: UUID(),
            name: "学习成绩",
            group: "学习",
            unit: "分",
            icon: "book.fill"
        ),
        TrackerItem(
            id: UUID(),
            name: "体重",
            group: "健康",
            unit: "kg",
            icon: "scalemass.fill"
        ),
        TrackerItem(
            id: UUID(),
            name: "习惯打卡",
            group: "生活",
            unit: nil,
            icon: "checkmark.circle.fill"
        )
    ]

    static let metrics: [String] = ["分数", "学习时长"]
}
