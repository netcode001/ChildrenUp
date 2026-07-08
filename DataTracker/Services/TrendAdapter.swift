import Foundation

struct TrendPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let date: Date?
}

struct TrendAdapter {
    static func points(metric: String, granularity: Int) -> [TrendPoint] {
        let base: [Double]
        switch metric {
        case "学习时长":
            base = [30, 45, 50, 35, 60, 40, 55]
        default:
            base = [78, 82, 75, 88, 90, 84, 92]
        }
        let labels: [String]
        switch granularity {
        case 0:
            labels = ["一","二","三","四","五","六","七"]
        case 2:
            labels = ["一月","二月","三月","四月","五月","六月","七月"]
        default:
            labels = ["第1周","第2周","第3周","第4周","第5周","第6周","第7周"]
        }
        return zip(labels, base).map { TrendPoint(label: $0.0, value: $0.1, date: nil) }
    }
}
