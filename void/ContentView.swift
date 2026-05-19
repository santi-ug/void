//
//  ContentView.swift
//  void
//
//  Created by Santiago Uribe on 3/14/26.
//

import SwiftUI

struct MiniWindowView: View {
    var body: some View {
        VoidPanelContent()
            .centerWindowOnLaunch()
    }
}

struct VoidPanelContent: View {
    @Environment(VoidModeController.self) private var voidMode

    private var showsAccessibilityNudge: Bool {
        voidMode.isVoidModeEnabled && !voidMode.hasAccessibilityPermission
    }

    var body: some View {
        VStack(spacing: 6) {
            EnableToggle()

            if showsAccessibilityNudge {
                AccessibilityNudge()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .fixedSize()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)
        .animation(.smooth(duration: 0.3), value: showsAccessibilityNudge)
    }
}

private struct AccessibilityNudge: View {
    var body: some View {
        Text("Needs Accessibility access")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

#Preview {
    MiniWindowView()
        .environment(VoidModeController())
}
