import SwiftUI

extension View {
    /// Centers the native window after SwiftUI has attached and sized it.
    func centerWindowOnLaunch() -> some View {
        background(WindowCenterer())
    }
}

// SwiftUI's Window scene provides no direct NSWindow handle, so we bridge
// through NSViewRepresentable for small AppKit window configuration.
struct WindowCenterer: NSViewRepresentable {
    final class Coordinator {
        var didConfigure = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        configureWindow(from: view, context: context)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configureWindow(from: nsView, context: context)
    }

    private func configureWindow(from view: NSView, context: Context) {
        Task { @MainActor in
            await Task.yield()

            guard let window = view.window else { return }
            window.isMovableByWindowBackground = true

            guard !context.coordinator.didConfigure else { return }
            context.coordinator.didConfigure = true

            window.layoutIfNeeded()
            centerContent(of: window)
        }
    }

    private func centerContent(of window: NSWindow) {
        guard let contentView = window.contentView else { return }

        let screenFrame = window.screen?.frame ?? NSScreen.main?.frame ?? .zero
        let contentSize = contentView.frame.size
        let contentRect = NSRect(
            x: screenFrame.midX - contentSize.width / 2,
            y: (screenFrame.midY - contentSize.height / 2) + 20,
            width: contentSize.width,
            height: contentSize.height
        )

        window.setFrame(window.frameRect(forContentRect: contentRect), display: true)
    }
}
