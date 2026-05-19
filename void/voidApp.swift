//
//  voidApp.swift
//  void
//
//  Created by Santiago Uribe on 3/14/26.
//

import SwiftUI

@main
struct VoidApp: App {
    @State private var voidMode = VoidModeController()

    var body: some Scene {
        Window("Void", id: "main") {
            MiniWindowView()
                .environment(voidMode)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        MenuBarExtra(
            "Void",
            systemImage: voidMode.isVoidModeEnabled ? "circle.fill" : "circle"
        ) {
            MenuBarView()
                .environment(voidMode)
        }
        .menuBarExtraStyle(.window)
    }
}
