//
//  CodexAccountsApp.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/21/26.
//

import SwiftUI
import AppKit

@main
struct CodexAccountsApp: App {
    @State private var viewModel = AccountsViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopover(viewModel: viewModel)
        } label: {
            MenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu Bar Label

struct MenuBarLabel: View {
    let viewModel: AccountsViewModel

    private var remaining: Double? {
        viewModel.accounts.isEmpty ? nil : viewModel.menuBarRemaining
    }

    private var statusColor: Color {
        guard let r = remaining else { return .primary }
        if r > 40 { return .green }
        if r > 15 { return .orange }
        return .red
    }

    private var litBars: Int {
        guard let r = remaining else { return 3 }
        if r >= 75 { return 3 }
        if r >= 40 { return 2 }
        return 1
    }

    private var showIcon: Bool {
        viewModel.menuBarDisplayMode != .percentOnly
    }

    private var showPercent: Bool {
        viewModel.menuBarDisplayMode != .iconOnly
    }

    var body: some View {
        HStack(spacing: 3) {
            if showIcon {
                Image(nsImage: makeBarsImage(litBars: litBars, litColor: statusColor))
            }

            if showPercent, let r = remaining {
                Text("\(Int(r))%")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
            }
        }
    }
}

/// Draw 3 ascending bars into an NSImage using CoreGraphics.
/// NSImage (not SwiftUI shapes) is required because NSStatusBarButton doesn't
/// give SwiftUI shape views a non-zero size when there is no accompanying Text —
/// causing the icon-only mode to disappear entirely from the menu bar.
private func makeBarsImage(litBars: Int, litColor: Color) -> NSImage {
    let w: CGFloat = 14
    let h: CGFloat = 12
    let img = NSImage(size: NSSize(width: w, height: h), flipped: false) { _ in
        let barW: CGFloat = 3.2
        let spacing: CGFloat = 1.5
        let heights: [CGFloat] = [4.5, 7.5, 11.0]

        let litNS  = NSColor(litColor)
        let dimNS  = NSColor.labelColor.withAlphaComponent(0.22)

        for i in 0..<3 {
            let x = CGFloat(i) * (barW + spacing)
            let bh = heights[i]
            let barRect = NSRect(x: x, y: 0, width: barW, height: bh)
            let path = NSBezierPath(roundedRect: barRect, xRadius: 1.5, yRadius: 1.5)
            (i < litBars ? litNS : dimNS).setFill()
            path.fill()
        }
        return true
    }
    img.isTemplate = false
    return img
}