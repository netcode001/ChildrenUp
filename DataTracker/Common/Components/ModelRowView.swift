import SwiftUI

struct ModelRowView: View {
    let item: TrackerItem
    
    var body: some View {
        HStack(spacing: 16) {
            // 图标区域
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.primaryGradient)
                    .frame(width: 48, height: 48)
                
                Image(systemName: item.icon ?? "doc.text.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // 信息区域
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(Theme.bodyFont)
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                
                if let group = item.group {
                    Text(group)
                        .font(Theme.captionFont)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            Spacer()
            
            // 箭头图标
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.vertical, 12)
        .background(Color.clear)
    }
}

struct ModelRowView_Previews: PreviewProvider {
    static var previews: some View {
        ModelRowView(item: TrackerItem(
            id: UUID(),
            name: "体重记录",
            group: "健康",
            unit: "kg",
            icon: "scalemass",
            color: nil
        ))
        .previewLayout(.sizeThatFits)
        .padding()
    }
}