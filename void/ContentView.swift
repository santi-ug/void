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

    var body: some View {
        VStack(spacing: 6) {
            EnableToggle()
            VoidStatusMessage()
        }
        // Top padding leaves room for the (now in-panel) traffic lights.
        // Asymmetric vertical padding visually centers the toggle in the
        // space *below* them.
        .padding(.top, 4)
        .padding(.bottom, 20)
        .padding(.horizontal, 24)
        .fixedSize()
    }
}

/// The only channel void has for saying why nothing happened. Every message here is
/// a refusal the user can act on, so it stays until the next attempt clears it.
struct VoidStatusMessage: View {
    @Environment(VoidModeController.self) private var voidMode

    var body: some View {
        Group {
            if let error = voidMode.lastError {
                Text(error.message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 260)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.smooth(duration: 0.3), value: voidMode.lastError)
    }
}

#Preview {
    MiniWindowView()
        .environment(VoidModeController())
}
