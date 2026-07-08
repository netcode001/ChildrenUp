import SwiftUI

struct SummaryMetricCard: View {
    let title: String
    let value: String
    let unit: String?
    let change: Double // 正值为上升，负值为下降
    let icon: String
    let gradient: LinearGradient
    
    init(title: String, value: String, unit: String? = nil, change: Double, icon: String, gradient: LinearGradient = Theme.primaryGradient) {
        self.title = title
        self.value = value
        self.unit = unit
        self.change = change
        self.icon = icon
        self.gradient = gradient
    }
    
    private var changeText: String {
        let sign = change >= 0 ? "+" : ""
        return String(format: "\(sign)%.1f%%", change)
    }
    
    private var changeColor: Color {
        change >= 0 ? Theme.accent : Theme.error
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: change >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.caption2)
                    Text(changeText)
                        .font(Theme.captionFont)
                }
                .foregroundStyle(changeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(changeColor.opacity(0.15))
                .clipShape(Capsule())
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.captionFont)
                    .foregroundStyle(.white.opacity(0.8))
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(Theme.titleFont)
                        .foregroundStyle(.white)
                    if let unit {
                        Text(unit)
                            .font(Theme.captionFont)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .shadow(color: Theme.shadowColor, radius: Theme.shadowRadius, x: Theme.shadowOffset.width, y: Theme.shadowOffset.height)
    }
}

struct SummaryMetricCard_Previews: PreviewProvider {
    static var previews: some View {
        SummaryMetricCard(
            title: "本周平均成绩",
            value: "88.5",
            unit: "分",
            change: 3.2,
            icon: "chart.line.uptrend.xyaxis"
        )
        .frame(width: 160)
        .previewLayout(.sizeThatFits)
    }
}