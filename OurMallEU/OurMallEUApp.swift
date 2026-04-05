//
//  OurMallEUApp.swift
//  OurMallEU
//
//  Created by Masud on 02/04/2026.
//

import SwiftUI

@main
struct OurMallEUApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
