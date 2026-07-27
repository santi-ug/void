import AppKit
import ApplicationServices
import SwiftUI

/// Why entering void mode was refused. Every case is recoverable by the user, so
/// each one carries the sentence that says how.
enum VoidModeError: Equatable {
    case accessibilityDenied
    case inputBlockingUnavailable
    case screenTooDim(percent: Int)

    var message: String {
        switch self {
        case .accessibilityDenied:
            "Needs Accessibility access"
        case .inputBlockingUnavailable:
            "Can't block input — remove and re-add void under Privacy & Security → Accessibility"
        case .screenTooDim(let percent):
            "Screen is at \(percent)% — raise the brightness so you can find your way back out"
        }
    }
}

@Observable
@MainActor
final class VoidModeController {
    private(set) var isVoidModeEnabled = false
    private(set) var hasAccessibilityPermission = false
    private(set) var lastError: VoidModeError?

    /// Below this the black overlay hides its own toggle, and the keyboard is
    /// already gone. Matches the threshold LUCE uses for the same reason.
    private static let minimumBrightness: Float = 0.2

    private var overlayWindow: NSWindow?
    private var previousPresentationOptions: NSApplication.PresentationOptions = []
    private let keyboardBlocker = KeyboardBlocker()

    init() {
        // Non-prompting: the prompt belongs to the moment the user actually asks to
        // enter void, not to launch.
        hasAccessibilityPermission = AXIsProcessTrusted()

        // Accessibility can be granted while void is running. Without re-checking,
        // the toggle keeps refusing until the next launch even though the switch in
        // System Settings is already on. The controller lives as long as the app, so
        // this observer is never removed.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshAccessibilityPermission()
            }
        }
    }

    func enable() {
        guard !isVoidModeEnabled, overlayWindow == nil else { return }
        lastError = nil

        guard !isRunningPreview else {
            isVoidModeEnabled = true
            return
        }

        refreshAccessibilityPermission()
        guard hasAccessibilityPermission else {
            requestAccessibilityPermission()
            lastError = .accessibilityDenied
            return
        }

        let targetScreen = activeScreen()

        if let displayID = targetScreen.displayID,
           let level = DisplayBrightness.current(for: displayID),
           level < Self.minimumBrightness {
            lastError = .screenTooDim(percent: Int((level * 100).rounded()))
            return
        }

        // Block input before the overlay goes up, in that order for two reasons: no
        // keystroke can land during the fade, and a tap that fails to start leaves
        // the screen untouched instead of black-but-not-blocking with no way to tell.
        do {
            try keyboardBlocker.start()
        } catch KeyboardBlockerError.accessibilityDenied {
            lastError = .accessibilityDenied
            return
        } catch {
            // Trusted for Accessibility and the tap still refused: almost always a
            // TCC grant bound to an older build of this bundle, which System Settings
            // keeps showing as enabled.
            lastError = .inputBlockingUnavailable
            return
        }

        isVoidModeEnabled = true
        presentOverlay(on: targetScreen)
    }

    func disable() {
        guard isVoidModeEnabled else { return }
        isVoidModeEnabled = false
        lastError = nil

        keyboardBlocker.stop()

        guard let window = overlayWindow else { return }
        overlayWindow = nil

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

    func refreshAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()

        // A grant that arrived after a failed attempt makes the old complaint stale.
        if hasAccessibilityPermission, lastError == .accessibilityDenied {
            lastError = nil
        }
    }

    private func requestAccessibilityPermission() {
        let promptOption = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(promptOption)
    }

    private func presentOverlay(on screen: NSScreen) {
        let screenFrame = screen.frame

        let window = VoidOverlayWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
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
