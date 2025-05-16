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

struct WindowConfig: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        
        DispatchQueue.main.async {
            if let window = view.window {
                window.styleMask.remove(.resizable)
                window.standardWindowButton(.zoomButton)?.isEnabled = false
                
                if let contentView = window.contentView {
                    let fittingSize = contentView.fittingSize
                    window.setContentSize(fittingSize)
                    
                    window.minSize = fittingSize
                    window.maxSize = fittingSize
                }
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        
    }
}

@main
struct Quick_GIFApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView().background(WindowConfig()).fixedSize()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                cleanTempFolder()
            }
        }
        .windowResizability(.contentSize)
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
