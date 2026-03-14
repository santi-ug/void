//
//  ContentView.swift
//  void
//
//  Created by Santiago Uribe on 3/14/26.
//

import SwiftUI


struct ContentView: View {
    @State private var enableVoid = false

    var body: some View {
        Toggle("Enable Void", isOn: $enableVoid)
            .toggleStyle(.switch)
            .padding()
    }
}

#Preview {
    ContentView()
}
