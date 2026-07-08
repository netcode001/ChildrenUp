import SwiftUI
import UIKit
import Combine

struct Theme {
    // MARK: - Dynamic Colors
    static var background: Color {
        Color.dynamic(lightHex: "F8FAFC", darkHex: "020617") // Slate-50 / Slate-950
    }
    
    static var surface: Color {
        Color.dynamic(lightHex: "FFFFFF", darkHex: "0F172A") // White / Slate-900
    }
    
    static var surfaceElevated: Color {
        Color.dynamic(lightHex: "FFFFFF", darkHex: "1E293B") // White / Slate-800
    }
    
    static var primary: Color {
        Color.dynamic(lightHex: "2563EB", darkHex: "3B82F6") // Blue-600 / Blue-500 (Royal Blue)
    }
    
    static var secondary: Color {
        Color.dynamic(lightHex: "10B981", darkHex: "34D399") // Emerald-500 / Emerald-400 (Success/Growth)
    }
    
    static var accent: Color {
        Color.dynamic(lightHex: "06B6D4", darkHex: "22D3EE") // Cyan-500 / Cyan-400 (Tech/AI)
    }

    static let cornerRadius: CGFloat = 16
    static let cornerRadiusSmall: CGFloat = 8

    
    static var warning: Color {
        Color.dynamic(lightHex: "F59E0B", darkHex: "FBBF24") // Amber-500 / Amber-400
    }
    
    static var error: Color {
        Color.dynamic(lightHex: "EF4444", darkHex: "F87171") // Red-500 / Red-400
    }
    
    static var info: Color {
        Color.dynamic(lightHex: "3B82F6", darkHex: "60A5FA") // Blue-500 / Blue-400
    }
    
    static var border: Color {
        Color.dynamic(light: Color.black.opacity(0.1), dark: Color.white.opacity(0.1))
    }
    
    // MARK: - Gradients
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [primary, Color.dynamic(lightHex: "60A5FA", darkHex: "93C5FD")], // Blue-600 -> Blue-400
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var secondaryGradient: LinearGradient {
        LinearGradient(
            colors: [secondary, Color.dynamic(lightHex: "34D399", darkHex: "6EE7B7")], // Emerald-500 -> Emerald-400
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [primary, accent], // Royal Blue -> Cyan (AI/Tech feel)
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var surfaceGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.dynamic(lightHex: "F9F9F9", darkHex: "252530"),
                Color.dynamic(lightHex: "F2F2F2", darkHex: "1C1C23")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Text Colors
    static var textPrimary: Color {
        Color.dynamic(lightHex: "000000", darkHex: "FFFFFF")
    }
    
    static var textSecondary: Color {
        Color.dynamic(light: Color.black.opacity(0.6), dark: Color.white.opacity(0.6))
    }
    
    static var textTertiary: Color {
        Color.dynamic(light: Color.black.opacity(0.3), dark: Color.white.opacity(0.3))
    }
    
    // MARK: - Shadows & Effects
    static var shadowColor: Color {
        Color.dynamic(light: Color.black.opacity(0.05), dark: Color.black.opacity(0.15))
    }
    
    static let shadowRadius: CGFloat = 8
    static let shadowOffset = CGSize(width: 0, height: 2)
    
    static var glowColor: Color {
        primary.opacity(0.4)
    }
    
    static let glowRadius: CGFloat = 8
    
    // MARK: - Spacing & Radius
    static let spacing: CGFloat = 16
    static let padding: CGFloat = 20
    
    // MARK: - Typography
    static let displayFont = Font.system(size: 34, weight: .bold, design: .rounded)
    static let titleFont = Font.system(size: 22, weight: .bold, design: .rounded)
    static let headlineFont = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let subheadlineFont = Font.system(size: 14, weight: .regular, design: .rounded)
    static let bodyFont = Font.system(size: 16, weight: .regular, design: .rounded)
    static let captionFont = Font.system(size: 13, weight: .medium, design: .rounded)
    static let smallFont = Font.system(size: 11, weight: .medium, design: .rounded)
    
    // MARK: - Animation
    static let springAnimation: Animation = .spring(response: 0.4, dampingFraction: 0.7)
    static let smoothAnimation: Animation = .easeInOut(duration: 0.3)
}

// MARK: - Extensions
extension Color {
    static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? dark : light
        })
    }
    
    static func dynamic(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
    
    static func dynamic(lightHex: String, darkHex: String) -> Color {
        let lightColor = UIColor(Color(hex: lightHex))
        let darkColor = UIColor(Color(hex: darkHex))
        return dynamic(light: lightColor, dark: darkColor)
    }
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - Theme Manager
enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色模式"
        case .dark: return "深色模式"
        }
    }
}

final class AppThemeManager: ObservableObject {
    static let shared = AppThemeManager()
    
    @Published var currentTheme: AppTheme = .system {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "user_theme")
        }
    }
    
    private init() {
        if let savedTheme = UserDefaults.standard.string(forKey: "user_theme"),
           let theme = AppTheme(rawValue: savedTheme) {
            self.currentTheme = theme
        }
    }
    
    var colorScheme: ColorScheme? {
        switch currentTheme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

