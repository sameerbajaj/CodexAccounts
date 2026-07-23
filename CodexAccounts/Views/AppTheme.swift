//
//  AppTheme.swift
//  CodexAccounts
//

import SwiftUI

// MARK: - AppTheme

public enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case midnight   // dark — near-black navy (DEFAULT)
    case sandstone  // light — warm cream
    case arctic     // light — cool slate-blue
    case dusk       // dark — deep indigo

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .midnight:  return "Midnight"
        case .sandstone: return "Sandstone"
        case .arctic:    return "Arctic"
        case .dusk:      return "Dusk"
        }
    }

    public var iconName: String {
        switch self {
        case .midnight:  return "moon.stars.fill"
        case .sandstone: return "sun.dust.fill"
        case .arctic:    return "snowflake"
        case .dusk:      return "sunset.fill"
        }
    }

    /// Preferred color scheme for SwiftUI environment
    public var preferredColorScheme: ColorScheme {
        switch self {
        case .midnight, .dusk: return .dark
        case .sandstone, .arctic: return .light
        }
    }
}

// MARK: - ThemeColors

public struct ThemeColors {
    // Card surfaces
    public let cardFill: Color
    public let cardStroke: Color
    public let cardFillHovered: Color
    public let cardStrokeHovered: Color

    // App background
    public let surfacePrimary: Color
    public let surfaceSecondary: Color

    // Text
    public let textPrimary: Color
    public let textSecondary: Color
    public let textTertiary: Color

    // UI chrome
    public let divider: Color
    public let badgeBackground: Color
    public let progressTrack: Color

    // Accent colors
    public let accentPrimary: Color
    public let accentSecondary: Color
    public let successGreen: Color
    public let warningOrange: Color
    public let dangerRed: Color
    public let pinnedAccent: Color

    // MARK: - Factory

    public static func colors(for theme: AppTheme) -> ThemeColors {
        switch theme {
        case .midnight:  return midnightColors()
        case .sandstone: return sandstoneColors()
        case .arctic:    return arcticColors()
        case .dusk:      return duskColors()
        }
    }

    // MARK: - Midnight (Dark — near-black navy)

    private static func midnightColors() -> ThemeColors {
        ThemeColors(
            cardFill:            Color(red: 0.09, green: 0.10, blue: 0.15),
            cardStroke:          Color(red: 0.20, green: 0.22, blue: 0.32),
            cardFillHovered:     Color(red: 0.12, green: 0.13, blue: 0.20),
            cardStrokeHovered:   Color(red: 0.30, green: 0.33, blue: 0.48),
            surfacePrimary:      Color(red: 0.05, green: 0.06, blue: 0.10),
            surfaceSecondary:    Color(red: 0.07, green: 0.08, blue: 0.13),
            textPrimary:         Color(red: 0.92, green: 0.93, blue: 0.97),
            textSecondary:       Color(red: 0.55, green: 0.58, blue: 0.68),
            textTertiary:        Color(red: 0.35, green: 0.37, blue: 0.47),
            divider:             Color(red: 0.16, green: 0.18, blue: 0.26),
            badgeBackground:     Color(red: 0.14, green: 0.15, blue: 0.22),
            progressTrack:       Color(red: 0.12, green: 0.13, blue: 0.20),
            accentPrimary:       Color(red: 0.45, green: 0.55, blue: 1.00),
            accentSecondary:     Color(red: 0.60, green: 0.40, blue: 0.95),
            successGreen:        Color(red: 0.18, green: 0.90, blue: 0.50),
            warningOrange:       Color(red: 1.00, green: 0.62, blue: 0.32),
            dangerRed:           Color(red: 1.00, green: 0.35, blue: 0.40),
            pinnedAccent:        Color(red: 0.90, green: 0.75, blue: 0.30)
        )
    }

    // MARK: - Sandstone (Light — warm parchment)

    private static func sandstoneColors() -> ThemeColors {
        ThemeColors(
            cardFill:            Color(red: 0.96, green: 0.93, blue: 0.88),
            cardStroke:          Color(red: 0.84, green: 0.79, blue: 0.72),
            cardFillHovered:     Color(red: 0.94, green: 0.90, blue: 0.84),
            cardStrokeHovered:   Color(red: 0.75, green: 0.69, blue: 0.60),
            surfacePrimary:      Color(red: 0.97, green: 0.95, blue: 0.91),
            surfaceSecondary:    Color(red: 0.93, green: 0.90, blue: 0.85),
            textPrimary:         Color(red: 0.15, green: 0.12, blue: 0.07),
            textSecondary:       Color(red: 0.40, green: 0.34, blue: 0.25),
            textTertiary:        Color(red: 0.58, green: 0.52, blue: 0.43),
            divider:             Color(red: 0.83, green: 0.78, blue: 0.70),
            badgeBackground:     Color(red: 0.88, green: 0.84, blue: 0.78),
            progressTrack:       Color(red: 0.88, green: 0.84, blue: 0.77),
            accentPrimary:       Color(red: 0.40, green: 0.20, blue: 0.76),
            accentSecondary:     Color(red: 0.65, green: 0.30, blue: 0.80),
            successGreen:        Color(red: 0.10, green: 0.48, blue: 0.22),
            warningOrange:       Color(red: 0.80, green: 0.30, blue: 0.08),
            dangerRed:           Color(red: 0.78, green: 0.16, blue: 0.16),
            pinnedAccent:        Color(red: 0.65, green: 0.50, blue: 0.20)
        )
    }

    // MARK: - Arctic (Light — cool crisp white-blue)

    private static func arcticColors() -> ThemeColors {
        ThemeColors(
            cardFill:            Color(red: 0.94, green: 0.96, blue: 0.99),
            cardStroke:          Color(red: 0.80, green: 0.85, blue: 0.92),
            cardFillHovered:     Color(red: 0.90, green: 0.93, blue: 0.97),
            cardStrokeHovered:   Color(red: 0.68, green: 0.75, blue: 0.86),
            surfacePrimary:      Color(red: 0.96, green: 0.97, blue: 0.99),
            surfaceSecondary:    Color(red: 0.91, green: 0.93, blue: 0.97),
            textPrimary:         Color(red: 0.09, green: 0.12, blue: 0.20),
            textSecondary:       Color(red: 0.34, green: 0.40, blue: 0.52),
            textTertiary:        Color(red: 0.52, green: 0.58, blue: 0.68),
            divider:             Color(red: 0.80, green: 0.84, blue: 0.90),
            badgeBackground:     Color(red: 0.87, green: 0.90, blue: 0.95),
            progressTrack:       Color(red: 0.87, green: 0.90, blue: 0.95),
            accentPrimary:       Color(red: 0.30, green: 0.15, blue: 0.82),
            accentSecondary:     Color(red: 0.50, green: 0.25, blue: 0.90),
            successGreen:        Color(red: 0.04, green: 0.46, blue: 0.28),
            warningOrange:       Color(red: 0.82, green: 0.26, blue: 0.04),
            dangerRed:           Color(red: 0.82, green: 0.12, blue: 0.20),
            pinnedAccent:        Color(red: 0.30, green: 0.20, blue: 0.80)
        )
    }

    // MARK: - Dusk (Dark — deep warm indigo-purple)

    private static func duskColors() -> ThemeColors {
        ThemeColors(
            cardFill:            Color(red: 0.12, green: 0.10, blue: 0.20),
            cardStroke:          Color(red: 0.22, green: 0.18, blue: 0.34),
            cardFillHovered:     Color(red: 0.16, green: 0.13, blue: 0.26),
            cardStrokeHovered:   Color(red: 0.32, green: 0.26, blue: 0.46),
            surfacePrimary:      Color(red: 0.08, green: 0.06, blue: 0.14),
            surfaceSecondary:    Color(red: 0.10, green: 0.08, blue: 0.18),
            textPrimary:         Color(red: 0.94, green: 0.90, blue: 0.84),
            textSecondary:       Color(red: 0.62, green: 0.56, blue: 0.48),
            textTertiary:        Color(red: 0.42, green: 0.37, blue: 0.32),
            divider:             Color(red: 0.20, green: 0.16, blue: 0.28),
            badgeBackground:     Color(red: 0.18, green: 0.14, blue: 0.26),
            progressTrack:       Color(red: 0.15, green: 0.12, blue: 0.22),
            accentPrimary:       Color(red: 0.75, green: 0.58, blue: 1.00),
            accentSecondary:     Color(red: 0.90, green: 0.45, blue: 0.80),
            successGreen:        Color(red: 0.28, green: 0.85, blue: 0.50),
            warningOrange:       Color(red: 0.98, green: 0.62, blue: 0.28),
            dangerRed:           Color(red: 1.00, green: 0.38, blue: 0.38),
            pinnedAccent:        Color(red: 0.95, green: 0.70, blue: 0.25)
        )
    }

    // MARK: - Helpers

    public func statusColor(remainingPercent: Double, isLimitReached: Bool) -> Color {
        if isLimitReached || remainingPercent <= 15 {
            return dangerRed
        } else if remainingPercent <= 40 {
            return warningOrange
        } else {
            return successGreen
        }
    }

    public func planBadgeGradient(for plan: String) -> LinearGradient {
        let p = plan.lowercased()
        if p.contains("pro") {
            return LinearGradient(colors: [Color(red: 0.65, green: 0.35, blue: 1.0), Color(red: 0.50, green: 0.25, blue: 0.92)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if p.contains("plus") {
            return LinearGradient(colors: [Color(red: 0.30, green: 0.55, blue: 1.0), Color(red: 0.15, green: 0.70, blue: 0.98)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if p.contains("go") {
            return LinearGradient(colors: [Color(red: 0.10, green: 0.72, blue: 0.58), Color(red: 0.05, green: 0.87, blue: 0.50)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if p.contains("team") || p.contains("enterprise") {
            return LinearGradient(colors: [Color(red: 1.0, green: 0.60, blue: 0.15), Color(red: 1.0, green: 0.75, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: [Color(red: 0.45, green: 0.48, blue: 0.55), Color(red: 0.35, green: 0.38, blue: 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - AppTypography

public enum AppTypography {
    public static let title = Font.system(size: 14, weight: .semibold, design: .rounded)
    public static let headline = Font.system(size: 12, weight: .semibold, design: .rounded)
    public static let body = Font.system(size: 11, weight: .regular, design: .rounded)
    public static let bodyMedium = Font.system(size: 11, weight: .medium, design: .rounded)
    public static let caption = Font.system(size: 10, weight: .regular, design: .rounded)
    public static let captionMedium = Font.system(size: 10, weight: .medium, design: .rounded)
    public static let micro = Font.system(size: 9, weight: .medium, design: .rounded)
    public static let stat = Font.system(size: 16, weight: .bold, design: .rounded).monospacedDigit()
    public static let statMedium = Font.system(size: 13, weight: .bold, design: .rounded).monospacedDigit()
    public static let statSmall = Font.system(size: 11, weight: .bold, design: .rounded).monospacedDigit()
    public static let mono = Font.system(size: 10, weight: .regular, design: .monospaced)
    public static let logoMono = Font.system(size: 11.5, weight: .black, design: .monospaced)
    public static let logoMonoLight = Font.system(size: 11.5, weight: .light, design: .monospaced)
}

// MARK: - Tokens

public enum AppSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
}

public enum AppCornerRadius {
    public static let sm: CGFloat = 6
    public static let md: CGFloat = 8
    public static let lg: CGFloat = 12
}

public enum AppAnimation {
    public static let quick: Double = 0.15
    public static let standard: Double = 0.25
    public static let smooth: Double = 0.35
    public static func spring() -> Animation {
        .spring(response: 0.3, dampingFraction: 0.8)
    }
}
