import CoreGraphics
import CoreFoundation

// Not @Observable, not @MainActor — this class manages a C-level callback that runs
// on a low-level event tap thread, outside Swift concurrency.
final class KeyboardBlocker {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        // Block all keyboard event phases: key down, key up, and modifier key changes.
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
                              | (1 << CGEventType.keyUp.rawValue)
                              | (1 << CGEventType.flagsChanged.rawValue)

        // The callback returns nil, which swallows the event — it never reaches any app.
        // userInfo is nil because this simple blocker needs no context passed back.
        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, _, _ in nil },
            userInfo: nil
        )

        guard let tap else { return }

        // CGEvent taps must be added to a run loop to receive events.
        // CFRunLoopGetMain() hooks into the app's main run loop.
        runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }
}
