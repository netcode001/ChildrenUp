import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject var themeManager: AppThemeManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: Theme.spacing) {
            ForEach(AppTheme.allCases) { theme in
                Button(action: {
                    withAnimation {
                        themeManager.currentTheme = theme
                    }
                }) {
                    HStack {
                        HStack(spacing: 12) {
                            Image(systemName: themeIcon(for: theme))
                                .font(.system(size: 20))
                                .foregroundColor(themeManager.currentTheme == theme ? Theme.primary : Theme.textSecondary)
                                .frame(width: 24)
                            
                            Text(theme.displayName)
                                .font(Theme.bodyFont)
                                .foregroundColor(Theme.textPrimary)
                        }
                        
                        Spacer()
                        
                        if themeManager.currentTheme == theme {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Theme.primary)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .fill(Theme.surfaceElevated)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                    .stroke(themeManager.currentTheme == theme ? Theme.primary.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
        }
        .padding(Theme.spacing)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("外观风格")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private func themeIcon(for theme: AppTheme) -> String {
        switch theme {
        case .system: return "gearshape"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

#Preview {
    NavigationStack {
        ThemeSettingsView()
            .environmentObject(AppThemeManager.shared)
    }
}
