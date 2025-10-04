//
//  ChronicaeApp.swift
//  Chronicae
//
//  Created by 최의택 on 9/22/25.
//

import SwiftUI

@main
struct ChronicaeApp: App {
    @NSApplicationDelegateAdaptor(ChronicaeAppDelegate.self) private var appDelegate

    @State private var appState = AppState()
    @State private var serverManager = ServerManager.shared
    @StateObject private var loginItemManager = LoginItemManager()

    var body: some Scene {
        WindowGroup(id: AppSceneRouter.SceneID.main.rawValue) {
            ContentView(appState: appState, serverManager: serverManager)
        }

        MenuBarExtra("Chronicae", systemImage: "server.rack") {
            MenuBarContentView(serverManager: serverManager, loginItemManager: loginItemManager)
        }
        .menuBarExtraStyle(.menu)
    }
}
