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

        let promptOption = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(promptOption)

        let targetScreen = activeScreen()
        let screenFrame = targetScreen.frame

        let window = VoidOverlayWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: targetScreen
        )

        // ARC owns this window. Without this, calling close() while we still hold
        // a strong reference causes AppKit to release the window once and ARC to
        // release it again — over-release crashes in objc_release.
        window.isReleasedWhenClosed = false

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

        // NSHostingView (not NSHostingController) avoids AppKit resizing the
        // window down to the SwiftUI content's intrinsic size when assigned,
        // which would otherwise cause a visible resize hitch during the
        // appearance animation.
        let hostingView = NSHostingView(
            rootView: VoidOverlayView().environment(self)
        )
        hostingView.frame = NSRect(origin: .zero, size: screenFrame.size)
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView
        window.setFrame(screenFrame, display: false)

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
        isVoidModeEnabled = false

        guard let window = overlayWindow else { return }
        overlayWindow = nil

        keyboardBlocker.stop()
        NSApp.presentationOptions = previousPresentationOptions

        // Defer all window teardown to a fresh runloop tick. Without this, when
        // disable() is triggered from the toggle *inside* the overlay window, we
        // would start tearing down the view tree currently dispatching the click,
        // which crashes with EXC_BAD_ACCESS in objc_release.
        Task { @MainActor in
            await Task.yield()

            await NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                ctx.allowsImplicitAnimation = true
                window.animator().alphaValue = 0
            }

            try? await Task.sleep(for: .milliseconds(50))
            window.orderOut(nil)
            NSApp.activate(ignoringOtherApps: true)
            // Window deallocates when this Task ends and releases its capture.
            // Don't touch contentViewController or call close() — letting ARC
            // own the lifecycle keeps SwiftUI's hosting controller teardown
            // off the same runloop tick as orderOut.
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

