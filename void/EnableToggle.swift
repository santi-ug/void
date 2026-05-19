import SwiftUI

struct EnableToggle: View {
    // @Environment(VoidModeController.self) is the modern @Observable pattern.
    // @EnvironmentObject is the legacy ObservableObject API — don't use it here.
    @Environment(VoidModeController.self) private var voidMode

    var body: some View {
        Toggle(
            voidMode.isVoidModeEnabled ? "Leave Void" : "Enter Void",
            isOn: enableBinding
        )
        .toggleStyle(VoidSwitchStyle())
    }

    // Computed property keeps Binding(get:set:) out of body — cleaner and easier
    // to read than an anonymous binding defined inline in the view hierarchy.
    private var enableBinding: Binding<Bool> {
        Binding(
            get: { voidMode.isVoidModeEnabled },
            set: { isOn in
                if isOn { voidMode.enable() }
                else { voidMode.disable() }
            }
        )
    }
}

private struct VoidSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.label
                .font(.system(size: 14, weight: .regular))

            Capsule()
                .fill(configuration.isOn ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                .overlay {
                    Capsule()
                        .stroke(Color(nsColor: .separatorColor).opacity(configuration.isOn ? 0 : 0.65), lineWidth: 1)
                }
                .frame(width: 46, height: 26)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(Color(.sRGB, white: 0.96, opacity: 1))
                        .shadow(color: .black.opacity(0.28), radius: 2, x: 0, y: 1)
                        .padding(3)
                }
                .contentShape(Rectangle())
                .animation(.easeOut(duration: 0.16), value: configuration.isOn)
        }
        .foregroundStyle(.primary)
        .contentShape(Rectangle())
        .onTapGesture {
            configuration.isOn.toggle()
        }
    }
}

#Preview {
    EnableToggle()
        .environment(VoidModeController())
        .padding()
}
