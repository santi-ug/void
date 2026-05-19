import SwiftUI
import AppKit

@Observable
@MainActor
final class VoidModeController {
    var isVoidModeEnabled = false
    var hasAccessibilityPermission = false

    private var overlayWindow: NSWindow?
    private var previousPresentationOptions: NSApplication.PresentationOptions = []
    private let keyboardBlocker = KeyboardBlocker()

    func enable() {
        guard !isVoidModeEnabled, overlayWindow == nil else { return }
        isVoidModeEnabled = true

        guard !isRunningPreview else { return }

        hasAccessibilityPermission = AXIsProcessTrusted()

        let targetScreen = activeScreen()
        let screenFrame = targetScreen.frame

        let window = VoidOverlayWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: targetScreen
        )

        window.setFrame(screenFrame, display: false)
        window.backgroundColor = .black
        window.isOpaque = true
        window.level = .screenSaver

        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]

        let hostingController = NSHostingController(
            rootView: VoidOverlayView()
                .environment(self)
        )
        hostingController.view.frame = NSRect(origin: .zero, size: screenFrame.size)
        hostingController.view.autoresizingMask = [.width, .height]
        window.contentViewController = hostingController

        overlayWindow = window
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.allowsImplicitAnimation = true
            window.animator().alphaValue = 1
        }

        previousPresentationOptions = NSApp.presentationOptions
        NSApp.presentationOptions = presentationOptionsForVoidMode(from: previousPresentationOptions)

        if hasAccessibilityPermission {
            keyboardBlocker.start()
        }
    }

    func disable() {
        guard isVoidModeEnabled else { return }

        guard let window = overlayWindow else {
            isVoidModeEnabled = false
            return
        }

        overlayWindow = nil
        keyboardBlocker.stop()
        NSApp.presentationOptions = previousPresentationOptions

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.allowsImplicitAnimation = true
            window.animator().alphaValue = 0
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            window.orderOut(nil)
            window.contentViewController = nil
            window.close()
            isVoidModeEnabled = false
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private var isRunningPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private func presentationOptionsForVoidMode(
        from options: NSApplication.PresentationOptions
    ) -> NSApplication.PresentationOptions {
        var options = options
        options.remove([.autoHideDock, .autoHideMenuBar])
        options.insert([.hideDock, .hideMenuBar])
        return options
    }

    private func activeScreen() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation

        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return screen
        }

        return NSApp.keyWindow?.screen ?? NSScreen.main ?? NSScreen.screens[0]
    }
}

private final class VoidOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

