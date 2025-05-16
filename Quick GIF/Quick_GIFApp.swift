//
//  Quick_GIFApp.swift
//  Quick GIF
//
//  Created by Viggo Lekdorf on 15/05/2025.
//

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

@main
struct Quick_GIFApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                cleanTempFolder()
            }
        }
    }
    
    func cleanTempFolder() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for file in contents {
                try fileManager.removeItem(at: file)
            }
            print("Temp folder cleared.")
        }
        catch {
            print("Error cleaning temp folder: \(error)")
        }
    }
}
