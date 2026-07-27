import AppKit
import CoreGraphics
import Darwin
import IOKit
import IOKit.graphics

/// Reads display brightness.
///
/// void paints a screen fully black and kills the keyboard at the same time, so the
/// on-screen toggle is the only way back out. On a display that is already dimmed
/// near zero that toggle is invisible, and the user is left blind-clicking. Checking
/// brightness first turns that into a refusal with an explanation.
enum DisplayBrightness {

    /// Current brightness in 0...1, or nil on displays that report neither source
    /// (common for external monitors).
    static func current(for displayID: CGDirectDisplayID) -> Float? {
        displayServicesBrightness(displayID) ?? ioKitBrightness()
    }

    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32

    private static let displayServicesPath =
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"

    /// Resolved once. The handle is deliberately never `dlclose`d — it stays valid
    /// for the life of the process, which is exactly how long it is needed.
    private static let getBrightness: GetBrightness? = {
        // `dlopen` rather than `RTLD_DEFAULT`: that only searches images already
        // loaded, and nothing a SwiftUI app links pulls DisplayServices in. Looking
        // it up there always misses, the fallback below also misses on Apple
        // Silicon, and the brightness guard quietly stops guarding anything.
        guard let handle = dlopen(displayServicesPath, RTLD_LAZY),
              let symbol = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }

        return unsafeBitCast(symbol, to: GetBrightness.self)
    }()

    /// `DisplayServicesGetBrightness` tracks the macOS brightness slider and is the
    /// only one of the two sources that works on Apple Silicon. Private API, so a
    /// future macOS dropping it degrades to "unknown" rather than crashing.
    private static func displayServicesBrightness(_ displayID: CGDirectDisplayID) -> Float? {
        guard let getBrightness else { return nil }

        var brightness: Float = 0
        guard getBrightness(displayID, &brightness) == 0 else { return nil }

        return min(max(brightness, 0), 1)
    }

    /// IODisplayConnect fallback, for Intel Macs where DisplayServices is unavailable.
    /// Reports the built-in display regardless of which screen was asked for — the
    /// service tree has no usable mapping back to a `CGDirectDisplayID` here.
    private static func ioKitBrightness() -> Float? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IODisplayConnect"),
            &iterator
        ) == kIOReturnSuccess else { return nil }

        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            var brightness: Float = -1
            let didRead = IODisplayGetFloatParameter(
                service, 0, kIODisplayBrightnessKey as CFString, &brightness
            ) == kIOReturnSuccess

            IOObjectRelease(service)
            if didRead { return min(max(brightness, 0), 1) }

            service = IOIteratorNext(iterator)
        }

        return nil
    }
}

extension NSScreen {
    /// The CoreGraphics display backing this screen, for the APIs that take an ID
    /// rather than an `NSScreen`.
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
