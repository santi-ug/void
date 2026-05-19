import SwiftUI

struct VoidOverlayView: View {
    var body: some View {
        // A simple ZStack centers its children automatically
        ZStack {
            VoidPanelContent()
        }
        // Force SwiftUI to take up the full dimensions of the AppKit window
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .ignoresSafeArea()
    }
}

#Preview {
    VoidOverlayView()
        .environment(VoidModeController())
}
