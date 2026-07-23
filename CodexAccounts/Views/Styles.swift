//
//  Styles.swift
//  CodexAccounts
//

import SwiftUI

struct ThemedCardModifier: ViewModifier {
    var isHovered: Bool
    var accentColor: Color?
    var theme: ThemeColors

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.md)
                    .fill(isHovered ? theme.cardFillHovered : theme.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.md)
                    .stroke(
                        isHovered && accentColor != nil
                            ? accentColor!.opacity(0.35)
                            : (isHovered ? theme.cardStrokeHovered : theme.cardStroke),
                        lineWidth: 0.75
                    )
            )
            .animation(.easeInOut(duration: AppAnimation.quick), value: isHovered)
    }
}

extension View {
    func themedCard(theme: ThemeColors, isHovered: Bool = false, accentColor: Color? = nil) -> some View {
        modifier(ThemedCardModifier(isHovered: isHovered, accentColor: accentColor, theme: theme))
    }
}

struct GlassButtonStyle: ButtonStyle {
    var color: Color
    var isCompact: Bool = false
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isCompact ? AppTypography.captionMedium : AppTypography.bodyMedium)
            .foregroundStyle(.white)
            .padding(.horizontal, isCompact ? AppSpacing.sm : AppSpacing.md)
            .padding(.vertical, isCompact ? AppSpacing.xs : AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                    .fill(color.opacity(configuration.isPressed ? 0.6 : (isHovering ? 0.85 : 0.75)))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: AppAnimation.quick), value: configuration.isPressed)
            .animation(.easeOut(duration: AppAnimation.quick), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

struct SubtleButtonStyle: ButtonStyle {
    var theme: ThemeColors
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.captionMedium)
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                    .fill(isHovering ? theme.cardFillHovered : .clear)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: AppAnimation.quick), value: configuration.isPressed)
            .onHover { isHovering = $0 }
    }
}
