import SwiftUI

struct MenuBarView: View {
    @Environment(VoidModeController.self) private var voidMode
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EnableToggle()

            Divider()

            // Button action form Button("Label", action: method) keeps
            // layout and logic clearly separated — no inline closures in body.
            Button("Show Window", action: showWindow)
            Button("Quit Void", action: quit)
                .keyboardShortcut("q")
        }
        .padding(14)
        .frame(width: 155)
    }

    private func showWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func quit() {
        NSApp.terminate(nil)
    }
}

#Preview {
    MenuBarView()
        .environment(VoidModeController())
}
