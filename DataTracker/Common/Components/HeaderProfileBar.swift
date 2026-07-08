import SwiftUI

struct HeaderProfileBar: View {
    @State private var searchText: String = ""
    @State private var showNotifications = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.textSecondary)
                    .font(.system(size: 16, weight: .medium))
                
                TextField("搜索记录、模型或数据...", text: $searchText)
                    .font(Theme.bodyFont)
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                            .stroke(Theme.primary.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: Theme.shadowColor.opacity(0.5), radius: Theme.shadowRadius / 2, x: 0, y: 2)
            )
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

#Preview {
    HeaderProfileBar()
}