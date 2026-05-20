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
        // Top padding leaves room for the (now in-panel) traffic lights.
        // Asymmetric vertical padding visually centers the toggle in the
        // space *below* them.
        .padding(.top, 4)
        .padding(.bottom, 20)
        .padding(.horizontal, 24)
        .fixedSize()
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
