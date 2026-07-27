import ApplicationServices
import CoreFoundation
import CoreGraphics
import Darwin
import Foundation

/// Why the keyboard could not be blocked.
enum KeyboardBlockerError: Error {
    /// The process is not trusted for Accessibility, so it may not create an event tap.
    case accessibilityDenied
    /// `CGEvent.tapCreate` refused. Usually a stale TCC grant pointing at an older
    /// build of the binary, which macOS reports as a still-enabled toggle.
    case tapCreationFailed
}

// The tap is torn down on the way out of `exit()`. The kernel would reclaim the
// mach port anyway; this just makes the ordering deterministic. Both globals are
// only ever touched from `start()` on the main thread.
nonisolated(unsafe) private weak var activeKeyboardBlocker: KeyboardBlocker?
nonisolated(unsafe) private var didRegisterExitHandler = false

private nonisolated func keyboardBlockerExitHandler() {
    activeKeyboardBlocker?.stop()
}

/// Runs on the event-tap thread for every keystroke, so it must stay allocation-free —
/// a slow callback is exactly what makes macOS disable the tap.
private nonisolated func keyboardBlockerTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // macOS disables a tap whose callback was too slow to answer, and after certain
    // input sequences. It says so by delivering these two pseudo-events. Ignoring
    // them leaves a dead tap that silently passes every key through, which is the
    // single most common way a "keyboard lock" stops locking mid-session.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let refcon {
            Unmanaged<KeyboardBlocker>.fromOpaque(refcon)
                .takeUnretainedValue()
                .reenableTapIfDisabled()
        }
        return Unmanaged.passUnretained(event)
    }

    // Returning nil swallows the event — it never reaches any app.
    return nil
}

/// Swallows every keyboard event system-wide until `stop()` is called.
///
/// `nonisolated` on purpose: the project defaults types to `@MainActor`, but the tap
/// callback is a C function pointer invoked on a dedicated thread, outside Swift
/// concurrency entirely. Shared state is guarded by `lock` instead.
/// `@unchecked Sendable` is carried by `lock`: every mutable member below is read and
/// written only while it is held.
nonisolated final class KeyboardBlocker: @unchecked Sendable {

    /// `NX_SYSDEFINED`. `CGEventType` has no case for it, but it carries the media
    /// keys — brightness, volume, play/pause — which never arrive as `keyDown`.
    /// The whole type is swallowed rather than filtered down to the aux-button
    /// subtype: reading a subtype means building an `NSEvent` per event, and the
    /// hot path is not the place to spend that.
    private static let systemDefinedEventType: CGEventMask = 14

    /// How often the watchdog confirms the tap is still alive.
    private static let watchdogInterval: CFTimeInterval = 1

    /// Upper bound on waiting for the tap thread to come up. Only hit if the thread
    /// fails to start at all, in which case blocking without it would be worse.
    private static let threadStartTimeout: DispatchTimeInterval = .seconds(2)

    private let lock = NSLock()
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var tapRunLoop: CFRunLoop?
    private var watchdog: CFRunLoopTimer?

    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return tap != nil
    }

    func start() throws {
        guard !isRunning else { return }

        // Checked here rather than inferred from a nil tap so the caller can tell
        // "not allowed" apart from "allowed but the grant is stale".
        guard AXIsProcessTrusted() else { throw KeyboardBlockerError.accessibilityDenied }

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
                              | (1 << CGEventType.keyUp.rawValue)
                              | (1 << CGEventType.flagsChanged.rawValue)
                              | (1 << Self.systemDefinedEventType)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: keyboardBlockerTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw KeyboardBlockerError.tapCreationFailed
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            throw KeyboardBlockerError.tapCreationFailed
        }

        lock.lock()
        self.tap = tap
        self.source = source
        lock.unlock()

        registerExitHandler()

        // Service the tap on its own thread. On the main run loop a single slow
        // frame — the overlay's fade-in, a SwiftUI layout pass across a large
        // display — delays the callback past the tap timeout and macOS pulls the
        // tap out from under us. A dedicated thread has nothing else to do.
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [weak self] in
            self?.runTapLoop(ready: ready)
        }
        thread.name = "void.keyboard-blocker"
        thread.qualityOfService = .userInteractive
        thread.start()

        _ = ready.wait(timeout: .now() + Self.threadStartTimeout)
    }

    func stop() {
        lock.lock()
        let tap = self.tap
        let runLoop = self.tapRunLoop
        self.tap = nil
        self.source = nil
        self.tapRunLoop = nil
        self.watchdog = nil
        lock.unlock()

        guard let tap else { return }

        // Disable before unwinding the run loop so no key slips through the gap.
        CGEvent.tapEnable(tap: tap, enable: false)
        if let runLoop { CFRunLoopStop(runLoop) }
    }

    deinit {
        stop()
    }

    /// Called from the tap thread when macOS reports the tap was disabled, and on
    /// every watchdog tick.
    fileprivate func reenableTapIfDisabled() {
        lock.lock()
        let tap = self.tap
        lock.unlock()

        guard let tap, !CGEvent.tapIsEnabled(tap: tap) else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// Reads the tap back out of `self` rather than taking it as a parameter: CF types
    /// aren't `Sendable`, so handing them to the thread's closure would be a warning
    /// for no benefit. `stop()` can't have run yet — `start()` waits on `ready`.
    private func runTapLoop(ready: DispatchSemaphore) {
        lock.lock()
        let tap = self.tap
        let source = self.source
        lock.unlock()

        guard let tap, let source else {
            ready.signal()
            return
        }

        let runLoop = CFRunLoopGetCurrent()!

        // The disabled-notification above is the fast path back from a dropped tap.
        // This is the slow one, for the case where that notification never arrives:
        // without it a dead tap stays dead and void looks enabled while blocking
        // nothing at all.
        let watchdog = CFRunLoopTimerCreateWithHandler(
            kCFAllocatorDefault,
            CFAbsoluteTimeGetCurrent() + Self.watchdogInterval,
            Self.watchdogInterval,
            0,
            0
        ) { [weak self] _ in
            self?.reenableTapIfDisabled()
        }

        lock.lock()
        self.tapRunLoop = runLoop
        self.watchdog = watchdog
        lock.unlock()

        CFRunLoopAddSource(runLoop, source, .commonModes)
        if let watchdog {
            CFRunLoopAddTimer(runLoop, watchdog, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)

        ready.signal()

        // Bounded runs rather than a bare CFRunLoopRun(): a stop() landing in the
        // window between signalling and entering the run loop would otherwise be
        // dropped and strand this thread forever.
        //
        // The condition is identity against the live run loop, not a shared "stopping"
        // flag: a stop() immediately followed by a start() would clear such a flag out
        // from under this thread and leave it spinning alongside its replacement.
        while isCurrentTapLoop(runLoop) {
            CFRunLoopRunInMode(.defaultMode, Self.watchdogInterval, false)
        }

        CFRunLoopRemoveSource(runLoop, source, .commonModes)
        if let watchdog {
            CFRunLoopTimerInvalidate(watchdog)
        }
        CFMachPortInvalidate(tap)
    }

    private func isCurrentTapLoop(_ runLoop: CFRunLoop) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return tapRunLoop === runLoop
    }

    private func registerExitHandler() {
        activeKeyboardBlocker = self
        guard !didRegisterExitHandler else { return }
        didRegisterExitHandler = true
        atexit(keyboardBlockerExitHandler)
    }
}
