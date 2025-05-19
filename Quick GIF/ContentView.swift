//
//  ContentView.swift
//  Quick GIF
//
//  Created by Viggo Lekdorf on 15/05/2025.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers
import Combine

struct ContentView: View {
    @State private var selectedPaths: [String] = []
    @State private var framerate: String = "15"
    @State private var resolution: String = "640"
    @State private var status: String = ""
    @State private var gifPreviewPath: String?
    @State private var outputPath: String = (NSTemporaryDirectory() as NSString).appendingPathComponent("output.gif")
    @State private var importedCount: Int = 0
    @State private var isInProgress: Bool = false
    @State private var progress: Double = 0.0
    
    let allowedExtensions = [
        "png", "jpg", "jpeg", "bmp", "tiff", "tif", "gif", "webp", "pbm", "pgm", "ppm", "tga", "sgi", "jp2", "j2k", "jpf", "jpx", "j2c", "icns", "heic", "heif"
    ]
    
    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            VStack(spacing: 10) {
                Text("Quick GIF").font(.title).padding(.top)
                Text("Quickly generate a GIF using ffmpeg")
            }
            
            VStack(spacing: 20) {
                Text("Press the button below to import files, or drag them into the window")
                Button("Select images or folder") {
                    selectFiles()
                }
                
                Text("\(importedCount) file(s) imported")
                
                HStack {
                    Text("Framerate:")
                    TextField("15", text: $framerate)
                        .frame(width: 60)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onReceive(Just(framerate)) { newValue in
                            let filtered = newValue.filter { ("0"..."9").contains($0) }
                            if filtered != newValue {
                                self.framerate = String(filtered)
                            }
                        }
                }
                
                HStack {
                    Text("Resolution (width):")
                    TextField("640", text: $resolution)
                        .frame(width: 60)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onReceive(Just(resolution)) { newValue in
                            let filtered = newValue.filter { ("0"..."9").contains($0) }
                            if filtered != newValue {
                                self.resolution = String(filtered)
                            }
                        }
                }
                
                Button("Generate GIF") {
                    generateGIF()
                }
                .disabled(selectedPaths.isEmpty)
                
                if isInProgress {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: 200)
                }
                
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .padding(.top, 5)
                
                if let gifPath = gifPreviewPath {
                    VStack(spacing: 10) {
                        Text("Preview:")
                        
                        AnimatedGIFView(gifPath: gifPath)
                            .frame(width: 360, height: 360)
                            .cornerRadius(8)
                        
                        Button("Export") {
                            exportFile()
                        }
                    }
                }
            }
            .padding(10)
            .frame(width: 400)
            Spacer()
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }
    
    func detectMajorityFileFormat(from paths: [String]) -> String? {
        let extensions = paths.compactMap { URL(fileURLWithPath: $0).pathExtension.lowercased() }
        let countedSet = NSCountedSet(array: extensions)
        let majority = countedSet.max { countedSet.count(for: $0) < countedSet.count(for: $1) }
        return majority as? String
    }
    
    func updateImportedCountFromSelection() {
        let (_, _, count) = GIFGenerator.prepareFiles(from: selectedPaths, allowedExtensions: allowedExtensions)
        importedCount = count
    }
    
    func selectFiles() {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = true
            panel.canChooseFiles = true
            panel.allowedContentTypes = [.image]
            
            if panel.runModal() == .OK {
                selectedPaths = panel.urls.map { $0.path }
                updateImportedCountFromSelection()
            }
        }
    }
    
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        var found = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                    if let url = item as? URL {
                        DispatchQueue.main.async {
                            selectedPaths.append(url.path)
                            updateImportedCountFromSelection()
                        }
                    }
                    else if let data = item as? Data, let url = NSURL(absoluteURLWithDataRepresentation: data, relativeTo: nil) as URL? {
                        DispatchQueue.main.async {
                            selectedPaths.append(url.path)
                            updateImportedCountFromSelection()
                        }
                    }
                }
            }
            found = true
        }
        return found
    }
    
    func generateGIF() {
        guard !selectedPaths.isEmpty else {
            status = "No files selected"
            return
        }
        
        outputPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("output_\(UUID().uuidString).gif")
        
        let (inputFiles, majorityExtOpt, count) = GIFGenerator.prepareFiles(from: selectedPaths, allowedExtensions: allowedExtensions)
        importedCount = count
        
        guard let majorityExt = majorityExtOpt else {
            status = "Could not determine file format"
            return
        }
        
        guard let tempDir = GIFGenerator.copyFilesToTempDir(files: inputFiles, fileExtension: majorityExt) else {
            status = "Failed to prepare temp files"
            return
        }
        
        let inputPattern = "\(tempDir.path)/img%03d.\(majorityExt)"
        
        guard let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: "") else {
            status = "ffmpeg binary not found"
            return
        }
        
        guard let _ = Int(framerate), let _ = Int(resolution) else {
            status = "Invalid frame rate or resolution"
            return
        }
        
        guard !isInProgress else {
            status = "Already generating, please wait..."
            return
        }
        
        guard framerate != "0", resolution != "0" else {
            status = "Framerate or resolution cannot be zero"
            return
        }
        
        isInProgress = true
        progress = 0.0
        
        let steps = max(importedCount, 10)
        let delay = min(0.1, 3.0 / Double(steps))
        
        DispatchQueue.global(qos: .background).async {
            for i in 0...steps {
                Thread.sleep(forTimeInterval: delay)
                DispatchQueue.main.async {
                    progress = Double(i) / Double(steps)
                }
            }
        }
        
        GIFGenerator.runFFmpeg(
            ffmpegPath: ffmpegPath,
            inputPathPattern: inputPattern,
            framerate: framerate,
            resolution: resolution,
            outputPath: outputPath,
            onStatusUpdate: { message in
                self.status = message
            },
            onCompletion: { success in
                self.isInProgress = false
                self.progress = 1.0
                if success {
                    self.gifPreviewPath = self.outputPath
                }
            }
        )
    }
    
    func exportFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.gif]
        panel.nameFieldStringValue = "output.gif"
        
        guard panel.runModal() == .OK, let exportURL = panel.url else {
            status = "Export cancelled"
            return
        }
        
        do {
            if FileManager.default.fileExists(atPath: exportURL.path) {
                try FileManager.default.removeItem(at: exportURL)
            }
            try FileManager.default.copyItem(atPath: outputPath, toPath: exportURL.path)
            status = "GIF exported to \(exportURL.path)"
        }
        catch {
            status = "Failed to export GIF: \(error.localizedDescription)"
            print("Failed to export GIF: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ContentView()
}
